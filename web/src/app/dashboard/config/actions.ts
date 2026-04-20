"use server";

import { createSupabaseAdminClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";

// ----------------------------------------------------------------
// app_config
// ----------------------------------------------------------------

export async function updateConfig(key: string, value: string): Promise<{ success: boolean; error?: string }> {
  const supabase = await createSupabaseAdminClient();
  const { error } = await supabase
    .from("app_config")
    .update({ value })
    .eq("key", key);

  if (error) return { success: false, error: error.message };

  revalidatePath("/dashboard/config");
  return { success: true };
}

// ----------------------------------------------------------------
// leagues_config
// ----------------------------------------------------------------

export async function toggleLeague(leagueId: number, isActive: boolean): Promise<{ success: boolean; error?: string }> {
  const supabase = await createSupabaseAdminClient();
  const { error } = await supabase
    .from("leagues_config")
    .update({ is_active: isActive })
    .eq("league_id", leagueId);

  if (error) return { success: false, error: error.message };

  revalidatePath("/dashboard/config");
  return { success: true };
}

export async function triggerFetchMatches(): Promise<{ success: boolean; data?: Record<string, unknown>; error?: string }> {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;

  try {
    const res = await fetch(`${supabaseUrl}/functions/v1/fetch-matches`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${serviceKey}`,
      },
      body: JSON.stringify({ mode: "morning" }),
    });
    const data = await res.json();
    if (!res.ok) return { success: false, error: data.error ?? "Erreur inconnue" };
    return { success: true, data };
  } catch (e) {
    return { success: false, error: (e as Error).message };
  }
}
