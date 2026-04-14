// ============================================================
// QUANTARA — Shared : client API-Football
// Rate-limité : pour rester safe sur le plan Ultra (75k/jour)
// ============================================================

const BASE_URL = "https://v3.football.api-sports.io";
const MIN_INTERVAL_MS = 500; // 0.5s entre chaque appel (Ultra = 75k/jour)
let lastCallTime = 0;

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function throttle(): Promise<void> {
  const now = Date.now();
  const elapsed = now - lastCallTime;
  if (elapsed < MIN_INTERVAL_MS) {
    await sleep(MIN_INTERVAL_MS - elapsed);
  }
  lastCallTime = Date.now();
}

export async function apifootball(
  endpoint: string,
  params: Record<string, string | number> = {},
): Promise<unknown> {
  const apiKey = Deno.env.get("API_FOOTBALL_KEY");
  if (!apiKey) throw new Error("Missing API_FOOTBALL_KEY");

  // Rate limit : attend si nécessaire
  await throttle();

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
    const text = await res.text();
    // Si rate-limited (429), attend 30s et retente une fois
    if (res.status === 429) {
      console.warn(`[api-football] Rate limited on ${endpoint}, waiting 30s...`);
      await sleep(30_000);
      lastCallTime = Date.now();
      const retry = await fetch(url.toString(), {
        headers: {
          "X-RapidAPI-Key": apiKey,
          "X-RapidAPI-Host": "v3.football.api-sports.io",
        },
      });
      if (!retry.ok) throw new Error(`API-Football ${retry.status}: ${await retry.text()}`);
      const retryJson = await retry.json() as { errors?: unknown; response?: unknown };
      if (retryJson.errors && Object.keys(retryJson.errors as object).length > 0) {
        throw new Error(`API-Football error: ${JSON.stringify(retryJson.errors)}`);
      }
      return retryJson.response;
    }
    throw new Error(`API-Football ${res.status}: ${text}`);
  }

  const json = await res.json() as { errors?: unknown; response?: unknown };

  if (json.errors && Object.keys(json.errors as object).length > 0) {
    throw new Error(`API-Football error: ${JSON.stringify(json.errors)}`);
  }

  return json.response;
}

/**
 * Exécute plusieurs appels API-Football séquentiellement (avec throttle).
 * Remplace Promise.all(apifootball(...)) pour éviter les rafales.
 */
export async function apifootballSequential<T>(
  calls: Array<() => Promise<T>>,
): Promise<T[]> {
  const results: T[] = [];
  for (const call of calls) {
    results.push(await call());
  }
  return results;
}
