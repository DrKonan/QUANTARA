# 📋 Note à l'équipe Backend — 2 mai 2026

**Auteur** : Équipe Mobile / Copilot  
**Sujet** : Corrections appliquées côté mobile + web · Actions requises côté backend

---

## 1. ✅ Ce qui a été fait (commit `89a4e80`)

### 1.1 Fix mobile — Notifications background (Flutter)

**Fichier** : `mobile/lib/core/services/notification_service.dart`

**Problème** : `import 'package:flutter/scheduler.dart'` importait tout le namespace,
créant une collision avec `Priority` de `flutter_local_notifications`.
Résultat : `flutter analyze` échouait avec 4 erreurs bloquantes, empêchant la compilation
du handler background `firebaseMessagingBackgroundHandler`.

**Fix appliqué** :
```dart
// Avant
import 'package:flutter/scheduler.dart';

// Après
import 'package:flutter/scheduler.dart' show SchedulerBinding;
```

**Impact** : Le handler `firebaseMessagingBackgroundHandler` (qui reçoit les push FCM
quand l'app est fermée ou en arrière-plan) est maintenant compilable. Les notifications
push arriveront correctement même app fermée.

---

### 1.2 Fix web — Lint ESLint (Back-office Next.js)

**Fichiers** :
- `web/src/app/dashboard/layout.tsx`
- `web/src/app/dashboard/history/page.tsx`

**Problèmes** :
1. `setSidebarOpen(false)` appelé directement dans un `useEffect` → erreur `react-hooks/set-state-in-effect`
2. Import `Filter` inutilisé dans `history/page.tsx`

**Fix appliqué** :
```tsx
// layout.tsx — avant
useEffect(() => {
  setSidebarOpen(false);
}, [pathname]);

// layout.tsx — après
const [, startSidebarTransition] = useTransition();
useEffect(() => {
  startSidebarTransition(() => setSidebarOpen(false));
}, [pathname]);
```

---

### 1.3 Migration SQL — Fix domaine email téléphone

**Fichier** : `backend/supabase/migrations/20260502000001_fix_phone_domain_nakora.sql`

**Problème** : Le trigger `handle_new_user()` filtrait `@phone.quantara.app` (ancien nom
du projet), alors que le mobile génère `@phone.nakora.app`. Conséquence : les emails
auto-générés pour les utilisateurs sans email réel étaient stockés dans `public.users.email`
comme de vrais emails, polluant les données.

**Fix** : Le trigger filtre maintenant les deux domaines :
```sql
IF v_email LIKE '%@phone.nakora.app' OR v_email LIKE '%@phone.quantara.app' THEN
  v_email := NULL;
END IF;
```

---

## 2. ⚠️ Actions requises côté backend

### 2.1 Déployer la migration SQL ← **PRIORITÉ HAUTE**

```bash
cd backend
supabase db push
```

Cela applique `20260502000001_fix_phone_domain_nakora.sql` sur la base de production.
Sans ça, les nouveaux comptes créés depuis un téléphone (sans email réel) auront
leur email auto-généré (`0700000000@phone.nakora.app`) stocké comme vrai email.

### 2.2 Corriger les données existantes (si des comptes ont déjà été créés)

Si des utilisateurs se sont inscrits avant ce fix, leurs `public.users.email` contient
peut-être un email `@phone.nakora.app`. Voici la requête de nettoyage à lancer manuellement :

```sql
UPDATE public.users
SET email = NULL
WHERE email LIKE '%@phone.nakora.app'
   OR email LIKE '%@phone.quantara.app';
```

### 2.3 Configurer le secret `FIREBASE_SERVICE_ACCOUNT_JSON` ← **REQUIS pour les push background**

L'Edge Function `notify-users` envoie les push FCM via l'API FCM v1 (OAuth2).
Elle a besoin du secret suivant dans Supabase Dashboard → **Settings → Edge Functions → Secrets** :

| Clé | Valeur |
|-----|--------|
| `FIREBASE_SERVICE_ACCOUNT_JSON` | JSON complet du service account Firebase |

**Comment l'obtenir** :
1. Firebase Console → Paramètres du projet (⚙️) → Comptes de service
2. Cliquer **"Générer une nouvelle clé privée"**
3. Copier le contenu du fichier JSON téléchargé
4. Le coller comme valeur du secret dans Supabase

> **Sans ce secret, aucun push ne sera envoyé quand l'app est fermée.** La fonction
> logge `[notify-users] No FIREBASE_SERVICE_ACCOUNT_JSON — push disabled` et retourne
> sans erreur (silencieux).

### 2.4 Déployer les Edge Functions (si pas encore fait)

```bash
cd backend
supabase functions deploy notify-users
supabase functions deploy predict-prematch
supabase functions deploy predict-live-t1
supabase functions deploy predict-live-t2
supabase functions deploy generate-combos
supabase functions deploy evaluate-predictions
```

> `notify-users` est appelée par les 4 autres — elle doit être déployée en premier.

### 2.5 Vérifier que les cron jobs sont actifs

Les prédictions et notifications sont déclenchées par des jobs cron configurés via
`pg_cron`. Vérifier dans Supabase Dashboard → Database → Cron Jobs que ces jobs existent
et sont actifs :

| Job | Fréquence | Rôle |
|-----|-----------|------|
| `fetch-matches` | `0 6 * * *` | Récupère les matchs du jour |
| `fetch-lineups` | `*/10 * * * *` | Compositions officielles |
| `predict-prematch` | cron ou trigger post-fetch | Génère les pronos |
| `predict-live-t1` | `*/15 * * * *` | Pronos live T1 |
| `predict-live-t2` | `*/5 * * * *` | Pronos live T2 (55-65 min) |
| `evaluate-predictions` | `*/30 * * * *` | Évalue les résultats |
| `generate-combos` | après predict-prematch | Génère les combinés |

---

## 3. Résumé — Ce qui fait arriver les notifications sur l'app fermée

Chaîne complète :

```
cron → predict-prematch → appelle notify-users
                               ↓
                   Lit push_tokens de la table
                               ↓
                   Envoie FCM v1 (avec FIREBASE_SERVICE_ACCOUNT_JSON)
                               ↓
                   Téléphone reçoit le push même app fermée
                               ↓
                   firebaseMessagingBackgroundHandler() s'exécute (fix 1.1)
                               ↓
                   Notification locale affichée à l'utilisateur
```

Les 3 maillons à valider côté backend : **migration SQL** (2.1), **secret Firebase** (2.3), **Edge Functions déployées** (2.4).

---

*Note rédigée le 02/05/2026 — Équipe mobile Nakora*
