-- ============================================================
-- QUANTARA — Migration 007 : Activation automatique de l'essai
-- Corrige le trigger handle_new_user pour donner 3 jours
-- d'essai Premium à chaque nouvel inscrit.
-- Met aussi à jour les utilisateurs existants sans essai.
-- ============================================================

-- 1. Corrige le trigger pour activer l'essai 3 jours à l'inscription
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  trial_days integer;
BEGIN
  -- Récupère la durée de l'essai depuis la config (défaut 3 jours)
  SELECT COALESCE(value::integer, 3)
    INTO trial_days
    FROM public.app_config
   WHERE key = 'trial_duration_days';
  IF trial_days IS NULL THEN
    trial_days := 3;
  END IF;

  INSERT INTO public.users (id, username, avatar_url, phone, trial_used, trial_ends_at)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'username',
    NEW.raw_user_meta_data->>'avatar_url',
    NEW.phone,
    true,
    NOW() + (trial_days || ' days')::interval
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$;

-- 2. Active l'essai pour les utilisateurs existants qui n'en ont jamais eu
--    (trial_used = false et trial_ends_at IS NULL)
UPDATE public.users
SET trial_used = true,
    trial_ends_at = NOW() + INTERVAL '3 days'
WHERE trial_used = false
  AND trial_ends_at IS NULL
  AND plan = 'free';
