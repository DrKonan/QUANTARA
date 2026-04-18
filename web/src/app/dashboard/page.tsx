import { createSupabaseAdminClient } from "@/lib/supabase/server";
import { StatCard } from "@/components/stat-card";
import { LocalTime } from "@/components/local-time";
import { Users, ListChecks, TrendingUp, CreditCard, Trophy, Clock, CheckCircle2, Radio, Layers } from "lucide-react";

export const revalidate = 60;

const CATEGORY_LABELS: Record<string, { label: string; emoji: string }> = {
  major_international: { label: "Compétitions internationales", emoji: "🏆" },
  top5: { label: "Top 5 européen", emoji: "⭐" },
  europe: { label: "Europe", emoji: "🇪🇺" },
  south_america: { label: "Amérique du Sud", emoji: "🌎" },
  rest_of_world: { label: "Reste du monde", emoji: "🌍" },
  other: { label: "Autres", emoji: "⚽" },
};

interface MatchWithPredictions {
  id: number;
  home_team: string;
  away_team: string;
  league: string;
  league_id: number;
  match_date: string;
  status: string;
  home_score: number | null;
  away_score: number | null;
  prediction_count: number;
  category: string;
  country: string;
}

async function getDashboardStats() {
  const supabase = await createSupabaseAdminClient();

  const [
    { count: totalUsers },
    { count: premiumUsers },
    { count: totalPredictions },
    { count: activeSubs },
    { data: globalStats },
    { data: recentPredictions },
    { data: todayMatches },
    { data: todayPredictions },
    { data: leaguesMeta },
    { data: todayCombos },
  ] = await Promise.all([
    supabase.from("users").select("*", { count: "exact", head: true }),
    supabase.from("users").select("*", { count: "exact", head: true }).in("plan", ["starter", "pro", "vip"]),
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
      .select("id, prediction, prediction_type, confidence, confidence_label, is_correct, is_live, is_refined, created_at, matches(home_team, away_team, league)")
      .eq("is_published", true)
      .order("created_at", { ascending: false })
      .limit(10),
    (() => {
      // Sports day: 06:00 UTC today → 05:59 UTC tomorrow (captures SA night matches)
      const today = new Date().toISOString().slice(0, 10);
      const tomorrow = new Date(Date.now() + 86400000).toISOString().slice(0, 10);
      return supabase
        .from("matches")
        .select("id, home_team, away_team, league, league_id, match_date, status, home_score, away_score")
        .gte("match_date", `${today}T06:00:00+00:00`)
        .lte("match_date", `${tomorrow}T05:59:59+00:00`)
        .not("status", "eq", "cancelled")
        .order("match_date");
    })(),
    supabase
      .from("predictions")
      .select("match_id")
      .eq("is_published", true),
    supabase
      .from("leagues_config")
      .select("league_id, country, category"),
    supabase
      .from("combo_predictions")
      .select("id, combo_type, result")
      .eq("combo_date", new Date().toISOString().slice(0, 10)),
  ]);

  // Build league metadata map
  const leagueMap = new Map<number, { country: string; category: string }>();
  for (const l of (leaguesMeta ?? [])) {
    leagueMap.set(l.league_id, { country: l.country, category: l.category });
  }

  // Count predictions per match
  const predCountMap = new Map<number, number>();
  for (const p of (todayPredictions ?? [])) {
    predCountMap.set(p.match_id, (predCountMap.get(p.match_id) ?? 0) + 1);
  }

  // Enrich matches — exclut les terminés sans prono (inutiles dans l'admin)
  const enrichedMatches: MatchWithPredictions[] = (todayMatches ?? [])
    .map((m: { id: number; home_team: string; away_team: string; league: string; league_id: number; match_date: string; status: string; home_score: number | null; away_score: number | null }) => ({
      ...m,
      prediction_count: predCountMap.get(m.id) ?? 0,
      category: leagueMap.get(m.league_id)?.category ?? "other",
      country: leagueMap.get(m.league_id)?.country ?? "",
    }))
    .filter((m) => !(m.status === "finished" && m.prediction_count === 0));

  return {
    totalUsers: totalUsers ?? 0,
    premiumUsers: premiumUsers ?? 0,
    totalPredictions: totalPredictions ?? 0,
    activeSubs: activeSubs ?? 0,
    globalStats: globalStats ?? { total: 0, correct: 0, win_rate: 0 },
    recentPredictions: (recentPredictions ?? []) as unknown as RecentPrediction[],
    todayMatches: enrichedMatches,
    todayCombos: (todayCombos ?? []) as Array<{ id: number; combo_type: string; result: string | null }>,
  };
}

export default async function DashboardPage() {
  const stats = await getDashboardStats();
  const winRate = stats.globalStats.win_rate
    ? `${(stats.globalStats.win_rate * 100).toFixed(1)}%`
    : "—";

  // Group matches by category — tri : live d'abord, puis plus récent en haut
  const categoryOrder = ["major_international", "top5", "europe", "south_america", "rest_of_world", "other"];
  const matchesByCategory = new Map<string, MatchWithPredictions[]>();
  for (const m of stats.todayMatches) {
    const cat = m.category;
    if (!matchesByCategory.has(cat)) matchesByCategory.set(cat, []);
    matchesByCategory.get(cat)!.push(m);
  }
  // Tri intra-catégorie : live > scheduled > finished, puis par heure décroissante
  const statusPriority: Record<string, number> = { live: 0, scheduled: 1, finished: 2 };
  for (const matches of matchesByCategory.values()) {
    matches.sort((a, b) => {
      const sp = (statusPriority[a.status] ?? 3) - (statusPriority[b.status] ?? 3);
      if (sp !== 0) return sp;
      return b.match_date.localeCompare(a.match_date); // plus récent en haut
    });
  }

  const liveCount = stats.todayMatches.filter(m => m.status === "live").length;
  const finishedCount = stats.todayMatches.filter(m => m.status === "finished").length;
  const scheduledCount = stats.todayMatches.filter(m => m.status === "scheduled").length;

  return (
    <div className="p-4 sm:p-6 lg:p-8 max-w-7xl mx-auto">
      {/* Header */}
      <div className="mb-8">
        <h2 className="text-2xl sm:text-3xl font-bold">Vue d&apos;ensemble</h2>
        <p className="text-[#6B6B80] mt-1">
          <LocalTime date={new Date().toISOString()} format="full" />
        </p>
      </div>

      {/* Stats cards */}
      <div className="grid grid-cols-2 lg:grid-cols-5 gap-3 sm:gap-4 mb-8">
        <StatCard
          title="Utilisateurs"
          value={stats.totalUsers.toLocaleString("fr")}
          subtitle={`${stats.premiumUsers} payant${stats.premiumUsers > 1 ? "s" : ""}`}
          icon={<Users size={18} />}
          color="gold"
        />
        <StatCard
          title="Win rate"
          value={winRate}
          subtitle={`${stats.globalStats.correct}/${stats.globalStats.total}`}
          icon={<TrendingUp size={18} />}
          color={stats.globalStats.win_rate >= 0.75 ? "green" : "default"}
        />
        <StatCard
          title="Pronos publiés"
          value={stats.totalPredictions.toLocaleString("fr")}
          subtitle="total"
          icon={<ListChecks size={18} />}
          color="default"
        />
        <StatCard
          title="Abonnements"
          value={stats.activeSubs.toLocaleString("fr")}
          subtitle="actifs"
          icon={<CreditCard size={18} />}
          color="green"
        />
        <StatCard
          title="Combinés du jour"
          value={stats.todayCombos.length.toString()}
          subtitle={stats.todayCombos.filter(c => c.result === "won").length > 0 ? `${stats.todayCombos.filter(c => c.result === "won").length} gagné(s)` : "en cours"}
          icon={<Layers size={18} />}
          color="gold"
        />
      </div>

      {/* Matchs du jour */}
      <div className="mb-8">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-3">
            <Trophy size={20} className="text-[#D4AF37]" />
            <h3 className="text-lg font-semibold">Matchs du jour</h3>
          </div>
          <div className="flex items-center gap-3 text-xs">
            {liveCount > 0 && (
              <span className="flex items-center gap-1.5 text-[#F87171]">
                <Radio size={12} className="live-pulse" /> {liveCount} live
              </span>
            )}
            <span className="flex items-center gap-1.5 text-[#6B6B80]">
              <Clock size={12} /> {scheduledCount} à venir
            </span>
            <span className="flex items-center gap-1.5 text-[#6B6B80]">
              <CheckCircle2 size={12} /> {finishedCount} terminés
            </span>
          </div>
        </div>

        {stats.todayMatches.length === 0 ? (
          <div className="glass-card p-8 text-center">
            <p className="text-[#6B6B80]">Aucun match aujourd&apos;hui</p>
          </div>
        ) : (
          <div className="space-y-6">
            {categoryOrder.map((cat) => {
              const matches = matchesByCategory.get(cat);
              if (!matches || matches.length === 0) return null;
              const info = CATEGORY_LABELS[cat] ?? CATEGORY_LABELS.other;
              return (
                <div key={cat}>
                  <div className="flex items-center gap-2 mb-3">
                    <span className="text-sm">{info.emoji}</span>
                    <h4 className="text-sm font-semibold text-[#9B9BB0] uppercase tracking-wider">{info.label}</h4>
                    <div className="flex-1 h-px bg-white/5" />
                  </div>
                  <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                    {matches.map((m) => (
                      <MatchCard key={m.id} match={m} />
                    ))}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Pronos récents */}
      <div className="glass-card">
        <div className="p-5 border-b border-white/[0.06]">
          <h3 className="font-semibold">Derniers pronos</h3>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-white/[0.04] text-[#6B6B80]">
                <th className="text-left p-4 font-medium text-xs uppercase tracking-wider">Match</th>
                <th className="text-left p-4 font-medium text-xs uppercase tracking-wider">Prono</th>
                <th className="text-left p-4 font-medium text-xs uppercase tracking-wider">Type</th>
                <th className="text-right p-4 font-medium text-xs uppercase tracking-wider">Confiance</th>
                <th className="text-right p-4 font-medium text-xs uppercase tracking-wider">Résultat</th>
              </tr>
            </thead>
            <tbody>
              {stats.recentPredictions.map((pred: RecentPrediction) => (
                <tr key={pred.id} className="border-b border-white/[0.04] hover:bg-white/[0.02] transition-colors">
                  <td className="p-4">
                    <span className="text-[#9B9BB0]">{(pred.matches as MatchRef)?.home_team}</span>
                    <span className="text-[#6B6B80] mx-1.5">vs</span>
                    <span className="text-[#9B9BB0]">{(pred.matches as MatchRef)?.away_team}</span>
                  </td>
                  <td className="p-4 font-medium">
                    {pred.prediction}
                    {pred.is_refined && (
                      <span className="ml-1.5 text-[9px] font-bold text-[#60A5FA] uppercase">Affiné</span>
                    )}
                  </td>
                  <td className="p-4 text-[#6B6B80]">{pred.prediction_type.replace("_", " ")}</td>
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
// Types
// ----------------------------------------------------------------
interface MatchRef { home_team: string; away_team: string; league: string }
interface RecentPrediction {
  id: number;
  prediction: string;
  prediction_type: string;
  confidence: number;
  confidence_label: string;
  is_correct: boolean | null;
  is_live: boolean;
  is_refined: boolean;
  created_at: string;
  matches: MatchRef | null;
}

// ----------------------------------------------------------------
// Sub-composants
// ----------------------------------------------------------------
function MatchCard({ match }: { match: MatchWithPredictions }) {
  const isLive = match.status === "live";
  const isFinished = match.status === "finished";
  return (
    <div className={`glass-card p-4 animate-fade-up ${isLive ? "border-[#F87171]/30" : ""}`}>
      <div className="flex items-center justify-between mb-3">
        <span className="text-xs text-[#6B6B80] truncate">{match.league}{match.country ? ` · ${match.country}` : ""}</span>
        {isLive ? (
          <span className="flex items-center gap-1 text-xs font-medium text-[#F87171]">
            <span className="w-1.5 h-1.5 rounded-full bg-[#F87171] live-pulse" /> LIVE
          </span>
        ) : isFinished ? (
          <span className="text-xs text-[#34D399] font-medium">Terminé</span>
        ) : (
          <LocalTime date={match.match_date} format="time" className="text-xs text-[#6B6B80]" />
        )}
      </div>
      <div className="flex items-center justify-between">
        <div className="flex-1 min-w-0">
          <div className="text-sm font-medium truncate">{match.home_team}</div>
          <div className="text-sm font-medium truncate text-[#9B9BB0]">{match.away_team}</div>
        </div>
        {(isLive || isFinished) && match.home_score !== null ? (
          <div className="text-right ml-3">
            <div className={`text-lg font-bold ${isLive ? "text-[#F87171]" : "text-white"}`}>
              {match.home_score} - {match.away_score}
            </div>
          </div>
        ) : (
          <div className="text-right ml-3">
            <div className="text-lg font-bold text-[#6B6B80]">vs</div>
          </div>
        )}
      </div>
      {match.prediction_count > 0 && (
        <div className="mt-3 pt-3 border-t border-white/[0.06]">
          <span className="text-xs text-[#D4AF37]">{match.prediction_count} prono{match.prediction_count > 1 ? "s" : ""}</span>
        </div>
      )}
    </div>
  );
}

function ConfidenceBadge({ label, value }: { label: string; value: number }) {
  const colors: Record<string, string> = {
    excellence: "text-[#D4AF37] bg-[#D4AF37]/10",
    high: "text-[#34D399] bg-[#34D399]/10",
    elevated: "text-[#60A5FA] bg-[#60A5FA]/10",
  };
  return (
    <span className={`px-2 py-0.5 rounded-md text-xs font-medium ${colors[label] ?? "text-white bg-white/10"}`}>
      {(value * 100).toFixed(0)}%
    </span>
  );
}

function ResultBadge({ isCorrect }: { isCorrect: boolean | null }) {
  if (isCorrect === null) return <span className="text-[#6B6B80] text-xs">En attente</span>;
  return (
    <span className={`text-xs font-medium ${isCorrect ? "text-[#34D399]" : "text-[#F87171]"}`}>
      {isCorrect ? "✅ Gagné" : "❌ Perdu"}
    </span>
  );
}
