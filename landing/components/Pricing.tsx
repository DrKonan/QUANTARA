const plans = [
  {
    name: "FREE",
    price: "Gratuit",
    priceRaw: null,
    period: "",
    desc: "Pour découvrir Nakora sans risque",
    accent: "rgba(255,255,255,0.6)",
    accentBg: "rgba(255,255,255,0.04)",
    popular: false,
    features: [
      { text: "3 pronostics par jour", ok: true },
      { text: "Statistiques publiques", ok: true },
      { text: "Suivi des matchs en direct", ok: true },
      { text: "Combos automatiques", ok: false },
      { text: "Tous les pronostics", ok: false },
      { text: "Alertes personnalisées", ok: false },
    ],
    cta: "Commencer gratuitement",
    ctaStyle: "secondary",
  },
  {
    name: "STARTER",
    price: "1 000",
    priceRaw: "FCFA",
    period: "/ mois",
    desc: "Pour commencer à parier avec l'IA",
    accent: "#22c55e",
    accentBg: "rgba(34,197,94,0.05)",
    popular: false,
    features: [
      { text: "Tous les pronostics illimités", ok: true },
      { text: "Suivi live complet", ok: true },
      { text: "Alertes résultats push", ok: true },
      { text: "Historique et statistiques", ok: true },
      { text: "Combo Sûr quotidien", ok: false },
      { text: "Combo Audacieux (VIP uniquement)", ok: false },
    ],
    cta: "Choisir STARTER",
    ctaStyle: "secondary",
  },
  {
    name: "PRO",
    price: "2 000",
    priceRaw: "FCFA",
    period: "/ mois",
    desc: "Pour les parieurs sérieux",
    accent: "#D4AF37",
    accentBg: "rgba(212,175,55,0.08)",
    popular: true,
    features: [
      { text: "Tous les pronostics illimités", ok: true },
      { text: "Combo Sûr quotidien (3 sélections)", ok: true },
      { text: "Suivi live complet", ok: true },
      { text: "Alertes résultats push", ok: true },
      { text: "Historique et statistiques avancées", ok: true },
      { text: "Combo Audacieux (VIP uniquement)", ok: false },
    ],
    cta: "Choisir PRO",
    ctaStyle: "primary",
  },
  {
    name: "VIP",
    price: "4 000",
    priceRaw: "FCFA",
    period: "/ mois",
    desc: "L'expérience Nakora complète",
    accent: "#f59e0b",
    accentBg: "rgba(245,158,11,0.06)",
    popular: false,
    features: [
      { text: "Tout ce qu'offre PRO", ok: true },
      { text: "Combo Audacieux (5 sélections, ×8-15)", ok: true },
      { text: "Accès prioritaire aux nouvelles fonctions", ok: true },
      { text: "Support dédié", ok: true },
      { text: "Analyses approfondies par match", ok: true },
      { text: "Badge VIP dans l'app", ok: true },
    ],
    cta: "Devenir VIP",
    ctaStyle: "secondary",
  },
];

export default function Pricing() {
  return (
    <section id="pricing" style={{ padding: "96px 24px", position: "relative" }}>
      {/* Background glow */}
      <div style={{
        position: "absolute", top: "30%", left: "50%", transform: "translateX(-50%)",
        width: 500, height: 300,
        background: "radial-gradient(ellipse, rgba(212,175,55,0.06) 0%, transparent 70%)",
        pointerEvents: "none",
      }} />

      <div style={{ maxWidth: 1100, margin: "0 auto", position: "relative" }}>
        {/* Header */}
        <div style={{ textAlign: "center", marginBottom: 64 }}>
          <div style={{
            display: "inline-block",
            background: "rgba(212,175,55,0.1)", border: "1px solid rgba(212,175,55,0.2)",
            borderRadius: 999, padding: "5px 16px", marginBottom: 20,
          }}>
            <span style={{ fontSize: 12, color: "#D4AF37", fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.5px" }}>Tarifs</span>
          </div>
          <h2 style={{ fontSize: "clamp(1.75rem, 4vw, 2.75rem)", fontWeight: 800, letterSpacing: "-0.5px", marginBottom: 16 }}>
            Un plan pour chaque
            <br />
            <span className="text-gold-gradient">niveau d&apos;ambition</span>
          </h2>
          <p style={{ color: "rgba(240,240,240,0.55)", fontSize: 16, maxWidth: 460, margin: "0 auto" }}>
            Sans engagement. Annulable à tout moment depuis l&apos;application.
          </p>
        </div>

        {/* Plans */}
        <div style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))",
          gap: 24,
          alignItems: "start",
        }}>
          {plans.map((p) => (
            <div key={p.name} style={{
              background: p.accentBg,
              border: `1px solid ${p.accent}${p.popular ? "40" : "18"}`,
              borderRadius: 20,
              padding: "32px 28px",
              position: "relative",
              transform: p.popular ? "scale(1.03)" : "scale(1)",
              boxShadow: p.popular ? `0 0 40px ${p.accent}18` : "none",
            }}>
              {/* Popular badge */}
              {p.popular && (
                <div style={{
                  position: "absolute", top: -14, left: "50%", transform: "translateX(-50%)",
                  background: "linear-gradient(135deg, #D4AF37, #B8960C)",
                  color: "#080810", fontWeight: 700, fontSize: 11,
                  padding: "4px 14px", borderRadius: 999,
                  letterSpacing: "0.5px", textTransform: "uppercase",
                  whiteSpace: "nowrap",
                }}>⭐ Plus populaire</div>
              )}

              {/* Plan name */}
              <div style={{ marginBottom: 20 }}>
                <div style={{ fontSize: 12, fontWeight: 700, color: p.accent, letterSpacing: "1px", textTransform: "uppercase", marginBottom: 8 }}>{p.name}</div>
                <div style={{ display: "flex", alignItems: "baseline", gap: 4, marginBottom: 8 }}>
                  <span style={{ fontSize: "2.4rem", fontWeight: 900, color: "#f0f0f0" }}>
                    {p.price}
                  </span>
                  {p.priceRaw && <span style={{ fontSize: 13, color: "rgba(240,240,240,0.5)", fontWeight: 600 }}>{p.priceRaw}</span>}
                  {p.period && <span style={{ fontSize: 14, color: "rgba(240,240,240,0.4)" }}>{p.period}</span>}
                </div>
                <p style={{ fontSize: 13, color: "rgba(240,240,240,0.5)" }}>{p.desc}</p>
              </div>

              {/* Divider */}
              <div className="divider" style={{ marginBottom: 24 }} />

              {/* Features */}
              <ul style={{ listStyle: "none", display: "flex", flexDirection: "column", gap: 12, marginBottom: 28 }}>
                {p.features.map(f => (
                  <li key={f.text} style={{ display: "flex", gap: 10, alignItems: "flex-start" }}>
                    <span style={{ fontSize: 14, color: f.ok ? "#22c55e" : "rgba(240,240,240,0.2)", flexShrink: 0, marginTop: 1 }}>
                      {f.ok ? "✓" : "✕"}
                    </span>
                    <span style={{ fontSize: 13, color: f.ok ? "rgba(240,240,240,0.8)" : "rgba(240,240,240,0.3)", lineHeight: 1.5 }}>{f.text}</span>
                  </li>
                ))}
              </ul>

              {/* CTA */}
              {p.ctaStyle === "primary"
                ? <a href="#" className="btn-primary" style={{ width: "100%", justifyContent: "center", fontSize: 14 }}>{p.cta}</a>
                : <a href="#" className="btn-secondary" style={{ width: "100%", justifyContent: "center", fontSize: 14 }}>{p.cta}</a>
              }
            </div>
          ))}
        </div>

        {/* Note */}
        <p style={{ textAlign: "center", marginTop: 32, fontSize: 13, color: "rgba(240,240,240,0.35)" }}>
          Paiement sécurisé via PayDunya · Mobile Money (Wave, Orange Money, MTN…)
        </p>
      </div>
    </section>
  );
}
