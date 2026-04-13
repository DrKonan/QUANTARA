-- ============================================================
-- QUANTARA — Migration 001 : Schéma initial
-- ============================================================

-- Extension UUID (disponible par défaut sur Supabase)
create extension if not exists "uuid-ossp";

-- ----------------------------------------------------------------
-- TABLE : users
-- Extension de auth.users fourni par Supabase Auth.
-- ----------------------------------------------------------------
create table if not exists public.users (
  id              uuid primary key references auth.users(id) on delete cascade,
  username        text,
  avatar_url      text,
  phone           text unique,                        -- numéro de téléphone validé OTP
  plan            text not null default 'free'        -- 'free' | 'premium'
                    check (plan in ('free', 'premium')),
  trial_used      boolean not null default false,     -- essai 3 jours consommé
  trial_ends_at   timestamptz,
  device_hash     text,                               -- fingerprint anti-abus
  created_at      timestamptz not null default now()
);

comment on table public.users is 'Profils utilisateurs — extension de auth.users';

-- ----------------------------------------------------------------
-- TABLE : matches
-- Matchs récupérés depuis API-Football.
-- ----------------------------------------------------------------
create table if not exists public.matches (
  id              bigserial primary key,
  external_id     text not null unique,               -- ID fixture API-Football
  sport           text not null default 'football'
                    check (sport in ('football', 'hockey', 'basketball')),
  home_team       text not null,
  away_team       text not null,
  home_team_id    integer,                            -- ID équipe API-Football
  away_team_id    integer,
  league          text not null,
  league_id       integer,
  season          integer,
  tier            integer not null default 2          -- 1 = grandes ligues, 2 = autres
                    check (tier in (1, 2)),
  match_date      timestamptz not null,
  status          text not null default 'scheduled'
                    check (status in ('scheduled', 'live', 'finished', 'cancelled')),
  home_score      integer,
  away_score      integer,
  lineups_ready   boolean not null default false,     -- compositions officielles reçues
  raw_stats       jsonb,                              -- stats brutes API-Football (cache)
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table public.matches is 'Matchs sportifs récupérés via API-Football';

-- ----------------------------------------------------------------
-- TABLE : team_elo
-- ELO rating calculé et maintenu par équipe.
-- ----------------------------------------------------------------
create table if not exists public.team_elo (
  id              bigserial primary key,
  team_id         integer not null,                   -- ID équipe API-Football
  team_name       text not null,
  sport           text not null default 'football',
  elo             numeric(8,2) not null default 1500,
  matches_played  integer not null default 0,
  updated_at      timestamptz not null default now(),
  unique (team_id, sport)
);

comment on table public.team_elo is 'ELO Rating par équipe — mis à jour après chaque match';

-- ----------------------------------------------------------------
-- TABLE : predictions
-- Pronos calculés par le moteur d'IA.
-- ----------------------------------------------------------------
create table if not exists public.predictions (
  id                bigserial primary key,
  match_id          bigint not null references public.matches(id) on delete cascade,
  prediction_type   text not null
                      check (prediction_type in (
                        'result', 'btts', 'over_under', 'handicap',
                        'corners', 'cards', 'halftime'
                      )),
  prediction        text not null,                  -- ex: 'home_win', 'yes', 'over_2.5'
  confidence        numeric(4,3) not null           -- 0.000 à 1.000
                      check (confidence >= 0 and confidence <= 1),
  confidence_label  text not null                   -- 'elevated' | 'high' | 'excellence'
                      check (confidence_label in ('elevated', 'high', 'excellence')),
  is_premium        boolean not null default false,
  is_live           boolean not null default false,
  analysis_text     text,                           -- texte généré par GPT-4o
  score_breakdown   jsonb,                          -- détail des indicateurs (debug/transparence)
  is_correct        boolean,                        -- null = match non terminé
  is_published      boolean not null default true,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

comment on table public.predictions is 'Pronos publiés par le moteur de prédiction';

-- ----------------------------------------------------------------
-- TABLE : subscriptions
-- Abonnements utilisateurs via CinetPay.
-- ----------------------------------------------------------------
create table if not exists public.subscriptions (
  id              bigserial primary key,
  user_id         uuid not null references public.users(id) on delete cascade,
  plan            text not null
                    check (plan in ('weekly', 'monthly', 'yearly')),
  status          text not null default 'active'
                    check (status in ('active', 'cancelled', 'expired', 'pending')),
  start_date      timestamptz not null default now(),
  end_date        timestamptz not null,
  payment_ref     text,                             -- référence de transaction CinetPay
  amount          integer,                          -- montant en FCFA
  currency        text not null default 'XOF',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table public.subscriptions is 'Abonnements premium — paiement via CinetPay';

-- ----------------------------------------------------------------
-- TABLE : prediction_stats
-- Statistiques agrégées de performance (mise à jour après chaque évaluation).
-- ----------------------------------------------------------------
create table if not exists public.prediction_stats (
  id              bigserial primary key,
  period          text not null,                    -- 'all_time' | 'YYYY-MM' (mensuel)
  sport           text not null default 'football',
  league          text,                             -- null = toutes ligues confondues
  prediction_type text,                             -- null = tous types confondus
  total           integer not null default 0,
  correct         integer not null default 0,
  incorrect       integer not null default 0,
  win_rate        numeric(5,4),                     -- calculé : correct / total
  updated_at      timestamptz not null default now(),
  unique (period, sport, league, prediction_type)
);

comment on table public.prediction_stats is 'Stats agrégées de réussite des pronos';

-- ----------------------------------------------------------------
-- TABLE : push_tokens
-- Tokens FCM/APNs des appareils pour les notifications push.
-- ----------------------------------------------------------------
create table if not exists public.push_tokens (
  id              bigserial primary key,
  user_id         uuid not null references public.users(id) on delete cascade,
  token           text not null unique,
  platform        text not null check (platform in ('ios', 'android')),
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table public.push_tokens is 'Tokens push FCM/APNs par appareil utilisateur';
