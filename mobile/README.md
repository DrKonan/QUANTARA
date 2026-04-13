# Quantara — Mobile (Flutter)

Application Flutter multi-plateforme (iOS & Android).

## Prérequis
- Flutter SDK >= 3.x
- Dart >= 3.x
- Android Studio ou Xcode

## Installation

```bash
cd mobile
flutter pub get
flutter run
```

## Structure

```
mobile/
├── lib/
│   ├── core/          → Config, thème, constantes
│   ├── features/      → Fonctionnalités (auth, predictions, subscription...)
│   ├── shared/        → Widgets réutilisables
│   └── main.dart
├── assets/
├── test/
└── pubspec.yaml
```

## Variables d'environnement
Créer un fichier `.env` à la racine de `mobile/` :
```
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=your_anon_key
CINETPAY_API_KEY=your_cinetpay_key
API_FOOTBALL_KEY=your_api_football_key
```

## Architecture
Pattern utilisé : **Feature-first + Clean Architecture**
- `features/auth/` → Authentification (Supabase Auth)
- `features/predictions/` → Prédictions sportives
- `features/subscription/` → Abonnements & paiements
- `features/home/` → Dashboard principal

## Documentation
Voir `../docs/mobile/` pour la documentation détaillée.
