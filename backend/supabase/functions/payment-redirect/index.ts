// ============================================================
// NAKORA — Edge Function : payment-redirect
// Appelée par PayDunya / Wave après paiement (return_url / success_url).
// Redirige l'utilisateur vers l'app mobile via deep link.
// Query params : ?status=success|cancel|error&payment_id=<uuid>
// ============================================================

Deno.serve((req: Request) => {
  const url = new URL(req.url);
  const status = url.searchParams.get("status") ?? "error";
  const paymentId = url.searchParams.get("payment_id") ?? "";

  // Deep link vers l'app Flutter
  const deepLink = `nakora://payment?status=${status}&payment_id=${encodeURIComponent(paymentId)}`;

  // Fallback page HTML si l'app n'est pas installée
  const html = `<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${status === "success" ? "Paiement réussi" : "Paiement"} — Nakora</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      background: #14172C;
      color: #e5e7eb;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 24px;
    }
    .card {
      background: #1a1e35;
      border: 1px solid rgba(255,255,255,0.1);
      border-radius: 16px;
      padding: 40px 32px;
      max-width: 400px;
      width: 100%;
      text-align: center;
    }
    .icon { font-size: 48px; margin-bottom: 16px; }
    h1 { color: #fff; font-size: 22px; font-weight: 700; margin-bottom: 8px; }
    p { color: #9ca3af; font-size: 15px; line-height: 1.6; }
    .badge {
      display: inline-block;
      margin-top: 20px;
      background: rgba(255,215,0,0.15);
      color: #FFD700;
      border: 1px solid rgba(255,215,0,0.3);
      border-radius: 8px;
      padding: 8px 16px;
      font-size: 14px;
    }
    .open-btn {
      display: inline-block;
      margin-top: 24px;
      background: #FFD700;
      color: #14172C;
      font-weight: 700;
      padding: 12px 28px;
      border-radius: 10px;
      text-decoration: none;
      font-size: 16px;
    }
  </style>
  <script>
    // Tentative d'ouverture du deep link immédiatement
    window.location.href = ${JSON.stringify(deepLink)};
    // Fallback : si toujours sur la page après 2s, afficher le bouton
    setTimeout(() => {
      document.getElementById('fallback').style.display = 'block';
    }, 2000);
  </script>
</head>
<body>
  <div class="card">
    ${status === "success"
      ? `<div class="icon">🎉</div>
         <h1>Paiement confirmé !</h1>
         <p>Votre abonnement Nakora est maintenant actif. Retournez dans l'application pour accéder à vos pronos.</p>
         <span class="badge">✓ Abonnement activé</span>`
      : status === "cancel"
      ? `<div class="icon">↩️</div>
         <h1>Paiement annulé</h1>
         <p>Vous avez annulé le paiement. Vous pouvez réessayer depuis l'application.</p>`
      : `<div class="icon">⚠️</div>
         <h1>Erreur de paiement</h1>
         <p>Une erreur est survenue lors du paiement. Réessayez depuis l'application ou contactez le support.</p>`
    }
    <div id="fallback" style="display:none">
      <br/>
      <a class="open-btn" href="${deepLink}">Ouvrir Nakora</a>
    </div>
  </div>
</body>
</html>`;

  return new Response(html, {
    status: 200,
    headers: { "Content-Type": "text/html; charset=utf-8" },
  });
});
