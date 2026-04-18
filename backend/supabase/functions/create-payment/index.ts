// ============================================================
// QUANTARA — Edge Function : create-payment
// Crée un paiement PawaPay (deposit) ou Wave (checkout session)
// Appelé depuis l'app Flutter.
// ============================================================
import { getSupabaseAdmin } from "../_shared/supabase.ts";
import { jsonResponse } from "../_shared/helpers.ts";

const PLAN_AMOUNTS: Record<string, number> = {
  weekly: 990,
  monthly: 2990,
  yearly: 24990,
};

const PLAN_DURATIONS: Record<string, number> = {
  weekly: 7,
  monthly: 30,
  yearly: 365,
};

// PawaPay correspondents for Côte d'Ivoire
const PAWAPAY_CORRESPONDENTS: Record<string, string> = {
  orange_ci: "ORANGE_CIV",
  mtn_ci: "MTN_MOMO_CIV",
};

interface CreatePaymentRequest {
  plan: string;          // 'weekly' | 'monthly' | 'yearly'
  provider: string;      // 'wave' | 'pawapay'
  phone?: string;        // Required for PawaPay (MSISDN format)
  correspondent?: string; // 'orange_ci' | 'mtn_ci' — required for PawaPay
}

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

  // Auth: get user from JWT
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "Missing authorization" }, 401);
  }

  const supabase = getSupabaseAdmin();

  // Verify user JWT
  const token = authHeader.replace("Bearer ", "");
  const { data: { user }, error: authError } = await supabase.auth.getUser(token);
  if (authError || !user) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  let body: CreatePaymentRequest;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON" }, 400);
  }

  const { plan, provider, phone, correspondent } = body;

  // Validate plan
  if (!plan || !PLAN_AMOUNTS[plan]) {
    return jsonResponse({ error: "Invalid plan. Use: weekly, monthly, yearly" }, 400);
  }

  // Validate provider
  if (!provider || !["wave", "pawapay"].includes(provider)) {
    return jsonResponse({ error: "Invalid provider. Use: wave or pawapay" }, 400);
  }

  const amount = PLAN_AMOUNTS[plan];
  const paymentId = crypto.randomUUID();

  try {
    if (provider === "wave") {
      return await handleWavePayment(supabase, user.id, plan, amount, paymentId);
    } else {
      return await handlePawapayPayment(supabase, user.id, plan, amount, paymentId, phone, correspondent);
    }
  } catch (err) {
    console.error("[create-payment] Error:", err);
    return jsonResponse({ error: "Payment creation failed" }, 500);
  }
});

// ─── Wave Checkout ───────────────────────────────────────────
async function handleWavePayment(
  supabase: ReturnType<typeof getSupabaseAdmin>,
  userId: string,
  plan: string,
  amount: number,
  paymentId: string,
) {
  const waveApiKey = Deno.env.get("WAVE_API_KEY");
  if (!waveApiKey) {
    console.error("[create-payment] Missing WAVE_API_KEY");
    return jsonResponse({ error: "Wave not configured" }, 500);
  }

  const baseUrl = Deno.env.get("APP_BASE_URL") || "https://epiaxzyzrclebutxvbgp.supabase.co";

  // Create Wave checkout session
  const waveResponse = await fetch("https://api.wave.com/v1/checkout/sessions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${waveApiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      amount: amount.toString(),
      currency: "XOF",
      error_url: `${baseUrl}/functions/v1/payment-redirect?status=error&payment_id=${paymentId}`,
      success_url: `${baseUrl}/functions/v1/payment-redirect?status=success&payment_id=${paymentId}`,
      client_reference: paymentId,
    }),
  });

  if (!waveResponse.ok) {
    const errText = await waveResponse.text();
    console.error("[create-payment] Wave API error:", errText);
    return jsonResponse({ error: "Wave payment creation failed" }, 502);
  }

  const waveData = await waveResponse.json();

  // Store payment record
  await supabase.from("payments").insert({
    id: paymentId,
    user_id: userId,
    provider: "wave",
    external_id: waveData.id || paymentId,
    plan,
    amount,
    currency: "XOF",
    status: "pending",
  });

  return jsonResponse({
    payment_id: paymentId,
    provider: "wave",
    checkout_url: waveData.wave_launch_url,
    session_id: waveData.id,
  });
}

// ─── PawaPay Deposit ─────────────────────────────────────────
async function handlePawapayPayment(
  supabase: ReturnType<typeof getSupabaseAdmin>,
  userId: string,
  plan: string,
  amount: number,
  paymentId: string,
  phone?: string,
  correspondentKey?: string,
) {
  if (!phone) {
    return jsonResponse({ error: "Phone number required for PawaPay" }, 400);
  }
  if (!correspondentKey || !PAWAPAY_CORRESPONDENTS[correspondentKey]) {
    return jsonResponse({ error: "Invalid correspondent. Use: orange_ci or mtn_ci" }, 400);
  }

  const pawapayToken = Deno.env.get("PAWAPAY_API_TOKEN");
  const pawapayBaseUrl = Deno.env.get("PAWAPAY_BASE_URL") || "https://api.sandbox.pawapay.io";

  if (!pawapayToken) {
    console.error("[create-payment] Missing PAWAPAY_API_TOKEN");
    return jsonResponse({ error: "PawaPay not configured" }, 500);
  }

  const correspondent = PAWAPAY_CORRESPONDENTS[correspondentKey];
  const msisdn = phone.startsWith("+") ? phone.slice(1) : phone.replace(/\s/g, "");

  const depositPayload = {
    depositId: paymentId,
    amount: amount.toString(),
    currency: "XOF",
    correspondent,
    payer: {
      type: "MSISDN",
      address: { value: msisdn },
    },
    customerTimestamp: new Date().toISOString(),
    statementDescription: `Quantara ${plan}`,
  };

  const ppResponse = await fetch(`${pawapayBaseUrl}/deposits`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${pawapayToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(depositPayload),
  });

  if (!ppResponse.ok) {
    const errText = await ppResponse.text();
    console.error("[create-payment] PawaPay API error:", ppResponse.status, errText);
    return jsonResponse({ error: "PawaPay payment creation failed" }, 502);
  }

  const ppData = await ppResponse.json();

  // Store payment record
  await supabase.from("payments").insert({
    id: paymentId,
    user_id: userId,
    provider: "pawapay",
    external_id: paymentId,
    plan,
    amount,
    currency: "XOF",
    correspondent,
    status: ppData.status === "ACCEPTED" ? "submitted" : "pending",
  });

  return jsonResponse({
    payment_id: paymentId,
    provider: "pawapay",
    status: ppData.status,
    correspondent,
    message: "Un push USSD a été envoyé sur votre téléphone. Entrez votre code PIN pour confirmer.",
  });
}
