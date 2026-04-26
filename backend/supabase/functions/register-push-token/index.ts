// ============================================================
// NAKORA — Edge Function : register-push-token
// Enregistre ou met à jour le token FCM/APNs d'un appareil.
// Requires: Authorization header (user JWT)
// ============================================================
import { getSupabaseAdmin } from "../_shared/supabase.ts";
import { jsonResponse } from "../_shared/helpers.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, content-type, apikey, x-client-info",
      },
    });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return jsonResponse({ error: "Unauthorized" }, 401);

  const supabase = getSupabaseAdmin();

  const { data: { user }, error: authError } = await supabase.auth.getUser(
    authHeader.replace("Bearer ", ""),
  );
  if (authError || !user) return jsonResponse({ error: "Unauthorized" }, 401);

  let body: { token?: string; platform?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON" }, 400);
  }

  const { token, platform } = body;
  if (!token || !platform) return jsonResponse({ error: "token et platform requis" }, 400);
  if (!["ios", "android"].includes(platform)) {
    return jsonResponse({ error: "platform doit être ios ou android" }, 400);
  }

  // Désactiver les anciens tokens de ce user sur cette plateforme
  await supabase
    .from("push_tokens")
    .update({ is_active: false, updated_at: new Date().toISOString() })
    .eq("user_id", user.id)
    .eq("platform", platform)
    .neq("token", token);

  // Upsert sur le token (globalement unique par appareil)
  const { error } = await supabase.from("push_tokens").upsert(
    {
      user_id: user.id,
      token,
      platform,
      is_active: true,
      updated_at: new Date().toISOString(),
    },
    { onConflict: "token" },
  );

  if (error) {
    console.error("[register-push-token] Upsert error:", error);
    return jsonResponse({ error: error.message }, 500);
  }

  console.log(`[register-push-token] Token registered: user=${user.id}, platform=${platform}`);
  return jsonResponse({ success: true });
});
