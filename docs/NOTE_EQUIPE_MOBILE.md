# QUANTARA — Note Technique pour l'Équipe Mobile
**Date** : 15 avril 2026  
**Version API** : v2.2 — Top Picks, Marchés Élargis, Fuseaux Horaires & Auth Téléphone  
**Auteur** : Backend Team

---

## 1. Résumé des Changements

Le backend a été profondément remanié pour améliorer la précision et la diversité des prédictions. Les points clés :

1. **Nouveaux marchés de paris** : corners, cartons, double chance (en plus des existants result, over/under, BTTS)
2. **Système "Top Pick"** : le moteur sélectionne automatiquement **1 à 2 meilleures prédictions** par match — c'est ce que l'utilisateur doit voir en priorité
3. **Nouveaux champs API** : `is_top_pick`, `is_refined` dans chaque objet prediction
4. **Fréquence accrue** : les données se mettent à jour toutes les 5 minutes (live scores, lineups, prédictions live)

---

## 2. Nouveau Schéma de Réponse `get-today-matches`

### Chaque prediction dans le tableau `predictions` contient désormais :

```json
{
  "id": 95,
  "prediction_type": "cards",           // NOUVEAU : "cards", "corners", "double_chance"
  "prediction": "over_3.5",             // NOUVEAU format pour corners/cards
  "confidence": 0.924,
  "confidence_label": "excellence",
  "is_premium": true,
  "is_locked": false,
  "is_live": false,
  "is_top_pick": true,                  // ⭐ NOUVEAU — à afficher en priorité
  "is_refined": false,                  // NOUVEAU — prono recalculé avec les compos
  "analysis_text": "..."
}
```

### Nouveaux `prediction_type` possibles :

| Type | Valeurs `prediction` | Description |
|------|---------------------|-------------|
| `result` | `home_win`, `away_win`, `draw` | Résultat du match (1X2) |
| `double_chance` | `1X`, `X2`, `12` | Double chance |
| `over_under` | `over_2.5`, `under_2.5` | Buts O/U 2.5 |
| `btts` | `yes`, `no` | Les deux équipes marquent |
| `corners` | `over_9.5`, `under_9.5` | Corners O/U 9.5 |
| `cards` | `over_3.5`, `under_3.5` | Cartons jaunes O/U 3.5 |

---

## 3. Concept "Top Pick" — Philosophie d'Affichage

### Principe fondamental
> Le backend génère 5 à 8 prédictions par match, mais **seules 1 à 2 sont marquées `is_top_pick: true`**. Ce sont les prédictions les plus fiables et les plus exploitables.

### Règles de sélection (backend) :
- Maximum **2 top picks** par match
- Chaque top pick est d'un **type de marché différent** (ex: un `cards` + un `over_under`, jamais deux `result`)
- Confiance minimale **≥ 62%** pour être top pick
- Fallback : si aucun n'atteint 62%, le meilleur prono ≥ 55% est quand même marqué

### Recommandation UI Mobile :

```
┌─────────────────────────────────────────────┐
│  ⚽ Indep. del Valle vs UCV                 │
│  Copa Libertadores — 16/04 à 02h00         │
│                                              │
│  ⭐ PRONO DU MATCH                          │
│  ┌──────────────────────────────────────┐   │
│  │ 🟡 +3.5 Cartons  │ Confiance: 92%   │   │
│  │ Analyse: "Les confrontations..."     │   │
│  └──────────────────────────────────────┘   │
│  ┌──────────────────────────────────────┐   │
│  │ ⬇️ Moins de 2.5 buts │ Conf: 78%    │   │
│  │ Analyse: "Les deux équipes..."       │   │
│  └──────────────────────────────────────┘   │
│                                              │
│  📊 Voir toutes les analyses (7) ▾          │
│      (section rétractable)                   │
│      • 12 (pas de nul) — 65%               │
│      • 1X (domicile ou nul) — 64%          │
│      • X2 (extérieur ou nul) — 62%         │
│      • BTTS Non — 58%                      │
│      • -9.5 Corners — 55%                  │
└─────────────────────────────────────────────┘
```

**Résumé** :
- **Afficher en gros** uniquement les predictions avec `is_top_pick: true`
- **Section rétractable** pour les autres predictions (optionnel, pour les utilisateurs curieux)
- Si **aucun top pick** pour un match → afficher "Analyse en cours" ou le meilleur prono disponible

---

## 4. Labels d'Affichage par Type

Pour convertir les valeurs techniques en texte lisible :

```javascript
const PREDICTION_LABELS = {
  // result
  home_win: "Victoire {home}",
  away_win: "Victoire {away}",
  draw: "Match nul",

  // double_chance
  "1X": "{home} ou Nul",
  "X2": "Nul ou {away}",
  "12": "Pas de match nul",

  // over_under
  "over_2.5": "+2.5 Buts",
  "under_2.5": "-2.5 Buts",

  // btts
  yes: "Les deux marquent",
  no: "Au moins un ne marque pas",

  // corners
  "over_9.5": "+9.5 Corners",
  "under_9.5": "-9.5 Corners",

  // cards
  "over_3.5": "+3.5 Cartons",
  "under_3.5": "-3.5 Cartons",
};

const TYPE_ICONS = {
  result: "⚽",
  double_chance: "🎯",
  over_under: "📊",
  btts: "🤝",
  corners: "🚩",
  cards: "🟨",
};
```

---

## 5. Badge "Affiné" (`is_refined`)

Quand `is_refined: true`, la prédiction a été **recalculée avec les compositions officielles** (~1h avant le match). C'est un gage de qualité.

**Recommandation UI** : Afficher un badge bleu "Affiné ✓" ou "Compos intégrées" à côté des top picks affinés.

---

## 6. Prédictions Live

### Comportement :
- Les prédictions live arrivent **toutes les 5 minutes** pendant le match
- Elles incluent les mêmes marchés (result, corners, cards, over_under, btts)
- `is_live: true` et `is_top_pick: true/false` sont mis à jour à chaque cycle
- **Plusieurs prédictions live** peuvent arriver au cours d'un match (le backend les met à jour)

### Recommandation UI :
- Afficher les prédictions live avec `is_top_pick: true` dans un encart spécial "💡 Pari Live Suggéré"
- Les prédictions live avec `is_top_pick: false` peuvent être listées en secondaire
- Animer la mise à jour (la confiance change toutes les 5 min)

---

## 7. Filtrage des Prédictions Côté Client

### Pour l'écran principal (liste des matchs) :
```javascript
// Afficher SEULEMENT les top picks
const topPicks = match.predictions.filter(p => p.is_top_pick);
```

### Pour l'écran détail d'un match :
```javascript
// Top picks en haut + reste en section rétractable
const topPicks = match.predictions.filter(p => p.is_top_pick);
const others = match.predictions.filter(p => !p.is_top_pick);
```

### Pour les matchs live :
```javascript
// Séparer prematch et live
const prematch = match.predictions.filter(p => !p.is_live);
const live = match.predictions.filter(p => p.is_live);
const liveTopPicks = live.filter(p => p.is_top_pick);
```

---

## 8. Niveaux de Confiance (inchangé)

| Label | Plage | Couleur recommandée |
|-------|-------|---------------------|
| `elevated` | 50-64% | Jaune/Orange |
| `high` | 65-79% | Vert |
| `excellence` | 80-99% | Or/Doré |

---

## 9. Timing & Rafraîchissement

| Événement | Fréquence | Impact |
|-----------|-----------|--------|
| Nouveaux matchs | 2×/jour (3h + 20h UTC) | Prédictions initiales auto-générées |
| Compositions | Toutes les 5 min (90min avant match) | Prédictions affinées (`is_refined`) |
| Scores live | Toutes les 5 min | Statut match + scores |
| Prédictions live T1 | Toutes les 5 min | Nouveaux pronos / mises à jour |
| Prédictions live T2 | Toutes les 5 min (fenêtre 45-80 min) | Analyse unique |
| Évaluations | Toutes les 15 min | `is_correct` sur les pronos |

**Recommandation** : Rafraîchir les données côté mobile toutes les **30-60 secondes** via polling ou Supabase Realtime.

---

## 10. Checklist Mobile à Mettre à Jour

- [ ] Ajouter le champ `is_top_pick` au modèle Prediction
- [ ] Ajouter le champ `is_refined` au modèle Prediction
- [ ] Créer une card "Top Pick" visuellement distincte (plus grande, dorée/accentuée)
- [ ] Gérer les nouveaux `prediction_type` : `double_chance`, `corners`, `cards`
- [ ] Mapper les prédictions en labels lisibles (voir section 4)
- [ ] Section rétractable "Voir toutes les analyses" pour les non-top-picks
- [ ] Badge "Affiné ✓" quand `is_refined: true`
- [ ] Section live dédiée avec animation de mise à jour
- [ ] Adapter les icônes par type de marché
- [ ] Tester avec les données de test (match 436 = Indep. del Valle vs UCV)

---

## 11. Données de Test

Match 436 — **Independiente del Valle vs UCV** (Copa Libertadores, 16/04 02h00 UTC)

| Type | Prédiction | Confiance | Top Pick |
|------|-----------|-----------|----------|
| cards | over_3.5 | 92.4% | ✅ |
| over_under | under_2.5 | 78.0% | ✅ |
| double_chance | 12 | 65.6% | ❌ |
| double_chance | 1X | 64.6% | ❌ |
| double_chance | X2 | 62.2% | ❌ |
| btts | no | 58.8% | ❌ |
| corners | under_9.5 | 55.8% | ❌ |

→ L'utilisateur verra uniquement : **"+3.5 Cartons (92%)"** et **"-2.5 Buts (78%)"**

---

## ⚠️ IMPORTANT — Calcul du Win Rate (Coupon Officiel)

### Principe
Le Win Rate ne doit **pas** être calculé sur toutes les prédictions. Il se base sur le **coupon officiel** que nous proposons à l'utilisateur :

| Source | Quoi compter | Logique |
|--------|-------------|---------|
| **Prematch** | Seulement les `is_top_pick = true` | C'est notre prono officiel (1-2 par match). Les autres analyses sont informatives. |
| **Live** | **Toutes** les prédictions live (`is_live = true`) | Les pronos live viennent par inspiration en temps réel, ils comptent tous. |

### Implémentation
```javascript
// Filtrer les pronos qui comptent pour le winrate
const officialPreds = predictions.filter(p =>
  p.is_correct !== null && (p.is_live || p.is_top_pick)
);
const winRate = officialPreds.filter(p => p.is_correct).length / officialPreds.length;
```

### Ce qui ne compte PAS
- Les prédictions prematch avec `is_top_pick = false` (analyses secondaires, faible confiance)
- Les prédictions non encore évaluées (`is_correct = null`)

### Affichage recommandé
- Win rate global en haut de l'écran principal
- Win rate par match dans l'historique (même logique : top picks + live)
- Séparer visuellement pronos officiels vs analyses secondaires

---

**Questions ?** Contactez l'équipe backend. L'API est live et les données sont disponibles dès maintenant.

---

## 12. ⏰ Fuseaux Horaires — Affichage Local des Heures

### Règle fondamentale
Le champ `match_date` est **toujours en UTC (GMT+0)** dans l'API (ex: `2026-04-15T19:00:00+00:00`).  
Les heures doivent être affichées **dans le fuseau horaire local de l'appareil de l'utilisateur**.

### Exemples concrets
Un match avec `match_date = "2026-04-15T19:00:00+00:00"` :
| Localisation | Heure affichée |
|-------------|---------------|
| Paris (GMT+2) | 21:00 |
| New York (GMT-4) | 15:00 |
| Londres (GMT+1) | 20:00 |
| Tokyo (GMT+9) | 04:00 (16 avril) |

### Implémentation côté mobile

**Flutter :**
```dart
final matchDate = DateTime.parse(matchDateStr).toLocal();
final formatted = DateFormat('HH:mm').format(matchDate);
```

**React Native :**
```javascript
const date = new Date(match.match_date);
const time = date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
const dateStr = date.toLocaleDateString([], { day: '2-digit', month: '2-digit' });
```

**Swift (iOS) :**
```swift
let formatter = DateFormatter()
formatter.dateFormat = "HH:mm"
formatter.timeZone = TimeZone.current
let time = formatter.string(from: matchDate)
```

**Kotlin (Android) :**
```kotlin
val sdf = SimpleDateFormat("HH:mm", Locale.getDefault())
sdf.timeZone = TimeZone.getDefault()
val time = sdf.format(matchDate)
```

### Points importants
- **NE PAS forcer un fuseau horaire fixe** (ex: ne pas utiliser "Europe/Berlin" ou "fr-FR"). Laisser le système de l'appareil décider.
- **Utiliser `navigator.language` ou l'équivalent mobile** pour le format (24h vs 12h AM/PM).
- Le champ `match_date` ne change JAMAIS côté serveur. C'est **uniquement l'affichage** qui s'adapte.
- Pour les dates (jour du match), attention : un match à 02:00 UTC du 16 avril sera affiché le **15 avril** à 22:00 pour un utilisateur à New York (GMT-4).

### Checklist fuseau horaire
- [ ] Convertir `match_date` en heure locale avant affichage
- [ ] Ne pas hardcoder de locale (`"fr-FR"`) — utiliser la locale de l'appareil
- [ ] Tester avec un appareil/simulateur en GMT-5 et en GMT+9
- [ ] Vérifier les matchs SA nocturnes (ex: 02:00 UTC → 22:00 à NYC, 04:00 à Paris)

---

## 13. 📱 Authentification Téléphone + Email

### Deux modes de connexion

| Mode | Flow | Priorité |
|------|------|----------|
| **📱 Téléphone (principal)** | Numéro → OTP SMS → Vérifié | Mode par défaut |
| **📧 Email (fallback)** | Email + mot de passe | Fallback classique |

### Flow inscription téléphone
1. L'utilisateur saisit **nom d'utilisateur** + **numéro** (préfixe +225 auto)
2. Appel `signInWithOtp(phone: '+225XXXXXXXXXX', data: {'username': 'Pseudo'})`
3. SMS OTP 6 chiffres reçu
4. Appel `verifyOTP(phone: '+225XXXXXXXXXX', token: '123456', type: OtpType.sms)`
5. Compte créé auto → trigger copie vers `public.users` (avec essai 3 jours)

### Ce que fait le backend automatiquement
- **Trigger INSERT** : crée `public.users` avec `username`, `phone`, essai premium 3 jours
- **Trigger UPDATE** : si phone ajouté/modifié après coup, met à jour `public.users.phone`
- **Pas d'Edge Function custom** — tout est Supabase Auth natif

### Important pour le mobile
- Le `username` **DOIT** être dans `data` lors du `signInWithOtp` :
  ```dart
  await supabase.auth.signInWithOtp(
    phone: '+225$numero',
    data: {'username': monUsername},
  );
  ```
- Si `username` absent → "Utilisateur" par défaut
- `phone` est **UNIQUE** — un numéro = un compte

### Statut : ⏳ En attente de Twilio
Le code backend est prêt. Twilio doit être configuré dans Supabase Dashboard.

### Checklist auth
- [x] Flow inscription téléphone (OTP)
- [x] Flow connexion téléphone (OTP)
- [x] Flow connexion email + mot de passe
- [x] Préfixe +225 automatique
- [ ] Tester avec un vrai numéro (après config Twilio)
- [ ] Gérer erreur "numéro déjà utilisé" (`user_already_exists`)
- [ ] Gérer erreur "code OTP invalide/expiré"
