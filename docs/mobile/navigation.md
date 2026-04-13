# Navigation — Application Flutter

## Structure de navigation

```
SplashScreen
└── OnboardingScreen (1ère fois)
    └── AuthScreen
        ├── LoginScreen
        └── RegisterScreen

MainShell (Bottom Navigation)
├── HomeScreen           → Prédictions du jour
├── MatchesScreen        → Tous les matchs
├── StatsScreen          → Historique & performance
└── ProfileScreen        → Compte & abonnement
    └── SubscriptionScreen → Plans & paiement
```

## Gestion de l'état
- **Riverpod** recommandé pour la gestion d'état
- **GoRouter** pour la navigation déclarative

## Accès Premium
Les écrans/widgets premium vérifient le statut via :
```dart
final isPremium = ref.watch(subscriptionProvider).isPremium;
```
