/// Model for daily combo predictions (accumulators).
/// "Safe" combos (3-4 legs, ~3-6 odds) → PRO + VIP
/// "Bold" combos (4-6 legs, ~6-15 odds) → VIP only
class ComboPrediction {
  final int id;
  final String comboType; // 'safe' | 'bold'
  final double? combinedOdds;
  final double? combinedConfidence;
  final int legCount;
  final List<ComboLeg>? legs;
  final String status; // 'active' | 'won' | 'lost' | 'partial' | 'void'
  final bool isLocked;
  final String minPlan; // 'pro' | 'vip'
  final DateTime createdAt;

  const ComboPrediction({
    required this.id,
    required this.comboType,
    this.combinedOdds,
    this.combinedConfidence,
    required this.legCount,
    this.legs,
    required this.status,
    this.isLocked = false,
    required this.minPlan,
    required this.createdAt,
  });

  bool get isSafe => comboType == 'safe';
  bool get isBold => comboType == 'bold';
  bool get isActive => status == 'active';
  bool get isWon => status == 'won';
  bool get isLost => status == 'lost';
  bool get isPartial => status == 'partial';

  String get typeLabel => isSafe ? 'Combiné Sûr' : 'Combiné Audacieux';
  String get typeEmoji => isSafe ? '🛡️' : '🔥';
  int get confidencePercent => ((combinedConfidence ?? 0) * 100).round();

  String get oddsLabel {
    if (combinedOdds == null) return '🔒';
    return 'x${combinedOdds!.toStringAsFixed(2)}';
  }

  String get statusLabel {
    switch (status) {
      case 'won': return '✅ Gagné';
      case 'lost': return '❌ Perdu';
      case 'partial': return '⚠️ Partiel';
      case 'void': return '🚫 Annulé';
      default: return '⏳ En cours';
    }
  }

  factory ComboPrediction.fromJson(Map<String, dynamic> json) {
    List<ComboLeg>? legs;
    if (json['legs'] != null) {
      legs = (json['legs'] as List<dynamic>)
          .map((l) => ComboLeg.fromJson(l as Map<String, dynamic>))
          .toList();
    }

    return ComboPrediction(
      id: json['id'] as int,
      comboType: json['combo_type'] as String,
      combinedOdds: (json['combined_odds'] as num?)?.toDouble(),
      combinedConfidence: (json['combined_confidence'] as num?)?.toDouble(),
      legCount: json['leg_count'] as int? ?? legs?.length ?? 0,
      legs: legs,
      status: json['status'] as String? ?? 'active',
      isLocked: json['is_locked'] as bool? ?? false,
      minPlan: json['min_plan'] as String? ?? 'pro',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

class ComboLeg {
  final int predictionId;
  final int matchId;
  final String homeTeam;
  final String awayTeam;
  final String league;
  final String predictionType;
  final String prediction;
  final double confidence;
  final double bookmakerOdds;

  const ComboLeg({
    required this.predictionId,
    required this.matchId,
    required this.homeTeam,
    required this.awayTeam,
    required this.league,
    required this.predictionType,
    required this.prediction,
    required this.confidence,
    required this.bookmakerOdds,
  });

  int get confidencePercent => (confidence * 100).round();

  String get typeIcon {
    switch (predictionType) {
      case 'result': return '⚽';
      case 'double_chance': return '🎯';
      case 'over_under': return '📊';
      case 'btts': return '🤝';
      case 'corners': return '🚩';
      case 'cards': return '🟨';
      case 'correct_score': return '🎯';
      case 'half_time':
      case 'halftime': return '⏱️';
      case 'first_team_to_score': return '⚡';
      case 'clean_sheet': return '🛡️';
      default: return '📈';
    }
  }

  String get eventLabel {
    switch (predictionType) {
      case 'result':
        switch (prediction) {
          case 'home_win': return 'Victoire $homeTeam';
          case 'away_win': return 'Victoire $awayTeam';
          case 'draw': return 'Match nul';
          default: return prediction;
        }
      case 'double_chance':
        switch (prediction) {
          case '1X': return '$homeTeam ou Nul';
          case 'X2': return 'Nul ou $awayTeam';
          case '12': return 'Pas de match nul';
          default: return prediction;
        }
      case 'btts':
        return prediction == 'yes' ? 'Les deux marquent' : 'Un ne marque pas';
      case 'over_under':
        final parts = prediction.split('_');
        if (parts.length >= 2) {
          return '${parts[0] == "over" ? "+" : "-"}${parts[1]} Buts';
        }
        return prediction;
      case 'halftime':
      case 'half_time':
        switch (prediction) {
          case 'home_win': return 'Mi-temps : Avantage $homeTeam';
          case 'away_win': return 'Mi-temps : Avantage $awayTeam';
          case 'draw': return 'Mi-temps : Égalité';
          default: return 'Mi-temps : $prediction';
        }
      case 'correct_score':
        return 'Score exact : $prediction';
      case 'first_team_to_score':
        return prediction == 'home'
            ? '$homeTeam marque en premier'
            : '$awayTeam marque en premier';
      case 'clean_sheet':
        return prediction == 'home'
            ? '$homeTeam garde sa cage inviolée'
            : '$awayTeam garde sa cage inviolée';
      default:
        return prediction;
    }
  }

  factory ComboLeg.fromJson(Map<String, dynamic> json) {
    return ComboLeg(
      predictionId: json['prediction_id'] as int,
      matchId: json['match_id'] as int,
      homeTeam: json['home_team'] as String? ?? '',
      awayTeam: json['away_team'] as String? ?? '',
      league: json['league'] as String? ?? '',
      predictionType: json['prediction_type'] as String? ?? '',
      prediction: json['prediction'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      bookmakerOdds: (json['bookmaker_odds'] as num?)?.toDouble() ?? 1.0,
    );
  }
}
