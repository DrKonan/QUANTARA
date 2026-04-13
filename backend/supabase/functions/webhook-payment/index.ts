// ============================================================
// QUANTARA — Edge Function : webhook-payment
// URL publique appelée par CinetPay après chaque paiement.
// Rôle : Valide la signature, active/annule l'abonnement en base.
// ============================================================
import { getSupabaseAdmin } from "../_shared/supabase.ts";
import { jsonResponse } from "../_shared/helpers.ts";

// Durées des plans en jours
const PLAN_DURATIONS: Record<string, number> = {
  weekly: 7,
  monthly: 30,
  yearly: 365,
};

// ----------------------------------------------------------------
// Vérification signature HMAC CinetPay
// CinetPay signe la payload avec : HMAC-SHA256(body, secret)
// Header : X-Cinetpay-Signature
// ----------------------------------------------------------------
async function verifySignature(
  body: string,
  signature: string,
  secret: string,
): Promise<boolean> {
  const encoder = new TextEncoder();
  const keyData = encoder.encode(secret);
  const messageData = encoder.encode(body);

  const key = await crypto.subtle.importKey(
    "raw",
    keyData,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );

  const signatureBytes = hexToBytes(signature);
  return crypto.subtle.verify("HMAC", key, signatureBytes, messageData);
}

function hexToBytes(hex: string): Uint8Array {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) {
    bytes[i / 2] = parseInt(hex.slice(i, i + 2), 16);
  }
  return bytes;
}

// ----------------------------------------------------------------
// Types CinetPay
// ----------------------------------------------------------------
interface CinetPayWebhook {
  cpm_trans_id: string;        // référence de transaction
  cpm_site_id: string;
  cpm_trans_date: string;
  cpm_amount: string;
  cpm_currency: string;
  cpm_payid: string;
  cpm_result: string;          // "00" = succès
  cpm_trans_status: string;    // "ACCEPTED" | "REFUSED" | ...
  cpm_custom: string;          // JSON : { user_id, plan }
  signature: string;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const rawBody = await req.text();
  const cinetpaySecret = Deno.env.get("CINETPAY_SECRET");

  if (!cinetpaySecret) {
    console.error("[webhook-payment] Missing CINETPAY_SECRET");
    return jsonResponse({ error: "Server configuration error" }, 500);
  }

  let payload: CinetPayWebhook;
  try {
    payload = JSON.parse(rawBody) as CinetPayWebhook;
  } catch {
    return jsonResponse({ error: "Invalid JSON payload" }, 400);
  }

  // Vérifie la signature HMAC
  const signature = req.headers.get("X-Cinetpay-Signature") ?? payload.signature;
  if (!signature) {
    return jsonResponse({ error: "Missing signature" }, 401);
  }

  const isValid = await verifySignature(rawBody, signature, cinetpaySecret);
  if (!isValid) {
    console.warn("[webhook-payment] Invalid signature received");
    return jsonResponse({ error: "Invalid signature" }, 401);
  }

  const supabase = getSupabaseAdmin();

  // Paiement refusé ou échoué
  if (payload.cpm_result !== "00" || payload.cpm_trans_status !== "ACCEPTED") {
    console.log(`[webhook-payment] Payment refused: ${payload.cpm_trans_id}`);

    // Met à jour le statut si une subscription pending existe
    await supabase
      .from("subscriptions")
      .update({ status: "cancelled" })
      .eq("payment_ref", payload.cpm_trans_id)
      .eq("status", "pending");

    return jsonResponse({ received: true, status: "refused" });
  }

  // Décode les données custom (user_id + plan)
  let customData: { user_id: string; plan: string };
  try {
    customData = JSON.parse(payload.cpm_custom) as { user_id: string; plan: string };
  } catch {
    console.error("[webhook-payment] Invalid cpm_custom:", payload.cpm_custom);
    return jsonResponse({ error: "Invalid custom data" }, 400);
  }

  const { user_id, plan } = customData;

  if (!user_id || !plan || !PLAN_DURATIONS[plan]) {
    return jsonResponse({ error: "Invalid user_id or plan" }, 400);
  }

  const durationDays = PLAN_DURATIONS[plan];
  const startDate = new Date();
  const endDate = new Date(startDate.getTime() + durationDays * 24 * 60 * 60 * 1000);

  // Vérifie si l'utilisateur a déjà un abonnement actif (extension)
  const { data: existingSub } = await supabase
    .from("subscriptions")
    .select("id, end_date")
    .eq("user_id", user_id)
    .eq("status", "active")
    .order("end_date", { ascending: false })
    .limit(1)
    .single();

  let subStartDate = startDate;
  let subEndDate = endDate;

  if (existingSub) {
    // Extension : part de la fin de l'abonnement actuel
    const currentEnd = new Date(existingSub.end_date);
    if (currentEnd > startDate) {
      subStartDate = currentEnd;
      subEndDate = new Date(currentEnd.getTime() + durationDays * 24 * 60 * 60 * 1000);
    }
  }

  // Crée la nouvelle subscription
  const { error: subError } = await supabase
    .from("subscriptions")
    .insert({
      user_id,
      plan,
      status: "active",
      start_date: subStartDate.toISOString(),
      end_date: subEndDate.toISOString(),
      payment_ref: payload.cpm_trans_id,
      amount: parseInt(payload.cpm_amount, 10),
      currency: payload.cpm_currency,
    });

  if (subError) {
    console.error("[webhook-payment] Failed to create subscription:", subError);
    return jsonResponse({ error: "Database error" }, 500);
  }

  // Passe le profil utilisateur en plan 'premium'
  const { error: userError } = await supabase
    .from("users")
    .update({ plan: "premium" })
    .eq("id", user_id);

  if (userError) {
    console.error("[webhook-payment] Failed to update user plan:", userError);
    // Non bloquant — la subscription est créée, on corrige le plan séparément
  }

  console.log(`[webhook-payment] Subscription activated for user ${user_id}, plan=${plan}, end=${subEndDate.toISOString()}`);
  return jsonResponse({ received: true, status: "activated", end_date: subEndDate.toISOString() });
});
