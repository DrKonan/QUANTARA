-- ============================================================
-- QUANTARA — Migration 006 : current_season + cron 30 min
-- 1) Ajoute current_season à leagues_config
-- 2) Remplace le cron update-live-scores de 2 min → 30 min
-- ============================================================

-- 1. Ajoute la colonne current_season (défaut 2025 pour saison 2025-2026)
ALTER TABLE public.leagues_config
  ADD COLUMN IF NOT EXISTS current_season integer NOT NULL DEFAULT 2025;

-- Met à jour les ligues internationales à cycle annuel si nécessaire
-- Coupe du Monde 2026 → season 2026
UPDATE public.leagues_config SET current_season = 2026 WHERE league_id = 1;

-- 2. Supprime l'ancien cron 2 min et crée le nouveau à 30 min
SELECT cron.unschedule('update-live-scores-2min');

SELECT cron.schedule(
  'update-live-scores-30min',
  '*/30 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://epiaxzyzrclebutxvbgp.supabase.co/functions/v1/update-live-scores',
    headers := jsonb_build_object(
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwaWF4enl6cmNsZWJ1dHh2YmdwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxMDUyNjEsImV4cCI6MjA5MTY4MTI2MX0.fJ8OvlvzJS-WAbZ1BJHSKy1NhjDoiL3-fPAn-I_yCAc',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);
