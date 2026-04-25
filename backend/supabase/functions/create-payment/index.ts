// ============================================================
// NAKORA — Edge Function : create-payment
// Crée un paiement Wave (direct) ou PayDunya (SoftPay USSD).
// Appelé depuis l'app Flutter.
// ============================================================
import { getSupabaseAdmin } from "../_shared/supabase.ts";
import { jsonResponse } from "../_shared/helpers.ts";

// Base prices in XOF
const PLAN_AMOUNTS: Record<string, number> = {
  starter: 1000,
  pro: 2000,
  vip: 4000,
};

// Currency multipliers relative to XOF base prices
const CURRENCY_MULTIPLIERS: Record<string, number> = {
  XOF: 1,
  XAF: 1,    // 1:1 parity with XOF
  GNF: 14,   // 1000 XOF ≈ 14000 GNF
  CDF: 3.5,  // 1000 XOF ≈ 3500 CDF
};

// PayDunya SoftPay network codes
const SOFTPAY_NETWORK_CODES: Record<string, string> = {
  orange_sn:  "orange-money-senegal",
  orange_ci:  "orange-money-cote-divoire",
  orange_ml:  "orange-money-mali",
  orange_bf:  "orange-money-burkina",
  orange_gn:  "orange-money-guinee",
  orange_cm:  "orange-money-cameroun",
  mtn_ci:     "mtn-cote-divoire",
  mtn_cm:     "mtn-cameroun",
  mtn_bj:     "mtn-benin",
  mtn_gn:     "mtn-guinee",
  mtn_cd:     "mtn-congo",
  free_sn:    "free-money-senegal",
  moov_bf:    "moov-money-burkina",
  moov_ci:    "moov-money-cote-divoire",
  moov_bj:    "moov-money-benin",
  moov_tg:    "moov-money-togo",
  moov_ne:    "moov-money-niger",
  airtel_cd:  "airtel-money-congo",
  tmoney_tg:  "tmoney-togo",
};

function getAmountInCurrency(baseAmount: number, currency: string): number {
  const mult = CURRENCY_MULTIPLIERS[currency] ?? 1;
  const raw = baseAmount * mult;
  return Math.round(raw / 500) * 500 || raw;
}

interface CreatePaymentRequest {
  plan: string;             // 'starter' | 'pro' | 'vip'
  provider: string;         // 'paydunya' | 'wave'
  currency?: string;        // 'XOF' (default) | 'XAF' | 'GNF' | 'CDF'
  phone?: string;           // Full phone with dial code e.g. '+221XXXXXXXXX' (USSD only)
  payment_method?: string;  // Method id e.g. 'orange_sn', 'mtn_ci', 'wave_sn'
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

  let body: CreatePaymentRequest;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON" }, 400);
  }

  const { plan, provider, currency = "XOF", phone, payment_method } = body;

  if (!plan || !PLAN_AMOUNTS[plan]) {
    return jsonResponse({ error: "Invalid plan. Use: starter, pro, vip" }, 400);
  }
  if (!provider || !["paydunya", "wave"].includes(provider)) {
    return jsonResponse({ error: "Invalid provider. Use: paydunya or wave" }, 400);
  }

  const baseAmount = PLAN_AMOUNTS[plan];
  const amount = getAmountInCurrency(baseAmount, currency);
  const paymentId = crypto.randomUUID();

  try {
    if (provider === "wave") {
      return await handleWavePayment(supabase, user.id, plan, baseAmount, paymentId, payment_method);
    } else {
      return await handlePaydunyaSoftPay(supabase, user.id, plan, amount, paymentId, currency, phone!, payment_method!);
    }
  } catch (err) {
    console.error("[create-payment] Error:", err);
    return jsonResponse({ error: "Payment creation failed" }, 500);
  }
});

// ─── Wave Checkout via PayDunya ───────────────────────────────
// Wave is integrated into PayDunya — no separate Wave API key needed.
// We create a PayDunya invoice and return the checkout URL which
// includes Wave as a payment option, redirecting to the Wave app.
async function handleWavePayment(
  supabase: ReturnType<typeof getSupabaseAdmin>,
  userId: string,
  plan: string,
  amount: number,
  paymentId: string,
  paymentMethod?: string,
) {
  const masterKey = Deno.env.get("PAYDUNYA_MASTER_KEY");
  const privateKey = Deno.env.get("PAYDUNYA_PRIVATE_KEY");
  const pdToken = Deno.env.get("PAYDUNYA_TOKEN");

  if (!masterKey || !privateKey || !pdToken) {
    console.error("[create-payment] Missing PayDunya credentials for Wave");
    return jsonResponse({ error: "Payment not configured" }, 500);
  }

  const baseUrl = Deno.env.get("APP_BASE_URL") || "https://epiaxzyzrclebutxvbgp.supabase.co";
  const planLabel = ({ starter: "Starter", pro: "Pro", vip: "VIP" } as Record<string, string>)[plan] ?? plan;

  const invoiceResponse = await fetch("https://app.paydunya.com/api/v1/checkout-invoice/create", {
    method: "POST",
    headers: {
      "PAYDUNYA-MASTER-KEY": masterKey,
      "PAYDUNYA-PRIVATE-KEY": privateKey,
      "PAYDUNYA-TOKEN": pdToken,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      invoice: {
        total_amount: amount,
        description: `Nakora ${planLabel} — 30 jours`,
      },
      store: {
        name: "Nakora",
        tagline: "Analyses sportives IA",
      },
      actions: {
        cancel_url: `${baseUrl}/functions/v1/payment-redirect?status=cancel&payment_id=${paymentId}`,
        return_url: `${baseUrl}/functions/v1/payment-redirect?status=success&payment_id=${paymentId}`,
        callback_url: `${baseUrl}/functions/v1/webhook-payment`,
      },
      custom_data: {
        payment_id: paymentId,
        user_id: userId,
        plan,
      },
    }),
  });

  if (!invoiceResponse.ok) {
    const errText = await invoiceResponse.text();
    console.error("[create-payment] PayDunya Wave invoice error:", errText);
    return jsonResponse({ error: "Wave payment creation failed" }, 502);
  }

  const invoiceData = await invoiceResponse.json();
  if (invoiceData.response_code !== "00") {
    console.error("[create-payment] PayDunya Wave invoice error:", invoiceData);
    return jsonResponse({ error: invoiceData.response_text ?? "PayDunya error" }, 502);
  }

  const invoiceToken: string = invoiceData.token;
  const checkoutUrl = `https://app.paydunya.com/checkout/${invoiceToken}`;

  await supabase.from("payments").insert({
    id: paymentId,
    user_id: userId,
    provider: "paydunya",
    external_id: invoiceToken,
    plan,
    amount,
    currency: "XOF",
    status: "pending",
    payment_method: paymentMethod ?? "wave_sn",
  });

  console.log(`[create-payment] Wave via PayDunya: invoice ${invoiceToken}`);

  return jsonResponse({
    payment_id: paymentId,
    checkout_url: checkoutUrl,
    payment_type: "wave",
    payment_method_name: "Wave",
  });
}

// ─── PayDunya SoftPay (USSD push) ────────────────────────────
async function handlePaydunyaSoftPay(
  supabase: ReturnType<typeof getSupabaseAdmin>,
  userId: string,
  plan: string,
  amount: number,
  paymentId: string,
  currency: string,
  phone: string,
  paymentMethod: string,
) {
  if (!phone) {
    return jsonResponse({ error: "Phone number required for USSD payment" }, 400);
  }
  if (!paymentMethod) {
    return jsonResponse({ error: "payment_method required" }, 400);
  }

  const networkCode = SOFTPAY_NETWORK_CODES[paymentMethod];
  if (!networkCode) {
    return jsonResponse({ error: `Unknown payment_method: ${paymentMethod}` }, 400);
  }

  const masterKey = Deno.env.get("PAYDUNYA_MASTER_KEY");
  const privateKey = Deno.env.get("PAYDUNYA_PRIVATE_KEY");
  const pdToken = Deno.env.get("PAYDUNYA_TOKEN");

  if (!masterKey || !privateKey || !pdToken) {
    console.error("[create-payment] Missing PayDunya credentials");
    return jsonResponse({ error: "PayDunya not configured" }, 500);
  }

  const baseUrl = Deno.env.get("APP_BASE_URL") || "https://epiaxzyzrclebutxvbgp.supabase.co";
  const planLabel = ({ starter: "Starter", pro: "Pro", vip: "VIP" } as Record<string, string>)[plan] ?? plan;

  // Step 1 — Create PayDunya invoice
  const invoiceResponse = await fetch("https://app.paydunya.com/api/v1/checkout-invoice/create", {
    method: "POST",
    headers: {
      "PAYDUNYA-MASTER-KEY": masterKey,
      "PAYDUNYA-PRIVATE-KEY": privateKey,
      "PAYDUNYA-TOKEN": pdToken,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      invoice: {
        total_amount: amount,
        description: `Nakora ${planLabel} — 30 jours`,
      },
      store: {
        name: "Nakora",
        tagline: "Analyses sportives IA",
      },
      actions: {
        cancel_url: `${baseUrl}/functions/v1/payment-redirect?status=cancel&payment_id=${paymentId}`,
        return_url: `${baseUrl}/functions/v1/payment-redirect?status=success&payment_id=${paymentId}`,
        callback_url: `${baseUrl}/functions/v1/webhook-payment`,
      },
      custom_data: {
        payment_id: paymentId,
        user_id: userId,
        plan,
      },
    }),
  });

  if (!invoiceResponse.ok) {
    const errText = await invoiceResponse.text();
    console.error("[create-payment] PayDunya invoice error:", errText);
    return jsonResponse({ error: "PayDunya invoice creation failed" }, 502);
  }

  const invoiceData = await invoiceResponse.json();
  if (invoiceData.response_code !== "00") {
    console.error("[create-payment] PayDunya invoice error:", invoiceData);
    return jsonResponse({ error: invoiceData.response_text ?? "PayDunya error" }, 502);
  }

  const invoiceToken: string = invoiceData.token;

  // Step 2 — Trigger SoftPay (USSD push)
  const softPayResponse = await fetch(`https://app.paydunya.com/api/v1/softpay/${networkCode}`, {
    method: "POST",
    headers: {
      "PAYDUNYA-MASTER-KEY": masterKey,
      "PAYDUNYA-PRIVATE-KEY": privateKey,
      "PAYDUNYA-TOKEN": pdToken,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      invoice_token: invoiceToken,
      phone_number: phone.replace(/^\+/, ''), // PayDunya expects no leading '+'
    }),
  });

  if (!softPayResponse.ok) {
    const errText = await softPayResponse.text();
    console.error("[create-payment] PayDunya SoftPay error:", errText);
    return jsonResponse({ error: "USSD push failed" }, 502);
  }

  const softPayData = await softPayResponse.json();
  if (softPayData.response_code !== "00") {
    console.error("[create-payment] SoftPay error:", softPayData);
    return jsonResponse({ error: softPayData.response_text ?? "SoftPay error" }, 502);
  }

  // Format method name for display
  const methodNames: Record<string, string> = {
    orange_sn: "Orange Money", orange_ci: "Orange Money",
    orange_ml: "Orange Money", orange_bf: "Orange Money",
    orange_gn: "Orange Money", orange_cm: "Orange Money",
    mtn_ci: "MTN Mobile Money", mtn_cm: "MTN Mobile Money",
    mtn_bj: "MTN Mobile Money", mtn_gn: "MTN Mobile Money",
    mtn_cd: "MTN Mobile Money",
    free_sn: "Free Money",
    moov_bf: "Moov Money", moov_ci: "Moov Money",
    moov_bj: "Moov Money", moov_tg: "Moov Money", moov_ne: "Moov Money",
    airtel_cd: "Airtel Money",
    tmoney_tg: "T-Money",
  };

  await supabase.from("payments").insert({
    id: paymentId,
    user_id: userId,
    provider: "paydunya",
    external_id: invoiceToken,
    plan,
    amount,
    currency,
    status: "pending",
    payment_method: paymentMethod,
    phone,
  });

  console.log(`[create-payment] SoftPay triggered: ${networkCode} for ${phone}, invoice ${invoiceToken}`);

  return jsonResponse({
    payment_id: paymentId,
    payment_type: "ussd",
    payment_method_name: methodNames[paymentMethod] ?? paymentMethod,
  });
}
