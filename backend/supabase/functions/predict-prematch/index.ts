// ============================================================
// QUANTARA — Edge Function : predict-prematch
// Déclencheur : appelée par fetch-lineups dès qu'un match a
//               ses compositions officielles.
// Body attendu : { match_id: number }
// Rôle : Collecte toutes les données, calcule les scores de
//        confiance et publie les pronos pré-match en base.
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
// Helpers de transformation des données API-Football
// ----------------------------------------------------------------
function extractRecentForm(fixtures: ApiTeamFixture[]): number[] {
  return fixtures
    .slice(0, 5)
    .map((f) => {
      if (f.teams.home.winner === true || f.teams.away.winner === true) {
        // On détermine si c'est notre équipe qui a gagné
        return f.teams.home.winner ? 1 : 0;
      }
      return 0.5; // nul
    });
}

interface ApiTeamFixture {
  teams: {
    home: { id: number; winner: boolean | null };
    away: { id: number; winner: boolean | null };
  };
  goals: { home: number | null; away: number | null };
}

interface ApiTeamStats {
  form: string;
  fixtures: {
    wins: { home: number; away: number; total: number };
    draws: { home: number; away: number; total: number };
    loses: { home: number; away: number; total: number };
    played: { home: number; away: number; total: number };
  };
  goals: {
    for: { average: { home: string; away: string } };
    against: { average: { home: string; away: string } };
  };
}

function parseTeamStats(
  raw: ApiTeamStats,
  eloRating: number,
  teamId: number,
  teamName: string,
): TeamStats {
  const playedHome = raw.fixtures.played.home || 1;
  const playedAway = raw.fixtures.played.away || 1;

  return {
    teamId,
    teamName,
    recentForm: raw.form
      ? raw.form.slice(-5).split("").map((c) => c === "W" ? 1 : c === "D" ? 0.5 : 0)
      : Array(5).fill(0.5),
    homeWinRate: raw.fixtures.wins.home / playedHome,
    awayWinRate: raw.fixtures.wins.away / playedAway,
    homeGoalsScored: parseFloat(raw.goals.for.average.home) || 1.2,
    awayGoalsScored: parseFloat(raw.goals.for.average.away) || 1.0,
    homeGoalsConceded: parseFloat(raw.goals.against.average.home) || 1.2,
    awayGoalsConceded: parseFloat(raw.goals.against.average.away) || 1.0,
    elo: eloRating,
  };
}

interface ApiH2H {
  teams: {
    home: { id: number };
    away: { id: number };
  };
  goals: { home: number | null; away: number | null };
  teams_result?: { home: { winner: boolean | null }; away: { winner: boolean | null } };
}

function parseH2HContext(
  h2hFixtures: ApiH2H[],
  homeTeamId: number,
  isHighStakes: boolean,
  keyInjuries: number,
): MatchContext {
  if (!h2hFixtures || h2hFixtures.length === 0) {
    return {
      isHighStakes,
      keyInjuries,
      h2hHomeWins: 0,
      h2hDraws: 0,
      h2hAwayWins: 0,
      h2hTotal: 0,
      h2hHomeGoalsAvg: 0,
      h2hAwayGoalsAvg: 0,
    };
  }

  let homeWins = 0, draws = 0, awayWins = 0;
  let totalHomeGoals = 0, totalAwayGoals = 0;
  const recent = h2hFixtures.slice(0, 10);

  for (const f of recent) {
    const hGoals = f.goals.home ?? 0;
    const aGoals = f.goals.away ?? 0;

    // Normalise "domicile" par rapport à homeTeamId
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
    isHighStakes,
    keyInjuries,
    h2hHomeWins: homeWins,
    h2hDraws: draws,
    h2hAwayWins: awayWins,
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

    const currentYear = new Date().getFullYear();

    // 3. Récupère les stats des équipes et le H2H séquentiellement (rate limit)
    const [homeStatsRaw, awayStatsRaw, h2hRaw, injuriesRaw] = await apifootballSequential([
      () => apifootball("/teams/statistics", {
        team: match.home_team_id,
        league: match.league_id,
        season: match.season ?? currentYear,
      }),
      () => apifootball("/teams/statistics", {
        team: match.away_team_id,
        league: match.league_id,
        season: match.season ?? currentYear,
      }),
      () => apifootball("/fixtures/headtohead", {
        h2h: `${match.home_team_id}-${match.away_team_id}`,
        last: 10,
      }),
      () => apifootball("/injuries", {
        fixture: match.external_id,
      }),
    ]);

    // 4. Récupère les ELO depuis la base (ou utilise 1500 par défaut)
    const { data: eloRows } = await supabase
      .from("team_elo")
      .select("team_id, elo")
      .in("team_id", [match.home_team_id, match.away_team_id]);

    const eloMap = new Map((eloRows ?? []).map((r: { team_id: number; elo: number }) => [r.team_id, r.elo]));
    const homeElo = eloMap.get(match.home_team_id) ?? 1500;
    const awayElo = eloMap.get(match.away_team_id) ?? 1500;

    // 5. Compte les blessures clés (simplification : tous les blessés comptent)
    const keyInjuries = Array.isArray(injuriesRaw) ? (injuriesRaw as unknown[]).length : 0;

    // 6. Construit les objets TeamStats et MatchContext
    const homeStats = parseTeamStats(
      homeStatsRaw as ApiTeamStats,
      homeElo,
      match.home_team_id,
      match.home_team,
    );
    const awayStats = parseTeamStats(
      awayStatsRaw as ApiTeamStats,
      awayElo,
      match.away_team_id,
      match.away_team,
    );
    const matchCtx = parseH2HContext(
      h2hRaw as ApiH2H[],
      match.home_team_id,
      false,  // TODO: détecter automatiquement les matchs à enjeu
      keyInjuries,
    );

    // 7. Lance le moteur de scoring
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
    const PREMIUM_THRESHOLD = 0.75;

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
