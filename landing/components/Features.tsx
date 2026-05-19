"use client";

const features = [
  {
    icon: "🤖",
    title: "Pronostics par IA",
    desc: "Notre algorithme analyse l'ELO des équipes, les statistiques historiques, la forme récente et les confrontations directes pour calculer les probabilités les plus précises.",
    accent: "#D4AF37",
  },
  {
    icon: "🛡️",
    title: "Combo Sûr",
    desc: "2 à 3 sélections à haute confiance (≥78%) choisies automatiquement. Indépendantes du Combo Audacieux — si un match perd, l'autre combo reste intact.",
    accent: "#22c55e",
  },
  {
    icon: "🔥",
    title: "Combo Audacieux",
    desc: "5 sélections avec un potentiel de gain multiplié, sur des matchs différents du Combo Sûr. Réservé aux abonnés VIP pour maximiser les profits.",
    accent: "#f59e0b",
  },
  {
    icon: "📡",
    title: "Suivi en direct",
    desc: "Tes pronostics se mettent à jour en temps réel pendant les matchs. Scores, statuts, résultats — tout est synchronisé automatiquement toutes les 5 minutes.",
    accent: "#818cf8",
  },
  {
    icon: "📊",
    title: "Précision transparente",
    desc: "Aucun chiffre inventé. Nakora publie son taux de réussite réel, calculé sur l'ensemble des pronostics émis. Tu sais exactement ce que tu achètes.",
    accent: "#06b6d4",
  },
  {
    icon: "🌍",
    title: "Football, Basket & Hockey",
    desc: "Nakora couvre 3 sports : football (Champions League, Premier League, Ligue 1...), basketball (NBA, Euroleague) et hockey sur glace (NHL, KHL). Les meilleures ligues chaque jour.",
    accent: "#ec4899",
  },
];

export default function Features() {
  return (
    <section id="features" style={{ padding: "96px 24px", maxWidth: 1200, margin: "0 auto" }}>
      {/* Header */}
      <div style={{ textAlign: "center", marginBottom: 64 }}>
        <div style={{
          display: "inline-block",
          background: "rgba(212,175,55,0.1)", border: "1px solid rgba(212,175,55,0.2)",
          borderRadius: 999, padding: "5px 16px", marginBottom: 20,
        }}>
          <span style={{ fontSize: 12, color: "#D4AF37", fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.5px" }}>Fonctionnalités</span>
        </div>
        <h2 style={{ fontSize: "clamp(1.75rem, 4vw, 2.75rem)", fontWeight: 800, letterSpacing: "-0.5px", marginBottom: 16 }}>
          Tout ce dont tu as besoin
          <br />
          <span className="text-gold-gradient">pour parier mieux</span>
        </h2>
        <p style={{ color: "rgba(240,240,240,0.55)", fontSize: 16, maxWidth: 520, margin: "0 auto" }}>
          Une plateforme complète conçue pour transformer des données en décisions gagnantes.
        </p>
      </div>

      {/* Grid */}
      <div style={{
        display: "grid",
        gridTemplateColumns: "repeat(auto-fit, minmax(300px, 1fr))",
        gap: 24,
      }}>
        {features.map((f) => (
          <div key={f.title} className="glass" style={{
            padding: "32px 28px",
            transition: "transform 0.2s, border-color 0.2s",
            cursor: "default",
          }}
          onMouseEnter={e => {
            (e.currentTarget as HTMLElement).style.transform = "translateY(-4px)";
            (e.currentTarget as HTMLElement).style.borderColor = `${f.accent}40`;
          }}
          onMouseLeave={e => {
            (e.currentTarget as HTMLElement).style.transform = "translateY(0)";
            (e.currentTarget as HTMLElement).style.borderColor = "rgba(255,255,255,0.08)";
          }}
          >
            {/* Icon */}
            <div style={{
              width: 52, height: 52, borderRadius: 14,
              background: `${f.accent}18`,
              border: `1px solid ${f.accent}30`,
              display: "flex", alignItems: "center", justifyContent: "center",
              fontSize: 24, marginBottom: 20,
            }}>{f.icon}</div>

            <h3 style={{ fontSize: 18, fontWeight: 700, marginBottom: 12, color: "#f0f0f0" }}>{f.title}</h3>
            <p style={{ fontSize: 14, color: "rgba(240,240,240,0.55)", lineHeight: 1.7 }}>{f.desc}</p>
          </div>
        ))}
      </div>
    </section>
  );
}
