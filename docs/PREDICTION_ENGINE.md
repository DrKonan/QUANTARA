# Quantara — Moteur de Prédiction

> Spécifications techniques et fonctionnelles du cœur de l'application.

---

## 1. Vue d'ensemble

Le moteur de prédiction est une **Edge Function Supabase** (Deno/TypeScript) qui :
1. Récupère les données d'un match via **API-Football**
2. Calcule un score de confiance pour chaque catégorie d'événement
3. Filtre et retient uniquement les événements pertinents (≥ 80%)
4. Génère une analyse textuelle courte via **OpenAI GPT-4o**
5. Publie automatiquement les pronos en base de données

---

## 2. Sources de données — API-Football

Tous les appels passent via `https://v3.football.api-sports.io/`

### Données collectées par match
| Donnée | Endpoint API-Football | Moment | Statut |
|--------|-----------------------|--------|--------|
| Matchs du jour | `/fixtures?date=...` | Cron 3h + 20h UTC | ✅ Implémenté |
| Compositions officielles | `/fixtures/lineups?fixture=...` | ~1h avant le match | ✅ Implémenté |
| Statistiques équipes (saison) | `/teams/statistics` | À la prédiction | ✅ Implémenté |
| Head-to-head | `/fixtures/headtohead` | À la prédiction | ✅ Implémenté |
| Blessures & suspensions | `/injuries?fixture=...` | À la prédiction | ✅ Implémenté |
| Stats live | `/fixtures/statistics?fixture=...` | En cours de match (*/5min) | ✅ Implémenté |
| Résultats finaux | `/fixtures?id=...` | Après le match (*/15min) | ✅ Implémenté |
| **Cotes bookmakers** | **`/odds?fixture=...`** | **À la prédiction** | **🔜 V1.1** |
| **Prédictions API** | **`/predictions?fixture=...`** | **À la prédiction** | **🔜 V1.1** |
| **Stats historiques matchs** | **`/fixtures/statistics?fixture=...`** | **Derniers matchs** | **🔜 V1.1** |
| **Classement** | **`/standings?league=...&season=...`** | **Hebdomadaire** | **🔜 V1.2** |

### Nouveaux endpoints V1.1 — Détails

#### `/odds` — Cotes bookmakers (35+ types de paris)
Permet de récupérer les cotes réelles du marché pour un match. Les cotes implicites (`1/cote`) servent de **calibration** pour nos probabilités. Types disponibles :
- Match Winner (1X2)
- Goals Over/Under (0.5 à 4.5)
- Both Teams Score
- Double Chance
- Asian Handicap
- Corners Over/Under
- Cards Over/Under
- HT/FT Double, Clean Sheet, Win to Nil, etc.

#### `/predictions` — Prédictions API-Football
L'API fournit ses propres prédictions (winner, win_or_draw, under_over, percentages, last_5 att/def). Utilisé comme **signal de cross-validation**.

#### `/fixtures/statistics` — Stats réelles historiques
Fournit pour chaque match terminé : `expected_goals` (xG réel), `Corner Kicks`, `Fouls`, `Total Shots`, `Shots on Goal`, `Ball Possession`, `Yellow Cards`, `Red Cards`, etc. Utilisé pour calculer les **vrais xG moyens** et les **vraies moyennes de corners/cartons** par équipe.

---

## 3. Couverture & Ligues

### Tier 1 — Grandes compétitions (analyse complète + live renforcé)
- Premier League (Angleterre)
- La Liga (Espagne)
- Bundesliga (Allemagne)
- Serie A (Italie)
- Ligue 1 (France)
- Champions League UEFA
- Europa League UEFA
- Coupe du Monde / Euro / CAN

### Tier 2 — Autres ligues (analyse complète, live allégé)
- Toutes les autres ligues disponibles dans API-Football
- Condition : minimum 5 matchs joués dans la saison par les deux équipes

### Filtres d'exclusion
- Matchs amicaux (hors grandes équipes)
- Équipes avec < 5 matchs dans la saison
- Matchs avec données insuffisantes (pas de stats, pas de H2H)

---

## 4. Catégories d'événements analysées

L'IA ne fixe pas à l'avance le type de pari. Elle analyse **toutes les catégories** et retient celles où la conviction est ≥ 75%.

| Catégorie | Exemples d'événements |
|-----------|----------------------|
| **Résultat** | Victoire domicile, Nul, Victoire extérieur, Double chance |
| **Buts** | Over/Under 1.5 / 2.5 / 3.5, BTTS (oui/non) |
| **Mi-temps** | Résultat à la mi-temps, Over/Under 0.5 buts MT |
| **Corners** | Over/Under corners, équipe avec le plus de corners |
| **Cartons** | Over/Under cartons, joueur à risque (jaune) |
| **Handicap asiatique** | Si déséquilibre fort entre les équipes |

---

## 5. Algorithme de scoring

### Indicateurs utilisés (pré-match) — Architecture actuelle V1.0

```
Score(événement) = Σ(poids_i × indicateur_i) / Σ(poids_i)
```

| Indicateur | Poids | Description |
|------------|-------|-------------|
| Forme récente | 25% | Résultats des 5 derniers matchs (pondération décroissante) |
| Stats domicile/extérieur | 20% | Win rate / buts selon lieu |
| Head-to-head | 15% | Historique des confrontations directes (10 derniers) |
| Force de l'adversaire | 15% | ELO Rating relatif (sigmoid ±400pts) |
| Blessures / suspensions | 15% | Impact des absences clés (max -30%) |
| Enjeux du match | 10% | Classement, zone relégation, titre... |

### Amélioration V1.1 — Calibration par les cotes bookmakers

Le signal le plus fort du marché est le prix des cotes. Les bookmakers intègrent des milliers de variables (équipes de traders, modèles ML, données privées). Notre moteur ajoutera une **couche de calibration** :

```
confiance_finale = confiance_modèle × facteur_calibration(odds)
```

| Situation | Facteur |
|-----------|--------|
| Notre proba concorde avec les odds (écart < 10%) | ×1.05 (bonus) |
| Léger désaccord (écart 10-20%) | ×1.00 (neutre) |
| Fort désaccord (écart > 20%) | ×0.85 (pénalité) |
| Notre prono contredit le favori net du marché | ×0.70 (blocage potentiel) |

Ceci résoudra les problèmes de **sur-confiance** observés sur les marchés `result` (52.9% à ≥80%) et `over_under` (57.1% à ≥80%).

### Amélioration V1.1 — Cross-validation API Predictions

L'endpoint `/predictions` fournit un avis indépendant (winner, percentages). Utilisé comme **second avis** :
- Si notre prono est confirmé par l'API → bonus +5% confiance
- Si notre prono est contredit → pénalité -10% confiance

### Modèle de Poisson (buts)
- Calcul de l'espérance de buts (xG) pour chaque équipe
- **V1.0** : `xG = (attaque_moy × défense_concédée_moy) / moyenne_ligue` (formule naïve)
- **V1.1** : xG basés sur les **vrais expected_goals** des 5 derniers matchs (endpoint `/fixtures/statistics`)
- Utilisé pour : Over/Under buts, BTTS, résultat

### Modèle Corners (V1.1)
- **V1.0** : Corners estimés à partir de l'intensité des buts (proxy peu fiable)
- **V1.1** : Corners basés sur les **vraies statistiques de corners** des matchs passés (`Corner Kicks` dans `/fixtures/statistics`)
- Correction majeure : la corrélation buts↔corners est faible (r² < 0.2)

### ELO Rating
- Calculé en base pour chaque équipe
- **V1.0** : Statique (initialisé manuellement)
- **V1.1** : Mis à jour dynamiquement après chaque match (`K=32, ΔR = K × (résultat - expected)`)
- Utilisé pour : force relative des équipes, handicap

### Indicateurs live (en plus, pendant le match)
| Indicateur | Poids |
|------------|-------|
| Possession (cumulative) | 20% |
| Tirs cadrés | 20% |
| Corners accumulés | 15% |
| Cartons reçus | 15% |
| Score actuel | 30% |

---

## 6. Seuils de publication

| Score | Niveau | Action |
|-------|--------|--------|
| < 80% | Insuffisant | ❌ Non publié (interne uniquement) |
| 80–84% | Élevé | ✅ Publié (label bleu) |
| 85–91% | Très élevé | ✅ Publié (label vert) + Badge "Haute Confiance" (Pro/VIP) |
| ≥ 92% | Excellence | ✅ Publié (label or + mise en avant) + Badge "Excellence" |

**Règle qualité :** Mieux vaut 3 pronos solides par jour que 20 pronos douteux.  
**Seuil unique :** 80% pour tous les niveaux d'abonnement. Voir `PRICING_TIERS.md`.

---

## 7. Stratégie Live

### Tier 1 — Grandes compétitions
- Analyse toutes les **15 minutes** pendant le match
- Chaque cycle : récupération des stats live → recalcul du score → publication si ≥ 80%
- Pas de prono systématique : si rien de pertinent, on ne publie pas
- Potentiellement 0 à 4+ pronos live par match
- **Accès LIVE réservé aux plans Pro et VIP**

### Tier 2 — Autres ligues
- Analyse **une seule fois en 2ème mi-temps** (autour de la 60ème minute)
- Même logique : publication uniquement si ≥ 80%

### Déduplication
- Si un prono live porte sur le même événement qu'un prono pré-match → on met à jour le score de confiance, on ne crée pas un doublon

---

## 8. Génération de l'analyse textuelle (GPT-4o)

### Prompt système
```
Tu es un analyste sportif expert. En 2-3 phrases maximum, explique pourquoi 
cet événement est pertinent à jouer sur ce match. Sois factuel, précis, 
et base-toi uniquement sur les données fournies. Pas de jargon complexe.
Langue : {fr|en} selon la langue de l'utilisateur.
```

### Données injectées dans le prompt
- Équipes, ligue, date
- Événement prédit + score de confiance
- Top 3 indicateurs ayant le plus contribué au score
- Stats clés (forme, H2H, ELO)

### Exemple de sortie GPT-4o
> "PSG joue à domicile avec une moyenne de 8.2 corners par match cette saison. Lyon adopte un bloc défensif bas qui génère mécaniquement des situations de corner. Sur les 5 derniers H2H à Paris, PSG a obtenu au moins 4 corners à chaque fois."

---

## 9. Auto-évaluation des pronos

Après chaque match terminé :
1. Edge Function `evaluate-predictions` récupère le résultat final via API-Football
2. Compare chaque prono publié au résultat réel
3. Met à jour le champ `is_correct` (true/false) en base
4. Recalcule les stats globales : taux de réussite par catégorie, par ligue, global
5. Déclenche la notification push au résultat (gagné ✅ / perdu ❌)

---

## 10. Edge Functions — Liste

| Fonction | Déclencheur | Rôle |
|----------|-------------|------|
| `fetch-matches` | Cron 6h UTC chaque jour | Récupère les matchs du jour, stocke en base |
| `fetch-lineups` | Cron toutes les 10min entre 9h-23h | Détecte les compositions officielles |
| `predict-prematch` | Déclenché par `fetch-lineups` | Calcule et publie les pronos pré-match |
| `predict-live-t1` | Cron toutes les 15min (matchs Tier 1 en cours) | Analyse live Tier 1 |
| `predict-live-t2` | Cron à la 58ème min des matchs Tier 2 | Analyse live Tier 2 (une fois) |
| `evaluate-predictions` | Cron 30min après fin de chaque match | Vérifie les résultats et met à jour la base |
| `notify-users` | Déclenché par nouvelles prédictions | Envoie les notifications push |

---

## 11. Back-office Admin (web séparé)

Interface web légère (Next.js ou simple dashboard Supabase étendu) pour :
- 📊 Stats globales : taux de réussite, pronos publiés, volume par ligue
- 👥 Utilisateurs : liste, statut abonnement, date d'inscription
- 💰 Revenus : abonnements actifs, historique paiements CinetPay
- 📋 Pronos : liste complète, possibilité de supprimer un prono erroné
- ⚙️ Config : seuil de publication, ligues actives, mode maintenance

---

## 12. Diagnostic de performance (état au 18/04/2026)

### Winrate global
- **Toutes prédictions** : 473/754 (62.7%)
- **Confidence ≥ 0.75** : 77.1% (37/48 top picks)
- **Confidence ≥ 0.80** : 76% (130/171)
- **Objectif** : ≥ 80% pour toutes les prédictions publiées

### Winrate par marché (confidence ≥ 0.80)
| Marché | W/L | Winrate | Statut |
|--------|-----|---------|--------|
| BTTS | 42/44 | **95.5%** | ✅ Excellent |
| Corners | 18/20 | **90%** | ✅ Excellent |
| Cards | 21/26 | **80.8%** | ✅ Bon |
| Double Chance | 20/29 | **69%** | ⚠️ Problématique |
| Over/Under | 20/35 | **57.1%** | ❌ Mauvais |
| Result | 9/17 | **52.9%** | ❌ Mauvais |

### Prédictions les plus faibles (≥ 0.80 confidence)
| Prédiction | W/L | Winrate | Analyse |
|------------|-----|---------|--------|
| `under_1.5` | 8/19 | **42.1%** | Sous-estime les buts → **supprimer** |
| `X2` | 4/8 | **50%** | Confiance mal calibrée → **calibrer via odds** |
| `draw` | 9/17 | **52.9%** | Inherently imprévisible → **seuil ≥ 0.88** |
| `over_9.5` corners | 2/4 | **50%** | Proxy buts→corners → **utiliser vrais stats** |

### Faiblesses identifiées
1. **Pas de calibration par les odds** — Notre confiance diverge du marché sans correction
2. **xG naïfs** — Formule `(attaque × défense) / ligue_avg` au lieu des vrais xG disponibles
3. **Corners en proxy** — Estimation via intensité des buts (corrélation faible)
4. **ELO statique** — Jamais mis à jour après les matchs
5. **Sur-confiance O/U et Result** — ≥80% confiance mais ~55% winrate réel
6. **`under_1.5` catastrophique** — 42% winrate, ne devrait jamais être publié
7. **`/predictions` et `/odds` ignorés** — Signaux forts disponibles mais non exploités

---

## 13. Roadmap moteur

### V1.0 (✅ Livré)
- Modèle de scoring statique (poids fixes)
- 6 marchés : result, double_chance, over_under, btts, corners, cards
- Lignes dynamiques (`selectBestLine`)
- Raffinement par compositions officielles
- GPT-4o pour la synthèse textuelle
- Auto-évaluation des résultats
- Live Tier 1 (*/5min) + Live Tier 2
- Top Picks (2 meilleurs pronos par match)
- Winrate : 76% @ confidence ≥ 0.80

### V1.1 (🔜 En cours — objectif : winrate ≥ 80%)
- **Intégration `/odds`** : calibration des confiances par les cotes bookmakers
- **Intégration `/predictions`** : cross-validation avec les prédictions API
- **Vrais xG** : utiliser `expected_goals` réels des derniers matchs
- **Vrais corners/cards** : stats réelles au lieu de proxys
- **Filtres anti-faux positifs** :
  - Supprimer `under_1.5` du catalogue
  - `draw` : seuil minimum 0.88
  - `X2` : publier uniquement si confirmé par les odds
  - `result` : publier uniquement si confirmé par odds OU API predictions
- **ELO dynamique** : mise à jour automatique après chaque match
- Impact estimé : +4-8 points de winrate (objectif 80%+)

### V2.0
- Feedback loop : ajustement automatique des poids selon les performances
- Modèle ML entraîné sur l'historique (XGBoost ou RandomForest)
- Intégration `/standings` pour les enjeux de classement
- Extension Basketball & Hockey
