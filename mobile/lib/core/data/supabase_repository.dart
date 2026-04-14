import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/domain/auth_provider.dart';
import '../../features/predictions/domain/match_model.dart';
import '../../features/predictions/domain/prediction_model.dart';

final supabaseRepoProvider = Provider<SupabaseRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseRepository(client);
});

class SupabaseRepository {
  final SupabaseClient _client;

  SupabaseRepository(this._client);

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
    final now = DateTime.now().toUtc();
    final startOfDay = DateTime.utc(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final data = await _client
        .from('predictions')
        .select('*, matches!inner(*)')
        .eq('is_published', true)
        .gte('matches.match_date', startOfDay.toIso8601String())
        .lt('matches.match_date', endOfDay.toIso8601String())
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

  Match _parseMatch(Map<String, dynamic> json) {
    return Match(
      id: json['id'].toString(),
      externalId: json['external_id'] as int?,
      homeTeam: Team(
        id: json['home_team_id']?.toString() ?? '',
        name: json['home_team'] as String,
      ),
      awayTeam: Team(
        id: json['away_team_id']?.toString() ?? '',
        name: json['away_team'] as String,
      ),
      league: League(
        id: json['league_id']?.toString() ?? '',
        name: json['league'] as String? ?? 'Unknown',
        country: '',
      ),
      dateTime: DateTime.parse(json['match_date'] as String),
      status: _parseStatus(json['status'] as String),
      score: (json['home_score'] != null && json['away_score'] != null)
          ? MatchScore(
              home: json['home_score'] as int,
              away: json['away_score'] as int,
            )
          : null,
      tier: json['tier'] as int? ?? 2,
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
