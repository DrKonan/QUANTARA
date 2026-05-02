-- ============================================================
-- NAKORA — Migration : Exclure les jambes de combos du winrate
--
-- Règle : une prédiction qui est une jambe d'un combiné
-- ne compte PAS dans le winrate officiel.
-- Raison : les combos sont un produit "fun" accessoire — leur
-- résultat ne doit pas polluer les statistiques de performance
-- de l'IA sur les paris individuels.
--
-- Exception : si une prédiction a été publiée indépendamment
-- comme top pick sur un match qui n'est dans AUCUN combo, elle
-- compte. En pratique, le filtre exclut simplement tous les IDs
-- qui apparaissent dans le JSONB legs de combo_predictions.
-- ============================================================

CREATE OR REPLACE FUNCTION public.recalculate_prediction_stats()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- ==========================================================
  -- Winrate officiel Nakora :
  --   • Prematch top picks (confidence >= 0.75, is_top_pick = true)
  --   • Toutes les prédictions live
  --   • Excluant les prédictions utilisées comme jambes de combos
  -- ==========================================================

  DELETE FROM public.prediction_stats;

  -- CTE : IDs de toutes les prédictions utilisées comme jambe de combo
  -- (on les exclut du winrate, ils ont leur propre suivi dans combo_predictions)
  WITH combo_leg_ids AS (
    SELECT DISTINCT (leg->>'prediction_id')::bigint AS prediction_id
    FROM public.combo_predictions
    CROSS JOIN LATERAL jsonb_array_elements(legs) AS leg
    WHERE leg->>'prediction_id' IS NOT NULL
  )

  -- 1) Agrégat global (all_time)
  INSERT INTO public.prediction_stats (period, sport, league, prediction_type, total, correct, incorrect)
  SELECT
    'all_time', 'football', NULL, NULL,
    COUNT(*) FILTER (WHERE p.is_correct IS NOT NULL),
    COUNT(*) FILTER (WHERE p.is_correct = true),
    COUNT(*) FILTER (WHERE p.is_correct = false)
  FROM public.predictions p
  WHERE p.is_published = true
    AND p.confidence >= 0.75
    AND ((p.is_live = false AND p.is_top_pick = true) OR p.is_live = true)
    AND p.id NOT IN (SELECT prediction_id FROM combo_leg_ids);

  -- 2) Agrégat par ligue (all_time)
  WITH combo_leg_ids AS (
    SELECT DISTINCT (leg->>'prediction_id')::bigint AS prediction_id
    FROM public.combo_predictions
    CROSS JOIN LATERAL jsonb_array_elements(legs) AS leg
    WHERE leg->>'prediction_id' IS NOT NULL
  )
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
    AND p.id NOT IN (SELECT prediction_id FROM combo_leg_ids)
  GROUP BY m.league;

  -- 3) Agrégat par type de prono (all_time)
  WITH combo_leg_ids AS (
    SELECT DISTINCT (leg->>'prediction_id')::bigint AS prediction_id
    FROM public.combo_predictions
    CROSS JOIN LATERAL jsonb_array_elements(legs) AS leg
    WHERE leg->>'prediction_id' IS NOT NULL
  )
  INSERT INTO public.prediction_stats (period, sport, league, prediction_type, total, correct, incorrect)
  SELECT
    'all_time', 'football', NULL, p.prediction_type,
    COUNT(*) FILTER (WHERE p.is_correct IS NOT NULL),
    COUNT(*) FILTER (WHERE p.is_correct = true),
    COUNT(*) FILTER (WHERE p.is_correct = false)
  FROM public.predictions p
  WHERE p.is_published = true
    AND p.confidence >= 0.75
    AND ((p.is_live = false AND p.is_top_pick = true) OR p.is_live = true)
    AND p.id NOT IN (SELECT prediction_id FROM combo_leg_ids)
  GROUP BY p.prediction_type;

  -- 4) Agrégat mensuel global
  WITH combo_leg_ids AS (
    SELECT DISTINCT (leg->>'prediction_id')::bigint AS prediction_id
    FROM public.combo_predictions
    CROSS JOIN LATERAL jsonb_array_elements(legs) AS leg
    WHERE leg->>'prediction_id' IS NOT NULL
  )
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
    AND p.id NOT IN (SELECT prediction_id FROM combo_leg_ids)
  GROUP BY to_char(p.created_at, 'YYYY-MM');

END;
$$;

COMMENT ON FUNCTION public.recalculate_prediction_stats() IS
  'Winrate officiel : top picks prematch (conf>=0.75) + live, hors jambes de combos';

-- Recalculer immédiatement pour nettoyer les stats existantes
SELECT public.recalculate_prediction_stats();
