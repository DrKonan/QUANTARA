// ============================================================
// NAKORA — Edge Function : lookup-phone-auth
// Rôle : Résout l'email auth Supabase correspondant à un numéro
//        de téléphone, pour permettre la connexion par phone.
// Body : { phone: string }
// Réponse : { auth_email: string | null }
// Auth : Accessible sans JWT (anon) — ne renvoie pas de donnée sensible
// ============================================================
import { getSupabaseAdmin } from "../_shared/supabase.ts";
import { jsonResponse } from "../_shared/helpers.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    const { phone } = await req.json() as { phone?: string };

    if (!phone) {
      return jsonResponse({ auth_email: null });
    }

    const supabase = getSupabaseAdmin();

    // Cherche le profil par numéro de téléphone
    const { data: profile } = await supabase
      .from("users")
      .select("email, phone")
      .eq("phone", phone)
      .maybeSingle();

    if (!profile) {
      return jsonResponse({ auth_email: null });
    }

    // Si l'utilisateur a un vrai email → c'est l'identifiant auth Supabase
    if (profile.email && profile.email.trim() !== "") {
      return jsonResponse({ auth_email: profile.email });
    }

    // Sinon → email dérivé du téléphone
    const cleaned = phone.replace(/[^\d]/g, "");
    return jsonResponse({ auth_email: `${cleaned}@phone.nakora.app` });
  } catch (err) {
    console.error("[lookup-phone-auth] Error:", err);
    return jsonResponse({ auth_email: null });
  }
});
