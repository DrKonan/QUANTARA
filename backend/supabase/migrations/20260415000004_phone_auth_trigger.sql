-- ============================================================
-- QUANTARA — Migration 012 : Auth téléphone + email
-- Améliore le trigger handle_new_user pour gérer :
--   • Inscription par OTP téléphone (flow principal mobile)
--   • Inscription par email (fallback)
--   • Mise à jour du phone/username si l'utilisateur existe déjà
-- ============================================================

-- Trigger amélioré : INSERT + UPDATE sur auth.users
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
    COALESCE(NEW.raw_user_meta_data->>'username', 'Utilisateur'),
    NEW.raw_user_meta_data->>'avatar_url',
    NEW.phone,
    true,
    NOW() + (trial_days || ' days')::interval
  )
  ON CONFLICT (id) DO UPDATE SET
    phone    = COALESCE(EXCLUDED.phone, public.users.phone),
    username = COALESCE(NULLIF(EXCLUDED.username, 'Utilisateur'), public.users.username);

  RETURN NEW;
END;
$$;

-- Trigger sur INSERT (nouvelle inscription)
DROP TRIGGER IF EXISTS trg_on_auth_user_created ON auth.users;
CREATE TRIGGER trg_on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Trigger sur UPDATE (confirmation OTP, ajout phone, etc.)
DROP TRIGGER IF EXISTS trg_on_auth_user_updated ON auth.users;
CREATE TRIGGER trg_on_auth_user_updated
  AFTER UPDATE ON auth.users
  FOR EACH ROW
  WHEN (OLD.phone IS DISTINCT FROM NEW.phone OR OLD.raw_user_meta_data IS DISTINCT FROM NEW.raw_user_meta_data)
  EXECUTE FUNCTION public.handle_new_user();
