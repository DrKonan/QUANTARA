// ============================================================
// NAKORA — Edge Function : predict-prematch
// 
// DEUX MODES DE FONCTIONNEMENT :
// 
// 1) Mode INITIAL (sans compo) :
//    Appelé par le cron fetch-matches ou manuellement.
//    Génère des pronos basés sur stats + H2H + blessures.
//    → Pronos "de base" publiés immédiatement.
//
// 2) Mode RAFFINEMENT (avec compo) :
//    Appelé par fetch-lineups quand les compos officielles arrivent.
//    Body : { match_id, lineups: { home: [...], away: [...] } }
//    Recalcule les pronos en tenant compte de la qualité des titulaires.
//    → Les pronos existants sont MIS À JOUR (confiance, prédiction, etc.)
//    → Marqués is_refined = true + refined_at
//
// Ce mécanisme de raffinement est la clé de la proposition de valeur
// de NAKORA : les infos de dernière minute changent tout.
// Exemple : PSG-Brest, compo révèle des jeunes alignés →
// prono passe de "victoire PSG" à confiance réduite.
// ============================================================
import { apifootball, apifootballSequential } from "../_shared/api-football.ts";
import { getSupabaseAdmin } from "../_shared/supabase.ts";
import { jsonResponse, confidenceLabel } from "../_shared/helpers.ts";
import {
  computePrematchScores,
  TeamStats,
  MatchContext,
  OddsData,
  ApiPredictionData,
  mapPredictionToOdds,
} from "../_shared/scoring-engine.ts";
import { generateAnalysis } from "../_shared/openai.ts";

// ----------------------------------------------------------------
// Types API
// ----------------------------------------------------------------
interface ApiH2HFixture {
  teams: {
    home: { id: number; name: string; winner: boolean | null };
    away: { id: number; name: string; winner: boolean | null };
  };
  goals: { home: number | null; away: number | null };
}

interface ApiTeamStats {
  form: string | null;  // ex: "WWDLW"
  fixtures: {
    wins:  { home: number; away: number; total: number };
    draws: { home: number; away: number; total: number };
    loses: { home: number; away: number; total: number };
  };
  goals: {
    for:     { total: { home: number; away: number }; average: { home: string; away: string } };
    against: { total: { home: number; away: number }; average: { home: string; away: string } };
  };
  cards?: {
    yellow: Record<string, { total: number | null; percentage: string | null }>;
    red: Record<string, { total: number | null; percentage: string | null }>;
  };
}

interface LineupPlayer {
  id: number;
  name: string;
  number: number;
  pos: string;       // G, D, M, F
}

interface LineupsPayload {
  home: LineupPlayer[];
  away: LineupPlayer[];
}

// ----------------------------------------------------------------
// Parse les stats équipe depuis /teams/statistics
// ----------------------------------------------------------------
function parseTeamStats(
  raw: ApiTeamStats | null,
  teamId: number,
  teamName: string,
  eloRating: number,
): TeamStats {
  if (!raw) {
    return {
      teamId, teamName, elo: eloRating,
      recentForm: Array(5).fill(0.5),
      homeWinRate: 0.45, awayWinRate: 0.35,
      homeGoalsScored: 1.3, awayGoalsScored: 1.0,
      homeGoalsConceded: 1.2, awayGoalsConceded: 1.3,
      totalMatches: 0, avgYellowCards: 2.0, avgRedCards: 0.15,
    };
  }

  // Form : "WWDLW" → [1, 1, 0.5, 0, 1]
  const recentForm: number[] = [];
  if (raw.form) {
    for (const ch of raw.form.slice(-5)) {
      recentForm.push(ch === "W" ? 1 : ch === "D" ? 0.5 : 0);
    }
  }
  while (recentForm.length < 5) recentForm.push(0.5);

  const homeGames = raw.fixtures.wins.home + raw.fixtures.draws.home + raw.fixtures.loses.home;
  const awayGames = raw.fixtures.wins.away + raw.fixtures.draws.away + raw.fixtures.loses.away;
  const totalMatches = raw.fixtures.wins.total + raw.fixtures.draws.total + raw.fixtures.loses.total;

  // Parse cartons depuis les données API
  let avgYellowCards = 2.0;
  let avgRedCards = 0.15;
  if (raw.cards && totalMatches > 0) {
    let totalYellow = 0;
    let totalRed = 0;
    for (const period of Object.values(raw.cards.yellow ?? {})) {
      totalYellow += period?.total ?? 0;
    }
    for (const period of Object.values(raw.cards.red ?? {})) {
      totalRed += period?.total ?? 0;
    }
    avgYellowCards = totalYellow / totalMatches;
    avgRedCards = totalRed / totalMatches;
  }

  return {
    teamId,
    teamName,
    elo: eloRating,
    recentForm,
    homeWinRate: homeGames > 0 ? raw.fixtures.wins.home / homeGames : 0.45,
    awayWinRate: awayGames > 0 ? raw.fixtures.wins.away / awayGames : 0.35,
    homeGoalsScored: parseFloat(raw.goals.for.average.home) || 1.3,
    awayGoalsScored: parseFloat(raw.goals.for.average.away) || 1.0,
    homeGoalsConceded: parseFloat(raw.goals.against.average.home) || 1.2,
    awayGoalsConceded: parseFloat(raw.goals.against.average.away) || 1.3,
    totalMatches,
    avgYellowCards,
    avgRedCards,
  };
}

// ----------------------------------------------------------------
// Parse le contexte H2H
// ----------------------------------------------------------------
function parseH2HContext(
  h2hFixtures: ApiH2HFixture[],
  homeTeamId: number,
  isHighStakes: boolean,
  keyInjuries: number,
): MatchContext {
  if (!h2hFixtures || h2hFixtures.length === 0) {
    return {
      isHighStakes, keyInjuries,
      h2hHomeWins: 0, h2hDraws: 0, h2hAwayWins: 0,
      h2hTotal: 0, h2hHomeGoalsAvg: 0, h2hAwayGoalsAvg: 0,
    };
  }

  let homeWins = 0, draws = 0, awayWins = 0;
  let totalHomeGoals = 0, totalAwayGoals = 0;
  const recent = h2hFixtures.slice(0, 10);

  for (const f of recent) {
    const hGoals = f.goals.home ?? 0;
    const aGoals = f.goals.away ?? 0;
    const isHomeTeamAtHome = f.teams.home.id === homeTeamId;
    const homeTeamGoals = isHomeTeamAtHome ? hGoals : aGoals;
    const awayTeamGoals = isHomeTeamAtHome ? aGoals : hGoals;

    totalHomeGoals += homeTeamGoals;
    totalAwayGoals += awayTeamGoals;

    if (homeTeamGoals > awayTeamGoals) homeWins++;
    else if (homeTeamGoals === awayTeamGoals) draws++;
    else awayWins++;
  }

  return {
    isHighStakes, keyInjuries,
    h2hHomeWins: homeWins, h2hDraws: draws, h2hAwayWins: awayWins,
    h2hTotal: recent.length,
    h2hHomeGoalsAvg: totalHomeGoals / recent.length,
    h2hAwayGoalsAvg: totalAwayGoals / recent.length,
  };
}

// ----------------------------------------------------------------
// V1.2 — Score de motivation depuis le classement (0.0–1.0)
// ----------------------------------------------------------------
function computeMotivationScore(teamId: number, standingsData: unknown): number {
  if (!standingsData || !Array.isArray(standingsData) || standingsData.length === 0) return 0.5;
  try {
    const league = (standingsData[0] as {
      league?: {
        standings?: Array<Array<{
          team: { id: number };
          rank: number;
          description?: string | null;
          status?: string | null;
        }>>;
      };
    })?.league;
    if (!league?.standings?.[0]) return 0.5;
    const table = league.standings[0];
    const totalTeams = table.length;
    const entry = table.find((e) => e.team.id === teamId);
    if (!entry) return 0.5;
    const rank = entry.rank;
    const desc = ((entry.description ?? "") + " " + (entry.status ?? "")).toLowerCase();
    // Course au titre ou montée directe
    if (rank <= 3 || desc.includes("champion") || desc.includes("promotion")) return 0.90;
    // Place européenne
    if (rank <= 6 || desc.includes("europa") || desc.includes("conference")) return 0.70;
    // Relégation directe ou play-off descente
    if (desc.includes("relegation") || rank >= totalTeams - 2) return 0.80;
    if (rank >= totalTeams - 5) return 0.65;
    // Milieu de tableau sans enjeu
    return 0.50;
  } catch {
    return 0.50;
  }
}

// ----------------------------------------------------------------
// Calcul du facteur qualité de la compo
// Compare les titulaires de ce match aux données stats de l'API.
// Retourne un multiplicateur pour les xG : 
//   1.0  = compo type attendue
//   <1.0 = compo affaiblie (jeunes, rotations)
//   >1.0 = compo renforcée (tous les meilleurs)
// ----------------------------------------------------------------
function computeLineupFactor(
  lineup: LineupPlayer[],
  squadPlayers: ApiSquadPlayer[] | null,
): number {
  if (!squadPlayers || squadPlayers.length === 0 || lineup.length === 0) {
    return 1.0; // Pas assez de données → neutre
  }

  // Crée un set des titulaires du match (par ID)
  const starterIds = new Set(lineup.map(p => p.id));

  // Calcule combien de joueurs de l'effectif principal sont titulaires
  // L'effectif est trié par apparitions — les premiers sont les plus réguliers
  const regularPlayers = squadPlayers
    .filter(p => p.statistics?.[0]?.games?.appearences != null)
    .sort((a, b) => (b.statistics[0]?.games?.appearences ?? 0) - (a.statistics[0]?.games?.appearences ?? 0))
    .slice(0, 15); // Top 15 joueurs les plus utilisés

  if (regularPlayers.length === 0) return 1.0;

  const regularsInLineup = regularPlayers.filter(p => starterIds.has(p.player.id)).length;
  const regularityRatio = regularsInLineup / Math.min(regularPlayers.length, 11);

  // Échelle : 0% des réguliers → 0.65, 100% → 1.05
  // Un turnover massif (comme PSG avec des jeunes) = factor ~0.70
  const factor = 0.65 + regularityRatio * 0.40;
  return Math.max(0.50, Math.min(factor, 1.20));
}

interface ApiSquadPlayer {
  player: { id: number; name: string };
  statistics: Array<{
    games?: { appearences?: number; lineups?: number; minutes?: number };
  }>;
}

// ----------------------------------------------------------------
// Haversine : distance en km entre deux coordonnées GPS
// ----------------------------------------------------------------
function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2
    + Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ----------------------------------------------------------------
// Handler principal
// ----------------------------------------------------------------
Deno.serve(async (req: Request) => {
  try {
    const body = await req.json() as { match_id: number; lineups?: LineupsPayload };
    const { match_id, lineups } = body;
    const isRefinement = !!lineups;

    if (!match_id) {
      return jsonResponse({ error: "match_id is required" }, 400);
    }

    const supabase = getSupabaseAdmin();

    // 1. Récupère le match en base
    const { data: match, error: matchError } = await supabase
      .from("matches")
      .select("*")
      .eq("id", match_id)
      .single();

    if (matchError || !match) {
      return jsonResponse({ error: "Match not found" }, 404);
    }

    // Refuse de prédire sur un match déjà terminé, annulé, ou en cours
    if (match.status === "finished") {
      return jsonResponse({ error: "Match already finished", match_id }, 400);
    }
    if (match.status === "cancelled") {
      return jsonResponse({ error: "Match cancelled", match_id }, 400);
    }
    if (match.status === "live") {
      return jsonResponse({ error: "Match already in progress — use live predictions", match_id }, 400);
    }

    // Refuse de prédire si le match est dans le passé (safety net)
    const kickoff = new Date(match.match_date);
    if (kickoff.getTime() < Date.now()) {
      return jsonResponse({ error: "Match kickoff is in the past", match_id, match_date: match.match_date }, 400);
    }

    console.log(`[predict-prematch] Processing match ${match.home_team} vs ${match.away_team} (mode: ${isRefinement ? "REFINEMENT" : "INITIAL"})`);

    // 2. Vérifie les pronos existants
    const { count: existingCount } = await supabase
      .from("predictions")
      .select("id", { count: "exact", head: true })
      .eq("match_id", match_id)
      .eq("is_live", false);

    const hasExistingPredictions = existingCount && existingCount > 0;

    // Mode initial : skip si des pronos existent déjà
    if (!isRefinement && hasExistingPredictions) {
      return jsonResponse({ message: "Predictions already exist for this match — waiting for lineup refinement", match_id });
    }

    // 3. Récupère les données depuis l'API (4 appels — plan Ultra)
    //    /teams/statistics × 2 + H2H (last=10) + injuries
    const [homeStatsRaw, awayStatsRaw, h2hRaw, injuriesRaw] = await apifootballSequential([
      () => apifootball("/teams/statistics", {
        team: match.home_team_id,
        season: match.season,
        league: match.league_id,
      }),
      () => apifootball("/teams/statistics", {
        team: match.away_team_id,
        season: match.season,
        league: match.league_id,
      }),
      () => apifootball("/fixtures/headtohead", {
        h2h: `${match.home_team_id}-${match.away_team_id}`,
        last: 10,
      }),
      () => apifootball("/injuries", {
        fixture: match.external_id,
      }),
    ]);

    const h2hFixtures = (h2hRaw ?? []) as ApiH2HFixture[];

    // /teams/statistics retourne un objet (pas un tableau)
    const homeTeamStatsApi = homeStatsRaw as ApiTeamStats | null;
    const awayTeamStatsApi = awayStatsRaw as ApiTeamStats | null;

    // 3b. V1.1 — Récupère les cotes bookmakers, prédictions API, et stats historiques
    let oddsData: OddsData | undefined;
    let apiPredData: ApiPredictionData | undefined;
    let homeRealXg: number | undefined;
    let awayRealXg: number | undefined;
    let homeRealCorners: number | undefined;
    let awayRealCorners: number | undefined;
    let homeRealCards: number | undefined;
    let awayRealCards: number | undefined;
    let standingsData: unknown = null;

    try {
      const [oddsRaw, predRaw, homeLastFixturesRaw, awayLastFixturesRaw, standingsFetch] = await apifootballSequential([
        () => apifootball("/odds", { fixture: match.external_id }),
        () => apifootball("/predictions", { fixture: match.external_id }),
        () => apifootball("/fixtures", { team: match.home_team_id, last: 5, status: "FT" }),
        () => apifootball("/fixtures", { team: match.away_team_id, last: 5, status: "FT" }),
        () => apifootball("/standings", { league: match.league_id, season: match.season }),
      ]);
      standingsData = standingsFetch;

      // Parse odds
      if (Array.isArray(oddsRaw) && oddsRaw.length > 0) {
        const bookmaker = (oddsRaw[0] as { bookmakers?: Array<{ bets: Array<{ id: number; values: Array<{ value: string; odd: string }> }> }> })?.bookmakers?.[0];
        if (bookmaker) {
          const getBetOdds = (betId: number, val: string) => {
            const bet = bookmaker.bets.find((b: { id: number }) => b.id === betId);
            const v = bet?.values.find((v: { value: string }) => v.value === val);
            return v ? parseFloat(v.odd) : undefined;
          };
          oddsData = {
            homeWinOdds: getBetOdds(1, "Home"),
            drawOdds: getBetOdds(1, "Draw"),
            awayWinOdds: getBetOdds(1, "Away"),
            over25Odds: getBetOdds(5, "Over 2.5"),
            under25Odds: getBetOdds(5, "Under 2.5"),
            bttsYesOdds: getBetOdds(8, "Yes"),
            bttsNoOdds: getBetOdds(8, "No"),
            dc1XOdds: getBetOdds(12, "Home/Draw"),
            dc12Odds: getBetOdds(12, "Home/Away"),
            dcX2Odds: getBetOdds(12, "Draw/Away"),
          };
          console.log(`[predict-prematch] Odds loaded: H=${oddsData.homeWinOdds} D=${oddsData.drawOdds} A=${oddsData.awayWinOdds}`);
        }
      }

      // Parse API predictions
      if (Array.isArray(predRaw) && predRaw.length > 0) {
        const apiP = predRaw[0] as { predictions?: { winner?: { id?: number }; percent?: { home?: string; draw?: string; away?: string }; advice?: string; under_over?: string | null } };
        if (apiP?.predictions) {
          apiPredData = {
            winnerTeamId: apiP.predictions.winner?.id,
            homePercent: parseInt(apiP.predictions.percent?.home ?? "0"),
            drawPercent: parseInt(apiP.predictions.percent?.draw ?? "0"),
            awayPercent: parseInt(apiP.predictions.percent?.away ?? "0"),
            advice: apiP.predictions.advice,
            underOver: apiP.predictions.under_over,
          };
          console.log(`[predict-prematch] API prediction: winner=${apiPredData.winnerTeamId} advice="${apiPredData.advice}"`);
        }
      }

      // Parse historical stats (xG, corners, cards) from last 5 finished fixtures
      const extractAvgStats = async (fixturesRaw: unknown): Promise<{ xg: number | undefined; corners: number | undefined; cards: number | undefined }> => {
        if (!Array.isArray(fixturesRaw) || fixturesRaw.length === 0) return { xg: undefined, corners: undefined, cards: undefined };
        const fixtureIds = (fixturesRaw as Array<{ fixture: { id: number } }>).map(f => f.fixture.id).slice(0, 5);
        let totalXg = 0, totalCorners = 0, totalCards = 0, countXg = 0, countCorners = 0, countCards = 0;

        for (const fid of fixtureIds) {
          try {
            const statsRaw = await apifootball("/fixtures/statistics", { fixture: fid });
            if (!Array.isArray(statsRaw) || statsRaw.length < 2) continue;
            for (const teamStats of statsRaw as Array<{ statistics: Array<{ type: string; value: string | number | null }> }>) {
              for (const s of teamStats.statistics) {
                const val = s.value != null ? (typeof s.value === "number" ? s.value : parseFloat(String(s.value))) : NaN;
                if (isNaN(val)) continue;
                if (s.type === "expected_goals") { totalXg += val; countXg++; }
                if (s.type === "Corner Kicks") { totalCorners += val; countCorners++; }
                if (s.type === "Yellow Cards") { totalCards += val; countCards++; }
              }
            }
          } catch { /* skip fixture */ }
        }

        return {
          xg: countXg > 0 ? totalXg / countXg : undefined,
          corners: countCorners > 0 ? totalCorners / (countCorners / 2) : undefined, // per team per match
          cards: countCards > 0 ? totalCards / (countCards / 2) : undefined,
        };
      };

      const homeHistorical = await extractAvgStats(homeLastFixturesRaw);
      const awayHistorical = await extractAvgStats(awayLastFixturesRaw);
      homeRealXg = homeHistorical.xg;
      awayRealXg = awayHistorical.xg;
      homeRealCorners = homeHistorical.corners;
      awayRealCorners = awayHistorical.corners;
      homeRealCards = homeHistorical.cards;
      awayRealCards = awayHistorical.cards;

      console.log(`[predict-prematch] Real stats — homeXG=${homeRealXg?.toFixed(2)} awayXG=${awayRealXg?.toFixed(2)} homeCorners=${homeRealCorners?.toFixed(1)} awayCorners=${awayRealCorners?.toFixed(1)}`);

    } catch (err) {
      console.warn(`[predict-prematch] V1.1 enrichment failed (continuing with base model):`, err);
    }

    // 3c. Si mode raffinement, récupérer les effectifs pour évaluer la qualité des compos
    let homeLineupFactor = 1.0;
    let awayLineupFactor = 1.0;

    if (isRefinement && lineups) {
      try {
        // Récupère les effectifs complets (avec stats d'apparitions) — 2 appels API supplémentaires
        const [homeSquadRaw, awaySquadRaw] = await apifootballSequential([
          () => apifootball("/players/squads", { team: match.home_team_id }),
          () => apifootball("/players/squads", { team: match.away_team_id }),
        ]);

        // L'endpoint /players/squads retourne un array avec un objet par équipe
        const homeSquadPlayers = Array.isArray(homeSquadRaw)
          ? (homeSquadRaw[0] as { players?: ApiSquadPlayer[] })?.players ?? null
          : null;
        const awaySquadPlayers = Array.isArray(awaySquadRaw)
          ? (awaySquadRaw[0] as { players?: ApiSquadPlayer[] })?.players ?? null
          : null;

        // Utilise /players?team=X&season=Y pour les stats d'apparitions (plus fiable)
        const [homePlayersRaw, awayPlayersRaw] = await apifootballSequential([
          () => apifootball("/players", { team: match.home_team_id, season: match.season, league: match.league_id }),
          () => apifootball("/players", { team: match.away_team_id, season: match.season, league: match.league_id }),
        ]);

        const homePlayersStats = Array.isArray(homePlayersRaw) ? homePlayersRaw as ApiSquadPlayer[] : null;
        const awayPlayersStats = Array.isArray(awayPlayersRaw) ? awayPlayersRaw as ApiSquadPlayer[] : null;

        homeLineupFactor = computeLineupFactor(lineups.home, homePlayersStats);
        awayLineupFactor = computeLineupFactor(lineups.away, awayPlayersStats);

        console.log(`[predict-prematch] Lineup factors: home=${homeLineupFactor.toFixed(2)} away=${awayLineupFactor.toFixed(2)}`);
      } catch (err) {
        console.warn(`[predict-prematch] Failed to compute lineup factors, using 1.0:`, err);
      }
    }

    // 4. Récupère les ELO depuis la base (ou utilise 1500 par défaut)
    const { data: eloRows } = await supabase
      .from("team_elo")
      .select("team_id, elo")
      .in("team_id", [match.home_team_id, match.away_team_id]);

    const eloMap = new Map((eloRows ?? []).map((r: { team_id: number; elo: number }) => [r.team_id, r.elo]));
    const homeElo = eloMap.get(match.home_team_id) ?? 1500;
    const awayElo = eloMap.get(match.away_team_id) ?? 1500;

    // 5. Compte les blessures
    const keyInjuries = Array.isArray(injuriesRaw) ? (injuriesRaw as unknown[]).length : 0;

    // 6. Parse les stats d'équipe depuis /teams/statistics (plan Ultra)
    const homeStats = parseTeamStats(homeTeamStatsApi, match.home_team_id, match.home_team, homeElo);
    const awayStats = parseTeamStats(awayTeamStatsApi, match.away_team_id, match.away_team, awayElo);

    // V1.1 — Injecte les vrais stats historiques
    homeStats.realXgAvg = homeRealXg;
    awayStats.realXgAvg = awayRealXg;
    homeStats.realCornersAvg = homeRealCorners;
    awayStats.realCornersAvg = awayRealCorners;
    homeStats.realCardsAvg = homeRealCards;
    awayStats.realCardsAvg = awayRealCards;

    // 3d. Moyenne cartons de l'arbitre (2 appels séquentiels)
    let refereeAvgCards: number | undefined;
    try {
      const fixtureDetailsRaw = await apifootball("/fixtures", { id: match.external_id });
      const refereeName = Array.isArray(fixtureDetailsRaw) && fixtureDetailsRaw.length > 0
        ? (fixtureDetailsRaw[0] as { fixture: { referee?: string | null } }).fixture.referee
        : null;
      if (refereeName) {
        const refFixturesRaw = await apifootball("/fixtures", {
          referee: refereeName,
          season: match.season,
          last: 5,
        });
        if (Array.isArray(refFixturesRaw) && refFixturesRaw.length > 0) {
          const refIds = (refFixturesRaw as Array<{ fixture: { id: number } }>).map(f => f.fixture.id);
          let totalCards = 0, countMatches = 0;
          for (const fid of refIds) {
            try {
              const statsRaw = await apifootball("/fixtures/statistics", { fixture: fid });
              if (!Array.isArray(statsRaw)) continue;
              for (const ts of statsRaw as Array<{ statistics: Array<{ type: string; value: string | number | null }> }>) {
                for (const s of ts.statistics) {
                  if (s.type === "Yellow Cards" && s.value != null) {
                    totalCards += typeof s.value === "number" ? s.value : parseInt(String(s.value)) || 0;
                  }
                }
              }
              countMatches++;
            } catch { /* skip fixture */ }
          }
          if (countMatches > 0) {
            refereeAvgCards = totalCards / countMatches;
            console.log(`[predict-prematch] Referee "${refereeName}": avg ${refereeAvgCards.toFixed(1)} yellow cards/match`);
          }
        }
      }
    } catch (err) {
      console.warn("[predict-prematch] Referee stats failed (non-blocking):", err);
    }

    // 3e. Distance de déplacement (lookup table team_cities + Haversine)
    let travelDistanceKm: number | undefined;
    try {
      const { data: teamCities } = await supabase
        .from("team_cities")
        .select("team_id, latitude, longitude")
        .in("team_id", [match.home_team_id, match.away_team_id]);
      if (teamCities && teamCities.length === 2) {
        const homeCity = (teamCities as Array<{ team_id: number; latitude: number; longitude: number }>)
          .find(c => c.team_id === match.home_team_id);
        const awayCity = (teamCities as Array<{ team_id: number; latitude: number; longitude: number }>)
          .find(c => c.team_id === match.away_team_id);
        if (homeCity && awayCity) {
          travelDistanceKm = haversineKm(homeCity.latitude, homeCity.longitude, awayCity.latitude, awayCity.longitude);
          console.log(`[predict-prematch] Travel distance: ${travelDistanceKm.toFixed(0)}km`);
        }
      }
    } catch (err) {
      console.warn("[predict-prematch] Travel distance failed (non-blocking):", err);
    }

    const matchCtx = parseH2HContext(h2hFixtures, match.home_team_id, false, keyInjuries);
    // Injecte les facteurs de compo dans le contexte
    matchCtx.homeLineupFactor = homeLineupFactor;
    matchCtx.awayLineupFactor = awayLineupFactor;
    matchCtx.refereeAvgCards = refereeAvgCards;
    matchCtx.travelDistanceKm = travelDistanceKm;
    // V1.2 — Motivation depuis le classement
    const homeMotivationScore = computeMotivationScore(match.home_team_id, standingsData);
    const awayMotivationScore = computeMotivationScore(match.away_team_id, standingsData);
    matchCtx.homeMotivationScore = homeMotivationScore;
    matchCtx.awayMotivationScore = awayMotivationScore;
    console.log(`[predict-prematch] V1.2 — Motivation: home=${homeMotivationScore.toFixed(2)} away=${awayMotivationScore.toFixed(2)}`);

    // 7. Lance le moteur de scoring (V1.1 — avec odds + API predictions)
    console.log(`[predict-prematch] homeStats:`, JSON.stringify(homeStats));
    console.log(`[predict-prematch] awayStats:`, JSON.stringify(awayStats));
    console.log(`[predict-prematch] matchCtx:`, JSON.stringify(matchCtx));
    const scoringResults = computePrematchScores(homeStats, awayStats, matchCtx, true, oddsData, apiPredData);

    if (scoringResults.length === 0) {
      console.log(`[predict-prematch] No predictions above threshold for match ${match_id}`);
      return jsonResponse({ message: "No predictions above threshold", match_id });
    }

    // 8. Génère les analyses textuelles (OpenAI) en parallèle
    const analysisTexts = await Promise.all(
      scoringResults.map((r) =>
        generateAnalysis({
          homeTeam: match.home_team,
          awayTeam: match.away_team,
          league: match.league,
          matchDate: match.match_date,
          predictionType: r.prediction_type,
          prediction: r.prediction,
          confidence: r.confidence,
          scoreBreakdown: r.score_breakdown,
          lang: "fr",
        })
      ),
    );

    // 9. Sauvegarde les prédictions en base
    const PREMIUM_THRESHOLD = 0.70;

    if (isRefinement && hasExistingPredictions) {
      // ── MODE RAFFINEMENT : met à jour les pronos existants ──────
      console.log(`[predict-prematch] REFINEMENT mode — updating existing predictions`);

      // Récupère les pronos existants pour ce match
      const { data: existingPreds } = await supabase
        .from("predictions")
        .select("id, prediction_type, prediction")
        .eq("match_id", match_id)
        .eq("is_live", false);

      const existingMap = new Map(
        (existingPreds ?? []).map((p: { id: number; prediction_type: string; prediction: string }) =>
          [`${p.prediction_type}:${p.prediction}`, p.id]
        )
      );

      let updated = 0;
      let inserted = 0;
      let removed = 0;

      for (let i = 0; i < scoringResults.length; i++) {
        const r = scoringResults[i];
        const key = `${r.prediction_type}:${r.prediction}`;
        const existingId = existingMap.get(key);

        const predData = {
          confidence: r.confidence,
          confidence_label: confidenceLabel(r.confidence),
          is_premium: r.confidence >= PREMIUM_THRESHOLD,
          analysis_text: analysisTexts[i],
          score_breakdown: r.score_breakdown,
          is_refined: true,
          refined_at: new Date().toISOString(),
          is_top_pick: r.is_top_pick ?? false,
          bookmaker_odds: oddsData ? mapPredictionToOdds(r.prediction, r.prediction_type, oddsData) ?? null : null,
        };

        if (existingId) {
          // Met à jour le prono existant avec la nouvelle confiance
          await supabase.from("predictions").update(predData).eq("id", existingId);
          existingMap.delete(key);
          updated++;
        } else {
          // Nouveau type de prono qui n'existait pas avant → INSERT
          await supabase.from("predictions").insert({
            match_id,
            prediction_type: r.prediction_type,
            prediction: r.prediction,
            is_live: false,
            is_correct: null,
            is_published: true,
            ...predData,
          });
          inserted++;
        }
      }

      // Pronos qui existaient avant mais ne sont plus au-dessus du seuil → on les dépublie
      // ET on reset leur top_pick
      for (const [_key, id] of existingMap) {
        await supabase.from("predictions")
          .update({ is_published: false, is_refined: true, refined_at: new Date().toISOString(), is_top_pick: false })
          .eq("id", id);
        removed++;
      }

      console.log(`[predict-prematch] Refinement done: ${updated} updated, ${inserted} new, ${removed} depublished`);

      return jsonResponse({
        success: true,
        mode: "refinement",
        match_id,
        updated,
        inserted,
        removed,
        lineup_factors: { home: homeLineupFactor, away: awayLineupFactor },
      });

    } else {
      // ── MODE INITIAL : insert les pronos ─────────────────────────

      const predictions = scoringResults.map((r, i) => ({
        match_id,
        prediction_type: r.prediction_type,
        prediction: r.prediction,
        confidence: r.confidence,
        confidence_label: confidenceLabel(r.confidence),
        is_premium: r.confidence >= PREMIUM_THRESHOLD,
        is_live: false,
        analysis_text: analysisTexts[i],
        score_breakdown: r.score_breakdown,
        is_correct: null,
        is_published: true,
        is_refined: false,
        is_top_pick: r.is_top_pick ?? false,
        bookmaker_odds: oddsData ? mapPredictionToOdds(r.prediction, r.prediction_type, oddsData) ?? null : null,
      }));

      const { error: insertError } = await supabase
        .from("predictions")
        .insert(predictions);

      if (insertError) throw insertError;

      console.log(`[predict-prematch] Published ${predictions.length} initial predictions for match ${match_id}`);

      // Déclenche la notification push
      const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
      const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
      fetch(`${supabaseUrl}/functions/v1/notify-users`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${serviceKey}`,
        },
        body: JSON.stringify({
          type: "new_predictions",
          match_id,
          count: predictions.length,
        }),
      }).catch((err) => console.warn("[predict-prematch] notify-users failed:", err));

      return jsonResponse({ success: true, mode: "initial", match_id, predictions_count: predictions.length });
    }
  } catch (err) {
    console.error("[predict-prematch] Error:", err);
    return jsonResponse({ error: (err as Error).message }, 500);
  }
});
