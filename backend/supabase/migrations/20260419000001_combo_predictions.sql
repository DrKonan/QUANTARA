-- ================================================================
-- QUANTARA — Migration : Système de combinés (combos)
-- Ajoute bookmaker_odds aux prédictions + table combo_predictions
-- PRO et VIP ont accès aux combinés
-- ================================================================

-- 1. Ajouter la cote bookmaker à chaque prédiction individuelle
ALTER TABLE public.predictions
  ADD COLUMN IF NOT EXISTS bookmaker_odds numeric(6,2);

COMMENT ON COLUMN public.predictions.bookmaker_odds IS 'Bookmaker odds for this specific prediction (e.g. 1.65 for BTTS Yes)';

-- 2. Table des combinés du jour
CREATE TABLE IF NOT EXISTS public.combo_predictions (
  id            bigserial PRIMARY KEY,
  combo_date    date NOT NULL,
  combo_type    text NOT NULL CHECK (combo_type IN ('safe', 'bold')),
  combined_odds numeric(8,2) NOT NULL,
  combined_confidence numeric(4,3) NOT NULL,
  leg_count     integer NOT NULL,
  legs          jsonb NOT NULL,
  -- legs = [{ prediction_id, match_id, home_team, away_team, league,
  --           prediction_type, prediction, confidence, bookmaker_odds }]
  status        text NOT NULL DEFAULT 'active'
                  CHECK (status IN ('active', 'won', 'lost', 'partial', 'void')),
  result_detail jsonb,
  -- result_detail = [{ prediction_id, is_correct }] — rempli par evaluate
  min_plan      text NOT NULL DEFAULT 'pro'
                  CHECK (min_plan IN ('pro', 'vip')),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_combo_predictions_date
  ON public.combo_predictions(combo_date);

COMMENT ON TABLE public.combo_predictions IS 'Daily combo predictions (accumulators) for PRO/VIP users';

-- 3. RLS — lecture publique (filtrage par plan côté API), écriture service_role uniquement
ALTER TABLE public.combo_predictions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read combos"
  ON public.combo_predictions FOR SELECT
  USING (true);

-- 4. PRO a aussi accès aux combos
UPDATE public.plan_pricing SET has_combos = true WHERE plan = 'pro';

-- 5. Cron : génère les combinés après les prédictions prematch
-- Exécution à 4h et 21h UTC (30 min après predict-prematch)
SELECT cron.schedule(
  'generate-combos',
  '0 4,21 * * *',
  $$
  SELECT net.http_post(
    url := current_setting('app.settings.service_url', true) || '/functions/v1/generate-combos',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
    ),
    body := '{}'::jsonb
  );
  $$
);
