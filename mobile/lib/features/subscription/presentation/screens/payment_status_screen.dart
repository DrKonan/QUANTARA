import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/subscription_provider.dart';
import '../../data/payment_service.dart';

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
  ConsumerState<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends ConsumerState<PaymentStatusScreen>
    with WidgetsBindingObserver {
  bool _deepLinkOpened = false;
  StreamSubscription<Uri>? _linkSub;
  final TextEditingController _otpCtrl = TextEditingController();
  bool _otpSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Listen for incoming nakora://payment deep links
    final appLinks = AppLinks();
    _linkSub = appLinks.uriLinkStream.listen(_onDeepLink);

    // Auto-open the checkout URL on first render (for deeplink/redirect types)
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOpenUrl());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    _otpCtrl.dispose();
    super.dispose();
  }

  // App returns from foreground → trigger immediate status check
  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.resumed) {
      final phase = ref.read(paymentNotifierProvider).phase;
      if (phase == PaymentPhase.waitingConfirmation) {
        ref.read(paymentNotifierProvider.notifier).forceCheckNow();
      }
    }
  }

  void _onDeepLink(Uri uri) {
    if (uri.scheme == 'nakora' && uri.host == 'payment') {
      final status    = uri.queryParameters['status'] ?? '';
      final paymentId = uri.queryParameters['payment_id'] ?? '';
      ref.read(paymentNotifierProvider.notifier).handleDeepLinkReturn(status, paymentId);
    }
  }

  void _maybeOpenUrl() {
    if (_deepLinkOpened) return;
    final result = ref.read(paymentNotifierProvider).result;
    if (result == null) return;
    if (result.paymentType == PaymentType.deeplink ||
        result.paymentType == PaymentType.redirect) {
      final url = result.checkoutUrl;
      if (url != null && url.isNotEmpty) {
        _deepLinkOpened = true;
        _openUrl(url);
      }
    }
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final canOpen = await canLaunchUrl(uri);
      if (canOpen) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('[PaymentStatus] Cannot open URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentNotifierProvider);

    return PopScope(
      canPop: state.phase == PaymentPhase.success || state.phase == PaymentPhase.error || state.phase == PaymentPhase.otpRequired,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && state.phase == PaymentPhase.waitingConfirmation) {
          _confirmCancel(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
            onPressed: () async {
              if (state.phase == PaymentPhase.waitingConfirmation) {
                final cancel = await _confirmCancel(context);
                if (cancel == true && mounted) {
                  ref.read(paymentNotifierProvider.notifier).handleCancel();
                  Navigator.of(context).pop();
                }
              } else {
                ref.read(paymentNotifierProvider.notifier).reset();
                Navigator.of(context).pop();
              }
            },
          ),
          title: const Text('Paiement', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: switch (state.phase) {
              PaymentPhase.creating => _buildCreating(),
              PaymentPhase.waitingConfirmation => _buildWaiting(state),
              PaymentPhase.otpRequired => _buildOtpInput(state),
              PaymentPhase.success => _buildSuccess(),
              PaymentPhase.error => _buildError(state),
              _ => const SizedBox.shrink(),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCreating() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.gold),
          SizedBox(height: 20),
          Text('Initialisation du paiement\u2026',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildWaiting(PaymentState state) {
    final result = state.result;
    final isUssd = result?.paymentType == PaymentType.ussd;
    final methodName = result?.paymentMethodName ?? 'Mobile Money';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isUssd) ...[
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone_in_talk, color: AppColors.gold, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              'Vérifiez votre téléphone',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'Une demande de paiement a été envoyée sur votre numéro ${widget.phone ?? ""}.\nEntrez votre code PIN $methodName pour valider.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
            ),
          ] else ...[
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(color: AppColors.gold, strokeWidth: 3),
            ),
            const SizedBox(height: 24),
            const Text(
              'Paiement en cours\u2026',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              'Completez le paiement dans l\'application ouverte,\npuis revenez ici.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
            ),
          ],
          const SizedBox(height: 32),
          if (result?.checkoutUrl != null)
            TextButton.icon(
              onPressed: () => _openUrl(result!.checkoutUrl!),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Rouvrir l\'application de paiement'),
              style: TextButton.styleFrom(foregroundColor: AppColors.gold),
            ),
          const SizedBox(height: 8),
          const Text(
            'Vérification automatique en cours\u2026',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 6),
          const SizedBox(width: 120, child: LinearProgressIndicator(color: AppColors.gold, backgroundColor: Colors.transparent)),
        ],
      ),
    );
  }

  Widget _buildOtpInput(PaymentState state) {
    final instructions = state.result?.otpInstructions ?? 'Composez le code USSD pour obtenir votre OTP.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        const Icon(Icons.lock_outline, color: AppColors.gold, size: 48),
        const SizedBox(height: 16),
        const Text(
          'Code de paiement requis',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Text(
          instructions,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          maxLength: 8,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 6),
          decoration: InputDecoration(
            counterText: '',
            hintText: '------',
            hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.3), letterSpacing: 6),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _otpSubmitting ? null : _submitOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _otpSubmitting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : const Text('Valider le code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    final planLabel = {'starter': 'Starter', 'pro': 'Pro', 'vip': 'VIP'}[widget.plan] ?? widget.plan;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 72),
          const SizedBox(height: 20),
          const Text(
            'Paiement confirmé !',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            'Votre abonnement $planLabel est maintenant actif.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Continuer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildError(PaymentState state) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 72),
          const SizedBox(height: 20),
          const Text(
            'Paiement échoué',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            state.errorMessage ?? 'Une erreur est survenue. Veuillez réessayer.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              ref.read(paymentNotifierProvider.notifier).reset();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Réessayer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.isEmpty) return;
    setState(() => _otpSubmitting = true);
    await ref.read(paymentNotifierProvider.notifier).submitOtp(otp);
    if (mounted) setState(() => _otpSubmitting = false);
    // Auto-open URL if now in waiting state with a checkout URL
    _maybeOpenUrl();
  }

  Future<bool?> _confirmCancel(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Annuler le paiement ?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Votre paiement est en cours. Êtes-vous sûr de vouloir annuler ?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuer le paiement', style: TextStyle(color: AppColors.gold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Annuler', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
