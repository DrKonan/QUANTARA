-- ================================================================
-- NAKORA — Migration : Combos du jour + Combos du soir
-- Ajoute une colonne combo_slot ('day' | 'evening') pour distinguer
-- les deux créneaux horaires de combinés quotidiens :
--   • 'day'     → matchs avant  22h UTC (généré à 4h UTC)
--   • 'evening' → matchs ≥ 22h UTC      (généré à 21h UTC)
-- ================================================================

ALTER TABLE public.combo_predictions
  ADD COLUMN IF NOT EXISTS combo_slot text NOT NULL DEFAULT 'day'
    CHECK (combo_slot IN ('day', 'evening'));

COMMENT ON COLUMN public.combo_predictions.combo_slot IS
  '''day'': matches before 22:00 UTC | ''evening'': matches from 22:00 UTC';

-- Met à jour l'index pour inclure le slot (idempotence date+slot côté Edge Function)
DROP INDEX IF EXISTS idx_combo_predictions_date;
CREATE INDEX IF NOT EXISTS idx_combo_predictions_date_slot
  ON public.combo_predictions(combo_date, combo_slot);

-- ── Mise à jour des crons ────────────────────────────────────────
-- Supprime l'ancien cron unique, crée deux crons distincts
SELECT cron.unschedule('generate-combos');

SELECT cron.schedule(
  'generate-combos-day',
  '0 4 * * *',
  $$
  SELECT net.http_post(
    url := current_setting('app.settings.service_url', true) || '/functions/v1/generate-combos',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
    ),
    body := '{"slot":"day"}'::jsonb
  );
  $$
);

SELECT cron.schedule(
  'generate-combos-evening',
  '0 21 * * *',
  $$
  SELECT net.http_post(
    url := current_setting('app.settings.service_url', true) || '/functions/v1/generate-combos',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
    ),
    body := '{"slot":"evening"}'::jsonb
  );
  $$
);
