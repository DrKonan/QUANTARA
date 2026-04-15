-- ============================================================
-- QUANTARA — Migration 008 : Refonte complète des crons
-- 
-- Changements :
--   1. Supprime TOUS les anciens crons (clé anon → service_role)
--   2. Recrée tous les crons avec la clé service_role
--   3. fetch-matches : 2×/jour (3h UTC matin + 20h UTC soir)
--   4. update-live-scores : toutes les 5 minutes (était 30 min)
--   5. fetch-lineups : toutes les 5 minutes (était 10 min)
--   6. predict-live-t1 : toutes les 5 minutes (était 15 min)
--   7. predict-live-t2 : toutes les 5 minutes (inchangé)
--   8. evaluate-predictions : toutes les 15 minutes (était 30 min)
-- ============================================================

-- ============================================================
-- ÉTAPE 1 : Supprimer TOUS les anciens crons
-- ============================================================
SELECT cron.unschedule('fetch-matches-daily');
SELECT cron.unschedule('fetch-lineups-10min');
SELECT cron.unschedule('predict-live-t1-15min');
SELECT cron.unschedule('predict-live-t2-5min');
SELECT cron.unschedule('evaluate-predictions-30min');
SELECT cron.unschedule('update-live-scores-30min');

-- ============================================================
-- ÉTAPE 2 : Recréer TOUS les crons avec service_role key
-- ============================================================

-- fetch-matches MATIN : 3h UTC → matchs du jour 6h–23h
SELECT cron.schedule(
  'fetch-matches-morning',
  '0 3 * * *',
  $$
  SELECT net.http_post(
    url := 'https://epiaxzyzrclebutxvbgp.supabase.co/functions/v1/fetch-matches',
    headers := jsonb_build_object(
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwaWF4enl6cmNsZWJ1dHh2YmdwIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjEwNTI2MSwiZXhwIjoyMDkxNjgxMjYxfQ.uCJT4jgA--qwzeH8mDvxDMa8TmtBxAi68wS4huMPF-A',
      'Content-Type', 'application/json'
    ),
    body := '{"mode":"morning"}'::jsonb
  );
  $$
);

-- fetch-matches SOIR : 20h UTC → matchs de nuit 23h–6h
SELECT cron.schedule(
  'fetch-matches-evening',
  '0 20 * * *',
  $$
  SELECT net.http_post(
    url := 'https://epiaxzyzrclebutxvbgp.supabase.co/functions/v1/fetch-matches',
    headers := jsonb_build_object(
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwaWF4enl6cmNsZWJ1dHh2YmdwIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjEwNTI2MSwiZXhwIjoyMDkxNjgxMjYxfQ.uCJT4jgA--qwzeH8mDvxDMa8TmtBxAi68wS4huMPF-A',
      'Content-Type', 'application/json'
    ),
    body := '{"mode":"evening"}'::jsonb
  );
  $$
);

-- update-live-scores : toutes les 5 minutes
SELECT cron.schedule(
  'update-live-scores-5min',
  '*/5 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://epiaxzyzrclebutxvbgp.supabase.co/functions/v1/update-live-scores',
    headers := jsonb_build_object(
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwaWF4enl6cmNsZWJ1dHh2YmdwIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjEwNTI2MSwiZXhwIjoyMDkxNjgxMjYxfQ.uCJT4jgA--qwzeH8mDvxDMa8TmtBxAi68wS4huMPF-A',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);

-- fetch-lineups : toutes les 5 minutes
SELECT cron.schedule(
  'fetch-lineups-5min',
  '*/5 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://epiaxzyzrclebutxvbgp.supabase.co/functions/v1/fetch-lineups',
    headers := jsonb_build_object(
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwaWF4enl6cmNsZWJ1dHh2YmdwIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjEwNTI2MSwiZXhwIjoyMDkxNjgxMjYxfQ.uCJT4jgA--qwzeH8mDvxDMa8TmtBxAi68wS4huMPF-A',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);

-- predict-live-t1 : toutes les 5 minutes
SELECT cron.schedule(
  'predict-live-t1-5min',
  '*/5 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://epiaxzyzrclebutxvbgp.supabase.co/functions/v1/predict-live-t1',
    headers := jsonb_build_object(
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwaWF4enl6cmNsZWJ1dHh2YmdwIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjEwNTI2MSwiZXhwIjoyMDkxNjgxMjYxfQ.uCJT4jgA--qwzeH8mDvxDMa8TmtBxAi68wS4huMPF-A',
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
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwaWF4enl6cmNsZWJ1dHh2YmdwIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjEwNTI2MSwiZXhwIjoyMDkxNjgxMjYxfQ.uCJT4jgA--qwzeH8mDvxDMa8TmtBxAi68wS4huMPF-A',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);

-- evaluate-predictions : toutes les 15 minutes
SELECT cron.schedule(
  'evaluate-predictions-15min',
  '*/15 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://epiaxzyzrclebutxvbgp.supabase.co/functions/v1/evaluate-predictions',
    headers := jsonb_build_object(
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwaWF4enl6cmNsZWJ1dHh2YmdwIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjEwNTI2MSwiZXhwIjoyMDkxNjgxMjYxfQ.uCJT4jgA--qwzeH8mDvxDMa8TmtBxAi68wS4huMPF-A',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);
