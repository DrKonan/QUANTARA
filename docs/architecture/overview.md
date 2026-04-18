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

### Indicateurs utilisés (V1.0 — actuel)
- Forme récente (5 derniers matchs, pondération décroissante)
- Stats domicile/extérieur (win rate, buts moyens)
- Head-to-head historique (10 derniers)
- Blessures / suspensions (impact max -30%)
- Modèle de Poisson pour les buts (xG naïfs)
- ELO Rating statique (sigmoid ±400pts)
- Raffinement par compositions (lineup quality factor)
- 6 marchés : result, double_chance, over_under, btts, corners, cards

### Améliorations planifiées (V1.1)
- **Calibration par cotes bookmakers** (`/odds`) — ancrage marché pour corriger sur-confiances
- **Cross-validation API** (`/predictions`) — second avis indépendant
- **Vrais xG** (`/fixtures/statistics` → `expected_goals`) — remplace formule naïve
- **Vrais stats corners/cards** (`/fixtures/statistics`) — remplace proxy buts→corners
- **ELO dynamique** — mise à jour auto après chaque match (K=32)
- **Filtres anti-faux positifs** — suppression `under_1.5`, seuil `draw` à 0.88

### Score de confiance
- < 80% → Non affiché (interne uniquement)
- 80-84% → Élevé (tous les plans)
- 85-91% → Très élevé + badge Haute Confiance (Pro/VIP)
- ≥ 92% → Excellence (mis en avant)

### Performance actuelle (18/04/2026)
- Winrate global (≥0.80) : **76%** (130/171)
- Meilleurs marchés : BTTS 95.5%, Corners 90%, Cards 80.8%
- Marchés à améliorer : Over/Under 57.1%, Result 52.9%, Double Chance 69%
- Objectif V1.1 : **≥ 80%** via calibration odds + vrais xG
