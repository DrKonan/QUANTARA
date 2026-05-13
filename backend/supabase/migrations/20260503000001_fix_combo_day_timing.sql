-- NAKORA: Decale generate-combos-day de 4h a 7h UTC
-- Raison: fetch-matches tourne a 3h UTC, puis predict-prematch
-- est declenche pour chaque match (peut prendre 1-3h pour 50+ matchs).
-- A 4h UTC les predictions ne sont pas encore prets, donc pool vide.
-- A 7h UTC les predictions sont prets, les combos peuvent etre generes.

SELECT cron.unschedule('generate-combos-day');

SELECT cron.schedule(
  'generate-combos-day',
  '0 7 * * *',
  $$
  SELECT net.http_post(
    url := 'https://epiaxzyzrclebutxvbgp.supabase.co/functions/v1/generate-combos',
    headers := jsonb_build_object(
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwaWF4enl6cmNsZWJ1dHh2YmdwIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjEwNTI2MSwiZXhwIjoyMDkxNjgxMjYxfQ.uCJT4jgA--qwzeH8mDvxDMa8TmtBxAi68wS4huMPF-A',
      'Content-Type', 'application/json'
    ),
    body := '{"slot":"day"}'::jsonb
  );
  $$
);
