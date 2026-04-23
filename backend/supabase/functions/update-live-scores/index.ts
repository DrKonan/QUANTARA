// ============================================================
// NAKORA — Edge Function : update-live-scores
// Déclencheur : Cron toutes les 30 minutes
// Rôle : Suivi léger des transitions de statut (pas du live).
//        NAKORA n'est PAS une app de scores en direct.
//        On suit juste : scheduled → live → finished pour savoir
//        quand déclencher predict-live et evaluate-predictions.
//        Si aucun match actif en DB → 0 appel API.
// ============================================================
import { apifootball } from "../_shared/api-football.ts";
import { getSupabaseAdmin } from "../_shared/supabase.ts";
import { jsonResponse, mapFixtureStatus } from "../_shared/helpers.ts";

interface ApiFixture {
  fixture: {
    id: number;
    status: { short: string; elapsed: number | null };
  };
  league: { id: number };
  goals: {
    home: number | null;
    away: number | null;
  };
}

Deno.serve(async (_req: Request) => {
  try {
    const supabase = getSupabaseAdmin();
    const now = new Date();

    // 1. Vérifie d'abord en DB s'il y a des matchs à surveiller
    //    (scheduled proches du kick-off OU déjà live)
    //    → Si aucun, on économise l'appel API.
    const threeHoursAgo = new Date(now.getTime() - 3 * 60 * 60 * 1000).toISOString();
    const { data: ourMatches, error: dbError } = await supabase
      .from("matches")
      .select("id, external_id, status, match_date")
      .in("status", ["scheduled", "live"])
      .gte("match_date", threeHoursAgo);

    if (dbError) throw dbError;
    if (!ourMatches || ourMatches.length === 0) {
      return jsonResponse({ message: "No active matches to track", apiCalls: 0 });
    }

    // Filtre : ne garder que les matchs scheduled dont le kick-off
    // est dans moins de 45 min (ou dépassé) + tous les matchs "live"
    const relevantMatches = ourMatches.filter((m) => {
      if (m.status === "live") return true;
      // scheduled : kick-off prévu - vérifier s'il est proche ou dépassé
      const kickoff = new Date(m.match_date);
      const minutesUntilKickoff = (kickoff.getTime() - now.getTime()) / 60000;
      return minutesUntilKickoff <= 45; // kick-off dans moins de 45 min ou déjà passé
    });

    if (relevantMatches.length === 0) {
      return jsonResponse({ message: "No matches near kick-off or live", apiCalls: 0 });
    }

    // 2. UN seul appel API : récupère tous les matchs live dans le monde
    const liveFixtures = await apifootball("/fixtures", {
      live: "all",
    }) as ApiFixture[];

    const liveMap = new Map<string, ApiFixture>();
    if (liveFixtures && liveFixtures.length > 0) {
      for (const fix of liveFixtures) {
        liveMap.set(String(fix.fixture.id), fix);
      }
    }

    // 3. Met à jour les transitions de statut
    let updatedCount = 0;

    for (const match of relevantMatches) {
      const liveFix = liveMap.get(match.external_id);

      if (liveFix) {
        // Match trouvé dans le flux live → mettre à jour statut + score
        const newStatus = mapFixtureStatus(liveFix.fixture.status.short);
        const { error } = await supabase
          .from("matches")
          .update({
            status: newStatus,
            home_score: liveFix.goals.home,
            away_score: liveFix.goals.away,
          })
          .eq("id", match.id);

        if (!error) updatedCount++;
      } else if (match.status === "live") {
        // Était "live" mais n'apparaît plus → très probablement terminé
        const kickoff = new Date(match.match_date);
        const minutesSinceKickoff = (now.getTime() - kickoff.getTime()) / 60000;

        if (minutesSinceKickoff > 100) {
          // Récupère le score final via API-Football avant de marquer "finished"
          try {
            const fixtureData = await apifootball("/fixtures", {
              id: match.external_id,
            }) as ApiFixture[];
            const fix = fixtureData?.[0];
            const finalHome = fix?.goals?.home ?? null;
            const finalAway = fix?.goals?.away ?? null;
            const { error } = await supabase
              .from("matches")
              .update({
                status: "finished",
                home_score: finalHome,
                away_score: finalAway,
              })
              .eq("id", match.id);
            if (!error) updatedCount++;
            console.log(`[update-live-scores] ${match.external_id} finished: ${finalHome}-${finalAway}`);
          } catch (fetchErr) {
            // Fallback : marquer finished sans score, evaluate-predictions récupérera
            console.warn(`[update-live-scores] Could not fetch final score for ${match.external_id}:`, fetchErr);
            const { error } = await supabase
              .from("matches")
              .update({ status: "finished" })
              .eq("id", match.id);
            if (!error) updatedCount++;
          }
        }
      }
      // scheduled + kick-off passé mais pas dans live → on attend
      // le prochain cycle (30 min), pas de panique, c'est normal
      // que le match mette quelques minutes à apparaître
    }

    console.log(`[update-live-scores] Relevant: ${relevantMatches.length}, updated: ${updatedCount}, API live worldwide: ${liveMap.size}`);
    return jsonResponse({
      success: true,
      relevant: relevantMatches.length,
      updated: updatedCount,
      apiCalls: 1,
    });
  } catch (err) {
    console.error("[update-live-scores] Error:", err);
    return jsonResponse({ error: (err as Error).message }, 500);
  }
});
