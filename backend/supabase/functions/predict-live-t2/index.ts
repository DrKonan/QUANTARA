// ============================================================
// QUANTARA — Edge Function : predict-live-t2
// Déclencheur : Cron vérifiant les matchs Tier 2 autour de la
//               58ème minute (analyse unique en 2ème mi-temps).
// Rôle : Une seule analyse live par match Tier 2 — publie
//        uniquement si ≥ 75% de confiance.
// ============================================================
import { apifootball } from "../_shared/api-football.ts";
import { getSupabaseAdmin } from "../_shared/supabase.ts";
import { jsonResponse, confidenceLabel } from "../_shared/helpers.ts";
import { computeLiveScores, LiveStats } from "../_shared/live-engine.ts";
import { generateAnalysis } from "../_shared/openai.ts";

interface ApiLiveStat {
  team: { id: number };
  statistics: Array<{ type: string; value: string | number | null }>;
}

function extractStat(stats: Array<{ type: string; value: string | number | null }>, type: string): number {
  const item = stats.find((s) => s.type === type);
  if (!item || item.value === null) return 0;
  return parseFloat(String(item.value).replace("%", "")) || 0;
}

Deno.serve(async (_req: Request) => {
  try {
    const supabase = getSupabaseAdmin();

    // Récupère les matchs Tier 2 en cours, pas encore analysés en live
    // (on vérifie l'absence de prédiction live pour ce match)
    const { data: liveMatches, error } = await supabase
      .from("matches")
      .select("id, external_id, home_team, away_team, home_team_id, away_team_id, league, match_date")
      .eq("status", "live")
      .eq("tier", 2);

    if (error) throw error;
    if (!liveMatches || liveMatches.length === 0) {
      return jsonResponse({ message: "No live Tier 2 matches", processed: 0 });
    }

    // Filtre : uniquement les matchs qui n'ont pas encore de prédiction live
    const matchIds = liveMatches.map((m: { id: number }) => m.id);
    const { data: alreadyAnalyzed } = await supabase
      .from("predictions")
      .select("match_id")
      .in("match_id", matchIds)
      .eq("is_live", true);

    const alreadyAnalyzedIds = new Set((alreadyAnalyzed ?? []).map((r: { match_id: number }) => r.match_id));
    const toAnalyze = liveMatches.filter((m: { id: number }) => !alreadyAnalyzedIds.has(m.id));

    if (toAnalyze.length === 0) {
      return jsonResponse({ message: "All Tier 2 matches already analyzed", processed: 0 });
    }

    console.log(`[predict-live-t2] Analyzing ${toAnalyze.length} Tier 2 matches`);
    let totalPublished = 0;

    for (const match of toAnalyze) {
      try {
        const [liveData, fixtureData] = await Promise.all([
          apifootball("/fixtures/statistics", { fixture: match.external_id }) as Promise<ApiLiveStat[]>,
          apifootball("/fixtures", { id: match.external_id }) as Promise<Array<{
            fixture: { status: { elapsed: number } };
            goals: { home: number | null; away: number | null };
          }>>,
        ]);

        const currentMinute = fixtureData?.[0]?.fixture?.status?.elapsed ?? 60;

        // Tier 2 : n'analyse qu'autour de la 58ème minute (55–65)
        if (currentMinute < 55 || currentMinute > 65) {
          console.log(`[predict-live-t2] Match ${match.id} at minute ${currentMinute}, skipping (not in 55-65 window)`);
          continue;
        }

        const homeScore = fixtureData?.[0]?.goals?.home ?? 0;
        const awayScore = fixtureData?.[0]?.goals?.away ?? 0;

        if (!liveData || liveData.length === 0) continue;

        const homeStats = (liveData as ApiLiveStat[]).find((s) => s.team.id === match.home_team_id)?.statistics ?? [];
        const awayStats = (liveData as ApiLiveStat[]).find((s) => s.team.id === match.away_team_id)?.statistics ?? [];

        const liveStats: LiveStats = {
          minute: currentMinute,
          homeScore,
          awayScore,
          homePossession: extractStat(homeStats, "Ball Possession"),
          homeShots: extractStat(homeStats, "Total Shots"),
          homeShotsOnTarget: extractStat(homeStats, "Shots on Goal"),
          awayShots: extractStat(awayStats, "Total Shots"),
          awayShotsOnTarget: extractStat(awayStats, "Shots on Goal"),
          homeCorners: extractStat(homeStats, "Corner Kicks"),
          awayCorners: extractStat(awayStats, "Corner Kicks"),
          homeYellowCards: extractStat(homeStats, "Yellow Cards"),
          awayYellowCards: extractStat(awayStats, "Yellow Cards"),
          homeRedCards: extractStat(homeStats, "Red Cards"),
          awayRedCards: extractStat(awayStats, "Red Cards"),
        };

        const scoringResults = computeLiveScores(liveStats, { home: 1.2, away: 1.0 });

        for (const result of scoringResults) {
          const analysisText = await generateAnalysis({
            homeTeam: match.home_team,
            awayTeam: match.away_team,
            league: match.league,
            matchDate: match.match_date,
            predictionType: result.prediction_type,
            prediction: result.prediction,
            confidence: result.confidence,
            scoreBreakdown: result.score_breakdown,
            lang: "fr",
          });

          await supabase.from("predictions").insert({
            match_id: match.id,
            prediction_type: result.prediction_type,
            prediction: result.prediction,
            confidence: result.confidence,
            confidence_label: confidenceLabel(result.confidence),
            is_premium: true,
            is_live: true,
            analysis_text: analysisText,
            score_breakdown: result.score_breakdown,
            is_correct: null,
            is_published: true,
          });

          totalPublished++;
        }
      } catch (matchErr) {
        console.warn(`[predict-live-t2] Error for match ${match.id}:`, matchErr);
      }
    }

    return jsonResponse({ success: true, analyzed: toAnalyze.length, published: totalPublished });
  } catch (err) {
    console.error("[predict-live-t2] Error:", err);
    return jsonResponse({ error: (err as Error).message }, 500);
  }
});
