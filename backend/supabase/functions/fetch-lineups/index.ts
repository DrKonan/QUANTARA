// ============================================================
// QUANTARA — Edge Function : fetch-lineups
// Déclencheur : Cron toutes les 10 min
// Rôle : Vérifie UNIQUEMENT les matchs dont le kick-off est
//        dans les 90 prochaines minutes (les compos officielles
//        sont généralement publiées 1h–1h30 avant le match).
//        Met à jour lineups_ready puis déclenche predict-prematch.
//        Les matchs plus lointains ne sont PAS interrogés pour
//        économiser les appels API-Football.
// ============================================================
import { apifootball } from "../_shared/api-football.ts";
import { getSupabaseAdmin } from "../_shared/supabase.ts";
import { jsonResponse, todayUTC } from "../_shared/helpers.ts";

interface ApiLineup {
  team: { id: number; name: string };
  startXI: unknown[];
}

Deno.serve(async (_req: Request) => {
  try {
    const supabase = getSupabaseAdmin();
    const today = todayUTC();
    const now = new Date();

    // Fenêtre ciblée : matchs dont le kick-off est entre maintenant
    // et dans 90 minutes. Les compos sont rarement dispo plus tôt.
    const ninetyMinFromNow = new Date(now.getTime() + 90 * 60 * 1000).toISOString();

    const { data: matches, error: fetchError } = await supabase
      .from("matches")
      .select("id, external_id, home_team, away_team, match_date")
      .eq("status", "scheduled")
      .eq("lineups_ready", false)
      .gte("match_date", now.toISOString())
      .lte("match_date", ninetyMinFromNow);

    if (fetchError) throw fetchError;
    if (!matches || matches.length === 0) {
      return jsonResponse({ message: "No upcoming matches pending lineups", checked: 0 });
    }

    console.log(`[fetch-lineups] Checking ${matches.length} matches for lineup availability`);

    const ready: number[] = [];

    for (const match of matches) {
      try {
        const lineups = await apifootball("/fixtures/lineups", {
          fixture: match.external_id,
        }) as ApiLineup[];

        // Les compos sont disponibles quand les deux équipes ont au moins 11 joueurs
        const hasLineups =
          Array.isArray(lineups) &&
          lineups.length === 2 &&
          lineups[0].startXI?.length >= 11 &&
          lineups[1].startXI?.length >= 11;

        if (hasLineups) {
          ready.push(match.id);
        }
      } catch (err) {
        // On ne bloque pas la boucle si une fixture échoue
        console.warn(`[fetch-lineups] Skipping fixture ${match.external_id}:`, err);
      }
    }

    if (ready.length === 0) {
      return jsonResponse({ message: "No new lineups available yet", checked: matches.length, ready: 0 });
    }

    // Marque les matchs comme lineups_ready
    const { error: updateError } = await supabase
      .from("matches")
      .update({ lineups_ready: true })
      .in("id", ready);

    if (updateError) throw updateError;

    console.log(`[fetch-lineups] Marked ${ready.length} matches as lineups_ready`);

    // Déclenche predict-prematch pour chaque match prêt
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const invokeResults = await Promise.allSettled(
      ready.map((matchId) =>
        fetch(`${supabaseUrl}/functions/v1/predict-prematch`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${serviceKey}`,
          },
          body: JSON.stringify({ match_id: matchId }),
        })
      ),
    );

    const triggered = invokeResults.filter((r) => r.status === "fulfilled").length;
    console.log(`[fetch-lineups] Triggered predict-prematch for ${triggered}/${ready.length} matches`);

    return jsonResponse({
      success: true,
      checked: matches.length,
      ready: ready.length,
      triggered,
    });
  } catch (err) {
    console.error("[fetch-lineups] Error:", err);
    return jsonResponse({ error: (err as Error).message }, 500);
  }
});
