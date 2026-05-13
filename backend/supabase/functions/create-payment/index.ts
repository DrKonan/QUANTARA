// ============================================================
// NAKORA — Edge Function : create-payment
// Crée une invoice PayDunya + appelle SoftPay si disponible.
// Types de retour :
//   deeplink      → URL à ouvrir dans app externe (Wave)
//   ussd          → Push envoyé, utilisateur valide sur téléphone
//   otp_required  → Besoin d'un OTP (Orange CI / Orange BF)
//   redirect      → Page de checkout PayDunya (fallback)
// ============================================================

import { getSupabaseAdmin } from "../_shared/supabase.ts";
import { jsonResponse } from "../_shared/helpers.ts";

const PD_BASE = "https://app.paydunya.com/api/v1";

const PLAN_AMOUNTS: Record<string, number> = {
  starter: 1000,
  pro: 2000,
  vip: 4000,
};

const CURRENCY_MULT: Record<string, number> = {
  XOF: 1, XAF: 1, GNF: 14, CDF: 3.5,
};

type SoftPayResultType = "url" | "ussd" | "otp";

interface SoftPayCfg {
  slug: string;
  resultType: SoftPayResultType;
  dialCode: string;
  buildBody: (token: string, phone: string, otp?: string) => Record<string, string>;
  urlPicker?: (data: Record<string, unknown>) => string | undefined;
}

const SOFTPAY: Record<string, SoftPayCfg> = {
  // ── Sénégal ─────────────────────────────────────────────
  wave_sn: {
    slug: "wave-senegal", resultType: "url", dialCode: "221",
    buildBody: (token, phone) => ({
      wave_senegal_fullName: "Nakora User",
      wave_senegal_email: "user@nakora.app",
      wave_senegal_phone: phone,
      wave_senegal_payment_token: token,
    }),
    urlPicker: (d) => d.url as string | undefined,
  },
  orange_sn: {
    slug: "new-orange-money-senegal", resultType: "url", dialCode: "221",
    buildBody: (token, phone) => ({
      customer_name: "Nakora User",
      customer_email: "user@nakora.app",
      phone_number: phone,
      invoice_token: token,
    }),
    urlPicker: (d) => {
      const o = d.other_url as Record<string, string> | undefined;
      return o?.om_url ?? o?.maxit_url ?? (d.url as string | undefined);
    },
  },
  free_sn: {
    slug: "free-money-senegal", resultType: "ussd", dialCode: "221",
    buildBody: (token, phone) => ({
      customer_name: "Nakora User",
      customer_email: "user@nakora.app",
      phone_number: phone,
      payment_token: token,
    }),
  },
  // ── Côte d'Ivoire ────────────────────────────────────────
  wave_ci: {
    slug: "wave-ci", resultType: "url", dialCode: "225",
    buildBody: (token, phone) => ({
      wave_ci_fullName: "Nakora User",
      wave_ci_email: "user@nakora.app",
      wave_ci_phone: phone,
      wave_ci_payment_token: token,
    }),
    urlPicker: (d) => d.url as string | undefined,
  },
  orange_ci: {
    slug: "orange-money-ci", resultType: "otp", dialCode: "225",
    buildBody: (token, phone, otp = "") => ({
      orange_money_ci_customer_fullname: "Nakora User",
      orange_money_ci_email: "user@nakora.app",
      orange_money_ci_phone_number: phone,
      orange_money_ci_otp: otp,
      payment_token: token,
    }),
  },
  mtn_ci: {
    slug: "mtn-ci", resultType: "ussd", dialCode: "225",
    buildBody: (token, phone) => ({
      mtn_ci_customer_fullname: "Nakora User",
      mtn_ci_email: "user@nakora.app",
      mtn_ci_phone_number: phone,
      mtn_ci_wallet_provider: "MTNCI",
      payment_token: token,
    }),
  },
  moov_ci: {
    slug: "moov-ci", resultType: "ussd", dialCode: "225",
    buildBody: (token, phone) => ({
      moov_ci_customer_fullname: "Nakora User",
      moov_ci_email: "user@nakora.app",
      moov_ci_phone_number: phone,
      payment_token: token,
    }),
  },
  // ── Mali ────────────────────────────────────────────────
  orange_ml: {
    slug: "orange-money-mali", resultType: "ussd", dialCode: "223",
    buildBody: (token, phone) => ({
      orange_money_mali_customer_fullname: "Nakora User",
      orange_money_mali_email: "user@nakora.app",
      orange_money_mali_phone_number: phone,
      orange_money_mali_customer_address: "Bamako",
      payment_token: token,
    }),
  },
  moov_ml: {
    slug: "moov-mali", resultType: "ussd", dialCode: "223",
    buildBody: (token, phone) => ({
      moov_ml_customer_fullname: "Nakora User",
      moov_ml_email: "user@nakora.app",
      moov_ml_phone_number: phone,
      moov_ml_customer_address: "Bamako",
      payment_token: token,
    }),
  },
  // ── Burkina Faso ─────────────────────────────────────────
  orange_bf: {
    slug: "orange-money-burkina", resultType: "otp", dialCode: "226",
    buildBody: (token, phone, otp = "") => ({
      name_bf: "Nakora User",
      email_bf: "user@nakora.app",
      phone_bf: phone,
      otp_code: otp,
      payment_token: token,
    }),
  },
  moov_bf: {
    slug: "moov-burkina", resultType: "ussd", dialCode: "226",
    buildBody: (token, phone) => ({
      moov_burkina_faso_fullName: "Nakora User",
      moov_burkina_faso_email: "user@nakora.app",
      moov_burkina_faso_phone_number: phone,
      moov_burkina_faso_payment_token: token,
    }),
  },
  // ── Bénin ────────────────────────────────────────────────
  mtn_bj: {
    slug: "mtn-benin", resultType: "ussd", dialCode: "229",
    buildBody: (token, phone) => ({
      mtn_benin_customer_fullname: "Nakora User",
      mtn_benin_email: "user@nakora.app",
      mtn_benin_phone_number: phone,
      mtn_benin_wallet_provider: "MTNBENIN",
      payment_token: token,
    }),
  },
  moov_bj: {
    slug: "moov-benin", resultType: "ussd", dialCode: "229",
    buildBody: (token, phone) => ({
      moov_benin_customer_fullname: "Nakora User",
      moov_benin_email: "user@nakora.app",
      moov_benin_phone_number: phone,
      payment_token: token,
    }),
  },
  // ── Togo ─────────────────────────────────────────────────
  moov_tg: {
    slug: "moov-togo", resultType: "ussd", dialCode: "228",
    buildBody: (token, phone) => ({
      moov_togo_customer_fullname: "Nakora User",
      moov_togo_email: "user@nakora.app",
      moov_togo_customer_address: "Lomé",
      moov_togo_phone_number: phone,
      payment_token: token,
    }),
  },
  // ── Cameroun ─────────────────────────────────────────────
  mtn_cm: {
    slug: "mtn-cameroun", resultType: "ussd", dialCode: "237",
    buildBody: (token, phone) => ({
      mtn_cameroun_customer_fullname: "Nakora User",
      mtn_cameroun_email: "user@nakora.app",
      mtn_cameroun_phone_number: phone,
      mtn_cameroun_wallet_provider: "MTNCAMEROUN",
      payment_token: token,
    }),
  },
};

const METHOD_LABELS: Record<string, string> = {
  wave_sn: "Wave SN", orange_sn: "Orange Money SN", free_sn: "Free Money",
  wave_ci: "Wave CI", orange_ci: "Orange Money CI", mtn_ci: "MTN MoMo CI", moov_ci: "Moov Money CI",
  orange_ml: "Orange Money ML", moov_ml: "Moov Money ML",
  orange_bf: "Orange Money BF", moov_bf: "Moov Money BF",
  mtn_bj: "MTN MoMo BJ", moov_bj: "Moov Money BJ",
  moov_tg: "Moov Money TG", mtn_cm: "MTN MoMo CM",
};

function extractLocalPhone(fullPhone: string, dialCode: string): string {
  const clean = fullPhone.replace(/^\+/, "").replace(/\s/g, "");
  return clean.startsWith(dialCode) ? clean.slice(dialCode.length) : clean;
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

  if (req.method !== "POST") return jsonResponse({ error: "Method not allowed" }, 405);

  // ── Auth ──────────────────────────────────────────────────
  const jwt = req.headers.get("authorization")?.replace("Bearer ", "");
  if (!jwt) return jsonResponse({ error: "Unauthorized" }, 401);

  const supabase = getSupabaseAdmin();
  const { data: { user }, error: authErr } = await supabase.auth.getUser(jwt);
  if (authErr || !user) return jsonResponse({ error: "Unauthorized" }, 401);

  // ── Parse body ────────────────────────────────────────────
  let plan: string, phone: string, paymentMethod: string, currency: string, otp: string | undefined;
  try {
    const body = await req.json() as Record<string, unknown>;
    plan          = String(body.plan ?? "");
    phone         = String(body.phone ?? "");
    paymentMethod = String(body.payment_method ?? "");
    currency      = String(body.currency ?? "XOF");
    otp           = body.otp ? String(body.otp) : undefined;
  } catch {
    return jsonResponse({ error: "Invalid JSON" }, 400);
  }

  if (!plan || !phone || !paymentMethod) {
    return jsonResponse({ error: "Champs manquants : plan, phone, payment_method" }, 400);
  }

  const xofAmount = PLAN_AMOUNTS[plan];
  if (!xofAmount) return jsonResponse({ error: `Plan inconnu: ${plan}` }, 400);

  const mult   = CURRENCY_MULT[currency] ?? 1;
  const amount = Math.round(xofAmount * mult);

  // ── PayDunya env ──────────────────────────────────────────
  const masterKey  = Deno.env.get("PAYDUNYA_MASTER_KEY") ?? "";
  const privateKey = Deno.env.get("PAYDUNYA_PRIVATE_KEY") ?? "";
  const publicKey  = Deno.env.get("PAYDUNYA_PUBLIC_KEY") ?? "";
  const pdToken    = Deno.env.get("PAYDUNYA_TOKEN") ?? "";
  if (!masterKey || !privateKey || !pdToken) {
    return jsonResponse({ error: "Passerelle de paiement non configurée." }, 503);
  }

  const pdHeaders = {
    "PAYDUNYA-MASTER-KEY":  masterKey,
    "PAYDUNYA-PRIVATE-KEY": privateKey,
    "PAYDUNYA-PUBLIC-KEY":  publicKey,
    "PAYDUNYA-TOKEN":       pdToken,
    "Content-Type": "application/json",
  };

  // ── OTP method without OTP → ask client ───────────────────
  const cfg        = SOFTPAY[paymentMethod];
  const methodName = METHOD_LABELS[paymentMethod] ?? paymentMethod;

  if (cfg?.resultType === "otp" && !otp) {
    const ussdCode = paymentMethod === "orange_ci" ? "#144*82#" : "#143#";
    return jsonResponse({
      payment_type: "otp_required",
      payment_method_name: methodName,
      otp_instructions: `Composez ${ussdCode} → option 2 pour obtenir votre code de paiement, puis entrez-le ci-dessous.`,
    });
  }

  // ── Check recent pending payment (avoid duplicates) ───────
  const twoHoursAgo = new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString();
  const { data: existingPayment } = await supabase
    .from("payments")
    .select("id, external_id, metadata")
    .eq("user_id", user.id)
    .eq("plan", plan)
    .eq("payment_method", paymentMethod)
    .eq("status", "pending")
    .gte("created_at", twoHoursAgo)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (existingPayment?.external_id) {
    const invoiceToken = existingPayment.external_id as string;
    // Verify invoice status with PayDunya
    try {
      const confirmResp = await fetch(`${PD_BASE}/checkout-invoice/confirm/${invoiceToken}`, { headers: pdHeaders });
      if (confirmResp.ok) {
        const confirmData = await confirmResp.json() as Record<string, unknown>;
        const inv = confirmData.invoice as Record<string, unknown> | undefined;
        const invStatus = String((inv?.status ?? confirmData.status) ?? "");

        if (invStatus === "completed") {
          await supabase.from("payments").update({ status: "completed", completed_at: new Date().toISOString() }).eq("id", existingPayment.id);
          return jsonResponse({ error: "Ce paiement a déjà été effectué." }, 409);
        }
        if (invStatus === "pending" || invStatus === "initiated") {
          // Still valid → retry SoftPay
          return await trySoftPay({ supabase, pdHeaders, paymentId: existingPayment.id as string, invoiceToken, userId: user.id, paymentMethod, phone, otp, amount, currency, plan, methodName });
        }
      }
    } catch { /* ignore — create fresh */ }
    // Old invoice is done/broken → mark failed and create new one
    await supabase.from("payments").update({ status: "failed" }).eq("id", existingPayment.id);
  }

  // ── Build callback / return URLs ──────────────────────────
  const fnBase      = Deno.env.get("SUPABASE_URL") ?? "";
  const callbackUrl = `${fnBase}/functions/v1/webhook-payment`;

  // payment_id is embedded BEFORE creating the invoice so PayDunya returns to the exact URL
  const paymentId = crypto.randomUUID();
  const returnUrl = `${fnBase}/functions/v1/payment-redirect?status=completed&payment_id=${paymentId}`;
  const cancelUrl = `${fnBase}/functions/v1/payment-redirect?status=cancelled&payment_id=${paymentId}`;

  // ── Step 1: Create PayDunya invoice ───────────────────────
  const planLabels: Record<string, string> = { starter: "Starter", pro: "Pro", vip: "VIP" };
  const invoicePayload = {
    invoice: { total_amount: amount, description: `Nakora ${planLabels[plan] ?? plan} - 30 jours` },
    store:   { name: "Nakora", tagline: "Pronostics sportifs" },
    custom_data: { user_id: user.id, plan },
    actions: { callback_url: callbackUrl, return_url: returnUrl, cancel_url: cancelUrl },
  };

  const invoiceResp = await fetch(`${PD_BASE}/checkout-invoice/create`, {
    method: "POST",
    headers: pdHeaders,
    body: JSON.stringify(invoicePayload),
  });

  const invoiceData = await invoiceResp.json() as Record<string, unknown>;
  if (!invoiceResp.ok || !invoiceData.token) {
    console.error("[create-payment] Invoice creation failed:", invoiceData);
    return jsonResponse({ error: "Echec de creation de la facture PayDunya." }, 502);
  }

  const invoiceToken    = invoiceData.token as string;
  const checkoutPageUrl = `https://app.paydunya.com/checkout/invoice/${invoiceToken}`;

  // ── Step 2: Persist payment row ───────────────────────────
  const { error: insertErr } = await supabase.from("payments").insert({
    id: paymentId,
    user_id: user.id,
    provider: "paydunya",
    external_id: invoiceToken,
    plan,
    amount,
    currency,
    payment_method: paymentMethod,
    phone,
    status: "pending",
  });

  if (insertErr) {
    console.error("[create-payment] DB insert error:", insertErr);
    return jsonResponse({ error: "Erreur base de données." }, 500);
  }

  // ── Step 3: SoftPay ───────────────────────────────────────
  return await trySoftPay({ supabase, pdHeaders, paymentId, invoiceToken, userId: user.id, paymentMethod, phone, otp, amount, currency, plan, methodName, checkoutFallback: checkoutPageUrl });
});

// ─────────────────────────────────────────────────────────────
// trySoftPay — appelle l'endpoint SoftPay pour l'opérateur donné
// ─────────────────────────────────────────────────────────────
interface SoftPayOpts {
  supabase: ReturnType<typeof getSupabaseAdmin>;
  pdHeaders: Record<string, string>;
  paymentId: string;
  invoiceToken: string;
  userId: string;
  paymentMethod: string;
  phone: string;
  otp?: string;
  amount: number;
  currency: string;
  plan: string;
  methodName: string;
  checkoutFallback?: string;
}

// Activates subscription immediately after confirmed payment (USSD/OTP path).
async function activateSubscription(
  supabase: ReturnType<typeof getSupabaseAdmin>,
  paymentId: string,
  userId: string,
  plan: string,
  amount: number,
  currency: string,
  invoiceToken: string,
): Promise<boolean> {
  const { error: updateErr } = await supabase
    .from("payments")
    .update({ status: "completed", completed_at: new Date().toISOString() })
    .eq("id", paymentId);
  if (updateErr) {
    console.error("[create-payment] Failed to mark payment completed:", updateErr);
    return false;
  }

  const startDate = new Date();
  const endDate   = new Date(startDate.getTime() + 30 * 24 * 60 * 60 * 1000);

  await supabase
    .from("subscriptions")
    .update({ status: "cancelled", updated_at: new Date().toISOString() })
    .eq("user_id", userId)
    .eq("status", "active");

  const { error: subErr } = await supabase.from("subscriptions").insert({
    user_id:    userId,
    plan,
    status:     "active",
    start_date: startDate.toISOString(),
    end_date:   endDate.toISOString(),
    payment_ref: invoiceToken,
    amount,
    currency,
    provider:   "paydunya",
  });
  if (subErr) {
    console.error("[create-payment] Failed to create subscription:", subErr);
    return false;
  }

  await supabase.from("users").update({ plan }).eq("id", userId);
  console.log(`[create-payment] Subscription activated: user=${userId} plan=${plan}`);
  return true;
}

async function trySoftPay(opts: SoftPayOpts): Promise<Response> {
  const { supabase, pdHeaders, paymentId, invoiceToken, paymentMethod, phone, otp, methodName } = opts;
  const cfg = SOFTPAY[paymentMethod];
  const checkoutUrl = opts.checkoutFallback ?? `https://app.paydunya.com/checkout/invoice/${invoiceToken}`;

  if (!cfg) {
    // Opérateur sans SoftPay → page checkout PayDunya
    return jsonResponse({ payment_id: paymentId, payment_type: "redirect", checkout_url: checkoutUrl, payment_method_name: methodName });
  }

  const localPhone = extractLocalPhone(phone, cfg.dialCode);
  const body = cfg.buildBody(invoiceToken, localPhone, otp);

  try {
    const spResp = await fetch(`${PD_BASE}/softpay/${cfg.slug}`, {
      method: "POST",
      headers: pdHeaders,
      body: JSON.stringify(body),
    });

    const spText = await spResp.text();
    await supabase.from("payments")
      .update({ metadata: { softpay_slug: cfg.slug, softpay_status: spResp.status, softpay_response: spText.substring(0, 500) } })
      .eq("id", paymentId);

    const spData = JSON.parse(spText) as Record<string, unknown>;

    if (spData?.success === true) {
      if (cfg.resultType === "url" && cfg.urlPicker) {
        const deepLink = cfg.urlPicker(spData);
        if (deepLink) {
          return jsonResponse({ payment_id: paymentId, payment_type: "deeplink", checkout_url: deepLink, payment_method_name: methodName });
        }
      }
      if (cfg.resultType === "otp") {
        // OTP flow: SoftPay success = payment immediately confirmed
        const activated = await activateSubscription(
          supabase, paymentId, opts.userId, opts.plan, opts.amount, opts.currency, invoiceToken,
        );
        if (activated) {
          return jsonResponse({ payment_id: paymentId, payment_type: "completed", payment_method_name: methodName });
        }
        // Activation failed — fall back to polling
        return jsonResponse({
          payment_id: paymentId,
          payment_type: "ussd",
          payment_method_name: methodName,
          ussd_message: spData.message as string | undefined,
        });
      }
      if (cfg.resultType === "ussd") {
        // USSD flow: push was sent, user must confirm on their phone.
        // Payment will be confirmed asynchronously via IPN webhook.
        return jsonResponse({
          payment_id: paymentId,
          payment_type: "ussd",
          payment_method_name: methodName,
          ussd_message: spData.message as string | undefined,
        });
      }
    }

    console.warn(`[create-payment] SoftPay ${cfg.slug} failed → checkout fallback. Body: ${spText.substring(0, 200)}`);
  } catch (err) {
    console.error(`[create-payment] SoftPay ${cfg.slug} error:`, err);
    await supabase.from("payments").update({ metadata: { softpay_error: String(err) } }).eq("id", paymentId);
  }

  // Fallback checkout page
  return jsonResponse({ payment_id: paymentId, payment_type: "redirect", checkout_url: checkoutUrl, payment_method_name: methodName });
}
