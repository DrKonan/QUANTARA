// ============================================================
// QUANTARA — Edge Function : fetch-matches
// Déclencheur : Cron 6h UTC chaque jour
// Rôle : Récupère TOUS les matchs du jour en 1 seul appel API
//        (sans filtre league/season — compatible Free plan),
//        puis filtre côté serveur par leagues_config.
//        Économise ~10 appels API par jour.
// ============================================================
import { apifootball } from "../_shared/api-football.ts";
import { getSupabaseAdmin } from "../_shared/supabase.ts";
import { jsonResponse, mapFixtureStatus, todayUTC } from "../_shared/helpers.ts";

interface ApiFixture {
  fixture: {
    id: number;
    status: { short: string };
    date: string;
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

Deno.serve(async (_req: Request) => {
  try {
    const supabase = getSupabaseAdmin();
    const date = todayUTC();

    console.log(`[fetch-matches] Fetching fixtures for ${date}`);

    // 1. Récupère les ligues actives depuis leagues_config
    const { data: activeLeagues, error: leagueError } = await supabase
      .from("leagues_config")
      .select("league_id, tier")
      .eq("is_active", true);

    if (leagueError) throw leagueError;
    if (!activeLeagues || activeLeagues.length === 0) {
      return jsonResponse({ message: "No active leagues configured", date, count: 0 });
    }

    const leagueIdSet = new Set(
      activeLeagues.map((l: { league_id: number }) => l.league_id)
    );
    const leagueTierMap = new Map(
      activeLeagues.map((l: { league_id: number; tier: number }) => [l.league_id, l.tier])
    );

    // 2. UN SEUL appel API : tous les matchs du jour (pas de filtre league/season)
    //    Le Free plan bloque season=2025+ mais date= sans season fonctionne.
    console.log(`[fetch-matches] Fetching ALL fixtures for ${date} (1 API call)`);

    const allFixtures = await apifootball("/fixtures", {
      date,
      timezone: "Africa/Abidjan",
    }) as ApiFixture[];

    if (!allFixtures || allFixtures.length === 0) {
      return jsonResponse({ message: "No fixtures for today", date, count: 0 });
    }

    console.log(`[fetch-matches] API returned ${allFixtures.length} total fixtures`);

    // 3. Filtre côté serveur : ne garder que nos ligues actives + équipes valides
    const filtered = allFixtures.filter(
      (f) => leagueIdSet.has(f.league.id) && f.teams.home.id && f.teams.away.id,
    );

    if (filtered.length === 0) {
      return jsonResponse({
        message: "No fixtures for today in active leagues",
        date,
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
      season: f.league.season ?? new Date().getFullYear(),
      tier: leagueTierMap.get(f.league.id) ?? 2,
      match_date: f.fixture.date,
      status: mapFixtureStatus(f.fixture.status.short),
      home_score: f.goals.home ?? null,
      away_score: f.goals.away ?? null,
    }));

    // 4. Upsert
    const { error, count } = await supabase
      .from("matches")
      .upsert(rows, {
        onConflict: "external_id",
        ignoreDuplicates: false,
      })
      .select("id", { count: "exact", head: true });

    if (error) throw error;

    console.log(`[fetch-matches] Upserted ${count ?? rows.length} matches from ${allFixtures.length} total`);
    return jsonResponse({
      success: true,
      date,
      totalFromApi: allFixtures.length,
      filteredForOurLeagues: filtered.length,
      upserted: count ?? rows.length,
    });
  } catch (err) {
    console.error("[fetch-matches] Error:", err);
    return jsonResponse({ error: (err as Error).message }, 500);
  }
});
