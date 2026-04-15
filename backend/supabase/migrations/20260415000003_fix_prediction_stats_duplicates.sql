-- ============================================================
-- QUANTARA — Migration 011 : Fix doublons prediction_stats
-- La contrainte UNIQUE (period, sport, league, prediction_type)
-- ne fonctionne pas avec les NULLs en PostgreSQL.
-- On la remplace par un index unique avec COALESCE et on
-- nettoie les doublons accumulés.
-- ============================================================

-- 1) Supprimer l'ancienne contrainte UNIQUE
ALTER TABLE public.prediction_stats
  DROP CONSTRAINT IF EXISTS prediction_stats_period_sport_league_prediction_type_key;

-- 2) Nettoyer TOUS les doublons — garder la ligne la plus récente (id max)
DELETE FROM public.prediction_stats
WHERE id NOT IN (
  SELECT MAX(id)
  FROM public.prediction_stats
  GROUP BY period, sport, COALESCE(league, '__null__'), COALESCE(prediction_type, '__null__')
);

-- 3) Créer un index unique qui gère les NULLs correctement
CREATE UNIQUE INDEX IF NOT EXISTS idx_prediction_stats_unique
  ON public.prediction_stats (
    period,
    sport,
    COALESCE(league, '__null__'),
    COALESCE(prediction_type, '__null__')
  );

-- 4) Mettre à jour la fonction RPC pour utiliser ON CONFLICT avec l'index
CREATE OR REPLACE FUNCTION public.recalculate_prediction_stats()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- ==========================================================
  -- Winrate = top_picks prematch + toutes les prédictions live
  -- ==========================================================

  -- Vide la table et recrée depuis les prédictions
  -- (plus fiable que les upserts avec NULLs)
  DELETE FROM public.prediction_stats;

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

-- 5) Recalculer les stats immédiatement (nettoie + reconstruit)
SELECT public.recalculate_prediction_stats();
