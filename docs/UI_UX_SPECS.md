# Quantara — Spécifications UI/UX & Produit

> Complément de `VISION.md`. Décrit l'expérience utilisateur en détail.

---

## 1. Identité Visuelle

### Style général
**Sombre & Premium** — inspire confiance, sérieux et exclusivité.

### Palette de couleurs
| Rôle | Couleur | Hex |
|------|---------|-----|
| Fond principal | Noir profond | `#0D0D0D` |
| Fond carte | Anthracite | `#1A1A2E` |
| Accent primaire | Or | `#D4AF37` |
| Accent secondaire | Vert émeraude | `#00C896` |
| Texte principal | Blanc | `#FFFFFF` |
| Texte secondaire | Gris clair | `#A0A0B0` |
| Danger / Perdu | Rouge | `#FF4757` |
| Succès / Gagné | Vert | `#2ED573` |

### Score de confiance — couleurs
| Niveau | % | Couleur |
|--------|---|---------|
| Faible | < 65% | Rouge `#FF4757` |
| Moyen | 65–74% | Orange `#FFA502` |
| Élevé | 75–84% | Bleu `#1E90FF` |
| Très élevé | ≥ 85% | Vert `#2ED573` |

### Logo
- Lettre **Q stylisée** — sobre, premium, reconnaissable comme icône d'app
- Typographie : moderne sans-serif (ex: Inter ou Poppins)

---

## 2. Navigation

### Bottom Navigation Bar (4 onglets)
```
[ 🏠 Home ] [ ⚽ Matchs ] [ 📋 Historique ] [ 👤 Profil ]
```

| Onglet | Contenu |
|--------|---------|
| **Home** | Dashboard : stats Quantara + pronos du jour en vedette |
| **Matchs** | Tous les matchs disponibles, filtrables par ligue/date |
| **Historique** | Pronos passés avec résultats (gagné/perdu) |
| **Profil** | Compte, abonnement, paramètres, préférences |

---

## 3. Flux de navigation complet

```
SplashScreen (logo Q animé)
└── Onboarding (1ère installation)
    ├── Slide 1 : "Des pronos intelligents, pas des paris au hasard"
    ├── Slide 2 : "L'IA analyse chaque match sous tous les angles"
    ├── Slide 3 : "Pré-match et Live — on s'adapte au match"
    └── Slide 4 : "3 jours gratuits, accès complet" → [Commencer]
        └── AuthScreen
            ├── LoginScreen (email + OTP)
            └── RegisterScreen (email + numéro de téléphone + OTP)

MainShell (Bottom Nav)
├── HomeScreen
│   └── PronoDetailScreen (tap sur un prono)
├── MatchsScreen
│   └── MatchDetailScreen (tap sur un match)
│       └── PronoDetailScreen
├── HistoriqueScreen
│   └── PronoDetailScreen
└── ProfilScreen
    ├── SubscriptionScreen
    │   └── PaymentScreen (CinetPay)
    └── SettingsScreen
        └── PreferencesScreen (ligues favorites)
```

---

## 4. Écrans en détail

### SplashScreen
- Logo Q animé sur fond noir
- Durée : 2 secondes
- Redirige vers Onboarding (1ère fois) ou MainShell (déjà connecté)

### Onboarding (4 slides)
- Slide 1 : Illustration + "Des pronos intelligents, pas des paris au hasard"
- Slide 2 : Illustration + "L'IA analyse chaque match sous tous les angles"
- Slide 3 : Illustration + "Pré-match et Live — on s'adapte au match"
- Slide 4 : "3 jours gratuits, accès complet" → bouton [Commencer gratuitement]
- Skip possible dès le slide 1

### AuthScreen
- Toggle Login / Inscription
- **Login** : email + mot de passe
- **Inscription** : email + numéro de téléphone + mot de passe → OTP SMS pour valider le téléphone
- Politique anti-abus : 1 essai gratuit par numéro de téléphone + device fingerprint

### HomeScreen
```
┌─────────────────────────────────┐
│  Quantara             🔔        │
│  Bonjour, [Prénom] 👋           │
├─────────────────────────────────┤
│  📊 STATS QUANTARA CE MOIS      │
│  Taux de réussite : 84%         │
│  Pronos joués : 142             │
│  Gagnés : 119 | Perdus : 23     │
├─────────────────────────────────┤
│  🔴 LIVE (2 matchs en cours)    │
│  [Card prono live]              │
│  [Card prono live]              │
├─────────────────────────────────┤
│  📅 AUJOURD'HUI (8 pronos)      │
│  [Card prono]                   │
│  [Card prono]                   │
│  [Card prono]                   │
├─────────────────────────────────┤
│  ⏳ À VENIR                     │
│  [Card prono]                   │
└─────────────────────────────────┘
```

### Card Prono (composant réutilisable)
```
┌──────────────────────────────────────┐
│  🇫🇷 Ligue 1 · Aujourd'hui 21h00     │
│  PSG  vs  Lyon                       │
│                                      │
│  🎯 Plus de 3.5 corners PSG          │
│  87% ●●●●○  Très élevé 🟢           │
│                                      │
│  "PSG domine à domicile avec 8.2..." │
│  [Voir l'analyse complète →]         │
└──────────────────────────────────────┘
```
> Si non-abonné (après essai) : l'événement est visible, l'analyse est masquée avec [🔒 Débloquer avec Premium]

### PronoDetailScreen
- En-tête : match, ligue, date/heure, statut (live/à venir/terminé)
- Événement prédit + score de confiance
- Analyse complète (2-3 lignes)
- Données clés utilisées : forme, H2H, stats domicile/extérieur
- Résultat (si terminé) : ✅ Gagné / ❌ Perdu

### MatchsScreen
- Barre de recherche
- Filtres : Ligue, Date, Statut (live/à venir/terminé)
- Liste des matchs avec indication si un prono est disponible
- Ligues favorites en haut (configurables dans Paramètres)

### HistoriqueScreen
- Filtre : Semaine / Mois / Tout
- Stats en haut : taux de réussite personnel (pronos consultés)
- Liste chronologique des pronos passés + résultat

### ProfilScreen
- Avatar + nom + email
- Statut abonnement (actif jusqu'au JJ/MM/AAAA ou "Essai : X jours restants")
- Bouton [Gérer mon abonnement]
- Bouton [Préférences] (ligues favorites, notifications)
- Bouton [Langue] (FR / EN)
- Bouton [Déconnexion]

### SubscriptionScreen
```
┌──────────────────────────────────┐
│  Passez Premium 🏆               │
│  Accès illimité à tous les pronos│
├──────────────────────────────────┤
│  ○ Hebdomadaire   XXXX FCFA/sem  │
│  ● Mensuel        XXXX FCFA/mois │  ← recommandé
│  ○ Annuel         XXXX FCFA/an   │
│    (économisez 40%)              │
├──────────────────────────────────┤
│  ✅ Pronos illimités             │
│  ✅ Analyses complètes           │
│  ✅ Alertes Live                 │
│  ✅ Historique complet           │
├──────────────────────────────────┤
│  [Payer via Wave / Orange / MTN] │
└──────────────────────────────────┘
```

---

## 5. Notifications Push

| Déclencheur | Message |
|-------------|---------|
| Prono pré-match disponible | "🎯 PSG vs Lyon — Nouveau prono disponible !" |
| Compositions connues | "📋 Compositions officielles connues — analyse mise à jour" |
| Prono live | "🔴 LIVE : Opportunité détectée dans PSG vs Lyon" |
| Prono gagné | "✅ Prono gagné ! PSG vs Lyon — Plus de 3.5 corners PSG" |
| Prono perdu | "❌ PSG vs Lyon — ce prono n'est pas passé" |
| Rappel essai | "⏳ Il te reste 1 jour d'essai gratuit — passe Premium !" |

---

## 6. Gestion Abonnement & Anti-Abus

### Essai gratuit
- Durée : 3 jours
- Décompte visible dans le profil
- Rappel push à J-1

### Anti-abus
- OTP SMS obligatoire à l'inscription → 1 essai par numéro de téléphone
- Device fingerprinting (package `device_info_plus` + hash stocké en base)
- Blocage si même device fingerprint + essai déjà consommé

### Après l'essai
- Pronos toujours visibles (match + événement)
- Analyse masquée → remplacée par [🔒 Débloquer avec Premium]
- Pas de limitation du nombre de matchs visibles

---

## 7. Localisation

- Langue détectée automatiquement depuis la locale du téléphone
- Français par défaut si langue non reconnue
- Changeable manuellement dans Profil → Langue
- Langues supportées V1 : **fr**, **en**
