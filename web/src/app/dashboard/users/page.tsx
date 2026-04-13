import { createSupabaseAdminClient } from "@/lib/supabase/server";

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
    <div className="p-8">
      <div className="mb-8 flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold">Utilisateurs</h2>
          <p className="text-[#A0A0B0] mt-1">
            {count ?? 0} inscrits · {premiumCount ?? 0} premium
          </p>
        </div>
      </div>

      <div className="bg-[#1A1A2E] rounded-xl border border-white/10 overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-white/5 text-[#A0A0B0]">
              <th className="text-left p-4 font-medium">Utilisateur</th>
              <th className="text-left p-4 font-medium">Téléphone</th>
              <th className="text-left p-4 font-medium">Plan</th>
              <th className="text-left p-4 font-medium">Essai</th>
              <th className="text-right p-4 font-medium">Inscription</th>
            </tr>
          </thead>
          <tbody>
            {list.map((user) => (
              <tr key={user.id} className="border-b border-white/5 hover:bg-white/5">
                <td className="p-4">
                  <div className="font-medium">{user.username ?? "—"}</div>
                  <div className="text-xs text-[#A0A0B0] font-mono">{user.id.slice(0, 8)}…</div>
                </td>
                <td className="p-4 text-[#A0A0B0]">{user.phone ?? "—"}</td>
                <td className="p-4">
                  <span className={`px-2 py-0.5 rounded text-xs font-medium ${
                    user.plan === "premium"
                      ? "text-[#D4AF37] bg-[#D4AF37]/10"
                      : "text-[#A0A0B0] bg-white/5"
                  }`}>
                    {user.plan}
                  </span>
                </td>
                <td className="p-4 text-xs text-[#A0A0B0]">
                  {user.trial_used ? "Utilisé" : "Disponible"}
                </td>
                <td className="p-4 text-right text-[#A0A0B0] text-xs">
                  {new Date(user.created_at).toLocaleDateString("fr")}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
