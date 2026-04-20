// ============================================================
// QUANTARA — Edge Function : generate-combos
//
// Génère 1 à 2 combinés du jour à partir des TOP PICKS prematch.
// 
// STRATÉGIE :
// — Sélectionne des prédictions à confiance ≥ 0.80 avec cotes bookmaker
// — Marchés robustes uniquement : btts, over_under, double_chance
//   (peu sensibles aux changements de compo)
// — Max 1 jambe par match, diversité de ligues favorisée
// — "Sûr" (3-4 jambes, cote ~3-6) → PRO + VIP
// — "Audacieux" (4-6 jambes, cote ~6-15) → VIP uniquement
//
// Cron : 4h et 21h UTC (après predict-prematch à 3h et 20h)
// ============================================================
import { getSupabaseAdmin } from "../_shared/supabase.ts";
import { jsonResponse } from "../_shared/helpers.ts";

// Marchés autorisés pour les combinés (robustes face aux changements de compo)
const COMBO_MARKETS = ["btts", "over_under", "double_chance"];
const MIN_CONFIDENCE = 0.80;
const MIN_ODDS = 1.25;    // cote min par jambe (éviter les pari à 1.05)
const MAX_ODDS = 3.50;    // cote max par jambe (éviter les paris trop risqués)

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

  if (selected.length < 3) return null; // minimum 3 jambes pour un combiné

  // Vérifie que les cotes combinées sont dans la cible
  const combinedOdds = selected.reduce((acc, l) => acc * l.bookmaker_odds, 1);
  if (combinedOdds < targetMinOdds || combinedOdds > targetMaxOdds) {
    // Essaie d'ajuster en retirant/ajoutant des jambes
    // Si trop haut : retire la jambe la moins confiante
    while (combinedOdds > targetMaxOdds && selected.length > 3) {
      selected.sort((a, b) => a.confidence - b.confidence);
      selected.shift(); // retire la moins confiante
    }
    // Recalcule
    const adjusted = selected.reduce((acc, l) => acc * l.bookmaker_odds, 1);
    if (adjusted < targetMinOdds * 0.8) return null; // trop faible même après ajustement
  }

  return selected.length >= 3 ? selected : null;
}

Deno.serve(async (req: Request) => {
  try {
    const supabase = getSupabaseAdmin();

    // Journée sportive (06:00 UTC → 05:59 UTC+1)
    const now = new Date();
    const today = now.toISOString().slice(0, 10);
    const dayStart = `${today}T06:00:00+00:00`;
    const nextDay = new Date(now.getTime() + 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
    const dayEnd = `${nextDay}T05:59:59+00:00`;

    // Vérifie qu'on n'a pas déjà généré de combos aujourd'hui
    const { data: existingCombos } = await supabase
      .from("combo_predictions")
      .select("id")
      .eq("combo_date", today);

    if (existingCombos && existingCombos.length > 0) {
      console.log(`[generate-combos] Combos already exist for ${today}, skipping`);
      return jsonResponse({ message: "Combos already generated", date: today });
    }

    // Récupère toutes les prédictions éligibles du jour
    // Joindre avec matches pour avoir les infos équipes/ligue
    const { data: matchesRaw } = await supabase
      .from("matches")
      .select("id, home_team, away_team, league, league_id, match_date, status")
      .gte("match_date", dayStart)
      .lte("match_date", dayEnd)
      .eq("status", "scheduled")
      .not("tier", "is", null);

    if (!matchesRaw || matchesRaw.length === 0) {
      console.log(`[generate-combos] No scheduled matches for ${today}`);
      return jsonResponse({ message: "No matches today", date: today });
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
      .not("bookmaker_odds", "is", null);

    if (!predsRaw || predsRaw.length === 0) {
      console.log(`[generate-combos] No eligible predictions with odds for ${today}`);
      return jsonResponse({ message: "No predictions with bookmaker odds", date: today });
    }

    // Filtre : marchés robustes uniquement + cotes dans la plage acceptable
    const pool: EligiblePrediction[] = [];
    for (const p of predsRaw as Array<{ id: number; match_id: number; prediction_type: string; prediction: string; confidence: number; bookmaker_odds: number }>) {
      if (!COMBO_MARKETS.includes(p.prediction_type)) continue;
      if (p.bookmaker_odds < MIN_ODDS || p.bookmaker_odds > MAX_ODDS) continue;

      const match = matchMap.get(p.match_id);
      if (!match) continue;

      pool.push({
        ...p,
        home_team: match.home_team,
        away_team: match.away_team,
        league: match.league,
        league_id: match.league_id,
        match_date: match.match_date,
      });
    }

    console.log(`[generate-combos] Pool: ${pool.length} eligible predictions from ${matchesRaw.length} matches`);

    if (pool.length < 3) {
      console.log(`[generate-combos] Not enough eligible predictions (need ≥3)`);
      return jsonResponse({ message: "Not enough eligible predictions for combos", pool_size: pool.length });
    }

    const combosToInsert: Array<{
      combo_date: string;
      combo_type: string;
      combined_odds: number;
      combined_confidence: number;
      leg_count: number;
      legs: ComboLeg[];
      min_plan: string;
    }> = [];

    // ── COMBO 1 : "SÛR" — 3-4 jambes, cote entre 2.5 et 7.0 ────
    const safeLegs = selectLegs(pool, 4, 2.5, 7.0, new Set());
    if (safeLegs) {
      const combinedOdds = safeLegs.reduce((acc, l) => acc * l.bookmaker_odds, 1);
      const combinedConf = safeLegs.reduce((acc, l) => acc * l.confidence, 1);
      combosToInsert.push({
        combo_date: today,
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
    
    // Pour le combo audacieux, élargit le pool : confiance >= 0.78
    const { data: widePreds } = await supabase
      .from("predictions")
      .select("id, match_id, prediction_type, prediction, confidence, bookmaker_odds")
      .in("match_id", matchIds)
      .eq("is_published", true)
      .eq("is_live", false)
      .gte("confidence", 0.78)
      .not("bookmaker_odds", "is", null);

    const widePool: EligiblePrediction[] = [];
    for (const p of (widePreds ?? []) as Array<{ id: number; match_id: number; prediction_type: string; prediction: string; confidence: number; bookmaker_odds: number }>) {
      if (!COMBO_MARKETS.includes(p.prediction_type)) continue;
      if (p.bookmaker_odds < MIN_ODDS || p.bookmaker_odds > MAX_ODDS) continue;
      const match = matchMap.get(p.match_id);
      if (!match) continue;
      widePool.push({
        ...p,
        home_team: match.home_team,
        away_team: match.away_team,
        league: match.league,
        league_id: match.league_id,
        match_date: match.match_date,
      });
    }

    const boldLegs = selectLegs(widePool, 6, 6.0, 25.0, safeMatchIds);
    if (boldLegs) {
      const combinedOdds = boldLegs.reduce((acc, l) => acc * l.bookmaker_odds, 1);
      const combinedConf = boldLegs.reduce((acc, l) => acc * l.confidence, 1);
      combosToInsert.push({
        combo_date: today,
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
      console.log(`[generate-combos] Could not build any valid combo for ${today}`);
      return jsonResponse({ message: "Not enough diverse predictions for combos", date: today });
    }

    const { error: insertError } = await supabase
      .from("combo_predictions")
      .insert(combosToInsert);

    if (insertError) throw insertError;

    console.log(`[generate-combos] Generated ${combosToInsert.length} combo(s) for ${today}`);

    // Notifie les utilisateurs PRO/VIP via notify-users
    try {
      const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
      const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
      const safeCombo = combosToInsert.find(c => c.combo_type === "safe");

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
        }),
      });
      console.log(`[generate-combos] Notification sent via notify-users`);
    } catch (notifErr) {
      console.warn(`[generate-combos] Notification failed:`, notifErr);
    }

    return jsonResponse({
      success: true,
      date: today,
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
