# 📋 Note à l'équipe Backend — 20 avril 2026

## 1. 🔔 Notifications Push (FCM) — App fermée

### Contexte
Le mobile gère déjà les **notifications locales** quand l'app est ouverte :
- Nouveau prono disponible (≥80% confiance)
- Prono LIVE disponible
- Nouvelle combinaison générée
- Résultat d'un match (gagné/perdu)

L'app enregistre aussi le **token FCM** via `register-push-token` au login.

### Ce qui manque côté backend
Quand l'app est **fermée ou en arrière-plan**, les notifications locales ne se déclenchent pas. Il faut que le backend **envoie des push FCM** dans les cas suivants :

| Événement | Titre suggéré | Priorité |
|-----------|--------------|----------|
| Nouveau prono officiel publié (≥80%) | 🎯 Nouveau prono disponible | **Haute** |
| Prono LIVE publié pendant un match | ⚡ Prono LIVE disponible | **Haute** |
| Nouvelle combinaison générée | 🔥 Combinaison disponible | Moyenne |
| Résultat d'un match (prono gagné) | ✅ Prono gagné ! | Moyenne |
| Résultat d'un match (prono perdu) | ❌ Prono perdu | Basse |

### Implémentation suggérée
1. **Database trigger** ou **webhook** sur insert/update dans les tables `predictions` / `combos` / `matches`
2. Récupérer les tokens FCM depuis la table où `register-push-token` les stocke
3. Envoyer via **Firebase Admin SDK** (ou l'API FCM v1 directement)
4. Le payload doit inclure `match_id` dans `data` pour que l'app puisse naviguer au bon match quand l'utilisateur tape la notification

### Préférences utilisateur
L'app stocke des préférences locales (`SharedPreferences`), mais pour filtrer côté backend (ne pas envoyer de push si l'utilisateur a désactivé une catégorie), il faudrait :
- Soit synchroniser les préférences vers une table `user_notification_prefs`
- Soit envoyer tous les push et laisser le mobile filtrer (plus simple, mais consomme du réseau)

**Recommandation** : commencer par tout envoyer, l'app filtre déjà localement. On ajoutera le filtrage serveur plus tard si besoin.

---

## 2. 💳 Système de paiement — Correspondants PawaPay

### Contexte
Le mobile supporte maintenant **12 pays d'Afrique de l'Ouest/Centrale** avec sélection dynamique du pays → moyens de paiement. Le backend (`create-payment`) a été mis à jour pour accepter les codes PawaPay directement (ex: `ORANGE_CIV`, `MTN_MOMO_CMR`).

### ⚠️ Problème : correspondants non vérifiés
La liste des correspondants dans le code (backend + mobile) a été générée à partir de la documentation PawaPay, **mais n'a pas été vérifiée contre les correspondants réellement actifs sur notre compte**.

### Action requise
1. **Appeler l'endpoint PawaPay** pour récupérer les correspondants actifs :
   ```
   GET https://api.sandbox.pawapay.io/active-conf
   Authorization: Bearer <PAWAPAY_API_TOKEN>
   ```

2. **Partager la réponse** avec l'équipe mobile pour qu'on mette à jour :
   - `backend/supabase/functions/create-payment/index.ts` → `VALID_CORRESPONDENTS`
   - `mobile/lib/core/constants/app_constants.dart` → `supportedCountries`

3. **Vérifier les devises** — le backend mappe automatiquement :
   - `_CIV`, `_SEN`, `_MLI`, `_BFA`, `_BEN`, `_TGO`, `_NER` → `XOF`
   - `_CMR`, `_GAB`, `_COG` → `XAF`
   - `_COD` → `CDF`
   - `_GIN` → `GNF`
   
   Confirmer que ces devises correspondent bien à ce que PawaPay attend pour chaque correspondant.

### Optionnel : Edge Function utilitaire
On peut créer une Edge Function `get-active-correspondents` qui appelle `/active-conf` et retourne le résultat filtré. Utile pour :
- Debug rapide
- Potentiellement faire du dynamique côté mobile (charger les pays disponibles au runtime)

---

## 3. 📁 Fichiers modifiés (référence)

### Backend
- `supabase/functions/create-payment/index.ts`
  - Whitelist élargie (`VALID_CORRESPONDENTS`) — 12 pays
  - Multi-devises automatique (`getCurrencyForCorrespondent()`)
  - Accepte les codes PawaPay directement (plus de mapping intermédiaire)

### Mobile (pour info)
- `lib/core/constants/app_constants.dart` — modèle `PaymentCountry` + `PaymentMethod`
- `lib/features/subscription/presentation/screens/subscription_screen.dart` — bottom sheet pays → méthodes
- `lib/features/subscription/data/payment_service.dart` — envoi MSISDN pré-formaté
- `lib/core/services/notification_service.dart` — service notifications locales complet
- `lib/features/predictions/domain/predictions_provider.dart` — triggers notifications sur refresh

---

## 4. 🔐 Authentification — Nouveau flow sans OTP

### Changement
L'inscription/connexion par **OTP SMS/WhatsApp a été supprimée**. Le nouveau flow :

- **Inscription** : nom d'utilisateur + téléphone (avec sélecteur pays) + email optionnel + mot de passe
- **Connexion** : téléphone + mot de passe OU email + mot de passe

### Fonctionnement interne
- Supabase utilise **email/password** comme méthode d'auth
- Si l'utilisateur ne fournit pas d'email, un email dérivé du téléphone est généré : `{dialCode}{numéro}@phone.quantara.app` (ex: `2250700000000@phone.quantara.app`)
- Le vrai numéro de téléphone est stocké dans la table `users.phone`
- L'email réel (si fourni) est aussi stocké dans `users.email`

### Action requise côté Supabase
1. **Désactiver la confirmation email** dans Dashboard → Authentication → Settings → Email :
   - `Enable email confirmations` → **OFF** (sinon les comptes avec email auto-généré ne pourront pas se connecter)
   - Ou configurer un domaine autorisé `phone.quantara.app` qui bypass la confirmation
2. Le provider **Phone** n'a plus besoin d'être activé (pas de Twilio nécessaire)

### Table `users` — colonnes attendues
| Colonne | Type | Nullable | Description |
|---------|------|----------|-------------|
| `id` | uuid | Non | FK vers auth.users |
| `username` | text | Non | Nom d'utilisateur |
| `phone` | text | Non | Numéro complet avec indicatif (ex: +2250700000000) |
| `email` | text | Oui | Email réel (optionnel) |
| `plan` | text | Non | Plan d'abonnement (default: 'free') |

---

*Note rédigée le 20/04/2026 — Équipe mobile Quantara*
