// ============================================================
// NAKORA — Shared : génération analyse textuelle (OpenAI)
// ============================================================

export interface AnalysisInput {
  homeTeam: string;
  awayTeam: string;
  league: string;
  matchDate: string;
  predictionType: string;
  prediction: string;
  confidence: number;
  scoreBreakdown: Record<string, number>;
  lang?: "fr" | "en";
}

export async function generateAnalysis(input: AnalysisInput): Promise<string | null> {
  const openaiKey = Deno.env.get("OPENAI_API_KEY");
  const model = Deno.env.get("OPENAI_MODEL") ?? "gpt-4o";

  if (!openaiKey) {
    console.warn("[openai] No OPENAI_API_KEY — skipping analysis generation");
    return null;
  }

  const lang = input.lang ?? "fr";
  const topIndicators = Object.entries(input.scoreBreakdown)
    .sort(([, a], [, b]) => b - a)
    .slice(0, 3)
    .map(([k, v]) => `${k}: ${(v * 100).toFixed(1)}%`)
    .join(", ");

  const systemPrompt =
    `Tu es un analyste sportif expert. En 2-3 phrases maximum, explique pourquoi ` +
    `cet événement est pertinent à jouer sur ce match. Sois factuel, précis, ` +
    `et base-toi uniquement sur les données fournies. Pas de jargon complexe. ` +
    `Langue : ${lang}.`;

  const userPrompt =
    `Match : ${input.homeTeam} vs ${input.awayTeam} (${input.league})\n` +
    `Événement : ${input.prediction} (type: ${input.predictionType})\n` +
    `Confiance : ${(input.confidence * 100).toFixed(1)}%\n` +
    `Indicateurs clés : ${topIndicators}`;

  try {
    const res = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${openaiKey}`,
      },
      body: JSON.stringify({
        model,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
        max_tokens: 150,
        temperature: 0.4,
      }),
    });

    if (!res.ok) {
      console.error("[openai] API error:", await res.text());
      return null;
    }

    const json = await res.json() as {
      choices: Array<{ message: { content: string } }>;
    };
    return json.choices?.[0]?.message?.content?.trim() ?? null;
  } catch (err) {
    console.error("[openai] Error:", err);
    return null;
  }
}
