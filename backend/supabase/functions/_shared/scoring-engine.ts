// ============================================================
// QUANTARA — Shared : moteur de scoring (pré-match)
// Implémente le modèle documenté dans PREDICTION_ENGINE.md
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
}

export interface ScoringResult {
  prediction: string;
  prediction_type: string;
  confidence: number;             // 0.0 à 1.0
  score_breakdown: Record<string, number>;
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

  // ── 2. Over/Under 2.5 buts ─────────────────────────────────────
  const { over: over25, under: under25 } = computeOverUnderProb(homeXG, awayXG, 2.5);
  const h2hGoalsAvg = ctx.h2hTotal > 0
    ? (ctx.h2hHomeGoalsAvg + ctx.h2hAwayGoalsAvg)
    : (homeXG + awayXG);

  const over25Score = over25 * 0.6 + (h2hGoalsAvg > 2.5 ? 0.3 : 0.1) + homeFormScore * 0.1;
  const under25Score = under25 * 0.6 + (h2hGoalsAvg < 2.5 ? 0.3 : 0.1) + (1 - homeFormScore) * 0.1;

  if (over25Score >= PUBLISH_THRESHOLD) {
    results.push({
      prediction: "over_2.5",
      prediction_type: "over_under",
      confidence: Math.min(over25Score, 0.99),
      score_breakdown: { poisson_over: over25, h2h_goals: h2hGoalsAvg, form: homeFormScore * 0.1 },
    });
  }
  if (under25Score >= PUBLISH_THRESHOLD) {
    results.push({
      prediction: "under_2.5",
      prediction_type: "over_under",
      confidence: Math.min(under25Score, 0.99),
      score_breakdown: { poisson_under: under25, h2h_goals: h2hGoalsAvg },
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

  // Debug : log tous les scores calculés (même ceux sous le seuil)
  console.log(`[scoring-engine] homeXG=${homeXG.toFixed(2)} awayXG=${awayXG.toFixed(2)}`);
  console.log(`[scoring-engine] homeWinComposite=${homeWinComposite.toFixed(3)} awayWinComposite=${awayWinComposite.toFixed(3)}`);
  console.log(`[scoring-engine] over25=${over25Score.toFixed(3)} under25=${under25Score.toFixed(3)}`);
  console.log(`[scoring-engine] btts=${bttsScore.toFixed(3)} noBtts=${noBttsScore.toFixed(3)}`);
  console.log(`[scoring-engine] PUBLISH_THRESHOLD=${PUBLISH_THRESHOLD} → ${results.length} predictions passed`);

  // Tri par confiance décroissante, max 5 pronos par match
  return results
    .sort((a, b) => b.confidence - a.confidence)
    .slice(0, 5);
}
