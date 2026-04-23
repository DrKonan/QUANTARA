// ============================================================
// NAKORA — Edge Function : notify-users
// Déclencheur : appelée par predict-prematch, predict-live-t1,
//               generate-combos et evaluate-predictions
// Body attendu :
//   { type: "new_predictions", match_id: number, count: number }
//   { type: "live_prediction", match_id: number, count: number }
//   { type: "combo_available", combo_count: number, safe_legs?: number, safe_odds?: number }
//   { type: "prediction_results", match_id: number, results: Array<{id, is_correct}> }
// Rôle : Envoie les notifications push via FCM v1 HTTP API (OAuth2).
//
// Secret requis : FIREBASE_SERVICE_ACCOUNT_JSON
//   Contenu : JSON complet du service account Firebase
//   Obtenir : Firebase Console > Paramètres > Comptes de service > Générer une nouvelle clé privée
// ============================================================
import { getSupabaseAdmin } from "../_shared/supabase.ts";
import { jsonResponse } from "../_shared/helpers.ts";

type NotifyPayload =
  | { type: "new_predictions"; match_id: number; count: number }
  | { type: "live_prediction"; match_id: number; count: number }
  | { type: "combo_available"; combo_count: number; safe_legs?: number; safe_odds?: number }
  | { type: "prediction_results"; match_id: number; results: Array<{ id: number; is_correct: boolean }> };

interface PushToken {
  token: string;
  platform: string;
  user_id: string;
}

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

// ----------------------------------------------------------------
// FCM HTTP v1 API — OAuth2 via Service Account (Google recommandé)
// ----------------------------------------------------------------

function pemToDer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

function b64url(data: Uint8Array | string): string {
  const str = typeof data === "string"
    ? data
    : String.fromCharCode(...data);
  return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}

async function getOAuth2Token(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = b64url(JSON.stringify({
    iss: sa.client_email,
    sub: sa.client_email,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  }));

  const signingInput = `${header}.${payload}`;
  const privateKeyDer = pemToDer(sa.private_key);

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    privateKeyDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signatureBuffer = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signingInput),
  );

  const signature = b64url(new Uint8Array(signatureBuffer));
  const jwt = `${signingInput}.${signature}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`OAuth2 token error: ${err}`);
  }

  const json = await res.json() as { access_token: string };
  return json.access_token;
}

async function sendFCMNotification(
  tokens: string[],
  title: string,
  body: string,
  data?: Record<string, string>,
): Promise<number> {
  const saJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!saJson) {
    console.warn("[notify-users] No FIREBASE_SERVICE_ACCOUNT_JSON — push disabled");
    return 0;
  }
  if (tokens.length === 0) return 0;

  let sa: ServiceAccount;
  try {
    sa = JSON.parse(saJson) as ServiceAccount;
  } catch {
    console.error("[notify-users] Invalid FIREBASE_SERVICE_ACCOUNT_JSON");
    return 0;
  }

  let accessToken: string;
  try {
    accessToken = await getOAuth2Token(sa);
  } catch (e) {
    console.error("[notify-users] Failed to get OAuth2 token:", e);
    return 0;
  }

  const projectId = sa.project_id;
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

  // FCM v1 ne supporte pas le multicast direct — envoi par batch asynchrone
  const BATCH = 200;
  let sent = 0;

  for (let i = 0; i < tokens.length; i += BATCH) {
    const batch = tokens.slice(i, i + BATCH);

    const results = await Promise.allSettled(
      batch.map((token) =>
        fetch(url, {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token,
              notification: { title, body },
              data: data ?? {},
              android: {
                priority: "high",
                notification: { channel_id: "quantara_predictions" },
              },
              apns: {
                payload: { aps: { sound: "default", badge: 1 } },
              },
            },
          }),
        }).then((r) => r.ok ? 1 : 0)
      ),
    );

    const batchSent = results.reduce(
      (acc, r) => acc + (r.status === "fulfilled" ? r.value : 0),
      0,
    );
    sent += batchSent;
    console.log(`[notify-users] FCM v1 batch ${i / BATCH + 1}: ${batchSent}/${batch.length} ok`);
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

    if (payload.type === "live_prediction") {
      const { data: match } = await supabase
        .from("matches")
        .select("home_team, away_team, league")
        .eq("id", payload.match_id)
        .single();

      if (!match) return jsonResponse({ error: "Match not found" }, 404);

      const { data: tokens } = await supabase
        .from("push_tokens")
        .select("token")
        .eq("is_active", true);

      const tokenList = (tokens ?? []).map((t: { token: string }) => t.token);

      const title = `⚡ Prono LIVE — ${match.league}`;
      const body = `${match.home_team} vs ${match.away_team} · ${payload.count} prono${payload.count > 1 ? "s" : ""} LIVE`;

      const sent = await sendFCMNotification(tokenList, title, body, {
        type: "live_prediction",
        match_id: String(payload.match_id),
      });

      return jsonResponse({ success: true, sent });
    }

    if (payload.type === "combo_available") {
      // Notifie uniquement les PRO/VIP
      const { data: tokens } = await supabase
        .from("push_tokens")
        .select("token, users!inner(plan)")
        .eq("is_active", true)
        .in("users.plan", ["pro", "vip"]);

      const tokenList = (tokens ?? []).map((t: { token: string }) => t.token);

      const title = "🎯 Combiné du jour disponible";
      const body = payload.safe_legs && payload.safe_odds
        ? `Combiné du jour : ${payload.safe_legs} sélections · Cote ${payload.safe_odds.toFixed(2)}`
        : `${payload.combo_count} combiné(s) disponible(s)`;

      const sent = await sendFCMNotification(tokenList, title, body, {
        type: "combo",
        date: new Date().toISOString().slice(0, 10),
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
