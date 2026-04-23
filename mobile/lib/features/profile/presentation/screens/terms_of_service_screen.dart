import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
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
                      "Conditions d'utilisation",
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

                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.gavel_rounded,
                            color: AppColors.gold, size: 32),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        "Conditions Générales d'Utilisation",
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

                    const SizedBox(height: 32),

                    _buildSection(
                      "1. Acceptation des conditions",
                      "En téléchargeant, installant ou utilisant l'application Nakora, "
                      "vous acceptez d'être lié par les présentes Conditions Générales "
                      "d'Utilisation (CGU). Si vous n'acceptez pas ces conditions, "
                      "veuillez ne pas utiliser l'application.\n\n"
                      "Nakora se réserve le droit de modifier ces CGU à tout moment. "
                      "Les modifications prennent effet dès leur publication dans l'application.",
                    ),

                    _buildSection(
                      "2. Description du service",
                      "Nakora est une application d'analyse sportive basée sur "
                      "l'intelligence artificielle. Elle fournit des prédictions et "
                      "analyses pour le football, le basketball et le hockey sur glace.\n\n"
                      "Les prédictions sont fournies à titre informatif uniquement et "
                      "ne constituent en aucun cas des conseils de paris ou d'investissement. "
                      "Nakora ne garantit pas l'exactitude des prédictions.",
                    ),

                    _buildSection(
                      "3. Inscription et compte",
                      "• Vous devez fournir un numéro de téléphone valide pour créer un compte\n"
                      "• Vous êtes responsable de la confidentialité de votre mot de passe\n"
                      "• Un seul compte par personne est autorisé\n"
                      "• Vous devez avoir au moins 18 ans pour utiliser Nakora\n"
                      "• Toute information fournie doit être exacte et à jour",
                    ),

                    _buildSection(
                      "4. Période d'essai",
                      "Chaque nouvel utilisateur bénéficie d'une période d'essai gratuite "
                      "donnant accès aux fonctionnalités VIP. Cette période d'essai est "
                      "limitée à une seule fois par appareil.\n\n"
                      "Toute tentative de contournement de cette limitation (création de "
                      "comptes multiples, manipulation de l'identifiant d'appareil, etc.) "
                      "est strictement interdite et peut entraîner la suspension du compte.",
                    ),

                    _buildSection(
                      "5. Abonnements et paiements",
                      "• Les abonnements sont disponibles en formules Starter, Pro et VIP\n"
                      "• Les prix sont affichés dans la devise locale de l'utilisateur\n"
                      "• Les paiements s'effectuent via Mobile Money (PawaPay, Wave)\n"
                      "• Les abonnements se renouvellent automatiquement sauf annulation\n"
                      "• Aucun remboursement n'est accordé pour la période en cours\n"
                      "• Nakora se réserve le droit de modifier les tarifs avec préavis",
                    ),

                    _buildSection(
                      "6. Utilisation acceptable",
                      "Il est interdit de :\n\n"
                      "• Partager, redistribuer ou revendre les prédictions de Nakora\n"
                      "• Utiliser des robots ou scripts pour accéder au service\n"
                      "• Tenter de contourner les mesures de sécurité\n"
                      "• Utiliser le service à des fins illégales\n"
                      "• Créer plusieurs comptes pour abuser de la période d'essai\n"
                      "• Porter atteinte au fonctionnement de l'application",
                    ),

                    _buildSection(
                      "7. Propriété intellectuelle",
                      "Tous les contenus de Nakora (textes, graphiques, logos, algorithmes, "
                      "prédictions, design) sont protégés par le droit de la propriété "
                      "intellectuelle et appartiennent à Nakora.\n\n"
                      "Toute reproduction, modification ou distribution non autorisée est "
                      "strictement interdite.",
                    ),

                    _buildSection(
                      "8. Limitation de responsabilité",
                      "Nakora fournit ses analyses à titre informatif. En aucun cas "
                      "Nakora ne pourra être tenu responsable :\n\n"
                      "• Des pertes financières liées aux paris sportifs\n"
                      "• De l'inexactitude des prédictions\n"
                      "• Des interruptions de service\n"
                      "• Des dommages indirects résultant de l'utilisation du service\n\n"
                      "Le jeu comporte des risques. Jouez de manière responsable.",
                    ),

                    _buildSection(
                      "9. Suspension et résiliation",
                      "Nakora se réserve le droit de suspendre ou résilier votre compte "
                      "en cas de violation des présentes CGU, sans préavis ni remboursement.\n\n"
                      "Vous pouvez à tout moment supprimer votre compte depuis les paramètres "
                      "de l'application. La suppression est irréversible et entraîne la perte "
                      "de toutes vos données.",
                    ),

                    _buildSection(
                      "10. Protection des données",
                      "Le traitement de vos données personnelles est régi par notre "
                      "Politique de Confidentialité, accessible depuis l'application.\n\n"
                      "En utilisant Nakora, vous consentez à la collecte et au traitement "
                      "de vos données conformément à cette politique.",
                    ),

                    _buildSection(
                      "11. Droit applicable",
                      "Les présentes CGU sont régies par le droit en vigueur en Côte d'Ivoire. "
                      "Tout litige sera soumis aux tribunaux compétents d'Abidjan.\n\n"
                      "Si une disposition des présentes CGU est jugée invalide, les autres "
                      "dispositions restent en vigueur.",
                    ),

                    _buildSection(
                      "12. Contact",
                      "Pour toute question relative aux présentes CGU :\n\n"
                      "📧 Email : support@quantara.app\n"
                      "📱 Application : Aide & Support > Nous contacter",
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
              color: AppColors.gold,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.85),
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
