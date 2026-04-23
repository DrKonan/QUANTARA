// ============================================================
// NAKORA — Edge Function : webhook-payment
// Webhook public appelé par PawaPay et Wave après chaque paiement.
// Détecte le provider à partir du payload et active l'abonnement.
// ============================================================
import { getSupabaseAdmin } from "../_shared/supabase.ts";
import { jsonResponse } from "../_shared/helpers.ts";

const PLAN_DURATIONS: Record<string, number> = {
  starter: 30,
  pro: 30,
  vip: 30,
};

// ────────────────────────────────────────────────────────────
// Main handler — route to the correct provider handler
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
  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(rawBody);
  } catch {
    return jsonResponse({ error: "Invalid JSON" }, 400);
  }

  // Detect provider from payload shape
  if ("depositId" in payload) {
    return handlePawapayCallback(payload, rawBody, req);
  } else if ("client_reference" in payload || "checkout_session_id" in payload) {
    return handleWaveCallback(payload);
  } else if ("cpm_trans_id" in payload) {
    return handleCinetpayCallback(payload, rawBody, req);
  }

  console.warn("[webhook-payment] Unknown payload shape:", Object.keys(payload));
  return jsonResponse({ error: "Unknown provider" }, 400);
});

// ────────────────────────────────────────────────────────────
// PawaPay Callback
// Payload: { depositId, status, requestedAmount, currency, ... }
// ────────────────────────────────────────────────────────────
async function handlePawapayCallback(
  payload: Record<string, unknown>,
  _rawBody: string,
  _req: Request,
) {
  const supabase = getSupabaseAdmin();

  const depositId = payload.depositId as string;
  const status = payload.status as string;

  console.log(`[webhook-payment] PawaPay callback: depositId=${depositId}, status=${status}`);

  // Find payment record
  const { data: payment, error: findError } = await supabase
    .from("payments")
    .select("*")
    .eq("external_id", depositId)
    .single();

  if (findError || !payment) {
    // Also check by id (depositId = our payment id)
    const { data: paymentById } = await supabase
      .from("payments")
      .select("*")
      .eq("id", depositId)
      .single();

    if (!paymentById) {
      console.error("[webhook-payment] Payment not found:", depositId);
      return jsonResponse({ error: "Payment not found" }, 404);
    }
    return processPawapayResult(supabase, paymentById, status, payload);
  }

  return processPawapayResult(supabase, payment, status, payload);
}

async function processPawapayResult(
  supabase: ReturnType<typeof getSupabaseAdmin>,
  payment: Record<string, unknown>,
  status: string,
  payload: Record<string, unknown>,
) {
  if (status === "COMPLETED") {
    // Update payment
    await supabase.from("payments").update({
      status: "completed",
      completed_at: new Date().toISOString(),
      metadata: payload,
      updated_at: new Date().toISOString(),
    }).eq("id", payment.id);

    // Activate subscription
    return activateSubscription(
      supabase,
      payment.user_id as string,
      payment.plan as string,
      payment.id as string,
      "pawapay",
      payment.correspondent as string | null,
      payment.amount as number,
    );
  } else if (status === "FAILED") {
    await supabase.from("payments").update({
      status: "failed",
      metadata: payload,
      updated_at: new Date().toISOString(),
    }).eq("id", payment.id);

    return jsonResponse({ received: true, status: "failed" });
  }

  // ACCEPTED or SUBMITTED — intermediate status
  await supabase.from("payments").update({
    status: "submitted",
    metadata: payload,
    updated_at: new Date().toISOString(),
  }).eq("id", payment.id);

  return jsonResponse({ received: true, status: "pending" });
}

// ────────────────────────────────────────────────────────────
// Wave Callback
// Wave sends webhook with checkout session data
// ────────────────────────────────────────────────────────────
async function handleWaveCallback(payload: Record<string, unknown>) {
  const supabase = getSupabaseAdmin();

  const clientRef = (payload.client_reference as string) || (payload.checkout_session_id as string);
  const paymentStatus = payload.payment_status as string;

  console.log(`[webhook-payment] Wave callback: ref=${clientRef}, status=${paymentStatus}`);

  // Find payment by client_reference (= our payment id)
  const { data: payment } = await supabase
    .from("payments")
    .select("*")
    .eq("id", clientRef)
    .single();

  if (!payment) {
    // Try by external_id
    const { data: paymentByExt } = await supabase
      .from("payments")
      .select("*")
      .eq("external_id", clientRef)
      .single();

    if (!paymentByExt) {
      console.error("[webhook-payment] Wave payment not found:", clientRef);
      return jsonResponse({ error: "Payment not found" }, 404);
    }
    return processWaveResult(supabase, paymentByExt, paymentStatus, payload);
  }

  return processWaveResult(supabase, payment, paymentStatus, payload);
}

async function processWaveResult(
  supabase: ReturnType<typeof getSupabaseAdmin>,
  payment: Record<string, unknown>,
  paymentStatus: string,
  payload: Record<string, unknown>,
) {
  if (paymentStatus === "succeeded") {
    await supabase.from("payments").update({
      status: "completed",
      completed_at: new Date().toISOString(),
      metadata: payload,
      updated_at: new Date().toISOString(),
    }).eq("id", payment.id);

    return activateSubscription(
      supabase,
      payment.user_id as string,
      payment.plan as string,
      payment.id as string,
      "wave",
      null,
      payment.amount as number,
    );
  } else if (paymentStatus === "failed" || paymentStatus === "expired") {
    await supabase.from("payments").update({
      status: "failed",
      metadata: payload,
      updated_at: new Date().toISOString(),
    }).eq("id", payment.id);

    return jsonResponse({ received: true, status: "failed" });
  }

  return jsonResponse({ received: true, status: "pending" });
}

// ────────────────────────────────────────────────────────────
// CinetPay Callback (legacy)
// ────────────────────────────────────────────────────────────
async function handleCinetpayCallback(
  payload: Record<string, unknown>,
  rawBody: string,
  req: Request,
) {
  const supabase = getSupabaseAdmin();
  const cinetpaySecret = Deno.env.get("CINETPAY_SECRET");

  if (!cinetpaySecret) {
    console.error("[webhook-payment] Missing CINETPAY_SECRET");
    return jsonResponse({ error: "Server configuration error" }, 500);
  }

  const signature = req.headers.get("X-Cinetpay-Signature") ?? (payload.signature as string);
  if (!signature) {
    return jsonResponse({ error: "Missing signature" }, 401);
  }

  const isValid = await verifyHmacSignature(rawBody, signature, cinetpaySecret);
  if (!isValid) {
    console.warn("[webhook-payment] CinetPay invalid signature");
    return jsonResponse({ error: "Invalid signature" }, 401);
  }

  if (payload.cpm_result !== "00" || payload.cpm_trans_status !== "ACCEPTED") {
    console.log(`[webhook-payment] CinetPay payment refused: ${payload.cpm_trans_id}`);
    await supabase
      .from("subscriptions")
      .update({ status: "cancelled" })
      .eq("payment_ref", payload.cpm_trans_id as string)
      .eq("status", "pending");
    return jsonResponse({ received: true, status: "refused" });
  }

  let customData: { user_id: string; plan: string };
  try {
    customData = JSON.parse(payload.cpm_custom as string);
  } catch {
    return jsonResponse({ error: "Invalid custom data" }, 400);
  }

  return activateSubscription(
    supabase,
    customData.user_id,
    customData.plan,
    payload.cpm_trans_id as string,
    "cinetpay",
    null,
    parseInt(payload.cpm_amount as string, 10),
  );
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
  const durationDays = PLAN_DURATIONS[plan];
  if (!durationDays) {
    return jsonResponse({ error: "Invalid plan" }, 400);
  }

  const startDate = new Date();
  let subEndDate = new Date(startDate.getTime() + durationDays * 86_400_000);

  // Check for existing active subscription (extension)
  const { data: existingSub } = await supabase
    .from("subscriptions")
    .select("id, end_date")
    .eq("user_id", userId)
    .eq("status", "active")
    .order("end_date", { ascending: false })
    .limit(1)
    .single();

  let subStartDate = startDate;
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

  // Update user plan to the subscription tier
  const { error: userError } = await supabase
    .from("users")
    .update({ plan })
    .eq("id", userId);

  if (userError) {
    console.error("[webhook-payment] Failed to update user plan:", userError);
  }

  console.log(`[webhook-payment] ✅ Subscription activated: user=${userId}, plan=${plan}, provider=${provider}, end=${subEndDate.toISOString()}`);
  return jsonResponse({
    received: true,
    status: "activated",
    end_date: subEndDate.toISOString(),
  });
}

// ────────────────────────────────────────────────────────────
// HMAC-SHA256 verification (for CinetPay)
// ────────────────────────────────────────────────────────────
async function verifyHmacSignature(
  body: string,
  signature: string,
  secret: string,
): Promise<boolean> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const sigBytes = new Uint8Array(signature.length / 2);
  for (let i = 0; i < signature.length; i += 2) {
    sigBytes[i / 2] = parseInt(signature.slice(i, i + 2), 16);
  }
  return crypto.subtle.verify("HMAC", key, sigBytes, encoder.encode(body));
}
