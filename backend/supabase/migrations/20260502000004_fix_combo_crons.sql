-- ================================================================
-- NAKORA — Migration : Fix crons combos (hardcoded URL + JWT)
--
-- Les crons combo utilisaient current_setting('app.settings.*')
-- qui retourne NULL (jamais configuré) → les crons ne déclenchaient rien.
-- Tous les autres crons (migration 008) utilisent URL + JWT hardcodés.
-- On aligne les crons combos sur le même pattern.
-- ================================================================

-- Supprime les crons cassés (current_setting pattern)
SELECT cron.unschedule('generate-combos-day');
SELECT cron.unschedule('generate-combos-evening');

-- Combo du jour : 4h UTC → matchs avant 22h UTC
SELECT cron.schedule(
  'generate-combos-day',
  '0 4 * * *',
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

-- Combo du soir : 21h UTC → matchs à partir de 22h UTC
SELECT cron.schedule(
  'generate-combos-evening',
  '0 21 * * *',
  $$
  SELECT net.http_post(
    url := 'https://epiaxzyzrclebutxvbgp.supabase.co/functions/v1/generate-combos',
    headers := jsonb_build_object(
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwaWF4enl6cmNsZWJ1dHh2YmdwIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjEwNTI2MSwiZXhwIjoyMDkxNjgxMjYxfQ.uCJT4jgA--qwzeH8mDvxDMa8TmtBxAi68wS4huMPF-A',
      'Content-Type', 'application/json'
    ),
    body := '{"slot":"evening"}'::jsonb
  );
  $$
);
