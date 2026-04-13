import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { supabaseAdmin } from "../_shared/supabase.ts";
import { jsonResponse } from "../_shared/helpers.ts";

serve(async (req) => {
  if (req.method !== "GET") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace("Bearer ", "");

  const {
    data: { user },
    error: authError,
  } = await supabaseAdmin.auth.getUser(token);

  if (authError || !user) {
    return jsonResponse({ error: "Non autorisé" }, 401);
  }

  // Profil utilisateur
  const { data: profile } = await supabaseAdmin
    .from("users")
    .select("id, username, avatar_url, phone, plan, trial_used, trial_ends_at, created_at")
    .eq("id", user.id)
    .single();

  // Abonnement actif (s'il existe)
  const { data: subscription } = await supabaseAdmin
    .from("subscriptions")
    .select("plan, status, start_date, end_date")
    .eq("user_id", user.id)
    .eq("status", "active")
    .order("end_date", { ascending: false })
    .limit(1)
    .maybeSingle();

  // Stats globales de l'app (pas du user, mais utile pour le mobile)
  const { data: globalStats } = await supabaseAdmin
    .from("prediction_stats")
    .select("total, correct, win_rate")
    .eq("period", "all_time")
    .is("league", null)
    .is("prediction_type", null)
    .maybeSingle();

  // Nombre de prédictions publiées aujourd'hui
  const today = new Date().toISOString().slice(0, 10);
  const { count: todayPredictions } = await supabaseAdmin
    .from("predictions")
    .select("*", { count: "exact", head: true })
    .eq("is_published", true)
    .gte("created_at", `${today}T00:00:00Z`);

  return jsonResponse({
    profile: profile ?? null,
    subscription: subscription ?? null,
    stats: {
      total: globalStats?.total ?? 0,
      correct: globalStats?.correct ?? 0,
      win_rate: globalStats?.win_rate ?? 0,
      today_predictions: todayPredictions ?? 0,
    },
    is_premium:
      profile?.plan === "premium" ||
      (profile?.trial_ends_at && new Date(profile.trial_ends_at) > new Date()),
  });
});
