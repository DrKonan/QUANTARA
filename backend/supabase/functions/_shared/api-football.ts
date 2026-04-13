// ============================================================
// QUANTARA — Shared : client API-Football
// ============================================================

const BASE_URL = "https://v3.football.api-sports.io";

export async function apifootball(
  endpoint: string,
  params: Record<string, string | number> = {},
): Promise<unknown> {
  const apiKey = Deno.env.get("API_FOOTBALL_KEY");
  if (!apiKey) throw new Error("Missing API_FOOTBALL_KEY");

  const url = new URL(`${BASE_URL}${endpoint}`);
  for (const [k, v] of Object.entries(params)) {
    url.searchParams.set(k, String(v));
  }

  const res = await fetch(url.toString(), {
    headers: {
      "X-RapidAPI-Key": apiKey,
      "X-RapidAPI-Host": "v3.football.api-sports.io",
    },
  });

  if (!res.ok) {
    throw new Error(`API-Football ${res.status}: ${await res.text()}`);
  }

  const json = await res.json() as { errors?: unknown; response?: unknown };

  if (json.errors && Object.keys(json.errors as object).length > 0) {
    throw new Error(`API-Football error: ${JSON.stringify(json.errors)}`);
  }

  return json.response;
}
