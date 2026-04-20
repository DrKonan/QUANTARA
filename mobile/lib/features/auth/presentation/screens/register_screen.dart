import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/auth_provider.dart';
import '../widgets/auth_text_field.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  bool _otpSent = false;
  bool _registered = false;
  String _fullPhone = '';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  String _buildFullPhone() {
    final raw = _phoneCtrl.text.trim().replaceAll(RegExp(r'[\s\-]'), '');
    if (raw.startsWith('+')) return raw;
    if (raw.startsWith('00')) return '+${raw.substring(2)}';
    // Default Côte d'Ivoire prefix
    return '+225$raw';
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    ref.read(authErrorProvider.notifier).state = null;
    ref.read(authLoadingProvider.notifier).state = true;

    try {
      _fullPhone = _buildFullPhone();
      await ref.read(authServiceProvider).signInWithPhone(phone: _fullPhone);
      if (mounted) setState(() => _otpSent = true);
    } catch (e) {
      ref.read(authErrorProvider.notifier).state = _mapError(e);
    } finally {
      if (mounted) ref.read(authLoadingProvider.notifier).state = false;
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.trim().length < 6) {
      ref.read(authErrorProvider.notifier).state = "Entrez le code à 6 chiffres";
      return;
    }

    ref.read(authErrorProvider.notifier).state = null;
    ref.read(authLoadingProvider.notifier).state = true;

    try {
      await ref.read(authServiceProvider).verifyPhoneOtp(
            phone: _fullPhone,
            token: _otpCtrl.text.trim(),
            username: _nameCtrl.text.trim(),
          );
      if (mounted) setState(() => _registered = true);
    } catch (e) {
      ref.read(authErrorProvider.notifier).state = _mapError(e);
    } finally {
      if (mounted) ref.read(authLoadingProvider.notifier).state = false;
    }
  }

  Future<void> _resendOtp() async {
    ref.read(authErrorProvider.notifier).state = null;
    ref.read(authLoadingProvider.notifier).state = true;
    try {
      await ref.read(authServiceProvider).signInWithPhone(phone: _fullPhone);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Code renvoyé !"),
            backgroundColor: AppColors.emerald,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ref.read(authErrorProvider.notifier).state = _mapError(e);
    } finally {
      if (mounted) ref.read(authLoadingProvider.notifier).state = false;
    }
  }

  String _mapError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('already registered') || msg.contains('user_already_exists')) {
      return "Un compte existe déjà avec ce numéro";
    }
    if (msg.contains('invalid') && msg.contains('otp')) {
      return "Code invalide. Vérifiez et réessayez";
    }
    if (msg.contains('expired')) {
      return "Code expiré. Demandez un nouveau code";
    }
    if (msg.contains('phone') && msg.contains('provider')) {
      return "L'inscription par téléphone n'est pas encore activée. Contactez le support";
    }
    if (msg.contains('rate') || msg.contains('too many')) {
      return "Trop de tentatives. Attendez quelques minutes";
    }
    if (msg.contains('network') || msg.contains('socket')) {
      return "Erreur de connexion. Vérifiez votre internet";
    }
    return "Une erreur est survenue. Réessayez";
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authLoadingProvider);
    final error = ref.watch(authErrorProvider);

    if (_registered) return _buildSuccessView();
    if (_otpSent) return _buildOtpView(isLoading, error);
    return _buildPhoneForm(isLoading, error);
  }

  Widget _buildPhoneForm(bool isLoading, String? error) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            Text(
              "Créer un compte",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              "${AppConstants.trialDurationDays} jours d'essai gratuit inclus",
              style: const TextStyle(color: AppColors.emerald, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 36),

            if (error != null) ...[
              _buildErrorBanner(error),
              const SizedBox(height: 20),
            ],

            // Username
            AuthTextField(
              controller: _nameCtrl,
              label: "Nom d'utilisateur",
              hint: "Ex: jean_dupont",
              prefixIcon: Icons.person_outline,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return "Nom requis";
                if (v.trim().length < 2) return "Nom trop court";
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Phone number
            AuthTextField(
              controller: _phoneCtrl,
              label: "Numéro de téléphone",
              hint: "07 XX XX XX XX",
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _sendOtp(),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return "Numéro requis";
                final clean = v.trim().replaceAll(RegExp(r'[\s\-\+]'), '');
                if (clean.length < 8) return "Numéro trop court";
                if (!RegExp(r'^[0-9]+$').hasMatch(clean)) return "Numéro invalide";
                return null;
              },
            ),
            const SizedBox(height: 8),
            const Text(
              "🇨🇮 Préfixe +225 ajouté automatiquement",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 32),

            // Send OTP button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading ? null : _sendOtp,
                child: isLoading
                    ? const SizedBox(
                        height: 22, width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.background),
                      )
                    : const Text("Recevoir le code WhatsApp"),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpView(bool isLoading, String? error) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text(
            "Vérification",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            "Un code a été envoyé via WhatsApp au $_fullPhone",
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 36),

          if (error != null) ...[
            _buildErrorBanner(error),
            const SizedBox(height: 20),
          ],

          // OTP field
          AuthTextField(
            controller: _otpCtrl,
            label: "Code de vérification",
            hint: "123456",
            prefixIcon: Icons.sms_outlined,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _verifyOtp(),
            validator: (v) {
              if (v == null || v.trim().length < 6) return "Code à 6 chiffres requis";
              return null;
            },
          ),
          const SizedBox(height: 32),

          // Verify button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: isLoading ? null : _verifyOtp,
              child: isLoading
                  ? const SizedBox(
                      height: 22, width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.background),
                    )
                  : const Text("Vérifier et créer mon compte"),
            ),
          ),
          const SizedBox(height: 16),

          // Resend + Back
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  ref.read(authErrorProvider.notifier).state = null;
                  setState(() {
                    _otpSent = false;
                    _otpCtrl.clear();
                  });
                },
                child: const Text("← Modifier le numéro", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ),
              TextButton(
                onPressed: isLoading ? null : _resendOtp,
                child: const Text("Renvoyer le code", style: TextStyle(color: AppColors.gold, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.emerald.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 40),
          ),
          const SizedBox(height: 24),
          Text(
            "Compte créé ! 🎉",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            "Bienvenue ${_nameCtrl.text.trim()} !\nVotre essai gratuit de ${AppConstants.trialDurationDays} jours a commencé.",
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(error, style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
