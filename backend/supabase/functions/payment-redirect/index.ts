// ============================================================
// NAKORA — Edge Function : payment-redirect
// Appelée par PayDunya après paiement (return_url).
// Supabase/Cloudflare force content-type: text/plain sur les Edge Functions.
// Solution : redirect 302 vers une page HTML statique sur GitHub Pages.
// ============================================================

Deno.serve((req: Request) => {
  const url = new URL(req.url);
  const status = url.searchParams.get("status") ?? "error";
  const paymentId = url.searchParams.get("payment_id") ?? "";

  // Redirect to static GitHub Pages page that handles deep link
  const redirectUrl = `https://drkonan.github.io/QUANTARA/payment?status=${encodeURIComponent(status)}&payment_id=${encodeURIComponent(paymentId)}`;

  return new Response(null, {
    status: 302,
    headers: { location: redirectUrl },
  });
});
