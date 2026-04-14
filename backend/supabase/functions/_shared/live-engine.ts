// ============================================================
// QUANTARA — Shared : moteur de scoring live
// Indicateurs : possession, tirs cadrés, corners, cartons,
//               score actuel, xG ajustés
// Plan Ultra : 3 analyses par match Tier 1 (HT, 60', 75')
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

const PUBLISH_THRESHOLD = 0.60;

// ----------------------------------------------------------------
// Normalisation 0–1 d'une valeur entre min et max
// ----------------------------------------------------------------
function normalize(val: number, min: number, max: number): number {
  if (max === min) return 0.5;
  return Math.max(0, Math.min(1, (val - min) / (max - min)));
}

// ----------------------------------------------------------------
// Calcul du score live
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

  // Cartons rouges : pénalité directe pour l'équipe à 10
  const homeRedCards = stats.homeRedCards ?? 0;
  const awayRedCards = stats.awayRedCards ?? 0;
  const redCardAdv = (awayRedCards - homeRedCards) * 0.15; // +0.15 par carte rouge adverse

  // Score actuel — avantage pour l'équipe qui mène, pondéré par la minute
  const scoreDiff = stats.homeScore - stats.awayScore;
  const scoreScore = normalize(scoreDiff, -3, 3);
  // Plus le match avance, plus le score devient "définitif"
  const scoreWeight = 0.25 + 0.15 * minuteRatio; // 0.25 à 0.40

  // XG ajustés par la progression du match (régression vers la moyenne)
  const adjHomeXG = prematchXG.home * (1 - minuteRatio) + (stats.homeScore / Math.max(minuteRatio, 0.1)) * minuteRatio;
  const adjAwayXG = prematchXG.away * (1 - minuteRatio) + (stats.awayScore / Math.max(minuteRatio, 0.1)) * minuteRatio;

  // ── Résultat final probable (domicile) ────────────────────────
  const statWeight = 1 - scoreWeight; // reste du poids pour les stats
  const homeWinScore =
    possessionScore * (0.25 * statWeight) +
    shotsOnTargetScore * (0.30 * statWeight) +
    cornersScore * (0.15 * statWeight) +
    Math.max(0, redCardAdv) * (0.30 * statWeight) +
    scoreScore * scoreWeight;

  if (homeWinScore >= PUBLISH_THRESHOLD) {
    results.push({
      prediction: "home_win",
      prediction_type: "result",
      confidence: Math.min(homeWinScore, 0.99),
      score_breakdown: {
        possession: possessionScore,
        shots_on_target: shotsOnTargetScore,
        corners: cornersScore,
        red_card_advantage: redCardAdv,
        score_advantage: scoreScore,
        minute: stats.minute,
      },
    });
  }

  // ── Résultat extérieur ────────────────────────────────────────
  const awayWinScore =
    (1 - possessionScore) * (0.25 * statWeight) +
    (1 - shotsOnTargetScore) * (0.30 * statWeight) +
    (1 - cornersScore) * (0.15 * statWeight) +
    Math.max(0, -redCardAdv) * (0.30 * statWeight) +
    (1 - scoreScore) * scoreWeight;

  if (awayWinScore >= PUBLISH_THRESHOLD) {
    results.push({
      prediction: "away_win",
      prediction_type: "result",
      confidence: Math.min(awayWinScore, 0.99),
      score_breakdown: {
        possession: 1 - possessionScore,
        shots_on_target: 1 - shotsOnTargetScore,
        corners: 1 - cornersScore,
        red_card_advantage: -redCardAdv,
        score_advantage: 1 - scoreScore,
        minute: stats.minute,
      },
    });
  }

  // ── Match nul probable ────────────────────────────────────────
  if (stats.homeScore === stats.awayScore && stats.minute >= 65) {
    // Score nul tard dans le match + stats équilibrées
    const balancedStats = 1 - Math.abs(possessionScore - 0.5) * 2; // max quand 50-50
    const drawScore = balancedStats * 0.30 + minuteRatio * 0.40 + 0.30;
    if (drawScore >= PUBLISH_THRESHOLD) {
      results.push({
        prediction: "draw",
        prediction_type: "result",
        confidence: Math.min(drawScore, 0.99),
        score_breakdown: {
          balanced_stats: balancedStats,
          minute_factor: minuteRatio,
          score_tied: 1,
        },
      });
    }
  }

  // ── Over/Under buts restants ──────────────────────────────────
  const totalCurrentGoals = stats.homeScore + stats.awayScore;
  const remainingMinutes = Math.max(90 - stats.minute, 0);
  const totalShotsOnTarget = stats.homeShotsOnTarget + stats.awayShotsOnTarget;

  // Projection basée sur le rythme actuel + xG ajustés
  const goalsPerMinute = stats.minute > 0 ? totalCurrentGoals / stats.minute : 0;
  const projectedTotalGoals = totalCurrentGoals + goalsPerMinute * remainingMinutes;
  // Shots on target comme proxy de "pression" offensive
  const shotsRatio = stats.minute > 0 ? totalShotsOnTarget / stats.minute * 90 : 0;

  const over25LiveScore =
    normalize(projectedTotalGoals, 1.5, 4.5) * 0.50 +
    normalize(shotsRatio, 5, 20) * 0.25 +
    normalize(totalCurrentGoals, 0, 4) * 0.25;

  if (over25LiveScore >= PUBLISH_THRESHOLD) {
    results.push({
      prediction: "over_2.5",
      prediction_type: "over_under",
      confidence: Math.min(over25LiveScore, 0.99),
      score_breakdown: {
        current_goals: totalCurrentGoals,
        projected_goals: projectedTotalGoals,
        shots_on_target_ratio: shotsRatio,
        minute: stats.minute,
      },
    });
  }

  // Under 2.5 — si on approche de la fin avec peu de buts
  if (totalCurrentGoals <= 2 && stats.minute >= 60) {
    const under25LiveScore =
      (1 - normalize(projectedTotalGoals, 1.5, 4.5)) * 0.40 +
      minuteRatio * 0.35 +
      (1 - normalize(shotsRatio, 5, 20)) * 0.25;

    if (under25LiveScore >= PUBLISH_THRESHOLD) {
      results.push({
        prediction: "under_2.5",
        prediction_type: "over_under",
        confidence: Math.min(under25LiveScore, 0.99),
        score_breakdown: {
          current_goals: totalCurrentGoals,
          projected_goals: projectedTotalGoals,
          minute: stats.minute,
        },
      });
    }
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
      score_breakdown: { already_both_scored: 1, minute: stats.minute },
    });
  } else if (homeAlreadyScored || awayAlreadyScored) {
    // Une équipe a marqué, l'autre pas encore
    // Estimer la probabilité que l'autre marque dans le temps restant
    const scorelessTeamShots = homeAlreadyScored ? stats.awayShotsOnTarget : stats.homeShotsOnTarget;
    const shotsPerMin = stats.minute > 0 ? scorelessTeamShots / stats.minute : 0;
    const projectedExtraShots = shotsPerMin * remainingMinutes;
    const bttsProb = normalize(projectedExtraShots, 0, 3) * 0.60 + (1 - minuteRatio) * 0.40;

    if (bttsProb >= PUBLISH_THRESHOLD && stats.minute < 80) {
      results.push({
        prediction: "yes",
        prediction_type: "btts",
        confidence: Math.min(bttsProb, 0.85),
        score_breakdown: {
          scoreless_team_shots: scorelessTeamShots,
          projected_extra_shots: projectedExtraShots,
          minute: stats.minute,
        },
      });
    }
  }
  
  if (!homeAlreadyScored && !awayAlreadyScored && stats.minute >= 65) {
    // Fin de match proche, 0-0 → prono "no" élevé
    const noBttsLiveScore = normalize(stats.minute, 65, 90) * 0.70 + 
      (1 - normalize(totalShotsOnTarget, 0, 8)) * 0.30;
    if (noBttsLiveScore >= PUBLISH_THRESHOLD) {
      results.push({
        prediction: "no",
        prediction_type: "btts",
        confidence: Math.min(noBttsLiveScore, 0.99),
        score_breakdown: { minute: stats.minute, shots_on_target: totalShotsOnTarget },
      });
    }
  }

  return results
    .sort((a, b) => b.confidence - a.confidence)
    .slice(0, 5);
}
