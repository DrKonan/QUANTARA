// ============================================================
// QUANTARA — Edge Function : predict-prematch
// Déclencheur : appelée par fetch-lineups dès qu'un match a
//               ses compositions officielles.
// Body attendu : { match_id: number }
// Rôle : Collecte stats équipes + H2H + blessures (plan Ultra),
//        calcule les scores de confiance, publie les pronos.
//
// Stratégie Ultra Plan :
//   - /teams/statistics?team=&season=&league= → stats complètes
//   - /fixtures/headtohead?h2h=&last=10 → 10 derniers duels
//   - /injuries?fixture= → blessures du match
//   - 4 appels API par match
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
// Handler principal
// ----------------------------------------------------------------
Deno.serve(async (req: Request) => {
  try {
    const body = await req.json() as { match_id: number };
    const { match_id } = body;

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

    console.log(`[predict-prematch] Processing match ${match.home_team} vs ${match.away_team}`);

    // 2. Vérifie qu'on n'a pas déjà publié des pronos pré-match pour ce match
    const { count: existingCount } = await supabase
      .from("predictions")
      .select("id", { count: "exact", head: true })
      .eq("match_id", match_id)
      .eq("is_live", false);

    if (existingCount && existingCount > 0) {
      return jsonResponse({ message: "Predictions already exist for this match", match_id });
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
    }));

    const { error: insertError } = await supabase
      .from("predictions")
      .insert(predictions);

    if (insertError) throw insertError;

    console.log(`[predict-prematch] Published ${predictions.length} predictions for match ${match_id}`);

    // 10. Déclenche notify-users
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
    }).catch((err) => console.warn("[predict-prematch] notify-users trigger failed:", err));

    return jsonResponse({ success: true, match_id, predictions_count: predictions.length });
  } catch (err) {
    console.error("[predict-prematch] Error:", err);
    return jsonResponse({ error: (err as Error).message }, 500);
  }
});
