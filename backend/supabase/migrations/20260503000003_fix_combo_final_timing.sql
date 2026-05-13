-- Fix combo cron timings:
--   day     : 7h UTC -> 9h UTC  (fetch-matches at 3h, predictions done by ~8h)
--   evening : 21h UTC -> 23h UTC (fetch-matches at 21h, predictions done by ~23h)

SELECT cron.unschedule('generate-combos-day');
SELECT cron.unschedule('generate-combos-evening');

-- Combo du jour : 9h UTC (matchs avant 22h UTC)
SELECT cron.schedule(
  'generate-combos-day',
  '0 9 * * *',
  $$
  SELECT net.http_post(
    url := 'https://epiaxzyzrclebutxvbgp.supabase.co/functions/v1/generate-combos',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwaWF4enl6cmNsZWJ1dHh2YmdwIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjEwNTI2MSwiZXhwIjoyMDkxNjgxMjYxfQ.uCJT4jgA--qwzeH8mDvxDMa8TmtBxAi68wS4huMPF-A'
    ),
    body := '{"slot":"day"}'::jsonb
  );
  $$
);

-- Combo du soir : 23h UTC (matchs a partir de 22h UTC)
SELECT cron.schedule(
  'generate-combos-evening',
  '0 23 * * *',
  $$
  SELECT net.http_post(
    url := 'https://epiaxzyzrclebutxvbgp.supabase.co/functions/v1/generate-combos',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwaWF4enl6cmNsZWJ1dHh2YmdwIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjEwNTI2MSwiZXhwIjoyMDkxNjgxMjYxfQ.uCJT4jgA--qwzeH8mDvxDMa8TmtBxAi68wS4huMPF-A'
    ),
    body := '{"slot":"evening"}'::jsonb
  );
  $$
);
