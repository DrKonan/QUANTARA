// ============================================================
// NAKORA — Edge Function : create-payment
// Crée un paiement PayDunya (checkout hébergé) ou Wave direct.
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

function getAmountInCurrency(baseAmount: number, currency: string): number {
  const mult = CURRENCY_MULTIPLIERS[currency] ?? 1;
  const raw = baseAmount * mult;
  return Math.round(raw / 500) * 500 || raw;
}

interface CreatePaymentRequest {
  plan: string;       // 'starter' | 'pro' | 'vip'
  provider: string;   // 'paydunya' | 'wave'
  currency?: string;  // 'XOF' (default) | 'XAF' | 'GNF' | 'CDF'
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

  const { plan, provider, currency = "XOF" } = body;

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
      return await handleWavePayment(supabase, user.id, plan, baseAmount, paymentId);
    } else {
      return await handlePaydunyaPayment(supabase, user.id, plan, amount, paymentId, currency);
    }
  } catch (err) {
    console.error("[create-payment] Error:", err);
    return jsonResponse({ error: "Payment creation failed" }, 500);
  }
});

// ─── PayDunya Checkout ────────────────────────────────────────
async function handlePaydunyaPayment(
  supabase: ReturnType<typeof getSupabaseAdmin>,
  userId: string,
  plan: string,
  amount: number,
  paymentId: string,
  currency: string,
) {
  const masterKey = Deno.env.get("PAYDUNYA_MASTER_KEY");
  const privateKey = Deno.env.get("PAYDUNYA_PRIVATE_KEY");
  const token = Deno.env.get("PAYDUNYA_TOKEN");

  if (!masterKey || !privateKey || !token) {
    console.error("[create-payment] Missing PayDunya credentials");
    return jsonResponse({ error: "PayDunya not configured" }, 500);
  }

  const baseUrl = Deno.env.get("APP_BASE_URL") || "https://epiaxzyzrclebutxvbgp.supabase.co";
  const planLabel = ({ starter: "Starter", pro: "Pro", vip: "VIP" } as Record<string, string>)[plan] ?? plan;

  const pdResponse = await fetch("https://app.paydunya.com/api/v1/checkout-invoice/create", {
    method: "POST",
    headers: {
      "PAYDUNYA-MASTER-KEY": masterKey,
      "PAYDUNYA-PRIVATE-KEY": privateKey,
      "PAYDUNYA-TOKEN": token,
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

  if (!pdResponse.ok) {
    const errText = await pdResponse.text();
    console.error("[create-payment] PayDunya API error:", errText);
    return jsonResponse({ error: "PayDunya payment creation failed" }, 502);
  }

  const pdData = await pdResponse.json();

  if (pdData.response_code !== "00") {
    console.error("[create-payment] PayDunya error:", pdData);
    return jsonResponse({ error: pdData.response_text ?? "PayDunya error" }, 502);
  }

  await supabase.from("payments").insert({
    id: paymentId,
    user_id: userId,
    provider: "paydunya",
    external_id: pdData.token,
    plan,
    amount,
    currency,
    status: "pending",
  });

  console.log(`[create-payment] PayDunya invoice created: ${pdData.token} for user ${userId}`);

  return jsonResponse({
    payment_id: paymentId,
    checkout_url: `https://app.paydunya.com/checkout-invoice/confirm/${pdData.token}`,
  });
}

// ─── Wave Checkout (direct) ───────────────────────────────────
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

  await supabase.from("payments").insert({
    id: paymentId,
    user_id: userId,
    provider: "wave",
    external_id: waveData.id ?? paymentId,
    plan,
    amount,
    currency: "XOF",
    status: "pending",
  });

  return jsonResponse({
    payment_id: paymentId,
    checkout_url: waveData.wave_launch_url,
  });
}
