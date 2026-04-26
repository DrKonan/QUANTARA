// ============================================================
// NAKORA — Edge Function : webhook-payment
// IPN PayDunya (callback_url) + legacy Wave/PawaPay/CinetPay.
// Deployed with --no-verify-jwt (public endpoint).
// ============================================================
import { getSupabaseAdmin } from "../_shared/supabase.ts";
import { jsonResponse } from "../_shared/helpers.ts";

const PLAN_DURATIONS: Record<string, number> = {
  starter: 30,
  pro: 30,
  vip: 30,
};

// ────────────────────────────────────────────────────────────
// Main handler
// ────────────────────────────────────────────────────────────
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "content-type",
      },
    });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const rawBody = await req.text();
  console.log("[webhook-payment] Received payload:", rawBody.substring(0, 500));

  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(rawBody);
  } catch {
    return jsonResponse({ error: "Invalid JSON" }, 400);
  }

  // PayDunya IPN: has "hash" + "invoice" + "custom_data"
  if ("hash" in payload && "invoice" in payload && "custom_data" in payload) {
    return handlePaydunyaCallback(payload, rawBody);
  }

  // Wave callback
  if ("client_reference" in payload || "checkout_session_id" in payload) {
    return handleWaveCallback(payload);
  }

  // PawaPay (legacy)
  if ("depositId" in payload) {
    return handlePawapayCallback(payload);
  }

  // CinetPay (legacy)
  if ("cpm_trans_id" in payload) {
    return handleCinetpayCallback(payload, rawBody, req);
  }

  console.warn("[webhook-payment] Unknown payload shape:", Object.keys(payload));
  return jsonResponse({ error: "Unknown provider" }, 400);
});

// ────────────────────────────────────────────────────────────
// PayDunya IPN
// hash = SHA-512(masterKey) — fixed per account, proves request comes from PayDunya
// ────────────────────────────────────────────────────────────
async function handlePaydunyaCallback(
  payload: Record<string, unknown>,
  _rawBody: string,
) {
  const supabase = getSupabaseAdmin();
  const masterKey = Deno.env.get("PAYDUNYA_MASTER_KEY");

  if (!masterKey) {
    console.error("[webhook-payment] Missing PAYDUNYA_MASTER_KEY");
    return jsonResponse({ error: "Server configuration error" }, 500);
  }

  const invoice = payload.invoice as Record<string, unknown>;
  const customData = payload.custom_data as Record<string, unknown>;
  const hash = payload.hash as string;
  const status = payload.status as string;

  console.log(`[webhook-payment] PayDunya IPN: status=${status}, invoice_token=${invoice?.token}, payment_id=${customData?.payment_id}`);

  if (!invoice?.token || !customData?.payment_id || !hash) {
    console.error("[webhook-payment] Missing required fields:", { hasToken: !!invoice?.token, hasPaymentId: !!customData?.payment_id, hasHash: !!hash });
    return jsonResponse({ error: "Invalid PayDunya payload" }, 400);
  }

  // Verify SHA-512(masterKey) — per PayDunya spec
  const isValid = await verifyPaydunyaHash(hash, masterKey);
  console.log(`[webhook-payment] Hash valid: ${isValid}`);
  if (!isValid) {
    console.warn("[webhook-payment] PayDunya invalid hash");
    return jsonResponse({ error: "Invalid signature" }, 401);
  }

  const paymentId = customData.payment_id as string;

  if (status === "completed") {
    await supabase.from("payments").update({
      status: "completed",
      completed_at: new Date().toISOString(),
      metadata: payload,
      updated_at: new Date().toISOString(),
    }).eq("id", paymentId);

    return activateSubscription(
      supabase,
      customData.user_id as string,
      customData.plan as string,
      paymentId,
      "paydunya",
      null,
      invoice.total_amount as number,
    );
  }

  if (status === "cancelled" || status === "failed") {
    await supabase.from("payments").update({
      status: "failed",
      metadata: payload,
      updated_at: new Date().toISOString(),
    }).eq("id", paymentId);
    return jsonResponse({ received: true, status: "failed" });
  }

  // Pending / processing
  await supabase.from("payments").update({
    status: "submitted",
    metadata: payload,
    updated_at: new Date().toISOString(),
  }).eq("id", paymentId);

  return jsonResponse({ received: true, status: "pending" });
}

// PayDunya spec: hash = sha512(masterKey)
// Not HMAC — just a plain SHA-512 digest of the master key itself.
// It's a fixed value per account, used to confirm the request origin.
async function verifyPaydunyaHash(hash: string, masterKey: string): Promise<boolean> {
  try {
    const data = new TextEncoder().encode(masterKey);
    const hashBuffer = await crypto.subtle.digest("SHA-512", data);
    const expected = Array.from(new Uint8Array(hashBuffer))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");
    console.log(`[webhook-payment] Hash expected=${expected.substring(0, 20)}... got=${hash.substring(0, 20)}...`);
    return expected === hash;
  } catch (e) {
    console.error("[webhook-payment] Hash verification error:", e);
    return false;
  }
}

// ────────────────────────────────────────────────────────────
// Wave Callback
// ────────────────────────────────────────────────────────────
async function handleWaveCallback(payload: Record<string, unknown>) {
  const supabase = getSupabaseAdmin();
  const clientRef = (payload.client_reference as string) || (payload.checkout_session_id as string);
  const paymentStatus = payload.payment_status as string;

  console.log(`[webhook-payment] Wave callback: ref=${clientRef}, status=${paymentStatus}`);

  const { data: payment } = await supabase.from("payments").select("*").eq("id", clientRef).single();
  const target = payment ?? (await supabase.from("payments").select("*").eq("external_id", clientRef).single()).data;

  if (!target) {
    console.error("[webhook-payment] Wave payment not found:", clientRef);
    return jsonResponse({ error: "Payment not found" }, 404);
  }

  if (paymentStatus === "succeeded") {
    await supabase.from("payments").update({
      status: "completed",
      completed_at: new Date().toISOString(),
      metadata: payload,
      updated_at: new Date().toISOString(),
    }).eq("id", target.id);
    return activateSubscription(supabase, target.user_id, target.plan, target.id, "wave", null, target.amount);
  }

  if (paymentStatus === "failed" || paymentStatus === "expired") {
    await supabase.from("payments").update({ status: "failed", metadata: payload, updated_at: new Date().toISOString() }).eq("id", target.id);
    return jsonResponse({ received: true, status: "failed" });
  }

  return jsonResponse({ received: true, status: "pending" });
}

// ────────────────────────────────────────────────────────────
// PawaPay Callback (legacy)
// ────────────────────────────────────────────────────────────
async function handlePawapayCallback(payload: Record<string, unknown>) {
  const supabase = getSupabaseAdmin();
  const depositId = payload.depositId as string;
  const status = payload.status as string;

  console.log(`[webhook-payment] PawaPay callback: depositId=${depositId}, status=${status}`);

  const { data: payment } = await supabase.from("payments").select("*").eq("external_id", depositId).single();
  const target = payment ?? (await supabase.from("payments").select("*").eq("id", depositId).single()).data;

  if (!target) {
    console.error("[webhook-payment] PawaPay payment not found:", depositId);
    return jsonResponse({ error: "Payment not found" }, 404);
  }

  if (status === "COMPLETED") {
    await supabase.from("payments").update({ status: "completed", completed_at: new Date().toISOString(), metadata: payload, updated_at: new Date().toISOString() }).eq("id", target.id);
    return activateSubscription(supabase, target.user_id, target.plan, target.id, "pawapay", target.correspondent ?? null, target.amount);
  }

  if (status === "FAILED") {
    await supabase.from("payments").update({ status: "failed", metadata: payload, updated_at: new Date().toISOString() }).eq("id", target.id);
    return jsonResponse({ received: true, status: "failed" });
  }

  await supabase.from("payments").update({ status: "submitted", metadata: payload, updated_at: new Date().toISOString() }).eq("id", target.id);
  return jsonResponse({ received: true, status: "pending" });
}

// ────────────────────────────────────────────────────────────
// CinetPay Callback (legacy)
// ────────────────────────────────────────────────────────────
async function handleCinetpayCallback(payload: Record<string, unknown>, rawBody: string, req: Request) {
  const supabase = getSupabaseAdmin();
  const cinetpaySecret = Deno.env.get("CINETPAY_SECRET");

  if (!cinetpaySecret) {
    console.error("[webhook-payment] Missing CINETPAY_SECRET");
    return jsonResponse({ error: "Server configuration error" }, 500);
  }

  const signature = req.headers.get("X-Cinetpay-Signature") ?? (payload.signature as string);
  if (!signature) return jsonResponse({ error: "Missing signature" }, 401);

  const isValid = await verifyHmacSha256(rawBody, signature, cinetpaySecret);
  if (!isValid) return jsonResponse({ error: "Invalid signature" }, 401);

  if (payload.cpm_result !== "00" || payload.cpm_trans_status !== "ACCEPTED") {
    await supabase.from("subscriptions").update({ status: "cancelled" }).eq("payment_ref", payload.cpm_trans_id as string).eq("status", "pending");
    return jsonResponse({ received: true, status: "refused" });
  }

  let customData: { user_id: string; plan: string };
  try {
    customData = JSON.parse(payload.cpm_custom as string);
  } catch {
    return jsonResponse({ error: "Invalid custom data" }, 400);
  }

  return activateSubscription(supabase, customData.user_id, customData.plan, payload.cpm_trans_id as string, "cinetpay", null, parseInt(payload.cpm_amount as string, 10));
}

// ────────────────────────────────────────────────────────────
// Shared: Activate subscription
// ────────────────────────────────────────────────────────────
async function activateSubscription(
  supabase: ReturnType<typeof getSupabaseAdmin>,
  userId: string,
  plan: string,
  paymentRef: string,
  provider: string,
  correspondent: string | null,
  amount: number,
) {
  const durationDays = PLAN_DURATIONS[plan] ?? 30;
  const startDate = new Date();
  let subStartDate = startDate;
  let subEndDate = new Date(startDate.getTime() + durationDays * 86_400_000);

  const { data: existingSub } = await supabase
    .from("subscriptions")
    .select("id, end_date")
    .eq("user_id", userId)
    .eq("status", "active")
    .order("end_date", { ascending: false })
    .limit(1)
    .single();

  if (existingSub) {
    const currentEnd = new Date(existingSub.end_date);
    if (currentEnd > startDate) {
      subStartDate = currentEnd;
      subEndDate = new Date(currentEnd.getTime() + durationDays * 86_400_000);
    }
  }

  const { error: subError } = await supabase.from("subscriptions").insert({
    user_id: userId,
    plan,
    status: "active",
    start_date: subStartDate.toISOString(),
    end_date: subEndDate.toISOString(),
    payment_ref: paymentRef,
    amount,
    currency: "XOF",
    provider,
    correspondent,
  });

  if (subError) {
    console.error("[webhook-payment] Failed to create subscription:", subError);
    return jsonResponse({ error: "Database error" }, 500);
  }

  await supabase.from("users").update({ plan }).eq("id", userId);

  console.log(`[webhook-payment] ✅ Activated: user=${userId}, plan=${plan}, provider=${provider}, end=${subEndDate.toISOString()}`);
  return jsonResponse({ received: true, status: "activated", end_date: subEndDate.toISOString() });
}

// ────────────────────────────────────────────────────────────
// HMAC-SHA256 (CinetPay)
// ────────────────────────────────────────────────────────────
async function verifyHmacSha256(body: string, signature: string, secret: string): Promise<boolean> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey("raw", encoder.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["verify"]);
  const sigBytes = new Uint8Array(signature.length / 2);
  for (let i = 0; i < signature.length; i += 2) {
    sigBytes[i / 2] = parseInt(signature.slice(i, i + 2), 16);
  }
  return crypto.subtle.verify("HMAC", key, sigBytes, encoder.encode(body));
}
