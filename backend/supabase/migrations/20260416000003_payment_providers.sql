-- ================================================================
-- QUANTARA — Migration : Support multi-provider (PawaPay + Wave)
-- ================================================================

-- 1. Add provider & correspondent columns to subscriptions
alter table public.subscriptions
  add column if not exists provider text default 'cinetpay'
    check (provider in ('cinetpay', 'pawapay', 'wave')),
  add column if not exists correspondent text;

comment on column public.subscriptions.provider is 'Payment provider: pawapay, wave, or cinetpay (legacy)';
comment on column public.subscriptions.correspondent is 'MMO correspondent code (e.g. MTN_MOMO_CIV, ORANGE_CIV)';

-- 2. Create payments table for tracking individual payment attempts
create table if not exists public.payments (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.users(id) on delete cascade,
  provider        text not null check (provider in ('pawapay', 'wave')),
  external_id     text not null,        -- PawaPay depositId or Wave checkout session id
  plan            text not null check (plan in ('weekly', 'monthly', 'yearly')),
  amount          integer not null,     -- amount in XOF (no decimals)
  currency        text not null default 'XOF',
  correspondent   text,                 -- MTN_MOMO_CIV, ORANGE_CIV, etc. (null for Wave)
  status          text not null default 'pending'
                    check (status in ('pending', 'submitted', 'completed', 'failed', 'refunded')),
  metadata        jsonb,                -- raw callback payload for debugging
  created_at      timestamptz not null default now(),
  completed_at    timestamptz,
  updated_at      timestamptz not null default now()
);

comment on table public.payments is 'Individual payment attempts via PawaPay or Wave';

-- Indexes
create index if not exists idx_payments_user on public.payments(user_id);
create index if not exists idx_payments_external on public.payments(external_id);
create index if not exists idx_payments_status on public.payments(status);

-- RLS
alter table public.payments enable row level security;

-- Users can read their own payments
create policy "Users read own payments"
  on public.payments for select
  using (auth.uid() = user_id);

-- Only service role can insert/update (via Edge Functions)
create policy "Service role manages payments"
  on public.payments for all
  using (auth.role() = 'service_role');

-- 3. Plan amounts config (for validation)
create table if not exists public.plan_pricing (
  plan            text primary key check (plan in ('weekly', 'monthly', 'yearly')),
  amount_xof      integer not null,
  duration_days   integer not null,
  label           text not null
);

insert into public.plan_pricing (plan, amount_xof, duration_days, label) values
  ('weekly',  990,   7,   'Hebdomadaire'),
  ('monthly', 2990,  30,  'Mensuel'),
  ('yearly',  24990, 365, 'Annuel')
on conflict (plan) do nothing;
