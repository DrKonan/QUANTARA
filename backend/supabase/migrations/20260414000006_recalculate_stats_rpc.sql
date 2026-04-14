-- ============================================================
-- QUANTARA — Migration 006 : Fonction RPC recalculate_prediction_stats
-- Agrège les résultats depuis la table predictions vers
-- prediction_stats. Appelée par evaluate-predictions après
-- chaque évaluation de match.
-- ============================================================

CREATE OR REPLACE FUNCTION public.recalculate_prediction_stats()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  _month text;
BEGIN
  -- 1) Agrégat global (all_time) — toutes ligues, tous types
  INSERT INTO public.prediction_stats (period, sport, league, prediction_type, total, correct, incorrect)
  SELECT
    'all_time',
    'football',
    NULL,
    NULL,
    COUNT(*) FILTER (WHERE is_correct IS NOT NULL),
    COUNT(*) FILTER (WHERE is_correct = true),
    COUNT(*) FILTER (WHERE is_correct = false)
  FROM public.predictions
  WHERE is_published = true AND is_live = false
  ON CONFLICT (period, sport, league, prediction_type)
  DO UPDATE SET
    total     = EXCLUDED.total,
    correct   = EXCLUDED.correct,
    incorrect = EXCLUDED.incorrect,
    updated_at = now();

  -- 2) Agrégat par ligue (all_time)
  INSERT INTO public.prediction_stats (period, sport, league, prediction_type, total, correct, incorrect)
  SELECT
    'all_time',
    'football',
    m.league,
    NULL,
    COUNT(*) FILTER (WHERE p.is_correct IS NOT NULL),
    COUNT(*) FILTER (WHERE p.is_correct = true),
    COUNT(*) FILTER (WHERE p.is_correct = false)
  FROM public.predictions p
  JOIN public.matches m ON m.id = p.match_id
  WHERE p.is_published = true AND p.is_live = false
  GROUP BY m.league
  ON CONFLICT (period, sport, league, prediction_type)
  DO UPDATE SET
    total     = EXCLUDED.total,
    correct   = EXCLUDED.correct,
    incorrect = EXCLUDED.incorrect,
    updated_at = now();

  -- 3) Agrégat par type de prono (all_time)
  INSERT INTO public.prediction_stats (period, sport, league, prediction_type, total, correct, incorrect)
  SELECT
    'all_time',
    'football',
    NULL,
    prediction_type,
    COUNT(*) FILTER (WHERE is_correct IS NOT NULL),
    COUNT(*) FILTER (WHERE is_correct = true),
    COUNT(*) FILTER (WHERE is_correct = false)
  FROM public.predictions
  WHERE is_published = true AND is_live = false
  GROUP BY prediction_type
  ON CONFLICT (period, sport, league, prediction_type)
  DO UPDATE SET
    total     = EXCLUDED.total,
    correct   = EXCLUDED.correct,
    incorrect = EXCLUDED.incorrect,
    updated_at = now();

  -- 4) Agrégat mensuel global
  INSERT INTO public.prediction_stats (period, sport, league, prediction_type, total, correct, incorrect)
  SELECT
    to_char(p.created_at, 'YYYY-MM'),
    'football',
    NULL,
    NULL,
    COUNT(*) FILTER (WHERE p.is_correct IS NOT NULL),
    COUNT(*) FILTER (WHERE p.is_correct = true),
    COUNT(*) FILTER (WHERE p.is_correct = false)
  FROM public.predictions p
  WHERE p.is_published = true AND p.is_live = false
  GROUP BY to_char(p.created_at, 'YYYY-MM')
  ON CONFLICT (period, sport, league, prediction_type)
  DO UPDATE SET
    total     = EXCLUDED.total,
    correct   = EXCLUDED.correct,
    incorrect = EXCLUDED.incorrect,
    updated_at = now();

END;
$$;

COMMENT ON FUNCTION public.recalculate_prediction_stats() IS
  'Recalcule les stats agrégées de réussite depuis predictions — appelée par evaluate-predictions';
