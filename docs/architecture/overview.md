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
│  API-Football  │          │ Wave + PawaPay  │
│  (Stats sport) │          │  (Wave/PawaPay) │
└────────────────┘          └─────────────────┘
```

## Flux de données

1. **Fetch quotidien** : Edge Function `fetch-matches` récupère les matchs du jour via API-Football
2. **Analyse** : Edge Function `predict` calcule les prédictions (modèle Poisson + ELO + contexte)
3. **Stockage** : Prédictions sauvegardées en base PostgreSQL
4. **App mobile** : Flutter consomme les prédictions via Supabase Realtime/REST
5. **Paiement** : Wave/PawaPay traite les abonnements, webhook confirme en base

## Modèle de tarification

> Détails complets dans `docs/PRICING_TIERS.md`

4 niveaux : Gratuit (1 match/j) → Starter 990F (5/j) → Pro 1990F (15/j) → VIP 3990F (illimité)
- Seuil de confiance ≥ 80% pour TOUS les niveaux
- Différenciation : quantité + fonctionnalités (LIVE, combinés), pas qualité

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
- < 80% → Non affiché (interne uniquement)
- 80-84% → Élevé (tous les plans)
- 85-91% → Très élevé + badge Haute Confiance (Pro/VIP)
- ≥ 92% → Excellence (mis en avant)
