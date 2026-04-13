import { createSupabaseAdminClient } from "@/lib/supabase/server";

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
    <div className="p-8">
      <div className="mb-8">
        <h2 className="text-2xl font-bold">Revenus</h2>
        <p className="text-[#A0A0B0] mt-1">
          {activeSubs ?? 0} abonnements actifs · {totalSubs ?? 0} total
        </p>
      </div>

      {/* Résumé */}
      <div className="grid grid-cols-3 gap-4 mb-8">
        <div className="bg-[#1A1A2E] rounded-xl border border-white/10 p-5">
          <div className="text-sm text-[#A0A0B0] mb-2">Revenus totaux</div>
          <div className="text-2xl font-bold text-[#D4AF37]">
            {totalRevenueFCFA.toLocaleString("fr")} XOF
          </div>
        </div>
        <div className="bg-[#1A1A2E] rounded-xl border border-white/10 p-5">
          <div className="text-sm text-[#A0A0B0] mb-2">Abonnements actifs</div>
          <div className="text-2xl font-bold text-[#2ED573]">{activeSubs ?? 0}</div>
        </div>
        <div className="bg-[#1A1A2E] rounded-xl border border-white/10 p-5">
          <div className="text-sm text-[#A0A0B0] mb-2">Total transactions</div>
          <div className="text-2xl font-bold">{totalSubs ?? 0}</div>
        </div>
      </div>

      {/* Table */}
      <div className="bg-[#1A1A2E] rounded-xl border border-white/10 overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-white/5 text-[#A0A0B0]">
              <th className="text-left p-4 font-medium">Utilisateur</th>
              <th className="text-left p-4 font-medium">Plan</th>
              <th className="text-left p-4 font-medium">Statut</th>
              <th className="text-right p-4 font-medium">Montant</th>
              <th className="text-right p-4 font-medium">Début</th>
              <th className="text-right p-4 font-medium">Fin</th>
              <th className="text-right p-4 font-medium">Réf CinetPay</th>
            </tr>
          </thead>
          <tbody>
            {list.map((sub) => (
              <tr key={sub.id} className="border-b border-white/5 hover:bg-white/5">
                <td className="p-4">{sub.users?.username ?? sub.users?.phone ?? "—"}</td>
                <td className="p-4 capitalize">{sub.plan}</td>
                <td className="p-4">
                  <span className={`px-2 py-0.5 rounded text-xs font-medium ${statusColor(sub.status)}`}>
                    {sub.status}
                  </span>
                </td>
                <td className="p-4 text-right font-medium">
                  {sub.amount ? `${sub.amount.toLocaleString("fr")} ${sub.currency}` : "—"}
                </td>
                <td className="p-4 text-right text-[#A0A0B0] text-xs">
                  {new Date(sub.start_date).toLocaleDateString("fr")}
                </td>
                <td className="p-4 text-right text-[#A0A0B0] text-xs">
                  {new Date(sub.end_date).toLocaleDateString("fr")}
                </td>
                <td className="p-4 text-right font-mono text-xs text-[#A0A0B0]">
                  {sub.payment_ref ?? "—"}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function statusColor(status: string): string {
  const m: Record<string, string> = {
    active: "text-[#2ED573] bg-[#2ED573]/10",
    expired: "text-[#A0A0B0] bg-white/5",
    cancelled: "text-[#FF4757] bg-[#FF4757]/10",
    pending: "text-[#FFA502] bg-[#FFA502]/10",
  };
  return m[status] ?? "text-white bg-white/10";
}
