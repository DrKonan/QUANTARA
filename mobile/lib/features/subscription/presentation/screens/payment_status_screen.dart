import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/analytics_service.dart';
import '../../data/payment_service.dart';
import '../../domain/subscription_provider.dart';

class PaymentStatusScreen extends ConsumerStatefulWidget {
  final String plan;
  final String currency;
  final String? phone;

  const PaymentStatusScreen({
    super.key,
    required this.plan,
    required this.currency,
    this.phone,
  });

  @override
  ConsumerState<PaymentStatusScreen> createState() =>
      _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends ConsumerState<PaymentStatusScreen>
    with WidgetsBindingObserver {
  StreamSubscription<Uri>? _deepLinkSub;
  bool _manualCheckLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Listen to deep links while screen is visible
    _deepLinkSub = AppLinks().uriLinkStream.listen(_handleDeepLink);

    // Handle the case where the app was opened cold via a deep link
    AppLinks().getInitialLink().then((uri) {
      if (uri != null && mounted) _handleDeepLink(uri);
    });

    // Open checkout URL on first render
    final checkoutUrl = ref.read(paymentNotifierProvider).result?.checkoutUrl;
    if (checkoutUrl != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _openCheckout(checkoutUrl));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deepLinkSub?.cancel();
    super.dispose();
  }

  // Called when the user switches back to the app from their mobile money app
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(paymentNotifierProvider.notifier).forceCheckNow();
    }
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme != 'nakora' || uri.host != 'payment') return;
    final status = uri.queryParameters['status'] ?? 'error';
    final notifier = ref.read(paymentNotifierProvider.notifier);
    if (status == 'success') {
      notifier.forceCheckNow();
    } else {
      notifier.handleCancelFromDeepLink();
    }
  }

  Future<void> _openCheckout(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
      // Browser closed — check immediately instead of waiting for next poll
      if (mounted) ref.read(paymentNotifierProvider.notifier).forceCheckNow();
    } catch (_) {}
  }

  Future<void> _manualCheck() async {
    setState(() => _manualCheckLoading = true);
    await ref.read(paymentNotifierProvider.notifier).forceCheckNow();
    if (mounted) setState(() => _manualCheckLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentNotifierProvider);

    // Analytics via listener — never from build()
    ref.listen<PaymentState>(paymentNotifierProvider, (previous, next) {
      if (previous?.phase == next.phase) return;
      if (next.phase == PaymentPhase.success) {
        AnalyticsService().logPaymentSuccess(widget.plan, 'paydunya');
      } else if (next.phase == PaymentPhase.error) {
        AnalyticsService()
            .logPaymentFailure(widget.plan, next.errorMessage ?? 'unknown');
      }
    });

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
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _statusMessage(state),
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                if (state.phase == PaymentPhase.waitingConfirmation) ...[
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                        strokeWidth: 3, color: AppColors.gold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Vérification en cours...",
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),

                  // Reopen checkout app (redirect flow only)
                  if (state.result?.paymentType == PaymentType.redirect &&
                      state.result?.checkoutUrl != null)
                    TextButton.icon(
                      onPressed: () =>
                          _openCheckout(state.result!.checkoutUrl!),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(
                          "Rouvrir l'appli ${state.result?.paymentMethodName ?? 'paiement'}"),
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF1BA8F0)),
                    ),

                  const SizedBox(height: 8),

                  // Manual check button — lets user trigger a DB check themselves
                  TextButton.icon(
                    onPressed: _manualCheckLoading ? null : _manualCheck,
                    icon: _manualCheckLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.textSecondary),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text("J'ai déjà payé — Vérifier maintenant"),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary),
                  ),
                ],

                if (state.phase == PaymentPhase.success) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        ref.read(paymentNotifierProvider.notifier).reset();
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emerald,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("C'est parti ! 🚀",
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],

                if (state.phase == PaymentPhase.error) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        ref.read(paymentNotifierProvider.notifier).reset();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceLight,
                        foregroundColor: AppColors.textPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Réessayer",
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
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
          width: 80,
          height: 80,
          decoration: BoxDecoration(
              color: AppColors.emerald.withValues(alpha: 0.15),
              shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_rounded,
              color: AppColors.emerald, size: 48),
        );
      case PaymentPhase.error:
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.15),
              shape: BoxShape.circle),
          child: const Icon(Icons.error_rounded,
              color: AppColors.error, size: 48),
        );
      default:
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              shape: BoxShape.circle),
          child: const Icon(Icons.hourglass_top_rounded,
              color: AppColors.gold, size: 44),
        );
    }
  }

  String _statusTitle(PaymentPhase phase) {
    switch (phase) {
      case PaymentPhase.success:
        return "Paiement confirmé ! 🎉";
      case PaymentPhase.error:
        return "Paiement échoué";
      default:
        return "En attente de confirmation";
    }
  }

  String _statusMessage(PaymentState state) {
    final planLabel = AppConstants.planLabels[widget.plan] ?? widget.plan;
    final priceLabel = AppConstants.formatPrice(
        AppConstants.getPriceInCurrency(widget.plan, widget.currency),
        widget.currency);
    final methodName = state.result?.paymentMethodName ?? 'votre opérateur';

    switch (state.phase) {
      case PaymentPhase.success:
        return "Votre abonnement $planLabel est maintenant actif ! 🎉\nProfitez de toutes vos fonctionnalités exclusives.";
      case PaymentPhase.error:
        return state.errorMessage ??
            "Une erreur est survenue. Veuillez réessayer.";
      default:
        if (state.result?.paymentType == PaymentType.redirect) {
          return "L'appli $methodName a été ouverte pour confirmer votre paiement de $priceLabel.\nRevenez ici une fois le paiement effectué.";
        }
        if (state.result?.ussdMessage != null) {
          return state.result!.ussdMessage!;
        }
        final phoneHint = widget.phone != null ? ' au ${widget.phone}' : '';
        return "Un code USSD a été envoyé$phoneHint via $methodName.\nEntrez votre code PIN pour valider le paiement de $priceLabel.";
    }
  }
}
