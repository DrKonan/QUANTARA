// ============================================================
// QUANTARA — Edge Function : predict-prematch
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
// de QUANTARA : les infos de dernière minute changent tout.
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

    // 3b. Si mode raffinement, récupérer les effectifs pour évaluer la qualité des compos
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
    const matchCtx = parseH2HContext(h2hFixtures, match.home_team_id, false, keyInjuries);
    // Injecte les facteurs de compo dans le contexte
    matchCtx.homeLineupFactor = homeLineupFactor;
    matchCtx.awayLineupFactor = awayLineupFactor;

    // 7. Lance le moteur de scoring
    console.log(`[predict-prematch] homeStats:`, JSON.stringify(homeStats));
    console.log(`[predict-prematch] awayStats:`, JSON.stringify(awayStats));
    console.log(`[predict-prematch] matchCtx:`, JSON.stringify(matchCtx));
    const scoringResults = computePrematchScores(homeStats, awayStats, matchCtx, true);

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
      for (const [_key, id] of existingMap) {
        await supabase.from("predictions")
          .update({ is_published: false, is_refined: true, refined_at: new Date().toISOString() })
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
      }));

      const { error: insertError } = await supabase
        .from("predictions")
        .insert(predictions);

      if (insertError) throw insertError;

      console.log(`[predict-prematch] Published ${predictions.length} initial predictions for match ${match_id}`);

      return jsonResponse({ success: true, mode: "initial", match_id, predictions_count: predictions.length });
    }
  } catch (err) {
    console.error("[predict-prematch] Error:", err);
    return jsonResponse({ error: (err as Error).message }, 500);
  }
});
