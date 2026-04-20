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
  if (!authHeader) {
    return jsonResponse({ error: "Missing authorization" }, 401);
  }

  const supabase = getSupabaseAdmin();
  const token = authHeader.replace("Bearer ", "");
  const { data: { user }, error: authError } = await supabase.auth.getUser(token);

  if (authError || !user) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  const userId = user.id;
  console.log(`[delete-account] Deleting user ${userId}`);

  try {
    // Delete user data from all tables (order matters for FK constraints)
    const tables = ["push_tokens", "payments", "subscriptions", "predictions_viewed", "users"];
    for (const table of tables) {
      const { error } = await supabase.from(table).delete().eq("user_id", userId);
      if (error) {
        console.warn(`[delete-account] Warning deleting from ${table}: ${error.message}`);
      }
    }

    // Delete auth user
    const { error: deleteError } = await supabase.auth.admin.deleteUser(userId);
    if (deleteError) {
      console.error(`[delete-account] Failed to delete auth user: ${deleteError.message}`);
      return jsonResponse({ error: "Failed to delete account" }, 500);
    }

    console.log(`[delete-account] User ${userId} deleted successfully`);
    return jsonResponse({ success: true });
  } catch (err) {
    console.error("[delete-account] Error:", err);
    return jsonResponse({ error: "Account deletion failed" }, 500);
  }
});
