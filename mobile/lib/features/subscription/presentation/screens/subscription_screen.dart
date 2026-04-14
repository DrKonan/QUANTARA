import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String _selectedPlan = AppConstants.planMonthly;

  static const _plans = [
    _Plan(
      id: AppConstants.planWeekly,
      label: "Hebdo",
      price: "990 FCFA",
      pricePerDay: "141 FCFA/jour",
      duration: "7 jours",
    ),
    _Plan(
      id: AppConstants.planMonthly,
      label: "Mensuel",
      price: "2 990 FCFA",
      pricePerDay: "100 FCFA/jour",
      duration: "30 jours",
      badge: "Populaire",
    ),
    _Plan(
      id: AppConstants.planYearly,
      label: "Annuel",
      price: "24 990 FCFA",
      pricePerDay: "68 FCFA/jour",
      duration: "365 jours",
      badge: "Meilleur prix",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium, color: AppColors.gold, size: 16),
                        SizedBox(width: 4),
                        Text(
                          "Premium",
                          style: TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // Hero
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.gold,
                            AppColors.gold.withValues(alpha: 0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Passez à Premium",
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Accédez à toutes les analyses IA\net maximisez vos gains",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 28),

                    // Features
                    _buildFeature(Icons.analytics_rounded, "Analyses complètes", "Accès à toutes les prédictions détaillées"),
                    _buildFeature(Icons.flash_on_rounded, "Pronos LIVE", "Prédictions en temps réel pendant les matchs"),
                    _buildFeature(Icons.stars_rounded, "Confiance élevée", "Pronos avec taux de confiance > 85%"),
                    _buildFeature(Icons.notifications_active_rounded, "Alertes prioritaires", "Notifications instantanées des meilleurs pronos"),

                    const SizedBox(height: 28),

                    // Plans
                    ...List.generate(_plans.length, (i) {
                      final plan = _plans[i];
                      final isSelected = _selectedPlan == plan.id;
                      return _buildPlanCard(plan, isSelected);
                    }),

                    const SizedBox(height: 24),

                    // Subscribe button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () => _showComingSoon(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_open_rounded, size: 20),
                            SizedBox(width: 10),
                            Text(
                              "S'abonner maintenant",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Payment methods
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _paymentBadge("Wave"),
                        const SizedBox(width: 8),
                        _paymentBadge("Orange Money"),
                        const SizedBox(width: 8),
                        _paymentBadge("MTN"),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      "Annulation possible à tout moment",
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeature(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.gold, size: 20),
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
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(_Plan plan, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gold.withValues(alpha: 0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.gold : AppColors.surfaceLight,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.gold : AppColors.textSecondary,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),

            // Plan info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        plan.label,
                        style: TextStyle(
                          color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (plan.badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.emerald.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            plan.badge!,
                            style: const TextStyle(
                              color: AppColors.emerald,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${plan.duration} · ${plan.pricePerDay}",
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),

            // Price
            Text(
              plan.price,
              style: TextStyle(
                color: isSelected ? AppColors.gold : AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentBadge(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        name,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w500),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.construction_rounded, color: AppColors.gold, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              "Bientôt disponible !",
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Le paiement via Wave, Orange Money et MTN\nsera disponible très prochainement.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Compris"),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _Plan {
  final String id;
  final String label;
  final String price;
  final String pricePerDay;
  final String duration;
  final String? badge;

  const _Plan({
    required this.id,
    required this.label,
    required this.price,
    required this.pricePerDay,
    required this.duration,
    this.badge,
  });
}
