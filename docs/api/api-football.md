# API-Football

Documentation d'utilisation de l'API sportive principale.

## Endpoint de base
```
https://v3.football.api-sports.io/
```

## Authentification
Header requis :
```
x-apisports-key: <API_FOOTBALL_KEY>
```
> La clé est stockée dans les **Supabase Secrets** (`API_FOOTBALL_KEY`).  
> Plan actif : **Ultra** (75 000 requêtes/jour). Expire le 14/05/2026.

## Endpoints utilisés — V1.0 (✅ Implémenté)

### Matchs du jour / à venir
```
GET /fixtures?date=2026-04-18&timezone=UTC
GET /fixtures?next=50&league=39
GET /fixtures?id=1379298              # Match spécifique
```

### Statistiques d'une équipe (saison)
```
GET /teams/statistics?season=2025&team=85&league=39
```
Retourne : form, wins/draws/loses (home/away), goals avg, cards par période.

### Head-to-head
```
GET /fixtures/headtohead?h2h=85-86&last=10
```

### Blessures & suspensions
```
GET /injuries?fixture=1379298
```

### Compositions officielles
```
GET /fixtures/lineups?fixture=1379298
```

### Statistiques live / post-match
```
GET /fixtures/statistics?fixture=1379298
```
Retourne : `Shots on Goal`, `Total Shots`, `Fouls`, `Corner Kicks`, `Offsides`, `Ball Possession`, `Yellow Cards`, `Red Cards`, `Goalkeeper Saves`, `Total passes`, `Passes accurate`, `Passes %`, **`expected_goals`**, `goals_prevented`.

### Effectifs (pour raffinement des compos)
```
GET /players/squads?team=85
GET /players?team=85&season=2025&league=39
```

## Endpoints à intégrer — V1.1 (🔜 Planifié)

### Cotes bookmakers
```
GET /odds?fixture=1379289
GET /odds?fixture=1379289&bookmaker=8    # Bet365 seulement
```
Retourne **35+ types de paris** avec cotes réelles :
- `1` Match Winner (1X2)
- `5` Goals Over/Under (0.5 à 4.5)
- `8` Both Teams Score
- `12` Double Chance
- `4` Asian Handicap
- `6` Goals O/U First Half
- `7` HT/FT Double
- `27-28` Clean Sheet
- `29-30` Win to Nil
- etc.

**Usage prévu** : Calibration des confiances. Les probas implicites (`1/cote`) servent d'ancrage pour détecter nos sur-confiances.

### Prédictions API-Football
```
GET /predictions?fixture=1379289
```
Retourne : `winner`, `win_or_draw`, `under_over`, `percent` (home/draw/away), `goals` estimés, `advice`, `last_5` (form, att, def, goals for/against), `league` stats complètes (fixtures, goals, biggest, clean_sheet).

**Usage prévu** : Cross-validation. Si notre prono contredit l'API → pénalité confiance.

### Classement
```
GET /standings?league=39&season=2025
```
**Usage prévu** : Calcul des enjeux du match (titre, relégation, qualification européenne).

### Statistiques match historiques (pour xG réel & corners réels)
```
GET /fixtures/statistics?fixture=<past_fixture_id>
```
L'endpoint `/fixtures/statistics` fournit les stats de n'importe quel match terminé. En interrogeant les **5 derniers matchs** de chaque équipe, on obtient :
- `expected_goals` → vrais xG moyens (remplace la formule naïve)
- `Corner Kicks` → vraie moyenne corners (remplace le proxy buts→corners)
- `Fouls` → contexte cartons
- `Yellow Cards` / `Red Cards` → stats réelles

## Limites du plan Ultra
| Métrique | Valeur |
|----------|--------|
| Requêtes / jour | 75 000 |
| Rate limit | Aucun (pas de throttling) |
| Ligues | Toutes (1000+) |
| Historique | Complet |
| Stats avancées | ✅ (xG, formations, odds) |
| Couverture live | ✅ Temps réel |

## Budget API estimé (V1.1)
| Endpoint | Appels / match | Appels / jour (50 matchs) |
|----------|---------------|--------------------------|
| `/teams/statistics` ×2 | 2 | 100 |
| `/fixtures/headtohead` | 1 | 50 |
| `/injuries` | 1 | 50 |
| `/odds` (nouveau) | 1 | 50 |
| `/predictions` (nouveau) | 1 | 50 |
| `/fixtures/statistics` ×10 (nouveau) | 10 | 500 |
| Live (stats ×2, every 5min) | ~36 | ~360 |
| **Total estimé** | | **~1 160 / jour** |

Marge confortable : 1 160 / 75 000 = **1.5%** du quota quotidien.
