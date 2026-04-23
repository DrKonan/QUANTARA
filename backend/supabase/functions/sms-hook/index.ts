// ============================================================
// NAKORA — Edge Function : sms-hook
// 
// Auth Hook « Custom SMS Sender » pour Supabase Auth.
// Intercepte l'OTP généré par Supabase et l'envoie via
// WhatsApp Cloud API (Meta) au lieu de Twilio/SMS.
//
// Payload reçu de Supabase Auth :
//   { user: { phone: "+225..." }, sms: { otp: "123456" } }
//
// Config requise (Supabase Secrets) :
//   WHATSAPP_TOKEN    — Token permanent Meta (System User)
//   WHATSAPP_PHONE_ID — ID du numéro WhatsApp Business
// ============================================================

interface AuthHookPayload {
  user: {
    id: string;
    phone: string;
    email?: string;
  };
  sms: {
    otp: string;
  };
}

Deno.serve(async (req: Request) => {
  // Ce hook est appelé en interne par Supabase Auth (pas de JWT user)
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  let payload: AuthHookPayload;
  try {
    payload = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid payload" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { user, sms } = payload;
  if (!user?.phone || !sms?.otp) {
    console.error("[sms-hook] Missing phone or otp in payload");
    return new Response(JSON.stringify({ error: "Missing phone or otp" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const whatsappToken = Deno.env.get("WHATSAPP_TOKEN");
  const phoneNumberId = Deno.env.get("WHATSAPP_PHONE_ID");

  if (!whatsappToken || !phoneNumberId) {
    console.error("[sms-hook] Missing WHATSAPP_TOKEN or WHATSAPP_PHONE_ID");
    return new Response(JSON.stringify({ error: "WhatsApp not configured" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Format : WhatsApp attend le numéro SANS le "+"
  const waPhone = user.phone.startsWith("+")
    ? user.phone.slice(1)
    : user.phone;

  console.log(`[sms-hook] Sending OTP to ${waPhone.slice(0, 6)}***`);

  try {
    // ── Méthode 1 : Template d'authentification (recommandé) ────
    // Utilise le template "quantara_otp" créé dans Meta Business
    const templateResponse = await fetch(
      `https://graph.facebook.com/v21.0/${phoneNumberId}/messages`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${whatsappToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          messaging_product: "whatsapp",
          to: waPhone,
          type: "template",
          template: {
            name: "quantara_otp",
            language: { code: "fr" },
            components: [
              {
                type: "body",
                parameters: [{ type: "text", text: sms.otp }],
              },
              {
                // Bouton "Copier le code" — auto-rempli par Meta
                type: "button",
                sub_type: "url",
                index: "0",
                parameters: [{ type: "text", text: sms.otp }],
              },
            ],
          },
        }),
      },
    );

    if (templateResponse.ok) {
      const result = await templateResponse.json();
      console.log(`[sms-hook] WhatsApp OTP sent via template, message_id: ${result.messages?.[0]?.id}`);
      return new Response(JSON.stringify({ success: true }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // ── Fallback : message texte simple ─────────────────────────
    // Fonctionne si l'utilisateur a déjà contacté le numéro Business
    // (fenêtre de 24h) ou en mode test sandbox
    console.warn(`[sms-hook] Template failed (${templateResponse.status}), trying plain text`);
    const fallbackBody = await templateResponse.text();
    console.warn(`[sms-hook] Template error:`, fallbackBody);

    const textResponse = await fetch(
      `https://graph.facebook.com/v21.0/${phoneNumberId}/messages`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${whatsappToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          messaging_product: "whatsapp",
          to: waPhone,
          type: "text",
          text: {
            body: `🔐 Nakora — Votre code de vérification est : *${sms.otp}*\n\nCe code expire dans 5 minutes. Ne le partagez avec personne.`,
          },
        }),
      },
    );

    if (!textResponse.ok) {
      const errText = await textResponse.text();
      console.error(`[sms-hook] WhatsApp text fallback failed:`, errText);
      return new Response(JSON.stringify({ error: "WhatsApp delivery failed" }), {
        status: 502,
        headers: { "Content-Type": "application/json" },
      });
    }

    const textResult = await textResponse.json();
    console.log(`[sms-hook] WhatsApp OTP sent via text, message_id: ${textResult.messages?.[0]?.id}`);

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("[sms-hook] Error sending WhatsApp OTP:", err);
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
