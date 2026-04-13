import { createSupabaseAdminClient } from "@/lib/supabase/server";
import { ConfigForm } from "./config-form";

export const revalidate = 0;

export default async function ConfigPage() {
  const supabase = await createSupabaseAdminClient();

  const { data: configs } = await supabase
    .from("app_config")
    .select("key, value, description")
    .order("key");

  const configMap = Object.fromEntries(
    (configs ?? []).map((c: { key: string; value: string }) => [c.key, c])
  );

  return (
    <div className="p-4 sm:p-6 lg:p-8">
      <div className="mb-6 lg:mb-8">
        <h2 className="text-xl sm:text-2xl font-bold">Configuration</h2>
        <p className="text-[#A0A0B0] mt-1 text-sm sm:text-base">Paramètres dynamiques de l&apos;application</p>
      </div>
      <ConfigForm configs={configMap} />
    </div>
  );
}
