import { createSupabaseAdminClient } from "@/lib/supabase/server";
import { Crown, UserCheck } from "lucide-react";

export const revalidate = 60;

interface User {
  id: string;
  username: string | null;
  phone: string | null;
  plan: string;
  trial_used: boolean;
  created_at: string;
}

export default async function UsersPage() {
  const supabase = await createSupabaseAdminClient();

  const { data: users, count } = await supabase
    .from("users")
    .select("id, username, phone, plan, trial_used, created_at", { count: "exact" })
    .order("created_at", { ascending: false })
    .limit(100);

  const { count: premiumCount } = await supabase
    .from("users")
    .select("*", { count: "exact", head: true })
    .eq("plan", "premium");

  const list = (users ?? []) as User[];

  return (
    <div className="p-4 sm:p-6 lg:p-8 max-w-7xl mx-auto">
      <div className="mb-8 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-2xl sm:text-3xl font-bold">Utilisateurs</h2>
          <p className="text-[#6B6B80] mt-1">
            {count ?? 0} inscrits · {premiumCount ?? 0} premium
          </p>
        </div>
        <div className="flex items-center gap-3">
          <div className="glass-card px-4 py-2.5 flex items-center gap-2">
            <UserCheck size={14} className="text-[#34D399]" />
            <span className="text-sm font-medium">{count ?? 0}</span>
            <span className="text-xs text-[#6B6B80]">total</span>
          </div>
          <div className="glass-card px-4 py-2.5 flex items-center gap-2">
            <Crown size={14} className="text-[#D4AF37]" />
            <span className="text-sm font-medium text-[#D4AF37]">{premiumCount ?? 0}</span>
            <span className="text-xs text-[#6B6B80]">premium</span>
          </div>
        </div>
      </div>

      <div className="glass-card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-white/[0.06] text-[#6B6B80]">
                <th className="text-left p-4 font-medium text-xs uppercase tracking-wider">Utilisateur</th>
                <th className="text-left p-4 font-medium text-xs uppercase tracking-wider">Téléphone</th>
                <th className="text-left p-4 font-medium text-xs uppercase tracking-wider">Plan</th>
                <th className="text-left p-4 font-medium text-xs uppercase tracking-wider">Essai</th>
                <th className="text-right p-4 font-medium text-xs uppercase tracking-wider">Inscription</th>
              </tr>
            </thead>
            <tbody>
              {list.map((user) => (
                <tr key={user.id} className="border-b border-white/[0.04] hover:bg-white/[0.02] transition-colors">
                  <td className="p-4">
                    <div className="flex items-center gap-3">
                      <div className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold ${
                        user.plan === "premium"
                          ? "bg-[#D4AF37]/10 text-[#D4AF37]"
                          : "bg-white/5 text-[#6B6B80]"
                      }`}>
                        {(user.username ?? "?")[0].toUpperCase()}
                      </div>
                      <div>
                        <div className="font-medium">{user.username ?? "—"}</div>
                        <div className="text-[10px] text-[#6B6B80] font-mono">{user.id.slice(0, 8)}</div>
                      </div>
                    </div>
                  </td>
                  <td className="p-4 text-[#6B6B80]">{user.phone ?? "—"}</td>
                  <td className="p-4">
                    <span className={`px-2.5 py-1 rounded-md text-xs font-medium ${
                      user.plan === "premium"
                        ? "text-[#D4AF37] bg-[#D4AF37]/10"
                        : "text-[#6B6B80] bg-white/5"
                    }`}>
                      {user.plan === "premium" && "★ "}{user.plan}
                    </span>
                  </td>
                  <td className="p-4">
                    <span className={`text-xs ${
                      user.trial_used ? "text-[#6B6B80]" : "text-[#34D399] font-medium"
                    }`}>
                      {user.trial_used ? "Utilisé" : "Disponible"}
                    </span>
                  </td>
                  <td className="p-4 text-right text-[#6B6B80] text-xs">
                    {new Date(user.created_at).toLocaleDateString("fr-FR", { day: "2-digit", month: "short", year: "numeric" })}
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
