// ============================================================
// QUANTARA — Shared : helpers communs
// ============================================================

/** Retourne une réponse JSON standard */
export function jsonResponse(
  data: unknown,
  status = 200,
): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** Retourne la date du jour au format YYYY-MM-DD (timezone Africa/Abidjan = UTC) */
export function todayUTC(): string {
  return new Date().toISOString().slice(0, 10);
}

/** Détermine si une ligue est Tier 1 à partir de son ID */
const TIER1_LEAGUE_IDS = new Set([2, 3, 4, 6, 39, 61, 78, 135, 140, 233]);

export function getLeagueTier(leagueId: number): 1 | 2 {
  return TIER1_LEAGUE_IDS.has(leagueId) ? 1 : 2;
}

/** Mappe le statut API-Football vers notre enum */
export function mapFixtureStatus(shortStatus: string): "scheduled" | "live" | "finished" | "cancelled" {
  const liveStatuses = ["1H", "HT", "2H", "ET", "BT", "P", "LIVE", "INT"];
  const finishedStatuses = ["FT", "AET", "PEN"];
  const cancelledStatuses = ["CANC", "ABD", "AWD", "WO", "PST", "SUSP"];

  if (liveStatuses.includes(shortStatus)) return "live";
  if (finishedStatuses.includes(shortStatus)) return "finished";
  if (cancelledStatuses.includes(shortStatus)) return "cancelled";
  return "scheduled";
}

/** Niveau de confiance en label texte */
export function confidenceLabel(confidence: number): "elevated" | "high" | "excellence" {
  if (confidence >= 0.92) return "excellence";
  if (confidence >= 0.85) return "high";
  return "elevated";
}
