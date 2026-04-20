"use client";

import { useState, useTransition } from "react";
import { toggleLeague, triggerFetchMatches } from "./actions";
import { Globe, RefreshCw } from "lucide-react";

interface League {
  league_id: number;
  league_name: string;
  country: string;
  tier: number;
  is_active: boolean;
  category: string;
}

interface LeaguesManagerProps {
  leagues: League[];
}

const TIER_LABELS: Record<number, { label: string; color: string }> = {
  1: { label: "Tier 1", color: "text-[#D4AF37] bg-[#D4AF37]/10" },
  2: { label: "Tier 2", color: "text-[#60A5FA] bg-[#60A5FA]/10" },
  3: { label: "Expansion", color: "text-[#9B9BB0] bg-white/5" },
};

const CATEGORY_LABELS: Record<string, string> = {
  major_international: "🏆 Internationales",
  top5: "⭐ Top 5",
  europe: "🇪🇺 Europe",
  south_america: "🌎 Amérique du Sud",
  rest_of_world: "🌍 Reste du monde",
};

export function LeaguesManager({ leagues: initial }: LeaguesManagerProps) {
  const [leagues, setLeagues] = useState(initial);
  const [toggling, setToggling] = useState<number | null>(null);
  const [fetchingMatches, startFetch] = useTransition();
  const [fetchResult, setFetchResult] = useState<{ ok: boolean; msg: string } | null>(null);

  async function handleToggle(leagueId: number, newActive: boolean) {
    setToggling(leagueId);
    const result = await toggleLeague(leagueId, newActive);
    setToggling(null);
    if (result.success) {
      setLeagues((prev) =>
        prev.map((l) => (l.league_id === leagueId ? { ...l, is_active: newActive } : l))
      );
    }
  }

  function handleFetch() {
    startFetch(async () => {
      setFetchResult(null);
      const result = await triggerFetchMatches();
      if (result.success && result.data) {
        const d = result.data as Record<string, number>;
        setFetchResult({
          ok: true,
          msg: `${d.totalFiltered ?? d.upserted ?? 0} matchs récupérés (${d.newMatches ?? 0} nouveaux, ${d.expansionMatches ?? 0} expansion)`,
        });
      } else {
        setFetchResult({ ok: false, msg: result.error ?? "Erreur" });
      }
      setTimeout(() => setFetchResult(null), 5000);
    });
  }

  // Group by category
  const categoryOrder = ["major_international", "top5", "europe", "south_america", "rest_of_world"];
  const byCategory = new Map<string, League[]>();
  for (const l of leagues) {
    const cat = l.category || "rest_of_world";
    if (!byCategory.has(cat)) byCategory.set(cat, []);
    byCategory.get(cat)!.push(l);
  }
  for (const arr of byCategory.values()) {
    arr.sort((a, b) => a.tier - b.tier || a.league_name.localeCompare(b.league_name));
  }

  const activeCount = leagues.filter((l) => l.is_active).length;
  const expansionCount = leagues.filter((l) => l.tier === 3).length;

  return (
    <div>
      {/* Header + actions */}
      <div className="flex items-center justify-between mb-4 flex-wrap gap-3">
        <div className="flex items-center gap-3">
          <Globe size={18} className="text-[#D4AF37]" />
          <span className="text-sm text-[#9B9BB0]">
            {activeCount} actives · {expansionCount} expansion
          </span>
        </div>
        <div className="flex items-center gap-3">
          {fetchResult && (
            <span className={`text-xs ${fetchResult.ok ? "text-[#34D399]" : "text-[#F87171]"}`}>
              {fetchResult.msg}
            </span>
          )}
          <button
            onClick={handleFetch}
            disabled={fetchingMatches}
            className="flex items-center gap-2 px-4 py-2 bg-white/5 border border-white/[0.08] rounded-lg text-sm text-[#9B9BB0] hover:text-white hover:border-[#D4AF37]/30 transition-all disabled:opacity-50"
          >
            <RefreshCw size={14} className={fetchingMatches ? "animate-spin" : ""} />
            Re-fetch matchs
          </button>
        </div>
      </div>

      {/* Leagues by category */}
      <div className="space-y-6">
        {categoryOrder.map((cat) => {
          const catLeagues = byCategory.get(cat);
          if (!catLeagues || catLeagues.length === 0) return null;
          return (
            <div key={cat}>
              <h4 className="text-sm font-semibold text-[#9B9BB0] uppercase tracking-wider mb-3">
                {CATEGORY_LABELS[cat] ?? cat}
              </h4>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                {catLeagues.map((league) => {
                  const tier = TIER_LABELS[league.tier] ?? TIER_LABELS[2];
                  const isToggling = toggling === league.league_id;
                  return (
                    <div
                      key={league.league_id}
                      className={`flex items-center justify-between px-4 py-3 rounded-xl border transition-all ${
                        league.is_active
                          ? "bg-white/[0.03] border-white/[0.08]"
                          : "bg-white/[0.01] border-white/[0.04] opacity-60"
                      }`}
                    >
                      <div className="flex items-center gap-3 min-w-0">
                        <div className="min-w-0">
                          <div className="text-sm font-medium truncate">{league.league_name}</div>
                          <div className="flex items-center gap-2 mt-0.5">
                            <span className="text-xs text-[#6B6B80]">{league.country}</span>
                            <span className={`text-[10px] font-bold uppercase px-1.5 py-0.5 rounded ${tier.color}`}>
                              {tier.label}
                            </span>
                          </div>
                        </div>
                      </div>
                      <button
                        onClick={() => handleToggle(league.league_id, !league.is_active)}
                        disabled={isToggling}
                        className={`relative w-11 h-6 rounded-full transition-colors duration-200 ${
                          league.is_active ? "bg-[#34D399]" : "bg-white/10"
                        } ${isToggling ? "opacity-50" : ""}`}
                      >
                        <span
                          className={`absolute top-0.5 left-0.5 w-5 h-5 rounded-full bg-white shadow-sm transition-transform duration-200 ${
                            league.is_active ? "translate-x-5" : "translate-x-0"
                          }`}
                        />
                      </button>
                    </div>
                  );
                })}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
