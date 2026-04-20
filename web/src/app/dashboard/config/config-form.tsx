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
  max_predictions_per_match: "Pronos max par match",  min_daily_matches: "Matchs minimum par jour (auto-expansion)",  openai_model: "Modèle OpenAI",
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
        <div key={key} className="glass-card p-5">
          <div className="mb-3">
            <label className="text-sm font-medium">{CONFIG_LABELS[key] ?? key}</label>
            {entry.description && (
              <p className="text-xs text-[#6B6B80] mt-0.5">{entry.description}</p>
            )}
          </div>
          <div className="flex gap-3">
            <input
              type="text"
              value={values[key] ?? ""}
              onChange={(e) => setValues((v) => ({ ...v, [key]: e.target.value }))}
              className="flex-1 bg-white/[0.03] border border-white/[0.08] rounded-lg px-3 py-2.5 text-sm focus:outline-none focus:border-[#D4AF37]/50 focus:ring-1 focus:ring-[#D4AF37]/20 transition-all"
            />
            <button
              onClick={() => handleSave(key)}
              disabled={saving === key}
              className="px-5 py-2.5 bg-gradient-to-r from-[#D4AF37] to-[#B8961F] text-black text-sm font-semibold rounded-lg hover:opacity-90 disabled:opacity-50 transition-all"
            >
              {saving === key ? "…" : saved === key ? "✓" : "Sauver"}
            </button>
          </div>
        </div>
      ))}
    </div>
  );
}
