import { createSupabaseAdminClient } from "@/lib/supabase/server";
import { LocalTime } from "@/components/local-time";
import { Wallet, TrendingUp, Receipt } from "lucide-react";

export const revalidate = 60;

interface Subscription {
  id: number;
  plan: string;
  status: string;
  start_date: string;
  end_date: string;
  payment_ref: string | null;
  amount: number | null;
  currency: string;
  users: { username: string | null; phone: string | null } | null;
}

export default async function RevenuePage() {
  const supabase = await createSupabaseAdminClient();

  const [
    { data: subs, count: totalSubs },
    { count: activeSubs },
  ] = await Promise.all([
    supabase
      .from("subscriptions")
      .select("id, plan, status, start_date, end_date, payment_ref, amount, currency, users(username, phone)", { count: "exact" })
      .order("created_at", { ascending: false })
      .limit(100),
    supabase
      .from("subscriptions")
      .select("*", { count: "exact", head: true })
      .eq("status", "active"),
  ]);

  const list = (subs ?? []) as unknown as Subscription[];
  const totalRevenueFCFA = list
    .filter((s) => s.status === "active" || s.status === "expired")
    .reduce((sum, s) => sum + (s.amount ?? 0), 0);

  return (
    <div className="p-4 sm:p-6 lg:p-8 max-w-7xl mx-auto">
      <div className="mb-8">
        <h2 className="text-2xl sm:text-3xl font-bold">Revenus</h2>
        <p className="text-[#6B6B80] mt-1">
          {activeSubs ?? 0} abonnements actifs · {totalSubs ?? 0} total
        </p>
      </div>

      {/* Résumé */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8">
        <div className="glass-card p-5 glow-gold">
          <div className="flex items-center gap-2 mb-3">
            <span className="p-2 rounded-lg bg-[#D4AF37]/10 text-[#D4AF37]"><Wallet size={16} /></span>
            <span className="text-xs font-medium uppercase tracking-wider text-[#6B6B80]">Revenus totaux</span>
          </div>
          <div className="text-3xl font-bold text-[#D4AF37]">
            {totalRevenueFCFA.toLocaleString("fr")} <span className="text-lg">XOF</span>
          </div>
        </div>
        <div className="glass-card p-5">
          <div className="flex items-center gap-2 mb-3">
            <span className="p-2 rounded-lg bg-[#34D399]/10 text-[#34D399]"><TrendingUp size={16} /></span>
            <span className="text-xs font-medium uppercase tracking-wider text-[#6B6B80]">Actifs</span>
          </div>
          <div className="text-3xl font-bold text-[#34D399]">{activeSubs ?? 0}</div>
        </div>
        <div className="glass-card p-5">
          <div className="flex items-center gap-2 mb-3">
            <span className="p-2 rounded-lg bg-white/5 text-[#9B9BB0]"><Receipt size={16} /></span>
            <span className="text-xs font-medium uppercase tracking-wider text-[#6B6B80]">Transactions</span>
          </div>
          <div className="text-3xl font-bold">{totalSubs ?? 0}</div>
        </div>
      </div>

      {/* Table */}
      <div className="glass-card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-white/[0.06] text-[#6B6B80]">
                <th className="text-left p-4 font-medium text-xs uppercase tracking-wider">Utilisateur</th>
                <th className="text-left p-4 font-medium text-xs uppercase tracking-wider">Plan</th>
                <th className="text-left p-4 font-medium text-xs uppercase tracking-wider">Statut</th>
                <th className="text-right p-4 font-medium text-xs uppercase tracking-wider">Montant</th>
                <th className="text-right p-4 font-medium text-xs uppercase tracking-wider">Début</th>
                <th className="text-right p-4 font-medium text-xs uppercase tracking-wider">Fin</th>
                <th className="text-right p-4 font-medium text-xs uppercase tracking-wider">Réf</th>
              </tr>
            </thead>
            <tbody>
              {list.map((sub) => (
                <tr key={sub.id} className="border-b border-white/[0.04] hover:bg-white/[0.02] transition-colors">
                  <td className="p-4 font-medium">{sub.users?.username ?? sub.users?.phone ?? "—"}</td>
                  <td className="p-4 capitalize text-[#9B9BB0]">{sub.plan}</td>
                  <td className="p-4">
                    <span className={`px-2 py-0.5 rounded-md text-xs font-medium ${statusColor(sub.status)}`}>
                      {sub.status}
                    </span>
                  </td>
                  <td className="p-4 text-right font-medium">
                    {sub.amount ? `${sub.amount.toLocaleString("fr")} ${sub.currency}` : "—"}
                  </td>
                  <td className="p-4 text-right text-[#6B6B80] text-xs">
                    <LocalTime date={sub.start_date} format="date" />
                  </td>
                  <td className="p-4 text-right text-[#6B6B80] text-xs">
                    <LocalTime date={sub.end_date} format="date" />
                  </td>
                  <td className="p-4 text-right font-mono text-xs text-[#6B6B80]">
                    {sub.payment_ref ?? "—"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

function statusColor(status: string): string {
  const m: Record<string, string> = {
    active: "text-[#34D399] bg-[#34D399]/10",
    expired: "text-[#6B6B80] bg-white/5",
    cancelled: "text-[#F87171] bg-[#F87171]/10",
    pending: "text-[#FBBF24] bg-[#FBBF24]/10",
  };
  return m[status] ?? "text-white bg-white/10";
}
