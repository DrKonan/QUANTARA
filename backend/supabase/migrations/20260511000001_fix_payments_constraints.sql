-- ============================================================
-- Fix payments & subscriptions tables for PayDunya integration
-- Old schema had: provider in ('pawapay','wave'), plan in ('weekly','monthly','yearly')
-- New schema needs: provider='paydunya', plan in ('starter','pro','vip')
-- ============================================================

-- 1. Drop old constraints on payments
ALTER TABLE public.payments
  DROP CONSTRAINT IF EXISTS payments_provider_check,
  DROP CONSTRAINT IF EXISTS payments_plan_check;

-- 2. Add new constraints
ALTER TABLE public.payments
  ADD CONSTRAINT payments_provider_check
    CHECK (provider IN ('pawapay', 'wave', 'paydunya', 'cinetpay')),
  ADD CONSTRAINT payments_plan_check
    CHECK (plan IN ('weekly', 'monthly', 'yearly', 'starter', 'pro', 'vip'));

-- 3. Add payment_method column if missing (used by create-payment)
ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS payment_method text,
  ADD COLUMN IF NOT EXISTS phone text;

-- 4. Drop old constraints on subscriptions plan column if needed
ALTER TABLE public.subscriptions
  DROP CONSTRAINT IF EXISTS subscriptions_plan_check;

ALTER TABLE public.subscriptions
  ADD CONSTRAINT subscriptions_plan_check
    CHECK (plan IN ('weekly', 'monthly', 'yearly', 'starter', 'pro', 'vip'));

-- 5. Add plan column to users if missing
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS plan text DEFAULT 'free';
