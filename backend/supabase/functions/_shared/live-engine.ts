// ============================================================
// QUANTARA — Shared : moteur de scoring live
// Indicateurs : possession, tirs cadrés, corners, cartons,
//               score actuel, xG ajustés
// Marchés : result, over_under, btts, corners, cards
// ============================================================
import { selectTopPicks, selectBestLine } from "./scoring-engine.ts";

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
  is_top_pick?: boolean;
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

  // ── Over/Under buts restants (ligne dynamique) ─────────────────
  const totalCurrentGoals = stats.homeScore + stats.awayScore;
  const remainingMinutes = Math.max(90 - stats.minute, 0);
  const totalShotsOnTarget = stats.homeShotsOnTarget + stats.awayShotsOnTarget;

  // Projection basée sur le rythme actuel + xG ajustés
  const goalsPerMinute = stats.minute > 0 ? totalCurrentGoals / stats.minute : 0;
  const projectedTotalGoals = totalCurrentGoals + goalsPerMinute * remainingMinutes;
  // Shots on target comme proxy de "pression" offensive
  const shotsRatio = stats.minute > 0 ? totalShotsOnTarget / stats.minute * 90 : 0;

  const goalLineLive = selectBestLine(projectedTotalGoals, [1.5, 2.5, 3.5, 4.5]);

  const overGoalsLiveScore =
    normalize(projectedTotalGoals, goalLineLive - 1, goalLineLive + 2) * 0.50 +
    normalize(shotsRatio, 5, 20) * 0.25 +
    normalize(totalCurrentGoals, 0, 4) * 0.25;

  if (overGoalsLiveScore >= PUBLISH_THRESHOLD) {
    results.push({
      prediction: `over_${goalLineLive}`,
      prediction_type: "over_under",
      confidence: Math.min(overGoalsLiveScore, 0.99),
      score_breakdown: {
        current_goals: totalCurrentGoals,
        projected_goals: projectedTotalGoals,
        shots_on_target_ratio: shotsRatio,
        line: goalLineLive,
        minute: stats.minute,
      },
    });
  }

  // Under — si on approche de la fin avec peu de buts
  if (totalCurrentGoals <= Math.floor(goalLineLive) && stats.minute >= 60) {
    const underGoalsLiveScore =
      (1 - normalize(projectedTotalGoals, goalLineLive - 1, goalLineLive + 2)) * 0.40 +
      minuteRatio * 0.35 +
      (1 - normalize(shotsRatio, 5, 20)) * 0.25;

    if (underGoalsLiveScore >= PUBLISH_THRESHOLD) {
      results.push({
        prediction: `under_${goalLineLive}`,
        prediction_type: "over_under",
        confidence: Math.min(underGoalsLiveScore, 0.99),
        score_breakdown: {
          current_goals: totalCurrentGoals,
          projected_goals: projectedTotalGoals,
          line: goalLineLive,
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

  // ── Corners Over/Under live (ligne dynamique) ──────────────────
  const totalCorners = stats.homeCorners + stats.awayCorners;
  const projectedCorners = stats.minute > 5
    ? (totalCorners / stats.minute) * 90
    : 10.5; // pas assez de données
  const cornerLine = selectBestLine(projectedCorners, [7.5, 8.5, 9.5, 10.5, 11.5, 12.5]);

  if (stats.minute >= 30) {
    const overCornersLive = 1 / (1 + Math.exp(-(projectedCorners - cornerLine) / 1.5));
    // Pondérer par la certitude (plus on est avancé, plus la projection est fiable)
    const cornerCertainty = 0.50 + 0.50 * minuteRatio;
    const overCornersScore = overCornersLive * cornerCertainty;

    if (overCornersScore >= PUBLISH_THRESHOLD) {
      results.push({
        prediction: `over_${cornerLine}`,
        prediction_type: "corners",
        confidence: Math.min(overCornersScore, 0.99),
        score_breakdown: {
          current_corners: totalCorners,
          projected_corners: projectedCorners,
          line: cornerLine,
          minute: stats.minute,
        },
      });
    }

    // Under corners : si rythme bas en 2ème mi-temps
    if (stats.minute >= 60 && totalCorners <= Math.floor(cornerLine * 0.7)) {
      const underCornersScore = (1 - overCornersLive) * cornerCertainty;
      if (underCornersScore >= PUBLISH_THRESHOLD) {
        results.push({
          prediction: `under_${cornerLine}`,
          prediction_type: "corners",
          confidence: Math.min(underCornersScore, 0.99),
          score_breakdown: {
            current_corners: totalCorners,
            projected_corners: projectedCorners,
            line: cornerLine,
            minute: stats.minute,
          },
        });
      }
    }
  }

  // ── Cards Over/Under live (ligne dynamique) ────────────────────
  const totalCards = stats.homeYellowCards + stats.awayYellowCards +
    stats.homeRedCards + stats.awayRedCards;
  const projectedCards = stats.minute > 10
    ? (totalCards / stats.minute) * 90
    : 4.0;
  const cardLine = selectBestLine(projectedCards, [2.5, 3.5, 4.5, 5.5, 6.5]);

  if (stats.minute >= 30) {
    const overCardsLive = 1 / (1 + Math.exp(-(projectedCards - cardLine) / 1.0));
    const cardCertainty = 0.50 + 0.50 * minuteRatio;
    const overCardsScore = overCardsLive * cardCertainty;

    if (overCardsScore >= PUBLISH_THRESHOLD) {
      results.push({
        prediction: `over_${cardLine}`,
        prediction_type: "cards",
        confidence: Math.min(overCardsScore, 0.99),
        score_breakdown: {
          current_cards: totalCards,
          projected_cards: projectedCards,
          line: cardLine,
          minute: stats.minute,
        },
      });
    }

    // Under cards : si match calme en fin de partie
    if (stats.minute >= 60 && totalCards <= Math.floor(cardLine * 0.6)) {
      const underCardsScore = (1 - overCardsLive) * cardCertainty;
      if (underCardsScore >= PUBLISH_THRESHOLD) {
        results.push({
          prediction: `under_${cardLine}`,
          prediction_type: "cards",
          confidence: Math.min(underCardsScore, 0.99),
          score_breakdown: {
            current_cards: totalCards,
            projected_cards: projectedCards,
            line: cardLine,
            minute: stats.minute,
          },
        });
      }
    }
  }

  // Tri + sélection des top picks (max 2 pour le live, seuil plus bas)
  results.sort((a, b) => b.confidence - a.confidence);
  selectTopPicks(results, 2, 0.60);
  return results;
}
