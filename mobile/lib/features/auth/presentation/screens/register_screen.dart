import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  PaymentCountry _selectedCountry = AppConstants.defaultCountry;
  bool _registered = false;
  bool _trialGranted = true;
  bool _acceptedTerms = false;
  String? _previousContact;

  @override
  void initState() {
    super.initState();
    _selectedCountry = AppConstants.countryFromLocale();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String _buildFullPhone() {
    final raw = _phoneCtrl.text.trim().replaceAll(RegExp(r'[\s\-]'), '');
    if (raw.startsWith('+')) return raw;
    if (raw.startsWith('0')) return '+${_selectedCountry.dialCode}${raw.substring(1)}';
    return '+${_selectedCountry.dialCode}$raw';
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    ref.read(authErrorProvider.notifier).state = null;
    ref.read(authLoadingProvider.notifier).state = true;

    try {
      final phone = _buildFullPhone();
      final email = _emailCtrl.text.trim();

      final result = await ref.read(authServiceProvider).signUpWithPhone(
            phone: phone,
            password: _passwordCtrl.text,
            username: _nameCtrl.text.trim(),
            email: email.isNotEmpty ? email : null,
          );
      if (mounted) {
        setState(() {
          _registered = true;
          _trialGranted = result.trialGranted;
          _previousContact = result.previousContact;
        });
      }
    } catch (e, stack) {
      debugPrint('[Nakora] SIGNUP ERROR: $e');
      debugPrint('[Nakora] STACK: $stack');
      ref.read(authErrorProvider.notifier).state = _mapError(e);
    } finally {
      if (mounted) ref.read(authLoadingProvider.notifier).state = false;
    }
  }

  String _mapError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('already registered') || msg.contains('user_already_exists') || msg.contains('already been registered')) {
      return "Un compte existe déjà avec ce numéro ou cet email";
    }
    if (msg.contains('email_provider_disabled') || msg.contains('email signups are disabled')) {
      return "L'inscription par email est désactivée côté serveur. Contactez le support";
    }
    if (msg.contains('weak_password') || (msg.contains('password') && msg.contains('weak'))) {
      return "Mot de passe trop faible (minimum 6 caractères)";
    }
    if (msg.contains('invalid') && msg.contains('email')) {
      return "Adresse email invalide";
    }
    if (msg.contains('email_confirmation_required')) {
      return "Un email de confirmation a été envoyé. Vérifiez votre boîte de réception";
    }
    if (msg.contains('signup_blocked_confirm_email')) {
      return "Inscription temporairement indisponible. Réessayez avec une adresse email";
    }
    if (msg.contains('rate') || msg.contains('too many')) {
      return "Trop de tentatives. Attendez quelques minutes";
    }
    if (msg.contains('network') || msg.contains('socket')) {
      return "Erreur de connexion. Vérifiez votre internet";
    }
    return "Une erreur est survenue. Réessayez";
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                    trailing: Text('+${country.dialCode}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    selected: isSelected,
                    selectedTileColor: AppColors.gold.withValues(alpha: 0.08),
                    onTap: () {
                      setState(() => _selectedCountry = country);
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

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authLoadingProvider);
    final error = ref.watch(authErrorProvider);

    if (_registered) return _buildSuccessView();
    return _buildForm(isLoading, error);
  }

  Widget _buildForm(bool isLoading, String? error) {
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
            const SizedBox(height: 28),

            if (error != null) ...[
              _buildErrorBanner(error),
              const SizedBox(height: 16),
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

            // Phone with country selector
            const Text("Numéro de téléphone", style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _showCountryPicker,
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceLight),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_selectedCountry.flag, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 4),
                        Text(
                          '+${_selectedCountry.dialCode}',
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary, size: 20),
                      ],
                    ),
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
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return "Numéro requis";
                      final clean = v.trim().replaceAll(RegExp(r'[\s\-]'), '');
                      if (clean.length < _selectedCountry.localDigits - 1) return "Numéro trop court";
                      if (!RegExp(r'^[0-9]+$').hasMatch(clean)) return "Numéro invalide";
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Email (optional)
            AuthTextField(
              controller: _emailCtrl,
              label: "Email (optionnel)",
              hint: "votre@email.com",
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null; // optional
                if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                  return "Email invalide";
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password
            AuthTextField(
              controller: _passwordCtrl,
              label: "Mot de passe",
              hint: "Minimum 6 caractères",
              prefixIcon: Icons.lock_outline,
              isPassword: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _register(),
              validator: (v) {
                if (v == null || v.isEmpty) return "Mot de passe requis";
                if (v.length < 6) return "Minimum 6 caractères";
                return null;
              },
            ),
            const SizedBox(height: 28),

            // Terms acceptance
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 24, height: 24,
                  child: Checkbox(
                    value: _acceptedTerms,
                    onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                    activeColor: AppColors.gold,
                    side: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.4)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.push('/profile/terms'),
                    child: Text.rich(
                      TextSpan(
                        text: "J'accepte les ",
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: "Conditions d'utilisation",
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 12,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.gold.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Register button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading || !_acceptedTerms ? null : _register,
                child: isLoading
                    ? const SizedBox(
                        height: 22, width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.background),
                      )
                    : const Text("Créer mon compte"),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
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
          if (_trialGranted)
            Text(
              "Bienvenue ${_nameCtrl.text.trim()} !\nVotre essai gratuit de ${AppConstants.trialDurationDays} jours a commencé.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
            )
          else ...[
            Text(
              "Bienvenue ${_nameCtrl.text.trim()} !",
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Votre période d'essai a déjà été utilisée "
                      "avec le compte ${_previousContact ?? 'précédent'}.\n\n"
                      "Abonnez-vous pour accéder aux fonctionnalités Premium.",
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
