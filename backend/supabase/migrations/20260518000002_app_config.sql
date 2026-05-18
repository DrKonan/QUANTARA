-- Ajout des clés de versioning dans la table app_config existante (clé-valeur).
-- Utilisé par le mobile pour détecter les mises à jour disponibles / obligatoires.
INSERT INTO public.app_config (key, value, description) VALUES
  ('android_latest_version', '2.0.0',  'Dernière version Android publiée sur le Play Store'),
  ('android_min_version',    '1.0.0',  'Version Android minimale supportée (en dessous = MAJ forcée)'),
  ('ios_latest_version',     '2.0.0',  'Dernière version iOS publiée sur l''App Store'),
  ('ios_min_version',        '1.0.0',  'Version iOS minimale supportée (en dessous = MAJ forcée)'),
  ('android_store_url',      'https://play.google.com/store/apps/details?id=app.nakora.nakora', 'URL Play Store'),
  ('ios_store_url',          'https://apps.apple.com/app/nakora/id6741996547',                  'URL App Store')
ON CONFLICT (key) DO NOTHING;
