// ============================================================
// NAKORA — Edge Function : fetch-matches
// Déclencheur : Cron 2×/jour — 3h UTC + 20h UTC
// 
// • 3h UTC (morning) → récupère TOUS les matchs du jour UTC
// • 20h UTC (evening) → récupère les matchs du lendemain UTC
//   (captures Amérique du Sud nuit = lendemain en UTC)
// 
// Plus de filtre d'heures : on upsert TOUT ce qu'on trouve sur
// nos ligues. L'upsert garantit qu'il n'y a pas de doublons.
// Après l'upsert, déclenche automatiquement predict-prematch
// pour chaque NOUVEAU match inséré.
// ============================================================
import { apifootball } from "../_shared/api-football.ts";
import { getSupabaseAdmin } from "../_shared/supabase.ts";
import { jsonResponse, mapFixtureStatus } from "../_shared/helpers.ts";

interface ApiFixture {
  fixture: {
    id: number;
    status: { short: string };
    date: string;
    venue?: { id?: number; name?: string; city?: string };
  };
  league: {
    id: number;
    name: string;
    country: string;
    season: number;
  };
  teams: {
    home: { id: number; name: string };
    away: { id: number; name: string };
  };
  goals: {
    home: number | null;
    away: number | null;
  };
}

/** YYYY-MM-DD for a Date */
function fmtDate(d: Date): string {
  return d.toISOString().slice(0, 10);
}

Deno.serve(async (req: Request) => {
  try {
    const supabase = getSupabaseAdmin();
    const now = new Date();
    const currentHourUTC = now.getUTCHours();

    // Détermine quelle(s) date(s) fetcher et quelle plage horaire garder
    // Body optionnel : { mode: "morning" | "evening" } pour forcer
    let mode: "morning" | "evening";
    try {
      const body = await req.json().catch(() => ({})) as { mode?: string };
      if (body.mode === "morning" || body.mode === "evening") {
        mode = body.mode;
      } else {
        mode = currentHourUTC < 12 ? "morning" : "evening";
      }
    } catch {
      mode = currentHourUTC < 12 ? "morning" : "evening";
    }

    const today = fmtDate(now);
    const tomorrow = fmtDate(new Date(now.getTime() + 24 * 60 * 60 * 1000));

    // Dates à fetcher
    // Morning : aujourd'hui (couvre 00:00–23:59 UTC)
    // Evening : aujourd'hui + demain (rattrape les matchs manqués + prend les SA nuit)
    const datesToFetch = mode === "morning"
      ? [today]
      : [today, tomorrow];

    console.log(`[fetch-matches] Mode: ${mode} | Fetching dates: ${datesToFetch.join(", ")} | Current UTC hour: ${currentHourUTC}`);

    // 1. Récupère les ligues actives
    const { data: activeLeagues, error: leagueError } = await supabase
      .from("leagues_config")
      .select("league_id, tier")
      .eq("is_active", true);

    if (leagueError) throw leagueError;
    if (!activeLeagues || activeLeagues.length === 0) {
      return jsonResponse({ message: "No active leagues configured", count: 0 });
    }

    const leagueIdSet = new Set(activeLeagues.map((l: { league_id: number }) => l.league_id));
    const leagueTierMap = new Map(activeLeagues.map((l: { league_id: number; tier: number }) => [l.league_id, l.tier]));

    // 2. Fetch les matchs pour chaque date (1 API call par date)
    let allFixtures: ApiFixture[] = [];
    for (const date of datesToFetch) {
      console.log(`[fetch-matches] Fetching fixtures for ${date}`);
      const fixtures = await apifootball("/fixtures", {
        date,
        timezone: "UTC",
      }) as ApiFixture[];
      if (fixtures && fixtures.length > 0) {
        allFixtures = allFixtures.concat(fixtures);
      }
    }

    if (allFixtures.length === 0) {
      return jsonResponse({ message: "No fixtures found", dates: datesToFetch, count: 0 });
    }

    console.log(`[fetch-matches] API returned ${allFixtures.length} total fixtures for ${datesToFetch.join("+")}`);

    // 3. Filtre : nos ligues actives + équipes valides (plus de filtre horaire)
    const filtered = allFixtures.filter((f) => {
      if (!leagueIdSet.has(f.league.id)) return false;
      if (!f.teams.home.id || !f.teams.away.id) return false;
      return true;
    });

    const primaryCount = filtered.length;

    // 4. AUTO-EXPANSION : si pas assez de matchs, enrichir avec les ligues Tier 3
    const { data: minDailyRow } = await supabase
      .from("app_config")
      .select("value")
      .eq("key", "min_daily_matches")
      .single();
    const MIN_DAILY_MATCHES = minDailyRow ? parseInt(minDailyRow.value, 10) : 25;

    let expansionUsed = 0;
    if (filtered.length < MIN_DAILY_MATCHES) {
      console.log(`[fetch-matches] Only ${filtered.length} matches from active leagues (need ${MIN_DAILY_MATCHES}). Auto-expanding...`);

      const { data: expansionLeagues } = await supabase
        .from("leagues_config")
        .select("league_id")
        .eq("tier", 3);

      if (expansionLeagues && expansionLeagues.length > 0) {
        const expansionIds = new Set(expansionLeagues.map((l: { league_id: number }) => l.league_id));

        const expansionFixtures = allFixtures.filter((f) => {
          if (!expansionIds.has(f.league.id)) return false;
          if (!f.teams.home.id || !f.teams.away.id) return false;
          return true;
        });

        const needed = MIN_DAILY_MATCHES - filtered.length;
        const extra = expansionFixtures.slice(0, needed);

        for (const f of extra) {
          filtered.push(f);
          leagueTierMap.set(f.league.id, 3);
        }
        expansionUsed = extra.length;
        if (expansionUsed > 0) {
          console.log(`[fetch-matches] Auto-expansion: +${expansionUsed} matches from ${new Set(extra.map(f => f.league.name)).size} expansion leagues`);
        }
      }
    }

    if (filtered.length === 0) {
      return jsonResponse({
        message: `No fixtures for our leagues`,
        dates: datesToFetch,
        totalFromApi: allFixtures.length,
        count: 0,
      });
    }

    const rows = filtered.map((f) => ({
      external_id: String(f.fixture.id),
      sport: "football",
      home_team: f.teams.home.name,
      away_team: f.teams.away.name,
      home_team_id: f.teams.home.id,
      away_team_id: f.teams.away.id,
      league: f.league.name,
      league_id: f.league.id,
      league_country: f.league.country,
      season: f.league.season ?? new Date().getFullYear(),
      tier: leagueTierMap.get(f.league.id) ?? 2,
      match_date: f.fixture.date,
      status: mapFixtureStatus(f.fixture.status.short),
      home_score: f.goals.home ?? null,
      away_score: f.goals.away ?? null,
    }));

    // 4. Upsert — retourne les IDs pour savoir lesquels sont nouveaux
    const externalIds = rows.map((r) => r.external_id);

    // Identifie les matchs déjà en DB avant l'upsert
    const { data: existingMatches } = await supabase
      .from("matches")
      .select("external_id")
      .in("external_id", externalIds);
    const existingSet = new Set((existingMatches ?? []).map((m: { external_id: string }) => m.external_id));

    const { error: upsertError } = await supabase
      .from("matches")
      .upsert(rows, { onConflict: "external_id", ignoreDuplicates: false });

    if (upsertError) throw upsertError;

    // 5. Identifie les NOUVEAUX matchs (pas encore en DB avant l'upsert)
    const newExternalIds = externalIds.filter((eid) => !existingSet.has(eid));

    console.log(`[fetch-matches] Upserted ${rows.length} matches (${newExternalIds.length} new)`);

    // 6. Déclenche predict-prematch pour les nouveaux matchs scheduled
    let predictTriggered = 0;
    if (newExternalIds.length > 0) {
      // Récupère les IDs internes des nouveaux matchs scheduled
      const { data: newMatches } = await supabase
        .from("matches")
        .select("id, external_id, match_date")
        .in("external_id", newExternalIds)
        .eq("status", "scheduled");

      if (newMatches && newMatches.length > 0) {
        const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
        const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

        // Déclenche predict-prematch en parallèle (mode initial, sans lineups)
        const results = await Promise.allSettled(
          newMatches.map((m: { id: number }) =>
            fetch(`${supabaseUrl}/functions/v1/predict-prematch`, {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${serviceKey}`,
              },
              body: JSON.stringify({ match_id: m.id }),
            })
          ),
        );
        predictTriggered = results.filter((r) => r.status === "fulfilled").length;
        console.log(`[fetch-matches] Auto-triggered predict-prematch for ${predictTriggered}/${newMatches.length} new matches`);
      }
    }

    // 7. Auto-populate team_cities pour les équipes domicile inconnues
    // Chaque fixture expose fixture.venue.city (ville du stade = ville de l'équipe domicile).
    // On geocode via Nominatim (OpenStreetMap, gratuit, sans clé) et on stocke lat/lng.
    let teamCitiesAdded = 0;
    try {
      // Collecte les paires uniques { home_team_id, home_team_name, city }
      const teamCityMap = new Map<number, { name: string; city: string }>();
      for (const f of filtered) {
        const city = f.fixture.venue?.city;
        if (city && f.teams.home.id) {
          teamCityMap.set(f.teams.home.id, { name: f.teams.home.name, city });
        }
      }

      if (teamCityMap.size > 0) {
        // Exclut les équipes déjà connues
        const { data: existing } = await supabase
          .from("team_cities")
          .select("team_id")
          .in("team_id", [...teamCityMap.keys()]);
        const existingIds = new Set((existing ?? []).map((r: { team_id: number }) => r.team_id));
        const toGeocode = [...teamCityMap.entries()]
          .filter(([id]) => !existingIds.has(id))
          .slice(0, 8); // max 8 geocodages par run pour rester rapide

        for (const [teamId, { name, city }] of toGeocode) {
          try {
            const url = `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(city)}&format=json&limit=1`;
            const resp = await fetch(url, {
              headers: {
                "User-Agent": "Nakora/1.0 (nakora.app)",
                "Accept-Language": "en",
              },
            });
            if (!resp.ok) continue;
            const geo = await resp.json() as Array<{ lat: string; lon: string }>;
            if (!geo || geo.length === 0) continue;
            await supabase.from("team_cities").upsert({
              team_id: teamId,
              team_name: name,
              city,
              latitude: parseFloat(geo[0].lat),
              longitude: parseFloat(geo[0].lon),
            }, { onConflict: "team_id" });
            teamCitiesAdded++;
            // Respecte le rate limit Nominatim : 1 req/s
            await new Promise((r) => setTimeout(r, 1100));
          } catch { /* skip team silently */ }
        }
        if (teamCitiesAdded > 0) {
          console.log(`[fetch-matches] team_cities: added ${teamCitiesAdded} new teams`);
        }
      }
    } catch (err) {
      console.warn("[fetch-matches] team_cities auto-population failed (non-blocking):", err);
    }

    return jsonResponse({
      success: true,
      mode,
      dates: datesToFetch,
      totalFromApi: allFixtures.length,
      primaryLeagues: primaryCount,
      expansionMatches: expansionUsed,
      totalFiltered: filtered.length,
      upserted: rows.length,
      newMatches: newExternalIds.length,
      predictionsTriggered: predictTriggered,
      teamCitiesAdded,
    });
  } catch (err) {
    console.error("[fetch-matches] Error:", err);
    return jsonResponse({ error: (err as Error).message }, 500);
  }
});
