import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Nakora - Pronostics Sportifs par IA",
  description: "Pronostics football, basket et hockey par IA. 85% de reussite. Combos automatiques, suivi en direct.",
  icons: {
    icon: "/logo.png",
    apple: "/logo.png",
  },
  openGraph: {
    title: "Nakora - Pronostics Sportifs par IA",
    description: "Pronostics football, basket et hockey par IA. 85% de reussite.",
    type: "website",
    images: [{ url: "/logo.png" }],
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="fr">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&display=swap" rel="stylesheet" />
      </head>
      <body>{children}</body>
    </html>
  );
}