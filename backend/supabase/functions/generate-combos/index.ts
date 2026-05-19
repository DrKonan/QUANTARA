// ============================================================
// NAKORA — Edge Function : generate-combos
//
// Génère les combinés pour UN créneau horaire (slot) :
//   • 'day'     → matchs AVANT 22h UTC  (lancé à 9h UTC)
//   • 'evening' → matchs A PARTIR DE 22h UTC (lancé à 23h UTC)
//
// Chaque slot produit jusqu'à 2 combos : 'safe' (PRO+VIP) et 'bold' (VIP)
//
// STRATEGIE :
// — Priorité absolue à la CONFIANCE : on prend les prédictions
//   les plus certaines, peu importe le marché, la cote ou la ligue.
// — Seul 'correct_score' est exclu (fondamentalement imprévisible).
// — Safe  : top 3 par confiance (seuil ≥ 0.78), min 2 jambes, 1 par match
// — Bold  : top 5 par confiance (≥ 0.72), 1 par match, max 2 par ligue
//           les matchs déjà utilisés dans le Safe sont EXCLUS du Bold
//           → si un match perd, il n'impacte qu'un seul combo
// — Les cotes sont affichées pour info mais ne pilotent PAS la sélection.
// ============================================================
import { getSupabaseAdmin } from "../_shared/supabase.ts";
import { jsonResponse } from "../_shared/helpers.ts";

const SAFE_MIN_CONFIDENCE = 0.78;  // seuil jambes du combo safe
const BOLD_MIN_CONFIDENCE = 0.72;  // seuil jambes du combo bold
const MIN_LEG_ODDS = 1.40;         // cote min par jambe — évite les paris sans valeur

// correct_score et first_team_to_score exclus : trop aléatoires quelle que soit la confiance
const EXCLUDED_MARKETS = ["correct_score", "first_team_to_score"];

interface EligiblePrediction {
  id: number;
  match_id: number;
  prediction_type: string;
  prediction: string;
  confidence: number;
  bookmaker_odds: number;
  home_team: string;
  away_team: string;
  league: string;
  league_id: number;
  match_date: string;
}

interface ComboLeg {
  prediction_id: number;
  match_id: number;
  home_team: string;
  away_team: string;
  league: string;
  prediction_type: string;
  prediction: string;
  confidence: number;
  bookmaker_odds: number;
}

// Cote synthétique quand le bookmaker ne fournit pas de données
// Affichage seulement — ne pilote pas la sélection
function syntheticOdds(confidence: number): number {
  return Math.round((1 / (confidence * 0.95)) * 100) / 100;
}

// ----------------------------------------------------------------
// Sélection des jambes uniquement par confiance décroissante
// Max 1 jambe par match, max 2 par ligue
// ----------------------------------------------------------------
function selectLegs(
  pool: EligiblePrediction[],
  targetLegs: number,
  excludeMatchIds: Set<number>,
  minLegs = 2,
): ComboLeg[] | null {
  // Tri par confiance décroissante — c'est le seul critère
  const sorted = pool
    .filter(p => !excludeMatchIds.has(p.match_id))
    .sort((a, b) => b.confidence - a.confidence);

  const selected: ComboLeg[] = [];
  const usedMatches = new Set<number>();
  const usedLeagues = new Map<number, number>();

  for (const p of sorted) {
    if (selected.length >= targetLegs) break;
    if (usedMatches.has(p.match_id)) continue;

    const leagueCount = usedLeagues.get(p.league_id) ?? 0;
    if (leagueCount >= 2) continue;

    selected.push({
      prediction_id: p.id,
      match_id: p.match_id,
      home_team: p.home_team,
      away_team: p.away_team,
      league: p.league,
      prediction_type: p.prediction_type,
      prediction: p.prediction,
      confidence: p.confidence,
      bookmaker_odds: p.bookmaker_odds,
    });
    usedMatches.add(p.match_id);
    usedLeagues.set(p.league_id, leagueCount + 1);
  }

  return selected.length >= minLegs ? selected : null;
}

Deno.serve(async (req: Request) => {
  try {
    const supabase = getSupabaseAdmin();

    // ── Détermine le slot (day | evening) ──────────────────────────
    // Priorité : body JSON > auto-détection par heure UTC
    let slot: "day" | "evening" = "day";
    try {
      const body = await req.json() as { slot?: string };
      if (body.slot === "evening") slot = "evening";
      else if (body.slot === "day") slot = "day";
      else {
        // Auto-détection : si heure >= 12 UTC on suppose le créneau du soir
        slot = new Date().getUTCHours() >= 12 ? "evening" : "day";
      }
    } catch {
      slot = new Date().getUTCHours() >= 12 ? "evening" : "day";
    }
    console.log(`[generate-combos] slot=${slot}`);

    // ── Fenêtre horaire du slot ─────────────────────────────────────
    const now = new Date();
    const today = now.toISOString().slice(0, 10);

    // day     : matchs entre 06:00 et 21:59 UTC
    // evening : matchs entre 22:00 UTC et 05:59 UTC lendemain
    const nextDay = new Date(now.getTime() + 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
    const slotStart = slot === "day"
      ? `${today}T06:00:00+00:00`
      : `${today}T22:00:00+00:00`;
    const slotEnd = slot === "day"
      ? `${today}T21:59:59+00:00`
      : `${nextDay}T05:59:59+00:00`;

    // Journée sportive complète (pour la journée du jour)
    const dayStart = `${today}T06:00:00+00:00`;
    const dayEnd = `${nextDay}T05:59:59+00:00`;

    // Vérifie qu'on n'a pas déjà généré des combos pour ce slot aujourd'hui
    const { data: existingCombos } = await supabase
      .from("combo_predictions")
      .select("id")
      .eq("combo_date", today)
      .eq("combo_slot", slot);

    if (existingCombos && existingCombos.length > 0) {
      console.log(`[generate-combos] Combos already exist for ${today} slot=${slot}, skipping`);
      return jsonResponse({ message: "Combos already generated", date: today, slot });
    }

    // Récupère les matchs du créneau horaire (slot)
    // IMPORTANT : pour le slot "evening", les matchs de 22h sont déjà "live"
    // quand le combo est généré à 23h UTC → inclure "live" en plus de "scheduled"
    const { data: matchesRaw } = await supabase
      .from("matches")
      .select("id, home_team, away_team, league, league_id, match_date, status")
      .gte("match_date", slotStart)
      .lte("match_date", slotEnd)
      .in("status", ["scheduled", "live"])
      .order("match_date", { ascending: true });

    if (!matchesRaw || matchesRaw.length === 0) {
      console.log(`[generate-combos] No scheduled matches for ${today} slot=${slot}`);
      return jsonResponse({ message: "No matches for this slot", date: today, slot });
    }

    const matchIds = matchesRaw.map((m: { id: number }) => m.id);
    const matchMap = new Map(matchesRaw.map((m: { id: number; home_team: string; away_team: string; league: string; league_id: number; match_date: string }) => [m.id, m]));

    const { data: predsRaw } = await supabase
      .from("predictions")
      .select("id, match_id, prediction_type, prediction, confidence, bookmaker_odds")
      .in("match_id", matchIds)
      .eq("is_published", true)
      .eq("is_live", false)
      .gte("confidence", BOLD_MIN_CONFIDENCE)
      .order("confidence", { ascending: false });

    if (!predsRaw || predsRaw.length === 0) {
      console.log(`[generate-combos] No eligible predictions for ${today}`);
      return jsonResponse({ message: "No eligible predictions", date: today });
    }

    // Pool unique : exclut uniquement les marchés fondamentalement imprévisibles
    // Pas de filtre sur les cotes — la confiance prime
    const allPool: EligiblePrediction[] = [];
    for (const p of predsRaw as Array<{ id: number; match_id: number; prediction_type: string; prediction: string; confidence: number; bookmaker_odds: number | null }>) {
      if (EXCLUDED_MARKETS.includes(p.prediction_type)) continue;

      const odds = p.bookmaker_odds ?? syntheticOdds(p.confidence);
      if (odds < MIN_LEG_ODDS) continue; // cote trop basse = pas de valeur dans un combo

      const match = matchMap.get(p.match_id);
      if (!match) continue;

      allPool.push({
        ...p,
        bookmaker_odds: p.bookmaker_odds ?? syntheticOdds(p.confidence),
        home_team: match.home_team,
        away_team: match.away_team,
        league: match.league,
        league_id: match.league_id,
        match_date: match.match_date,
      });
    }

    // Safe et Bold partagent le même pool initial (≥ 0.72), mais le Safe
    // filtre ensuite à ≥ 0.78 et accepte 2 ou 3 jambes.
    const safePool = allPool.filter(p => p.confidence >= SAFE_MIN_CONFIDENCE);

    console.log(`[generate-combos] Pool: ${allPool.length} predictions (safe pool: ${safePool.length}) from ${matchesRaw.length} matches (slot=${slot})`);

    if (allPool.length < 2) {
      return jsonResponse({ message: "Not enough eligible predictions for combos", pool_size: allPool.length, slot });
    }

    const combosToInsert: Array<{
      combo_date: string;
      combo_slot: string;
      combo_type: string;
      combined_odds: number;
      combined_confidence: number;
      leg_count: number;
      legs: ComboLeg[];
      min_plan: string;
    }> = [];

    // ── COMBO 1 : "SUR" — top 3 par confiance (≥ 0.78), min 2 jambes ──
    const safeLegs = selectLegs(safePool, 3, new Set(), 2);
    if (safeLegs) {
      const combinedOdds = safeLegs.reduce((acc, l) => acc * l.bookmaker_odds, 1);
      const combinedConf = safeLegs.reduce((acc, l) => acc * l.confidence, 1);
      combosToInsert.push({
        combo_date: today,
        combo_slot: slot,
        combo_type: "safe",
        combined_odds: Math.round(combinedOdds * 100) / 100,
        combined_confidence: Math.round(combinedConf * 1000) / 1000,
        leg_count: safeLegs.length,
        legs: safeLegs,
        min_plan: "pro",
      });
      console.log(`[generate-combos] Safe combo: ${safeLegs.length} legs, odds=${combinedOdds.toFixed(2)}, conf=${combinedConf.toFixed(3)}`);
    }

    // ── COMBO 2 : "AUDACIEUX" — top 5 par confiance (≥ 0.72) ──
    // Exclut les matchs déjà présents dans le safe : un match perdu
    // n'impacte ainsi qu'un seul combo à la fois.
    const safeMatchIds = new Set<number>(safeLegs?.map(l => l.match_id) ?? []);
    const boldLegs = selectLegs(allPool, 5, safeMatchIds, 3);
    if (boldLegs) {
      const combinedOdds = boldLegs.reduce((acc, l) => acc * l.bookmaker_odds, 1);
      const combinedConf = boldLegs.reduce((acc, l) => acc * l.confidence, 1);
      combosToInsert.push({
        combo_date: today,
        combo_slot: slot,
        combo_type: "bold",
        combined_odds: Math.round(combinedOdds * 100) / 100,
        combined_confidence: Math.round(combinedConf * 1000) / 1000,
        leg_count: boldLegs.length,
        legs: boldLegs,
        min_plan: "vip",
      });
      console.log(`[generate-combos] Bold combo: ${boldLegs.length} legs, odds=${combinedOdds.toFixed(2)}, conf=${combinedConf.toFixed(3)}`);
    }

    // Insère les combinés
    if (combosToInsert.length === 0) {
      console.log(`[generate-combos] Could not build any valid combo for ${today} slot=${slot}`);
      return jsonResponse({ message: "Not enough diverse predictions for combos", date: today, slot });
    }

    const { error: insertError } = await supabase
      .from("combo_predictions")
      .insert(combosToInsert);

    if (insertError) throw insertError;

    console.log(`[generate-combos] Generated ${combosToInsert.length} combo(s) for ${today} slot=${slot}`);

    // Notifie les utilisateurs PRO/VIP via notify-users
    try {
      const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
      const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
      const safeCombo = combosToInsert.find(c => c.combo_type === "safe");
      const slotLabel = slot === "evening" ? "du soir" : "du jour";

      await fetch(`${supabaseUrl}/functions/v1/notify-users`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${serviceKey}`,
        },
        body: JSON.stringify({
          type: "combo_available",
          combo_count: combosToInsert.length,
          safe_legs: safeCombo?.leg_count,
          safe_odds: safeCombo?.combined_odds,
          slot_label: slotLabel,
        }),
      });
      console.log(`[generate-combos] Notification sent via notify-users`);
    } catch (notifErr) {
      console.warn(`[generate-combos] Notification failed:`, notifErr);
    }

    return jsonResponse({
      success: true,
      date: today,
      slot,
      combos: combosToInsert.map(c => ({
        type: c.combo_type,
        legs: c.leg_count,
        combined_odds: c.combined_odds,
        combined_confidence: c.combined_confidence,
        min_plan: c.min_plan,
      })),
    });
  } catch (err) {
    console.error("[generate-combos] Error:", err);
    return jsonResponse({ error: (err as Error).message }, 500);
  }
});
