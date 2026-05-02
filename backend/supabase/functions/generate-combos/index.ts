// ============================================================
// NAKORA — Edge Function : generate-combos
//
// Génère les combinés pour UN créneau horaire (slot) :
//   • 'day'     → matchs AVANT 22h UTC  (lancé à 4h UTC)
//   • 'evening' → matchs À PARTIR DE 22h UTC (lancé à 21h UTC)
//
// Chaque slot produit jusqu'à 2 combos : 'safe' (PRO+VIP) et 'bold' (VIP)
//
// STRATÉGIE :
// — Sélectionne des prédictions à confiance ≥ 0.72 avec cotes bookmaker
// — Marchés robustes uniquement : btts, over_under, double_chance
//   (peu sensibles aux changements de compo)
// — Max 1 jambe par match, diversité de ligues favorisée
// — "Sûr" (3-4 jambes, cote ~3-6) → PRO + VIP
// — "Audacieux" (4-6 jambes, cote ~6-15) → VIP uniquement
//
// Cron : 4h UTC → slot=day | 21h UTC → slot=evening
// ============================================================
import { getSupabaseAdmin } from "../_shared/supabase.ts";
import { jsonResponse } from "../_shared/helpers.ts";

// V1.2 — Marchés éligibles pour les combinés
// result inclus (marché le plus commun) ; correct_score et first_team exclus (trop aléatoires)
const COMBO_MARKETS = ["btts", "over_under", "double_chance", "result", "half_time", "clean_sheet"];
const MIN_CONFIDENCE = 0.72;  // abaissé de 0.80 → couvre bien plus de prédictions
const MIN_ODDS = 1.15;        // cote min par jambe
const MAX_ODDS = 4.00;        // cote max par jambe (pool commun safe+bold)

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
// Formule : 1 / (confiance × 0.95) — simule une marge bookmaker de 5%
function syntheticOdds(confidence: number): number {
  return Math.round((1 / (confidence * 0.95)) * 100) / 100;
}

// ----------------------------------------------------------------
// Algorithme de sélection des jambes
// Greedy : prend les meilleures prédictions en évitant les doublons
// de match et en favorisant la diversité de ligues
// ----------------------------------------------------------------
function selectLegs(
  pool: EligiblePrediction[],
  targetLegs: number,
  targetMinOdds: number,
  targetMaxOdds: number,
  excludeMatchIds: Set<number>,
  minLegs = 2,
): ComboLeg[] | null {
  // Trie par un score combiné : haute confiance + cote intéressante
  const scored = pool
    .filter(p => !excludeMatchIds.has(p.match_id))
    .map(p => ({
      ...p,
      // Score = confiance * log(cote) — favorise les cotes > 1.5 à confiance égale
      _score: p.confidence * Math.log(p.bookmaker_odds + 0.5),
    }))
    .sort((a, b) => b._score - a._score);

  // Greedy : prend les meilleures, max 1 par match, favorise diversité de ligues
  const selected: ComboLeg[] = [];
  const usedMatches = new Set<number>();
  const usedLeagues = new Map<number, number>(); // league_id → count

  for (const p of scored) {
    if (selected.length >= targetLegs) break;
    if (usedMatches.has(p.match_id)) continue;
    
    // Limite à 2 jambes max par ligue (favorise diversité)
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

  if (selected.length < minLegs) return null;

  // Ajuste si les cotes combinées dépassent le plafond cible
  // Bug fix : recalcule runningOdds à chaque retrait (contrairement à l'ancienne const)
  let runningOdds = selected.reduce((acc, l) => acc * l.bookmaker_odds, 1);
  while (runningOdds > targetMaxOdds && selected.length > minLegs) {
    selected.sort((a, b) => a.confidence - b.confidence);
    selected.shift(); // retire la jambe la moins confiante
    runningOdds = selected.reduce((acc, l) => acc * l.bookmaker_odds, 1);
  }

  if (selected.length < minLegs) return null;
  // On accepte même si on est un peu sous targetMinOdds (mieux qu'aucun combo)
  if (runningOdds < targetMinOdds * 0.65) return null;

  return selected;
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
    const { data: matchesRaw } = await supabase
      .from("matches")
      .select("id, home_team, away_team, league, league_id, match_date, status")
      .gte("match_date", slotStart)
      .lte("match_date", slotEnd)
      .eq("status", "scheduled")
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
      .gte("confidence", MIN_CONFIDENCE)
      .order("confidence", { ascending: false });

    if (!predsRaw || predsRaw.length === 0) {
      console.log(`[generate-combos] No eligible predictions with odds for ${today}`);
      return jsonResponse({ message: "No predictions with bookmaker odds", date: today });
    }

    // Filtre : marchés éligibles + cotes dans la plage
    // Si bookmaker_odds est null → cote synthétique basée sur la confiance
    const pool: EligiblePrediction[] = [];
    for (const p of predsRaw as Array<{ id: number; match_id: number; prediction_type: string; prediction: string; confidence: number; bookmaker_odds: number | null }>) {
      if (!COMBO_MARKETS.includes(p.prediction_type)) continue;

      const odds = p.bookmaker_odds ?? syntheticOdds(p.confidence);
      if (odds < MIN_ODDS || odds > MAX_ODDS) continue;

      const match = matchMap.get(p.match_id);
      if (!match) continue;

      pool.push({
        ...p,
        bookmaker_odds: odds,
        home_team: match.home_team,
        away_team: match.away_team,
        league: match.league,
        league_id: match.league_id,
        match_date: match.match_date,
      });
    }

    console.log(`[generate-combos] Pool: ${pool.length} eligible predictions from ${matchesRaw.length} matches (slot=${slot})`);

    if (pool.length < 3) {
      console.log(`[generate-combos] Not enough eligible predictions (need ≥3)`);
      return jsonResponse({ message: "Not enough eligible predictions for combos", pool_size: pool.length, slot });
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

    // ── COMBO 1 : "SÛR" — 2-4 jambes, cote cible 1.6–8.0 ──────
    const safeLegs = selectLegs(pool, 4, 1.6, 8.0, new Set(), 2);
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

    // ── COMBO 2 : "AUDACIEUX" — 4-6 jambes, cote entre 6.0 et 20.0 ─
    // Exclut les matchs déjà utilisés dans le combo sûr
    const safeMatchIds = new Set(safeLegs?.map(l => l.match_id) ?? []);
    
    // Pour le combo audacieux, élargit le pool : confiance >= 0.70
    const { data: widePreds } = await supabase
      .from("predictions")
      .select("id, match_id, prediction_type, prediction, confidence, bookmaker_odds")
      .in("match_id", matchIds)
      .eq("is_published", true)
      .eq("is_live", false)
      .gte("confidence", 0.70)
      .order("confidence", { ascending: false });

    const widePool: EligiblePrediction[] = [];
    for (const p of (widePreds ?? []) as Array<{ id: number; match_id: number; prediction_type: string; prediction: string; confidence: number; bookmaker_odds: number | null }>) {
      if (!COMBO_MARKETS.includes(p.prediction_type)) continue;
      const odds = p.bookmaker_odds ?? syntheticOdds(p.confidence);
      if (odds < MIN_ODDS || odds > MAX_ODDS) continue;
      const match = matchMap.get(p.match_id);
      if (!match) continue;
      widePool.push({
        ...p,
        bookmaker_odds: odds,
        home_team: match.home_team,
        away_team: match.away_team,
        league: match.league,
        league_id: match.league_id,
        match_date: match.match_date,
      });
    }

    const boldLegs = selectLegs(widePool, 6, 4.0, 30.0, safeMatchIds, 3);
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
