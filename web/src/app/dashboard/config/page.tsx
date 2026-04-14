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
    <div className="p-4 sm:p-6 lg:p-8 max-w-7xl mx-auto">
      <div className="mb-8">
        <h2 className="text-2xl sm:text-3xl font-bold">Configuration</h2>
        <p className="text-[#6B6B80] mt-1">Paramètres dynamiques de l&apos;application</p>
      </div>
      <ConfigForm configs={configMap} />
    </div>
  );
}
