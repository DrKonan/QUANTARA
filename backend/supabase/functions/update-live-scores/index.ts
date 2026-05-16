// ============================================================
// NAKORA — Edge Function : update-live-scores
// Déclencheur : Cron toutes les 5 minutes
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

    // ──────────────────────────────────────────────────────────────
    // PHASE 1 — Nettoyage préventif des matchs "scheduled" bloqués
    //
    // Un match encore "scheduled" 130 min après son kick-off n'a
    // jamais été capturé comme "live" (ligue non couverte par le
    // flux live API, match annulé, etc.).
    // 130 min = 90 min match + 35 min arrêts + marge → match fini.
    //
    // • Matchs > 6h après ko → bulk-finish sans appel API (clairement finis).
    // • Matchs entre 130 min et 6h → jusqu'à 3 appels API pour le score final.
    // ──────────────────────────────────────────────────────────────
    const twoHoursAndTenAgo = new Date(now.getTime() - 130 * 60 * 1000).toISOString();
    const sixHoursAgo = new Date(now.getTime() - 6 * 60 * 60 * 1000).toISOString();

    const { data: staleScheduled } = await supabase
      .from("matches")
      .select("id, external_id, match_date")
      .eq("status", "scheduled")
      .lt("match_date", twoHoursAndTenAgo);

    let cleanedCount = 0;
    let recentApiCalls = 0;

    if (staleScheduled && staleScheduled.length > 0) {
      // Ancien (> 6h) : bulk-finish direct, pas d'appel API
      const old = staleScheduled.filter((m) => m.match_date < sixHoursAgo);
      if (old.length > 0) {
        const { error } = await supabase
          .from("matches")
          .update({ status: "finished" })
          .in("id", old.map((m) => m.id));
        if (!error) {
          cleanedCount += old.length;
          console.log(`[update-live-scores] Bulk-finished ${old.length} very old stale-scheduled matches`);
        }
      }

      // Récent (130 min – 6h) : essaie de récupérer le score final (max 3 appels)
      const recent = staleScheduled
        .filter((m) => m.match_date >= sixHoursAgo)
        .slice(0, 3);

      for (const match of recent) {
        try {
          const fixtureData = await apifootball("/fixtures", {
            id: match.external_id,
          }) as ApiFixture[];
          const fix = fixtureData?.[0];
          if (fix) {
            const apiStatus = mapFixtureStatus(fix.fixture.status.short);
            // Si l'API dit encore "scheduled" → le match n'a pas eu lieu, on le finit quand même
            const finalStatus = apiStatus === "scheduled" ? "finished" : apiStatus;
            await supabase.from("matches").update({
              status: finalStatus,
              home_score: fix.goals.home ?? null,
              away_score: fix.goals.away ?? null,
            }).eq("id", match.id);
          } else {
            await supabase.from("matches").update({ status: "finished" }).eq("id", match.id);
          }
          cleanedCount++;
        } catch (fetchErr) {
          console.warn(`[update-live-scores] Could not fetch stale match ${match.external_id}:`, fetchErr);
          await supabase.from("matches").update({ status: "finished" }).eq("id", match.id);
          cleanedCount++;
        }
      }
      recentApiCalls = recent.length;

      if (cleanedCount > 0) {
        console.log(`[update-live-scores] Phase1 cleanup: ${cleanedCount} stale-scheduled matches finished`);
      }
    }

    // ──────────────────────────────────────────────────────────────
    // PHASE 2 — Transitions scheduled → live → finished
    //
    // • Live matches : TOUJOURS inclus (pas de filtre date) pour ne
    //   jamais rater un match bloqué en "live" depuis des jours.
    // • Scheduled : seulement ceux proches du kick-off (≤ 45 min).
    // ──────────────────────────────────────────────────────────────
    const threeHoursAgo = new Date(now.getTime() - 3 * 60 * 60 * 1000).toISOString();

    const [{ data: liveMatches, error: liveErr }, { data: scheduledMatches, error: schedErr }] =
      await Promise.all([
        supabase
          .from("matches")
          .select("id, external_id, status, match_date")
          .eq("status", "live"),
        supabase
          .from("matches")
          .select("id, external_id, status, match_date")
          .eq("status", "scheduled")
          .gte("match_date", threeHoursAgo),
      ]);

    if (liveErr) throw liveErr;
    if (schedErr) throw schedErr;

    const ourMatches = [...(liveMatches ?? []), ...(scheduledMatches ?? [])];

    if (ourMatches.length === 0) {
      return jsonResponse({ message: "No active matches to track", cleaned: cleanedCount, apiCalls: 0 });
    }

    // Filtre : live toujours inclus + scheduled dans les 45 min avant/après ko
    const relevantMatches = ourMatches.filter((m) => {
      if (m.status === "live") return true;
      const kickoff = new Date(m.match_date);
      const minutesUntilKickoff = (kickoff.getTime() - now.getTime()) / 60000;
      return minutesUntilKickoff <= 45;
    });

    if (relevantMatches.length === 0) {
      return jsonResponse({ message: "No matches near kick-off or live", cleaned: cleanedCount, apiCalls: 0 });
    }

    // UN seul appel API : tous les matchs live dans le monde
    const liveFixtures = await apifootball("/fixtures", {
      live: "all",
    }) as ApiFixture[];

    const liveMap = new Map<string, ApiFixture>();
    if (liveFixtures && liveFixtures.length > 0) {
      for (const fix of liveFixtures) {
        liveMap.set(String(fix.fixture.id), fix);
      }
    }

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
          try {
            const fixtureData = await apifootball("/fixtures", {
              id: match.external_id,
            }) as ApiFixture[];
            const fix = fixtureData?.[0];
            const { error } = await supabase
              .from("matches")
              .update({
                status: "finished",
                home_score: fix?.goals?.home ?? null,
                away_score: fix?.goals?.away ?? null,
              })
              .eq("id", match.id);
            if (!error) updatedCount++;
            console.log(`[update-live-scores] ${match.external_id} finished: ${fix?.goals?.home}-${fix?.goals?.away}`);
          } catch (fetchErr) {
            console.warn(`[update-live-scores] Could not fetch final score for ${match.external_id}:`, fetchErr);
            const { error } = await supabase
              .from("matches")
              .update({ status: "finished" })
              .eq("id", match.id);
            if (!error) updatedCount++;
          }
        }
      }
    }

    console.log(`[update-live-scores] Phase1 cleaned: ${cleanedCount} | Phase2 relevant: ${relevantMatches.length}, updated: ${updatedCount}, API live: ${liveMap.size}`);
    return jsonResponse({
      success: true,
      cleaned: cleanedCount,
      relevant: relevantMatches.length,
      updated: updatedCount,
      apiCalls: 1 + recentApiCalls,
    });
  } catch (err) {
    console.error("[update-live-scores] Error:", err);
    return jsonResponse({ error: (err as Error).message }, 500);
  }
});
