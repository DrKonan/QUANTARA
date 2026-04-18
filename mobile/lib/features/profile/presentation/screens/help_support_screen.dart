import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _email = 'support@quantara.app';

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
                      "Aide & Support",
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
                          color: AppColors.emerald.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.support_agent_rounded,
                            color: AppColors.emerald, size: 32),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        "Comment pouvons-nous\nvous aider ?",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Contact card
                    _buildContactCard(context),

                    const SizedBox(height: 24),

                    // FAQ
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 14),
                      child: Text(
                        "QUESTIONS FRÉQUENTES",
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),

                    _buildFaqItem(
                      "Comment fonctionnent les prédictions ?",
                      "Notre IA analyse les statistiques des équipes, les compositions, la forme récente, "
                          "les confrontations directes et de nombreux autres paramètres pour générer des prédictions "
                          "avec un niveau de confiance. Seuls les pronostics avec un taux de confiance ≥ 80% vous sont proposés.",
                    ),

                    _buildFaqItem(
                      "Que signifient les tendances ?",
                      "Les tendances sont des analyses préliminaires effectuées avant la publication des compositions officielles. "
                          "Elles indiquent la direction probable de notre pronostic. Une fois les compositions disponibles, "
                          "nos prédictions sont affinées et deviennent des pronostics officiels.",
                    ),

                    _buildFaqItem(
                      "Comment est calculé le Win Rate ?",
                      "Le Win Rate est calculé uniquement sur les pronostics officiels que nous vous proposons "
                          "(top picks affinés ≥ 80% et pronos live ≥ 80%). Il représente le pourcentage de prédictions correctes "
                          "parmi celles que nous avons officiellement recommandées.",
                    ),

                    _buildFaqItem(
                      "Comment devenir Premium ?",
                      "Rendez-vous dans Profil → Passer à Premium. Vous pourrez choisir un abonnement hebdomadaire, "
                          "mensuel ou annuel. Le paiement se fait via Wave, Orange Money ou MTN Money.",
                    ),

                    _buildFaqItem(
                      "Puis-je annuler mon abonnement ?",
                      "Oui, vous pouvez annuler votre abonnement à tout moment. Votre accès Premium restera actif "
                          "jusqu'à la fin de la période payée.",
                    ),

                    _buildFaqItem(
                      "Les notifications ne fonctionnent pas",
                      "Vérifiez que les notifications sont activées dans Profil → Notifications. "
                          "Assurez-vous aussi que les notifications de Quantara sont autorisées dans les paramètres de votre appareil. "
                          "Si le problème persiste, contactez notre support.",
                    ),

                    _buildFaqItem(
                      "Comment modifier mon profil ?",
                      "Allez dans Profil → Modifier le profil. Vous pouvez changer votre nom d'utilisateur, "
                          "votre photo de profil et votre numéro de téléphone. L'adresse e-mail ne peut pas être modifiée.",
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

  Widget _buildContactCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.emerald.withValues(alpha: 0.1),
            AppColors.emerald.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.emerald.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          const Text(
            "Besoin d'aide personnalisée ?",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Notre équipe vous répond sous 24h",
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildContactButton(
                  context,
                  icon: Icons.email_rounded,
                  label: "Email",
                  color: AppColors.gold,
                  onTap: () => _sendEmail(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildContactButton(
                  context,
                  icon: Icons.content_copy_rounded,
                  label: "Copier email",
                  color: AppColors.info,
                  onTap: () => _copyEmail(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceLight.withValues(alpha: 0.5)),
      ),
      child: Theme(
        data: ThemeData(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: AppColors.gold,
          collapsedIconColor: AppColors.textSecondary,
          title: Text(
            question,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          children: [
            Text(
              answer,
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.8),
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _email,
      queryParameters: {'subject': 'Support Quantara'},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) _copyEmail(context);
    }
  }

  void _copyEmail(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: _email));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text("Email copié : support@quantara.app"),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
