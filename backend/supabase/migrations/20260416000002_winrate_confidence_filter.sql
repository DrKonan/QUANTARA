-- ============================================================
-- QUANTARA — Migration 014 : Winrate = confiance >= 75% uniquement
-- Seuls les pronos avec confidence >= 0.75 comptent dans le
-- winrate public. Les pronos < 75% restent visibles en admin
-- mais n'impactent pas les stats affichées aux utilisateurs.
-- ============================================================

CREATE OR REPLACE FUNCTION public.recalculate_prediction_stats()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- ==========================================================
  -- Winrate = pronos publiés avec confiance >= 75%
  --   • prematch : top_picks uniquement
  --   • live : toutes les prédictions live
  -- ==========================================================

  TRUNCATE public.prediction_stats;

  -- 1) Agrégat global (all_time)
  INSERT INTO public.prediction_stats (period, sport, league, prediction_type, total, correct, incorrect)
  SELECT
    'all_time', 'football', NULL, NULL,
    COUNT(*) FILTER (WHERE is_correct IS NOT NULL),
    COUNT(*) FILTER (WHERE is_correct = true),
    COUNT(*) FILTER (WHERE is_correct = false)
  FROM public.predictions
  WHERE is_published = true
    AND confidence >= 0.75
    AND ((is_live = false AND is_top_pick = true) OR is_live = true);

  -- 2) Agrégat par ligue (all_time)
  INSERT INTO public.prediction_stats (period, sport, league, prediction_type, total, correct, incorrect)
  SELECT
    'all_time', 'football', m.league, NULL,
    COUNT(*) FILTER (WHERE p.is_correct IS NOT NULL),
    COUNT(*) FILTER (WHERE p.is_correct = true),
    COUNT(*) FILTER (WHERE p.is_correct = false)
  FROM public.predictions p
  JOIN public.matches m ON m.id = p.match_id
  WHERE p.is_published = true
    AND p.confidence >= 0.75
    AND ((p.is_live = false AND p.is_top_pick = true) OR p.is_live = true)
  GROUP BY m.league;

  -- 3) Agrégat par type de prono (all_time)
  INSERT INTO public.prediction_stats (period, sport, league, prediction_type, total, correct, incorrect)
  SELECT
    'all_time', 'football', NULL, prediction_type,
    COUNT(*) FILTER (WHERE is_correct IS NOT NULL),
    COUNT(*) FILTER (WHERE is_correct = true),
    COUNT(*) FILTER (WHERE is_correct = false)
  FROM public.predictions
  WHERE is_published = true
    AND confidence >= 0.75
    AND ((is_live = false AND is_top_pick = true) OR is_live = true)
  GROUP BY prediction_type;

  -- 4) Agrégat mensuel global
  INSERT INTO public.prediction_stats (period, sport, league, prediction_type, total, correct, incorrect)
  SELECT
    to_char(p.created_at, 'YYYY-MM'), 'football', NULL, NULL,
    COUNT(*) FILTER (WHERE p.is_correct IS NOT NULL),
    COUNT(*) FILTER (WHERE p.is_correct = true),
    COUNT(*) FILTER (WHERE p.is_correct = false)
  FROM public.predictions p
  WHERE p.is_published = true
    AND p.confidence >= 0.75
    AND ((p.is_live = false AND p.is_top_pick = true) OR p.is_live = true)
  GROUP BY to_char(p.created_at, 'YYYY-MM');

END;
$$;

-- Recalculer immédiatement
SELECT public.recalculate_prediction_stats();
