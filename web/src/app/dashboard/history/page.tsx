import { createSupabaseAdminClient } from "@/lib/supabase/server";
import { LocalTime } from "@/components/local-time";
import { History, CheckCircle2, XCircle, Clock } from "lucide-react";

export const revalidate = 60;

const TYPE_LABELS: Record<string, string> = {
  result: "Résultat",
  over_under: "Buts",
  btts: "Les 2 marquent",
  home_win: "Victoire dom.",
  away_win: "Victoire ext.",
  draw: "Match nul",
  double_chance: "Double chance",
  corners: "Corners",
  cards: "Cartons",
};

interface HistoryPrediction {
  id: number;
  prediction: string;
  prediction_type: string;
  confidence: number;
  confidence_label: string;
  is_correct: boolean | null;
  is_live: boolean;
  is_premium: boolean;
  is_refined: boolean;
  is_top_pick: boolean;
  created_at: string;
  match_id: number;
  matches: {
    home_team: string;
    away_team: string;
    league: string;
    league_id: number;
    league_country: string | null;
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
  match_date: string;
  home_score: number | null;
  away_score: number | null;
  country: string;
  predictions: HistoryPrediction[];
  correct: number;
  incorrect: number;
  pending: number;
}

export default async function HistoryPage() {
  const supabase = await createSupabaseAdminClient();

  const [{ data: predictions }, { data: leaguesMeta }] = await Promise.all([
    supabase
      .from("predictions")
      .select("id, prediction, prediction_type, confidence, confidence_label, is_correct, is_live, is_premium, is_refined, is_top_pick, created_at, match_id, matches(home_team, away_team, league, league_id, league_country, match_date, status, home_score, away_score)")
      .eq("is_published", true)
      .gte("confidence", 0.70)
      .not("matches.status", "eq", "scheduled")
      .order("created_at", { ascending: false })
      .limit(500),
    supabase.from("leagues_config").select("league_id, country"),
  ]);

  const countryMap = new Map<number, string>();
  for (const l of (leaguesMeta ?? [])) {
    countryMap.set(l.league_id, l.country ?? "");
  }

  const list = (predictions ?? []) as unknown as HistoryPrediction[];

  // Group by match — only finished matches or matches with evaluated predictions
  const matchMap = new Map<number, GroupedMatch>();
  for (const pred of list) {
    if (!pred.matches) continue;
    if (pred.matches.status !== "finished" && pred.matches.status !== "live") continue;

    if (!matchMap.has(pred.match_id)) {
      matchMap.set(pred.match_id, {
        match_id: pred.match_id,
        home_team: pred.matches.home_team,
        away_team: pred.matches.away_team,
        league: pred.matches.league,
        match_date: pred.matches.match_date,
        home_score: pred.matches.home_score,
        away_score: pred.matches.away_score,
        country: pred.matches.league_country ?? countryMap.get(pred.matches.league_id) ?? "",
        predictions: [],
        correct: 0,
        incorrect: 0,
        pending: 0,
      });
    }
    const group = matchMap.get(pred.match_id)!;
    group.predictions.push(pred);
    if (pred.is_correct === true) group.correct++;
    else if (pred.is_correct === false) group.incorrect++;
    else group.pending++;
  }

  // Sort by date desc (most recent first)
  const matches = Array.from(matchMap.values()).sort(
    (a, b) => b.match_date.localeCompare(a.match_date)
  );

  // Stats globales — Winrate : tous les pronos évalués (>= 70% déjà filtrés par la query)
  const evaluatedPreds = list.filter(p => p.is_correct !== null);
  const totalPreds = evaluatedPreds.length;
  const correctPreds = evaluatedPreds.filter(p => p.is_correct === true).length;
  const winRate = totalPreds > 0 ? ((correctPreds / totalPreds) * 100).toFixed(1) : "—";

  return (
    <div className="p-4 sm:p-6 lg:p-8 max-w-7xl mx-auto">
      <div className="mb-8">
        <h2 className="text-2xl sm:text-3xl font-bold">Historique</h2>
        <p className="text-[#6B6B80] mt-1">Résultats de nos prédictions passées</p>
      </div>

      {/* Stats rapides */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-8">
        <div className="glass-card p-4 text-center">
          <div className="text-2xl font-bold">{matches.length}</div>
          <div className="text-xs text-[#6B6B80] mt-1">Matchs analysés</div>
        </div>
        <div className="glass-card p-4 text-center">
          <div className="text-2xl font-bold">{totalPreds}</div>
          <div className="text-xs text-[#6B6B80] mt-1">Pronos évalués</div>
        </div>
        <div className="glass-card p-4 text-center">
          <div className="text-2xl font-bold text-[#34D399]">{correctPreds}</div>
          <div className="text-xs text-[#6B6B80] mt-1">Gagnés</div>
        </div>
        <div className="glass-card p-4 text-center">
          <div className={`text-2xl font-bold ${parseFloat(winRate) >= 60 ? "text-[#D4AF37]" : parseFloat(winRate) >= 50 ? "text-[#34D399]" : "text-[#F87171]"}`}>
            {winRate}%
          </div>
          <div className="text-xs text-[#6B6B80] mt-1">Taux de réussite</div>
        </div>
      </div>

      {/* Liste des matchs */}
      {matches.length === 0 ? (
        <div className="glass-card p-12 text-center">
          <History size={32} className="mx-auto mb-3 text-[#6B6B80]" />
          <p className="text-[#6B6B80]">Aucun historique disponible</p>
          <p className="text-xs text-[#6B6B80] mt-1">Les résultats apparaîtront après l&apos;évaluation des matchs terminés</p>
        </div>
      ) : (
        <div className="space-y-3">
          {matches.map((m) => (
            <MatchHistoryCard key={m.match_id} match={m} />
          ))}
        </div>
      )}
    </div>
  );
}

function MatchHistoryCard({ match }: { match: GroupedMatch }) {


  const totalEval = match.correct + match.incorrect;
  const matchWinRate = totalEval > 0 ? Math.round((match.correct / totalEval) * 100) : null;

  return (
    <div className="glass-card animate-fade-up overflow-hidden">
      {/* Header : match info + score */}
      <div className="px-5 py-4 flex items-center justify-between border-b border-white/[0.06]">
        <div className="flex items-center gap-3 min-w-0 flex-1">
          <div className="text-center shrink-0">
            <LocalTime date={match.match_date} format="date-long" className="text-xs text-[#6B6B80] block" />
            <LocalTime date={match.match_date} format="time" className="text-[10px] text-[#6B6B80] block" />
          </div>
          <div className="h-8 w-px bg-white/[0.06]" />
          <div className="min-w-0">
            <div className="flex items-center gap-2">
              <span className="font-semibold truncate">{match.home_team}</span>
              <span className="text-lg font-bold text-white">
                {match.home_score ?? "?"} - {match.away_score ?? "?"}
              </span>
              <span className="font-semibold truncate">{match.away_team}</span>
            </div>
            <div className="text-xs text-[#6B6B80] mt-0.5">
              {match.league}{match.country ? ` · ${match.country}` : ""}
            </div>
          </div>
        </div>

        {/* Win rate du match */}
        <div className="flex items-center gap-3 ml-3 shrink-0">
          {matchWinRate !== null && (
            <div className={`text-sm font-bold ${matchWinRate >= 75 ? "text-[#D4AF37]" : matchWinRate >= 50 ? "text-[#34D399]" : "text-[#F87171]"}`}>
              {match.correct}/{totalEval}
            </div>
          )}
          {match.pending > 0 && (
            <span className="flex items-center gap-1 text-xs text-[#6B6B80]">
              <Clock size={12} /> {match.pending}
            </span>
          )}
        </div>
      </div>

      {/* Predictions */}
      <div className="p-4 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2">
        {match.predictions.map((pred) => (
          <PredictionResult key={pred.id} prediction={pred} />
        ))}
      </div>
    </div>
  );
}

function PredictionResult({ prediction: p }: { prediction: HistoryPrediction }) {
  const pct = Math.round(p.confidence * 100);
  const typeLabel = TYPE_LABELS[p.prediction_type] ?? p.prediction_type.replace("_", " ");

  const isCorrect = p.is_correct === true;
  const isIncorrect = p.is_correct === false;
  const isPending = p.is_correct === null;

  const borderColor = isCorrect
    ? "border-[#34D399]/20"
    : isIncorrect
    ? "border-[#F87171]/20"
    : "border-white/[0.04]";

  const bgColor = isCorrect
    ? "bg-[#34D399]/5"
    : isIncorrect
    ? "bg-[#F87171]/5"
    : "bg-white/[0.03]";

  return (
    <div className={`rounded-xl p-3 border ${borderColor} ${bgColor} transition-colors`}>
      <div className="flex items-center justify-between mb-1.5">
        <span className="text-xs text-[#6B6B80]">{typeLabel}</span>
        <div className="flex items-center gap-1.5">
          {p.is_refined && <span className="text-[9px] font-bold text-[#60A5FA] uppercase">Affiné</span>}
          {p.is_premium && <span className="text-[9px] font-bold text-[#D4AF37] uppercase">Premium</span>}
        </div>
      </div>
      <div className="flex items-center justify-between">
        <span className="font-semibold text-sm">{p.prediction}</span>
        <span className="text-xs text-[#6B6B80]">{pct}%</span>
      </div>
      <div className="flex items-center gap-1.5 mt-2">
        {isCorrect && (
          <span className="flex items-center gap-1 text-xs font-medium text-[#34D399]">
            <CheckCircle2 size={12} /> Gagné
          </span>
        )}
        {isIncorrect && (
          <span className="flex items-center gap-1 text-xs font-medium text-[#F87171]">
            <XCircle size={12} /> Perdu
          </span>
        )}
        {isPending && (
          <span className="flex items-center gap-1 text-xs text-[#6B6B80]">
            <Clock size={12} /> En attente
          </span>
        )}
      </div>
    </div>
  );
}
