// ============================================================
// NAKORA — Edge Function : webhook-payment
// Reçoit les IPN de PayDunya après paiement.
// Sécurité : vérifie hash = SHA-512(PAYDUNYA_MASTER_KEY).
// Sur "completed" → active l'abonnement (30 jours).
// ============================================================

import { getSupabaseAdmin } from "../_shared/supabase.ts";
import { jsonResponse } from "../_shared/helpers.ts";

async function sha512hex(text: string): Promise<string> {
  const encoder = new TextEncoder();
  const data     = encoder.encode(text);
  const hashBuf  = await crypto.subtle.digest("SHA-512", data);
  return Array.from(new Uint8Array(hashBuf)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

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

  if (req.method !== "POST") return jsonResponse({ error: "Method not allowed" }, 405);

  const rawBody = await req.text();
  console.log("[webhook-payment] Payload:", rawBody.substring(0, 300));

  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(rawBody) as Record<string, unknown>;
  } catch {
    return jsonResponse({ error: "Invalid JSON" }, 400);
  }

  // ── Verify authenticity ───────────────────────────────────
  const masterKey = Deno.env.get("PAYDUNYA_MASTER_KEY");
  if (!masterKey) return jsonResponse({ error: "Not configured" }, 503);

  const receivedHash = payload.hash as string | undefined;
  const expectedHash = await sha512hex(masterKey.trim());
  if (!receivedHash || receivedHash !== expectedHash) {
    console.error("[webhook-payment] Hash mismatch — received:", receivedHash?.substring(0, 16), "expected:", expectedHash.substring(0, 16));
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  // ── Parse invoice data ────────────────────────────────────
  const invoice    = payload.invoice  as Record<string, unknown> | undefined;
  const customData = payload.custom_data as Record<string, unknown> | undefined;

  const invoiceToken = invoice?.token as string | undefined;
  const status       = String(invoice?.status ?? "").toLowerCase();
  const userId       = customData?.user_id as string | undefined;
  const plan         = customData?.plan    as string | undefined;

  if (!invoiceToken) {
    console.warn("[webhook-payment] Missing invoice token");
    return jsonResponse({ received: true });
  }

  const supabase = getSupabaseAdmin();

  // ── Find payment row by external_id ──────────────────────
  const { data: payment, error: payErr } = await supabase
    .from("payments")
    .select("id, user_id, plan, amount, currency")
    .eq("external_id", invoiceToken)
    .maybeSingle();

  if (payErr || !payment) {
    console.warn("[webhook-payment] Payment row not found for token:", invoiceToken);
    return jsonResponse({ received: true });
  }

  const paymentId   = payment.id  as string;
  const paymentPlan = (payment.plan as string | undefined) ?? plan;
  const paymentUser = (payment.user_id as string | undefined) ?? userId;

  const VALID_PLANS = ["starter", "pro", "vip"];
  if (!paymentPlan || !VALID_PLANS.includes(paymentPlan)) {
    console.error("[webhook-payment] Invalid or missing plan:", paymentPlan);
    return jsonResponse({ received: true });
  }

  // ── Map status ────────────────────────────────────────────
  const dbStatus = status === "completed" ? "completed"
    : status === "failed"    ? "failed"
    : status === "cancelled" ? "failed"
    : null;

  if (!dbStatus) {
    console.log(`[webhook-payment] Intermediate status "${status}" — ignored`);
    return jsonResponse({ received: true });
  }

  // ── Update payments table ─────────────────────────────────
  const updateData: Record<string, unknown> = {
    status: dbStatus,
    metadata: payload,
    updated_at: new Date().toISOString(),
  };
  if (dbStatus === "completed") {
    updateData.completed_at = new Date().toISOString();
  }

  const { error: updateErr } = await supabase
    .from("payments")
    .update(updateData)
    .eq("id", paymentId);

  if (updateErr) console.error("[webhook-payment] Failed to update payment:", updateErr);

  // ── Activate subscription on completed ───────────────────
  if (dbStatus === "completed" && paymentUser && paymentPlan) {
    const PLAN_DAYS: Record<string, number> = { starter: 30, pro: 30, vip: 30 };
    const days     = PLAN_DAYS[paymentPlan] ?? 30;
    const startDate = new Date();
    const endDate   = new Date(startDate.getTime() + days * 24 * 60 * 60 * 1000);

    // Cancel any currently active subscription
    await supabase
      .from("subscriptions")
      .update({ status: "cancelled", updated_at: new Date().toISOString() })
      .eq("user_id", paymentUser)
      .eq("status", "active");

    // Insert new subscription
    const { error: subErr } = await supabase.from("subscriptions").insert({
      user_id:     paymentUser,
      plan:        paymentPlan,
      status:      "active",
      start_date:  startDate.toISOString(),
      end_date:    endDate.toISOString(),
      payment_ref: invoiceToken,
      amount:      payment.amount as number | undefined,
      currency:    (payment.currency as string | undefined) ?? "XOF",
      provider:    "paydunya",
    });

    if (subErr) {
      console.error("[webhook-payment] Failed to create subscription:", subErr);
    } else {
      console.log(`[webhook-payment] Subscription activated for user ${paymentUser} plan=${paymentPlan}`);

      // Update users.plan column
      await supabase.from("users").update({ plan: paymentPlan }).eq("id", paymentUser);
    }
  }

  return jsonResponse({ received: true });
});
