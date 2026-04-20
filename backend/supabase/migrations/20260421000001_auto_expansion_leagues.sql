-- ============================================================
-- QUANTARA — Migration : Auto-expansion des ligues (Tier 3)
-- Garantit 25+ matchs/jour en piochant dans des ligues
-- supplémentaires quand les ligues actives ne suffisent pas.
-- ============================================================

-- 1. Élargir la contrainte tier pour inclure tier 3
ALTER TABLE leagues_config DROP CONSTRAINT IF EXISTS leagues_config_tier_check;
ALTER TABLE leagues_config ADD CONSTRAINT leagues_config_tier_check CHECK (tier IN (1, 2, 3));

-- 2. Ajouter le seuil minimum dans app_config
INSERT INTO app_config (key, value, description)
VALUES ('min_daily_matches', '25', 'Nombre minimum de matchs/jour avant auto-expansion vers les ligues Tier 3')
ON CONFLICT (key) DO NOTHING;

-- 3. Ligues d'expansion Tier 3 (is_active = false)
--    Elles ne sont PAS fetchées par défaut ;
--    fetch-matches les utilise UNIQUEMENT quand le total du jour < min_daily_matches.
INSERT INTO leagues_config (league_id, league_name, country, tier, is_active, sport, category) VALUES
  -- Secondes divisions européennes
  (63,  'Ligue 2',            'France',         3, false, 'football', 'europe'),
  (79,  '2. Bundesliga',      'Germany',        3, false, 'football', 'europe'),
  (136, 'Serie B',            'Italy',          3, false, 'football', 'europe'),
  (141, 'Segunda División',   'Spain',          3, false, 'football', 'europe'),
  (332, 'Super League 1',     'Greece',         3, false, 'football', 'europe'),
  (119, 'Superligaen',        'Denmark',        3, false, 'football', 'europe'),
  (103, 'Eliteserien',        'Norway',         3, false, 'football', 'europe'),
  (188, 'Allsvenskan',        'Sweden',         3, false, 'football', 'europe'),
  (106, 'Ekstraklasa',        'Poland',         3, false, 'football', 'europe'),
  (345, 'First League',       'Czech-Republic', 3, false, 'football', 'europe'),
  -- Amériques
  (262, 'Liga MX',            'Mexico',         3, false, 'football', 'rest_of_world'),
  (128, 'Liga Profesional',   'Argentina',      3, false, 'football', 'south_america'),
  -- Asie
  (113, 'J1 League',          'Japan',          3, false, 'football', 'rest_of_world'),
  (292, 'K League 1',         'South-Korea',    3, false, 'football', 'rest_of_world')
ON CONFLICT (league_id) DO NOTHING;
