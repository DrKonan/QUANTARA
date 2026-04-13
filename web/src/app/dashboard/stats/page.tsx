import { createSupabaseAdminClient } from "@/lib/supabase/server";

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
    <div className="p-4 sm:p-6 lg:p-8">
      <div className="mb-6 lg:mb-8">
        <h2 className="text-xl sm:text-2xl font-bold">Performance</h2>
        <p className="text-[#A0A0B0] mt-1 text-sm sm:text-base">Taux de réussite global et par catégorie</p>
      </div>

      {/* Global */}
      {globalStat && (
        <div className="bg-[#1A1A2E] rounded-xl border border-white/10 p-4 sm:p-6 mb-6 grid grid-cols-2 sm:flex sm:items-center gap-4 sm:gap-8">
          <div>
            <div className="text-sm text-[#A0A0B0]">Taux de réussite global</div>
            <div className={`text-4xl font-bold mt-1 ${winRateColor(globalStat.win_rate ?? 0)}`}>
              {globalStat.win_rate ? `${(globalStat.win_rate * 100).toFixed(1)}%` : "—"}
            </div>
          </div>
          <div className="sm:border-l sm:border-white/10 sm:pl-8">
            <div className="text-sm text-[#A0A0B0]">Pronos évalués</div>
            <div className="text-xl sm:text-2xl font-bold mt-1">{globalStat.total}</div>
          </div>
          <div className="sm:border-l sm:border-white/10 sm:pl-8">
            <div className="text-sm text-[#A0A0B0]">Gagnés</div>
            <div className="text-xl sm:text-2xl font-bold text-[#2ED573] mt-1">{globalStat.correct}</div>
          </div>
          <div className="sm:border-l sm:border-white/10 sm:pl-8">
            <div className="text-sm text-[#A0A0B0]">Perdus</div>
            <div className="text-xl sm:text-2xl font-bold text-[#FF4757] mt-1">{globalStat.incorrect}</div>
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-6">
        {/* Par ligue */}
        <div className="bg-[#1A1A2E] rounded-xl border border-white/10">
          <div className="p-5 border-b border-white/10">
            <h3 className="font-semibold">Par ligue</h3>
          </div>
          <div className="p-4 space-y-3">
            {byLeague.length === 0 && (
              <p className="text-[#A0A0B0] text-sm text-center py-4">Aucune donnée</p>
            )}
            {byLeague.map((s) => (
              <div key={`${s.league}-${s.prediction_type}`} className="flex items-center justify-between">
                <div>
                  <div className="text-sm font-medium">{s.league}</div>
                  <div className="text-xs text-[#A0A0B0]">{s.total} pronos</div>
                </div>
                <div className={`text-sm font-bold ${winRateColor(s.win_rate ?? 0)}`}>
                  {s.win_rate ? `${(s.win_rate * 100).toFixed(1)}%` : "—"}
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Par type */}
        <div className="bg-[#1A1A2E] rounded-xl border border-white/10">
          <div className="p-5 border-b border-white/10">
            <h3 className="font-semibold">Par type d&apos;événement</h3>
          </div>
          <div className="p-4 space-y-3">
            {byType.length === 0 && (
              <p className="text-[#A0A0B0] text-sm text-center py-4">Aucune donnée</p>
            )}
            {byType.map((s) => (
              <div key={`${s.league}-${s.prediction_type}`} className="flex items-center justify-between">
                <div>
                  <div className="text-sm font-medium capitalize">{s.prediction_type?.replace("_", " ")}</div>
                  <div className="text-xs text-[#A0A0B0]">{s.total} pronos</div>
                </div>
                <div className={`text-sm font-bold ${winRateColor(s.win_rate ?? 0)}`}>
                  {s.win_rate ? `${(s.win_rate * 100).toFixed(1)}%` : "—"}
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function winRateColor(rate: number): string {
  if (rate >= 0.85) return "text-[#D4AF37]";
  if (rate >= 0.75) return "text-[#2ED573]";
  if (rate >= 0.60) return "text-[#1E90FF]";
  return "text-[#FF4757]";
}
