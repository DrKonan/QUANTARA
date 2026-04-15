-- ============================================================
-- QUANTARA — Migration 009 : Top Picks + Nouveaux marchés
--
-- 1. Ajoute la colonne is_top_pick sur predictions
-- 2. Étend le check constraint prediction_type pour inclure double_chance
-- ============================================================

-- 1. Nouvelle colonne is_top_pick (1-2 meilleurs pronos par match)
ALTER TABLE public.predictions
  ADD COLUMN IF NOT EXISTS is_top_pick boolean NOT NULL DEFAULT false;

-- 2. Remplace le check constraint pour ajouter double_chance
ALTER TABLE public.predictions
  DROP CONSTRAINT IF EXISTS predictions_prediction_type_check;

ALTER TABLE public.predictions
  ADD CONSTRAINT predictions_prediction_type_check
  CHECK (prediction_type IN (
    'result', 'btts', 'over_under', 'handicap',
    'corners', 'cards', 'halftime', 'double_chance'
  ));

-- 3. Index pour accélérer la requête "top picks du jour"
CREATE INDEX IF NOT EXISTS idx_predictions_top_pick
  ON public.predictions (match_id, is_top_pick)
  WHERE is_top_pick = true;
