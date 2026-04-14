import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "Quantara — Back-office",
  description: "Dashboard administrateur Quantara",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="fr">
      <body className={`${inter.className} bg-[var(--bg-primary)] text-white min-h-screen antialiased`}>
        {children}
      </body>
    </html>
  );
}
