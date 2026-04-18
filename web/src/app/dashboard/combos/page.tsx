import { createSupabaseAdminClient } from "@/lib/supabase/server";
import { LocalTime } from "@/components/local-time";
import { Layers, Shield, Flame, CheckCircle2, XCircle, Clock, Trophy } from "lucide-react";

export const revalidate = 60;

interface ComboLeg {
  match_id: number;
  prediction_id: number;
  prediction_type: string;
  prediction: string;
  confidence: number;
  bookmaker_odds: number;
  home_team: string;
  away_team: string;
  league: string;
}

interface Combo {
  id: number;
  combo_date: string;
  combo_type: string;
  combined_odds: number;
  combined_confidence: number;
  leg_count: number;
  legs: ComboLeg[];
  min_plan: string;
  result: string | null;
  created_at: string;
}

const TYPE_LABELS: Record<string, string> = {
  result: "Résultat",
  over_under: "Buts",
  btts: "Les 2 marquent",
  double_chance: "Double chance",
  corners: "Corners",
  cards: "Cartons",
};

export default async function CombosPage() {
  const supabase = await createSupabaseAdminClient();

  const { data: combos } = await supabase
    .from("combo_predictions")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(50);

  const list = (combos ?? []) as Combo[];

  const totalCombos = list.length;
  const wonCombos = list.filter((c) => c.result === "won").length;
  const lostCombos = list.filter((c) => c.result === "lost").length;
  const pendingCombos = list.filter((c) => c.result === null || c.result === "pending").length;
  const winRate = wonCombos + lostCombos > 0
    ? ((wonCombos / (wonCombos + lostCombos)) * 100).toFixed(1)
    : "—";

  // Group by date
  const byDate = new Map<string, Combo[]>();
  for (const c of list) {
    if (!byDate.has(c.combo_date)) byDate.set(c.combo_date, []);
    byDate.get(c.combo_date)!.push(c);
  }
  const dates = Array.from(byDate.keys()).sort((a, b) => b.localeCompare(a));

  return (
    <div className="p-4 sm:p-6 lg:p-8 max-w-7xl mx-auto">
      <div className="mb-8">
        <h2 className="text-2xl sm:text-3xl font-bold">Combinés</h2>
        <p className="text-[#6B6B80] mt-1">Combinés générés automatiquement pour PRO & VIP</p>
      </div>

      {/* Stats rapides */}
      <div className="grid grid-cols-2 sm:grid-cols-5 gap-3 mb-8">
        <div className="glass-card p-4 text-center">
          <div className="text-2xl font-bold">{totalCombos}</div>
          <div className="text-xs text-[#6B6B80] mt-1">Total</div>
        </div>
        <div className="glass-card p-4 text-center">
          <div className="text-2xl font-bold text-[#34D399]">{wonCombos}</div>
          <div className="text-xs text-[#6B6B80] mt-1">Gagnés</div>
        </div>
        <div className="glass-card p-4 text-center">
          <div className="text-2xl font-bold text-[#F87171]">{lostCombos}</div>
          <div className="text-xs text-[#6B6B80] mt-1">Perdus</div>
        </div>
        <div className="glass-card p-4 text-center">
          <div className="text-2xl font-bold text-[#6B6B80]">{pendingCombos}</div>
          <div className="text-xs text-[#6B6B80] mt-1">En attente</div>
        </div>
        <div className="glass-card p-4 text-center">
          <div className={`text-2xl font-bold ${parseFloat(winRate) >= 50 ? "text-[#D4AF37]" : "text-[#F87171]"}`}>
            {winRate}{winRate !== "—" ? "%" : ""}
          </div>
          <div className="text-xs text-[#6B6B80] mt-1">Win rate</div>
        </div>
      </div>

      {/* Liste par date */}
      {dates.length === 0 ? (
        <div className="glass-card p-12 text-center">
          <Layers size={32} className="mx-auto mb-3 text-[#6B6B80]" />
          <p className="text-[#6B6B80]">Aucun combiné généré</p>
          <p className="text-xs text-[#6B6B80] mt-1">Les combinés sont créés automatiquement chaque jour</p>
        </div>
      ) : (
        <div className="space-y-8">
          {dates.map((date) => {
            const dayCombos = byDate.get(date)!;
            return (
              <div key={date}>
                <div className="flex items-center gap-2 mb-4">
                  <Trophy size={16} className="text-[#D4AF37]" />
                  <h3 className="text-sm font-semibold text-[#9B9BB0] uppercase tracking-wider">
                    <LocalTime date={`${date}T12:00:00Z`} format="date-long" />
                  </h3>
                  <div className="flex-1 h-px bg-white/5" />
                </div>
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
                  {dayCombos.map((combo) => (
                    <ComboCard key={combo.id} combo={combo} />
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

function ComboCard({ combo }: { combo: Combo }) {
  const isSafe = combo.combo_type === "safe";
  const Icon = isSafe ? Shield : Flame;
  const label = isSafe ? "Sûr" : "Audacieux";
  const accent = isSafe ? "#34D399" : "#F59E0B";
  const planLabel = combo.min_plan === "pro" ? "PRO" : "VIP";

  const resultBorder =
    combo.result === "won" ? "border-[#34D399]/30" :
    combo.result === "lost" ? "border-[#F87171]/30" :
    "";

  return (
    <div className={`glass-card animate-fade-up overflow-hidden ${resultBorder}`}>
      {/* Header */}
      <div className="px-5 py-4 flex items-center justify-between border-b border-white/[0.06]">
        <div className="flex items-center gap-3">
          <div className="p-2 rounded-lg" style={{ backgroundColor: `${accent}15` }}>
            <Icon size={16} style={{ color: accent }} />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <span className="font-semibold">{label}</span>
              <span className="text-[9px] font-bold uppercase px-1.5 py-0.5 rounded" style={{ color: accent, backgroundColor: `${accent}15` }}>
                {planLabel}
              </span>
            </div>
            <div className="text-xs text-[#6B6B80] mt-0.5">
              {combo.leg_count} sélection{combo.leg_count > 1 ? "s" : ""}
            </div>
          </div>
        </div>
        <div className="text-right">
          <div className="text-lg font-bold text-[#D4AF37]">×{combo.combined_odds.toFixed(2)}</div>
          <ComboResultBadge result={combo.result} />
        </div>
      </div>

      {/* Legs */}
      <div className="p-4 space-y-2">
        {combo.legs.map((leg, i) => (
          <div key={i} className="flex items-center gap-3 bg-white/[0.03] rounded-lg p-3 border border-white/[0.04]">
            <div className="flex-1 min-w-0">
              <div className="text-xs text-[#6B6B80] truncate">{leg.league}</div>
              <div className="text-sm font-medium truncate">
                {leg.home_team} <span className="text-[#6B6B80]">vs</span> {leg.away_team}
              </div>
            </div>
            <div className="text-right shrink-0">
              <div className="text-xs text-[#6B6B80]">
                {TYPE_LABELS[leg.prediction_type] ?? leg.prediction_type.replace("_", " ")}
              </div>
              <div className="text-sm font-semibold">{leg.prediction}</div>
            </div>
            <div className="text-right shrink-0 ml-2">
              <div className="text-xs font-bold text-[#D4AF37]">{leg.bookmaker_odds.toFixed(2)}</div>
              <div className="text-[10px] text-[#6B6B80]">{Math.round(leg.confidence * 100)}%</div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function ComboResultBadge({ result }: { result: string | null }) {
  if (result === "won") {
    return (
      <span className="flex items-center gap-1 text-xs font-medium text-[#34D399]">
        <CheckCircle2 size={12} /> Gagné
      </span>
    );
  }
  if (result === "lost") {
    return (
      <span className="flex items-center gap-1 text-xs font-medium text-[#F87171]">
        <XCircle size={12} /> Perdu
      </span>
    );
  }
  return (
    <span className="flex items-center gap-1 text-xs text-[#6B6B80]">
      <Clock size={12} /> En cours
    </span>
  );
}
