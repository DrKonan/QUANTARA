import { createSupabaseAdminClient } from "@/lib/supabase/server";
import { ConfigForm } from "./config-form";
import { LeaguesManager } from "./leagues-manager";

export const revalidate = 0;

export default async function ConfigPage() {
  const supabase = await createSupabaseAdminClient();

  const [{ data: configs }, { data: leagues }] = await Promise.all([
    supabase
      .from("app_config")
      .select("key, value, description")
      .order("key"),
    supabase
      .from("leagues_config")
      .select("league_id, league_name, country, tier, is_active, category")
      .order("tier")
      .order("league_name"),
  ]);

  const configMap = Object.fromEntries(
    (configs ?? []).map((c: { key: string; value: string }) => [c.key, c])
  );

  return (
    <div className="p-4 sm:p-6 lg:p-8 max-w-7xl mx-auto">
      <div className="mb-8">
        <h2 className="text-2xl sm:text-3xl font-bold">Configuration</h2>
        <p className="text-[#6B6B80] mt-1">Paramètres dynamiques et gestion des ligues</p>
      </div>

      {/* Paramètres */}
      <div className="mb-10">
        <h3 className="text-lg font-semibold mb-4">Paramètres</h3>
        <ConfigForm configs={configMap} />
      </div>

      {/* Ligues */}
      <div>
        <h3 className="text-lg font-semibold mb-4">Ligues suivies</h3>
        <LeaguesManager leagues={(leagues ?? []) as { league_id: number; league_name: string; country: string; tier: number; is_active: boolean; category: string }[]} />
      </div>
    </div>
  );
}
