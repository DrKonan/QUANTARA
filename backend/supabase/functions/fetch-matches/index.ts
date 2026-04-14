// ============================================================
// QUANTARA — Edge Function : fetch-matches
// Déclencheur : Cron 6h UTC chaque jour
// Rôle : Récupère les matchs du jour pour les ligues actives
//        (leagues_config) via API-Football, un appel par ligue.
//        Résultat : ~80-120 matchs/jour au lieu de 200+.
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
  };
  teams: {
    home: { id: number; name: string };
    away: { id: number; name: string };
  };
  goals: {
    home: number | null;
    away: number | null;
  };
  season: number;
}

Deno.serve(async (_req: Request) => {
  try {
    const supabase = getSupabaseAdmin();
    const date = todayUTC();

    console.log(`[fetch-matches] Fetching fixtures for ${date}`);

    // 1. Récupère les ligues actives depuis leagues_config
    const { data: activeLeagues, error: leagueError } = await supabase
      .from("leagues_config")
      .select("league_id, tier, current_season")
      .eq("is_active", true);

    if (leagueError) throw leagueError;
    if (!activeLeagues || activeLeagues.length === 0) {
      return jsonResponse({ message: "No active leagues configured", date, count: 0 });
    }

    const leagueTierMap = new Map(
      activeLeagues.map((l: { league_id: number; tier: number }) => [l.league_id, l.tier])
    );
    const leagueSeasonMap = new Map(
      activeLeagues.map((l: { league_id: number; current_season: number }) => [l.league_id, l.current_season])
    );

    console.log(`[fetch-matches] Fetching for ${activeLeagues.length} active leagues`);

    // 2. Un appel par ligue (séquentiel grâce au throttle)
    const allFixtures: ApiFixture[] = [];

    for (const league of activeLeagues) {
      try {
        const season = leagueSeasonMap.get(league.league_id) ?? 2025;
        const fixtures = await apifootball("/fixtures", {
          date,
          league: league.league_id,
          season,
          timezone: "Africa/Abidjan",
        }) as ApiFixture[];

        if (fixtures && fixtures.length > 0) {
          allFixtures.push(...fixtures);
        }
      } catch (err) {
        console.warn(`[fetch-matches] Failed for league ${league.league_id}:`, err);
      }
    }

    if (allFixtures.length === 0) {
      return jsonResponse({ message: "No fixtures for today in active leagues", date, count: 0 });
    }

    // 3. Filtre les matchs sans ID d'équipe valide
    const validFixtures = allFixtures.filter(
      (f) => f.teams.home.id && f.teams.away.id,
    );

    const rows = validFixtures.map((f) => ({
      external_id: String(f.fixture.id),
      sport: "football",
      home_team: f.teams.home.name,
      away_team: f.teams.away.name,
      home_team_id: f.teams.home.id,
      away_team_id: f.teams.away.id,
      league: f.league.name,
      league_id: f.league.id,
      season: f.season ?? (leagueSeasonMap.get(f.league.id) ?? 2025),
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

    console.log(`[fetch-matches] Upserted ${count ?? rows.length} matches from ${activeLeagues.length} leagues`);
    return jsonResponse({ success: true, date, leagues: activeLeagues.length, upserted: count ?? rows.length });
  } catch (err) {
    console.error("[fetch-matches] Error:", err);
    return jsonResponse({ error: (err as Error).message }, 500);
  }
});
