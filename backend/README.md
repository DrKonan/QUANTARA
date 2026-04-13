# Quantara — Backend (Supabase)

Backend basé sur Supabase : PostgreSQL + Edge Functions + Auth.

## Prérequis
- Compte Supabase
- Supabase CLI (`npm install -g supabase`)
- Deno (pour les Edge Functions)

## Setup

```bash
cd backend
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

## Structure

```
backend/
├── supabase/
│   ├── functions/     → Edge Functions (Deno/TypeScript)
│   │   ├── predict/       → Moteur de prédiction
│   │   ├── fetch-matches/ → Récupération matchs (API-Football)
│   │   └── webhook-payment/ → Webhook CinetPay
│   └── migrations/    → Migrations PostgreSQL
└── scripts/           → Scripts utilitaires
```

## Variables d'environnement Supabase
Configurer dans le dashboard Supabase → Settings → Edge Functions :
```
API_FOOTBALL_KEY=your_key
CINETPAY_API_KEY=your_key
CINETPAY_SITE_ID=your_site_id
```

## Documentation
Voir `../docs/backend/` pour la documentation détaillée.
