-- ============================================================
-- NAKORA — Migration : Activation des ligues d'été (Mai–Septembre)
--
-- Les championnats européens majeurs finissent en mai.
-- On active les championnats encore en jeu dans le reste du monde
-- pour maintenir 30+ matchs/jour jusqu'en septembre.
--
-- Coût API : ZÉRO. Le fetch se fait par date (/fixtures?date=X),
-- les ligues_config ne servent qu'à filtrer localement.
-- ============================================================

-- 1. Permettre tier 4 dans la contrainte (tier 4 = expansion globale)
ALTER TABLE leagues_config DROP CONSTRAINT IF EXISTS leagues_config_tier_check;
ALTER TABLE leagues_config ADD CONSTRAINT leagues_config_tier_check
  CHECK (tier IN (1, 2, 3, 4));

-- 2. Activer et promouvoir les ligues déjà en DB mais inactives
--    Toutes actives mai–novembre : zéro coût quand elles sont off-season
UPDATE public.leagues_config
SET is_active = true, tier = 2
WHERE league_id IN (
  103,  -- Eliteserien (Norway)          Avr–Nov  🇳🇴
  113,  -- J1 League (Japan)             Fév–Nov  🇯🇵 ~10 matchs/sem
  128,  -- Liga Profesional (Argentina)  Annuel   🇦🇷
  188,  -- Allsvenskan (Sweden)          Avr–Nov  🇸🇪
  262,  -- Liga MX (Mexico)              Clan.→Jun / Apert.→Déc  🇲🇽
  292   -- K League 1 (South-Korea)      Mar–Nov  🇰🇷
);

-- Activer aussi les secondes divisions européennes encore en cours
UPDATE public.leagues_config
SET is_active = true
WHERE league_id IN (
  106,  -- Ekstraklasa (Poland)          Jul–Mai (encore en jeu en mai)
  119,  -- Superligaen (Denmark)         Jul–Jun (playoffs en mai/juin)
  345,  -- Czech First League            Jul–Mai (playoffs)
  332   -- Super League 1 (Greece)       Aoû–Mai (playoffs)
);

-- 3. Nouvelles ligues à ajouter (actives Mai–Septembre)
INSERT INTO public.leagues_config (league_id, league_name, country, tier, sport, category, is_active, current_season)
VALUES
  -- Compétitions CONMEBOL (matchdays toute l'année)
  (11,  'Copa Sudamericana',        'World',         1, 'football', 'major_international', true, 2025),

  -- Asie : ligues en pleine saison
  (169, 'Chinese Super League',     'China',         2, 'football', 'rest_of_world',       true, 2025),
  (323, 'Indian Super League',      'India',         3, 'football', 'rest_of_world',       false, 2025),

  -- Amériques : saisons actives
  (239, 'Liga BetPlay',             'Colombia',      2, 'football', 'south_america',       true, 2025),
  (265, 'Primera División',         'Chile',         2, 'football', 'south_america',       true, 2025),
  (268, 'Liga 1',                   'Peru',          2, 'football', 'south_america',       true, 2025),
  (256, 'Canadian Premier League',  'Canada',        2, 'football', 'rest_of_world',       true, 2025),
  (72,  'Serie B',                  'Brazil',        3, 'football', 'south_america',       false, 2025),

  -- Afrique : plusieurs championnats actifs de mai à novembre
  (200, 'CAF Champions League',     'World',         2, 'football', 'major_international', true, 2025),
  (384, 'Botola Pro',               'Morocco',       3, 'football', 'rest_of_world',       false, 2025),
  (301, 'NPFL',                     'Nigeria',       3, 'football', 'rest_of_world',       false, 2025)

ON CONFLICT (league_id) DO UPDATE SET
  league_name    = EXCLUDED.league_name,
  country        = EXCLUDED.country,
  tier           = EXCLUDED.tier,
  category       = EXCLUDED.category,
  is_active      = EXCLUDED.is_active,
  current_season = EXCLUDED.current_season;

-- 4. Augmenter le seuil minimum de matchs/jour (25 → 30)
--    Avec plus de ligues actives, viser 30 matchs/jour est raisonnable
UPDATE app_config
SET value = '30', description = 'Nombre minimum de matchs/jour avant auto-expansion vers les ligues Tier 3'
WHERE key = 'min_daily_matches';

-- 5. Ajouter une note de configuration pour référence
INSERT INTO app_config (key, value, description)
VALUES ('summer_mode_active_until', '2025-09-30', 'Date de fin du mode été (ligues alternatives prioritaires)')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
