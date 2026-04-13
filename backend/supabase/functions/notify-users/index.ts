// ============================================================
// QUANTARA — Edge Function : notify-users
// Déclencheur : appelée par predict-prematch et evaluate-predictions
// Body attendu :
//   { type: "new_predictions", match_id: number, count: number }
//   { type: "prediction_results", match_id: number, results: Array<{id, is_correct}> }
// Rôle : Envoie les notifications push via FCM (Firebase).
// ============================================================
import { getSupabaseAdmin } from "../_shared/supabase.ts";
import { jsonResponse } from "../_shared/helpers.ts";

type NotifyPayload =
  | { type: "new_predictions"; match_id: number; count: number }
  | { type: "prediction_results"; match_id: number; results: Array<{ id: number; is_correct: boolean }> };

interface PushToken {
  token: string;
  platform: string;
  user_id: string;
}

// ----------------------------------------------------------------
// Envoi FCM (Firebase Cloud Messaging) — HTTP v1 API
// Compatible iOS (APNs via FCM) et Android
// ----------------------------------------------------------------
async function sendFCMNotification(
  tokens: string[],
  title: string,
  body: string,
  data?: Record<string, string>,
): Promise<number> {
  const fcmKey = Deno.env.get("FCM_SERVER_KEY");
  if (!fcmKey) {
    console.warn("[notify-users] No FCM_SERVER_KEY — notifications disabled");
    return 0;
  }

  if (tokens.length === 0) return 0;

  // Envoi en batches de 500 (limite FCM)
  const BATCH_SIZE = 500;
  let sent = 0;

  for (let i = 0; i < tokens.length; i += BATCH_SIZE) {
    const batch = tokens.slice(i, i + BATCH_SIZE);

    const payload = {
      registration_ids: batch,
      notification: { title, body },
      data: data ?? {},
      priority: "high",
    };

    const res = await fetch("https://fcm.googleapis.com/fcm/send", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `key=${fcmKey}`,
      },
      body: JSON.stringify(payload),
    });

    if (res.ok) {
      const json = await res.json() as { success: number; failure: number };
      sent += json.success ?? 0;
      console.log(`[notify-users] FCM batch: ${json.success} ok, ${json.failure} failed`);
    } else {
      console.error("[notify-users] FCM error:", await res.text());
    }
  }

  return sent;
}

Deno.serve(async (req: Request) => {
  try {
    const supabase = getSupabaseAdmin();
    const payload = await req.json() as NotifyPayload;

    if (payload.type === "new_predictions") {
      // Récupère le match pour le titre de la notif
      const { data: match } = await supabase
        .from("matches")
        .select("home_team, away_team, league")
        .eq("id", payload.match_id)
        .single();

      if (!match) return jsonResponse({ error: "Match not found" }, 404);

      // Récupère tous les tokens actifs (tous les utilisateurs)
      const { data: tokens } = await supabase
        .from("push_tokens")
        .select("token, platform, user_id")
        .eq("is_active", true);

      const tokenList = (tokens ?? []).map((t: PushToken) => t.token);

      const title = `⚽ Nouveau prono — ${match.league}`;
      const body = `${match.home_team} vs ${match.away_team} · ${payload.count} prono${payload.count > 1 ? "s" : ""} disponible${payload.count > 1 ? "s" : ""}`;

      const sent = await sendFCMNotification(tokenList, title, body, {
        type: "new_predictions",
        match_id: String(payload.match_id),
      });

      return jsonResponse({ success: true, sent });
    }

    if (payload.type === "prediction_results") {
      const { data: match } = await supabase
        .from("matches")
        .select("home_team, away_team")
        .eq("id", payload.match_id)
        .single();

      if (!match) return jsonResponse({ error: "Match not found" }, 404);

      // Sépare les pronos gagnés et perdus
      const won = payload.results.filter((r) => r.is_correct).length;
      const lost = payload.results.filter((r) => !r.is_correct).length;

      const { data: tokens } = await supabase
        .from("push_tokens")
        .select("token")
        .eq("is_active", true);

      const tokenList = (tokens ?? []).map((t: { token: string }) => t.token);

      const title = `📊 Résultats — ${match.home_team} vs ${match.away_team}`;
      const body = won > 0 && lost === 0
        ? `✅ ${won} prono${won > 1 ? "s" : ""} gagnant${won > 1 ? "s" : ""} !`
        : `✅ ${won} gagné${won > 1 ? "s" : ""} · ❌ ${lost} perdu${lost > 1 ? "s" : ""}`;

      const sent = await sendFCMNotification(tokenList, title, body, {
        type: "prediction_results",
        match_id: String(payload.match_id),
      });

      return jsonResponse({ success: true, sent });
    }

    return jsonResponse({ error: "Unknown notification type" }, 400);
  } catch (err) {
    console.error("[notify-users] Error:", err);
    return jsonResponse({ error: (err as Error).message }, 500);
  }
});
