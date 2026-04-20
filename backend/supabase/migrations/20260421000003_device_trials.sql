-- Device trial tracking: prevents trial abuse by linking installation IDs to accounts
CREATE TABLE IF NOT EXISTS public.device_trials (
  installation_id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  phone TEXT,
  email TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS: only the service role can read/write (called from Edge Functions or service-key client)
ALTER TABLE public.device_trials ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to INSERT their own device trial
CREATE POLICY "Users can register their device trial"
  ON public.device_trials FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Allow authenticated users to SELECT to check if their installation_id exists
CREATE POLICY "Users can check device trials"
  ON public.device_trials FOR SELECT
  TO authenticated
  USING (true);

COMMENT ON TABLE public.device_trials IS 'Tracks installation IDs to prevent repeated trial abuse on the same device.';
