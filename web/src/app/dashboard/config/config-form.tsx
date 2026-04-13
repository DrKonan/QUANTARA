"use client";

import { useState } from "react";
import { createSupabaseClient } from "@/lib/supabase/client";

interface ConfigEntry {
  key: string;
  value: string;
  description?: string;
}

interface ConfigFormProps {
  configs: Record<string, ConfigEntry>;
}

const CONFIG_LABELS: Record<string, string> = {
  publish_threshold: "Seuil de publication (0.0–1.0)",
  maintenance_mode: "Mode maintenance (true/false)",
  trial_duration_days: "Durée de l'essai (jours)",
  max_predictions_per_match: "Pronos max par match",
  openai_model: "Modèle OpenAI",
  live_analysis_interval: "Intervalle analyse live (min)",
};

export function ConfigForm({ configs }: ConfigFormProps) {
  const [values, setValues] = useState<Record<string, string>>(
    Object.fromEntries(Object.entries(configs).map(([k, v]) => [k, v.value]))
  );
  const [saving, setSaving] = useState<string | null>(null);
  const [saved, setSaved] = useState<string | null>(null);

  async function handleSave(key: string) {
    setSaving(key);
    const supabase = createSupabaseClient();
    await supabase
      .from("app_config")
      .update({ value: values[key] })
      .eq("key", key);
    setSaving(null);
    setSaved(key);
    setTimeout(() => setSaved(null), 2000);
  }

  return (
    <div className="max-w-2xl space-y-4">
      {Object.entries(configs).map(([key, entry]) => (
        <div key={key} className="bg-[#1A1A2E] rounded-xl border border-white/10 p-5">
          <div className="mb-3">
            <label className="text-sm font-medium">{CONFIG_LABELS[key] ?? key}</label>
            {entry.description && (
              <p className="text-xs text-[#A0A0B0] mt-0.5">{entry.description}</p>
            )}
          </div>
          <div className="flex gap-3">
            <input
              type="text"
              value={values[key] ?? ""}
              onChange={(e) => setValues((v) => ({ ...v, [key]: e.target.value }))}
              className="flex-1 bg-white/5 border border-white/10 rounded-lg px-3 py-2 text-sm focus:outline-none focus:border-[#D4AF37] transition-colors"
            />
            <button
              onClick={() => handleSave(key)}
              disabled={saving === key}
              className="px-4 py-2 bg-[#D4AF37] text-black text-sm font-medium rounded-lg hover:bg-[#c9a430] disabled:opacity-50 transition-colors"
            >
              {saving === key ? "…" : saved === key ? "✓" : "Sauver"}
            </button>
          </div>
        </div>
      ))}
    </div>
  );
}
