# Quantara — Modèle de Tarification & Niveaux d'Abonnement

> Document de référence pour la stratégie de monétisation.  
> Dernière mise à jour : 18 avril 2026

---

## 1. Philosophie

### Principes fondamentaux
- **Accessibilité** : le prix d'entrée (990 F) est dans la zone "sans réfléchir" pour le marché cible
- **Qualité constante** : TOUS les pronos proposés ont un seuil de confiance ≥ 80%, quel que soit le niveau d'abonnement
- **Différenciation par la quantité et les fonctionnalités**, jamais par la qualité des pronos
- **Funnel naturel** : le gratuit crée l'engagement, les limites quotidiennes poussent l'upgrade

### Pourquoi pas de seuil de confiance variable ?
- Un utilisateur à 990 F qui reçoit des pronos à 75% perd plus souvent → mauvais avis
- Le winrate global chute → perte de crédibilité
- L'image de "mauvais prono pour les pauvres" détruit la confiance

---

## 2. Les 4 Formules

| | 🆓 **Gratuit** | ⚽ **Starter** | 🏆 **Pro** | 👑 **VIP** |
|---|---|---|---|---|
| **Prix** | 0 FCFA | **990 FCFA/mois** | **1 990 FCFA/mois** | **3 990 FCFA/mois** |
| **Matchs avec prono/jour** | 1 (Top Pick du jour) | 5 | 15 | **Illimité** |
| **Sports** | Football | Football | Football + Basketball | **Tous** (Foot, Basket, Hockey) |
| **Confiance minimum** | ≥ 80% | ≥ 80% | ≥ 80% | ≥ 80% |
| **Badge "Haute Confiance"** | ❌ | ❌ | ✅ (≥85% mis en avant) | ✅ |
| **Pronos LIVE** | ❌ | ❌ | ✅ | ✅ |
| **Alertes push** | ❌ | Basiques | Complètes | **Prioritaires** |
| **Combinés suggérés** | ❌ | ❌ | ❌ | ✅ |
| **Analyse détaillée** | ❌ (résumé court) | ✅ | ✅ | ✅ |

---

## 3. Détail de chaque formule

### 🆓 Gratuit — Le piège à engagement
- **1 match gratuit/jour** : le "Top Pick" (meilleur prono du jour sélectionné par l'IA)
- L'utilisateur voit que ça marche → il veut plus → il paye
- Analyse courte (2 lignes) sans détail complet
- Pas de pronos LIVE ni d'alertes push
- Football uniquement

### ⚽ Starter (990 FCFA/mois) — La masse
- **5 matchs avec pronos/jour** — assez pour parier quotidiennement
- Analyse détaillée de chaque prono
- Alertes push basiques (nouveau prono disponible)
- Pas de pronos LIVE
- Football uniquement
- **Cible** : 80% de la base payante, étudiants et parieurs occasionnels

### 🏆 Pro (1 990 FCFA/mois) — Le parieur régulier
- **15 matchs avec pronos/jour**
- Tous les avantages Starter +
- **Pronos LIVE** en temps réel pendant les matchs
- **Badge "Haute Confiance"** : marqueur visuel sur les pronos ≥ 85%
- Football + Basketball
- Alertes push complètes (pronos + résultats)

### 👑 VIP (3 990 FCFA/mois) — Le parieur sérieux
- **Matchs illimités**
- Tous les avantages Pro +
- **Tous les sports** (Football, Basketball, Hockey)
- **Combinés suggérés** : l'IA propose des combos de 2-3 matchs à cotes intéressantes
- Alertes push prioritaires
- **Cible** : ~5% des utilisateurs, mais revenu élevé par tête

---

## 4. Seuil de confiance — Règle unique

### Seuil minimum global : **80%**
- Aucun prono n'est montré à l'utilisateur (quel que soit son plan) s'il est en dessous de 80%
- Le backend peut générer des analyses à 60-79%, mais elles restent internes
- Le badge "Haute Confiance" (Pro/VIP) met en avant les pronos ≥ 85% — c'est un **marqueur visuel**, pas un seuil différent

### Labels de confiance affichés
| Niveau | Plage | Couleur | Badge |
|--------|-------|---------|-------|
| Élevé | 80–84% | Bleu | — |
| Très élevé | 85–91% | Vert | 🔥 Haute Confiance (Pro/VIP) |
| Excellence | ≥ 92% | Or | ⭐ Excellence (Pro/VIP) |

---

## 5. Logique de comptage des matchs

### Comment ça marche ?
- Chaque jour, l'IA génère des pronos pour X matchs
- L'utilisateur voit les pronos dans l'ordre de pertinence (meilleur prono en premier)
- Une fois la limite quotidienne atteinte, les pronos suivants sont masqués avec 🔒
- Le compteur se réinitialise à **00:00 UTC** chaque jour

### Qu'est-ce qui compte comme "1 match" ?
- Accéder aux pronos d'un match = 1 match consommé
- Un match peut avoir 1 à 3 pronos (top picks) — ils comptent comme **1 seul match**
- Les matchs déjà consultés dans la journée ne recomptent pas
- Les matchs "gratuits" du jour (Top Pick) ne comptent pas dans le quota Starter/Pro

### Règle de priorité d'affichage
1. Top Pick du jour (gratuit pour tous)
2. Pronos les plus fiables (confiance décroissante)
3. Matchs par popularité de la ligue (Tier 1 en premier)

---

## 6. Fonctionnalités exclusives par tier

### Badge "Haute Confiance" (Pro + VIP)
- Marqueur visuel spécial sur les pronos ≥ 85%
- Icône 🔥 ou badge vert dans la liste et le détail
- Ne change PAS les pronos — juste un indicateur visuel supplémentaire

### Pronos LIVE (Pro + VIP)
- Accès aux prédictions en temps réel pendant les matchs
- Analyse mise à jour toutes les 15 minutes (Tier 1) ou une fois en 2ème MT (Tier 2)
- Badge "LIVE" rouge animé

### Combinés suggérés (VIP uniquement)
- L'IA propose des combinaisons de 2-3 matchs
- Chaque match dans le combiné a individuellement ≥ 80% de confiance
- Cote combinée calculée (indicative, pas un bookmaker)
- Maximum 2 combinés suggérés par jour

---

## 7. Impact sur le backend

### Table `plan_pricing` (mise à jour)
```sql
plan      | amount_xof | duration_days | label        | max_matches_per_day | sports              | has_live | has_combos
----------|------------|---------------|--------------|---------------------|---------------------|----------|----------
free      | 0          | -1            | Gratuit      | 1                   | football            | false    | false
starter   | 990        | 30            | Starter      | 5                   | football            | false    | false
pro       | 1990       | 30            | Pro          | 15                  | football,basketball | true     | false
vip       | 3990       | 30            | VIP          | -1 (illimité)       | all                 | true     | true
```

### Table `users` — Champ `plan`
```sql
plan TEXT CHECK (plan IN ('free', 'starter', 'pro', 'vip'))
```

### Table `subscriptions` — Champ `plan`
```sql
plan TEXT CHECK (plan IN ('starter', 'pro', 'vip'))
```

### Nouveau tracking : `user_daily_views`
```sql
user_id     UUID
match_id    BIGINT
viewed_at   DATE
```
Pour compter les matchs consultés par jour et appliquer la limite.

---

## 8. Paiement

### Moyens de paiement
| Fournisseur | Méthodes | Marchés |
|-------------|----------|---------|
| **Wave Business API** | Wave | CI, Sénégal, Mali, Burkina, Gambie, Ouganda |
| **PawaPay** | Orange Money, MTN Mobile Money | 20 pays africains |

### Flux
1. Utilisateur choisit un plan → choisit une méthode de paiement
2. Wave : redirection checkout → paiement dans l'app Wave → webhook retour
3. PawaPay : push USSD sur le téléphone → code PIN → webhook retour
4. Activation instantanée de l'abonnement après confirmation webhook

### Notes
- Pas de formule hebdomadaire (trop de friction/oubli de renouvellement)
- Pas de formule annuelle (trop cher pour le marché cible)
- Toutes les formules sont **mensuelles** — simplicité maximale
- Renouvellement manuel (pas d'auto-renouvellement dans V1)

---

## 9. Analyse marché

### Prix psychologiques en Afrique de l'Ouest
- 500-1 000 FCFA : "prix d'un crédit téléphone" → achat impulsif
- 2 000-3 000 FCFA : "prix d'un repas" → réflexion légère
- 5 000+ FCFA : "investissement" → réflexion sérieuse

### Concurrence
- La plupart des apps de pronos en Afrique sont gratuites (qualité douteuse)
- Les tipsters premium sur Telegram facturent 5 000-15 000 FCFA/mois
- Notre positionnement : **qualité premium à prix accessible**

### Projection
- 70-80% des payants seront sur Starter (990 F)
- 15-20% sur Pro (1 990 F)
- 5-10% sur VIP (3 990 F)
- ARPU estimé : ~1 200-1 400 FCFA/mois
