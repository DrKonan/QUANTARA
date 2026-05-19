"use client";
import { useState } from "react";

const items = [
  {
    q: "Comment Nakora génère-t-il ses pronostics ?",
    a: "Notre algorithme d'IA analyse des dizaines de variables pour chaque match : ELO des équipes, forme des 6 derniers matchs, confrontations directes, statistiques défensives et offensives, conditions d'arbitrage, etc. Les probabilités calculées sont ensuite transformées en pronostics avec confiance et cote recommandée.",
  },
  {
    q: "Quelle est la différence entre le Combo Sûr et le Combo Audacieux ?",
    a: "Le Combo Sûr contient 3 sélections à très haute confiance (≥78%), sur des matchs sélectionnés en priorité. Le Combo Audacieux contient 5 sélections sur des matchs entièrement différents — ce qui signifie qu'un résultat défavorable n'impacte qu'un seul des deux combos.",
  },
  {
    q: "Les pronostics sont-ils garantis gagnants ?",
    a: "Non, aucun pronostic sportif ne peut être garanti. Ce que garantit Nakora, c'est une analyse rigoureuse et un win rate transparent. Notre algorithme vise à maximiser tes chances sur le long terme, pas à promettre des gains instantanés.",
  },
  {
    q: "Puis-je utiliser Nakora si je suis débutant dans les paris ?",
    a: "Absolument. L'interface est pensée pour être accessible à tous. Les explications sont claires, et le plan FREE te permet de te familiariser sans dépenser un centime. Notre conseil : commence par observer les résultats sur 2-3 semaines avant de miser.",
  },
  {
    q: "Comment fonctionne le paiement ?",
    a: "Les abonnements sont gérés via PayDunya (FCFA, EUR, USD). Aucun engagement : tu peux annuler à tout moment depuis les paramètres de l'application. Le renouvellement est automatique chaque mois.",
  },
  {
    q: "Quels sports et ligues Nakora couvre-t-il ?",
    a: "Nakora couvre 3 sports : le football (Champions League, Europa League, Premier League, La Liga, Ligue 1, Serie A, Bundesliga, et ligues africaines), le basketball (NBA, Euroleague, Pro A) et le hockey sur glace (NHL, KHL). La couverture s'élargit régulièrement.",
  },
  {
    q: "Nakora est-il disponible sur iOS et Android ?",
    a: "Oui, Nakora est disponible sur Google Play et l'App Store. Une version web de l'application est également en cours de développement pour accéder à tes pronostics directement depuis un navigateur.",
  },
];

export default function FAQ() {
  const [open, setOpen] = useState<number | null>(null);

  return (
    <section id="faq" style={{ padding: "96px 24px" }}>
      <div style={{ maxWidth: 760, margin: "0 auto" }}>
        {/* Header */}
        <div style={{ textAlign: "center", marginBottom: 56 }}>
          <div style={{
            display: "inline-block",
            background: "rgba(212,175,55,0.1)", border: "1px solid rgba(212,175,55,0.2)",
            borderRadius: 999, padding: "5px 16px", marginBottom: 20,
          }}>
            <span style={{ fontSize: 12, color: "#D4AF37", fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.5px" }}>FAQ</span>
          </div>
          <h2 style={{ fontSize: "clamp(1.75rem, 4vw, 2.75rem)", fontWeight: 800, letterSpacing: "-0.5px", marginBottom: 16 }}>
            Questions fréquentes
          </h2>
          <p style={{ color: "rgba(240,240,240,0.5)", fontSize: 15 }}>
            Une question ? Consulte notre FAQ ou écris-nous à <a href="mailto:support@nakora.app" style={{ color: "#D4AF37", textDecoration: "none" }}>support@nakora.app</a>
          </p>
        </div>

        {/* Items */}
        <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
          {items.map((item, i) => (
            <div key={i} className="glass" style={{
              overflow: "hidden",
              transition: "border-color 0.2s",
              borderColor: open === i ? "rgba(212,175,55,0.25)" : "rgba(255,255,255,0.08)",
            }}>
              <button
                onClick={() => setOpen(open === i ? null : i)}
                style={{
                  width: "100%", textAlign: "left",
                  background: "none", border: "none", cursor: "pointer",
                  padding: "20px 24px",
                  display: "flex", justifyContent: "space-between", alignItems: "center", gap: 16,
                }}
              >
                <span style={{ fontSize: 15, fontWeight: 600, color: "#f0f0f0", lineHeight: 1.4 }}>{item.q}</span>
                <span style={{
                  color: "#D4AF37", fontSize: 20, flexShrink: 0,
                  transform: open === i ? "rotate(45deg)" : "rotate(0)",
                  transition: "transform 0.2s",
                  lineHeight: 1,
                }}>+</span>
              </button>

              {open === i && (
                <div style={{ padding: "0 24px 20px" }}>
                  <div className="divider" style={{ marginBottom: 16 }} />
                  <p style={{ fontSize: 14, color: "rgba(240,240,240,0.6)", lineHeight: 1.8 }}>{item.a}</p>
                </div>
              )}
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
