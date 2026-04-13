// ============================================================
// QUANTARA — Shared : moteur de scoring live
// Indicateurs : possession, tirs cadrés, corners, cartons,
//               score actuel (poids définis dans PREDICTION_ENGINE.md)
// ============================================================

export interface LiveStats {
  minute: number;
  homeScore: number;
  awayScore: number;
  homePossession: number;        // 0–100
  homeShots: number;
  homeShotsOnTarget: number;
  awayShots: number;
  awayShotsOnTarget: number;
  homeCorners: number;
  awayCorners: number;
  homeYellowCards: number;
  awayYellowCards: number;
  homeRedCards: number;
  awayRedCards: number;
}

export interface LiveScoringResult {
  prediction: string;
  prediction_type: string;
  confidence: number;
  score_breakdown: Record<string, number>;
}

const PUBLISH_THRESHOLD = 0.75;

// ----------------------------------------------------------------
// Normalisation 0–1 d'une valeur entre min et max
// ----------------------------------------------------------------
function normalize(val: number, min: number, max: number): number {
  if (max === min) return 0.5;
  return Math.max(0, Math.min(1, (val - min) / (max - min)));
}

// ----------------------------------------------------------------
// Calcul du score live (BTTS, over/under, result tendance)
// ----------------------------------------------------------------
export function computeLiveScores(
  stats: LiveStats,
  prematchXG: { home: number; away: number },
): LiveScoringResult[] {
  const results: LiveScoringResult[] = [];
  const minuteRatio = Math.min(stats.minute / 90, 1);

  // ── Indicateurs normalisés ─────────────────────────────────────
  const possessionScore = normalize(stats.homePossession, 30, 70);
  const shotsOnTargetScore = normalize(stats.homeShotsOnTarget - stats.awayShotsOnTarget, -5, 5);
  const cornersScore = normalize(stats.homeCorners - stats.awayCorners, -5, 5);
  const cardsScore = normalize(stats.awayYellowCards + stats.awayRedCards * 2, 0, 5);

  // Score actuel — avantage pour l'équipe qui mène
  const scoreDiff = stats.homeScore - stats.awayScore;
  const scoreScore = normalize(scoreDiff, -3, 3);

  // XG ajustés par la progression du match (régression vers la moyenne)
  const adjHomeXG = prematchXG.home * (1 - minuteRatio) + (stats.homeScore / Math.max(minuteRatio, 0.1)) * minuteRatio;
  const adjAwayXG = prematchXG.away * (1 - minuteRatio) + (stats.awayScore / Math.max(minuteRatio, 0.1)) * minuteRatio;

  // ── Résultat final probable (domicile) ────────────────────────
  const homeWinScore =
    possessionScore * 0.20 +
    shotsOnTargetScore * 0.20 +
    cornersScore * 0.15 +
    cardsScore * 0.15 +
    scoreScore * 0.30;

  if (homeWinScore >= PUBLISH_THRESHOLD) {
    results.push({
      prediction: "home_win",
      prediction_type: "result",
      confidence: Math.min(homeWinScore, 0.99),
      score_breakdown: {
        possession: possessionScore * 0.20,
        shots: shotsOnTargetScore * 0.20,
        corners: cornersScore * 0.15,
        cards: cardsScore * 0.15,
        score: scoreScore * 0.30,
      },
    });
  }

  // ── Over/Under buts restants ──────────────────────────────────
  const totalCurrentGoals = stats.homeScore + stats.awayScore;
  const remainingMinutes = Math.max(90 - stats.minute, 0);
  const projectedTotalGoals = totalCurrentGoals + (adjHomeXG + adjAwayXG) * (remainingMinutes / 90);

  const over25LiveScore = normalize(projectedTotalGoals, 1.5, 4.5) * 0.65 +
    shotsOnTargetScore * 0.35;

  if (over25LiveScore >= PUBLISH_THRESHOLD) {
    results.push({
      prediction: "over_2.5",
      prediction_type: "over_under",
      confidence: Math.min(over25LiveScore, 0.99),
      score_breakdown: {
        projected_goals: projectedTotalGoals,
        shots_on_target: shotsOnTargetScore * 0.35,
      },
    });
  }

  // ── BTTS live ─────────────────────────────────────────────────
  const homeAlreadyScored = stats.homeScore > 0;
  const awayAlreadyScored = stats.awayScore > 0;

  if (homeAlreadyScored && awayAlreadyScored) {
    // BTTS déjà réalisé — prono "yes" avec haute confiance
    results.push({
      prediction: "yes",
      prediction_type: "btts",
      confidence: 0.97,
      score_breakdown: { already_both_scored: 1 },
    });
  } else if (!homeAlreadyScored && !awayAlreadyScored && stats.minute >= 70) {
    // Fin de match proche, aucun but — prono "no" élevé
    const noBttsLiveScore = normalize(stats.minute, 70, 90) * 0.80 + 0.15;
    if (noBttsLiveScore >= PUBLISH_THRESHOLD) {
      results.push({
        prediction: "no",
        prediction_type: "btts",
        confidence: Math.min(noBttsLiveScore, 0.99),
        score_breakdown: { minute: stats.minute, both_teams_scoreless: 1 },
      });
    }
  }

  return results
    .sort((a, b) => b.confidence - a.confidence)
    .slice(0, 4);
}
