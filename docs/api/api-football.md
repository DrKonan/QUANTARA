# API-Football

Documentation d'utilisation de l'API sportive principale.

## Endpoint de base
```
https://v3.football.api-sports.io/
```

## Authentification
Header requis :
```
X-RapidAPI-Key: YOUR_API_KEY
X-RapidAPI-Host: v3.football.api-sports.io
```

## Endpoints clés utilisés

### Matchs du jour
```
GET /fixtures?date=2024-01-15&timezone=Africa/Abidjan
```

### Statistiques d'une équipe
```
GET /teams/statistics?season=2024&team=85&league=61
```

### Blessures
```
GET /injuries?fixture=592872
```

### Head-to-head
```
GET /fixtures/headtohead?h2h=85-86
```

## Limites (plan gratuit)
- 100 requêtes/jour
- Accès aux grandes ligues uniquement

## Limites (plan pro)
- Requêtes illimitées
- Toutes les ligues
- Stats avancées
