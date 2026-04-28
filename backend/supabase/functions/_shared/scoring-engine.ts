// ============================================================
// NAKORA — Shared : moteur de scoring (pré-match) V1.1
// Marchés : result, double_chance, over_under, btts, corners, cards
// V1.1 : calibration odds, vrais xG/corners, filtres anti-faux positifs
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
  // V1.1 — vrais stats historiques
  realXgAvg?: number;            // vrais xG moyens (expected_goals) des derniers matchs
  realCornersAvg?: number;       // vrais corners moyens des derniers matchs
  realCardsAvg?: number;         // vrais cartons moyens des derniers matchs
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
  homeLineupFactor?: number;     // 0.5–1.2 — impact sur les xG domicile
  awayLineupFactor?: number;     // 0.5–1.2 — impact sur les xG extérieur
  leagueAvgCorners?: number;     // moyenne corners par match dans la ligue (défaut 10.5)
  // V1.2 — Priority 2 features
  refereeAvgCards?: number;      // Moyenne cartons totaux/match de l'arbitre (défaut 4.5)
  travelDistanceKm?: number;     // Distance de déplacement de l'équipe visitante (km)
  homeMotivationScore?: number;  // 0.0–1.0 : enjeu classement (titre=0.90, mi-table=0.50)
  awayMotivationScore?: number;  // 0.0–1.0
}

// V1.1 — Données bookmakers pour calibration
export interface OddsData {
  homeWinOdds?: number;          // cote victoire domicile
  drawOdds?: number;             // cote nul
  awayWinOdds?: number;          // cote victoire extérieur
  over25Odds?: number;           // cote over 2.5
  under25Odds?: number;          // cote under 2.5
  bttsYesOdds?: number;          // cote BTTS oui
  bttsNoOdds?: number;           // cote BTTS non
  dc1XOdds?: number;             // cote double chance 1X
  dc12Odds?: number;             // cote double chance 12
  dcX2Odds?: number;             // cote double chance X2
}

// Mappe une prédiction spécifique vers sa cote bookmaker
export function mapPredictionToOdds(
  prediction: string,
  predictionType: string,
  odds: OddsData,
): number | undefined {
  switch (predictionType) {
    case "btts":
      return prediction === "yes" ? odds.bttsYesOdds : odds.bttsNoOdds;
    case "over_under":
      if (prediction === "over_2.5") return odds.over25Odds;
      if (prediction === "under_2.5") return odds.under25Odds;
      return undefined;
    case "double_chance":
      if (prediction === "1X") return odds.dc1XOdds;
      if (prediction === "12") return odds.dc12Odds;
      if (prediction === "X2") return odds.dcX2Odds;
      return undefined;
    case "result":
      if (prediction === "home_win") return odds.homeWinOdds;
      if (prediction === "draw") return odds.drawOdds;
      if (prediction === "away_win") return odds.awayWinOdds;
      return undefined;
    default:
      return undefined;
  }
}

// V1.1 — Prédictions API-Football pour cross-validation
export interface ApiPredictionData {
  winnerTeamId?: number;         // id de l'équipe favorite selon l'API
  homePercent?: number;          // 0-100
  drawPercent?: number;          // 0-100
  awayPercent?: number;          // 0-100
  advice?: string;               // ex: "Winner : PSG"
  underOver?: string | null;     // ex: "Under 3.5"
}

export interface ScoringResult {
  prediction: string;
  prediction_type: string;
  confidence: number;             // 0.0 à 1.0
  score_breakdown: Record<string, number>;
  is_top_pick?: boolean;          // marqué par selectTopPicks()
}

// ----------------------------------------------------------------
// V1.2 — Forme récente : décroissance exponentielle (0.85^k)
// Le match le plus récent a le poids 1.0, le précédent 0.85, etc.
// ----------------------------------------------------------------
function formScore(form: number[]): number {
  if (form.length === 0) return 0.5;
  const DECAY = 0.85;
  let weightedSum = 0;
  let totalWeight = 0;
  for (let i = 0; i < form.length; i++) {
    const w = Math.pow(DECAY, i);
    weightedSum += form[i] * w;
    totalWeight += w;
  }
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
  let bestLine = lines[0];
  for (const line of lines) {
    if (line <= estimated) bestLine = line;
    else break;
  }
  return bestLine;
}

// ----------------------------------------------------------------
// V1.1 — Calibration par les cotes bookmakers
// Convertit une cote en probabilité implicite puis compare à notre proba.
// Retourne un facteur multiplicateur pour la confiance.
// ----------------------------------------------------------------
function oddsToProb(odds: number): number {
  return odds > 0 ? 1 / odds : 0;
}

function oddsCalibrationFactor(ourProb: number, marketOdds: number | undefined): number {
  if (!marketOdds || marketOdds <= 1) return 1.0; // pas de données odds → neutre
  const marketProb = oddsToProb(marketOdds);
  const gap = Math.abs(ourProb - marketProb);
  if (gap < 0.10) return 1.05;   // concordance → bonus
  if (gap < 0.20) return 1.00;   // léger écart → neutre
  if (gap < 0.30) return 0.85;   // fort désaccord → pénalité
  return 0.70;                    // contradiction totale → forte pénalité
}

// ----------------------------------------------------------------
// V1.1 — Cross-validation API predictions
// ----------------------------------------------------------------
function apiPredictionFactor(
  prediction: string,
  predType: string,
  apiPred: ApiPredictionData | undefined,
  homeTeamId: number,
  awayTeamId: number,
): number {
  if (!apiPred) return 1.0; // pas de données → neutre

  if (predType === "result") {
    const apiWinner = apiPred.winnerTeamId;
    if (!apiWinner) return 1.0;
    if (prediction === "home_win" && apiWinner === homeTeamId) return 1.05;
    if (prediction === "away_win" && apiWinner === awayTeamId) return 1.05;
    if (prediction === "draw" && !apiPred.winnerTeamId) return 1.05;
    // Contradiction
    if (prediction === "home_win" && apiWinner === awayTeamId) return 0.90;
    if (prediction === "away_win" && apiWinner === homeTeamId) return 0.90;
    return 0.95;
  }

  if (predType === "over_under" && apiPred.underOver) {
    const apiSaysUnder = apiPred.underOver.toLowerCase().includes("under");
    const ourSaysUnder = prediction.startsWith("under");
    if (apiSaysUnder === ourSaysUnder) return 1.05;
    return 0.90;
  }

  return 1.0;
}

// ----------------------------------------------------------------
// V1.2 — Correction Dixon-Coles pour les scores faibles (τ)
// Corrige la sous/sur-représentation des scores 0-0, 1-0, 0-1, 1-1
// Rho ≈ -0.13 : corrélation négative observée empiriquement
// ----------------------------------------------------------------
function dixonColesCorrection(h: number, a: number, lH: number, lA: number, rho = -0.13): number {
  if (h === 0 && a === 0) return 1 - lH * lA * rho;
  if (h === 0 && a === 1) return 1 + lH * rho;
  if (h === 1 && a === 0) return 1 + lA * rho;
  if (h === 1 && a === 1) return 1 - rho;
  return 1.0;
}

// ----------------------------------------------------------------
// V1.2 — Proba résultat (1X2) via Poisson + correction Dixon-Coles
// ----------------------------------------------------------------
export function computeResultProbs(
  homeXG: number,
  awayXG: number,
): { homeWin: number; draw: number; awayWin: number } {
  let homeWin = 0, draw = 0, awayWin = 0;
  for (let h = 0; h <= 10; h++) {
    for (let a = 0; a <= 10; a++) {
      const tau = dixonColesCorrection(h, a, homeXG, awayXG);
      const p = poissonProb(homeXG, h) * poissonProb(awayXG, a) * tau;
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
  isHome: boolean,
  odds?: OddsData,
  apiPred?: ApiPredictionData,
): ScoringResult[] {
  const PUBLISH_THRESHOLD = 0.70;
  const results: ScoringResult[] = [];

  const homeFormScore = formScore(home.recentForm);
  const awayFormScore = formScore(away.recentForm);
  const eloAdv = eloAdvantage(home.elo, away.elo);

  const injuryPenalty = Math.min(ctx.keyInjuries * 0.05, 0.3);

  // V1.2 — xG : lineup + motivation classement + fatigue déplacement
  const homeLineupMul = ctx.homeLineupFactor ?? 1.0;
  const awayLineupMul = ctx.awayLineupFactor ?? 1.0;
  // Motivation : course au titre/relégation boost xG dans [0.90, 1.10]
  const homeMotivMul = ctx.homeMotivationScore != null ? 0.90 + ctx.homeMotivationScore * 0.20 : 1.0;
  const awayMotivMul = ctx.awayMotivationScore != null ? 0.90 + ctx.awayMotivationScore * 0.20 : 1.0;
  // Fatigue déplacement : >800km = -10%, >1500km = -15%
  const awayTravelMul = ctx.travelDistanceKm != null
    ? (ctx.travelDistanceKm > 1500 ? 0.85 : ctx.travelDistanceKm > 800 ? 0.90 : ctx.travelDistanceKm > 400 ? 0.95 : 1.0)
    : 1.0;
  const homeXG = (home.realXgAvg != null && home.realXgAvg > 0)
    ? home.realXgAvg * homeLineupMul * homeMotivMul
    : expectedGoals(home.homeGoalsScored, away.homeGoalsConceded) * homeLineupMul * homeMotivMul;
  const awayXG = (away.realXgAvg != null && away.realXgAvg > 0)
    ? away.realXgAvg * awayLineupMul * awayMotivMul * awayTravelMul
    : expectedGoals(away.awayGoalsScored, home.homeGoalsConceded) * awayLineupMul * awayMotivMul * awayTravelMul;

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

  // V1.1 — Calibration odds + cross-validation API
  const homeWinCalibrated = homeWinComposite
    * oddsCalibrationFactor(homeWin, odds?.homeWinOdds)
    * apiPredictionFactor("home_win", "result", apiPred, home.teamId, away.teamId);

  if (homeWinCalibrated >= PUBLISH_THRESHOLD) {
    results.push({
      prediction: "home_win",
      prediction_type: "result",
      confidence: Math.min(homeWinCalibrated, 0.99),
      score_breakdown: {
        form: homeFormWeight,
        home_stats: homeStatWeight,
        h2h: h2hWeight,
        elo: eloWeight,
        injuries: injuryWeight,
        stakes: stakesWeight,
        poisson_validation: poissonHomeScore,
        odds_calibration: oddsCalibrationFactor(homeWin, odds?.homeWinOdds),
        api_validation: apiPredictionFactor("home_win", "result", apiPred, home.teamId, away.teamId),
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

  // V1.1 — Calibration odds + cross-validation API
  const awayWinCalibrated = awayWinComposite
    * oddsCalibrationFactor(awayWin, odds?.awayWinOdds)
    * apiPredictionFactor("away_win", "result", apiPred, home.teamId, away.teamId);

  if (awayWinCalibrated >= PUBLISH_THRESHOLD) {
    results.push({
      prediction: "away_win",
      prediction_type: "result",
      confidence: Math.min(awayWinCalibrated, 0.99),
      score_breakdown: {
        form: awayFormWeight,
        away_stats: awayStatWeight,
        h2h: h2hAwayWeight,
        elo: eloAwayWeight,
        injuries: injuryWeight,
        stakes: stakesWeight,
        poisson_validation: awayWin,
        odds_calibration: oddsCalibrationFactor(awayWin, odds?.awayWinOdds),
        api_validation: apiPredictionFactor("away_win", "result", apiPred, home.teamId, away.teamId),
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

  // V1.1 — Calibration odds pour O/U + cross-validation API
  const overCalib = overGoalsScore
    * oddsCalibrationFactor(overGoals, odds?.over25Odds)
    * apiPredictionFactor(`over_${goalLine}`, "over_under", apiPred, home.teamId, away.teamId);
  const underCalib = underGoalsScore
    * oddsCalibrationFactor(underGoals, odds?.under25Odds)
    * apiPredictionFactor(`under_${goalLine}`, "over_under", apiPred, home.teamId, away.teamId);

  if (overCalib >= PUBLISH_THRESHOLD) {
    results.push({
      prediction: `over_${goalLine}`,
      prediction_type: "over_under",
      confidence: Math.min(overCalib, 0.99),
      score_breakdown: { poisson_over: overGoals, h2h_goals: h2hGoalsAvg, form: homeFormScore * 0.1, line: goalLine, estimated_total: totalXG, odds_calibration: oddsCalibrationFactor(overGoals, odds?.over25Odds) },
    });
  }
  // V1.1 — Filtre : under_1.5 a 42% winrate historique → on le bloque
  if (underCalib >= PUBLISH_THRESHOLD && goalLine !== 1.5) {
    results.push({
      prediction: `under_${goalLine}`,
      prediction_type: "over_under",
      confidence: Math.min(underCalib, 0.99),
      score_breakdown: { poisson_under: underGoals, h2h_goals: h2hGoalsAvg, line: goalLine, estimated_total: totalXG, odds_calibration: oddsCalibrationFactor(underGoals, odds?.under25Odds) },
    });
  }

  // ── 3. BTTS ────────────────────────────────────────────────────
  const bttsProb = computeBTTSProb(homeXG, awayXG);
  const h2hBttsRate = ctx.h2hTotal > 0
    ? (ctx.h2hHomeGoalsAvg > 0.5 && ctx.h2hAwayGoalsAvg > 0.5 ? 0.7 : 0.3)
    : 0.5;

  const bttsScore = bttsProb * 0.65 + h2hBttsRate * 0.35;
  const noBttsScore = (1 - bttsProb) * 0.65 + (1 - h2hBttsRate) * 0.35;

  // V1.1 — Calibration odds BTTS
  const bttsCalib = bttsScore * oddsCalibrationFactor(bttsProb, odds?.bttsYesOdds);
  const noBttsCalib = noBttsScore * oddsCalibrationFactor(1 - bttsProb, odds?.bttsNoOdds);

  if (bttsCalib >= PUBLISH_THRESHOLD) {
    results.push({
      prediction: "yes",
      prediction_type: "btts",
      confidence: Math.min(bttsCalib, 0.99),
      score_breakdown: { poisson_btts: bttsProb, h2h_btts_rate: h2hBttsRate, odds_calibration: oddsCalibrationFactor(bttsProb, odds?.bttsYesOdds) },
    });
  }
  if (noBttsCalib >= PUBLISH_THRESHOLD) {
    results.push({
      prediction: "no",
      prediction_type: "btts",
      confidence: Math.min(noBttsCalib, 0.99),
      score_breakdown: { poisson_no_btts: 1 - bttsProb, h2h_rate: 1 - h2hBttsRate, odds_calibration: oddsCalibrationFactor(1 - bttsProb, odds?.bttsNoOdds) },
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
  // V1.1 — Calibration odds pour double chance
  const dcHomeOrDrawCalib = dcHomeOrDraw * oddsCalibrationFactor(homeOrDraw, odds?.homeWinOdds);
  if (dcHomeOrDrawCalib >= 0.60) {
    results.push({
      prediction: "1X",
      prediction_type: "double_chance",
      confidence: Math.min(dcHomeOrDrawCalib, 0.99),
      score_breakdown: { poisson_1x: homeOrDraw, h2h_rate: h2hHomeOrDrawRate, form: homeFormScore },
    });
  }

  const dcAwayOrDraw = awayOrDraw * 0.60 + h2hAwayOrDrawRate * 0.25 + awayFormScore * 0.15;
  // V1.1 — X2 : publier seulement si calibré par odds
  const dcAwayOrDrawCalib = dcAwayOrDraw * oddsCalibrationFactor(awayOrDraw, odds?.awayWinOdds);
  if (dcAwayOrDrawCalib >= 0.60) {
    results.push({
      prediction: "X2",
      prediction_type: "double_chance",
      confidence: Math.min(dcAwayOrDrawCalib, 0.99),
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
  // V1.2 — Utilise les vrais corners si disponibles, sinon proxy intensité
  const leagueAvgCorners = ctx.leagueAvgCorners ?? 10.5;
  const leagueAvgGoals = 1.35;
  const homeIntensity = ((home.homeGoalsScored + home.homeGoalsConceded) / 2) / leagueAvgGoals;
  const awayIntensity = ((away.awayGoalsScored + away.awayGoalsConceded) / 2) / leagueAvgGoals;
  const estimatedCorners = (home.realCornersAvg != null && away.realCornersAvg != null)
    ? home.realCornersAvg + away.realCornersAvg
    : leagueAvgCorners * (homeIntensity + awayIntensity) / 2;
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
  // V1.2 — Vrais cartons × facteur arbitre (strict = plus de cartons)
  // 4.5 = moyenne ligue cartons totaux/match (référence de normalisation)
  const refereeFactor = ctx.refereeAvgCards != null
    ? Math.max(0.70, Math.min(1.50, ctx.refereeAvgCards / 4.5))
    : 1.0;
  const homeAvgCards = (home.realCardsAvg ?? home.avgYellowCards ?? 2.0) * refereeFactor;
  const awayAvgCards = (away.realCardsAvg ?? away.avgYellowCards ?? 2.0) * refereeFactor;
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

  // ── 7. Score exact (correct_score) ─────────────────────────────
  // Matrice Poisson+DC 6×6 → top score le plus probable
  // confidence : [0.12 → 0.70, 0.20+ → 0.95]
  const csProbs: Array<{ score: string; prob: number }> = [];
  for (let h = 0; h <= 5; h++) {
    for (let a = 0; a <= 5; a++) {
      const tau = dixonColesCorrection(h, a, homeXG, awayXG);
      csProbs.push({ score: `${h}-${a}`, prob: poissonProb(homeXG, h) * poissonProb(awayXG, a) * tau });
    }
  }
  csProbs.sort((x, y) => y.prob - x.prob);
  const topCS = csProbs[0];
  if (topCS && topCS.prob >= 0.12) {
    const csConf = Math.min(0.60 + (topCS.prob - 0.12) / 0.10 * 0.25, 0.95);
    results.push({
      prediction: topCS.score,
      prediction_type: "correct_score",
      confidence: csConf,
      score_breakdown: {
        probability: topCS.prob,
        second_prob: csProbs[1]?.prob ?? 0,
        home_xg: homeXG,
        away_xg: awayXG,
      },
    });
  }

  // ── 8. Mi-temps (half_time result 1X2) ─────────────────────────
  // λ_HT ≈ λ_FT × 0.45 (proportion empirique des buts en 1re mi-temps)
  const htHome = homeXG * 0.45;
  const htAway = awayXG * 0.45;
  const { homeWin: htHW, draw: htD, awayWin: htAW } = computeResultProbs(htHome, htAway);
  const htBest = [
    { prediction: "home_win", prob: htHW },
    { prediction: "draw", prob: htD },
    { prediction: "away_win", prob: htAW },
  ].sort((x, y) => y.prob - x.prob)[0];
  const htConf = Math.min(htBest.prob * 0.90, 0.99);
  if (htConf >= 0.58) {
    results.push({
      prediction: htBest.prediction,
      prediction_type: "half_time",
      confidence: htConf,
      score_breakdown: { ht_xg_home: htHome, ht_xg_away: htAway, ht_hw: htHW, ht_d: htD, ht_aw: htAW },
    });
  }

  // ── 9. Première équipe à scorer ─────────────────────────────────
  // P(X marque en premier) = λ_X / (λ_X + λ_Y) × P(≥1 but dans le match)
  const totalLambda = homeXG + awayXG;
  const pGoalInMatch = 1 - poissonProb(homeXG, 0) * poissonProb(awayXG, 0);
  if (pGoalInMatch >= 0.60 && totalLambda > 0) {
    const pHomeFirst = (homeXG / totalLambda) * pGoalInMatch;
    const pAwayFirst = (awayXG / totalLambda) * pGoalInMatch;
    // Bonus H2H : quelle équipe domine généralement les duels offensifs
    const h2hHomeFTS = ctx.h2hTotal > 0
      ? (ctx.h2hHomeGoalsAvg >= ctx.h2hAwayGoalsAvg ? 0.56 : 0.44) : 0.52;
    const homeFTSConf = pHomeFirst * 0.70 + h2hHomeFTS * 0.30;
    const awayFTSConf = pAwayFirst * 0.70 + (1 - h2hHomeFTS) * 0.30;
    if (homeFTSConf >= 0.60 && homeFTSConf >= awayFTSConf) {
      results.push({
        prediction: "home",
        prediction_type: "first_team_to_score",
        confidence: Math.min(homeFTSConf, 0.99),
        score_breakdown: { poisson_prob: pHomeFirst, h2h_factor: h2hHomeFTS, elo_adv: eloAdv },
      });
    } else if (awayFTSConf >= 0.60) {
      results.push({
        prediction: "away",
        prediction_type: "first_team_to_score",
        confidence: Math.min(awayFTSConf, 0.99),
        score_breakdown: { poisson_prob: pAwayFirst, h2h_factor: 1 - h2hHomeFTS },
      });
    }
  }

  // ── 10. Feuille blanche (clean_sheet) ──────────────────────────
  // P(feuille blanche) = P(adversaire marque 0 but) = e^(-λ_adversaire)
  const pHomeCS = poissonProb(awayXG, 0);
  const pAwayCS = poissonProb(homeXG, 0);
  if (pHomeCS >= 0.32) {
    const homeCSConf = pHomeCS * 0.65 + (home.homeGoalsConceded < 0.9 ? 0.20 : 0.10);
    if (homeCSConf >= 0.60) {
      results.push({
        prediction: "home",
        prediction_type: "clean_sheet",
        confidence: Math.min(homeCSConf, 0.99),
        score_breakdown: { p_clean_sheet: pHomeCS, avg_conceded: home.homeGoalsConceded, away_xg: awayXG },
      });
    }
  }
  if (pAwayCS >= 0.28) {
    const awayCSConf = pAwayCS * 0.65 + (away.awayGoalsConceded < 1.2 ? 0.15 : 0.08);
    if (awayCSConf >= 0.60) {
      results.push({
        prediction: "away",
        prediction_type: "clean_sheet",
        confidence: Math.min(awayCSConf, 0.99),
        score_breakdown: { p_clean_sheet: pAwayCS, avg_conceded: away.awayGoalsConceded, home_xg: homeXG },
      });
    }
  }

  // Debug : log tous les scores calculés
  console.log(`[scoring-engine] V1.2 — homeXG=${homeXG.toFixed(2)} awayXG=${awayXG.toFixed(2)} | motivH=${homeMotivMul.toFixed(2)} motivA=${awayMotivMul.toFixed(2)} travelA=${awayTravelMul.toFixed(2)} referee=${refereeFactor.toFixed(2)}`);
  console.log(`[scoring-engine] homeWinComposite=${homeWinComposite.toFixed(3)} awayWinComposite=${awayWinComposite.toFixed(3)}`);
  console.log(`[scoring-engine] over_under: line=${goalLine} estimated=${totalXG.toFixed(2)}`);
  console.log(`[scoring-engine] btts=${bttsScore.toFixed(3)} noBtts=${noBttsScore.toFixed(3)}`);
  console.log(`[scoring-engine] DC: 1X=${dcHomeOrDraw.toFixed(3)} X2=${dcAwayOrDraw.toFixed(3)} 12=${dcNoDraw.toFixed(3)}`);
  console.log(`[scoring-engine] corners=${estimatedCorners.toFixed(1)} line=${cornerLine} | cards=${estimatedCards.toFixed(1)} line=${cardLine}`);
  console.log(`[scoring-engine] PUBLISH_THRESHOLD=${PUBLISH_THRESHOLD} → ${results.length} predictions passed`);

  // V1.1 — Filtre draw : seuil minimum 0.88 (52.9% winrate historique)
  const filtered = results.filter(r => {
    // Le filtre anti-nul (52.9% winrate historique) ne s'applique qu'au marché résultat FT
    if (r.prediction_type === "result" && r.prediction === "draw" && r.confidence < 0.88) return false;
    return true;
  });

  // Tri par confiance décroissante + sélection des top picks
  filtered.sort((a, b) => b.confidence - a.confidence);
  selectTopPicks(filtered);
  return filtered;
}

// ----------------------------------------------------------------
// Sélectionne les 1-2 meilleurs pronos par match (top picks)
// V1.1 : confiance minimum relevée à 0.75 (de 0.62)
// ----------------------------------------------------------------
export function selectTopPicks<T extends { confidence: number; prediction_type: string; is_top_pick?: boolean }>(
  results: T[],
  maxPicks = 2,
  minConfidence = 0.75,
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
