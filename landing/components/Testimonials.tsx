const testimonials = [
  {
    name: "Kouassi A.",
    location: "Abidjan, CI",
    seed: "KouassiAbidjan",
    color: "#D4AF37",
    stars: 5,
    text: "Depuis que j'utilise Nakora, mon taux de réussite a vraiment augmenté. Le combo sûr m'a permis de gagner 3 semaines de suite. L'IA analyse mieux que moi.",
  },
  {
    name: "Mamadou D.",
    location: "Dakar, SN",
    seed: "MamadouDakar",
    color: "#22c55e",
    stars: 5,
    text: "L'appli est très intuitive. Je reçois mes pronos le matin et je mise tranquillement. Le suivi live est un énorme plus, tu sais en temps réel si ton combo tient.",
  },
  {
    name: "Ibrahima S.",
    location: "Paris, FR",
    seed: "IbrahimaParis",
    color: "#818cf8",
    stars: 5,
    text: "J'ai essayé plusieurs apps de pronostics. Nakora est la seule qui publie son vrai win rate sans l'embellir. Cette transparence m'a convaincu de passer VIP.",
  },
  {
    name: "Christophe M.",
    location: "Lyon, FR",
    seed: "ChristopheLyon",
    color: "#f59e0b",
    stars: 4,
    text: "Le combo audacieux est risqué mais quand ça passe, c'est énorme. J'ai eu ×8.4 ce mois-ci. L'indépendance entre safe et bold est une bonne idée stratégique.",
  },
  {
    name: "Fatou B.",
    location: "Bamako, ML",
    seed: "FatouBamako",
    color: "#ec4899",
    stars: 5,
    text: "Très bonne application. Je ne connaissais pas grand chose au foot mais les explications sont claires. J'ai commencé en FREE et je suis passée PRO après 2 semaines.",
  },
  {
    name: "Oumar T.",
    location: "Lomé, TG",
    seed: "OumarLome",
    color: "#06b6d4",
    stars: 5,
    text: "Support réactif, interface propre, pronostics fiables. Nakora fait exactement ce qu'il promet. Je recommande à tous ceux qui veulent être sérieux dans leurs mises.",
  },
];

function Stars({ count }: { count: number }) {
  return (
    <div style={{ display: "flex", gap: 3 }}>
      {Array.from({ length: 5 }).map((_, i) => (
        <span key={i} style={{ fontSize: 13, color: i < count ? "#D4AF37" : "rgba(212,175,55,0.2)" }}>★</span>
      ))}
    </div>
  );
}

export default function Testimonials() {
  return (
    <section style={{ padding: "96px 24px", position: "relative", overflow: "hidden" }}>
      {/* Soft bg */}
      <div style={{
        position: "absolute", inset: 0,
        background: "linear-gradient(180deg, transparent, rgba(34,197,94,0.03), transparent)",
        pointerEvents: "none",
      }} />

      <div style={{ maxWidth: 1200, margin: "0 auto", position: "relative" }}>
        {/* Header */}
        <div style={{ textAlign: "center", marginBottom: 64 }}>
          <div style={{
            display: "inline-block",
            background: "rgba(34,197,94,0.1)", border: "1px solid rgba(34,197,94,0.2)",
            borderRadius: 999, padding: "5px 16px", marginBottom: 20,
          }}>
            <span style={{ fontSize: 12, color: "#22c55e", fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.5px" }}>Témoignages</span>
          </div>
          <h2 style={{ fontSize: "clamp(1.75rem, 4vw, 2.75rem)", fontWeight: 800, letterSpacing: "-0.5px", marginBottom: 16 }}>
            Ils font confiance à
            <br />
            <span className="text-gold-gradient">Nakora chaque jour</span>
          </h2>
        </div>

        {/* Grid */}
        <div style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(300px, 1fr))",
          gap: 20,
        }}>
          {testimonials.map((t) => (
            <div key={t.name} className="glass" style={{ padding: "28px 24px" }}>
              {/* Stars */}
              <Stars count={t.stars} />

              {/* Text */}
              <p style={{
                fontSize: 14, color: "rgba(240,240,240,0.75)",
                lineHeight: 1.7, margin: "16px 0 20px",
                fontStyle: "italic",
              }}>
                &ldquo;{t.text}&rdquo;
              </p>

              {/* Author */}
              <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
                <div style={{
                  width: 44, height: 44, borderRadius: "50%",
                  border: `2px solid ${t.color}44`,
                  overflow: "hidden", flexShrink: 0,
                  background: `${t.color}11`,
                }}>
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={`https://api.dicebear.com/9.x/lorelei/svg?seed=${t.seed}&backgroundColor=transparent`}
                    alt={t.name}
                    width={44}
                    height={44}
                    style={{ width: "100%", height: "100%", objectFit: "cover" }}
                  />
                </div>
                <div>
                  <div style={{ fontSize: 13, fontWeight: 700, color: "#f0f0f0" }}>{t.name}</div>
                  <div style={{ fontSize: 11, color: "rgba(240,240,240,0.4)" }}>{t.location}</div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
