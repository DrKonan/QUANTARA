// ============================================================
// QUANTARA — Edge Function : predict-live-t1
// Déclencheur : Cron toutes les 15 minutes (matchs Tier 1 en cours)
// Rôle : Analyse live pour les grandes ligues (Tier 1).
//        Récupère les stats live API-Football, recalcule les
//        scores et publie les pronos pertinents (≥ 75%).
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
  const val = String(item.value).replace("%", "");
  return parseFloat(val) || 0;
}

function parseApiStats(
  apiStats: ApiLiveStat[],
  homeTeamId: number,
  awayTeamId: number,
  minute: number,
  homeScore: number,
  awayScore: number,
): LiveStats {
  const homeStats = apiStats.find((s) => s.team.id === homeTeamId)?.statistics ?? [];
  const awayStats = apiStats.find((s) => s.team.id === awayTeamId)?.statistics ?? [];

  return {
    minute,
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
}

Deno.serve(async (_req: Request) => {
  try {
    const supabase = getSupabaseAdmin();

    // Récupère tous les matchs Tier 1 actuellement en cours
    const { data: liveMatches, error } = await supabase
      .from("matches")
      .select("id, external_id, home_team, away_team, home_team_id, away_team_id, league, match_date, home_score, away_score")
      .eq("status", "live")
      .eq("tier", 1);

    if (error) throw error;
    if (!liveMatches || liveMatches.length === 0) {
      return jsonResponse({ message: "No live Tier 1 matches", processed: 0 });
    }

    console.log(`[predict-live-t1] Processing ${liveMatches.length} live Tier 1 matches`);
    let totalPublished = 0;

    for (const match of liveMatches) {
      try {
        // Récupère les stats live depuis API-Football
        const liveData = await apifootball("/fixtures/statistics", {
          fixture: match.external_id,
        }) as ApiLiveStat[];

        // Récupère aussi le fixture pour la minute actuelle
        const fixtureData = await apifootball("/fixtures", {
          id: match.external_id,
        }) as Array<{
          fixture: { status: { elapsed: number } };
          goals: { home: number | null; away: number | null };
        }>;

        const currentMinute = fixtureData?.[0]?.fixture?.status?.elapsed ?? 45;
        const homeScore = fixtureData?.[0]?.goals?.home ?? match.home_score ?? 0;
        const awayScore = fixtureData?.[0]?.goals?.away ?? match.away_score ?? 0;

        if (!liveData || liveData.length === 0) continue;

        const liveStats = parseApiStats(
          liveData,
          match.home_team_id,
          match.away_team_id,
          currentMinute,
          homeScore,
          awayScore,
        );

        // XG pré-match : cherche les prédictions pré-match pour estimer les xG
        const { data: prematchPreds } = await supabase
          .from("predictions")
          .select("prediction, confidence, prediction_type, score_breakdown")
          .eq("match_id", match.id)
          .eq("is_live", false)
          .in("prediction_type", ["over_under", "result"]);

        // Estime xG depuis les predictions pré-match ou utilise les moyennes par défaut
        let homeXG = 1.3, awayXG = 1.1;
        if (prematchPreds && prematchPreds.length > 0) {
          const overPred = prematchPreds.find((p: { prediction: string }) => p.prediction === "over_2.5");
          if (overPred && overPred.confidence > 0.6) {
            homeXG = 1.5; awayXG = 1.3;
          }
          const underPred = prematchPreds.find((p: { prediction: string }) => p.prediction === "under_2.5");
          if (underPred && underPred.confidence > 0.6) {
            homeXG = 0.9; awayXG = 0.8;
          }
        }
        const prematchXG = { home: homeXG, away: awayXG };

        const scoringResults = computeLiveScores(liveStats, prematchXG);

        for (const result of scoringResults) {
          // Déduplication : vérifie si ce prono (même type + même prédiction) existe déjà
          const { count: dupCount } = await supabase
            .from("predictions")
            .select("id", { count: "exact", head: true })
            .eq("match_id", match.id)
            .eq("prediction_type", result.prediction_type)
            .eq("prediction", result.prediction);

          if (dupCount && dupCount > 0) {
            // Met à jour le score de confiance au lieu de créer un doublon
            await supabase
              .from("predictions")
              .update({
                confidence: result.confidence,
                confidence_label: confidenceLabel(result.confidence),
                score_breakdown: result.score_breakdown,
                is_top_pick: result.is_top_pick ?? false,
              })
              .eq("match_id", match.id)
              .eq("prediction_type", result.prediction_type)
              .eq("prediction", result.prediction);
            continue;
          }

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
            is_top_pick: result.is_top_pick ?? false,
          });

          totalPublished++;
        }
      } catch (matchErr) {
        console.warn(`[predict-live-t1] Error for match ${match.id}:`, matchErr);
      }
    }

    console.log(`[predict-live-t1] Published ${totalPublished} new live predictions`);

    // Déclenche les notifications push pour chaque match ayant de nouveaux pronos LIVE
    if (totalPublished > 0) {
      const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
      const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
      for (const match of liveMatches) {
        fetch(`${supabaseUrl}/functions/v1/notify-users`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${serviceKey}`,
          },
          body: JSON.stringify({
            type: "live_prediction",
            match_id: match.id,
            count: totalPublished,
          }),
        }).catch((err) => console.warn("[predict-live-t1] notify-users failed:", err));
      }
    }

    return jsonResponse({ success: true, matches_processed: liveMatches.length, published: totalPublished });
  } catch (err) {
    console.error("[predict-live-t1] Error:", err);
    return jsonResponse({ error: (err as Error).message }, 500);
  }
});
