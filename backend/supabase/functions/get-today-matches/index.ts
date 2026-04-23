// ============================================================
// NAKORA — Edge Function : get-today-matches
// Auth : JWT requis (utilisateur connecté)
// Rôle : Retourne les matchs éligibles du jour avec leur
//        statut de prédiction. Un match terminé n'apparaît pas.
//        Si la prédiction n'est pas encore dispo, explique
//        pourquoi et donne une estimation du temps restant.
// ============================================================
import { getSupabaseAdmin } from "../_shared/supabase.ts";
import { jsonResponse } from "../_shared/helpers.ts";

interface MatchRow {
  id: number;
  external_id: string;
  home_team: string;
  away_team: string;
  home_team_id: number;
  away_team_id: number;
  league: string;
  league_id: number;
  tier: number;
  match_date: string;
  status: string;
  home_score: number | null;
  away_score: number | null;
  lineups_ready: boolean;
}

interface PredictionRow {
  id: number;
  match_id: number;
  prediction_type: string;
  prediction: string;
  confidence: number;
  confidence_label: string;
  is_premium: boolean;
  is_live: boolean;
  is_top_pick: boolean;
  is_refined: boolean;
  analysis_text: string | null;
}

Deno.serve(async (req: Request) => {
  try {
    const supabase = getSupabaseAdmin();

    // --- Auth : vérifie le JWT ---
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ error: "Authorization required" }, 401);
    }

    const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2");
    const anonClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user }, error: authError } = await anonClient.auth.getUser();
    if (authError || !user) {
      return jsonResponse({ error: "Invalid token" }, 401);
    }

    // --- Paramètre optionnel : date (par défaut aujourd'hui) ---
    const url = new URL(req.url);
    const dateParam = url.searchParams.get("date");

    const now = new Date();
    const targetDate = dateParam ?? now.toISOString().slice(0, 10); // YYYY-MM-DD

    // Journée sportive : de 06:00 UTC aujourd'hui à 05:59 UTC demain.
    // Cela garantit que les matchs d'Amérique du Sud en soirée locale
    // (qui sont le lendemain en UTC, ex: 00:30, 02:00 UTC) restent
    // affichés avec la bonne journée.
    const dayStart = `${targetDate}T06:00:00+00:00`;
    // Lendemain
    const nextDay = new Date(new Date(targetDate + "T00:00:00Z").getTime() + 24 * 60 * 60 * 1000)
      .toISOString().slice(0, 10);
    const dayEnd = `${nextDay}T05:59:59+00:00`;

    // --- Récupère TOUS les matchs du jour (y compris terminés) ---
    // On les regroupe ensuite par statut pour le client
    const { data: matches, error: matchError } = await supabase
      .from("matches")
      .select("id, external_id, home_team, away_team, home_team_id, away_team_id, league, league_id, tier, match_date, status, home_score, away_score, lineups_ready")
      .gte("match_date", dayStart)
      .lte("match_date", dayEnd)
      .not("status", "eq", "cancelled")
      .not("tier", "is", null)
      .order("match_date", { ascending: true });

    if (matchError) throw matchError;

    // --- Récupère les catégories/pays depuis leagues_config ---
    const leagueIds = [...new Set((matches ?? []).map((m: MatchRow) => m.league_id))];
    let leagueMetaMap = new Map<number, { country: string; category: string }>();
    if (leagueIds.length > 0) {
      const { data: leagueMeta } = await supabase
        .from("leagues_config")
        .select("league_id, country, category")
        .in("league_id", leagueIds);
      for (const lm of (leagueMeta ?? []) as { league_id: number; country: string; category: string }[]) {
        leagueMetaMap.set(lm.league_id, { country: lm.country, category: lm.category });
      }
    }

    // --- Récupère les prédictions existantes pour ces matchs ---
    const matchIds = (matches ?? []).map((m: MatchRow) => m.id);
    let predictionsMap = new Map<number, PredictionRow[]>();

    if (matchIds.length > 0) {
      const { data: predictions } = await supabase
        .from("predictions")
        .select("id, match_id, prediction_type, prediction, confidence, confidence_label, is_premium, is_live, is_top_pick, is_refined, analysis_text")
        .in("match_id", matchIds)
        .eq("is_published", true);

      for (const pred of (predictions ?? []) as PredictionRow[]) {
        const list = predictionsMap.get(pred.match_id) ?? [];
        list.push(pred);
        predictionsMap.set(pred.match_id, list);
      }
    }

    // --- Vérifie le plan de l'utilisateur ---
    const { data: userProfile } = await supabase
      .from("users")
      .select("plan, trial_ends_at")
      .eq("id", user.id)
      .single();

    const userPlan = userProfile?.plan ?? "free";
    const isPremium = userPlan !== "free" ||
      (userProfile?.trial_ends_at && new Date(userProfile.trial_ends_at) > now);
    const hasCombos = userPlan === "pro" || userPlan === "vip";

    // --- Construit la réponse enrichie ---
    const result = (matches ?? []).map((match: MatchRow) => {
      const preds = predictionsMap.get(match.id) ?? [];
      const kickoff = new Date(match.date ?? match.match_date);
      const msUntilKickoff = kickoff.getTime() - now.getTime();
      const minutesUntilKickoff = Math.round(msUntilKickoff / 60000);

      // Détermine le statut de disponibilité des prédictions
      let prediction_status: string;
      let prediction_message: string;
      let estimated_wait_minutes: number | null = null;

      if (match.status === "finished") {
        // Match terminé — on montre les résultats
        prediction_status = "finished";
        prediction_message = preds.length > 0
          ? `Match terminé — ${preds.length} prédiction(s) à vérifier`
          : "Match terminé";
      } else if (preds.length > 0) {
        prediction_status = "available";
        prediction_message = `${preds.length} prédiction(s) disponible(s)`;
      } else if (match.status === "live") {
        // Match en cours mais pas encore de prono live
        prediction_status = "pending_live";
        prediction_message = "Analyse en cours — les prédictions live arrivent bientôt";
        estimated_wait_minutes = match.tier === 1 ? 15 : 5;
      } else if (match.lineups_ready) {
        // Compos dispo mais prédiction pas encore générée
        prediction_status = "generating";
        prediction_message = "Compositions reçues — génération des prédictions en cours";
        estimated_wait_minutes = 2;
      } else if (minutesUntilKickoff <= 90) {
        // Moins de 90 min avant le match, on surveille les compos
        prediction_status = "waiting_lineups";
        prediction_message = "En attente des compositions officielles";
        estimated_wait_minutes = Math.max(0, minutesUntilKickoff - 60);
      } else {
        // Plus de 90 min avant le match
        prediction_status = "too_early";
        prediction_message = "Les compositions officielles sortent ~1h avant le match";
        estimated_wait_minutes = Math.max(0, minutesUntilKickoff - 60);
      }

      // Filtre les pronos premium si l'utilisateur est free
      const visiblePredictions = preds.map((p) => ({
        id: p.id,
        prediction_type: p.prediction_type,
        prediction: (!p.is_premium || isPremium) ? p.prediction : null,
        confidence: (!p.is_premium || isPremium) ? p.confidence : null,
        confidence_label: p.confidence_label,
        is_premium: p.is_premium,
        is_locked: p.is_premium && !isPremium,
        is_live: p.is_live,
        is_top_pick: p.is_top_pick ?? false,
        is_refined: p.is_refined ?? false,
        analysis_text: (!p.is_premium || isPremium) ? p.analysis_text : null,
      }));

      const meta = leagueMetaMap.get(match.league_id) ?? { country: "Unknown", category: "other" };

      return {
        id: match.id,
        external_id: match.external_id,
        home_team: match.home_team,
        away_team: match.away_team,
        league: match.league,
        league_id: match.league_id,
        country: meta.country,
        category: meta.category,
        tier: match.tier,
        match_date: match.match_date,
        status: match.status,
        home_score: match.home_score,
        away_score: match.away_score,
        minutes_until_kickoff: minutesUntilKickoff,
        prediction_status,
        prediction_message,
        estimated_wait_minutes,
        predictions: visiblePredictions,
      };
    });

    // Tri par catégorie (top5 et international d'abord) puis par heure
    const categoryOrder: Record<string, number> = {
      major_international: 0,
      top5: 1,
      europe: 2,
      south_america: 3,
      rest_of_world: 4,
      other: 5,
    };
    result.sort((a: { category: string; match_date: string }, b: { category: string; match_date: string }) => {
      const catDiff = (categoryOrder[a.category] ?? 5) - (categoryOrder[b.category] ?? 5);
      if (catDiff !== 0) return catDiff;
      return a.match_date.localeCompare(b.match_date);
    });

    // Regroupe par statut pour faciliter l'affichage côté client
    const finished = result.filter((m: { status: string }) => m.status === "finished");
    const live = result.filter((m: { status: string }) => m.status === "live");
    const upcoming = result.filter((m: { status: string }) => m.status === "scheduled");

    // --- Récupère les combinés du jour ---
    let combos: unknown[] = [];
    const { data: combosRaw } = await supabase
      .from("combo_predictions")
      .select("id, combo_type, combined_odds, combined_confidence, leg_count, legs, status, min_plan, created_at")
      .eq("combo_date", targetDate)
      .order("combo_type", { ascending: true });

    if (combosRaw && combosRaw.length > 0) {
      combos = combosRaw.map((c: {
        id: number; combo_type: string; combined_odds: number; combined_confidence: number;
        leg_count: number; legs: unknown; status: string; min_plan: string; created_at: string;
      }) => {
        // Vérifie si l'utilisateur a accès à ce combo
        const hasAccess = hasCombos && (c.min_plan === "pro" || (c.min_plan === "vip" && userPlan === "vip"));
        return {
          id: c.id,
          combo_type: c.combo_type,
          combined_odds: hasAccess ? c.combined_odds : null,
          combined_confidence: hasAccess ? c.combined_confidence : null,
          leg_count: c.leg_count,
          legs: hasAccess ? c.legs : null,
          status: c.status,
          is_locked: !hasAccess,
          min_plan: c.min_plan,
          created_at: c.created_at,
        };
      });
    }

    return jsonResponse({
      date: targetDate,
      count: result.length,
      summary: {
        finished: finished.length,
        live: live.length,
        upcoming: upcoming.length,
      },
      matches: result,
      combos,
    });
  } catch (err) {
    console.error("[get-today-matches] Error:", err);
    return jsonResponse({ error: (err as Error).message }, 500);
  }
});
