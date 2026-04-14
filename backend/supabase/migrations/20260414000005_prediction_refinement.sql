-- ============================================================
-- QUANTARA — Migration 005 : Raffinement des prédictions
-- Ajoute le support du raffinement basé sur les compositions
-- officielles (compos) — fonctionnalité clé de la proposition
-- de valeur QUANTARA.
-- ============================================================

-- Colonne indiquant si le prono a été affiné avec la compo officielle
ALTER TABLE public.predictions
  ADD COLUMN IF NOT EXISTS is_refined boolean NOT NULL DEFAULT false;

-- Date de raffinement (null = pas encore affiné)
ALTER TABLE public.predictions
  ADD COLUMN IF NOT EXISTS refined_at timestamptz;

COMMENT ON COLUMN public.predictions.is_refined IS
  'True si le prono a été recalculé avec les compositions officielles';

COMMENT ON COLUMN public.predictions.refined_at IS
  'Horodatage du dernier raffinement basé sur les compos';
