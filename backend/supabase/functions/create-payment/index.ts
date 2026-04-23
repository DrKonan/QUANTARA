// ============================================================
// NAKORA — Edge Function : create-payment
// Crée un paiement PawaPay (deposit) ou Wave (checkout session)
// Appelé depuis l'app Flutter.
// ============================================================
import { getSupabaseAdmin } from "../_shared/supabase.ts";
import { jsonResponse } from "../_shared/helpers.ts";

const PLAN_AMOUNTS: Record<string, number> = {
  starter: 1000,
  pro: 2000,
  vip: 4000,
};

const PLAN_DURATIONS: Record<string, number> = {
  starter: 30,
  pro: 30,
  vip: 30,
};

// Valid PawaPay correspondent codes (app sends these directly)
const VALID_CORRESPONDENTS = new Set([
  // Côte d'Ivoire (XOF)
  "ORANGE_CIV", "MTN_MOMO_CIV",
  // Sénégal (XOF)
  "ORANGE_SEN", "FREE_SEN",
  // Mali (XOF)
  "ORANGE_MLI", "MOOV_MLI",
  // Burkina Faso (XOF)
  "ORANGE_BFA", "MOOV_BFA",
  // Bénin (XOF)
  "MTN_MOMO_BEN", "MOOV_BEN",
  // Togo (XOF)
  "MOOV_TGO",
  // Niger (XOF)
  "AIRTEL_NER",
  // Guinée (GNF)
  "ORANGE_GIN", "MTN_MOMO_GIN",
  // Cameroun (XAF)
  "ORANGE_CMR", "MTN_MOMO_CMR",
  // Gabon (XAF)
  "AIRTEL_GAB",
  // Congo-Brazzaville (XAF)
  "MTN_MOMO_COG", "AIRTEL_COG",
  // RD Congo (CDF)
  "VODACOM_COD", "ORANGE_COD", "AIRTEL_COD",
]);

// Map correspondent to currency
function getCurrencyForCorrespondent(correspondent: string): string {
  if (correspondent.endsWith("_CMR") || correspondent.endsWith("_GAB") || correspondent.endsWith("_COG")) {
    return "XAF";
  }
  if (correspondent.endsWith("_COD")) {
    return "CDF";
  }
  if (correspondent.endsWith("_GIN")) {
    return "GNF";
  }
  return "XOF"; // UEMOA countries
}

// Currency multipliers relative to XOF base prices (rounded)
const CURRENCY_MULTIPLIERS: Record<string, number> = {
  XOF: 1,
  XAF: 1,    // 1:1 parity with XOF
  GNF: 14,   // 1000 XOF ≈ 14000 GNF
  CDF: 3.5,  // 1000 XOF ≈ 3500 CDF
};

function getAmountInCurrency(baseAmount: number, currency: string): number {
  const mult = CURRENCY_MULTIPLIERS[currency] ?? 1;
  const raw = baseAmount * mult;
  return Math.round(raw / 500) * 500 || raw; // round to nearest 500
}

interface CreatePaymentRequest {
  plan: string;          // 'starter' | 'pro' | 'vip'
  provider: string;      // 'wave' | 'pawapay'
  phone?: string;        // Required for PawaPay (MSISDN format)
  correspondent?: string; // PawaPay correspondent code (e.g. 'ORANGE_CIV', 'MTN_MOMO_CMR')
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
    return jsonResponse({ error: "Invalid plan. Use: starter, pro, vip" }, 400);
  }

  // Validate provider
  if (!provider || !["wave", "pawapay"].includes(provider)) {
    return jsonResponse({ error: "Invalid provider. Use: wave or pawapay" }, 400);
  }

  const baseAmount = PLAN_AMOUNTS[plan];
  const paymentId = crypto.randomUUID();

  try {
    if (provider === "wave") {
      // Wave uses XOF only
      return await handleWavePayment(supabase, user.id, plan, baseAmount, paymentId);
    } else {
      // PawaPay: convert to the correspondent's currency
      const currency = correspondent ? getCurrencyForCorrespondent(correspondent) : "XOF";
      const amount = getAmountInCurrency(baseAmount, currency);
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
  if (!correspondentKey || !VALID_CORRESPONDENTS.has(correspondentKey)) {
    return jsonResponse({ error: `Invalid correspondent: ${correspondentKey}` }, 400);
  }

  const pawapayToken = Deno.env.get("PAWAPAY_API_TOKEN");
  const pawapayBaseUrl = Deno.env.get("PAWAPAY_BASE_URL") || "https://api.sandbox.pawapay.io";

  if (!pawapayToken) {
    console.error("[create-payment] Missing PAWAPAY_API_TOKEN");
    return jsonResponse({ error: "PawaPay not configured" }, 500);
  }

  const correspondent = correspondentKey;
  const currency = getCurrencyForCorrespondent(correspondent);
  const msisdn = phone.startsWith("+") ? phone.slice(1) : phone.replace(/\s/g, "");

  const depositPayload = {
    depositId: paymentId,
    amount: amount.toString(),
    currency,
    correspondent,
    payer: {
      type: "MSISDN",
      address: { value: msisdn },
    },
    customerTimestamp: new Date().toISOString(),
    statementDescription: `Nakora ${plan}`,
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
    currency,
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
