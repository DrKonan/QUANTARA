// ============================================================
// QUANTARA — Edge Function : evaluate-predictions
// Déclencheur : Cron 30 min après la fin de chaque match
//               (en pratique : cron toutes les 30 min, filtre
//               les matchs terminés depuis moins de 1h)
// Rôle : Récupère les résultats finaux, évalue chaque prono,
//        met à jour is_correct, recalcule les stats globales.
// ============================================================
import { apifootball } from "../_shared/api-football.ts";
import { getSupabaseAdmin } from "../_shared/supabase.ts";
import { jsonResponse } from "../_shared/helpers.ts";

interface ApiFixtureResult {
  fixture: { id: number; status: { short: string } };
  goals: { home: number | null; away: number | null };
  score: {
    halftime: { home: number | null; away: number | null };
    fulltime: { home: number | null; away: number | null };
    extratime: { home: number | null; away: number | null };
    penalty: { home: number | null; away: number | null };
  };
  teams: {
    home: { id: number; winner: boolean | null };
    away: { id: number; winner: boolean | null };
  };
  statistics?: Array<{
    team: { id: number };
    statistics: Array<{ type: string; value: string | number | null }>;
  }>;
}

// ----------------------------------------------------------------
// Évalue si une prédiction est correcte selon le résultat réel
// ----------------------------------------------------------------
function evaluatePrediction(
  predType: string,
  prediction: string,
  result: ApiFixtureResult,
): boolean | null {
  const homeGoals = result.goals.home ?? 0;
  const awayGoals = result.goals.away ?? 0;
  const totalGoals = homeGoals + awayGoals;

  switch (predType) {
    case "result": {
      if (prediction === "home_win") return homeGoals > awayGoals;
      if (prediction === "away_win") return awayGoals > homeGoals;
      if (prediction === "draw") return homeGoals === awayGoals;
      return null;
    }
    case "btts": {
      const btts = homeGoals > 0 && awayGoals > 0;
      if (prediction === "yes") return btts;
      if (prediction === "no") return !btts;
      return null;
    }
    case "over_under": {
      const match = prediction.match(/^(over|under)_(\d+(?:\.\d+)?)$/);
      if (!match) return null;
      const direction = match[1];
      const line = parseFloat(match[2]);
      if (direction === "over") return totalGoals > line;
      if (direction === "under") return totalGoals < line;
      return null;
    }
    case "halftime": {
      const htHome = result.score.halftime.home ?? 0;
      const htAway = result.score.halftime.away ?? 0;
      if (prediction === "home_win") return htHome > htAway;
      if (prediction === "away_win") return htAway > htHome;
      if (prediction === "draw") return htHome === htAway;
      return null;
    }
    default:
      return null;
  }
}

Deno.serve(async (_req: Request) => {
  try {
    const supabase = getSupabaseAdmin();
    const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();

    // Matchs terminés avec des prédictions non encore évaluées
    // Fenêtre large de 24h pour ne rater aucun match
    const { data: matches, error: matchError } = await supabase
      .from("matches")
      .select("id, external_id, home_team, away_team, home_score, away_score")
      .eq("status", "finished")
      .gte("updated_at", twentyFourHoursAgo);

    if (matchError) throw matchError;
    if (!matches || matches.length === 0) {
      return jsonResponse({ message: "No recently finished matches to evaluate", evaluated: 0 });
    }

    console.log(`[evaluate-predictions] Evaluating ${matches.length} matches`);
    let totalEvaluated = 0;

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    for (const match of matches) {
      // Récupère le résultat final via API-Football
      const fixtureData = await apifootball("/fixtures", {
        id: match.external_id,
      }) as ApiFixtureResult[];

      if (!fixtureData || fixtureData.length === 0) continue;
      const result = fixtureData[0];

      // Backfill des scores si manquants sur la table matches
      const apiHome = result.goals.home;
      const apiAway = result.goals.away;
      if (apiHome !== null && apiAway !== null &&
          (match.home_score === null || match.away_score === null)) {
        await supabase
          .from("matches")
          .update({ home_score: apiHome, away_score: apiAway })
          .eq("id", match.id);
      }

      // Récupère les prédictions non évaluées pour ce match
      const { data: predictions } = await supabase
        .from("predictions")
        .select("id, prediction_type, prediction")
        .eq("match_id", match.id)
        .is("is_correct", null);

      if (!predictions || predictions.length === 0) continue;

      const updates: Array<{ id: number; is_correct: boolean }> = [];

      for (const pred of predictions) {
        const isCorrect = evaluatePrediction(pred.prediction_type, pred.prediction, result);
        if (isCorrect !== null) {
          updates.push({ id: pred.id, is_correct: isCorrect });
        }
      }

      // Met à jour en batch
      for (const upd of updates) {
        await supabase
          .from("predictions")
          .update({ is_correct: upd.is_correct })
          .eq("id", upd.id);
      }

      totalEvaluated += updates.length;

      // Recalcule les stats agrégées (all_time + mois courant)
      await supabase.rpc("recalculate_prediction_stats");

      // Déclenche les notifications de résultat
      fetch(`${supabaseUrl}/functions/v1/notify-users`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${serviceKey}`,
        },
        body: JSON.stringify({
          type: "prediction_results",
          match_id: match.id,
          results: updates,
        }),
      }).catch((err) => console.warn("[evaluate-predictions] notify-users trigger failed:", err));
    }

    console.log(`[evaluate-predictions] Evaluated ${totalEvaluated} predictions`);
    return jsonResponse({ success: true, matches: matches.length, predictions_evaluated: totalEvaluated });
  } catch (err) {
    console.error("[evaluate-predictions] Error:", err);
    return jsonResponse({ error: (err as Error).message }, 500);
  }
});
