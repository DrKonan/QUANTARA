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
} from "lucide-react";

const navItems = [
  { href: "/dashboard", label: "Vue d'ensemble", icon: LayoutDashboard },
  { href: "/dashboard/predictions", label: "Pronos", icon: ListChecks },
  { href: "/dashboard/history", label: "Historique", icon: History },
  { href: "/dashboard/users", label: "Utilisateurs", icon: Users },
  { href: "/dashboard/revenue", label: "Revenus", icon: CreditCard },
  { href: "/dashboard/stats", label: "Performance", icon: TrendingUp },
  { href: "/dashboard/config", label: "Configuration", icon: Settings },
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
        if (active) {
          e.preventDefault();
          return;
        }
        startTransition(() => {
          onClick();
        });
      }}
      className={`group flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm transition-all duration-200 ${
        active
          ? "text-[#D4AF37] bg-[#D4AF37]/10 font-semibold shadow-[inset_0_0_0_1px_rgba(212,175,55,0.2)]"
          : "text-[#6B6B80] hover:text-white hover:bg-white/5"
      }`}
    >
      {isPending ? (
        <Loader2 size={18} className="animate-spin text-[#D4AF37]" />
      ) : (
        <item.icon size={18} className={active ? "" : "group-hover:text-[#D4AF37] transition-colors"} />
      )}
      {item.label}
      {isPending && (
        <span className="ml-auto w-1.5 h-1.5 rounded-full bg-[#D4AF37] animate-pulse" />
      )}
    </Link>
  );
}

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const pathname = usePathname();
  const [sidebarOpen, setSidebarOpen] = useState(false);

  useEffect(() => {
    setSidebarOpen(false);
  }, [pathname]);

  const isActive = (href: string) =>
    href === "/dashboard" ? pathname === "/dashboard" : pathname.startsWith(href);

  return (
    <div className="flex min-h-screen bg-[var(--bg-primary)]">
      {/* Overlay mobile */}
      {sidebarOpen && (
        <div
          className="fixed inset-0 bg-black/70 backdrop-blur-sm z-40 lg:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* Sidebar */}
      <aside
        className={`fixed inset-y-0 left-0 z-50 w-64 bg-[#0F0F1A] border-r border-white/[0.06] flex flex-col
          transform transition-transform duration-200 ease-out
          lg:relative lg:translate-x-0
          ${sidebarOpen ? "translate-x-0" : "-translate-x-full"}`}
      >
        {/* Logo */}
        <div className="p-6 flex items-center justify-between">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-[#D4AF37] to-[#B8961F] flex items-center justify-center">
              <Zap size={16} className="text-black" />
            </div>
            <div>
              <h1 className="text-base font-bold text-gold-gradient">Quantara</h1>
              <p className="text-[10px] text-[#6B6B80] font-medium uppercase tracking-widest">Admin</p>
            </div>
          </div>
          <button
            onClick={() => setSidebarOpen(false)}
            className="lg:hidden text-[#6B6B80] hover:text-white"
          >
            <X size={20} />
          </button>
        </div>

        <div className="px-4 mb-2">
          <div className="h-px bg-gradient-to-r from-transparent via-white/10 to-transparent" />
        </div>

        <nav className="flex-1 px-3 py-2 space-y-0.5">
          {navItems.map((item) => (
            <NavLink
              key={item.href}
              item={item}
              active={isActive(item.href)}
              onClick={() => setSidebarOpen(false)}
            />
          ))}
        </nav>

        <div className="p-4">
          <div className="h-px bg-gradient-to-r from-transparent via-white/10 to-transparent mb-4" />
          <div className="flex items-center gap-2">
            <div className="w-2 h-2 rounded-full bg-[#34D399] live-pulse" />
            <p className="text-xs text-[#6B6B80]">v1.1 — Pipeline actif</p>
          </div>
        </div>
      </aside>

      {/* Main content */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Topbar mobile */}
        <header className="lg:hidden flex items-center gap-3 p-4 border-b border-white/[0.06] bg-[var(--bg-primary)]">
          <button
            onClick={() => setSidebarOpen(true)}
            className="text-[#6B6B80] hover:text-white transition-colors"
          >
            <Menu size={24} />
          </button>
          <div className="flex items-center gap-2">
            <div className="w-6 h-6 rounded-md bg-gradient-to-br from-[#D4AF37] to-[#B8961F] flex items-center justify-center">
              <Zap size={12} className="text-black" />
            </div>
            <h1 className="text-lg font-bold text-gold-gradient">Quantara</h1>
          </div>
        </header>
        <main className="flex-1 overflow-auto">{children}</main>
      </div>
    </div>
  );
}
