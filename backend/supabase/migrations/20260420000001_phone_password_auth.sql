-- ============================================================
-- QUANTARA — Migration : Auth par téléphone + mot de passe
-- Supprime le flow OTP. L'auth utilise maintenant email/password
-- sous le capot, avec un email dérivé du téléphone si aucun
-- email réel n'est fourni : {numéro}@phone.quantara.app
--
-- Le trigger crée le profil public.users à partir de
-- raw_user_meta_data (username, phone) au lieu de NEW.phone.
-- ============================================================

-- 1. Ajouter la colonne email (optionnelle) à public.users
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS email text;

-- 2. Rendre la colonne phone nullable (le trigger la remplit via metadata)
ALTER TABLE public.users
  ALTER COLUMN phone DROP NOT NULL;

-- 3. Nouveau trigger pour le flow email/password (pas d'OTP)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  trial_days integer;
  v_username text;
  v_phone    text;
  v_email    text;
BEGIN
  -- Durée de l'essai depuis la config (défaut 3 jours)
  SELECT COALESCE(value::integer, 3)
    INTO trial_days
    FROM public.app_config
   WHERE key = 'trial_duration_days';
  IF trial_days IS NULL THEN
    trial_days := 3;
  END IF;

  -- Récupère les données depuis raw_user_meta_data
  v_username := COALESCE(NEW.raw_user_meta_data->>'username', 'Utilisateur');
  v_phone    := NEW.raw_user_meta_data->>'phone';
  v_email    := NULLIF(NEW.email, '');

  -- Ne stocke pas les emails auto-générés (@phone.quantara.app) comme "vrai" email
  IF v_email LIKE '%@phone.quantara.app' THEN
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

-- 4. Recréer les triggers (inchangé)
DROP TRIGGER IF EXISTS trg_on_auth_user_created ON auth.users;
CREATE TRIGGER trg_on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

DROP TRIGGER IF EXISTS trg_on_auth_user_updated ON auth.users;
CREATE TRIGGER trg_on_auth_user_updated
  AFTER UPDATE ON auth.users
  FOR EACH ROW
  WHEN (OLD.raw_user_meta_data IS DISTINCT FROM NEW.raw_user_meta_data)
  EXECUTE FUNCTION public.handle_new_user();
