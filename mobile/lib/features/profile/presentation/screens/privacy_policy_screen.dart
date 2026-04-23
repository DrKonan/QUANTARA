import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: AppColors.textPrimary),
                  ),
                  const Expanded(
                    child: Text(
                      "Confidentialité",
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    // Header
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.shield_rounded,
                            color: AppColors.info, size: 32),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        "Politique de confidentialité",
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        "Dernière mise à jour : Avril 2026",
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    _buildSection(
                      "1. Données collectées",
                      "Nakora collecte uniquement les données nécessaires au fonctionnement de l'application :\n\n"
                          "• Numéro de téléphone (identifiant principal du compte)\n"
                          "• Adresse e-mail (optionnelle, pour récupération de compte)\n"
                          "• Nom d'utilisateur (affiché dans votre profil)\n"
                          "• Photo de profil (optionnelle)\n"
                          "• Pays détecté via l'indicatif téléphonique (pour la devise)\n"
                          "• Token de notification push (pour les alertes)\n"
                          "• Données biométriques locales (Face ID / Touch ID, stockées uniquement sur votre appareil)\n"
                          "• Données d'utilisation anonymisées via Firebase Analytics",
                    ),

                    _buildSection(
                      "2. Utilisation des données",
                      "Vos données sont utilisées exclusivement pour :\n\n"
                          "• Authentifier votre compte et sécuriser l'accès\n"
                          "• Permettre la reconnexion rapide via biométrie (Face ID / Touch ID)\n"
                          "• Détecter votre pays et devise pour l'affichage des tarifs\n"
                          "• Personnaliser votre expérience (préférences, historique de notifications)\n"
                          "• Vous envoyer des notifications de pronostics et résultats\n"
                          "• Améliorer nos algorithmes de prédiction et l'expérience utilisateur\n"
                          "• Gérer vos abonnements et paiements mobiles",
                    ),

                    _buildSection(
                      "3. Stockage et sécurité",
                      "Vos données sont stockées de manière sécurisée sur des serveurs Supabase (infrastructure cloud). "
                          "Les mots de passe sont hashés avec des algorithmes de chiffrement modernes. "
                          "Les communications sont chiffrées via HTTPS/TLS.\n\n"
                          "Les identifiants biométriques sont stockés localement dans le stockage sécurisé de votre appareil "
                          "(Keychain sur iOS, Keystore sur Android) et ne sont jamais transmis à nos serveurs.\n\n"
                          "L'historique de vos notifications est stocké localement sur votre appareil.",
                    ),

                    _buildSection(
                      "4. Paiements",
                      "Les paiements sont traités via PawaPay (mobile money) et Wave. "
                          "Nakora ne stocke aucune donnée financière. Les transactions sont gérées "
                          "intégralement par les opérateurs de paiement. Seuls le statut et la référence "
                          "de la transaction sont conservés pour le suivi de votre abonnement.",
                    ),

                    _buildSection(
                      "5. Partage des données",
                      "Nakora ne vend, ne loue et ne partage jamais vos données personnelles avec des tiers. "
                          "Aucune donnée n'est transmise à des fins publicitaires.\n\n"
                          "Les seuls services tiers utilisés sont :\n"
                          "• Supabase (authentification et base de données)\n"
                          "• Firebase (notifications push et analytics anonymes)\n"
                          "• PawaPay / Wave (traitement des paiements)",
                    ),

                    _buildSection(
                      "6. Vos droits",
                      "Vous disposez des droits suivants :\n\n"
                          "• Accès : consulter vos données dans votre profil\n"
                          "• Rectification : modifier vos informations à tout moment\n"
                          "• Suppression : supprimer votre compte directement dans Profil → Supprimer mon compte\n"
                          "• Désactivation biométrique : désactiver Face ID / Touch ID dans Profil\n"
                          "• Portabilité : exporter vos données sur demande\n\n"
                          "Pour exercer ces droits, contactez-nous à support@nakora.app",
                    ),

                    _buildSection(
                      "7. Notifications",
                      "Vous pouvez gérer vos préférences de notification directement dans l'application "
                          "(Profil → Notifications). Vous pouvez désactiver toutes les notifications à tout moment.\n\n"
                          "L'historique de vos notifications est consultable dans le Centre de notifications "
                          "(icône cloche sur l'accueil) et stocké localement sur votre appareil.",
                    ),

                    _buildSection(
                      "8. Cookies et tracking",
                      "Nakora n'utilise pas de cookies. L'application ne contient aucun tracker publicitaire. "
                          "Firebase Analytics collecte uniquement des données d'utilisation anonymes "
                          "(écrans visités, événements) pour améliorer le service. Aucune donnée personnelle "
                          "identifiable n'est envoyée à Firebase.",
                    ),

                    _buildSection(
                      "9. Contact",
                      "Pour toute question relative à la confidentialité :\n\n"
                          "📧 support@nakora.app\n"
                          "📍 Abidjan, Côte d'Ivoire",
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.8),
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
