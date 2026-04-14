// ============================================================
// QUANTARA — Edge Function : predict-prematch
// Déclencheur : appelée par fetch-lineups dès qu'un match a
//               ses compositions officielles.
// Body attendu : { match_id: number }
// Rôle : Collecte H2H + blessures (free-plan compatible),
//        calcule les scores de confiance, publie les pronos.
//
// Stratégie Free Plan :
//   - /fixtures/headtohead (sans last) → retourne ~30 duels → stats des 2 équipes
//   - /injuries?fixture= → blessures du match
//   - PAS de /teams/statistics (bloqué season 2025+)
//   - 2 appels API au lieu de 4
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
// Types H2H
// ----------------------------------------------------------------
interface ApiH2HFixture {
  teams: {
    home: { id: number; name: string; winner: boolean | null };
    away: { id: number; name: string; winner: boolean | null };
  };
  goals: { home: number | null; away: number | null };
}

// ----------------------------------------------------------------
// Dérive les TeamStats et le MatchContext depuis le H2H
// ----------------------------------------------------------------
function deriveStatsFromH2H(
  h2hFixtures: ApiH2HFixture[],
  teamId: number,
  teamName: string,
  eloRating: number,
): TeamStats {
  if (!h2hFixtures || h2hFixtures.length === 0) {
    return {
      teamId, teamName, elo: eloRating,
      recentForm: Array(5).fill(0.5),
      homeWinRate: 0.45, awayWinRate: 0.35,
      homeGoalsScored: 1.3, awayGoalsScored: 1.0,
      homeGoalsConceded: 1.2, awayGoalsConceded: 1.3,
    };
  }

  // Calcule les stats de l'équipe à partir de ses matchs dans le H2H
  let wins = 0, draws = 0, played = 0;
  let goalsFor = 0, goalsAgainst = 0;
  let homeGames = 0, homeWins = 0, homeGoalsFor = 0, homeGoalsAgainst = 0;
  let awayGames = 0, awayWins = 0, awayGoalsFor = 0, awayGoalsAgainst = 0;
  const recentForm: number[] = [];

  const recent = h2hFixtures.slice(0, 20); // 20 derniers duels

  for (const f of recent) {
    const hGoals = f.goals.home ?? 0;
    const aGoals = f.goals.away ?? 0;
    const isHome = f.teams.home.id === teamId;

    const teamGoals = isHome ? hGoals : aGoals;
    const oppGoals = isHome ? aGoals : hGoals;

    played++;
    goalsFor += teamGoals;
    goalsAgainst += oppGoals;

    const won = teamGoals > oppGoals;
    const drew = teamGoals === oppGoals;
    if (won) wins++;
    if (drew) draws++;

    if (isHome) {
      homeGames++;
      if (won) homeWins++;
      homeGoalsFor += teamGoals;
      homeGoalsAgainst += oppGoals;
    } else {
      awayGames++;
      if (won) awayWins++;
      awayGoalsFor += teamGoals;
      awayGoalsAgainst += oppGoals;
    }

    if (recentForm.length < 5) {
      recentForm.push(won ? 1 : drew ? 0.5 : 0);
    }
  }

  while (recentForm.length < 5) recentForm.push(0.5);

  return {
    teamId,
    teamName,
    elo: eloRating,
    recentForm,
    homeWinRate: homeGames > 0 ? homeWins / homeGames : 0.45,
    awayWinRate: awayGames > 0 ? awayWins / awayGames : 0.35,
    homeGoalsScored: homeGames > 0 ? homeGoalsFor / homeGames : 1.3,
    awayGoalsScored: awayGames > 0 ? awayGoalsFor / awayGames : 1.0,
    homeGoalsConceded: homeGames > 0 ? homeGoalsAgainst / homeGames : 1.2,
    awayGoalsConceded: awayGames > 0 ? awayGoalsAgainst / awayGames : 1.3,
  };
}

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

    // 3. Récupère H2H + blessures (2 appels API — compatible Free plan)
    //    PAS de /teams/statistics (bloqué season 2025+ en Free)
    const [h2hRaw, injuriesRaw] = await apifootballSequential([
      () => apifootball("/fixtures/headtohead", {
        h2h: `${match.home_team_id}-${match.away_team_id}`,
      }),
      () => apifootball("/injuries", {
        fixture: match.external_id,
      }),
    ]);

    const h2hFixtures = (h2hRaw ?? []) as ApiH2HFixture[];

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

    // 6. Dérive les stats des équipes depuis le H2H (pas de /teams/statistics)
    const homeStats = deriveStatsFromH2H(h2hFixtures, match.home_team_id, match.home_team, homeElo);
    const awayStats = deriveStatsFromH2H(h2hFixtures, match.away_team_id, match.away_team, awayElo);
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
