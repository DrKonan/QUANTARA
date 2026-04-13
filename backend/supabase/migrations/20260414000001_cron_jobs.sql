-- Activer pg_cron et pg_net
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
GRANT USAGE ON SCHEMA cron TO postgres;

-- fetch-matches : tous les jours a 6h UTC
SELECT cron.schedule(
  'fetch-matches-daily',
  '0 6 * * *',
  $$
  SELECT net.http_post(
    url := 'https://epiaxzyzrclebutxvbgp.supabase.co/functions/v1/fetch-matches',
    headers := jsonb_build_object(
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwaWF4enl6cmNsZWJ1dHh2YmdwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxMDUyNjEsImV4cCI6MjA5MTY4MTI2MX0.fJ8OvlvzJS-WAbZ1BJHSKy1NhjDoiL3-fPAn-I_yCAc',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);

-- fetch-lineups : toutes les 10 minutes
SELECT cron.schedule(
  'fetch-lineups-10min',
  '*/10 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://epiaxzyzrclebutxvbgp.supabase.co/functions/v1/fetch-lineups',
    headers := jsonb_build_object(
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwaWF4enl6cmNsZWJ1dHh2YmdwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxMDUyNjEsImV4cCI6MjA5MTY4MTI2MX0.fJ8OvlvzJS-WAbZ1BJHSKy1NhjDoiL3-fPAn-I_yCAc',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);

-- predict-live-t1 : toutes les 15 minutes
SELECT cron.schedule(
  'predict-live-t1-15min',
  '*/15 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://epiaxzyzrclebutxvbgp.supabase.co/functions/v1/predict-live-t1',
    headers := jsonb_build_object(
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwaWF4enl6cmNsZWJ1dHh2YmdwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxMDUyNjEsImV4cCI6MjA5MTY4MTI2MX0.fJ8OvlvzJS-WAbZ1BJHSKy1NhjDoiL3-fPAn-I_yCAc',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);

-- predict-live-t2 : toutes les 5 minutes
SELECT cron.schedule(
  'predict-live-t2-5min',
  '*/5 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://epiaxzyzrclebutxvbgp.supabase.co/functions/v1/predict-live-t2',
    headers := jsonb_build_object(
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwaWF4enl6cmNsZWJ1dHh2YmdwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxMDUyNjEsImV4cCI6MjA5MTY4MTI2MX0.fJ8OvlvzJS-WAbZ1BJHSKy1NhjDoiL3-fPAn-I_yCAc',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);

-- evaluate-predictions : toutes les 30 minutes
SELECT cron.schedule(
  'evaluate-predictions-30min',
  '*/30 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://epiaxzyzrclebutxvbgp.supabase.co/functions/v1/evaluate-predictions',
    headers := jsonb_build_object(
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwaWF4enl6cmNsZWJ1dHh2YmdwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxMDUyNjEsImV4cCI6MjA5MTY4MTI2MX0.fJ8OvlvzJS-WAbZ1BJHSKy1NhjDoiL3-fPAn-I_yCAc',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);
-- Activer pg_cron et pg_net
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
GRANT USAGE ON SCHEMA cron TO postgres;

-- fetch-matches : tous les jours à 6h UTC
SELECT cron.schedule(
  'fetch-matches-daily',
  '0 6 * * *',
  $$
  SELECT net.http_post(
    url := 'https://epiaxzyzrclebutxvbgp.supabase.co/functions/v1/fetch-matches',
    headers := jsonb_build_object(
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwaWF4enl6cmNsZWJ1dHh2YmdwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxMDUyNjEsImV4cCI6MjA5MTY4MTI2MX0.fJ8OvlvzJS-WAbZ1BJHSKy1NhjDoiL3-fPAn-I_yCAc',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);

-- fetch-lineups : toutes les 10 minutes
SELECT cron.schedule(
  'fetch-lineups-10min',
  '*/10 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://epiaxzyzrclebutxvbgp.supabase.co/functions/v1/fetch-lineups',
    headers := jsonb_build_object(
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwaWF4enl6cmNsZWJ1dHh2YmdwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxMDUyNjEsImV4cCI6MjA5MTY4MTI2MX0.fJ8OvlvzJS-WAbZ1BJHSKy1NhjDoiL3-fPAn-I_yCAc',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);

-- predict-live-t1 : toutes les 15 minutes
SELECT cron.schedule(
  'predict-live-t1-15min',
  '*/15 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://epiaxzyzrclebutxvbgp.supabase.co/functions/v1/predict-live-t1',
    headers := jsonb_build_object(
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwaWF4enl6cmNsZWJ1dHh2YmdwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxMDUyNjEsImV4cCI6MjA5MTY4MTI2MX0.fJ8OvlvzJS-WAbZ1BJHSKy1NhjDoiL3-fPAn-I_yCAc',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);

-- predict-live-t2 : toutes les 5 minutes
SELECT cron.schedule(
  'predict-live-t2-5min',
  '*/5 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://epiaxzyzrclebutxvbgp.supabase.co/functions/v1/predict-live-t2',
    headers := jsonb_build_object(
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwaWF4enl6cmNsZWJ1dHh2YmdwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxMDUyNjEsImV4cCI6MjA5MTY4MTI2MX0.fJ8OvlvzJS-WAbZ1BJHSKy1NhjDoiL3-fPAn-I_yCAc',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);

-- evaluate-predictions : toutes les 30 minutes
SELECT cron.schedule(
  'evaluate-predictions-30min',
  '*/30 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://epiaxzyzrclebutxvbgp.supabase.co/functions/v1/evaluate-predictions',
    headers := jsonb_build_object(
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwaWF4enl6cmNsZWJ1dHh2YmdwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxMDUyNjEsImV4cCI6MjA5MTY4MTI2MX0.fJ8OvlvzJS-WAbZ1BJHSKy1NhjDoiL3-fPAn-I_yCAc',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);
