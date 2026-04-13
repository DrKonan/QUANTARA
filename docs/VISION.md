# Quantara — Vision & Spécifications Produit

> Document de référence. À lire en premier avant tout développement.

---

## 1. Concept

Quantara est une application mobile de **prédictions sportives intelligentes** pilotée par l'IA.

Contrairement aux apps classiques qui proposent des types de paris prédéfinis, Quantara **analyse chaque match dans sa globalité** et détermine automatiquement **l'événement optimal à jouer** : victoire, cartons, corners, BTTS, over/under — tout dépend du contexte du match.

**Philosophie :** On ne prédit pas pour prédire. On cherche la faille logique dans chaque match, et on ne propose un prono que quand il y a une vraie conviction.

---

## 2. Sports & Couverture (V1)

- **Sport :** Football uniquement au lancement
- **Ligues :** Toutes les ligues disponibles via API (africaines + européennes + mondiales)
- **Extension future :** Basketball, Hockey sur glace (V2)

---

## 3. Moteur de Prédiction

### Approche
L'IA ne propose pas un type d'événement figé. Elle :
1. Collecte toutes les données disponibles sur un match
2. Analyse chaque angle possible (résultat, cartons, corners, buts...)
3. Identifie les événements à haute probabilité logique
4. Propose **tous les pronos pertinents** classés par score de confiance

### Déclencheurs de publication
- **Pré-match** : dès que les compositions d'équipes sont connues (généralement 1h avant)
- **Live** : en cours de match, selon la physionomie (possession, pression, cartons...)

### Données analysées
- Compositions d'équipes officielles
- Forme récente (5-10 derniers matchs)
- Stats domicile / extérieur
- Head-to-head historique
- Blessures & suspensions
- Classement & enjeux du match
- Stats live (possession, tirs, corners, cartons) pour le mode live
- Modèle de Poisson pour les buts
- ELO Rating adapté au football

### Format d'un prono
```
Match       : PSG vs Lyon
Événement   : Plus de 3.5 corners pour PSG
Confiance   : 87%
Analyse     : PSG joue à domicile avec 8.2 corners/match en moyenne.
              Lyon défend bas, ce qui génère des situations de corner.
              Sur les 5 derniers H2H, au moins 4 corners PSG à chaque fois.
```

---

## 4. Modèle Freemium & Abonnement

### Période d'essai
- **3 jours gratuits** avec accès à toutes les fonctionnalités premium
- Anti-abus : vérification par numéro de téléphone (pas juste email) pour limiter les créations multiples de comptes
- Device fingerprinting pour détecter les réinstallations

### Plans après l'essai
| Plan | Durée | Réduction |
|------|-------|-----------|
| Hebdomadaire | 7 jours | — |
| Mensuel | 30 jours | ~15% vs hebdo |
| Annuel | 365 jours | ~40% vs hebdo |

### Paiement
- **CinetPay** : Wave, Orange Money, MTN Money, Moov Money
- Marché cible initial : Côte d'Ivoire
- Extension : Afrique de l'Ouest (Sénégal, Mali, Burkina, Guinée...)

---

## 5. Fonctionnalités de l'App

### Écran principal (Home)
- Dashboard avec **stats de performance de Quantara** (taux de réussite global, par ligue, par type d'événement)
- Pronos du jour mis en avant
- Indicateur live si un match est en cours

### Pronos
- Liste des pronos disponibles (pré-match + live)
- Chaque prono affiche : match, événement, confiance, analyse courte (2-3 lignes)
- Filtre par ligue, par confiance, par statut (à venir / live / terminé)

### Notifications push
- Alerte quand un nouveau prono pré-match est disponible
- Alerte live quand l'IA détecte une opportunité en cours de match
- Résultat du prono après le match (gagné ✅ / perdu ❌)

### Historique & Stats
- Tous les pronos passés avec résultats
- Taux de réussite global et par catégorie
- Transparence totale sur les performances

### Compte & Abonnement
- Inscription par email + numéro de téléphone
- Gestion de l'abonnement (renouvellement, annulation)
- Historique des paiements

---

## 6. Architecture Technique

### Mobile
- **Framework :** Flutter (iOS + Android)
- **State management :** Riverpod
- **Navigation :** GoRouter
- **Langues :** Français + Anglais (i18n)

### Backend
- **Plateforme :** Supabase (PostgreSQL + Edge Functions + Auth + Realtime)
- **Moteur IA :** Edge Functions (Deno/TypeScript) + appels LLM pour synthèse
- **Scheduled Jobs :** Fetch matchs quotidien + calcul prédictions pré-match
- **Realtime :** Mises à jour live via Supabase Realtime

### APIs externes
| Service | Usage |
|---------|-------|
| API-Football | Stats matchs, compositions, résultats live |
| CinetPay | Paiements mobile money |
| OpenAI / Anthropic (optionnel) | Synthèse textuelle de l'analyse |

---

## 7. Sécurité & Anti-Abus

- Vérification numéro de téléphone à l'inscription (OTP SMS)
- Device fingerprinting pour détecter les réinstallations frauduleuses
- Un essai gratuit par appareil + par numéro de téléphone
- Rate limiting sur l'API Supabase

---

## 8. Roadmap

### V1 — MVP
- [ ] Auth (email + téléphone OTP)
- [ ] Moteur de prédiction football (pré-match)
- [ ] Dashboard + liste des pronos
- [ ] Abonnement via CinetPay
- [ ] Notifications push (prono disponible + résultat)
- [ ] Historique & stats de performance
- [ ] Français + Anglais

### V2
- [ ] Prédictions live (in-match)
- [ ] Basketball
- [ ] Hockey sur glace
- [ ] Expansion géographique (Sénégal, Mali...)

### V3
- [ ] Communauté / commentaires
- [ ] Intégration bookmakers (liens affiliés)
- [ ] Abonnement via carte bancaire internationale
