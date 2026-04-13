# Schéma Base de Données — Quantara

## Tables principales

### `users`
Extension de auth.users de Supabase.
```sql
id          uuid PRIMARY KEY (ref auth.users)
username    text
avatar_url  text
plan        text DEFAULT 'free'  -- 'free' | 'premium'
created_at  timestamptz
```

### `matches`
```sql
id              serial PRIMARY KEY
external_id     text UNIQUE  -- ID API-Football
sport           text         -- 'football' | 'hockey' | 'basketball'
home_team       text
away_team       text
league          text
match_date      timestamptz
status          text         -- 'scheduled' | 'live' | 'finished'
home_score      int
away_score      int
created_at      timestamptz
```

### `predictions`
```sql
id              serial PRIMARY KEY
match_id        int REFERENCES matches(id)
prediction_type text    -- 'result' | 'btts' | 'over_under' | 'handicap'
prediction      text    -- ex: 'home_win', 'yes', 'over_2.5'
confidence      float   -- 0.0 à 1.0
is_premium      boolean DEFAULT false
is_correct      boolean -- null jusqu'au résultat
created_at      timestamptz
```

### `subscriptions`
```sql
id              serial PRIMARY KEY
user_id         uuid REFERENCES users(id)
plan            text    -- 'monthly' | 'quarterly' | 'yearly'
status          text    -- 'active' | 'cancelled' | 'expired'
start_date      timestamptz
end_date        timestamptz
payment_ref     text    -- référence CinetPay
created_at      timestamptz
```
