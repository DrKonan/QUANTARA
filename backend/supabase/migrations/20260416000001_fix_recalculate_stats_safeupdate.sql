-- ============================================================
-- QUANTARA — Migration 013 : Fix pg_safeupdate pour recalculate_prediction_stats
-- DELETE sans WHERE est bloqué par pg_safeupdate.
-- On utilise TRUNCATE à la place (plus rapide et non bloqué).
-- ============================================================

CREATE OR REPLACE FUNCTION public.recalculate_prediction_stats()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- ==========================================================
  -- Winrate = top_picks prematch + toutes les prédictions live
  -- ==========================================================

  -- Vide la table (TRUNCATE n'est pas bloqué par pg_safeupdate)
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
    AND ((p.is_live = false AND p.is_top_pick = true) OR p.is_live = true)
  GROUP BY to_char(p.created_at, 'YYYY-MM');

END;
$$;

-- Recalculer immédiatement
SELECT public.recalculate_prediction_stats();
