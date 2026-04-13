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
} from "lucide-react";

const navItems = [
  { href: "/dashboard", label: "Vue d'ensemble", icon: LayoutDashboard },
  { href: "/dashboard/predictions", label: "Pronos", icon: ListChecks },
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
      className={`flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition-colors ${
        active
          ? "text-[#D4AF37] bg-[#D4AF37]/10 font-medium"
          : "text-[#A0A0B0] hover:text-white hover:bg-white/5"
      }`}
    >
      {isPending ? (
        <Loader2 size={18} className="animate-spin text-[#D4AF37]" />
      ) : (
        <item.icon size={18} />
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

  // Fermer la sidebar quand on change de page (mobile)
  useEffect(() => {
    setSidebarOpen(false);
  }, [pathname]);

  const isActive = (href: string) =>
    href === "/dashboard" ? pathname === "/dashboard" : pathname.startsWith(href);

  return (
    <div className="flex min-h-screen">
      {/* Overlay mobile */}
      {sidebarOpen && (
        <div
          className="fixed inset-0 bg-black/60 z-40 lg:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* Sidebar */}
      <aside
        className={`fixed inset-y-0 left-0 z-50 w-64 bg-[#1A1A2E] border-r border-white/10 flex flex-col
          transform transition-transform duration-200 ease-out
          lg:relative lg:translate-x-0
          ${sidebarOpen ? "translate-x-0" : "-translate-x-full"}`}
      >
        <div className="p-6 border-b border-white/10 flex items-center justify-between">
          <div>
            <h1 className="text-xl font-bold text-[#D4AF37]">Quantara</h1>
            <p className="text-xs text-[#A0A0B0] mt-1">Back-office admin</p>
          </div>
          <button
            onClick={() => setSidebarOpen(false)}
            className="lg:hidden text-[#A0A0B0] hover:text-white"
          >
            <X size={20} />
          </button>
        </div>
        <nav className="flex-1 p-4 space-y-1">
          {navItems.map((item) => (
            <NavLink
              key={item.href}
              item={item}
              active={isActive(item.href)}
              onClick={() => setSidebarOpen(false)}
            />
          ))}
        </nav>
        <div className="p-4 border-t border-white/10">
          <p className="text-xs text-[#A0A0B0]">v1.0.0 — Admin</p>
        </div>
      </aside>

      {/* Main content */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Topbar mobile */}
        <header className="lg:hidden flex items-center gap-3 p-4 border-b border-white/10 bg-[#0D0D0D]">
          <button
            onClick={() => setSidebarOpen(true)}
            className="text-[#A0A0B0] hover:text-white"
          >
            <Menu size={24} />
          </button>
          <h1 className="text-lg font-bold text-[#D4AF37]">Quantara</h1>
        </header>
        <main className="flex-1 overflow-auto">{children}</main>
      </div>
    </div>
  );
}
