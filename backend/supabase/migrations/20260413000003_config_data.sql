-- ============================================================
-- QUANTARA — Migration 003 : Données initiales & config
-- ============================================================

-- ----------------------------------------------------------------
-- Ligues Tier 1 — grandes compétitions
-- Utilisé par les Edge Functions pour déterminer le niveau d'analyse.
-- ----------------------------------------------------------------
create table if not exists public.leagues_config (
  id              bigserial primary key,
  league_id       integer not null unique,          -- ID API-Football
  league_name     text not null,
  country         text,
  tier            integer not null default 2
                    check (tier in (1, 2)),
  is_active       boolean not null default true,
  sport           text not null default 'football',
  created_at      timestamptz not null default now()
);

comment on table public.leagues_config is 'Configuration des ligues (tier, activation)';

-- Politique RLS : lecture publique, écriture service uniquement
alter table public.leagues_config enable row level security;

create policy "leagues_config_select_all"
  on public.leagues_config for select
  using (true);

-- Données initiales — Tier 1
insert into public.leagues_config (league_id, league_name, country, tier, sport) values
  (39,  'Premier League',       'England',      1, 'football'),
  (140, 'La Liga',              'Spain',        1, 'football'),
  (78,  'Bundesliga',           'Germany',      1, 'football'),
  (135, 'Serie A',              'Italy',        1, 'football'),
  (61,  'Ligue 1',              'France',       1, 'football'),
  (2,   'UEFA Champions League','World',        1, 'football'),
  (3,   'UEFA Europa League',   'World',        1, 'football'),
  (1,   'Coupe du Monde',       'World',        1, 'football'),
  (4,   'Euro Championship',    'Europe',       1, 'football'),
  (6,   'CAN',                  'Africa',       1, 'football'),
  (233, 'Premier League',        'Egypt',        1, 'football')  -- Egyptian Premier League
on conflict (league_id) do nothing;

-- ----------------------------------------------------------------
-- TABLE : app_config
-- Configuration dynamique de l'application (modifiable via admin).
-- ----------------------------------------------------------------
create table if not exists public.app_config (
  key             text primary key,
  value           text not null,
  description     text,
  updated_at      timestamptz not null default now()
);

comment on table public.app_config is 'Configuration dynamique — modifiable via back-office';

alter table public.app_config enable row level security;

create policy "app_config_select_all"
  on public.app_config for select
  using (true);

-- Valeurs par défaut
insert into public.app_config (key, value, description) values
  ('publish_threshold',        '0.75',  'Seuil de confiance minimum pour publier un prono'),
  ('maintenance_mode',         'false', 'Si true, l''app affiche un écran de maintenance'),
  ('trial_duration_days',      '3',     'Durée de l''essai gratuit en jours'),
  ('max_predictions_per_match','5',     'Nombre max de pronos publiés par match'),
  ('openai_model',             'gpt-4o','Modèle OpenAI pour la génération de texte'),
  ('live_analysis_interval',   '15',    'Intervalle en minutes pour l''analyse live Tier 1')
on conflict (key) do nothing;

create or replace trigger trg_app_config_updated_at
  before update on public.app_config
  for each row execute function public.set_updated_at();
