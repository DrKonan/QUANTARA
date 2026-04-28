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

  // Traduction lisible des types de marché pour le prompt GPT
  const marketLabels: Record<string, string> = {
    result: "Résultat 1X2",
    double_chance: "Double chance",
    over_under: "Plus/Moins de buts",
    btts: "Les deux équipes marquent",
    corners: "Nombre de corners",
    cards: "Nombre de cartons",
    correct_score: "Score exact",
    half_time: "Mi-temps résultat",
    first_team_to_score: "Première équipe à marquer",
    clean_sheet: "Feuille blanche",
  };
  const predLabels: Record<string, string> = {
    home_win: "victoire domicile", away_win: "victoire extérieur", draw: "match nul",
    "1X": "domicile ou nul", X2: "extérieur ou nul", "12": "domicile ou extérieur",
    yes: "oui", no: "non", home: "équipe domicile", away: "équipe extérieur",
  };
  const marketLabel = marketLabels[input.predictionType] ?? input.predictionType;
  const predLabel = predLabels[input.prediction] ?? input.prediction;

  const userPrompt =
    `Match : ${input.homeTeam} vs ${input.awayTeam} (${input.league})\n` +
    `Marché : ${marketLabel} → ${predLabel}\n` +
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
