-- ============================================================
-- QUANTARA — Migration 002 : Indexes & Row Level Security
-- ============================================================

-- ----------------------------------------------------------------
-- INDEXES
-- ----------------------------------------------------------------

-- matches
create index if not exists idx_matches_match_date      on public.matches (match_date);
create index if not exists idx_matches_status          on public.matches (status);
create index if not exists idx_matches_sport           on public.matches (sport);
create index if not exists idx_matches_tier            on public.matches (tier);
create index if not exists idx_matches_lineups_ready   on public.matches (lineups_ready) where lineups_ready = false;
create index if not exists idx_matches_live            on public.matches (status) where status = 'live';

-- predictions
create index if not exists idx_predictions_match_id    on public.predictions (match_id);
create index if not exists idx_predictions_confidence  on public.predictions (confidence);
create index if not exists idx_predictions_is_live     on public.predictions (is_live);
create index if not exists idx_predictions_is_correct  on public.predictions (is_correct) where is_correct is null;
create index if not exists idx_predictions_published   on public.predictions (is_published, created_at desc);

-- subscriptions
create index if not exists idx_subscriptions_user_id   on public.subscriptions (user_id);
create index if not exists idx_subscriptions_status    on public.subscriptions (status);
create index if not exists idx_subscriptions_end_date  on public.subscriptions (end_date);

-- team_elo
create index if not exists idx_team_elo_team_id        on public.team_elo (team_id);

-- push_tokens
create index if not exists idx_push_tokens_user_id     on public.push_tokens (user_id);
create index if not exists idx_push_tokens_active      on public.push_tokens (is_active) where is_active = true;

-- ----------------------------------------------------------------
-- FONCTIONS UTILITAIRES
-- ----------------------------------------------------------------

-- Mise à jour automatique de updated_at
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Triggers updated_at
create or replace trigger trg_matches_updated_at
  before update on public.matches
  for each row execute function public.set_updated_at();

create or replace trigger trg_predictions_updated_at
  before update on public.predictions
  for each row execute function public.set_updated_at();

create or replace trigger trg_subscriptions_updated_at
  before update on public.subscriptions
  for each row execute function public.set_updated_at();

create or replace trigger trg_push_tokens_updated_at
  before update on public.push_tokens
  for each row execute function public.set_updated_at();

-- Création automatique d'un profil users lors de l'inscription Auth
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.users (id, username, avatar_url, phone)
  values (
    new.id,
    new.raw_user_meta_data->>'username',
    new.raw_user_meta_data->>'avatar_url',
    new.phone
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create or replace trigger trg_on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Calcul win_rate sur prediction_stats
create or replace function public.refresh_prediction_stats_win_rate()
returns trigger language plpgsql as $$
begin
  if new.total > 0 then
    new.win_rate = new.correct::numeric / new.total::numeric;
  else
    new.win_rate = null;
  end if;
  return new;
end;
$$;

create or replace trigger trg_prediction_stats_win_rate
  before insert or update on public.prediction_stats
  for each row execute function public.refresh_prediction_stats_win_rate();

-- ----------------------------------------------------------------
-- ROW LEVEL SECURITY
-- ----------------------------------------------------------------

alter table public.users             enable row level security;
alter table public.matches           enable row level security;
alter table public.predictions       enable row level security;
alter table public.subscriptions     enable row level security;
alter table public.prediction_stats  enable row level security;
alter table public.push_tokens       enable row level security;
alter table public.team_elo          enable row level security;

-- users : lecture/modification de son propre profil uniquement
create policy "users_select_own"
  on public.users for select
  using (auth.uid() = id);

create policy "users_update_own"
  on public.users for update
  using (auth.uid() = id);

-- matches : lecture publique
create policy "matches_select_all"
  on public.matches for select
  using (true);

-- predictions : lecture publique des pronos publiés
create policy "predictions_select_published"
  on public.predictions for select
  using (is_published = true);

-- team_elo : lecture publique
create policy "team_elo_select_all"
  on public.team_elo for select
  using (true);

-- prediction_stats : lecture publique
create policy "prediction_stats_select_all"
  on public.prediction_stats for select
  using (true);

-- subscriptions : lecture de sa propre subscription uniquement
create policy "subscriptions_select_own"
  on public.subscriptions for select
  using (auth.uid() = user_id);

-- push_tokens : gestion de ses propres tokens uniquement
create policy "push_tokens_select_own"
  on public.push_tokens for select
  using (auth.uid() = user_id);

create policy "push_tokens_insert_own"
  on public.push_tokens for insert
  with check (auth.uid() = user_id);

create policy "push_tokens_update_own"
  on public.push_tokens for update
  using (auth.uid() = user_id);

create policy "push_tokens_delete_own"
  on public.push_tokens for delete
  using (auth.uid() = user_id);

-- ----------------------------------------------------------------
-- RÔLE SERVICE (Edge Functions) — accès complet sans RLS
-- Les Edge Functions utilisent la service_role key (bypass RLS).
-- Rien à configurer ici, c'est géré côté Supabase automatiquement.
-- ----------------------------------------------------------------
