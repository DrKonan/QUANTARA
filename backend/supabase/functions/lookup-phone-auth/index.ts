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

    // Cherche le profil par numéro de téléphone (correspondance exacte)
    let profile: { email: string | null; phone: string | null } | null = null;

    const { data: directMatch } = await supabase
      .from("users")
      .select("email, phone")
      .eq("phone", phone)
      .maybeSingle();

    profile = directMatch;

    // Fallback CI (+225) : les anciens comptes ont été enregistrés sans le 0
    // national (+225707… au lieu de +2250707…). On teste les deux formats.
    if (!profile && phone.startsWith("+225")) {
      let altPhone: string | null = null;
      if (phone.startsWith("+2250")) {
        // Nouveau format → essaie ancien : +2250707… → +225707…
        altPhone = "+225" + phone.slice(5);
      } else {
        // Ancien format → essaie nouveau : +225707… → +2250707…
        altPhone = "+2250" + phone.slice(4);
      }
      const { data: altMatch } = await supabase
        .from("users")
        .select("email, phone")
        .eq("phone", altPhone)
        .maybeSingle();
      profile = altMatch;
    }

    if (!profile) {
      return jsonResponse({ auth_email: null });
    }

    // Si l'utilisateur a un vrai email → c'est l'identifiant auth Supabase
    if (profile.email && profile.email.trim() !== "") {
      return jsonResponse({ auth_email: profile.email });
    }

    // Email dérivé du téléphone STOCKÉ (pour correspondre à l'email créé à l'inscription)
    const storedPhone = profile.phone ?? phone;
    const cleaned = storedPhone.replace(/[^\d]/g, "");
    return jsonResponse({ auth_email: `${cleaned}@phone.nakora.app` });
  } catch (err) {
    console.error("[lookup-phone-auth] Error:", err);
    return jsonResponse({ auth_email: null });
  }
});
