import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/auth_provider.dart';
import '../widgets/auth_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  bool _usePhone = true; // Phone by default
  bool _otpSent = false;
  String _fullPhone = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  String _buildFullPhone() {
    final raw = _phoneCtrl.text.trim().replaceAll(RegExp(r'[\s\-]'), '');
    if (raw.startsWith('+')) return raw;
    if (raw.startsWith('00')) return '+${raw.substring(2)}';
    return '+225$raw';
  }

  Future<void> _loginEmail() async {
    if (!_formKey.currentState!.validate()) return;

    ref.read(authErrorProvider.notifier).state = null;
    ref.read(authLoadingProvider.notifier).state = true;

    try {
      await ref.read(authServiceProvider).signIn(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
          );
    } catch (e) {
      ref.read(authErrorProvider.notifier).state = _mapError(e);
    } finally {
      if (mounted) ref.read(authLoadingProvider.notifier).state = false;
    }
  }

  Future<void> _sendPhoneOtp() async {
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
          );
    } catch (e) {
      ref.read(authErrorProvider.notifier).state = _mapError(e);
    } finally {
      if (mounted) ref.read(authLoadingProvider.notifier).state = false;
    }
  }

  String _mapError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid login credentials') || msg.contains('invalid_credentials')) {
      return "Email ou mot de passe incorrect";
    }
    if (msg.contains('email not confirmed')) {
      return "Veuillez confirmer votre email";
    }
    if (msg.contains('invalid') && msg.contains('otp')) {
      return "Code invalide. Vérifiez et réessayez";
    }
    if (msg.contains('expired')) {
      return "Code expiré. Demandez un nouveau code";
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

    if (_usePhone && _otpSent) return _buildOtpView(isLoading, error);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            Text(
              "Bon retour !",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Connectez-vous pour accéder à vos prédictions",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),

            // Toggle phone / email
            Row(
              children: [
                _buildToggle("📱 Téléphone", _usePhone, () {
                  ref.read(authErrorProvider.notifier).state = null;
                  setState(() => _usePhone = true);
                }),
                const SizedBox(width: 10),
                _buildToggle("📧 Email", !_usePhone, () {
                  ref.read(authErrorProvider.notifier).state = null;
                  setState(() => _usePhone = false);
                }),
              ],
            ),
            const SizedBox(height: 24),

            if (error != null) ...[
              _buildErrorBanner(error),
              const SizedBox(height: 20),
            ],

            if (_usePhone) ...[
              // Phone login
              AuthTextField(
                controller: _phoneCtrl,
                label: "Numéro de téléphone",
                hint: "07 XX XX XX XX",
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _sendPhoneOtp(),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "Numéro requis";
                  final clean = v.trim().replaceAll(RegExp(r'[\s\-\+]'), '');
                  if (clean.length < 8) return "Numéro trop court";
                  return null;
                },
              ),
              const SizedBox(height: 8),
              const Text(
                "🇨🇮 Préfixe +225 ajouté automatiquement",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _sendPhoneOtp,
                  child: isLoading
                      ? const SizedBox(
                          height: 22, width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.background),
                        )
                      : const Text("Recevoir le code WhatsApp"),
                ),
              ),
            ] else ...[
              // Email login
              AuthTextField(
                controller: _emailCtrl,
                label: "Email",
                hint: "votre@email.com",
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "Email requis";
                  if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                    return "Email invalide";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _passwordCtrl,
                label: "Mot de passe",
                hint: "••••••••",
                prefixIcon: Icons.lock_outline,
                isPassword: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _loginEmail(),
                validator: (v) {
                  if (v == null || v.isEmpty) return "Mot de passe requis";
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/auth/forgot-password'),
                  child: const Text(
                    "Mot de passe oublié ?",
                    style: TextStyle(color: AppColors.gold, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _loginEmail,
                  child: isLoading
                      ? const SizedBox(
                          height: 22, width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.background),
                        )
                      : const Text("Se connecter"),
                ),
              ),
            ],
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
            "Code envoyé via WhatsApp au $_fullPhone",
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 36),

          if (error != null) ...[
            _buildErrorBanner(error),
            const SizedBox(height: 20),
          ],

          AuthTextField(
            controller: _otpCtrl,
            label: "Code de vérification",
            hint: "123456",
            prefixIcon: Icons.sms_outlined,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _verifyOtp(),
            validator: (v) => null,
          ),
          const SizedBox(height: 32),

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
                  : const Text("Vérifier"),
            ),
          ),
          const SizedBox(height: 16),
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
                child: const Text("← Retour", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ),
              TextButton(
                onPressed: isLoading ? null : _sendPhoneOtp,
                child: const Text("Renvoyer le code", style: TextStyle(color: AppColors.gold, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildToggle(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.gold.withValues(alpha: 0.15) : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: active ? Border.all(color: AppColors.gold.withValues(alpha: 0.4)) : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? AppColors.gold : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
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
