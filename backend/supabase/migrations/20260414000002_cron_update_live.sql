-- ============================================================
-- QUANTARA  Migration 005 : Cron update-live-scores
-- Rafraîchit les scores et statuts toutes les 2 minutes.
-- ============================================================

SELECT cron.schedule(
  'update-live-scores-2min',
  '*/2 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://epiaxzyzrclebutxvbgp.supabase.co/functions/v1/update-live-scores',
    headers := jsonb_build_object(
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwaWF4enl6cmNsZWJ1dHh2YmdwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxMDUyNjEsImV4cCI6MjA5MTY4MTI2MX0.fJ8OvlvzJS-WAbZ1BJHSKy1NhjDoiL3-fPAn-I_yCAc',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);