// ============================================================
// QUANTARA — Shared : moteur de scoring (pré-match)
// Implémente le modèle documenté dans PREDICTION_ENGINE.md
// Marchés : result, double_chance, over_under, btts, corners, cards
// ============================================================

export interface TeamStats {
  teamId: number;
  teamName: string;
  recentForm: number[];          // 5 derniers matchs : 1=victoire, 0.5=nul, 0=défaite
  homeWinRate: number;           // 0.0 à 1.0
  awayWinRate: number;
  homeGoalsScored: number;       // moyenne buts marqués à domicile
  awayGoalsScored: number;       // moyenne buts marqués à l'extérieur
  homeGoalsConceded: number;
  awayGoalsConceded: number;
  elo: number;
  totalMatches?: number;         // nombre total de matchs joués cette saison
  avgYellowCards?: number;       // cartons jaunes par match
  avgRedCards?: number;          // cartons rouges par match
}

export interface MatchContext {
  isHighStakes: boolean;         // match à enjeu (titre, relégation)
  keyInjuries: number;           // nombre de joueurs clés absents
  h2hHomeWins: number;
  h2hDraws: number;
  h2hAwayWins: number;
  h2hTotal: number;
  h2hHomeGoalsAvg: number;
  h2hAwayGoalsAvg: number;
  // Facteurs de qualité des compos (1.0 = compo type, <1 = affaiblie, >1 = renforcée)
  // undefined = pas de compo dispo (mode initial)
  homeLineupFactor?: number;     // 0.5–1.2 — impact sur les xG domicile
  awayLineupFactor?: number;     // 0.5–1.2 — impact sur les xG extérieur
  leagueAvgCorners?: number;     // moyenne corners par match dans la ligue (défaut 10.5)
}

export interface ScoringResult {
  prediction: string;
  prediction_type: string;
  confidence: number;             // 0.0 à 1.0
  score_breakdown: Record<string, number>;
  is_top_pick?: boolean;          // marqué par selectTopPicks()
}

// ----------------------------------------------------------------
// Forme récente : moyenne pondérée (match récent = plus de poids)
// ----------------------------------------------------------------
function formScore(form: number[]): number {
  if (form.length === 0) return 0.5;
  const weights = [5, 4, 3, 2, 1].slice(0, form.length);
  const weightedSum = form.reduce((s, v, i) => s + v * weights[i], 0);
  const totalWeight = weights.reduce((s, w) => s + w, 0);
  return weightedSum / totalWeight;
}

// ----------------------------------------------------------------
// ELO : avantage relatif normalisé entre 0 et 1
// ----------------------------------------------------------------
function eloAdvantage(homeElo: number, awayElo: number): number {
  const diff = homeElo - awayElo;
  // Sigmoid centrée sur 0, plage ±400 points ≈ écart max réaliste
  return 1 / (1 + Math.exp(-diff / 200));
}

// ----------------------------------------------------------------
// Modèle de Poisson : proba P(X = k) pour k buts
// ----------------------------------------------------------------
function poissonProb(lambda: number, k: number): number {
  let p = Math.exp(-lambda);
  for (let i = 1; i <= k; i++) p *= lambda / i;
  return p;
}

function expectedGoals(
  attackAvg: number,
  defenceConcededAvg: number,
  leagueAvg = 1.35,
): number {
  return (attackAvg * defenceConcededAvg) / leagueAvg;
}

// ----------------------------------------------------------------
// Sélectionne la meilleure ligne de pari parmi les options
// Logique : choisit la ligne la plus proche de l'estimation, avec un
// léger biais vers l'écart (on veut une ligne où on a un avantage)
// Ex: estimatedCorners=11.2 → parmi [7.5, 8.5, 9.5, 10.5, 11.5, 12.5] → 10.5
// (en dessous de l'estimation = on parie over avec confiance)
// ----------------------------------------------------------------
export function selectBestLine(estimated: number, lines: number[]): number {
  // Choisit la ligne juste en dessous de l'estimation (pour un meilleur edge)
  // Si l'estimation est pile sur une ligne, on la prend
  let bestLine = lines[0];
  for (const line of lines) {
    if (line <= estimated) bestLine = line;
    else break;
  }
  return bestLine;
}

// ----------------------------------------------------------------
// Proba résultat (1X2) via modèle de Poisson (jusqu'à 10 buts)
// ----------------------------------------------------------------
export function computeResultProbs(
  homeXG: number,
  awayXG: number,
): { homeWin: number; draw: number; awayWin: number } {
  let homeWin = 0, draw = 0, awayWin = 0;
  for (let h = 0; h <= 10; h++) {
    for (let a = 0; a <= 10; a++) {
      const p = poissonProb(homeXG, h) * poissonProb(awayXG, a);
      if (h > a) homeWin += p;
      else if (h === a) draw += p;
      else awayWin += p;
    }
  }
  return { homeWin, draw, awayWin };
}

// ----------------------------------------------------------------
// Proba over/under buts
// ----------------------------------------------------------------
export function computeOverUnderProb(
  homeXG: number,
  awayXG: number,
  line: number,
): { over: number; under: number } {
  let under = 0;
  for (let h = 0; h <= 10; h++) {
    for (let a = 0; a <= 10; a++) {
      if (h + a <= Math.floor(line)) {
        under += poissonProb(homeXG, h) * poissonProb(awayXG, a);
      }
    }
  }
  return { over: 1 - under, under };
}

// ----------------------------------------------------------------
// Proba BTTS
// ----------------------------------------------------------------
export function computeBTTSProb(homeXG: number, awayXG: number): number {
  const homeScores = 1 - poissonProb(homeXG, 0);
  const awayScores = 1 - poissonProb(awayXG, 0);
  return homeScores * awayScores;
}

// ----------------------------------------------------------------
// Score composite pour le résultat du match (poids fixes doc)
// ----------------------------------------------------------------
export function computePrematchScores(
  home: TeamStats,
  away: TeamStats,
  ctx: MatchContext,
  isHome: boolean,  // true = calcul pour la victoire domicile
): ScoringResult[] {
  const PUBLISH_THRESHOLD = 0.50;
  const results: ScoringResult[] = [];

  const homeFormScore = formScore(home.recentForm);
  const awayFormScore = formScore(away.recentForm);
  const eloAdv = eloAdvantage(home.elo, away.elo);  // > 0.5 = avantage domicile

  // Blessures : pénalise proportionnellement à l'impact (max 30% de réduction)
  const injuryPenalty = Math.min(ctx.keyInjuries * 0.05, 0.3);

  // XG attendus (ajustés par la qualité de la compo si dispo)
  const homeLineupMul = ctx.homeLineupFactor ?? 1.0;
  const awayLineupMul = ctx.awayLineupFactor ?? 1.0;
  const homeXG = expectedGoals(home.homeGoalsScored, away.homeGoalsConceded) * homeLineupMul;
  const awayXG = expectedGoals(away.awayGoalsScored, home.homeGoalsConceded) * awayLineupMul;

  // ── 1. Résultat (1X2) ──────────────────────────────────────────
  const { homeWin, draw, awayWin } = computeResultProbs(homeXG, awayXG);

  // Score composite pour victoire domicile
  const homeFormWeight   = homeFormScore * 0.25;
  const homeStatWeight   = home.homeWinRate * 0.20;
  const h2hWeight        = ctx.h2hTotal > 0
    ? (ctx.h2hHomeWins / ctx.h2hTotal) * 0.15
    : 0.5 * 0.15;
  const eloWeight        = eloAdv * 0.15;
  const injuryWeight     = (1 - injuryPenalty) * 0.15;
  const stakesWeight     = (ctx.isHighStakes ? 0.6 : 0.5) * 0.10;
  const poissonHomeScore = homeWin;  // validation via Poisson

  const homeWinComposite =
    (homeFormWeight + homeStatWeight + h2hWeight + eloWeight + injuryWeight + stakesWeight) *
    (0.7 + 0.3 * poissonHomeScore);

  if (homeWinComposite >= PUBLISH_THRESHOLD) {
    results.push({
      prediction: "home_win",
      prediction_type: "result",
      confidence: Math.min(homeWinComposite, 0.99),
      score_breakdown: {
        form: homeFormWeight,
        home_stats: homeStatWeight,
        h2h: h2hWeight,
        elo: eloWeight,
        injuries: injuryWeight,
        stakes: stakesWeight,
        poisson_validation: poissonHomeScore,
      },
    });
  }

  // Score composite pour victoire extérieur
  const awayFormWeight  = awayFormScore * 0.25;
  const awayStatWeight  = away.awayWinRate * 0.20;
  const h2hAwayWeight   = ctx.h2hTotal > 0
    ? (ctx.h2hAwayWins / ctx.h2hTotal) * 0.15
    : 0.5 * 0.15;
  const eloAwayWeight   = (1 - eloAdv) * 0.15;
  const awayWinComposite =
    (awayFormWeight + awayStatWeight + h2hAwayWeight + eloAwayWeight + injuryWeight + stakesWeight) *
    (0.7 + 0.3 * awayWin);

  if (awayWinComposite >= PUBLISH_THRESHOLD) {
    results.push({
      prediction: "away_win",
      prediction_type: "result",
      confidence: Math.min(awayWinComposite, 0.99),
      score_breakdown: {
        form: awayFormWeight,
        away_stats: awayStatWeight,
        h2h: h2hAwayWeight,
        elo: eloAwayWeight,
        injuries: injuryWeight,
        stakes: stakesWeight,
        poisson_validation: awayWin,
      },
    });
  }

  // ── 2. Over/Under buts (ligne dynamique) ────────────────────────
  // Choix de la ligne la plus pertinente selon l'estimation xG
  const totalXG = homeXG + awayXG;
  const goalLine = selectBestLine(totalXG, [1.5, 2.5, 3.5, 4.5]);
  const { over: overGoals, under: underGoals } = computeOverUnderProb(homeXG, awayXG, goalLine);
  const h2hGoalsAvg = ctx.h2hTotal > 0
    ? (ctx.h2hHomeGoalsAvg + ctx.h2hAwayGoalsAvg)
    : (homeXG + awayXG);

  const overGoalsScore = overGoals * 0.6 + (h2hGoalsAvg > goalLine ? 0.3 : 0.1) + homeFormScore * 0.1;
  const underGoalsScore = underGoals * 0.6 + (h2hGoalsAvg < goalLine ? 0.3 : 0.1) + (1 - homeFormScore) * 0.1;

  if (overGoalsScore >= PUBLISH_THRESHOLD) {
    results.push({
      prediction: `over_${goalLine}`,
      prediction_type: "over_under",
      confidence: Math.min(overGoalsScore, 0.99),
      score_breakdown: { poisson_over: overGoals, h2h_goals: h2hGoalsAvg, form: homeFormScore * 0.1, line: goalLine, estimated_total: totalXG },
    });
  }
  if (underGoalsScore >= PUBLISH_THRESHOLD) {
    results.push({
      prediction: `under_${goalLine}`,
      prediction_type: "over_under",
      confidence: Math.min(underGoalsScore, 0.99),
      score_breakdown: { poisson_under: underGoals, h2h_goals: h2hGoalsAvg, line: goalLine, estimated_total: totalXG },
    });
  }

  // ── 3. BTTS ────────────────────────────────────────────────────
  const bttsProb = computeBTTSProb(homeXG, awayXG);
  const h2hBttsRate = ctx.h2hTotal > 0
    ? (ctx.h2hHomeGoalsAvg > 0.5 && ctx.h2hAwayGoalsAvg > 0.5 ? 0.7 : 0.3)
    : 0.5;

  const bttsScore = bttsProb * 0.65 + h2hBttsRate * 0.35;
  const noBttsScore = (1 - bttsProb) * 0.65 + (1 - h2hBttsRate) * 0.35;

  if (bttsScore >= PUBLISH_THRESHOLD) {
    results.push({
      prediction: "yes",
      prediction_type: "btts",
      confidence: Math.min(bttsScore, 0.99),
      score_breakdown: { poisson_btts: bttsProb, h2h_btts_rate: h2hBttsRate },
    });
  }
  if (noBttsScore >= PUBLISH_THRESHOLD) {
    results.push({
      prediction: "no",
      prediction_type: "btts",
      confidence: Math.min(noBttsScore, 0.99),
      score_breakdown: { poisson_no_btts: 1 - bttsProb, h2h_rate: 1 - h2hBttsRate },
    });
  }

  // ── 4. Double Chance ───────────────────────────────────────────
  const homeOrDraw = homeWin + draw;   // 1X
  const awayOrDraw = awayWin + draw;   // X2
  const homeOrAway = homeWin + awayWin; // 12

  // H2H bonus pour chaque combinaison
  const h2hHomeOrDrawRate = ctx.h2hTotal > 0
    ? (ctx.h2hHomeWins + ctx.h2hDraws) / ctx.h2hTotal : 0.65;
  const h2hAwayOrDrawRate = ctx.h2hTotal > 0
    ? (ctx.h2hAwayWins + ctx.h2hDraws) / ctx.h2hTotal : 0.55;

  const dcHomeOrDraw = homeOrDraw * 0.60 + h2hHomeOrDrawRate * 0.25 + homeFormScore * 0.15;
  if (dcHomeOrDraw >= 0.60) {
    results.push({
      prediction: "1X",
      prediction_type: "double_chance",
      confidence: Math.min(dcHomeOrDraw, 0.99),
      score_breakdown: { poisson_1x: homeOrDraw, h2h_rate: h2hHomeOrDrawRate, form: homeFormScore },
    });
  }

  const dcAwayOrDraw = awayOrDraw * 0.60 + h2hAwayOrDrawRate * 0.25 + awayFormScore * 0.15;
  if (dcAwayOrDraw >= 0.60) {
    results.push({
      prediction: "X2",
      prediction_type: "double_chance",
      confidence: Math.min(dcAwayOrDraw, 0.99),
      score_breakdown: { poisson_x2: awayOrDraw, h2h_rate: h2hAwayOrDrawRate, form: awayFormScore },
    });
  }

  const dcNoDrawRate = ctx.h2hTotal > 0
    ? (ctx.h2hHomeWins + ctx.h2hAwayWins) / ctx.h2hTotal : 0.60;
  const dcNoDraw = homeOrAway * 0.60 + dcNoDrawRate * 0.25 + Math.max(homeFormScore, awayFormScore) * 0.15;
  if (dcNoDraw >= 0.65) {
    results.push({
      prediction: "12",
      prediction_type: "double_chance",
      confidence: Math.min(dcNoDraw, 0.99),
      score_breakdown: { poisson_12: homeOrAway, h2h_no_draw: dcNoDrawRate },
    });
  }

  // ── 5. Corners Over/Under (ligne dynamique) ─────────────────────
  // Estimation basée sur l'intensité offensive des deux équipes
  const leagueAvgCorners = ctx.leagueAvgCorners ?? 10.5;
  const leagueAvgGoals = 1.35;
  const homeIntensity = ((home.homeGoalsScored + home.homeGoalsConceded) / 2) / leagueAvgGoals;
  const awayIntensity = ((away.awayGoalsScored + away.awayGoalsConceded) / 2) / leagueAvgGoals;
  const estimatedCorners = leagueAvgCorners * (homeIntensity + awayIntensity) / 2;
  const cornerLine = selectBestLine(estimatedCorners, [7.5, 8.5, 9.5, 10.5, 11.5, 12.5]);

  // Sigmoid : plus l'estimation s'éloigne de la ligne, plus la confiance est forte
  const overCornersRaw = 1 / (1 + Math.exp(-(estimatedCorners - cornerLine) / 1.5));
  const underCornersRaw = 1 - overCornersRaw;

  // Bonus H2H : matchs intenses entre ces équipes = plus de corners probable
  const h2hGoalsTotal = ctx.h2hTotal > 0 ? ctx.h2hHomeGoalsAvg + ctx.h2hAwayGoalsAvg : 2.5;
  const h2hIntensityBonus = h2hGoalsTotal > 2.5 ? 0.05 : -0.03;

  const overCornersScore = overCornersRaw + h2hIntensityBonus;
  const underCornersScore = underCornersRaw - h2hIntensityBonus;

  if (overCornersScore >= PUBLISH_THRESHOLD) {
    results.push({
      prediction: `over_${cornerLine}`,
      prediction_type: "corners",
      confidence: Math.min(overCornersScore, 0.99),
      score_breakdown: {
        estimated_corners: estimatedCorners,
        line: cornerLine,
        home_intensity: homeIntensity,
        away_intensity: awayIntensity,
        h2h_intensity_bonus: h2hIntensityBonus,
      },
    });
  }
  if (underCornersScore >= PUBLISH_THRESHOLD) {
    results.push({
      prediction: `under_${cornerLine}`,
      prediction_type: "corners",
      confidence: Math.min(underCornersScore, 0.99),
      score_breakdown: {
        estimated_corners: estimatedCorners,
        line: cornerLine,
        home_intensity: homeIntensity,
        away_intensity: awayIntensity,
        h2h_intensity_bonus: -h2hIntensityBonus,
      },
    });
  }

  // ── 6. Cards Over/Under (ligne dynamique) ───────────────────────
  // Basé sur les cartons jaunes moyens par match de chaque équipe
  const homeAvgCards = home.avgYellowCards ?? 2.0;
  const awayAvgCards = away.avgYellowCards ?? 2.0;
  const estimatedCards = homeAvgCards + awayAvgCards;
  const cardLine = selectBestLine(estimatedCards, [2.5, 3.5, 4.5, 5.5, 6.5]);

  // Sigmoid centrée sur la ligne
  const overCardsRaw = 1 / (1 + Math.exp(-(estimatedCards - cardLine) / 1.0));
  const underCardsRaw = 1 - overCardsRaw;

  // Bonus enjeu : matchs à enjeu = plus de tension = plus de cartons
  const stakesCardBonus = ctx.isHighStakes ? 0.05 : 0;

  const overCardsScore = overCardsRaw + stakesCardBonus;
  const underCardsScore = underCardsRaw - stakesCardBonus;

  if (overCardsScore >= PUBLISH_THRESHOLD) {
    results.push({
      prediction: `over_${cardLine}`,
      prediction_type: "cards",
      confidence: Math.min(overCardsScore, 0.99),
      score_breakdown: {
        estimated_cards: estimatedCards,
        line: cardLine,
        home_avg_cards: homeAvgCards,
        away_avg_cards: awayAvgCards,
        stakes_bonus: stakesCardBonus,
      },
    });
  }
  if (underCardsScore >= PUBLISH_THRESHOLD) {
    results.push({
      prediction: `under_${cardLine}`,
      prediction_type: "cards",
      confidence: Math.min(underCardsScore, 0.99),
      score_breakdown: {
        estimated_cards: estimatedCards,
        line: cardLine,
        home_avg_cards: homeAvgCards,
        away_avg_cards: awayAvgCards,
      },
    });
  }

  // Debug : log tous les scores calculés
  console.log(`[scoring-engine] homeXG=${homeXG.toFixed(2)} awayXG=${awayXG.toFixed(2)}`);
  console.log(`[scoring-engine] homeWinComposite=${homeWinComposite.toFixed(3)} awayWinComposite=${awayWinComposite.toFixed(3)}`);
  console.log(`[scoring-engine] over_under: line=${goalLine} estimated=${totalXG.toFixed(2)}`);
  console.log(`[scoring-engine] btts=${bttsScore.toFixed(3)} noBtts=${noBttsScore.toFixed(3)}`);
  console.log(`[scoring-engine] DC: 1X=${dcHomeOrDraw.toFixed(3)} X2=${dcAwayOrDraw.toFixed(3)} 12=${dcNoDraw.toFixed(3)}`);
  console.log(`[scoring-engine] corners=${estimatedCorners.toFixed(1)} line=${cornerLine} | cards=${estimatedCards.toFixed(1)} line=${cardLine}`);
  console.log(`[scoring-engine] PUBLISH_THRESHOLD=${PUBLISH_THRESHOLD} → ${results.length} predictions passed`);

  // Tri par confiance décroissante + sélection des top picks
  results.sort((a, b) => b.confidence - a.confidence);
  selectTopPicks(results);
  return results;
}

// ----------------------------------------------------------------
// Sélectionne les 1-2 meilleurs pronos par match (top picks)
// Règle : max 2 picks de types différents, confiance minimum 0.62
// Fallback : si aucun n'atteint 0.62, on prend le meilleur si >= 0.55
// Utilisé aussi par le live-engine.
// ----------------------------------------------------------------
export function selectTopPicks<T extends { confidence: number; prediction_type: string; is_top_pick?: boolean }>(
  results: T[],
  maxPicks = 2,
  minConfidence = 0.62,
): T[] {
  // Reset
  for (const r of results) r.is_top_pick = false;

  if (results.length === 0) return results;

  const sorted = [...results].sort((a, b) => b.confidence - a.confidence);
  let picked = 0;
  const pickedTypes = new Set<string>();

  for (const c of sorted) {
    if (picked >= maxPicks) break;
    if (c.confidence < minConfidence) break;
    // Un seul pick par type de marché (pas home_win ET away_win)
    if (pickedTypes.has(c.prediction_type)) continue;

    c.is_top_pick = true;
    pickedTypes.add(c.prediction_type);
    picked++;
  }

  // Fallback : si aucun pick, prend le meilleur si >= 0.55
  if (picked === 0 && sorted.length > 0 && sorted[0].confidence >= 0.55) {
    sorted[0].is_top_pick = true;
  }

  return results;
}
