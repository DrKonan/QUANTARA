import 'match_model.dart';
import 'prediction_model.dart';

class NakoraStats {
  final double successRate;
  final int totalPredictions;
  final int won;
  final int lost;

  const NakoraStats({
    required this.successRate,
    required this.totalPredictions,
    required this.won,
    required this.lost,
  });
}

// Dev mock data — will be replaced by Supabase queries

final mockStats = NakoraStats(
  successRate: 0.84,
  totalPredictions: 142,
  won: 119,
  lost: 23,
);

final mockMatches = <Match>[
  Match(
    id: 'm1',
    homeTeam: const Team(id: 't1', name: 'PSG'),
    awayTeam: const Team(id: 't2', name: 'Lyon'),
    league: const League(id: 'l1', name: 'Ligue 1', country: 'France', flagEmoji: '🇫🇷'),
    dateTime: DateTime.now().subtract(const Duration(minutes: 35)),
    status: MatchStatus.live,
    score: const MatchScore(home: 1, away: 0),
    minute: 35,
  ),
  Match(
    id: 'm2',
    homeTeam: const Team(id: 't3', name: 'Barcelona'),
    awayTeam: const Team(id: 't4', name: 'Real Madrid'),
    league: const League(id: 'l2', name: 'La Liga', country: 'Espagne', flagEmoji: '🇪🇸'),
    dateTime: DateTime.now().subtract(const Duration(minutes: 62)),
    status: MatchStatus.live,
    score: const MatchScore(home: 2, away: 2),
    minute: 62,
  ),
  Match(
    id: 'm3',
    homeTeam: const Team(id: 't5', name: 'ASEC Mimosas'),
    awayTeam: const Team(id: 't6', name: 'Africa Sports'),
    league: const League(id: 'l3', name: 'Ligue 1', country: "Côte d'Ivoire", flagEmoji: '🇨🇮'),
    dateTime: DateTime.now().add(const Duration(hours: 2)),
    status: MatchStatus.upcoming,
  ),
  Match(
    id: 'm4',
    homeTeam: const Team(id: 't7', name: 'Man City'),
    awayTeam: const Team(id: 't8', name: 'Arsenal'),
    league: const League(id: 'l4', name: 'Premier League', country: 'Angleterre', flagEmoji: '🏴\u200D☠️'),
    dateTime: DateTime.now().add(const Duration(hours: 4)),
    status: MatchStatus.upcoming,
  ),
  Match(
    id: 'm5',
    homeTeam: const Team(id: 't9', name: 'Bayern'),
    awayTeam: const Team(id: 't10', name: 'Dortmund'),
    league: const League(id: 'l5', name: 'Bundesliga', country: 'Allemagne', flagEmoji: '🇩🇪'),
    dateTime: DateTime.now().add(const Duration(hours: 5)),
    status: MatchStatus.upcoming,
  ),
];

final mockPredictions = <Prediction>[
  // Live predictions
  Prediction(
    id: 'p1',
    matchId: 'm1',
    event: 'Plus de 3.5 corners PSG',
    confidence: 0.87,
    analysis: "PSG domine à domicile avec 8.2 corners/match en moyenne. Lyon défend bas, ce qui génère des situations de corner.",
    isLive: true,
    createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
  ),
  Prediction(
    id: 'p2',
    matchId: 'm2',
    event: 'Les deux équipes marquent',
    confidence: 0.92,
    analysis: "Barcelona et Real Madrid ont marqué dans 80% de leurs derniers face-à-face. Les deux défenses sont fragiles ce soir.",
    isLive: true,
    result: PredictionResult.won,
    createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
  ),
  // Today predictions
  Prediction(
    id: 'p3',
    matchId: 'm3',
    event: "Victoire ASEC Mimosas",
    confidence: 0.79,
    analysis: "ASEC invaincu à domicile cette saison (8V-2N). Africa Sports reste sur 4 défaites consécutives à l'extérieur.",
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
  ),
  Prediction(
    id: 'p4',
    matchId: 'm3',
    event: 'Moins de 2.5 buts',
    confidence: 0.76,
    analysis: "Les matchs ASEC à domicile cette saison : moyenne de 1.8 buts. Africa Sports marque peu en déplacement (0.6 but/match).",
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
  ),
  Prediction(
    id: 'p5',
    matchId: 'm4',
    event: 'Plus de 9.5 corners total',
    confidence: 0.85,
    analysis: "Man City et Arsenal génèrent en moyenne 12.4 corners combinés. Le pressing haut des deux équipes multiplie les situations de corner.",
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  // Upcoming
  Prediction(
    id: 'p6',
    matchId: 'm5',
    event: 'Plus de 2.5 buts',
    confidence: 0.88,
    analysis: "Bayern-Dortmund : 3.4 buts/match en moyenne sur les 10 derniers face-à-face. Les deux attaques sont en grande forme.",
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
  ),
];

Match getMatchForPrediction(Prediction prediction) {
  return mockMatches.firstWhere((m) => m.id == prediction.matchId);
}
