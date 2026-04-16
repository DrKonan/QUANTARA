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

  /// Minimum confidence to show any prediction to the user
  static const double minConfidence = 0.75;

  bool get hasPredictions => predictions.isNotEmpty;
  bool get isLive => match.status == MatchStatus.live;
  bool get isFinished => match.status == MatchStatus.finished || predictionStatus == 'finished';

  /// Has lineup been received? (at least one refined prediction exists)
  bool get hasLineup => predictions.any((p) => p.isRefined);

  /// Official coupon: refined top picks ≥75% + live ≥75%
  /// Only shown after lineup confirmation or during live
  List<TodayPrediction> get officialPredictions =>
      predictions.where((p) =>
        (p.confidence ?? 0) >= minConfidence &&
        ((p.isTopPick && p.isRefined) || p.isLive)
      ).toList();
  bool get hasOfficialPredictions => officialPredictions.isNotEmpty;

  /// Tendances: pre-lineup signals ≥75% (shown as hints before compo)
  List<TodayPrediction> get tendancePredictions {
    final list = predictions.where((p) =>
      (p.confidence ?? 0) >= minConfidence && !p.isRefined && !p.isLive
    ).toList()
      ..sort((a, b) => (b.confidence ?? 0).compareTo(a.confidence ?? 0));
    return list.take(2).toList(); // Max 2 tendances
  }
  bool get hasTendances => tendancePredictions.isNotEmpty;

  /// Everything visible to the user (official + tendances depending on state)
  bool get hasVisibleContent =>
      hasOfficialPredictions || (!hasLineup && hasTendances);

  List<TodayPrediction> get topPicks => predictions.where((p) => p.isTopPick).toList();
  List<TodayPrediction> get otherPredictions => predictions.where((p) => !p.isTopPick).toList();
  TodayPrediction? get bestTopPick {
    final picks = officialPredictions.where((p) => p.isTopPick).toList();
    if (picks.isEmpty) return null;
    picks.sort((a, b) => (b.confidence ?? 0).compareTo(a.confidence ?? 0));
    return picks.first;
  }
  /// Best visible prediction (official if available, else best tendance)
  TodayPrediction? get bestVisiblePrediction {
    if (hasOfficialPredictions) return bestTopPick ?? officialPredictions.first;
    if (!hasLineup && hasTendances) return tendancePredictions.first;
    return null;
  }

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
  final bool isTopPick;
  final bool isRefined;
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
    this.isTopPick = false,
    this.isRefined = false,
    this.analysisText,
    this.isCorrect,
  });

  String get typeIcon {
    switch (predictionType) {
      case 'result': return '⚽';
      case 'double_chance': return '🎯';
      case 'over_under': return '📊';
      case 'btts': return '🤝';
      case 'corners': return '🚩';
      case 'cards': return '🟨';
      default: return '📈';
    }
  }

  String get typeLabel {
    switch (predictionType) {
      case 'result': return 'RÉSULTAT';
      case 'double_chance': return 'DOUBLE CHANCE';
      case 'btts': return 'BTTS';
      case 'over_under': return 'BUTS';
      case 'corners': return 'CORNERS';
      case 'cards': return 'CARTONS';
      case 'halftime': return 'MI-TEMPS';
      default: return predictionType.toUpperCase();
    }
  }

  /// Human-readable label with optional team name substitution
  String eventLabelWith({String? home, String? away}) {
    switch (predictionType) {
      case 'result':
        switch (prediction) {
          case 'home_win': return home != null ? 'Victoire $home' : 'Victoire domicile';
          case 'away_win': return away != null ? 'Victoire $away' : 'Victoire extérieur';
          case 'draw': return 'Match nul';
          default: return prediction ?? '🔒';
        }
      case 'double_chance':
        switch (prediction) {
          case '1X': return home != null ? '$home ou Nul' : 'Domicile ou Nul';
          case 'X2': return away != null ? 'Nul ou $away' : 'Nul ou Extérieur';
          case '12': return 'Pas de match nul';
          default: return prediction ?? '🔒';
        }
      case 'btts':
        if (prediction == null) return '🔒';
        return prediction == 'yes'
            ? 'Les deux marquent'
            : 'Au moins un ne marque pas';
      case 'over_under':
        if (prediction == null) return '🔒';
        final parts = prediction!.split('_');
        if (parts.length >= 2) {
          return '${parts[0] == "over" ? "+" : "-"}${parts[1]} Buts';
        }
        return prediction!;
      case 'corners':
        if (prediction == null) return '🔒';
        final parts = prediction!.split('_');
        if (parts.length >= 2) {
          return '${parts[0] == "over" ? "+" : "-"}${parts[1]} Corners';
        }
        return prediction!;
      case 'cards':
        if (prediction == null) return '🔒';
        final parts = prediction!.split('_');
        if (parts.length >= 2) {
          return '${parts[0] == "over" ? "+" : "-"}${parts[1]} Cartons';
        }
        return prediction!;
      case 'halftime':
        switch (prediction) {
          case 'home_win': return 'Mi-temps: Avantage domicile';
          case 'away_win': return 'Mi-temps: Avantage extérieur';
          case 'draw': return 'Mi-temps: Égalité';
          default: return prediction != null ? 'Mi-temps: $prediction' : '🔒';
        }
      default:
        return prediction ?? '🔒';
    }
  }

  String get eventLabel => eventLabelWith();

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
      isTopPick: json['is_top_pick'] as bool? ?? false,
      isRefined: json['is_refined'] as bool? ?? false,
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
      isTopPick: json['is_top_pick'] as bool? ?? false,
      isRefined: json['is_refined'] as bool? ?? false,
      analysisText: json['analysis_text'] as String?,
      isCorrect: json['is_correct'] as bool?,
    );
  }
}
