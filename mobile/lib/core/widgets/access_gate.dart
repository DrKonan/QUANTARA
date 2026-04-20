import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../services/analytics_service.dart';
import '../../features/auth/domain/auth_provider.dart';

/// Shows a lock overlay when the user's plan doesn't meet requirements.
class AccessGate extends ConsumerWidget {
  final String requiredPlan;
  final Widget child;
  final String? message;

  const AccessGate({
    super.key,
    required this.requiredPlan,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final hasAccess = profile?.meetsRequirement(requiredPlan) ?? false;

    if (hasAccess) return child;

    return Stack(
      children: [
        Opacity(opacity: 0.35, child: IgnorePointer(child: child)),
        Positioned.fill(
          child: GestureDetector(
            onTap: () => _showUpgradeSheet(context, profile?.effectivePlan ?? 'free'),
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_rounded, color: AppColors.gold, size: 24),
                  const SizedBox(height: 6),
                  Text(
                    message ?? _defaultMessage,
                    style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String get _defaultMessage {
    switch (requiredPlan) {
      case 'starter': return 'Disponible avec Starter+';
      case 'pro': return 'Disponible avec Pro+';
      case 'vip': return 'Exclusif VIP';
      default: return 'Abonnement requis';
    }
  }

  void _showUpgradeSheet(BuildContext context, String currentPlan) {
    AnalyticsService().logAccessGateHit(requiredPlan);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => UpgradePromptSheet(
        currentPlan: currentPlan,
        requiredPlan: requiredPlan,
      ),
    );
  }
}

/// Bottom sheet that explains features and invites upgrade.
class UpgradePromptSheet extends StatelessWidget {
  final String currentPlan;
  final String requiredPlan;

  const UpgradePromptSheet({
    super.key,
    required this.currentPlan,
    required this.requiredPlan,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: AppColors.gold.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.rocket_launch_rounded, color: AppColors.gold, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            _title,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _subtitle,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          ..._features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(f, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12))),
              ],
            ),
          )),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/subscription');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text(
                "Passer à ${_planLabel(requiredPlan)} 🚀",
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _title {
    switch (requiredPlan) {
      case 'starter': return 'Passez à Starter ⚡';
      case 'pro': return 'Passez à Pro 💎';
      case 'vip': return 'Devenez VIP 👑';
      default: return 'Abonnez-vous';
    }
  }

  String get _subtitle {
    switch (requiredPlan) {
      case 'starter': return 'Débloquez jusqu\'à 5 matchs par jour\navec des pronos IA fiables';
      case 'pro': return 'Pronos LIVE, combinés IA et 15 matchs par jour\npour maximiser vos gains';
      case 'vip': return 'Accès illimité, 3 combinés IA par jour\net toutes les fonctionnalités exclusives';
      default: return 'Accédez à des pronos premium';
    }
  }

  List<String> get _features {
    switch (requiredPlan) {
      case 'starter':
        return [
          '5 matchs analysés par jour',
          'Prédictions IA ≥ 80% de confiance',
          'Historique et winrate complet',
        ];
      case 'pro':
        return [
          '15 matchs par jour · Football + Basketball',
          'Pronos LIVE en temps réel',
          '1 combiné IA par jour',
          'Cotes bookmaker affichées',
        ];
      case 'vip':
        return [
          'Matchs illimités · Tous sports',
          'Pronos LIVE en temps réel',
          '3 combinés IA par jour (sûrs + audacieux)',
          'Alertes prioritaires & support dédié',
        ];
      default:
        return [];
    }
  }

  String _planLabel(String plan) {
    switch (plan) {
      case 'starter': return 'Starter';
      case 'pro': return 'Pro';
      case 'vip': return 'VIP';
      default: return plan;
    }
  }
}

/// Inline upgrade banner for lists/sections.
class UpgradeBanner extends StatelessWidget {
  final String requiredPlan;
  final String text;
  final VoidCallback? onTap;

  const UpgradeBanner({
    super.key,
    required this.requiredPlan,
    required this.text,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => context.go('/subscription'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.gold.withAlpha(15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gold.withAlpha(40)),
        ),
        child: Row(
          children: [
            Text(_emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.gold, size: 14),
          ],
        ),
      ),
    );
  }

  String get _emoji {
    switch (requiredPlan) {
      case 'pro': return '💎';
      case 'vip': return '👑';
      default: return '⚡';
    }
  }
}

/// Match limit reached banner
class MatchLimitBanner extends StatelessWidget {
  final int limit;
  final int viewed;
  final String plan;

  const MatchLimitBanner({
    super.key,
    required this.limit,
    required this.viewed,
    required this.plan,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = limit - viewed;
    final nextPlan = plan == 'free' ? 'starter' : plan == 'starter' ? 'pro' : 'vip';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: remaining <= 0 ? AppColors.error.withAlpha(15) : AppColors.warning.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: remaining <= 0 ? AppColors.error.withAlpha(40) : AppColors.warning.withAlpha(40),
        ),
      ),
      child: Row(
        children: [
          Icon(
            remaining <= 0 ? Icons.block_rounded : Icons.info_outline_rounded,
            color: remaining <= 0 ? AppColors.error : AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              remaining <= 0
                  ? 'Limite atteinte ($limit/$limit matchs). Passez à ${_planLabel(nextPlan)} pour plus.'
                  : '$remaining/$limit matchs restants aujourd\'hui',
              style: TextStyle(
                color: remaining <= 0 ? AppColors.error : AppColors.warning,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (remaining <= 0)
            GestureDetector(
              onTap: () => context.go('/subscription'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Upgrade', style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
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
}
