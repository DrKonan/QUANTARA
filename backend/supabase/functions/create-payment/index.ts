// ============================================================
// NAKORA — Edge Function : create-payment
// Crée un paiement PayDunya (SoftPay ou checkout page).
// Chaque opérateur a ses propres noms de champs — doc officielle :
// https://developers.paydunya.com/doc/FR/softpay
// ============================================================
import { getSupabaseAdmin } from "../_shared/supabase.ts";
import { jsonResponse } from "../_shared/helpers.ts";

const PLAN_AMOUNTS: Record<string, number> = {
  starter: 200, // TEST — remettre à 1000 avant production
  pro: 2000,
  vip: 4000,
};

const CURRENCY_MULTIPLIERS: Record<string, number> = {
  XOF: 1,
  XAF: 1,
  GNF: 14,
  CDF: 3.5,
};

// ── SoftPay config per operator ──────────────────────────────
// 'resultType':
//   'url'  → response contains a URL/deep link to open in the app
//   'ussd' → USSD push / SMS confirmation sent to the user
//   'otp'  → user must generate an OTP first — skip SoftPay, use checkout
type SoftPayResultType = "url" | "ussd" | "otp";

interface SoftPayConfig {
  slug: string;
  resultType: SoftPayResultType;
  dialCode: string; // to extract local number from E.164
  buildBody: (token: string, phone: string, name: string) => Record<string, string>;
}

const SOFTPAY: Record<string, SoftPayConfig> = {
  // ── Sénégal ──
  orange_sn: {
    slug: "new-orange-money-senegal",
    resultType: "url",
    dialCode: "221",
    buildBody: (token, phone, name) => ({
      customer_name: name,
      customer_email: "user@nakora.app",
      phone_number: phone,
      invoice_token: token,
    }),
  },
  wave_sn: {
    slug: "wave-senegal",
    resultType: "url",
    dialCode: "221",
    buildBody: (token, phone, name) => ({
      wave_senegal_fullName: name,
      wave_senegal_email: "user@nakora.app",
      wave_senegal_phone: phone,
      wave_senegal_payment_token: token,
    }),
  },
  free_sn: {
    slug: "free-money-senegal",
    resultType: "ussd",
    dialCode: "221",
    buildBody: (token, phone, name) => ({
      customer_name: name,
      customer_email: "user@nakora.app",
      phone_number: phone,
      payment_token: token,
    }),
  },
  // ── Côte d'Ivoire ──
  wave_ci: {
    slug: "wave-ci",
    resultType: "url",
    dialCode: "225",
    buildBody: (token, phone, name) => ({
      wave_ci_fullName: name,
      wave_ci_email: "user@nakora.app",
      wave_ci_phone: phone,
      wave_ci_payment_token: token,
    }),
  },
  // orange_ci and moov_ci require OTP → checkout fallback
  mtn_ci: {
    slug: "mtn-ci",
    resultType: "ussd",
    dialCode: "225",
    buildBody: (token, phone, name) => ({
      mtn_ci_customer_fullname: name,
      mtn_ci_email: "user@nakora.app",
      mtn_ci_phone_number: phone,
      mtn_ci_wallet_provider: "MTNCI",
      payment_token: token,
    }),
  },
  // ── Burkina Faso ──
  moov_bf: {
    slug: "moov-burkina",
    resultType: "ussd",
    dialCode: "226",
    buildBody: (token, phone, name) => ({
      moov_burkina_faso_fullName: name,
      moov_burkina_faso_email: "user@nakora.app",
      moov_burkina_faso_phone_number: phone,
      moov_burkina_faso_payment_token: token,
    }),
  },
  // orange_bf requires OTP → checkout fallback
  // ── Mali ──
  orange_ml: {
    slug: "orange-money-mali",
    resultType: "ussd",
    dialCode: "223",
    buildBody: (token, phone, name) => ({
      orange_money_mali_customer_fullname: name,
      orange_money_mali_email: "user@nakora.app",
      orange_money_mali_phone_number: phone,
      orange_money_mali_customer_address: "N/A",
      payment_token: token,
    }),
  },
  moov_ml: {
    slug: "moov-mali",
    resultType: "ussd",
    dialCode: "223",
    buildBody: (token, phone, name) => ({
      moov_ml_customer_fullname: name,
      moov_ml_email: "user@nakora.app",
      moov_ml_phone_number: phone,
      moov_ml_customer_address: "N/A",
      payment_token: token,
    }),
  },
  // ── Bénin ──
  mtn_bj: {
    slug: "mtn-benin",
    resultType: "ussd",
    dialCode: "229",
    buildBody: (token, phone, name) => ({
      mtn_benin_customer_fullname: name,
      mtn_benin_email: "user@nakora.app",
      mtn_benin_phone_number: phone,
      mtn_benin_wallet_provider: "MTNBENIN",
      payment_token: token,
    }),
  },
  moov_bj: {
    slug: "moov-benin",
    resultType: "ussd",
    dialCode: "229",
    buildBody: (token, phone, name) => ({
      moov_benin_customer_fullname: name,
      moov_benin_email: "user@nakora.app",
      moov_benin_phone_number: phone,
      payment_token: token,
    }),
  },
  // ── Togo ──
  tmoney_tg: {
    slug: "t-money-togo",
    resultType: "ussd",
    dialCode: "228",
    buildBody: (token, phone, name) => ({
      name_t_money: name,
      email_t_money: "user@nakora.app",
      phone_t_money: phone,
      payment_token: token,
    }),
  },
  moov_tg: {
    slug: "moov-togo",
    resultType: "ussd",
    dialCode: "228",
    buildBody: (token, phone, name) => ({
      moov_togo_customer_fullname: name,
      moov_togo_email: "user@nakora.app",
      moov_togo_customer_address: "N/A",
      moov_togo_phone_number: phone,
      payment_token: token,
    }),
  },
  // ── Cameroun ──
  mtn_cm: {
    slug: "mtn-cameroun",
    resultType: "ussd",
    dialCode: "237",
    buildBody: (token, phone, name) => ({
      mtn_cameroun_customer_fullname: name,
      mtn_cameroun_email: "user@nakora.app",
      mtn_cameroun_phone_number: phone,
      mtn_cameroun_wallet_provider: "MTNCAMEROUN",
      payment_token: token,
    }),
  },
};

const METHOD_NAMES: Record<string, string> = {
  orange_sn: "Orange Money", orange_ci: "Orange Money",
  orange_ml: "Orange Money", orange_bf: "Orange Money",
  orange_cm: "Orange Money",
  wave_sn: "Wave", wave_ci: "Wave",
  mtn_ci: "MTN Money", mtn_cm: "MTN Money",
  mtn_bj: "MTN Money",
  free_sn: "Free Money",
  moov_bf: "Moov Money", moov_ci: "Moov Money",
  moov_bj: "Moov Money", moov_tg: "Moov Money", moov_ml: "Moov Money",
  tmoney_tg: "T-Money",
};

function extractLocalPhone(phone: string, dialCode: string): string {
  const clean = phone.replace(/^\+/, "");
  return clean.startsWith(dialCode) ? clean.substring(dialCode.length) : clean;
}

function getAmountInCurrency(baseAmount: number, currency: string): number {
  const mult = CURRENCY_MULTIPLIERS[currency] ?? 1;
  const raw = baseAmount * mult;
  return Math.round(raw / 500) * 500 || raw;
}

interface CreatePaymentRequest {
  plan: string;             // 'starter' | 'pro' | 'vip'
  provider: string;         // always 'paydunya' now
  currency?: string;        // 'XOF' (default) | 'XAF' | 'GNF' | 'CDF'
  phone?: string;           // Full phone in E.164 e.g. '+221XXXXXXXXX'
  payment_method?: string;  // Method id e.g. 'orange_sn', 'wave_sn'
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

  const { plan, currency = "XOF", phone, payment_method } = body;

  if (!plan || !PLAN_AMOUNTS[plan]) {
    return jsonResponse({ error: "Invalid plan. Use: starter, pro, vip" }, 400);
  }

  const baseAmount = PLAN_AMOUNTS[plan];
  const amount = getAmountInCurrency(baseAmount, currency);
  const paymentId = crypto.randomUUID();

  try {
    return await handlePayment(supabase, user.id, plan, amount, paymentId, currency, phone, payment_method);
  } catch (err) {
    console.error("[create-payment] Error:", err);
    return jsonResponse({ error: "Payment creation failed" }, 500);
  }
});

// ─── Unified payment handler ─────────────────────────────────
// All operators go through PayDunya:
// - Wave SN/CI → SoftPay → pay.wave.com URL
// - Orange SN → SoftPay new-orange-money-senegal → om_url deep link
// - Other supported ops → SoftPay USSD push (SMS confirmation)
// - OTP/unsupported ops → PayDunya checkout page (user picks operator)
async function handlePayment(
  supabase: ReturnType<typeof getSupabaseAdmin>,
  userId: string,
  plan: string,
  amount: number,
  paymentId: string,
  currency: string,
  phone?: string,
  paymentMethod?: string,
) {
  const masterKey = Deno.env.get("PAYDUNYA_MASTER_KEY");
  const privateKey = Deno.env.get("PAYDUNYA_PRIVATE_KEY");
  const publicKey  = Deno.env.get("PAYDUNYA_PUBLIC_KEY");
  const pdToken    = Deno.env.get("PAYDUNYA_TOKEN");

  if (!masterKey || !privateKey || !pdToken) {
    console.error("[create-payment] Missing PayDunya credentials");
    return jsonResponse({ error: "PayDunya not configured" }, 500);
  }

  const baseUrl = Deno.env.get("APP_BASE_URL") || "https://epiaxzyzrclebutxvbgp.supabase.co";
  const planLabel = ({ starter: "Starter", pro: "Pro", vip: "VIP" } as Record<string, string>)[plan] ?? plan;

  const pdHeaders = {
    "PAYDUNYA-MASTER-KEY":  masterKey,
    "PAYDUNYA-PRIVATE-KEY": privateKey,
    "PAYDUNYA-PUBLIC-KEY":  publicKey ?? "",
    "PAYDUNYA-TOKEN":       pdToken,
    "Content-Type": "application/json",
  };

  // Step 1 — Create PayDunya invoice
  const invoiceResponse = await fetch("https://app.paydunya.com/api/v1/checkout-invoice/create", {
    method: "POST",
    headers: pdHeaders,
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
        cancel_url: `nakora://payment?status=cancel&payment_id=${paymentId}`,
        return_url: `nakora://payment?status=success&payment_id=${paymentId}`,
        callback_url: `${baseUrl}/functions/v1/webhook-payment`,
      },
      custom_data: { payment_id: paymentId, user_id: userId, plan },
    }),
  });

  if (!invoiceResponse.ok) {
    const errText = await invoiceResponse.text();
    console.error("[create-payment] PayDunya invoice error:", errText);
    return jsonResponse({ error: "PayDunya invoice creation failed" }, 502);
  }

  const invoiceData = await invoiceResponse.json();
  console.log("[create-payment] PayDunya invoice response:", JSON.stringify(invoiceData));

  if (invoiceData.response_code !== "00") {
    console.error("[create-payment] PayDunya invoice error:", invoiceData);
    return jsonResponse({ error: invoiceData.response_text ?? "PayDunya error" }, 502);
  }

  const invoiceToken: string = invoiceData.token ?? invoiceData.invoice_token;

  // PayDunya returns the checkout URL directly in response_text when response_code === "00"
  // e.g. "https://paydunya.com/checkout/invoice/{token}"
  const checkoutFallback: string =
    (typeof invoiceData.response_text === "string" && invoiceData.response_text.startsWith("http"))
      ? invoiceData.response_text
      : `https://paydunya.com/checkout/invoice/${invoiceToken}`;

  // Step 2 — Try SoftPay if operator config exists and phone is provided
  let checkoutUrl = checkoutFallback;
  let paymentType: "redirect" | "ussd" = "redirect";
  let ussdMessage: string | undefined;

  const cfg = paymentMethod ? SOFTPAY[paymentMethod] : undefined;

  if (cfg && phone) {
    const localPhone = extractLocalPhone(phone, cfg.dialCode);
    const body = cfg.buildBody(invoiceToken, localPhone, "Nakora User");

    console.log(`[create-payment] SoftPay ${cfg.slug}: phone=${localPhone}, body keys=${Object.keys(body).join(",")}`);

    const spResp = await fetch(`https://app.paydunya.com/api/v1/softpay/${cfg.slug}`, {
      method: "POST",
      headers: pdHeaders,
      body: JSON.stringify(body),
    });

    const spText = await spResp.text();

    if (!spResp.ok) {
      console.warn(`[create-payment] SoftPay HTTP ${spResp.status} for ${cfg.slug}: ${spText.substring(0, 200)} — using checkout`);
    } else {
      try {
        const spData = JSON.parse(spText);
        if (spData?.success === true) {
          if (cfg.resultType === "url") {
            // Wave / Orange SN return a URL to open directly
            checkoutUrl =
              spData.other_url?.om_url ??
              spData.other_url?.maxit_url ??
              spData.url ??
              checkoutFallback;
          } else {
            // USSD push sent — show confirmation message to user
            paymentType = "ussd";
            ussdMessage = spData.message;
            checkoutUrl = checkoutFallback; // not used for USSD but keep as fallback
          }
          console.log(`[create-payment] SoftPay OK ${cfg.slug}: type=${cfg.resultType}, url=${checkoutUrl}`);
        } else {
          console.warn(`[create-payment] SoftPay error ${cfg.slug}: ${spText} — using checkout`);
        }
      } catch {
        console.warn(`[create-payment] SoftPay non-JSON ${cfg.slug} — using checkout`);
      }
    }
  } else if (!cfg) {
    console.log(`[create-payment] No SoftPay config for ${paymentMethod ?? "unknown"} — checkout page`);
  }

  const { error: insertError } = await supabase.from("payments").insert({
    id: paymentId,
    user_id: userId,
    provider: "paydunya",
    external_id: invoiceToken,
    plan,
    amount,
    currency,
    status: "pending",
    payment_method: paymentMethod ?? "unknown",
    phone: phone ?? null,
  });

  if (insertError) {
    console.error("[create-payment] Failed to insert payment row:", insertError);
    return jsonResponse({ error: "Database error — payment not recorded" }, 500);
  }

  console.log(`[create-payment] Done: method=${paymentMethod}, type=${paymentType}, invoice=${invoiceToken}, payment_id=${paymentId}`);

  return jsonResponse({
    payment_id: paymentId,
    checkout_url: paymentType === "redirect" ? checkoutUrl : undefined,
    payment_type: paymentType,
    payment_method_name: METHOD_NAMES[paymentMethod ?? ""] ?? paymentMethod ?? "Mobile Money",
    ussd_message: ussdMessage,
  });
}
