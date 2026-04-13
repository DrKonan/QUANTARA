// ============================================================
// QUANTARA — Edge Function : fetch-matches
// Déclencheur : Cron 6h UTC chaque jour
// Rôle : Récupère les matchs du jour via API-Football et les
//        stocke (ou met à jour) dans la table `matches`.
// ============================================================
import { apifootball } from "../_shared/api-football.ts";
import { getSupabaseAdmin } from "../_shared/supabase.ts";
import { getLeagueTier, jsonResponse, mapFixtureStatus, todayUTC } from "../_shared/helpers.ts";

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

    const fixtures = await apifootball("/fixtures", {
      date,
      timezone: "Africa/Abidjan",
    }) as ApiFixture[];

    if (!fixtures || fixtures.length === 0) {
      return jsonResponse({ message: "No fixtures for today", date, count: 0 });
    }

    // Filtre : on exclut les matchs sans ID d'équipe valide
    const validFixtures = fixtures.filter(
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
      season: f.season ?? new Date().getFullYear(),
      tier: getLeagueTier(f.league.id),
      match_date: f.fixture.date,
      status: mapFixtureStatus(f.fixture.status.short),
      home_score: f.goals.home ?? null,
      away_score: f.goals.away ?? null,
    }));

    // Upsert : on ne touche pas aux champs calculés (lineups_ready, raw_stats)
    const { error, count } = await supabase
      .from("matches")
      .upsert(rows, {
        onConflict: "external_id",
        ignoreDuplicates: false,
      })
      .select("id", { count: "exact", head: true });

    if (error) throw error;

    console.log(`[fetch-matches] Upserted ${count ?? rows.length} matches`);
    return jsonResponse({ success: true, date, upserted: count ?? rows.length });
  } catch (err) {
    console.error("[fetch-matches] Error:", err);
    return jsonResponse({ error: (err as Error).message }, 500);
  }
});
