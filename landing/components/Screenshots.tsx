// Simulation de captures d'écran de l'app mobile sous forme de maquettes stylisées

const screens = [
  {
    title: "Pronostics du jour",
    desc: "Tous les matchs analysés avec leur probabilité et cote recommandée",
    accent: "#D4AF37",
    preview: (
      <MatchPreview />
    ),
  },
  {
    title: "Combos automatiques",
    desc: "Safe & Bold générés chaque jour avec détail des sélections",
    accent: "#22c55e",
    preview: <ComboPreview />,
  },
  {
    title: "Tableau de bord",
    desc: "Suivi de tes performances, win rate et historique complet",
    accent: "#818cf8",
    preview: <DashPreview />,
  },
];

function MatchPreview() {
  const items = [
    { home: "Man City", away: "Arsenal", pred: "Victoire dom.", conf: 81, odds: "1.72", color: "#22c55e" },
    { home: "PSG", away: "Lyon", pred: "+2.5 Buts", conf: 76, odds: "1.55", color: "#D4AF37" },
    { home: "Real Madrid", away: "Barça", pred: "Les 2 marquent", conf: 79, odds: "1.68", color: "#22c55e" },
  ];
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
      {items.map(i => (
        <div key={i.home} style={{ background: "rgba(255,255,255,0.05)", borderRadius: 10, padding: "10px 12px" }}>
          <div style={{ fontSize: 11, color: "rgba(240,240,240,0.5)", marginBottom: 4 }}>{i.home} vs {i.away}</div>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
            <span style={{ fontSize: 12, fontWeight: 600, color: "#f0f0f0" }}>{i.pred}</span>
            <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
              <span style={{ fontSize: 11, color: i.color, fontWeight: 700 }}>{i.conf}%</span>
              <span style={{ fontSize: 12, fontWeight: 700, color: "#D4AF37" }}>×{i.odds}</span>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}

function ComboPreview() {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
      <div style={{ background: "rgba(34,197,94,0.08)", border: "1px solid rgba(34,197,94,0.2)", borderRadius: 10, padding: "10px 12px" }}>
        <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 6 }}>
          <span style={{ fontSize: 11, fontWeight: 700, color: "#22c55e" }}>🛡️ COMBO SÛR</span>
          <span style={{ fontSize: 13, fontWeight: 800, color: "#D4AF37" }}>×3.24</span>
        </div>
        {["Man City — Victoire dom.", "Real Madrid — BTTS: Oui", "PSG — +2.5 Buts"].map(l => (
          <div key={l} style={{ fontSize: 11, color: "rgba(240,240,240,0.6)", padding: "3px 0", borderTop: "1px solid rgba(255,255,255,0.05)" }}>{l}</div>
        ))}
      </div>
      <div style={{ background: "rgba(245,158,11,0.08)", border: "1px solid rgba(245,158,11,0.2)", borderRadius: 10, padding: "10px 12px" }}>
        <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 6 }}>
          <span style={{ fontSize: 11, fontWeight: 700, color: "#f59e0b" }}>🔥 COMBO AUDACIEUX</span>
          <span style={{ fontSize: 13, fontWeight: 800, color: "#D4AF37" }}>×8.71</span>
        </div>
        {["Arsenal — Victoire dom.", "Bayern — +3.5 Buts", "Juve — Dom. ou Nul", "Ajax — BTTS: Non", "Atlético — -1.5 Buts"].map(l => (
          <div key={l} style={{ fontSize: 11, color: "rgba(240,240,240,0.6)", padding: "3px 0", borderTop: "1px solid rgba(255,255,255,0.05)" }}>{l}</div>
        ))}
      </div>
    </div>
  );
}

function DashPreview() {
  const bars = [65, 80, 55, 90, 73, 85];
  return (
    <div>
      <div style={{ display: "flex", gap: 8, marginBottom: 12 }}>
        {[
          { label: "Pronos", val: "247", color: "#D4AF37" },
          { label: "Win rate", val: "85%", color: "#22c55e" },
          { label: "Streak", val: "+8", color: "#818cf8" },
        ].map(s => (
          <div key={s.label} style={{ flex: 1, background: "rgba(255,255,255,0.05)", borderRadius: 8, padding: "8px 6px", textAlign: "center" }}>
            <div style={{ fontSize: 14, fontWeight: 700, color: s.color }}>{s.val}</div>
            <div style={{ fontSize: 9, color: "rgba(240,240,240,0.4)" }}>{s.label}</div>
          </div>
        ))}
      </div>
      <div style={{ background: "rgba(255,255,255,0.04)", borderRadius: 8, padding: "10px 8px" }}>
        <div style={{ fontSize: 10, color: "rgba(240,240,240,0.4)", marginBottom: 8 }}>Performance 6 derniers jours</div>
        <div style={{ display: "flex", gap: 4, alignItems: "flex-end", height: 40 }}>
          {bars.map((b, i) => (
            <div key={i} style={{ flex: 1, background: b > 75 ? "rgba(34,197,94,0.6)" : "rgba(212,175,55,0.5)", borderRadius: 3, height: `${b * 0.4}px` }} />
          ))}
        </div>
      </div>
    </div>
  );
}

export default function Screenshots() {
  return (
    <section style={{ padding: "96px 24px", position: "relative", overflow: "hidden" }}>
      {/* Background */}
      <div style={{
        position: "absolute", inset: 0,
        background: "linear-gradient(180deg, transparent, rgba(212,175,55,0.04), transparent)",
        pointerEvents: "none",
      }} />

      <div style={{ maxWidth: 1200, margin: "0 auto", position: "relative" }}>
        {/* Header */}
        <div style={{ textAlign: "center", marginBottom: 64 }}>
          <div style={{
            display: "inline-block",
            background: "rgba(212,175,55,0.1)", border: "1px solid rgba(212,175,55,0.2)",
            borderRadius: 999, padding: "5px 16px", marginBottom: 20,
          }}>
            <span style={{ fontSize: 12, color: "#D4AF37", fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.5px" }}>Aperçu</span>
          </div>
          <h2 style={{ fontSize: "clamp(1.75rem, 4vw, 2.75rem)", fontWeight: 800, letterSpacing: "-0.5px", marginBottom: 16 }}>
            Une app pensée pour les
            <br />
            <span className="text-gold-gradient">parieurs exigeants</span>
          </h2>
          <p style={{ color: "rgba(240,240,240,0.55)", fontSize: 16, maxWidth: 480, margin: "0 auto" }}>
            Interface claire, infos pertinentes, zéro superflu.
          </p>
        </div>

        {/* Phone mockups */}
        <div style={{
          display: "flex",
          gap: 28,
          justifyContent: "center",
          flexWrap: "wrap",
        }}>
          {screens.map((s, idx) => (
            <div key={s.title} style={{
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              gap: 20,
              opacity: 1,
              transform: idx === 1 ? "translateY(-20px)" : "translateY(0)",
            }}>
              {/* Phone frame */}
              <div style={{
                width: 220,
                background: "#0f0f1a",
                borderRadius: 32,
                border: `2px solid ${s.accent}30`,
                padding: "20px 16px",
                boxShadow: `0 24px 60px rgba(0,0,0,0.5), 0 0 40px ${s.accent}15`,
                position: "relative",
              }}>
                {/* Notch */}
                <div style={{
                  width: 80, height: 6, background: "rgba(255,255,255,0.08)",
                  borderRadius: 3, margin: "0 auto 16px",
                }} />
                {/* Screen content */}
                <div style={{ minHeight: 180 }}>
                  {s.preview}
                </div>
              </div>
              {/* Caption */}
              <div style={{ textAlign: "center", maxWidth: 200 }}>
                <div style={{ fontSize: 14, fontWeight: 700, color: "#f0f0f0", marginBottom: 6 }}>{s.title}</div>
                <div style={{ fontSize: 12, color: "rgba(240,240,240,0.5)", lineHeight: 1.5 }}>{s.desc}</div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
