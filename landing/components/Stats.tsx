const stats = [
  { value: "85%", label: "Précision globale", color: "#D4AF37", bar: 85 },
  { value: "89%", label: "Combos Sûrs gagnés", color: "#22c55e", bar: 89 },
  { value: "3", label: "Sports couverts", color: "#818cf8", bar: 100 },
  { value: "200+", label: "Pronos par semaine", color: "#f59e0b", bar: 60 },
];

export default function Stats() {
  return (
    <section style={{ padding: "0 24px 96px", maxWidth: 1200, margin: "0 auto" }}>
      <div style={{
        display: "grid",
        gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))",
        gap: 20,
      }}>
        {stats.map((s) => (
          <div key={s.label} className="glass" style={{ padding: "28px 24px" }}>
            <div style={{ fontSize: "2rem", fontWeight: 800, color: s.color, marginBottom: 4 }}>{s.value}</div>
            <div style={{ fontSize: 13, color: "rgba(240,240,240,0.55)", marginBottom: 16 }}>{s.label}</div>
            <div style={{ height: 4, background: "rgba(255,255,255,0.07)", borderRadius: 2, overflow: "hidden" }}>
              <div style={{
                height: "100%",
                width: `${s.bar}%`,
                background: `linear-gradient(90deg, ${s.color}88, ${s.color})`,
                borderRadius: 2,
                animation: "bar-grow 1.2s ease both",
              }} />
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}
