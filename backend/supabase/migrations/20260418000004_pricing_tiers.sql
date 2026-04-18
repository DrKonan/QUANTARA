-- ================================================================
-- QUANTARA — Migration : Nouveau modèle de tarification (4 niveaux)
-- Gratuit / Starter / Pro / VIP — seuil confiance relevé à 80%
-- ================================================================

-- 1. Drop old constraint, migrate legacy values, add new constraint
alter table public.users
  drop constraint if exists users_plan_check;

update public.users set plan = 'pro' where plan = 'premium';

alter table public.users
  add constraint users_plan_check
    check (plan in ('free', 'starter', 'pro', 'vip'));

comment on column public.users.plan is 'Subscription tier: free, starter, pro, or vip';

-- 2. Update subscriptions.plan constraint
alter table public.subscriptions
  drop constraint if exists subscriptions_plan_check;
alter table public.subscriptions
  add constraint subscriptions_plan_check
    check (plan in ('starter', 'pro', 'vip'));

-- 3. Update payments.plan constraint
alter table public.payments
  drop constraint if exists payments_plan_check;
alter table public.payments
  add constraint payments_plan_check
    check (plan in ('starter', 'pro', 'vip'));

-- 4. Replace plan_pricing data with new tiers
truncate public.plan_pricing;

alter table public.plan_pricing
  drop constraint if exists plan_pricing_plan_check;
alter table public.plan_pricing
  add constraint plan_pricing_plan_check
    check (plan in ('starter', 'pro', 'vip'));

-- Add new columns for tier features
alter table public.plan_pricing
  add column if not exists max_matches_per_day integer not null default -1,
  add column if not exists sports text not null default 'football',
  add column if not exists has_live boolean not null default false,
  add column if not exists has_combos boolean not null default false;

insert into public.plan_pricing (plan, amount_xof, duration_days, label, max_matches_per_day, sports, has_live, has_combos) values
  ('starter', 990,  30, 'Starter', 5,  'football',                    false, false),
  ('pro',     1990, 30, 'Pro',     15, 'football,basketball',         true,  false),
  ('vip',     3990, 30, 'VIP',     -1, 'football,basketball,hockey',  true,  true)
on conflict (plan) do update set
  amount_xof = excluded.amount_xof,
  duration_days = excluded.duration_days,
  label = excluded.label,
  max_matches_per_day = excluded.max_matches_per_day,
  sports = excluded.sports,
  has_live = excluded.has_live,
  has_combos = excluded.has_combos;

-- 5. Create user_daily_views table (for match quota tracking)
create table if not exists public.user_daily_views (
  id          bigserial primary key,
  user_id     uuid not null references public.users(id) on delete cascade,
  match_id    bigint not null references public.matches(id) on delete cascade,
  viewed_at   date not null default current_date,
  created_at  timestamptz not null default now(),
  unique (user_id, match_id, viewed_at)
);

comment on table public.user_daily_views is 'Tracks which matches a user viewed per day for quota enforcement';

create index if not exists idx_user_daily_views_user_date
  on public.user_daily_views(user_id, viewed_at);

-- RLS
alter table public.user_daily_views enable row level security;

create policy "Users read own views"
  on public.user_daily_views for select
  using (auth.uid() = user_id);

create policy "Users insert own views"
  on public.user_daily_views for insert
  with check (auth.uid() = user_id);
