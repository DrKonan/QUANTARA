import Link from "next/link";
import { LayoutDashboard, Users, TrendingUp, CreditCard, ListChecks, Settings } from "lucide-react";

const navItems = [
  { href: "/dashboard", label: "Vue d'ensemble", icon: LayoutDashboard },
  { href: "/dashboard/predictions", label: "Pronos", icon: ListChecks },
  { href: "/dashboard/users", label: "Utilisateurs", icon: Users },
  { href: "/dashboard/revenue", label: "Revenus", icon: CreditCard },
  { href: "/dashboard/stats", label: "Performance", icon: TrendingUp },
  { href: "/dashboard/config", label: "Configuration", icon: Settings },
];

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="flex min-h-screen">
      {/* Sidebar */}
      <aside className="w-64 bg-[#1A1A2E] border-r border-white/10 flex flex-col">
        <div className="p-6 border-b border-white/10">
          <h1 className="text-xl font-bold text-[#D4AF37]">Quantara</h1>
          <p className="text-xs text-[#A0A0B0] mt-1">Back-office admin</p>
        </div>
        <nav className="flex-1 p-4 space-y-1">
          {navItems.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="flex items-center gap-3 px-3 py-2.5 rounded-lg text-[#A0A0B0] hover:text-white hover:bg-white/5 transition-colors text-sm"
            >
              <item.icon size={18} />
              {item.label}
            </Link>
          ))}
        </nav>
        <div className="p-4 border-t border-white/10">
          <p className="text-xs text-[#A0A0B0]">v1.0.0 — Admin</p>
        </div>
      </aside>

      {/* Main content */}
      <main className="flex-1 overflow-auto">{children}</main>
    </div>
  );
}
