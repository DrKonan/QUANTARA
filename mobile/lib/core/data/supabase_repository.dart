import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/domain/auth_provider.dart';
import '../../features/predictions/domain/match_model.dart';
import '../../features/predictions/domain/prediction_model.dart';
import '../../features/predictions/domain/today_match_model.dart';

final supabaseRepoProvider = Provider<SupabaseRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseRepository(client);
});

class SupabaseRepository {
  final SupabaseClient _client;

  SupabaseRepository(this._client);

  // Cached league_id → {country, category} mapping from leagues_config
  Map<int, Map<String, String>>? _leagueMetaCache;

  Future<Map<int, Map<String, String>>> _getLeagueMetaMap() async {
    if (_leagueMetaCache != null) return _leagueMetaCache!;
    try {
      final data = await _client
          .from('leagues_config')
          .select('league_id, country, category');
      final map = <int, Map<String, String>>{};
      for (final row in (data as List)) {
        final leagueId = row['league_id'] as int;
        map[leagueId] = {
          'country': row['country'] as String? ?? '',
          'category': row['category'] as String? ?? 'other',
        };
      }
      _leagueMetaCache = map;
      debugPrint('[Quantara] Loaded ${map.length} league configs');
      return map;
    } catch (e) {
      debugPrint('[Quantara] Failed to load leagues_config: $e');
      return {};
    }
  }

  // ── Today Matches (Edge Function) ──

  Future<List<TodayMatch>> fetchTodayEligibleMatches({String? date, bool useEdgeFunction = true}) async {
    if (!useEdgeFunction) {
      debugPrint('[Quantara] Skipping Edge Function (no auth), using DB fallback');
      return _fetchTodayMatchesFallback(date);
    }

    try {
      final response = await _client.functions.invoke(
        'get-today-matches',
        queryParameters: date != null ? {'date': date} : {},
      );

      if (response.status != 200) {
        debugPrint('[Quantara] Edge function status: ${response.status}');
        debugPrint('[Quantara] Edge function body: ${response.data}');
        throw Exception('Edge function error: ${response.status}');
      }

      final body = response.data is String
          ? jsonDecode(response.data as String) as Map<String, dynamic>
          : response.data as Map<String, dynamic>;

      final matchesList = body['matches'] as List<dynamic>? ?? [];
      debugPrint('[Quantara] Edge function returned ${matchesList.length} matches');
      return matchesList
          .map((m) => TodayMatch.fromJson(m as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      debugPrint('[Quantara] Edge function failed: $e');
      debugPrint('[Quantara] Stack: $st');
      // Fallback: query DB directly if Edge Function unavailable
      try {
        final result = await _fetchTodayMatchesFallback(date);
        debugPrint('[Quantara] Fallback succeeded: ${result.length} matches');
        return result;
      } catch (e2) {
        debugPrint('[Quantara] Fallback also failed: $e2');
        rethrow;
      }
    }
  }

  Future<List<TodayMatch>> _fetchTodayMatchesFallback(String? date) async {
    final now = DateTime.now().toUtc();
    final targetDate = date ?? '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final dayStart = '${targetDate}T00:00:00+00:00';
    final dayEnd = '${targetDate}T23:59:59+00:00';

    final metaMap = await _getLeagueMetaMap();

    // Fetch ALL matches (including finished, excluding cancelled)
    final data = await _client
        .from('matches')
        .select()
        .gte('match_date', dayStart)
        .lte('match_date', dayEnd)
        .not('status', 'eq', 'cancelled')
        .order('match_date', ascending: true);

    final matches = (data as List).map((json) => _parseMatch(json, metaMap: metaMap)).toList();
    final nowMs = now.millisecondsSinceEpoch;

    // Fetch predictions for finished matches in one query
    final finishedIds = matches
        .where((m) => m.status == MatchStatus.finished)
        .map((m) => int.tryParse(m.id))
        .where((id) => id != null)
        .cast<int>()
        .toList();

    final predsByMatch = <int, List<TodayPrediction>>{};
    if (finishedIds.isNotEmpty) {
      try {
        final predData = await _client
            .from('predictions')
            .select()
            .inFilter('match_id', finishedIds)
            .eq('is_published', true);
        for (final p in (predData as List)) {
          final matchId = p['match_id'] as int;
          predsByMatch.putIfAbsent(matchId, () => []);
          predsByMatch[matchId]!.add(TodayPrediction.fromPredRow(p));
        }
      } catch (e) {
        debugPrint('[Quantara] Failed to fetch predictions for finished: $e');
      }
    }

    return matches.map((match) {
      final msUntil = match.dateTime.millisecondsSinceEpoch - nowMs;
      final minUntil = (msUntil / 60000).round();
      final leagueId = int.tryParse(match.league.id);
      final meta = leagueId != null ? metaMap[leagueId] : null;
      final category = meta?['category'] ?? 'other';

      String status;
      String message;
      int? wait;
      List<TodayPrediction> preds = [];

      if (match.status == MatchStatus.finished) {
        final matchPreds = predsByMatch[int.tryParse(match.id)] ?? [];
        preds = matchPreds;
        status = 'finished';
        message = matchPreds.isNotEmpty
            ? "Match termin\u00e9 \u2014 ${matchPreds.length} pr\u00e9diction(s) \u00e0 v\u00e9rifier"
            : "Match termin\u00e9";
      } else if (match.status == MatchStatus.live) {
        status = 'pending_live';
        message = "Analyse en cours \u2014 pr\u00e9dictions live bient\u00f4t";
        wait = 5;
      } else if (minUntil <= 90) {
        status = 'waiting_lineups';
        message = "En attente des compositions officielles";
        wait = (minUntil - 60).clamp(0, 90);
      } else {
        status = 'too_early';
        message = "Compositions ~1h avant le match";
        wait = (minUntil - 60).clamp(0, 999);
      }

      return TodayMatch(
        match: match,
        predictionStatus: status,
        predictionMessage: message,
        estimatedWaitMinutes: wait,
        minutesUntilKickoff: minUntil,
        predictions: preds,
        category: category,
      );
    }).toList();
  }

  // ── Matches ──

  Future<List<Match>> fetchTodayMatches() async {
    final now = DateTime.now().toUtc();
    final startOfDay = DateTime.utc(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final data = await _client
        .from('matches')
        .select()
        .gte('match_date', startOfDay.toIso8601String())
        .lt('match_date', endOfDay.toIso8601String())
        .order('match_date', ascending: true);

    return (data as List).map((json) => _parseMatch(json)).toList();
  }

  Future<List<Match>> fetchLiveMatches() async {
    final data = await _client
        .from('matches')
        .select()
        .eq('status', 'live')
        .order('match_date', ascending: true);

    return (data as List).map((json) => _parseMatch(json)).toList();
  }

  Future<List<Match>> fetchUpcomingMatches({int limit = 20}) async {
    final data = await _client
        .from('matches')
        .select()
        .eq('status', 'scheduled')
        .gte('match_date', DateTime.now().toUtc().toIso8601String())
        .order('match_date', ascending: true)
        .limit(limit);

    return (data as List).map((json) => _parseMatch(json)).toList();
  }

  Future<List<Match>> fetchFinishedMatches({int limit = 30}) async {
    final data = await _client
        .from('matches')
        .select()
        .eq('status', 'finished')
        .order('match_date', ascending: false)
        .limit(limit);

    return (data as List).map((json) => _parseMatch(json)).toList();
  }

  // ── Predictions ──

  Future<List<Prediction>> fetchPredictionsForMatch(int matchId) async {
    final data = await _client
        .from('predictions')
        .select()
        .eq('match_id', matchId)
        .eq('is_published', true)
        .order('confidence', ascending: false);

    return (data as List).map((json) => _parsePrediction(json)).toList();
  }

  Future<List<Prediction>> fetchLivePredictions() async {
    final data = await _client
        .from('predictions')
        .select('*, matches!inner(*)')
        .eq('is_live', true)
        .eq('is_published', true)
        .eq('matches.status', 'live')
        .order('confidence', ascending: false);

    return (data as List).map((json) => _parsePrediction(json)).toList();
  }

  Future<List<Prediction>> fetchTodayPredictions() async {
    // Fetch all published predictions with pending result (upcoming/today)
    final data = await _client
        .from('predictions')
        .select('*, matches!inner(*)')
        .eq('is_published', true)
        .eq('is_live', false)
        .isFilter('is_correct', null)
        .inFilter('matches.status', ['scheduled', 'finished'])
        .order('confidence', ascending: false);

    return (data as List).map((json) => _parsePrediction(json)).toList();
  }

  Future<List<Prediction>> fetchRecentResults({int limit = 50}) async {
    final data = await _client
        .from('predictions')
        .select('*, matches!inner(*)')
        .eq('is_published', true)
        .not('is_correct', 'is', null)
        .order('created_at', ascending: false)
        .limit(limit);

    return (data as List).map((json) => _parsePrediction(json)).toList();
  }

  // ── Stats ──

  Future<Map<String, dynamic>?> fetchGlobalStats() async {
    final data = await _client
        .from('prediction_stats')
        .select()
        .eq('period', 'all_time')
        .isFilter('league', null)
        .isFilter('prediction_type', null)
        .maybeSingle();

    return data;
  }

  Future<Map<String, dynamic>?> fetchMonthlyStats() async {
    final now = DateTime.now();
    final period = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final data = await _client
        .from('prediction_stats')
        .select()
        .eq('period', period)
        .isFilter('league', null)
        .isFilter('prediction_type', null)
        .maybeSingle();

    return data;
  }

  // ── User Profile ──

  Future<Map<String, dynamic>?> fetchUserProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();

    return data;
  }

  // ── Push Token ──

  Future<void> registerPushToken(String token, String platform) async {
    await _client.functions.invoke(
      'register-push-token',
      body: {'token': token, 'platform': platform},
    );
  }

  // ── Parsers ──

  Match _parseMatch(Map<String, dynamic> json, {Map<int, Map<String, String>>? metaMap}) {
    final leagueId = int.tryParse(json['league_id']?.toString() ?? '');
    final meta = metaMap != null && leagueId != null ? metaMap[leagueId] : null;
    final country = meta?['country'] ?? '';

    return Match(
      id: json['id'].toString(),
      externalId: int.tryParse(json['external_id']?.toString() ?? ''),
      homeTeam: Team(
        id: json['home_team_id']?.toString() ?? '',
        name: json['home_team'] as String,
      ),
      awayTeam: Team(
        id: json['away_team_id']?.toString() ?? '',
        name: json['away_team'] as String,
      ),
      league: League(
        id: leagueId?.toString() ?? '',
        name: json['league'] as String? ?? 'Unknown',
        country: country,
      ),
      dateTime: DateTime.parse(json['match_date'] as String).toUtc(),
      status: _parseStatus(json['status'] as String),
      score: (json['home_score'] != null && json['away_score'] != null)
          ? MatchScore(
              home: (json['home_score'] is int)
                  ? json['home_score'] as int
                  : int.tryParse(json['home_score'].toString()) ?? 0,
              away: (json['away_score'] is int)
                  ? json['away_score'] as int
                  : int.tryParse(json['away_score'].toString()) ?? 0,
            )
          : null,
      tier: (json['tier'] is int)
          ? json['tier'] as int
          : int.tryParse(json['tier']?.toString() ?? '') ?? 2,
    );
  }

  MatchStatus _parseStatus(String status) {
    switch (status) {
      case 'live':
        return MatchStatus.live;
      case 'finished':
        return MatchStatus.finished;
      default:
        return MatchStatus.upcoming;
    }
  }

  Prediction _parsePrediction(Map<String, dynamic> json) {
    final matchData = json['matches'] as Map<String, dynamic>?;
    final confidence = (json['confidence'] as num).toDouble();

    return Prediction(
      id: json['id'].toString(),
      matchId: json['match_id'].toString(),
      event: _formatEvent(
        json['prediction_type'] as String,
        json['prediction'] as String,
      ),
      confidence: confidence,
      analysis: json['analysis_text'] as String? ?? '',
      result: _parseResult(json['is_correct']),
      isLive: json['is_live'] as bool? ?? false,
      isPremium: json['is_premium'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      match: matchData != null ? _parseMatch(matchData) : null,
    );
  }

  PredictionResult _parseResult(dynamic isCorrect) {
    if (isCorrect == null) return PredictionResult.pending;
    return (isCorrect as bool) ? PredictionResult.won : PredictionResult.lost;
  }

  String _formatEvent(String type, String prediction) {
    switch (type) {
      case 'result':
        switch (prediction) {
          case 'home_win': return 'Victoire domicile';
          case 'away_win': return 'Victoire extérieur';
          case 'draw': return 'Match nul';
          default: return prediction;
        }
      case 'btts':
        return prediction == 'yes'
            ? 'Les deux équipes marquent'
            : 'Les deux ne marquent pas';
      case 'over_under':
        final parts = prediction.split('_');
        if (parts.length >= 2) {
          final direction = parts[0] == 'over' ? 'Plus de' : 'Moins de';
          return '$direction ${parts[1]} buts';
        }
        return prediction;
      case 'corners':
        return 'Corners: $prediction';
      case 'cards':
        return 'Cartons: $prediction';
      case 'halftime':
        switch (prediction) {
          case 'home_win': return 'Mi-temps: Avantage domicile';
          case 'away_win': return 'Mi-temps: Avantage extérieur';
          case 'draw': return 'Mi-temps: Égalité';
          default: return 'Mi-temps: $prediction';
        }
      default:
        return prediction;
    }
  }
}
