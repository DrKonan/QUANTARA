// ============================================================
// QUANTARA — Edge Function : get-today-matches
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
    const dayStart = `${targetDate}T00:00:00+00:00`;
    const dayEnd = `${targetDate}T23:59:59+00:00`;

    // --- Récupère les matchs éligibles du jour ---
    // Éligible = leagues_config.is_active = true (déjà filtré via tier != null)
    // Exclut les matchs terminés et annulés
    const { data: matches, error: matchError } = await supabase
      .from("matches")
      .select("id, external_id, home_team, away_team, home_team_id, away_team_id, league, league_id, tier, match_date, status, home_score, away_score, lineups_ready")
      .gte("match_date", dayStart)
      .lte("match_date", dayEnd)
      .not("status", "in", '("finished","cancelled")')
      .not("tier", "is", null)
      .order("match_date", { ascending: true });

    if (matchError) throw matchError;

    // --- Récupère les prédictions existantes pour ces matchs ---
    const matchIds = (matches ?? []).map((m: MatchRow) => m.id);
    let predictionsMap = new Map<number, PredictionRow[]>();

    if (matchIds.length > 0) {
      const { data: predictions } = await supabase
        .from("predictions")
        .select("id, match_id, prediction_type, prediction, confidence, confidence_label, is_premium, is_live, analysis_text")
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
      .select("plan")
      .eq("id", user.id)
      .single();

    const isPremium = userProfile?.plan === "premium";

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

      if (preds.length > 0) {
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
        analysis_text: (!p.is_premium || isPremium) ? p.analysis_text : null,
      }));

      return {
        id: match.id,
        external_id: match.external_id,
        home_team: match.home_team,
        away_team: match.away_team,
        league: match.league,
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

    return jsonResponse({
      date: targetDate,
      count: result.length,
      matches: result,
    });
  } catch (err) {
    console.error("[get-today-matches] Error:", err);
    return jsonResponse({ error: (err as Error).message }, 500);
  }
});
