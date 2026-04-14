-- ============================================================
-- QUANTARA — Migration 004 : Extension des ligues
-- - Corrige league 233 (Egyptian Premier League, pas CI)
-- - Ajoute Conference League (C3) + championnats majeurs
-- - Ajoute colonne 'category' pour le classement par pays/compétition
-- ============================================================

-- 1) Ajoute la colonne category pour classer par contexte géographique
ALTER TABLE public.leagues_config
  ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'other';

COMMENT ON COLUMN public.leagues_config.category IS
  'Catégorie de classement : major_international, top5, europe, south_america, rest_of_world';

-- 2) Corrige league 233 : c'est la Premier League Égyptienne, pas la CI
UPDATE public.leagues_config SET league_name = 'Premier League', country = 'Egypt', is_active = true, category = 'rest_of_world' WHERE league_id = 233;

-- 3) Met à jour les catégories des ligues existantes
UPDATE public.leagues_config SET category = 'major_international' WHERE league_id IN (1, 2, 3, 4, 6);
UPDATE public.leagues_config SET category = 'top5' WHERE league_id IN (39, 61, 78, 135, 140);

-- 4) Ajoute les nouvelles ligues
INSERT INTO public.leagues_config (league_id, league_name, country, tier, sport, category, is_active) VALUES
  -- Compétitions internationales
  (848, 'UEFA Europa Conference League', 'World',    1, 'football', 'major_international', true),
  (13,  'CONMEBOL Libertadores',      'World',       1, 'football', 'major_international', true),

  -- Europe : championnats importants (Tier 1)
  (94,  'Primeira Liga',              'Portugal',    1, 'football', 'europe', true),
  (88,  'Eredivisie',                 'Netherlands', 1, 'football', 'europe', true),
  (144, 'Jupiler Pro League',         'Belgium',     1, 'football', 'europe', true),
  (203, 'Süper Lig',                  'Turkey',      1, 'football', 'europe', true),
  (179, 'Premiership',               'Scotland',    2, 'football', 'europe', true),

  -- Angleterre : Championship (Tier 2)
  (40,  'Championship',              'England',     2, 'football', 'top5', true),

  -- Amérique du Sud
  (71,  'Serie A',                    'Brazil',      1, 'football', 'south_america', true),

  -- Reste du monde
  (253, 'Major League Soccer',        'USA',         2, 'football', 'rest_of_world', true),
  (307, 'Saudi Pro League',           'Saudi-Arabia', 2, 'football', 'rest_of_world', true)

ON CONFLICT (league_id) DO UPDATE SET
  league_name = EXCLUDED.league_name,
  country     = EXCLUDED.country,
  tier        = EXCLUDED.tier,
  category    = EXCLUDED.category,
  is_active   = EXCLUDED.is_active;

-- 5) Met à jour current_season pour les nouvelles ligues
-- Europe suit le cycle 2025-2026, les autres 2026
UPDATE public.leagues_config SET current_season = 2025
  WHERE league_id IN (848, 94, 88, 144, 203, 179, 40) AND current_season IS NULL;
UPDATE public.leagues_config SET current_season = 2026
  WHERE league_id IN (13, 71, 253, 307) AND current_season IS NULL;
