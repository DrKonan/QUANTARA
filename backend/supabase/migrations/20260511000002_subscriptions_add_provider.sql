-- Add provider column to subscriptions (was missing, caused insert to fail)
ALTER TABLE public.subscriptions
  ADD COLUMN IF NOT EXISTS provider text DEFAULT 'paydunya';
