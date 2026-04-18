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
| Donnée | Endpoint API-Football | Moment |
|--------|-----------------------|--------|
| Matchs du jour | `/fixtures?date=...` | Matin (6h UTC) |
| Compositions officielles | `/fixtures/lineups?fixture=...` | ~1h avant le match |
| Statistiques équipes (saison) | `/teams/statistics` | Matin |
| Head-to-head | `/fixtures/headtohead` | Matin |
| Blessures & suspensions | `/injuries?fixture=...` | Matin |
| Stats live | `/fixtures/statistics?fixture=...` | En cours de match |
| Résultats finaux | `/fixtures?id=...` | Après le match |

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

### Indicateurs utilisés (pré-match)

```
Score(événement) = Σ(poids_i × indicateur_i) / Σ(poids_i)
```

| Indicateur | Poids | Description |
|------------|-------|-------------|
| Forme récente | 25% | Résultats des 5 derniers matchs |
| Stats domicile/extérieur | 20% | Win rate / buts selon lieu |
| Head-to-head | 15% | Historique des confrontations directes |
| Force de l'adversaire | 15% | ELO Rating relatif |
| Blessures / suspensions | 15% | Impact des absences clés |
| Enjeux du match | 10% | Classement, zone relégation, titre... |

### Modèle de Poisson (buts)
- Calcul de l'espérance de buts pour chaque équipe
- Basé sur : force offensive × faiblesse défensive adverse × facteur domicile
- Utilisé pour : Over/Under buts, BTTS, résultat

### ELO Rating
- Calculé et mis à jour en base après chaque match
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

## 12. Roadmap moteur

### V1
- Modèle de scoring statique (poids fixes)
- GPT-4o pour la synthèse
- Auto-évaluation des résultats
- Live Tier 1 (15min) + Live Tier 2 (2ème mi-temps)

### V2
- Feedback loop : ajustement automatique des poids selon les performances
- Modèle ML entraîné sur l'historique (XGBoost ou RandomForest)
- Extension Basketball & Hockey
