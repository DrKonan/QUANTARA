-- ============================================================
-- Migration : Fix Côte d'Ivoire phone numbers in profiles
--
-- Contexte :
--   Côte d'Ivoire (post-réforme 2021) : les numéros locaux sont
--   à 10 chiffres commençant par 0 (01, 05, 07).
--   Le 0 fait partie du numéro abonné — pas un indicatif national.
--   E.164 correct : +225 0707XXXXXX = +2250707XXXXXX
--
--   Bug précédent : _buildFullPhone() strippait le 0 initial,
--   stockant +225707XXXXXX (9 chiffres après indicatif) au lieu
--   de +2250707XXXXXX (10 chiffres après indicatif).
--
-- Règle de détection des numéros à corriger :
--   - commencent par +225
--   - ont exactement 12 caractères (+ + 225 + 8 chiffres) [WRONG]
--   OU 13 caractères (+ + 225 + 9 chiffres) [WRONG]
--   - le chiffre suivant +225 est 1, 5 ou 7 (préfixes CI : 01, 05, 07)
--
-- NB: on cible uniquement les numéros avec 9 chiffres après +225
--     (longueur totale = 13), pas ceux déjà corrects (14 chars).
-- ============================================================

UPDATE public.users
SET phone = '+2250' || substring(phone FROM 5)
WHERE phone ~ '^\+225[157][0-9]{8}$';
-- Explication du regex :
--   ^\+225   → commence par +225
--   [157]    → 1er chiffre = 1, 5 ou 7 (préfixes CI sans le 0)
--   [0-9]{8} → 8 chiffres restants
--   $        → fin de chaîne → total: +225 + 9 chiffres = 13 chars

-- Vérification post-migration (optionnelle, ne bloque pas) :
-- SELECT count(*) FROM public.users WHERE phone ~ '^\+225[157][0-9]{8}$';
-- → Doit retourner 0
