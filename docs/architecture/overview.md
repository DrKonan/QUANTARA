# Architecture Globale — Quantara

## Vue d'ensemble

```
┌─────────────────────────────────────────────────┐
│                  Flutter App                     │
│  (iOS & Android)                                 │
│                                                  │
│  ┌──────────┐  ┌────────────┐  ┌─────────────┐  │
│  │   Auth   │  │Predictions │  │Subscription │  │
│  └──────────┘  └────────────┘  └─────────────┘  │
└──────────────────────┬──────────────────────────┘
                       │ HTTPS / Realtime
┌──────────────────────▼──────────────────────────┐
│                   Supabase                       │
│                                                  │
│  ┌────────────┐  ┌──────────────────────────┐   │
│  │ PostgreSQL │  │     Edge Functions        │   │
│  │            │  │  - predict                │   │
│  │ - users    │  │  - fetch-matches           │   │
│  │ - matches  │  │  - webhook-payment         │   │
│  │ - preds    │  └──────────────────────────┘   │
│  │ - subs     │                                  │
│  └────────────┘  ┌──────────────────────────┐   │
│                  │     Supabase Auth         │   │
│                  └──────────────────────────┘   │
└──────────────────────┬──────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
┌───────▼────────┐          ┌────────▼────────┐
│  API-Football  │          │   CinetPay      │
│  (Stats sport) │          │  (Paiements CI) │
└────────────────┘          └─────────────────┘
```

## Flux de données

1. **Fetch quotidien** : Edge Function `fetch-matches` récupère les matchs du jour via API-Football
2. **Analyse** : Edge Function `predict` calcule les prédictions (modèle Poisson + ELO + contexte)
3. **Stockage** : Prédictions sauvegardées en base PostgreSQL
4. **App mobile** : Flutter consomme les prédictions via Supabase Realtime/REST
5. **Paiement** : CinetPay traite les abonnements, webhook confirme en base

## Modèle de prédiction

### Indicateurs utilisés
- Forme récente (5 derniers matchs)
- Stats domicile/extérieur
- Head-to-head historique
- Blessures / suspensions
- Classement & enjeux du match
- Modèle de Poisson pour les buts (football)
- ELO Rating adapté par sport

### Score de confiance
- < 60% → Non affiché
- 60-75% → Prédiction basique (gratuit)
- > 75% → Prédiction premium (payant)
- > 85% → Prédiction haute confiance (premium)
