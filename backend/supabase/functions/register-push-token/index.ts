import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { supabaseAdmin } from "../_shared/supabase.ts";
import { jsonResponse } from "../_shared/helpers.ts";

serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  // Vérifier l'authentification
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace("Bearer ", "");

  const {
    data: { user },
    error: authError,
  } = await supabaseAdmin.auth.getUser(token);

  if (authError || !user) {
    return jsonResponse({ error: "Non autorisé" }, 401);
  }

  const body = await req.json();
  const { token: pushToken, platform } = body;

  if (!pushToken || !platform) {
    return jsonResponse({ error: "token et platform requis" }, 400);
  }

  if (!["ios", "android"].includes(platform)) {
    return jsonResponse({ error: "platform doit être ios ou android" }, 400);
  }

  // Désactiver les anciens tokens de ce user sur cette plateforme
  await supabaseAdmin
    .from("push_tokens")
    .update({ is_active: false })
    .eq("user_id", user.id)
    .eq("platform", platform);

  // Upsert le nouveau token
  const { error } = await supabaseAdmin.from("push_tokens").upsert(
    {
      user_id: user.id,
      token: pushToken,
      platform,
      is_active: true,
    },
    { onConflict: "user_id,token" }
  );

  if (error) {
    return jsonResponse({ error: error.message }, 500);
  }

  return jsonResponse({ success: true });
});
