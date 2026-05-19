"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState, useEffect, useTransition } from "react";
import {
  LayoutDashboard,
  Users,
  TrendingUp,
  CreditCard,
  ListChecks,
  Settings,
  Menu,
  X,
  Loader2,
  Zap,
  History,
  Layers,
  LogOut,
} from "lucide-react";

const navItems = [
  { href: "/dashboard",             label: "Vue d'ensemble", icon: LayoutDashboard },
  { href: "/dashboard/predictions", label: "Pronos",         icon: ListChecks },
  { href: "/dashboard/combos",      label: "Combinés",       icon: Layers },
  { href: "/dashboard/history",     label: "Historique",     icon: History },
  { href: "/dashboard/users",       label: "Utilisateurs",   icon: Users },
  { href: "/dashboard/revenue",     label: "Revenus",        icon: CreditCard },
  { href: "/dashboard/stats",       label: "Performance",    icon: TrendingUp },
  { href: "/dashboard/config",      label: "Configuration",  icon: Settings },
];

function NavLink({
  item,
  active,
  onClick,
}: {
  item: (typeof navItems)[number];
  active: boolean;
  onClick: () => void;
}) {
  const [isPending, startTransition] = useTransition();

  return (
    <Link
      href={item.href}
      onClick={(e) => {
        if (active) { e.preventDefault(); return; }
        startTransition(() => { onClick(); });
      }}
      className={`group flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm transition-all duration-200 ${
        active
          ? "text-[#D4AF37] bg-[#D4AF37]/10 font-semibold shadow-[inset_0_0_0_1px_rgba(212,175,55,0.22)]"
          : "text-[#5E5E75] hover:text-white hover:bg-white/[0.05]"
      }`}
    >
      {isPending ? (
        <Loader2 size={17} className="animate-spin text-[#D4AF37] shrink-0" />
      ) : (
        <item.icon
          size={17}
          className={`shrink-0 transition-colors ${active ? "text-[#D4AF37]" : "group-hover:text-[#D4AF37]"}`}
        />
      )}
      <span className="truncate">{item.label}</span>
      {isPending && (
        <span className="ml-auto w-1.5 h-1.5 rounded-full bg-[#D4AF37] animate-pulse shrink-0" />
      )}
    </Link>
  );
}

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [loggingOut, setLoggingOut] = useState(false);
  const [, startSidebarTransition] = useTransition();

  useEffect(() => {
    startSidebarTransition(() => setSidebarOpen(false));
  }, [pathname]);

  const isActive = (href: string) =>
    href === "/dashboard" ? pathname === "/dashboard" : pathname.startsWith(href);

  async function handleLogout() {
    setLoggingOut(true);
    await fetch("/quantara/api/auth/logout", { method: "POST" });
    window.location.href = "/nakora/login";
  }

  return (
    <div className="flex h-screen overflow-hidden" style={{ background: "var(--bg-primary)" }}>
      {/* Overlay mobile */}
      {sidebarOpen && (
        <div
          className="fixed inset-0 bg-black/75 backdrop-blur-sm z-40 lg:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* Sidebar */}
      <aside
        className={`fixed inset-y-0 left-0 z-50 w-64 flex flex-col
          border-r border-white/[0.05]
          transform transition-transform duration-200 ease-out
          lg:sticky lg:top-0 lg:h-screen lg:translate-x-0
          ${sidebarOpen ? "translate-x-0" : "-translate-x-full"}`}
        style={{ background: "var(--bg-sidebar)" }}
      >
        {/* Gold accent stripe at top */}
        <div className="h-0.5 w-full bg-gradient-to-r from-transparent via-[#D4AF37]/60 to-transparent" />

        {/* Logo */}
        <div className="px-5 pt-5 pb-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-[#D4AF37] to-[#9A7A10] flex items-center justify-center shadow-lg shadow-[#D4AF37]/20">
              <Zap size={17} className="text-black" strokeWidth={2.5} />
            </div>
            <div>
              <h1 className="text-[15px] font-bold tracking-tight text-gold-gradient">Nakora</h1>
              <p className="text-[9px] text-[#5E5E75] font-semibold uppercase tracking-[0.15em]">Admin</p>
            </div>
          </div>
          <button
            onClick={() => setSidebarOpen(false)}
            className="lg:hidden text-[#5E5E75] hover:text-white transition-colors p-1 rounded-lg hover:bg-white/5"
          >
            <X size={18} />
          </button>
        </div>

        <div className="px-4 mb-3">
          <div className="divider" />
        </div>

        {/* Nav */}
        <nav className="flex-1 px-3 py-1 space-y-0.5 overflow-y-auto">
          {navItems.map((item) => (
            <NavLink
              key={item.href}
              item={item}
              active={isActive(item.href)}
              onClick={() => setSidebarOpen(false)}
            />
          ))}
        </nav>

        {/* Footer */}
        <div className="px-4 pt-3 pb-5">
          <div className="divider mb-4" />
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-[#34D399] opacity-60" />
                <span className="relative inline-flex rounded-full h-2 w-2 bg-[#34D399]" />
              </span>
              <p className="text-[11px] text-[#5E5E75]">v1.2 · Pipeline actif</p>
            </div>
            <button
              onClick={handleLogout}
              disabled={loggingOut}
              className="p-1.5 rounded-lg text-[#5E5E75] hover:text-[#F87171] hover:bg-[#F87171]/10 transition-all disabled:opacity-40"
              title="Déconnexion"
            >
              <LogOut size={15} />
            </button>
          </div>
        </div>
      </aside>

      {/* Main content */}
      <div className="flex-1 flex flex-col min-w-0 h-screen overflow-hidden">
        {/* Mobile topbar */}
        <header className="lg:hidden flex items-center gap-3 px-4 py-3 border-b border-white/[0.05] shrink-0" style={{ background: "var(--bg-sidebar)" }}>
          <button
            onClick={() => setSidebarOpen(true)}
            className="text-[#5E5E75] hover:text-white transition-colors"
          >
            <Menu size={22} />
          </button>
          <div className="flex items-center gap-2.5">
            <div className="w-7 h-7 rounded-lg bg-gradient-to-br from-[#D4AF37] to-[#9A7A10] flex items-center justify-center">
              <Zap size={13} className="text-black" strokeWidth={2.5} />
            </div>
            <h1 className="text-[15px] font-bold text-gold-gradient">Nakora</h1>
          </div>
        </header>
        <main className="flex-1 overflow-y-auto">{children}</main>
      </div>
    </div>
  );
}
