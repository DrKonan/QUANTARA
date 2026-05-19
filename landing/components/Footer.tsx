"use client";

export default function Footer() {
  const year = new Date().getFullYear();

  return (
    <footer style={{ borderTop: "1px solid rgba(255,255,255,0.06)", padding: "64px 24px 40px" }}>
      {/* CTA Banner */}
      <div style={{
        maxWidth: 800, margin: "0 auto 64px",
        background: "linear-gradient(135deg, rgba(212,175,55,0.1), rgba(212,175,55,0.04))",
        border: "1px solid rgba(212,175,55,0.2)",
        borderRadius: 24, padding: "48px 40px",
        textAlign: "center",
      }}>
        <h2 style={{ fontSize: "clamp(1.5rem, 3.5vw, 2.2rem)", fontWeight: 800, marginBottom: 16, letterSpacing: "-0.5px" }}>
          Prêt à parier <span className="text-gold-gradient">plus intelligemment</span> ?
        </h2>
        <p style={{ color: "rgba(240,240,240,0.55)", fontSize: 15, marginBottom: 32, maxWidth: 420, margin: "0 auto 32px" }}>
          Rejoins des milliers de parieurs qui font confiance à l&apos;IA Nakora chaque jour.
        </p>
        <div style={{ display: "flex", gap: 16, justifyContent: "center", flexWrap: "wrap" }}>
          <a href="https://play.google.com/store/apps/details?id=app.nakora.nakora" target="_blank" rel="noopener" className="btn-primary">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
              <path d="M3.18 23.76c.35.19.75.24 1.14.14l11.08-11.08L12 9.49 3.18 23.76zM20.6 10.28l-2.45-1.41-3.41 3.42 3.41 3.41 2.47-1.42a1.95 1.95 0 0 0 0-3.99zM1.7.61A1.9 1.9 0 0 0 1 2.14v19.72c0 .62.27 1.17.7 1.53L12 13.16 1.7.61zM4.32.1l11.08 6.41L12 9.82 4.32.1z"/>
            </svg>
            Google Play
          </a>
          <a href="https://apps.apple.com" target="_blank" rel="noopener" className="btn-secondary">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
              <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
            </svg>
            App Store
          </a>
        </div>
      </div>

      {/* Footer grid */}
      <div style={{ maxWidth: 1200, margin: "0 auto" }}>
        <div style={{
          display: "grid",
          gridTemplateColumns: "2fr 1fr 1fr 1fr",
          gap: 40,
          marginBottom: 48,
        }}>
          {/* Brand */}
          <div>
            <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 16 }}>
              <div style={{
                width: 32, height: 32, borderRadius: 9,
                background: "linear-gradient(135deg, #D4AF37, #B8960C)",
                display: "flex", alignItems: "center", justifyContent: "center",
                fontSize: 16, fontWeight: 900, color: "#080810",
              }}>N</div>
              <span style={{ fontSize: 18, fontWeight: 800, color: "#f0f0f0" }}>
                nakora<span style={{ color: "#D4AF37" }}>.</span>
              </span>
            </div>
            <p style={{ fontSize: 13, color: "rgba(240,240,240,0.45)", lineHeight: 1.7, maxWidth: 260 }}>
              Pronostics sportifs (football, basket, hockey) alimentés par l&apos;IA. Précis, transparents, indépendants.
            </p>
          </div>

          {/* Produit */}
          <div>
            <div style={{ fontSize: 12, fontWeight: 700, color: "rgba(240,240,240,0.5)", textTransform: "uppercase", letterSpacing: "0.5px", marginBottom: 16 }}>Produit</div>
            {["Fonctionnalités", "Tarifs", "FAQ", "Télécharger"].map(l => (
              <a key={l} href="#" style={{ display: "block", fontSize: 14, color: "rgba(240,240,240,0.55)", textDecoration: "none", marginBottom: 10 }}
              onMouseEnter={e => (e.currentTarget.style.color = "#D4AF37")}
              onMouseLeave={e => (e.currentTarget.style.color = "rgba(240,240,240,0.55)")}
              >{l}</a>
            ))}
          </div>

          {/* Légal */}
          <div>
            <div style={{ fontSize: 12, fontWeight: 700, color: "rgba(240,240,240,0.5)", textTransform: "uppercase", letterSpacing: "0.5px", marginBottom: 16 }}>Légal</div>
            {[
              { label: "Politique de confidentialité", href: "/nakora/privacy" },
              { label: "Conditions d'utilisation", href: "/nakora/terms" },
              { label: "Supprimer mon compte", href: "/nakora/delete-account" },
            ].map(l => (
              <a key={l.label} href={l.href} style={{ display: "block", fontSize: 14, color: "rgba(240,240,240,0.55)", textDecoration: "none", marginBottom: 10 }}
              onMouseEnter={e => (e.currentTarget.style.color = "#D4AF37")}
              onMouseLeave={e => (e.currentTarget.style.color = "rgba(240,240,240,0.55)")}
              >{l.label}</a>
            ))}
          </div>

          {/* Contact */}
          <div>
            <div style={{ fontSize: 12, fontWeight: 700, color: "rgba(240,240,240,0.5)", textTransform: "uppercase", letterSpacing: "0.5px", marginBottom: 16 }}>Contact</div>
            <a href="mailto:support@nakora.app" style={{ display: "block", fontSize: 14, color: "rgba(240,240,240,0.55)", textDecoration: "none", marginBottom: 10 }}
            onMouseEnter={e => (e.currentTarget.style.color = "#D4AF37")}
            onMouseLeave={e => (e.currentTarget.style.color = "rgba(240,240,240,0.55)")}
            >support@nakora.app</a>
            <a href="https://twitter.com" target="_blank" rel="noopener" style={{ display: "inline-flex", alignItems: "center", gap: 6, fontSize: 14, color: "rgba(240,240,240,0.55)", textDecoration: "none" }}
            onMouseEnter={e => (e.currentTarget.style.color = "#D4AF37")}
            onMouseLeave={e => (e.currentTarget.style.color = "rgba(240,240,240,0.55)")}
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-4.714-6.231-5.401 6.231H2.747l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/></svg>
              Twitter / X
            </a>
          </div>
        </div>

        {/* Bottom bar */}
        <div className="divider" style={{ marginBottom: 24 }} />
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: 12 }}>
          <p style={{ fontSize: 12, color: "rgba(240,240,240,0.3)" }}>
            © {year} Nakora · DOC CODE DEV · Tous droits réservés
          </p>
          <p style={{ fontSize: 12, color: "rgba(240,240,240,0.25)" }}>
            Les paris comportent des risques. Jouez de façon responsable.
          </p>
        </div>
      </div>

      {/* Responsive fix */}
      <style>{`
        @media (max-width: 768px) {
          footer > div:last-child > div:first-child {
            grid-template-columns: 1fr 1fr !important;
          }
        }
        @media (max-width: 480px) {
          footer > div:last-child > div:first-child {
            grid-template-columns: 1fr !important;
          }
        }
      `}</style>
    </footer>
  );
}
