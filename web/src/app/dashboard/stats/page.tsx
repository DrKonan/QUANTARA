import { createSupabaseAdminClient } from "@/lib/supabase/server";
import { Target, Trophy, BarChart3 } from "lucide-react";

export const revalidate = 300;

interface PredictionStat {
  period: string;
  sport: string;
  league: string | null;
  prediction_type: string | null;
  total: number;
  correct: number;
  incorrect: number;
  win_rate: number | null;
}

const TYPE_LABELS: Record<string, string> = {
  result: "Résultat",
  over_under: "Buts (O/U)",
  btts: "Les 2 marquent",
  double_chance: "Double chance",
  corners: "Corners",
  cards: "Cartons",
};

export default async function StatsPage() {
  const supabase = await createSupabaseAdminClient();

  const { data: stats } = await supabase
    .from("prediction_stats")
    .select("*")
    .order("total", { ascending: false });

  const all = (stats ?? []) as PredictionStat[];

  const globalStat = all.find(
    (s) => s.period === "all_time" && s.league === null && s.prediction_type === null
  );

  const byLeague = all.filter(
    (s) => s.period === "all_time" && s.league !== null && s.prediction_type === null
  );

  const byType = all.filter(
    (s) => s.period === "all_time" && s.prediction_type !== null && s.league === null
  );

  return (
    <div className="p-4 sm:p-6 lg:p-8 max-w-7xl mx-auto">
      <div className="mb-8">
        <h2 className="text-2xl sm:text-3xl font-bold">Performance</h2>
        <p className="text-[#6B6B80] mt-1">Taux de réussite global et par catégorie</p>
      </div>

      {/* Global hero stat */}
      {globalStat && (
        <div className="glass-card p-6 sm:p-8 mb-8 glow-gold">
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-6">
            <div className="col-span-2 sm:col-span-1">
              <div className="flex items-center gap-2 mb-2">
                <Target size={16} className="text-[#D4AF37]" />
                <span className="text-xs font-medium uppercase tracking-wider text-[#6B6B80]">Win rate global</span>
              </div>
              <div className={`text-5xl font-bold ${winRateColor(globalStat.win_rate ?? 0)}`}>
                {globalStat.win_rate ? `${(globalStat.win_rate * 100).toFixed(1)}%` : "—"}
              </div>
              {globalStat.win_rate && (
                <div className="mt-3 h-2 bg-white/[0.06] rounded-full overflow-hidden">
                  <div
                    className={`h-full rounded-full bar-fill ${winRateGradient(globalStat.win_rate)}`}
                    style={{ width: `${globalStat.win_rate * 100}%` }}
                  />
                </div>
              )}
            </div>
            <div>
              <span className="text-xs font-medium uppercase tracking-wider text-[#6B6B80]">Évalués</span>
              <div className="text-3xl font-bold mt-2">{globalStat.total}</div>
            </div>
            <div>
              <span className="text-xs font-medium uppercase tracking-wider text-[#6B6B80]">Gagnés</span>
              <div className="text-3xl font-bold text-[#34D399] mt-2">{globalStat.correct}</div>
            </div>
            <div>
              <span className="text-xs font-medium uppercase tracking-wider text-[#6B6B80]">Perdus</span>
              <div className="text-3xl font-bold text-[#F87171] mt-2">{globalStat.incorrect}</div>
            </div>
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Par ligue */}
        <div className="glass-card">
          <div className="p-5 border-b border-white/[0.06] flex items-center gap-2">
            <Trophy size={16} className="text-[#D4AF37]" />
            <h3 className="font-semibold">Par ligue</h3>
          </div>
          <div className="p-5 space-y-4">
            {byLeague.length === 0 && (
              <p className="text-[#6B6B80] text-sm text-center py-6">Aucune donnée</p>
            )}
            {byLeague.map((s) => (
              <WinRateRow
                key={`league-${s.league}`}
                label={s.league ?? ""}
                total={s.total}
                winRate={s.win_rate ?? 0}
              />
            ))}
          </div>
        </div>

        {/* Par type */}
        <div className="glass-card">
          <div className="p-5 border-b border-white/[0.06] flex items-center gap-2">
            <BarChart3 size={16} className="text-[#60A5FA]" />
            <h3 className="font-semibold">Par type</h3>
          </div>
          <div className="p-5 space-y-4">
            {byType.length === 0 && (
              <p className="text-[#6B6B80] text-sm text-center py-6">Aucune donnée</p>
            )}
            {byType.map((s) => (
              <WinRateRow
                key={`type-${s.prediction_type}`}
                label={TYPE_LABELS[s.prediction_type ?? ""] ?? s.prediction_type?.replace("_", " ") ?? ""}
                total={s.total}
                winRate={s.win_rate ?? 0}
              />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function WinRateRow({ label, total, winRate }: { label: string; total: number; winRate: number }) {
  const pct = Math.round(winRate * 100);
  return (
    <div>
      <div className="flex items-center justify-between mb-1.5">
        <div>
          <span className="text-sm font-medium">{label}</span>
          <span className="text-xs text-[#6B6B80] ml-2">{total} pronos</span>
        </div>
        <span className={`text-sm font-bold tabular-nums ${winRateColor(winRate)}`}>
          {winRate ? `${pct}%` : "—"}
        </span>
      </div>
      <div className="h-2 bg-white/[0.06] rounded-full overflow-hidden">
        <div
          className={`h-full rounded-full bar-fill ${winRateGradient(winRate)}`}
          style={{ width: `${pct}%` }}
        />
      </div>
    </div>
  );
}

function winRateColor(rate: number): string {
  if (rate >= 0.85) return "text-[#D4AF37]";
  if (rate >= 0.75) return "text-[#34D399]";
  if (rate >= 0.60) return "text-[#60A5FA]";
  return "text-[#F87171]";
}

function winRateGradient(rate: number): string {
  if (rate >= 0.85) return "bg-gradient-to-r from-[#D4AF37] to-[#F5E6A3]";
  if (rate >= 0.75) return "bg-gradient-to-r from-[#34D399] to-[#6EE7B7]";
  if (rate >= 0.60) return "bg-gradient-to-r from-[#60A5FA] to-[#93C5FD]";
  return "bg-gradient-to-r from-[#F87171] to-[#FCA5A5]";
}
