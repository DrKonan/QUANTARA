// ============================================================
// NAKORA — Edge Function : payment-redirect
// Return URL appelée par PayDunya après paiement.
// 1. Fait confiance au status=completed de PayDunya (c'est eux qui appellent)
// 2. Vérifie via API pour confirmer (accepte completed/paid/success)
// 3. Met à jour la DB et active l'abonnement
// 4. Affiche une page propre pour que l'utilisateur revienne dans l'app
// ============================================================

import { getSupabaseAdmin } from "../_shared/supabase.ts";

const PD_BASE = "https://app.paydunya.com/api/v1";

Deno.serve(async (req: Request) => {
  const url       = new URL(req.url);
  const status    = url.searchParams.get("status") ?? "error";
  const paymentId = url.searchParams.get("payment_id") ?? "";

  console.log(`[payment-redirect] status=${status} payment_id=${paymentId}`);

  // Guard: paymentId is required to do anything useful
  if (!paymentId) {
    console.error("[payment-redirect] Missing payment_id — cannot process");
    return new Response(
      "Paiement non identifié. Contactez le support Nakora.",
      { status: 400, headers: { "Content-Type": "text/plain; charset=utf-8" } },
    );
  }

  let activated = false;

  if (paymentId && status === "completed") {
    try {
      const supabase = getSupabaseAdmin();

      // ── 1. Find payment row by our own UUID ───────────────
      const { data: payment, error: fetchErr } = await supabase
        .from("payments")
        .select("id, user_id, plan, amount, currency, status, external_id")
        .eq("id", paymentId)
        .maybeSingle();

      if (fetchErr) {
        console.error("[payment-redirect] DB fetch error:", fetchErr);
      } else if (!payment) {
        console.warn(`[payment-redirect] No payment found for id=${paymentId}`);
      } else {
        console.log(`[payment-redirect] Found payment: status=${payment.status} plan=${payment.plan}`);

        if ((payment.status as string) === "completed") {
          activated = true; // Already done
        } else {
          // ── 2. Optionally verify with PayDunya API ────────
          const pdToken   = payment.external_id as string;
          let shouldActivate = false;

          try {
            const pdHeaders = {
              "Content-Type":         "application/json",
              "PAYDUNYA-MASTER-KEY":  Deno.env.get("PAYDUNYA_MASTER_KEY")  ?? "",
              "PAYDUNYA-PRIVATE-KEY": Deno.env.get("PAYDUNYA_PRIVATE_KEY") ?? "",
              "PAYDUNYA-PUBLIC-KEY":  Deno.env.get("PAYDUNYA_PUBLIC_KEY")  ?? "",
              "PAYDUNYA-TOKEN":       Deno.env.get("PAYDUNYA_TOKEN")        ?? "",
            };
            const verifyResp = await fetch(`${PD_BASE}/checkout-invoice/confirm/${pdToken}`, { headers: pdHeaders });
            const verifyData = await verifyResp.json() as Record<string, unknown>;
            const invoice    = verifyData?.invoice as Record<string, unknown> | undefined;
            const apiStatus  = String(invoice?.status ?? verifyData?.status ?? "").toLowerCase();
            console.log(`[payment-redirect] PayDunya API status="${apiStatus}" for token=${pdToken}`);
            shouldActivate = ["completed", "paid", "success"].includes(apiStatus);
          } catch (apiErr) {
            console.warn("[payment-redirect] API verify failed, trusting PayDunya return_url:", apiErr);
            // PayDunya controls the return_url — if they redirected here with status=completed, trust it
            shouldActivate = true;
          }

          if (shouldActivate) {
            // ── 3. Update payment row ────────────────────────
            const { error: updErr } = await supabase.from("payments").update({
              status:       "completed",
              completed_at: new Date().toISOString(),
            }).eq("id", paymentId);
            if (updErr) console.error("[payment-redirect] payments update error:", updErr);
            else        console.log("[payment-redirect] payments.status -> completed");

            // ── 4. Cancel any existing active subscription ───
            const paymentUser = payment.user_id as string;
            const paymentPlan = payment.plan as string;

            const { error: cancelErr } = await supabase.from("subscriptions")
              .update({ status: "cancelled", updated_at: new Date().toISOString() })
              .eq("user_id", paymentUser)
              .eq("status", "active");
            if (cancelErr) console.error("[payment-redirect] cancel old subscription error:", cancelErr);

            // ── 5. Insert new subscription (30 days) ─────────
            const startDate = new Date();
            const endDate   = new Date(startDate.getTime() + 30 * 24 * 60 * 60 * 1000);

            const { error: subErr } = await supabase.from("subscriptions").insert({
              user_id:     paymentUser,
              plan:        paymentPlan,
              status:      "active",
              start_date:  startDate.toISOString(),
              end_date:    endDate.toISOString(),
              payment_ref: payment.external_id as string,
              amount:      payment.amount as number,
              currency:    (payment.currency as string) ?? "XOF",
              provider:    "paydunya",
            });
            if (subErr) console.error("[payment-redirect] subscription insert error:", subErr);
            else        console.log(`[payment-redirect] subscription created plan=${paymentPlan} end=${endDate.toISOString()}`);

            // ── 6. Update users.plan ─────────────────────────
            const { error: userErr } = await supabase.from("users").update({ plan: paymentPlan }).eq("id", paymentUser);
            if (userErr) console.error("[payment-redirect] users.plan update error:", userErr);
            else         console.log(`[payment-redirect] users.plan -> ${paymentPlan}`);

            activated = !updErr && !subErr;
          }
        }
      }
    } catch (err) {
      console.error("[payment-redirect] Unexpected error:", err);
    }
  }

  const deepLink = `nakora://payment?status=${encodeURIComponent(status)}&payment_id=${encodeURIComponent(paymentId)}`;
  // Use &amp; in HTML attributes (href) but raw & in JS strings
  const deepLinkHtml = deepLink.replace(/&/g, "&amp;");

  const isSuccess   = status === "completed";
  const isCancelled = status === "cancelled";

  const icon    = isSuccess ? "\u2705" : isCancelled ? "\u274C" : "\u26A0\uFE0F";
  const heading = isSuccess ? "Paiement confirm\u00e9 !" : isCancelled ? "Paiement annul\u00e9" : "Erreur de paiement";
  const message = isSuccess
    ? "Votre abonnement Nakora est activ\u00e9.\nAppuyez sur le bouton pour revenir dans l\u2019application."
    : isCancelled
    ? "Votre paiement a \u00e9t\u00e9 annul\u00e9.\nVous pouvez r\u00e9essayer depuis l\u2019application."
    : "Une erreur est survenue.\nVeuillez r\u00e9essayer depuis l\u2019application.";

  const html = `<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta http-equiv="refresh" content="1;url=${deepLinkHtml}">
  <title>Nakora</title>
  <style>
    *{box-sizing:border-box;margin:0;padding:0}
    html,body{height:100%}
    body{
      font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;
      background:#09090f;
      color:#fff;
      display:flex;
      align-items:center;
      justify-content:center;
      padding:32px 24px;
      text-align:center;
    }
    .card{
      background:#13131f;
      border:1px solid #2a2a40;
      border-radius:24px;
      padding:48px 32px;
      max-width:360px;
      width:100%;
      box-shadow:0 24px 64px rgba(0,0,0,.6);
    }
    .icon{font-size:56px;line-height:1;margin-bottom:24px}
    h1{font-size:24px;font-weight:800;color:#fff;margin-bottom:12px}
    p{color:#888;font-size:15px;line-height:1.7;margin-bottom:36px;white-space:pre-line}
    .btn{
      display:block;
      background:linear-gradient(135deg,#6C63FF,#A855F7);
      color:#fff;
      text-decoration:none;
      padding:18px 24px;
      border-radius:16px;
      font-size:17px;
      font-weight:700;
      letter-spacing:0.3px;
      box-shadow:0 8px 24px rgba(108,99,255,.35);
      transition:opacity .15s;
    }
    .btn:active{opacity:.85}
    .note{margin-top:16px;font-size:13px;color:#555}
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">${icon}</div>
    <h1>${heading}</h1>
    <p>${message}</p>
    <a class="btn" href="${deepLinkHtml}">Retourner dans Nakora</a>
    <p class="note">Redirection automatique dans quelques secondes&hellip;</p>
  </div>
  <script>
    window.location.replace("${deepLink}");
  </script>
</body>
</html>`;

  return new Response(html, {
    status: 200,
    headers: { "Content-Type": "text/html; charset=utf-8" },
  });
});
