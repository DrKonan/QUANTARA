import 'match_model.dart';


class TodayMatch {
  final Match match;
  final String predictionStatus; // available, finished, pending_live, generating, waiting_lineups, too_early
  final String predictionMessage;
  final int? estimatedWaitMinutes;
  final int minutesUntilKickoff;
  final List<TodayPrediction> predictions;
  final String category; // major_international, top5, europe, south_america, rest_of_world, other

  const TodayMatch({
    required this.match,
    required this.predictionStatus,
    required this.predictionMessage,
    this.estimatedWaitMinutes,
    required this.minutesUntilKickoff,
    this.predictions = const [],
    this.category = 'other',
  });

  bool get hasPredictions => predictions.isNotEmpty;
  bool get isLive => match.status == MatchStatus.live;
  bool get isFinished => match.status == MatchStatus.finished || predictionStatus == 'finished';

  /// True if match kickoff was > 150 min ago and not explicitly live
  bool get isEffectivelyFinished {
    if (isFinished) return true;
    if (isLive) return false;
    final elapsed = DateTime.now().toUtc().difference(match.dateTime).inMinutes;
    return elapsed > 150;
  }

  String get waitLabel {
    if (estimatedWaitMinutes == null || estimatedWaitMinutes! <= 0) return "";
    if (estimatedWaitMinutes! < 60) return "~${estimatedWaitMinutes}min";
    final h = estimatedWaitMinutes! ~/ 60;
    final m = estimatedWaitMinutes! % 60;
    return m > 0 ? "~${h}h${m.toString().padLeft(2, '0')}" : "~${h}h";
  }

  factory TodayMatch.fromJson(Map<String, dynamic> json) {
    final matchData = Match(
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
        id: json['league_id']?.toString() ?? '',
        name: json['league'] as String? ?? 'Unknown',
        country: json['country'] as String? ?? '',
      ),
      dateTime: DateTime.parse(json['match_date'] as String),
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

    final preds = (json['predictions'] as List<dynamic>? ?? [])
        .map((p) => TodayPrediction.fromJson(p as Map<String, dynamic>))
        .toList();

    return TodayMatch(
      match: matchData,
      predictionStatus: json['prediction_status'] as String? ?? 'too_early',
      predictionMessage: json['prediction_message'] as String? ?? '',
      estimatedWaitMinutes: json['estimated_wait_minutes'] as int?,
      minutesUntilKickoff: json['minutes_until_kickoff'] as int? ?? 0,
      predictions: preds,
      category: json['category'] as String? ?? 'other',
    );
  }

  static MatchStatus _parseStatus(String status) {
    switch (status) {
      case 'live':
        return MatchStatus.live;
      case 'finished':
        return MatchStatus.finished;
      default:
        return MatchStatus.upcoming;
    }
  }
}

class TodayPrediction {
  final int id;
  final String predictionType;
  final String? prediction;
  final double? confidence;
  final String? confidenceLabel;
  final bool isPremium;
  final bool isLocked;
  final bool isLive;
  final String? analysisText;
  final bool? isCorrect;

  const TodayPrediction({
    required this.id,
    required this.predictionType,
    this.prediction,
    this.confidence,
    this.confidenceLabel,
    this.isPremium = false,
    this.isLocked = false,
    this.isLive = false,
    this.analysisText,
    this.isCorrect,
  });

  String get eventLabel {
    switch (predictionType) {
      case 'result':
        switch (prediction) {
          case 'home_win': return 'Victoire domicile';
          case 'away_win': return 'Victoire ext\u00e9rieur';
          case 'draw': return 'Match nul';
          default: return prediction ?? '\ud83d\udd12';
        }
      case 'btts':
        if (prediction == null) return '\ud83d\udd12';
        return prediction == 'yes'
            ? 'Les deux \u00e9quipes marquent'
            : 'Les deux ne marquent pas';
      case 'over_under':
        if (prediction == null) return '\ud83d\udd12';
        final parts = prediction!.split('_');
        if (parts.length >= 2) {
          return '${parts[0] == "over" ? "Plus de" : "Moins de"} ${parts[1]} buts';
        }
        return prediction!;
      case 'corners':
        return prediction != null ? 'Corners: $prediction' : '\ud83d\udd12';
      case 'cards':
        return prediction != null ? 'Cartons: $prediction' : '\ud83d\udd12';
      case 'halftime':
        switch (prediction) {
          case 'home_win': return 'Mi-temps: Avantage domicile';
          case 'away_win': return 'Mi-temps: Avantage ext\u00e9rieur';
          case 'draw': return 'Mi-temps: \u00c9galit\u00e9';
          default: return prediction != null ? 'Mi-temps: $prediction' : '\ud83d\udd12';
        }
      default:
        return prediction ?? '\ud83d\udd12';
    }
  }

  int get confidencePercent => ((confidence ?? 0) * 100).round();

  factory TodayPrediction.fromJson(Map<String, dynamic> json) {
    return TodayPrediction(
      id: json['id'] as int,
      predictionType: json['prediction_type'] as String,
      prediction: json['prediction'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      confidenceLabel: json['confidence_label'] as String?,
      isPremium: json['is_premium'] as bool? ?? false,
      isLocked: json['is_locked'] as bool? ?? false,
      isLive: json['is_live'] as bool? ?? false,
      analysisText: json['analysis_text'] as String?,
      isCorrect: json['is_correct'] as bool?,
    );
  }

  /// Create from a raw predictions DB row (used in fallback)
  factory TodayPrediction.fromPredRow(Map<String, dynamic> json) {
    return TodayPrediction(
      id: (json['id'] is int) ? json['id'] as int : int.parse(json['id'].toString()),
      predictionType: json['prediction_type'] as String,
      prediction: json['prediction'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      confidenceLabel: json['confidence_label'] as String?,
      isPremium: json['is_premium'] as bool? ?? false,
      isLocked: false,
      isLive: json['is_live'] as bool? ?? false,
      analysisText: json['analysis_text'] as String?,
      isCorrect: json['is_correct'] as bool?,
    );
  }
}
