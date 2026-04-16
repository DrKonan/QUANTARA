import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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
                      "À propos",
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
                  children: [
                    const SizedBox(height: 40),

                    // Logo
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.gold,
                            AppColors.gold.withValues(alpha: 0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.analytics_rounded,
                          color: Colors.white, size: 44),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      "Quantara",
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "v1.0.0",
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      "Prédictions sportives alimentées\npar l'Intelligence Artificielle",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Sports
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSportBadge("⚽", "Football"),
                        const SizedBox(width: 12),
                        _buildSportBadge("🏀", "Basket"),
                        const SizedBox(width: 12),
                        _buildSportBadge("🏒", "Hockey"),
                      ],
                    ),

                    const SizedBox(height: 36),

                    // Features
                    _buildFeatureRow(
                      Icons.auto_awesome_rounded,
                      AppColors.gold,
                      "IA avancée",
                      "Algorithmes de machine learning entraînés sur des millions de matchs",
                    ),
                    _buildFeatureRow(
                      Icons.speed_rounded,
                      AppColors.emerald,
                      "Temps réel",
                      "Analyses live et mises à jour des pronostics pendant les matchs",
                    ),
                    _buildFeatureRow(
                      Icons.verified_rounded,
                      AppColors.info,
                      "Fiabilité",
                      "Seuil de confiance minimum de 75% pour chaque pronostic",
                    ),
                    _buildFeatureRow(
                      Icons.security_rounded,
                      AppColors.warning,
                      "Sécurité",
                      "Données chiffrées, aucun partage avec des tiers",
                    ),

                    const SizedBox(height: 36),

                    // Separator
                    Divider(
                        color: AppColors.surfaceLight.withValues(alpha: 0.5),
                        height: 1),

                    const SizedBox(height: 24),

                    // Legal
                    Text(
                      "Quantara est une application d'analyse sportive.\n"
                      "Les prédictions sont fournies à titre informatif.\n"
                      "Le jeu comporte des risques, jouez de manière responsable.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                        fontSize: 11,
                        height: 1.6,
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      "© 2026 Quantara — Tous droits réservés",
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Fait avec ❤️ à Abidjan, Côte d'Ivoire",
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
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

  Widget _buildSportBadge(String emoji, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(
      IconData icon, Color color, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
