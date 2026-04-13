import { createSupabaseAdminClient } from "@/lib/supabase/server";
import { StatCard } from "@/components/stat-card";
import { Users, ListChecks, TrendingUp, CreditCard } from "lucide-react";

export const revalidate = 60; // Revalide toutes les 60 secondes

async function getDashboardStats() {
  const supabase = await createSupabaseAdminClient();

  const [
    { count: totalUsers },
    { count: premiumUsers },
    { count: totalPredictions },
    { count: activeSubs },
    { data: globalStats },
    { data: recentPredictions },
  ] = await Promise.all([
    supabase.from("users").select("*", { count: "exact", head: true }),
    supabase.from("users").select("*", { count: "exact", head: true }).eq("plan", "premium"),
    supabase.from("predictions").select("*", { count: "exact", head: true }).eq("is_published", true),
    supabase.from("subscriptions").select("*", { count: "exact", head: true }).eq("status", "active"),
    supabase
      .from("prediction_stats")
      .select("total, correct, win_rate")
      .eq("period", "all_time")
      .is("league", null)
      .is("prediction_type", null)
      .single(),
    supabase
      .from("predictions")
      .select("id, prediction, prediction_type, confidence, confidence_label, is_correct, created_at, matches(home_team, away_team, league)")
      .eq("is_published", true)
      .order("created_at", { ascending: false })
      .limit(10),
  ]);

  return {
    totalUsers: totalUsers ?? 0,
    premiumUsers: premiumUsers ?? 0,
    totalPredictions: totalPredictions ?? 0,
    activeSubs: activeSubs ?? 0,
    globalStats: globalStats ?? { total: 0, correct: 0, win_rate: 0 },
    recentPredictions: (recentPredictions ?? []) as unknown as RecentPrediction[],
  };
}

export default async function DashboardPage() {
  const stats = await getDashboardStats();
  const winRate = stats.globalStats.win_rate
    ? `${(stats.globalStats.win_rate * 100).toFixed(1)}%`
    : "—";

  return (
    <div className="p-8">
      <div className="mb-8">
        <h2 className="text-2xl font-bold">Vue d&apos;ensemble</h2>
        <p className="text-[#A0A0B0] mt-1">Statistiques globales de Quantara</p>
      </div>

      {/* Stats cards */}
      <div className="grid grid-cols-4 gap-4 mb-8">
        <StatCard
          title="Utilisateurs"
          value={stats.totalUsers.toLocaleString("fr")}
          subtitle={`dont ${stats.premiumUsers} premium`}
          icon={<Users size={20} />}
          color="gold"
        />
        <StatCard
          title="Taux de réussite"
          value={winRate}
          subtitle={`${stats.globalStats.correct}/${stats.globalStats.total} pronos`}
          icon={<TrendingUp size={20} />}
          color={stats.globalStats.win_rate >= 0.75 ? "green" : "default"}
        />
        <StatCard
          title="Pronos publiés"
          value={stats.totalPredictions.toLocaleString("fr")}
          subtitle="tous temps"
          icon={<ListChecks size={20} />}
          color="default"
        />
        <StatCard
          title="Abonnements actifs"
          value={stats.activeSubs.toLocaleString("fr")}
          subtitle="abonnés premium"
          icon={<CreditCard size={20} />}
          color="green"
        />
      </div>

      {/* Pronos récents */}
      <div className="bg-[#1A1A2E] rounded-xl border border-white/10">
        <div className="p-5 border-b border-white/10">
          <h3 className="font-semibold">Pronos récents</h3>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-white/5 text-[#A0A0B0]">
                <th className="text-left p-4 font-medium">Match</th>
                <th className="text-left p-4 font-medium">Événement</th>
                <th className="text-left p-4 font-medium">Type</th>
                <th className="text-right p-4 font-medium">Confiance</th>
                <th className="text-right p-4 font-medium">Résultat</th>
              </tr>
            </thead>
            <tbody>
              {stats.recentPredictions.map((pred: RecentPrediction) => (
                <tr key={pred.id} className="border-b border-white/5 hover:bg-white/2">
                  <td className="p-4 text-[#A0A0B0]">
                    {(pred.matches as MatchRef)?.home_team} vs {(pred.matches as MatchRef)?.away_team}
                  </td>
                  <td className="p-4 font-medium">{pred.prediction}</td>
                  <td className="p-4 text-[#A0A0B0]">{pred.prediction_type}</td>
                  <td className="p-4 text-right">
                    <ConfidenceBadge label={pred.confidence_label} value={pred.confidence} />
                  </td>
                  <td className="p-4 text-right">
                    <ResultBadge isCorrect={pred.is_correct} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

// ----------------------------------------------------------------
// Types locaux
// ----------------------------------------------------------------
interface MatchRef { home_team: string; away_team: string; league: string }
interface RecentPrediction {
  id: number;
  prediction: string;
  prediction_type: string;
  confidence: number;
  confidence_label: string;
  is_correct: boolean | null;
  created_at: string;
  matches: MatchRef | null;
}

// ----------------------------------------------------------------
// Sub-composants inline
// ----------------------------------------------------------------
function ConfidenceBadge({ label, value }: { label: string; value: number }) {
  const colors: Record<string, string> = {
    excellence: "text-[#D4AF37] bg-[#D4AF37]/10",
    high: "text-[#2ED573] bg-[#2ED573]/10",
    elevated: "text-[#1E90FF] bg-[#1E90FF]/10",
  };
  return (
    <span className={`px-2 py-0.5 rounded text-xs font-medium ${colors[label] ?? "text-white bg-white/10"}`}>
      {(value * 100).toFixed(0)}%
    </span>
  );
}

function ResultBadge({ isCorrect }: { isCorrect: boolean | null }) {
  if (isCorrect === null) return <span className="text-[#A0A0B0] text-xs">En attente</span>;
  return (
    <span className={`text-xs font-medium ${isCorrect ? "text-[#2ED573]" : "text-[#FF4757]"}`}>
      {isCorrect ? "✅ Gagné" : "❌ Perdu"}
    </span>
  );
}
