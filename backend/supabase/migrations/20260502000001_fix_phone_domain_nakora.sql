-- ============================================================
-- NAKORA — Fix : domaine email téléphone quantara → nakora
-- Le mobile génère des emails `{numéro}@phone.nakora.app`.
-- L'ancien trigger filtrait `@phone.quantara.app`, ce qui
-- faisait stocker ces emails comme de vrais emails utilisateur.
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  trial_days integer;
  v_username text;
  v_phone    text;
  v_email    text;
BEGIN
  SELECT COALESCE(value::integer, 3)
    INTO trial_days
    FROM public.app_config
   WHERE key = 'trial_duration_days';
  IF trial_days IS NULL THEN
    trial_days := 3;
  END IF;

  v_username := COALESCE(NEW.raw_user_meta_data->>'username', 'Utilisateur');
  v_phone    := NEW.raw_user_meta_data->>'phone';
  v_email    := NULLIF(NEW.email, '');

  -- Ne stocke pas les emails auto-générés comme "vrai" email utilisateur
  IF v_email LIKE '%@phone.nakora.app' OR v_email LIKE '%@phone.quantara.app' THEN
    v_email := NULL;
  END IF;

  INSERT INTO public.users (id, username, phone, email, plan, trial_used, trial_ends_at)
  VALUES (
    NEW.id,
    v_username,
    v_phone,
    v_email,
    'free',
    true,
    NOW() + (trial_days || ' days')::interval
  )
  ON CONFLICT (id) DO UPDATE SET
    phone    = COALESCE(EXCLUDED.phone, public.users.phone),
    email    = COALESCE(EXCLUDED.email, public.users.email),
    username = CASE
                 WHEN EXCLUDED.username = 'Utilisateur' THEN public.users.username
                 ELSE COALESCE(EXCLUDED.username, public.users.username)
               END;

  RETURN NEW;
END;
$$;
