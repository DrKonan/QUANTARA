import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../auth/domain/auth_provider.dart';
import '../../data/payment_service.dart';
import '../../domain/subscription_provider.dart';
import 'payment_status_screen.dart';
import '../widgets/payment_method_sheet.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  String _selectedPlan = AppConstants.planPro;
  bool _forceShowUpgrade = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService().logViewSubscription();
  }

  List<_Plan> _plans(String currency) {
    return [
      _Plan(
        id: AppConstants.planStarter,
        label: "Starter",
        emoji: "⚽",
        price: AppConstants.formatPrice(
            AppConstants.getPriceInCurrency(AppConstants.planStarter, currency),
            currency),
        subtitle: "5 matchs/jour · Football",
        duration: "/mois",
      ),
      _Plan(
        id: AppConstants.planPro,
        label: "Pro",
        emoji: "🏆",
        price: AppConstants.formatPrice(
            AppConstants.getPriceInCurrency(AppConstants.planPro, currency),
            currency),
        subtitle: "15 matchs/jour · LIVE · 1 combo/jour",
        duration: "/mois",
        badge: "Recommandé",
      ),
      _Plan(
        id: AppConstants.planVip,
        label: "VIP",
        emoji: "👑",
        price: AppConstants.formatPrice(
            AppConstants.getPriceInCurrency(AppConstants.planVip, currency),
            currency),
        subtitle: "Illimité · Tous sports · 3 combos/jour",
        duration: "/mois",
        badge: "Complet",
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final paymentState = ref.watch(paymentNotifierProvider);
    final activeSub = ref.watch(activeSubscriptionProvider);
    final currency = ref.watch(userCurrencyProvider);

    final sub = activeSub.valueOrNull;
    if (sub != null && sub.isActive && !_forceShowUpgrade) {
      return _buildActiveSubscription(sub);
    }

    final plans = _plans(currency);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildHero(currency),
                    const SizedBox(height: 28),

                    _buildFeature(Icons.analytics_rounded, "Analyses complètes",
                        "Pronos avec confiance ≥ 80% garantie"),
                    _buildFeature(Icons.flash_on_rounded, "Pronos LIVE",
                        "Prédictions en temps réel (Pro+)"),
                    _buildFeature(Icons.stars_rounded, "Badge Haute Confiance",
                        "Pronos ≥ 85% mis en avant (Pro+)"),
                    _buildFeature(Icons.casino_rounded, "Combinés IA",
                        "1 combo/jour (Pro) · 3 combos/jour (VIP)"),

                    const SizedBox(height: 28),

                    ...plans.map((plan) =>
                        _buildPlanCard(plan, _selectedPlan == plan.id)),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: paymentState.phase == PaymentPhase.creating
                            ? null
                            : () => _showPaymentMethodSheet(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor:
                              AppColors.gold.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: paymentState.phase == PaymentPhase.creating
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.black54),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.lock_open_rounded, size: 20),
                                  SizedBox(width: 10),
                                  Text(
                                    "S'abonner maintenant",
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _paymentBadge("🔵 Wave"),
                        const SizedBox(width: 8),
                        _paymentBadge("🟠 Orange Money"),
                        const SizedBox(width: 8),
                        _paymentBadge("🟡 MTN"),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _paymentBadge("🟢 Free Money"),
                        const SizedBox(width: 8),
                        _paymentBadge("🔵 Moov Money"),
                      ],
                    ),

                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_rounded,
                            color: AppColors.textSecondary, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          "Paiement sécurisé · Annulation possible à tout moment",
                          style: TextStyle(
                            color: AppColors.textSecondary
                                .withValues(alpha: 0.7),
                            fontSize: 10,
                          ),
                        ),
                      ],
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

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.textPrimary),
          ),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium,
                    color: AppColors.gold, size: 16),
                SizedBox(width: 4),
                Text("Premium",
                    style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(String currency) {
    final starterPrice = AppConstants.formatPrice(
        AppConstants.getPriceInCurrency(AppConstants.planStarter, currency),
        currency);
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.gold, AppColors.gold.withValues(alpha: 0.6)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.rocket_launch_rounded,
              color: Colors.white, size: 36),
        ),
        const SizedBox(height: 20),
        const Text(
          "Passez à Premium",
          style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          "Des pronos IA fiables\nà partir de $starterPrice/mois",
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 14, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildActiveSubscription(Subscription sub) {
    final plan = sub.plan;
    final features = _planFeatures(plan);
    final emoji = _planEmoji(plan);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.emerald.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                          child: Text(emoji,
                              style: const TextStyle(fontSize: 40))),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Vous êtes ${_planLabel(plan)} ! 🎉",
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          _infoRow("Formule", _planLabel(plan)),
                          const Divider(
                              color: AppColors.surfaceLight, height: 20),
                          _infoRow("Expire le", _formatDate(sub.endDate)),
                          const Divider(
                              color: AppColors.surfaceLight, height: 20),
                          _infoRow(
                              "Jours restants", "${sub.remainingDays} jours"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.12)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Vos privilèges",
                            style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 14,
                                fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          ...features.map((f) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded,
                                        color: AppColors.emerald, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(f,
                                          style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 12)),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                    if (plan != AppConstants.planVip) ...[
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _forceShowUpgrade = true),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.12)),
                          ),
                          child: Row(
                            children: [
                              const Text("👑",
                                  style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      plan == AppConstants.planStarter
                                          ? 'Passer à Pro ou VIP'
                                          : 'Passer à VIP',
                                      style: const TextStyle(
                                          color: AppColors.gold,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      plan == AppConstants.planStarter
                                          ? 'Pronos LIVE, combinés IA et plus de matchs'
                                          : 'Matchs illimités, 3 combinés/jour, tous sports',
                                      style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded,
                                  color: AppColors.gold, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ],
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

  List<String> _planFeatures(String plan) {
    switch (plan) {
      case AppConstants.planStarter:
        return [
          '5 matchs analysés par jour',
          'Prédictions IA ≥ 80% de confiance',
          'Football uniquement',
          'Historique et winrate complet',
        ];
      case AppConstants.planPro:
        return [
          '15 matchs analysés par jour',
          'Prédictions IA ≥ 80% de confiance',
          'Football + Basketball',
          'Pronos LIVE en temps réel',
          '1 combiné IA par jour (sûrs)',
          'Cotes bookmaker affichées',
        ];
      case AppConstants.planVip:
        return [
          'Matchs illimités',
          'Prédictions IA ≥ 80% de confiance',
          'Tous les sports',
          'Pronos LIVE en temps réel',
          '3 combinés IA par jour (sûrs + audacieux)',
          'Cotes bookmaker affichées',
          'Alertes prioritaires & support dédié',
        ];
      default:
        return ['1 match par jour (Top Pick)', 'Football uniquement'];
    }
  }

  String _planEmoji(String plan) {
    switch (plan) {
      case AppConstants.planStarter:
        return '⚡';
      case AppConstants.planPro:
        return '🏆';
      case AppConstants.planVip:
        return '👑';
      default:
        return '⚽';
    }
  }

  String _planLabel(String plan) {
    return AppConstants.planLabels[plan] ?? plan;
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13)),
        Text(value,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  void _showPaymentMethodSheet(BuildContext context) {
    final profile = ref.read(userProfileProvider).valueOrNull;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => PaymentMethodSheet(
        selectedPlan: _selectedPlan,
        userPhone: profile?.phone,
        onPay: ({String? currency, String? phone, String? paymentMethod}) {
          Navigator.pop(ctx);
          _initiatePayment(
              currency: currency, phone: phone, paymentMethod: paymentMethod);
        },
      ),
    );
  }

  String _resolveMethodName(String? methodId) {
    if (methodId == null) return 'Mobile Money';
    for (final country in AppConstants.supportedCountries) {
      for (final method in country.methods) {
        if (method.id == methodId) return method.name;
      }
    }
    return methodId;
  }

  Future<void> _initiatePayment(
      {String? currency, String? phone, String? paymentMethod}) async {
    final planLabel =
        AppConstants.planLabels[_selectedPlan] ?? _selectedPlan;
    final cur = currency ?? 'XOF';
    final price = AppConstants.getPriceInCurrency(_selectedPlan, cur);
    final priceLabel = AppConstants.formatPrice(price, cur);
    final methodName = _resolveMethodName(paymentMethod);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Confirmer le paiement",
          style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _confirmRow("Formule", "$planLabel ⭐"),
            const SizedBox(height: 8),
            _confirmRow("Montant", "$priceLabel/mois"),
            const SizedBox(height: 8),
            _confirmRow("Paiement", "via $methodName"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler",
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Confirmer",
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    HapticFeedback.mediumImpact();

    AnalyticsService().logStartPayment(_selectedPlan, 'paydunya');

    final notifier = ref.read(paymentNotifierProvider.notifier);
    await notifier.initiatePayment(
        plan: _selectedPlan,
        currency: cur,
        phone: phone,
        paymentMethod: paymentMethod);

    if (!mounted) return;

    final state = ref.read(paymentNotifierProvider);
    if (state.phase == PaymentPhase.error) {
      _showErrorSnackBar(state.errorMessage ?? "Erreur inconnue");
      return;
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentStatusScreen(
          plan: _selectedPlan,
          currency: cur,
          phone: phone,
        ),
      ),
    );
  }

  Widget _confirmRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13)),
        Text(value,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                Text(title,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(_Plan plan, bool isSelected) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedPlan = plan.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.gold.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.gold : AppColors.surfaceLight,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: isSelected
                        ? AppColors.gold
                        : AppColors.textSecondary,
                    width: 2),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                              color: AppColors.gold,
                              shape: BoxShape.circle)))
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(plan.emoji,
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(plan.label,
                          style: TextStyle(
                              color: isSelected
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      if (plan.badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: AppColors.emerald
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(plan.badge!,
                              style: const TextStyle(
                                  color: AppColors.emerald,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(plan.subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(plan.price,
                    style: TextStyle(
                        color: isSelected
                            ? AppColors.gold
                            : AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                Text(plan.duration,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 10)),
              ],
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
          borderRadius: BorderRadius.circular(6)),
      child: Text(name,
          style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w500)),
    );
  }
}

class _Plan {
  final String id;
  final String label;
  final String emoji;
  final String price;
  final String subtitle;
  final String duration;
  final String? badge;

  const _Plan({
    required this.id,
    required this.label,
    required this.emoji,
    required this.price,
    required this.subtitle,
    required this.duration,
    this.badge,
  });
}
