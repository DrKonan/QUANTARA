-- ================================================================
-- Fix : Alignement schéma payments/subscriptions avec PayDunya
-- Les contraintes 'provider' excluaient 'paydunya', et les colonnes
-- payment_method/phone manquaient — causant des insertions silencieuses
-- qui échouaient et laissaient les utilisateurs sans abonnement.
-- ================================================================

-- 1. Fix payments.provider constraint
alter table public.payments
  drop constraint if exists payments_provider_check;

alter table public.payments
  add constraint payments_provider_check
    check (provider in ('cinetpay', 'pawapay', 'wave', 'paydunya'));

-- 2. Add missing columns to payments
alter table public.payments
  add column if not exists payment_method text,
  add column if not exists phone          text;

comment on column public.payments.payment_method is 'Operator slug (e.g. wave_sn, orange_ci, mtn_ci)';
comment on column public.payments.phone          is 'Full phone number in E.164 format';

-- 3. Fix subscriptions.provider constraint
alter table public.subscriptions
  drop constraint if exists subscriptions_provider_check;

alter table public.subscriptions
  add constraint subscriptions_provider_check
    check (provider in ('cinetpay', 'pawapay', 'wave', 'paydunya'));

-- Enable Realtime on payments (idempotent)
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'payments'
  ) then
    alter publication supabase_realtime add table public.payments;
  end if;
end $$;
