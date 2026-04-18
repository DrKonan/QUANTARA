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
// Extrait une stat numérique depuis les statistics API-Football
// ----------------------------------------------------------------
function getStatValue(
  stats: ApiFixtureResult["statistics"],
  statType: string,
): { home: number; away: number } | null {
  if (!stats || stats.length < 2) return null;
  const findVal = (teamStats: typeof stats[0]) => {
    const s = teamStats.statistics.find(
      (st) => st.type.toLowerCase().replace(/\s+/g, "_") === statType ||
              st.type.toLowerCase() === statType.replace(/_/g, " "),
    );
    if (!s || s.value === null) return null;
    return typeof s.value === "number" ? s.value : parseInt(String(s.value), 10) || 0;
  };
  const homeVal = findVal(stats[0]);
  const awayVal = findVal(stats[1]);
  if (homeVal === null || awayVal === null) return null;
  return { home: homeVal, away: awayVal };
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
    case "double_chance": {
      const homeWin = homeGoals > awayGoals;
      const isDraw = homeGoals === awayGoals;
      const awayWin = awayGoals > homeGoals;
      if (prediction === "1X") return homeWin || isDraw;
      if (prediction === "X2") return awayWin || isDraw;
      if (prediction === "12") return homeWin || awayWin;  // = pas de nul
      return null;
    }
    case "corners": {
      const cornerStats = getStatValue(result.statistics, "corner_kicks");
      if (!cornerStats) return null;  // pas de stats dispo → on ne peut pas évaluer
      const totalCorners = cornerStats.home + cornerStats.away;
      const match = prediction.match(/^(over|under)_(\d+(?:\.\d+)?)$/);
      if (!match) return null;
      const direction = match[1];
      const line = parseFloat(match[2]);
      if (direction === "over") return totalCorners > line;
      if (direction === "under") return totalCorners < line;
      return null;
    }
    case "cards": {
      // Cartons jaunes + rouges (un rouge = un carton dans le décompte)
      const yellowStats = getStatValue(result.statistics, "yellow_cards");
      const redStats = getStatValue(result.statistics, "red_cards");
      if (!yellowStats) return null;  // pas de stats dispo
      const totalCards = yellowStats.home + yellowStats.away +
        (redStats ? redStats.home + redStats.away : 0);
      const match = prediction.match(/^(over|under)_(\d+(?:\.\d+)?)$/);
      if (!match) return null;
      const direction = match[1];
      const line = parseFloat(match[2]);
      if (direction === "over") return totalCards > line;
      if (direction === "under") return totalCards < line;
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

      // Récupère les statistiques du match (corners, cartons…)
      // L'endpoint /fixtures ne renvoie pas toujours les stats, on doit utiliser /fixtures/statistics
      if (!result.statistics || result.statistics.length === 0) {
        try {
          const statsData = await apifootball("/fixtures/statistics", {
            fixture: match.external_id,
          }) as Array<{
            team: { id: number };
            statistics: Array<{ type: string; value: string | number | null }>;
          }>;
          if (statsData && statsData.length >= 2) {
            result.statistics = statsData;
          }
        } catch (e) {
          console.warn(`[evaluate-predictions] Could not fetch statistics for fixture ${match.external_id}:`, e);
        }
      }

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

      // V1.1 — Mise à jour dynamique de l'ELO après chaque match
      try {
        const { data: eloRows } = await supabase
          .from("team_elo")
          .select("team_id, elo")
          .in("team_id", [result.teams.home.id, result.teams.away.id]);

        if (eloRows && eloRows.length === 2) {
          const homeEloRow = eloRows.find((r: { team_id: number }) => r.team_id === result.teams.home.id);
          const awayEloRow = eloRows.find((r: { team_id: number }) => r.team_id === result.teams.away.id);
          if (homeEloRow && awayEloRow) {
            const K = 32;
            const homeElo = homeEloRow.elo;
            const awayElo = awayEloRow.elo;
            const expectedHome = 1 / (1 + Math.pow(10, (awayElo - homeElo) / 400));
            const expectedAway = 1 - expectedHome;

            // Résultat réel : 1 = victoire, 0.5 = nul, 0 = défaite
            const homeGoals = result.goals.home ?? 0;
            const awayGoals = result.goals.away ?? 0;
            const actualHome = homeGoals > awayGoals ? 1 : homeGoals === awayGoals ? 0.5 : 0;
            const actualAway = 1 - actualHome;

            const newHomeElo = Math.round(homeElo + K * (actualHome - expectedHome));
            const newAwayElo = Math.round(awayElo + K * (actualAway - expectedAway));

            await supabase.from("team_elo").update({ elo: newHomeElo }).eq("team_id", result.teams.home.id);
            await supabase.from("team_elo").update({ elo: newAwayElo }).eq("team_id", result.teams.away.id);
            console.log(`[evaluate-predictions] ELO updated: ${result.teams.home.id} ${homeElo}→${newHomeElo}, ${result.teams.away.id} ${awayElo}→${newAwayElo}`);
          }
        }
      } catch (eloErr) {
        console.warn(`[evaluate-predictions] ELO update failed:`, eloErr);
      }

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

    // ── Évaluation des combinés ────────────────────────────────
    try {
      const today = new Date().toISOString().slice(0, 10);
      const { data: activeCombos } = await supabase
        .from("combo_predictions")
        .select("id, legs, status")
        .eq("status", "active")
        .lte("combo_date", today);

      for (const combo of (activeCombos ?? []) as Array<{ id: number; legs: Array<{ prediction_id: number }>; status: string }>) {
        // Récupère l'état actuel de chaque jambe
        const legPredIds = combo.legs.map(l => l.prediction_id);
        const { data: legPreds } = await supabase
          .from("predictions")
          .select("id, is_correct")
          .in("id", legPredIds);

        if (!legPreds || legPreds.length !== legPredIds.length) continue;

        const results = legPreds as Array<{ id: number; is_correct: boolean | null }>;
        const allResolved = results.every(r => r.is_correct !== null);
        if (!allResolved) continue; // pas encore tous les matchs terminés

        const allCorrect = results.every(r => r.is_correct === true);
        const anyCorrect = results.some(r => r.is_correct === true);
        const comboStatus = allCorrect ? "won" : (anyCorrect ? "partial" : "lost");

        const resultDetail = results.map(r => ({
          prediction_id: r.id,
          is_correct: r.is_correct,
        }));

        await supabase
          .from("combo_predictions")
          .update({
            status: comboStatus,
            result_detail: resultDetail,
            updated_at: new Date().toISOString(),
          })
          .eq("id", combo.id);

        console.log(`[evaluate-predictions] Combo #${combo.id} → ${comboStatus}`);
      }
    } catch (comboErr) {
      console.warn("[evaluate-predictions] Combo evaluation failed:", comboErr);
    }

    return jsonResponse({ success: true, matches: matches.length, predictions_evaluated: totalEvaluated });
  } catch (err) {
    console.error("[evaluate-predictions] Error:", err);
    return jsonResponse({ error: (err as Error).message }, 500);
  }
});
