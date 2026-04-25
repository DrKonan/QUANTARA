import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../auth/domain/auth_provider.dart';
import '../../data/payment_service.dart';
import '../../domain/subscription_provider.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  String _selectedPlan = AppConstants.planPro;

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
        price: AppConstants.formatPrice(AppConstants.getPriceInCurrency(AppConstants.planStarter, currency), currency),
        subtitle: "5 matchs/jour · Football",
        duration: "/mois",
      ),
      _Plan(
        id: AppConstants.planPro,
        label: "Pro",
        emoji: "🏆",
        price: AppConstants.formatPrice(AppConstants.getPriceInCurrency(AppConstants.planPro, currency), currency),
        subtitle: "15 matchs/jour · LIVE · 1 combo/jour",
        duration: "/mois",
        badge: "Recommandé",
      ),
      _Plan(
        id: AppConstants.planVip,
        label: "VIP",
        emoji: "👑",
        price: AppConstants.formatPrice(AppConstants.getPriceInCurrency(AppConstants.planVip, currency), currency),
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

    // If already premium, show active subscription info
    final sub = activeSub.valueOrNull;
    if (sub != null && sub.isActive) {
      return _buildActiveSubscription(sub);
    }

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

                    _buildFeature(Icons.analytics_rounded, "Analyses complètes", "Pronos avec confiance ≥ 80% garantie"),
                    _buildFeature(Icons.flash_on_rounded, "Pronos LIVE", "Prédictions en temps réel (Pro+)"),
                    _buildFeature(Icons.stars_rounded, "Badge Haute Confiance", "Pronos ≥ 85% mis en avant (Pro+)"),
                    _buildFeature(Icons.casino_rounded, "Combinés IA", "1 combo/jour (Pro) · 3 combos/jour (VIP)"),

                    const SizedBox(height: 28),

                    ...List.generate(_plans(currency).length, (i) {
                      final plan = _plans(currency)[i];
                      return _buildPlanCard(plan, _selectedPlan == plan.id);
                    }),

                    const SizedBox(height: 24),

                    // Subscribe button
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
                          disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: paymentState.phase == PaymentPhase.creating
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black54),
                              )
                            : const Row(
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
                        const Icon(Icons.lock_rounded, color: AppColors.textSecondary, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          "Paiement sécurisé · Annulation possible à tout moment",
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(alpha: 0.7),
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

  // ── App Bar ──
  Widget _buildAppBar() {
    return Padding(
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
                Text("Premium", style: TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero Section ──
  Widget _buildHero(String currency) {
    final starterPrice = AppConstants.formatPrice(
      AppConstants.getPriceInCurrency(AppConstants.planStarter, currency), currency);
    return Column(
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [AppColors.gold, AppColors.gold.withValues(alpha: 0.6)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 20),
        const Text(
          "Passez à Premium",
          style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          "Des pronos IA fiables\nà partir de $starterPrice/mois",
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
        ),
      ],
    );
  }

  // ── Active Subscription View ──
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
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.emerald.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 40))),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Vous êtes ${_planLabel(plan)} ! 🎉",
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),
                    // Subscription info card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          _infoRow("Formule", _planLabel(plan)),
                          const Divider(color: AppColors.surfaceLight, height: 20),
                          _infoRow("Expire le", _formatDate(sub.endDate)),
                          const Divider(color: AppColors.surfaceLight, height: 20),
                          _infoRow("Jours restants", "${sub.remainingDays} jours"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Plan features list
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.gold.withAlpha(30)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Vos privilèges",
                            style: TextStyle(color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          ...features.map((f) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(f, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                                ),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                    // Upgrade prompt if not VIP
                    if (plan != AppConstants.planVip) ...[
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: () => setState(() {}), // Refresh to show plan picker
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withAlpha(10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.gold.withAlpha(30)),
                          ),
                          child: Row(
                            children: [
                              const Text("👑", style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      plan == AppConstants.planStarter ? 'Passer à Pro ou VIP' : 'Passer à VIP',
                                      style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      plan == AppConstants.planStarter
                                          ? 'Pronos LIVE, combinés IA et plus de matchs'
                                          : 'Matchs illimités, 3 combinés/jour, tous sports',
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.gold, size: 14),
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
      case AppConstants.planStarter: return '⚡';
      case AppConstants.planPro: return '🏆';
      case AppConstants.planVip: return '👑';
      default: return '⚽';
    }
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  String _planLabel(String plan) {
    switch (plan) {
      case 'starter': return 'Starter';
      case 'pro': return 'Pro';
      case 'vip': return 'VIP';
      default: return plan;
    }
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
      builder: (ctx) => _PaymentMethodSheet(
        selectedPlan: _selectedPlan,
        userPhone: profile?.phone,
        onPay: ({String? currency, String? phone, String? paymentMethod}) {
          Navigator.pop(ctx);
          _initiatePayment(currency: currency, phone: phone, paymentMethod: paymentMethod);
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

  Future<void> _initiatePayment({String? currency, String? phone, String? paymentMethod}) async {
    // Show confirmation dialog first
    final planLabel = AppConstants.planLabels[_selectedPlan] ?? _selectedPlan;
    final cur = currency ?? 'XOF';
    final price = AppConstants.getPriceInCurrency(_selectedPlan, cur);
    final priceLabel = AppConstants.formatPrice(price, cur);
    final methodName = _resolveMethodName(paymentMethod);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Confirmer le paiement",
          style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
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
            child: const Text("Annuler", style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Confirmer", style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    HapticFeedback.mediumImpact();

    AnalyticsService().logStartPayment(_selectedPlan, 'paydunya');

    final notifier = ref.read(paymentNotifierProvider.notifier);
    await notifier.initiatePayment(plan: _selectedPlan, currency: cur, phone: phone, paymentMethod: paymentMethod);

    if (!mounted) return;

    final state = ref.read(paymentNotifierProvider);
    if (state.phase == PaymentPhase.error) {
      _showErrorSnackBar(state.errorMessage ?? "Erreur inconnue");
      return;
    }

    if (!mounted) return;
    // Navigate to payment status screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PaymentStatusPage(
          paymentId: state.result!.paymentId,
          plan: _selectedPlan,
          checkoutUrl: state.result?.checkoutUrl,
          currency: cur,
          paymentType: state.result?.paymentType ?? PaymentType.ussd,
          paymentMethodName: state.result?.paymentMethodName,
          phone: phone,
        ),
      ),
    );
  }

  Widget _confirmRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Reusable widgets ──
  Widget _buildFeature(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
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
                Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
          color: isSelected ? AppColors.gold.withValues(alpha: 0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.gold : AppColors.surfaceLight,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? AppColors.gold : AppColors.textSecondary, width: 2),
              ),
              child: isSelected
                  ? Center(child: Container(width: 12, height: 12, decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle)))
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(plan.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(plan.label, style: TextStyle(color: isSelected ? AppColors.textPrimary : AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w600)),
                      if (plan.badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.emerald.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                          child: Text(plan.badge!, style: const TextStyle(color: AppColors.emerald, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(plan.subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(plan.price, style: TextStyle(color: isSelected ? AppColors.gold : AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                Text(plan.duration, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
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
      decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(6)),
      child: Text(name, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w500)),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Payment Method Bottom Sheet — PayDunya hosted checkout
// ══════════════════════════════════════════════════════════════
class _PaymentMethodSheet extends StatefulWidget {
  final String selectedPlan;
  final String? userPhone;
  final void Function({String? currency, String? phone, String? paymentMethod}) onPay;

  const _PaymentMethodSheet({required this.selectedPlan, required this.onPay, this.userPhone});

  @override
  State<_PaymentMethodSheet> createState() => _PaymentMethodSheetState();
}

class _PaymentMethodSheetState extends State<_PaymentMethodSheet> {
  late PaymentCountry _selectedCountry;
  PaymentMethod? _selectedMethod;
  final _phoneCtrl = TextEditingController();
  bool _phoneValid = false;

  bool get _isWave => _selectedMethod?.isWave ?? false;
  bool get _canPay => _selectedMethod != null && (_isWave || _phoneValid);

  @override
  void initState() {
    super.initState();
    _selectedCountry = AppConstants.countryFromPhone(widget.userPhone) ?? AppConstants.defaultCountry;
    // Pre-fill local number (strip dial code)
    if (widget.userPhone != null) {
      final dc = _selectedCountry.dialCode;
      final raw = widget.userPhone!.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      final stripped = raw.startsWith('+$dc') ? raw.substring(dc.length + 1)
          : raw.startsWith(dc) ? raw.substring(dc.length) : raw;
      _phoneCtrl.text = stripped;
      _validatePhone();
    }
    _phoneCtrl.addListener(_validatePhone);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _validatePhone() {
    final clean = _phoneCtrl.text.trim().replaceAll(RegExp(r'[\s\-]'), '');
    setState(() => _phoneValid = clean.length >= 8);
  }

  void _onCountryChanged(PaymentCountry c) {
    setState(() {
      _selectedCountry = c;
      _selectedMethod = null;
      _phoneCtrl.clear();
      _phoneValid = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currency = AppConstants.currencyForCountry(_selectedCountry.code);

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),

          // ── Title ──
          const Text(
            "Paiement",
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            "Choisissez votre moyen de paiement mobile",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // ── Country selector ──
          const Text("Votre pays", style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _showCountryPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Row(
                children: [
                  Text(_selectedCountry.flag, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_selectedCountry.name}  (+${_selectedCountry.dialCode})',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 22),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Method selector ──
          const Text("Moyen de paiement", style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ..._selectedCountry.methods.map((m) {
            final isSelected = _selectedMethod?.id == m.id;
            final color = Color(m.color);
            return GestureDetector(
              onTap: () => setState(() => _selectedMethod = m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? color.withValues(alpha: 0.12) : AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? color : AppColors.surfaceLight,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                      child: Icon(
                        m.isWave ? Icons.waves_rounded : Icons.phone_android_rounded,
                        color: color, size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.name, style: TextStyle(color: isSelected ? color : AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                          Text(
                            m.isWave ? "Redirection vers l'appli Wave" : "Push USSD sur votre téléphone",
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle_rounded, color: color, size: 20),
                  ],
                ),
              ),
            );
          }),

          // ── Phone input (USSD only) ──
          if (_selectedMethod != null && !_isWave) ...[
            const SizedBox(height: 8),
            const Text("Numéro de téléphone", style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.surfaceLight),
                  ),
                  child: Text(
                    '+${_selectedCountry.dialCode}',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'X' * _selectedCountry.localDigits,
                      hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.4)),
                      prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.textSecondary, size: 20),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.surfaceLight)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.surfaceLight)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.gold)),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // ── Hint ──
          if (_selectedMethod != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  _isWave ? Icons.open_in_new_rounded : Icons.phone_callback_outlined,
                  size: 13, color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _isWave
                        ? "L'appli Wave s'ouvrira pour confirmer le paiement."
                        : "Un code USSD sera envoyé sur votre téléphone ${_selectedCountry.flag}.",
                    style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.8), fontSize: 11),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // ── Pay button ──
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _canPay
                  ? () {
                      final phone = _isWave ? null
                          : '+${_selectedCountry.dialCode}${_phoneCtrl.text.trim().replaceAll(RegExp(r'[\s\-]'), '')}';
                      widget.onPay(
                        currency: currency,
                        phone: phone,
                        paymentMethod: _selectedMethod!.id,
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                disabledBackgroundColor: AppColors.surfaceLight,
                foregroundColor: Colors.black,
                disabledForegroundColor: AppColors.textSecondary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isWave ? Icons.waves_rounded : Icons.smartphone_rounded,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedMethod != null
                        ? "Payer avec ${_selectedMethod!.name}"
                        : "Choisissez un moyen de paiement",
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text("Choisir votre pays", style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: AppConstants.supportedCountries.length,
                itemBuilder: (ctx, i) {
                  final country = AppConstants.supportedCountries[i];
                  final isSelected = country.code == _selectedCountry.code;
                  return ListTile(
                    leading: Text(country.flag, style: const TextStyle(fontSize: 24)),
                    title: Text(country.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                    subtitle: Text(
                      country.methods.map((m) => m.name).join(' · '),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                    trailing: Text('+${country.dialCode}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    selected: isSelected,
                    selectedTileColor: AppColors.gold.withValues(alpha: 0.08),
                    onTap: () {
                      _onCountryChanged(country);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Payment Status Page (inline — shown after payment initiation)
// ══════════════════════════════════════════════════════════════
class _PaymentStatusPage extends ConsumerStatefulWidget {
  final String paymentId;
  final String plan;
  final String? checkoutUrl;
  final String currency;
  final PaymentType paymentType;
  final String? paymentMethodName;
  final String? phone;

  const _PaymentStatusPage({
    required this.paymentId,
    required this.plan,
    this.checkoutUrl,
    this.currency = 'XOF',
    this.paymentType = PaymentType.ussd,
    this.paymentMethodName,
    this.phone,
  });

  @override
  ConsumerState<_PaymentStatusPage> createState() => _PaymentStatusPageState();
}

class _PaymentStatusPageState extends ConsumerState<_PaymentStatusPage> {
  bool _analyticsLogged = false;

  @override
  void initState() {
    super.initState();
    // Auto-open the PayDunya checkout page
    if (widget.checkoutUrl != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openCheckout());
    }
  }

  Future<void> _openCheckout() async {
    final url = widget.checkoutUrl;
    if (url == null) return;
    try {
      // Use in-app browser (SFSafariViewController on iOS) so Wave deep links
      // are handled correctly without leaving the app context.
      await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
    } catch (_) {
      // If launcher fails, show the URL manually
    }
  }

  void _logOutcome(PaymentPhase phase, String? errorMessage) {
    if (_analyticsLogged) return;
    if (phase == PaymentPhase.success) {
      _analyticsLogged = true;
      AnalyticsService().logPaymentSuccess(widget.plan, 'paydunya');
    } else if (phase == PaymentPhase.error) {
      _analyticsLogged = true;
      AnalyticsService().logPaymentFailure(widget.plan, errorMessage ?? 'unknown');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentNotifierProvider);
    _logOutcome(state.phase, state.errorMessage);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatusIcon(state.phase),
                const SizedBox(height: 24),
                Text(
                  _statusTitle(state.phase),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _statusMessage(state),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                if (state.phase == PaymentPhase.waitingConfirmation) ...[
                  const SizedBox(
                    width: 32, height: 32,
                    child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.gold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Vérification en cours...",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  if (widget.paymentType == PaymentType.wave && widget.checkoutUrl != null)
                    TextButton.icon(
                      onPressed: _openCheckout,
                      icon: const Icon(Icons.waves_rounded, size: 18),
                      label: const Text("Rouvrir l'appli Wave"),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF1BA8F0)),
                    ),
                ],

                if (state.phase == PaymentPhase.success) ...[
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        ref.read(paymentNotifierProvider.notifier).reset();
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emerald,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("C'est parti ! 🚀", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],

                if (state.phase == PaymentPhase.error) ...[
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        ref.read(paymentNotifierProvider.notifier).reset();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceLight,
                        foregroundColor: AppColors.textPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Réessayer", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(PaymentPhase phase) {
    switch (phase) {
      case PaymentPhase.success:
        return Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: AppColors.emerald.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 48),
        );
      case PaymentPhase.error:
        return Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: const Icon(Icons.error_rounded, color: AppColors.error, size: 48),
        );
      default:
        return Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: const Icon(Icons.hourglass_top_rounded, color: AppColors.gold, size: 44),
        );
    }
  }

  String _statusTitle(PaymentPhase phase) {
    switch (phase) {
      case PaymentPhase.success: return "Paiement confirmé ! 🎉";
      case PaymentPhase.error: return "Paiement échoué";
      default: return "En attente de confirmation";
    }
  }

  String _statusMessage(PaymentState state) {
    final planLabel = AppConstants.planLabels[widget.plan] ?? widget.plan;
    final priceLabel = AppConstants.formatPrice(
      AppConstants.getPriceInCurrency(widget.plan, widget.currency), widget.currency);
    final methodName = widget.paymentMethodName ?? 'votre opérateur';
    switch (state.phase) {
      case PaymentPhase.success:
        return "Votre abonnement $planLabel est maintenant actif ! 🎉\nProfitez de toutes vos fonctionnalités exclusives.";
      case PaymentPhase.error:
        return state.errorMessage ?? "Une erreur est survenue. Veuillez réessayer.";
      default:
        if (widget.paymentType == PaymentType.wave) {
          return "L'appli Wave a été ouverte pour confirmer votre paiement de $priceLabel.\nRevenez ici une fois le paiement effectué.";
        }
        final phoneHint = widget.phone != null ? ' au ${widget.phone}' : '';
        return "Un code USSD a été envoyé$phoneHint via $methodName.\nEntrez votre code PIN pour valider le paiement de $priceLabel.";
    }
  }
}

// ── Plan Model ──
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
