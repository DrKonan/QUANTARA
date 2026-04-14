import { createSupabaseAdminClient } from "@/lib/supabase/server";
import { Filter } from "lucide-react";

export const revalidate = 30;

const CATEGORY_LABELS: Record<string, { label: string; emoji: string }> = {
  major_international: { label: "Compétitions internationales", emoji: "🏆" },
  top5: { label: "Top 5 européen", emoji: "⭐" },
  europe: { label: "Europe", emoji: "🇪🇺" },
  south_america: { label: "Amérique du Sud", emoji: "🌎" },
  rest_of_world: { label: "Reste du monde", emoji: "🌍" },
  other: { label: "Autres", emoji: "⚽" },
};

const TYPE_LABELS: Record<string, string> = {
  result: "Résultat",
  over_under: "Buts",
  btts: "Les 2 marquent",
  home_win: "Victoire dom.",
  away_win: "Victoire ext.",
  draw: "Match nul",
};

interface Prediction {
  id: number;
  prediction: string;
  prediction_type: string;
  confidence: number;
  confidence_label: string;
  is_correct: boolean | null;
  is_live: boolean;
  is_premium: boolean;
  is_published: boolean;
  is_refined: boolean;
  created_at: string;
  match_id: number;
  matches: {
    home_team: string;
    away_team: string;
    league: string;
    league_id: number;
    match_date: string;
    status: string;
    home_score: number | null;
    away_score: number | null;
  } | null;
}

interface GroupedMatch {
  match_id: number;
  home_team: string;
  away_team: string;
  league: string;
  league_id: number;
  match_date: string;
  status: string;
  home_score: number | null;
  away_score: number | null;
  category: string;
  country: string;
  predictions: Prediction[];
}

export default async function PredictionsPage() {
  const supabase = await createSupabaseAdminClient();

  const [{ data: predictions }, { data: leaguesMeta }] = await Promise.all([
    supabase
      .from("predictions")
      .select("id, prediction, prediction_type, confidence, confidence_label, is_correct, is_live, is_premium, is_published, is_refined, created_at, match_id, matches(home_team, away_team, league, league_id, match_date, status, home_score, away_score)")
      .eq("is_published", true)
      .order("created_at", { ascending: false })
      .limit(200),
    supabase.from("leagues_config").select("league_id, country, category"),
  ]);

  const leagueMap = new Map<number, { category: string; country: string }>();
  for (const l of (leaguesMeta ?? [])) {
    leagueMap.set(l.league_id, { category: l.category, country: l.country ?? "" });
  }

  const list = (predictions ?? []) as unknown as Prediction[];

  // Group by match
  const matchMap = new Map<number, GroupedMatch>();
  for (const pred of list) {
    if (!pred.matches) continue;
    if (!matchMap.has(pred.match_id)) {
      matchMap.set(pred.match_id, {
        match_id: pred.match_id,
        home_team: pred.matches.home_team,
        away_team: pred.matches.away_team,
        league: pred.matches.league,
        league_id: pred.matches.league_id,
        match_date: pred.matches.match_date,
        status: pred.matches.status,
        home_score: pred.matches.home_score,
        away_score: pred.matches.away_score,
        category: leagueMap.get(pred.matches.league_id)?.category ?? "other",
        country: leagueMap.get(pred.matches.league_id)?.country ?? "",
        predictions: [],
      });
    }
    matchMap.get(pred.match_id)!.predictions.push(pred);
  }

  // Group by category
  const categoryOrder = ["major_international", "top5", "europe", "south_america", "rest_of_world", "other"];
  const byCategory = new Map<string, GroupedMatch[]>();
  for (const m of matchMap.values()) {
    if (!byCategory.has(m.category)) byCategory.set(m.category, []);
    byCategory.get(m.category)!.push(m);
  }
  // Sort matches within each category: live first, then by date desc
  const statusPriority: Record<string, number> = { live: 0, scheduled: 1, finished: 2 };
  for (const matches of byCategory.values()) {
    matches.sort((a, b) => {
      const sp = (statusPriority[a.status] ?? 3) - (statusPriority[b.status] ?? 3);
      if (sp !== 0) return sp;
      return b.match_date.localeCompare(a.match_date);
    });
  }

  const totalPreds = list.length;
  const livePreds = list.filter(p => p.is_live).length;
  const premiumPreds = list.filter(p => p.is_premium).length;

  return (
    <div className="p-4 sm:p-6 lg:p-8 max-w-7xl mx-auto">
      <div className="mb-8">
        <h2 className="text-2xl sm:text-3xl font-bold">Pronos</h2>
        <div className="flex items-center gap-4 mt-2">
          <span className="text-sm text-[#6B6B80]">{totalPreds} pronos</span>
          {livePreds > 0 && <span className="text-sm text-[#F87171]">{livePreds} live</span>}
          <span className="text-sm text-[#D4AF37]">{premiumPreds} premium</span>
        </div>
      </div>

      {totalPreds === 0 ? (
        <div className="glass-card p-12 text-center">
          <Filter size={32} className="mx-auto mb-3 text-[#6B6B80]" />
          <p className="text-[#6B6B80]">Aucun prono publié</p>
        </div>
      ) : (
        <div className="space-y-8">
          {categoryOrder.map((cat) => {
            const matches = byCategory.get(cat);
            if (!matches || matches.length === 0) return null;
            const info = CATEGORY_LABELS[cat] ?? CATEGORY_LABELS.other;
            return (
              <div key={cat}>
                <div className="flex items-center gap-2 mb-4">
                  <span>{info.emoji}</span>
                  <h3 className="text-sm font-semibold text-[#9B9BB0] uppercase tracking-wider">{info.label}</h3>
                  <div className="flex-1 h-px bg-white/5" />
                  <span className="text-xs text-[#6B6B80]">{matches.length} match{matches.length > 1 ? "s" : ""}</span>
                </div>
                <div className="space-y-4">
                  {matches.map((m) => (
                    <MatchPredictionCard key={m.match_id} match={m} />
                  ))}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

function MatchPredictionCard({ match }: { match: GroupedMatch }) {
  const isLive = match.status === "live";
  const isFinished = match.status === "finished";
  const time = new Date(match.match_date).toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" });
  const date = new Date(match.match_date).toLocaleDateString("fr-FR", { day: "2-digit", month: "2-digit" });

  return (
    <div className={`glass-card animate-fade-up overflow-hidden ${isLive ? "border-[#F87171]/20" : ""}`}>
      {/* Match header */}
      <div className="px-5 py-4 flex items-center justify-between border-b border-white/[0.06]">
        <div className="flex items-center gap-3 min-w-0">
          <div className="min-w-0">
            <div className="flex items-center gap-2">
              <span className="font-semibold truncate">{match.home_team}</span>
              <span className="text-[#6B6B80] text-sm">vs</span>
              <span className="font-semibold truncate">{match.away_team}</span>
            </div>
            <div className="flex items-center gap-2 mt-0.5">
              <span className="text-xs text-[#6B6B80]">{match.league}{match.country ? ` · ${match.country}` : ""}</span>
              <span className="text-[#6B6B80]">·</span>
              <span className="text-xs text-[#6B6B80]">{date} {time}</span>
            </div>
          </div>
        </div>
        <div className="flex items-center gap-3 ml-3">
          {(isLive || isFinished) && match.home_score !== null && (
            <span className={`text-lg font-bold ${isLive ? "text-[#F87171]" : "text-white"}`}>
              {match.home_score} - {match.away_score}
            </span>
          )}
          {isLive && (
            <span className="flex items-center gap-1 px-2 py-0.5 rounded-full bg-[#F87171]/10 text-[#F87171] text-xs font-medium">
              <span className="w-1.5 h-1.5 rounded-full bg-[#F87171] live-pulse" /> LIVE
            </span>
          )}
          {isFinished && (
            <span className="px-2 py-0.5 rounded-full bg-[#34D399]/10 text-[#34D399] text-xs font-medium">Terminé</span>
          )}
        </div>
      </div>

      {/* Predictions grid */}
      <div className="p-4 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
        {match.predictions.map((pred) => (
          <PredictionChip key={pred.id} prediction={pred} />
        ))}
      </div>
    </div>
  );
}

function PredictionChip({ prediction: p }: { prediction: Prediction }) {
  const pct = Math.round(p.confidence * 100);
  const typeLabel = TYPE_LABELS[p.prediction_type] ?? p.prediction_type.replace("_", " ");

  const confColor =
    p.confidence >= 0.8 ? "from-[#D4AF37] to-[#B8961F]" :
    p.confidence >= 0.7 ? "from-[#34D399] to-[#059669]" :
    p.confidence >= 0.6 ? "from-[#60A5FA] to-[#2563EB]" :
    "from-[#6B6B80] to-[#4B4B60]";

  const confText =
    p.confidence >= 0.8 ? "text-[#D4AF37]" :
    p.confidence >= 0.7 ? "text-[#34D399]" :
    p.confidence >= 0.6 ? "text-[#60A5FA]" :
    "text-[#9B9BB0]";

  return (
    <div className="bg-white/[0.03] rounded-xl p-3 border border-white/[0.04] hover:border-white/[0.08] transition-colors">
      <div className="flex items-center justify-between mb-2">
        <span className="text-xs text-[#6B6B80]">{typeLabel}</span>
        <div className="flex items-center gap-1.5">
          {p.is_live && <span className="text-[9px] font-bold text-[#F87171] uppercase">Live</span>}
          {p.is_premium && <span className="text-[9px] font-bold text-[#D4AF37] uppercase">Premium</span>}
          {p.is_refined && <span className="text-[9px] font-bold text-[#60A5FA] uppercase">Affiné</span>}
        </div>
      </div>
      <div className="font-semibold text-sm mb-2">{p.prediction}</div>
      <div className="flex items-center gap-2">
        <div className="flex-1 h-1.5 bg-white/[0.06] rounded-full overflow-hidden">
          <div
            className={`h-full rounded-full bg-gradient-to-r ${confColor} bar-fill`}
            style={{ width: `${pct}%` }}
          />
        </div>
        <span className={`text-xs font-bold ${confText}`}>{pct}%</span>
      </div>
      {p.is_correct !== null && (
        <div className="mt-2 pt-2 border-t border-white/[0.04]">
          <span className={`text-xs font-medium ${p.is_correct ? "text-[#34D399]" : "text-[#F87171]"}`}>
            {p.is_correct ? "✅ Gagné" : "❌ Perdu"}
          </span>
        </div>
      )}
    </div>
  );
}
