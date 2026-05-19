"use client";
import { useState, useEffect } from "react";

export default function Navbar() {
  const [scrolled, setScrolled] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    const handler = () => setScrolled(window.scrollY > 40);
    window.addEventListener("scroll", handler);
    return () => window.removeEventListener("scroll", handler);
  }, []);

  const links = [
    { label: "Fonctionnalités", href: "#features" },
    { label: "Tarifs", href: "#pricing" },
    { label: "FAQ", href: "#faq" },
  ];

  return (
    <nav style={{
      position: "fixed", top: 0, left: 0, right: 0, zIndex: 100,
      transition: "all 0.3s",
      background: scrolled ? "rgba(8,8,16,0.92)" : "transparent",
      backdropFilter: scrolled ? "blur(16px)" : "none",
      borderBottom: scrolled ? "1px solid rgba(255,255,255,0.06)" : "none",
    }}>
      <div style={{ maxWidth: 1200, margin: "0 auto", padding: "0 24px", display: "flex", alignItems: "center", justifyContent: "space-between", height: 68 }}>
        {/* Logo */}
        <a href="#" style={{ display: "flex", alignItems: "center", gap: 10, textDecoration: "none" }}>
          <img
            src="/logo.png"
            alt="Nakora"
            style={{ width: 36, height: 36, borderRadius: 10, objectFit: "cover" }}
          />
          <span style={{ fontSize: 20, fontWeight: 800, color: "#f0f0f0", letterSpacing: "-0.3px" }}>
            nakora
            <span style={{ color: "#D4AF37" }}>.</span>
          </span>
        </a>

        {/* Desktop links */}
        <div style={{ display: "flex", alignItems: "center", gap: 32 }} className="hidden-mobile">
          {links.map(l => (
            <a key={l.href} href={l.href} style={{
              color: "rgba(240,240,240,0.7)", textDecoration: "none",
              fontSize: 15, fontWeight: 500, transition: "color 0.2s",
            }}
            onMouseEnter={e => (e.currentTarget.style.color = "#D4AF37")}
            onMouseLeave={e => (e.currentTarget.style.color = "rgba(240,240,240,0.7)")}
            >{l.label}</a>
          ))}
        </div>

        {/* CTA */}
        <div style={{ display: "flex", gap: 12, alignItems: "center" }}>
          <a href="#pricing" className="btn-primary" style={{ padding: "10px 20px", fontSize: 14 }}>
            Télécharger
          </a>
          {/* Burger */}
          <button
            onClick={() => setMenuOpen(!menuOpen)}
            style={{ display: "none", background: "none", border: "none", color: "#f0f0f0", cursor: "pointer", padding: 4 }}
            className="show-mobile"
            aria-label="Menu"
          >
            <svg width="22" height="22" fill="none" stroke="currentColor" strokeWidth="2">
              {menuOpen
                ? <><line x1="4" y1="4" x2="18" y2="18"/><line x1="18" y1="4" x2="4" y2="18"/></>
                : <><line x1="3" y1="6" x2="19" y2="6"/><line x1="3" y1="12" x2="19" y2="12"/><line x1="3" y1="18" x2="19" y2="18"/></>
              }
            </svg>
          </button>
        </div>
      </div>

      {/* Mobile menu */}
      {menuOpen && (
        <div style={{
          background: "rgba(8,8,16,0.98)", borderTop: "1px solid rgba(255,255,255,0.06)",
          padding: "16px 24px 24px",
        }}>
          {links.map(l => (
            <a key={l.href} href={l.href} onClick={() => setMenuOpen(false)} style={{
              display: "block", padding: "12px 0",
              color: "rgba(240,240,240,0.8)", textDecoration: "none",
              fontSize: 16, fontWeight: 500,
              borderBottom: "1px solid rgba(255,255,255,0.05)",
            }}>{l.label}</a>
          ))}
        </div>
      )}

      <style>{`
        @media (max-width: 640px) {
          .hidden-mobile { display: none !important; }
          .show-mobile { display: block !important; }
        }
      `}</style>
    </nav>
  );
}
