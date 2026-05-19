import { createSupabaseAdminClient } from "@/lib/supabase/server";
import { LocalTime } from "@/components/local-time";
import {
  Layers, Shield, Flame, CheckCircle2, XCircle, Clock,
  Trophy, AlertTriangle, TrendingUp,
} from "lucide-react";

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

interface ResultDetail {
  prediction_id: number;
  is_correct: boolean | null;
}

interface Combo {
  id: number;
  combo_date: string;
  combo_type: string;
  combo_slot: string | null;
  combined_odds: number;
  combined_confidence: number;
  leg_count: number;
  legs: ComboLeg[];
  result_detail: ResultDetail[] | null;
  min_plan: string;
  status: string | null;
  created_at: string;
}

// ── Labels pour les types de marché ───────────────────────
const TYPE_LABELS: Record<string, string> = {
  result:              "Résultat",
  over_under:          "Buts (O/U)",
  btts:                "Les 2 marquent",
  double_chance:       "Double chance",
  corners:             "Corners",
  cards:               "Cartons",
  half_time:           "Mi-temps",
  halftime:            "Mi-temps",
  correct_score:       "Score exact",
  first_team_to_score: "1er buteur",
  clean_sheet:         "Feuille blanche",
};

// ── Traduction des valeurs de prédiction en français ──────
function formatPrediction(type: string, value: string): string {
  // Résultat & double chance & mi-temps
  const resultMap: Record<string, string> = {
    home_win: "Victoire dom.",
    away_win: "Victoire ext.",
    draw:     "Match nul",
    "1X":     "Dom. ou Nul",
    "X2":     "Ext. ou Nul",
    "12":     "Pas de nul",
  };
  if (resultMap[value]) return resultMap[value];

  // BTTS
  if (type === "btts") return value === "yes" ? "Les deux marquent" : "Un ne marque pas";

  // Over/Under (buts, corners, cartons)
  const ouMatch = value.match(/^(over|under)_(\d+(?:\.\d+)?)$/);
  if (ouMatch) {
    const dir  = ouMatch[1] === "over" ? "+" : "−";
    const line = ouMatch[2];
    if (type === "corners") return `${dir}${line} corners`;
    if (type === "cards")   return `${dir}${line} cartons`;
    return `${dir}${line} buts`;
  }

  // Score exact
  if (type === "correct_score") return `Score ${value}`;

  // First team to score / clean sheet
  if (type === "first_team_to_score") return value === "home" ? "Domicile en premier" : "Extérieur en premier";
  if (type === "clean_sheet")         return value === "home" ? "Cage inviolée dom." : "Cage inviolée ext.";

  return value;
}

export default async function CombosPage() {
  const supabase = await createSupabaseAdminClient();

  const { data: combos } = await supabase
    .from("combo_predictions")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(60);

  const list = (combos ?? []) as Combo[];

  const totalCombos  = list.length;
  const wonCombos    = list.filter((c) => c.status === "won").length;
  const partialCombos = list.filter((c) => c.status === "partial").length;
  const lostCombos   = list.filter((c) => c.status === "lost").length;
  const pendingCombos = list.filter((c) => !c.status || c.status === "active").length;
  const evaluated    = wonCombos + lostCombos + partialCombos;
  const winRate      = evaluated > 0
    ? ((wonCombos / evaluated) * 100).toFixed(1)
    : null;

  // Group by date
  const byDate = new Map<string, Combo[]>();
  for (const c of list) {
    if (!byDate.has(c.combo_date)) byDate.set(c.combo_date, []);
    byDate.get(c.combo_date)!.push(c);
  }
  const dates = Array.from(byDate.keys()).sort((a, b) => b.localeCompare(a));

  return (
    <div className="p-4 sm:p-6 lg:p-8 max-w-6xl mx-auto">
      {/* Header */}
      <div className="mb-8">
        <div className="flex items-center gap-3 mb-1">
          <div className="p-2 rounded-xl bg-[#D4AF37]/10">
            <Layers size={20} className="text-[#D4AF37]" />
          </div>
          <h2 className="text-2xl sm:text-3xl font-bold">Combinés</h2>
        </div>
        <p className="text-[var(--text-muted)] ml-12">Accumulateurs journaliers générés automatiquement</p>
      </div>

      {/* Stats rapides */}
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3 mb-8">
        <StatBadge label="Total" value={totalCombos} />
        <StatBadge label="En cours" value={pendingCombos} color="muted" />
        <StatBadge label="Gagnés" value={wonCombos} color="green" />
        <StatBadge label="Partiels" value={partialCombos} color="orange" />
        <StatBadge label="Perdus" value={lostCombos} color="red" />
        <div className="glass-card p-4 text-center glow-gold">
          <div className={`text-2xl font-bold ${winRate ? "text-[#D4AF37]" : "text-[var(--text-muted)]"}`}>
            {winRate ? `${winRate}%` : "—"}
          </div>
          <div className="text-[11px] text-[var(--text-muted)] mt-1 uppercase tracking-wide font-medium">Win rate</div>
          {evaluated > 0 && (
            <div className="mt-2 h-1 rounded-full bg-white/10 overflow-hidden">
              <div
                className="h-full rounded-full bg-[#D4AF37] bar-fill"
                style={{ width: `${winRate}%` }}
              />
            </div>
          )}
        </div>
      </div>

      {/* Liste par date */}
      {dates.length === 0 ? (
        <div className="glass-card p-16 text-center">
          <Layers size={36} className="mx-auto mb-4 text-[var(--text-muted)]" />
          <p className="text-[var(--text-secondary)] font-medium">Aucun combiné généré</p>
          <p className="text-xs text-[var(--text-muted)] mt-1">
            Les combinés sont créés automatiquement chaque jour à partir des pronos publiés
          </p>
        </div>
      ) : (
        <div className="space-y-10">
          {dates.map((date) => {
            const dayCombos = byDate.get(date)!;
            const dayWon    = dayCombos.filter(c => c.status === "won").length;
            const dayTotal  = dayCombos.length;
            return (
              <div key={date}>
                <div className="flex items-center gap-3 mb-4">
                  <Trophy size={15} className="text-[#D4AF37] shrink-0" />
                  <h3 className="text-xs font-bold text-[var(--text-secondary)] uppercase tracking-widest">
                    <LocalTime date={`${date}T12:00:00Z`} format="date-long" />
                  </h3>
                  {dayWon > 0 && (
                    <span className="text-[10px] font-bold text-[#34D399] bg-[#34D399]/10 px-2 py-0.5 rounded-full">
                      {dayWon}/{dayTotal} gagné{dayWon > 1 ? "s" : ""}
                    </span>
                  )}
                  <div className="flex-1 divider" />
                </div>
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
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

// ── Stat badge compact ─────────────────────────────────────
function StatBadge({ label, value, color = "default" }: { label: string; value: number; color?: "green" | "red" | "orange" | "muted" | "default" }) {
  const colors = {
    green:   "text-[#34D399]",
    red:     "text-[#F87171]",
    orange:  "text-[#FBBF24]",
    muted:   "text-[var(--text-secondary)]",
    default: "text-white",
  };
  return (
    <div className="glass-card p-4 text-center">
      <div className={`text-2xl font-bold ${colors[color]}`}>{value}</div>
      <div className="text-[11px] text-[var(--text-muted)] mt-1 uppercase tracking-wide font-medium">{label}</div>
    </div>
  );
}

// ── Combo card ─────────────────────────────────────────────
function ComboCard({ combo }: { combo: Combo }) {
  const isSafe  = combo.combo_type === "safe";
  const accent  = isSafe ? "#34D399" : "#F59E0B";
  const Icon    = isSafe ? Shield : Flame;
  const label   = isSafe ? "Sûr" : "Audacieux";
  const planLabel = combo.min_plan === "pro" ? "PRO" : "VIP";
  const confPct = Math.round((combo.combined_confidence ?? 0) * 100);

  const statusBg =
    combo.status === "won"     ? "border-[#34D399]/25 shadow-[0_0_24px_rgba(52,211,153,0.06)]" :
    combo.status === "partial" ? "border-[#FBBF24]/25 shadow-[0_0_24px_rgba(251,191,36,0.06)]" :
    combo.status === "lost"    ? "border-[#F87171]/25 shadow-[0_0_24px_rgba(248,113,113,0.06)]" :
    "";

  return (
    <div className={`glass-card animate-fade-up overflow-hidden ${statusBg}`}>
      {/* Header */}
      <div className="px-5 py-4 flex items-start justify-between border-b border-white/[0.05]">
        <div className="flex items-center gap-3">
          <div className="p-2.5 rounded-xl" style={{ background: `${accent}18` }}>
            <Icon size={17} style={{ color: accent }} />
          </div>
          <div>
          <div className="flex items-center gap-2 flex-wrap">
              <span className="font-bold text-[15px]">{label}</span>
              <span
                className="text-[9px] font-bold uppercase px-1.5 py-0.5 rounded-md tracking-wider"
                style={{ color: accent, background: `${accent}18` }}
              >
                {planLabel}
              </span>
              {combo.combo_slot === "evening" && (
                <span className="text-[9px] font-semibold px-1.5 py-0.5 rounded-md text-[#818cf8] bg-[#818cf8]/10 tracking-wider uppercase">Soir</span>
              )}
            </div>
            <div className="text-[11px] text-[var(--text-muted)] mt-0.5">
              {combo.leg_count} sélection{combo.leg_count > 1 ? "s" : ""}
            </div>
          </div>
        </div>
        <div className="text-right shrink-0 ml-2">
          <div className="text-xl font-bold text-[#D4AF37]">×{combo.combined_odds.toFixed(2)}</div>
          <ComboStatusBadge status={combo.status} />
        </div>
      </div>

      {/* Confidence bar */}
      <div className="px-5 py-3 border-b border-white/[0.05]">
        <div className="flex items-center justify-between mb-1.5">
          <div className="flex items-center gap-1.5">
            <TrendingUp size={11} className="text-[var(--text-muted)]" />
            <span className="text-[10px] text-[var(--text-muted)] uppercase tracking-wider font-medium">Confiance combinée</span>
          </div>
          <span className={`text-[11px] font-bold ${confPct >= 55 ? "text-[#34D399]" : confPct >= 40 ? "text-[#FBBF24]" : "text-[#F87171]"}`}>
            {confPct}%
          </span>
        </div>
        <div className="h-1.5 rounded-full bg-white/[0.06] overflow-hidden">
          <div
            className="h-full rounded-full bar-fill confidence-bar-fill"
            style={{ width: `${confPct}%` }}
          />
        </div>
      </div>

      {/* Legs */}
      <div className="p-4 space-y-2">
        {combo.legs.map((leg, i) => {
          const detail = combo.result_detail?.find(d => d.prediction_id === leg.prediction_id);
          return <LegRow key={i} leg={leg} isCorrect={detail?.is_correct} />;
        })}
      </div>
    </div>
  );
}

// ── Leg row ────────────────────────────────────────────────
function LegRow({ leg, isCorrect }: { leg: ComboLeg; isCorrect?: boolean | null }) {
  const typeLabel = TYPE_LABELS[leg.prediction_type] ?? leg.prediction_type;
  const predLabel = formatPrediction(leg.prediction_type, leg.prediction);
  const confPct   = Math.round(leg.confidence * 100);

  const resultBorder =
    isCorrect === true  ? "border-l-2 border-[#34D399]" :
    isCorrect === false ? "border-l-2 border-[#F87171]" :
    "";

  return (
    <div className={`surface-card p-3 flex items-center gap-3 ${resultBorder}`}>
      <div className="flex-1 min-w-0">
        <div className="text-[10px] text-[var(--text-muted)] truncate mb-0.5">{leg.league}</div>
        <div className="text-[12px] font-medium truncate">
          {leg.home_team} <span className="text-[var(--text-muted)]">vs</span> {leg.away_team}
        </div>
      </div>
      <div className="shrink-0 text-right">
        <div className="text-[10px] text-[var(--text-muted)]">{typeLabel}</div>
        <div className="text-[12px] font-semibold text-white">{predLabel}</div>
      </div>
      <div className="shrink-0 text-right ml-1 min-w-[44px]">
        {isCorrect === true  && <div className="text-[13px] text-[#34D399] font-bold">✓</div>}
        {isCorrect === false && <div className="text-[13px] text-[#F87171] font-bold">✗</div>}
        {isCorrect == null   && <div className="text-[12px] font-bold text-[#D4AF37]">{leg.bookmaker_odds.toFixed(2)}</div>}
        <div className="text-[10px] text-[var(--text-muted)]">{confPct}%</div>
      </div>
    </div>
  );
}

// ── Status badge ───────────────────────────────────────────
function ComboStatusBadge({ status }: { status: string | null }) {
  switch (status) {
    case "won":
      return <span className="flex items-center gap-1 text-[11px] font-semibold text-[#34D399] mt-0.5"><CheckCircle2 size={11} /> Gagné</span>;
    case "partial":
      return <span className="flex items-center gap-1 text-[11px] font-semibold text-[#FBBF24] mt-0.5"><AlertTriangle size={11} /> Partiel</span>;
    case "lost":
      return <span className="flex items-center gap-1 text-[11px] font-semibold text-[#F87171] mt-0.5"><XCircle size={11} /> Perdu</span>;
    default:
      return <span className="flex items-center gap-1 text-[11px] text-[var(--text-muted)] mt-0.5"><Clock size={11} /> En cours</span>;
  }
}
