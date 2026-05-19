export default function Hero() {
  const floatingIcons: { icon: string; top: string; left?: string; right?: string; delay: string; size: number }[] = [
    { icon: "⚽", top: "18%", left: "8%", delay: "0s", size: 32 },
    { icon: "🏀", top: "28%", right: "7%", delay: "0.6s", size: 28 },
    { icon: "🏒", top: "65%", left: "5%", delay: "1.2s", size: 26 },
    { icon: "📊", top: "70%", right: "9%", delay: "0.3s", size: 24 },
    { icon: "🎯", top: "40%", left: "3%", delay: "0.9s", size: 22 },
    { icon: "🏆", top: "50%", right: "4%", delay: "1.5s", size: 28 },
  ];

  return (
    <section style={{
      minHeight: "100vh",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      position: "relative",
      overflow: "hidden",
      paddingTop: 68,
    }}>
      {/* Floating sport icons */}
      {floatingIcons.map((ic, i) => (
        <div key={i} style={{
          position: "absolute",
          top: ic.top,
          left: "left" in ic ? ic.left : undefined,
          right: "right" in ic ? ic.right : undefined,
          fontSize: ic.size,
          opacity: 0.18,
          animation: `float ${2.5 + i * 0.4}s ease-in-out infinite`,
          animationDelay: ic.delay,
          pointerEvents: "none",
          filter: "blur(0.5px)",
        }}>
          {ic.icon}
        </div>
      ))}
      {/* Background radial glow */}
      <div style={{
        position: "absolute", top: "20%", left: "50%", transform: "translateX(-50%)",
        width: 600, height: 600,
        background: "radial-gradient(circle, rgba(212,175,55,0.12) 0%, transparent 70%)",
        pointerEvents: "none",
      }} />
      <div style={{
        position: "absolute", bottom: "10%", right: "5%",
        width: 300, height: 300,
        background: "radial-gradient(circle, rgba(34,197,94,0.07) 0%, transparent 70%)",
        pointerEvents: "none",
      }} />

      {/* Grid pattern */}
      <div style={{
        position: "absolute", inset: 0, opacity: 0.03,
        backgroundImage: "linear-gradient(rgba(255,255,255,0.5) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.5) 1px, transparent 1px)",
        backgroundSize: "60px 60px",
        pointerEvents: "none",
      }} />

      <div style={{ maxWidth: 900, margin: "0 auto", padding: "0 24px", textAlign: "center", position: "relative" }}>
        {/* Badge */}
        <div className="animate-fade-up" style={{
          display: "inline-flex", alignItems: "center", gap: 8,
          background: "rgba(212,175,55,0.1)", border: "1px solid rgba(212,175,55,0.25)",
          borderRadius: 999, padding: "6px 16px", marginBottom: 32,
        }}>
          <span style={{ fontSize: 12, color: "#D4AF37", fontWeight: 600, letterSpacing: "0.5px", textTransform: "uppercase" }}>
            ⚽ Alimenté par l&apos;intelligence artificielle
          </span>
        </div>

        {/* Headline */}
        <h1 className="animate-fade-up delay-100" style={{
          fontSize: "clamp(2.5rem, 7vw, 5rem)",
          fontWeight: 900,
          lineHeight: 1.1,
          letterSpacing: "-1.5px",
          marginBottom: 24,
          color: "#f0f0f0",
        }}>
          Parie plus intelligemment.
          <br />
          <span className="text-shimmer">Gagne plus souvent.</span>
        </h1>

        {/* Subheadline */}
        <p className="animate-fade-up delay-200" style={{
          fontSize: "clamp(1rem, 2.5vw, 1.2rem)",
          color: "rgba(240,240,240,0.6)",
          lineHeight: 1.7,
          maxWidth: 600,
          margin: "0 auto 40px",
        }}>
          Nakora analyse des milliers de statistiques pour te fournir les pronostics les plus fiables.
          Combos automatiques, suivi en direct, précision transparente.
        </p>

        {/* CTAs */}
        <div className="animate-fade-up delay-300" style={{ display: "flex", gap: 16, justifyContent: "center", flexWrap: "wrap", marginBottom: 56 }}>
          <a href="https://play.google.com/store/apps/details?id=app.nakora.nakora" target="_blank" rel="noopener" className="btn-primary" style={{ fontSize: 15 }}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
              <path d="M3.18 23.76c.35.19.75.24 1.14.14l11.08-11.08L12 9.49 3.18 23.76zM20.6 10.28l-2.45-1.41-3.41 3.42 3.41 3.41 2.47-1.42a1.95 1.95 0 0 0 0-3.99zM1.7.61A1.9 1.9 0 0 0 1 2.14v19.72c0 .62.27 1.17.7 1.53L12 13.16 1.7.61zM4.32.1l11.08 6.41L12 9.82 4.32.1z"/>
            </svg>
            Google Play
          </a>
          <a href="https://apps.apple.com" target="_blank" rel="noopener" className="btn-secondary" style={{ fontSize: 15 }}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
              <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
            </svg>
            App Store
          </a>
        </div>

        {/* Stats bar */}
        <div className="animate-fade-up delay-400" style={{
          display: "flex",
          justifyContent: "center",
          alignItems: "center",
          gap: 40,
          flexWrap: "wrap",
        }}>
          {/* Avatar stack */}
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <div style={{ display: "flex" }}>
              {["Kouassi", "Mamadou", "Fatou", "Ibrahima"].map((seed, i) => (
                <div key={seed} style={{
                  width: 32, height: 32, borderRadius: "50%",
                  border: "2px solid rgba(8,8,16,0.9)",
                  overflow: "hidden",
                  marginLeft: i === 0 ? 0 : -10,
                  background: "rgba(212,175,55,0.15)",
                }}>
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={`https://api.dicebear.com/9.x/lorelei/svg?seed=${seed}&backgroundColor=transparent`}
                    alt=""
                    width={32}
                    height={32}
                    style={{ width: "100%", height: "100%" }}
                  />
                </div>
              ))}
            </div>
            <div style={{ textAlign: "left" }}>
              <div style={{ fontSize: "1rem", fontWeight: 800, color: "#D4AF37" }}>5k+</div>
              <div style={{ fontSize: 11, color: "rgba(240,240,240,0.5)", textTransform: "uppercase", letterSpacing: "0.5px" }}>Utilisateurs actifs</div>
            </div>
          </div>

          {[
            { value: "85%", label: "Taux de réussite" },
            { value: "3", label: "Sports couverts" },
          ].map((s) => (
            <div key={s.label} style={{ textAlign: "center" }}>
              <div style={{ fontSize: "1.75rem", fontWeight: 800, color: "#D4AF37" }}>{s.value}</div>
              <div style={{ fontSize: 12, color: "rgba(240,240,240,0.5)", textTransform: "uppercase", letterSpacing: "0.5px", marginTop: 4 }}>{s.label}</div>
            </div>
          ))}
        </div>

        {/* Scroll indicator */}
        <div style={{ marginTop: 64, display: "flex", justifyContent: "center" }}>
          <div style={{
            width: 28, height: 44,
            border: "2px solid rgba(255,255,255,0.15)",
            borderRadius: 14,
            display: "flex", justifyContent: "center", paddingTop: 6,
          }}>
            <div style={{
              width: 4, height: 8,
              background: "#D4AF37",
              borderRadius: 2,
              animation: "float 1.5s ease-in-out infinite",
            }} />
          </div>
        </div>
      </div>
    </section>
  );
}
