-- ============================================================
-- QUANTARA — Migration : Ajout league_country + tier 3 sur matches
-- Corrige l'ambiguïté des noms de ligue identiques (ex: Serie A
-- Italie vs Serie A Brésil) et autorise le tier 3 (expansion).
-- ============================================================

-- 1. Ajouter la colonne league_country
ALTER TABLE matches ADD COLUMN IF NOT EXISTS league_country text;

-- 2. Peupler les matchs existants à partir de leagues_config
UPDATE matches m
SET league_country = lc.country
FROM leagues_config lc
WHERE m.league_id = lc.league_id
  AND m.league_country IS NULL;

-- 3. Élargir la contrainte tier de matches pour inclure tier 3
ALTER TABLE matches DROP CONSTRAINT IF EXISTS matches_tier_check;
ALTER TABLE matches ADD CONSTRAINT matches_tier_check CHECK (tier IN (1, 2, 3));
