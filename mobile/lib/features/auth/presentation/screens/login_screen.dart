import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/biometric_service.dart';
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

  bool _usePhone = true;
  bool _canBiometric = false;
  String _bioLabel = '';
  bool _bioLoading = false;
  PaymentCountry _selectedCountry = AppConstants.defaultCountry;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final bio = BiometricService();
    final supported = await bio.isDeviceSupported;
    final enabled = await bio.isEnabled;
    final hasCreds = await bio.hasStoredCredentials;
    if (supported && enabled && hasCreds) {
      final label = await bio.biometricLabel;
      if (mounted) setState(() { _canBiometric = true; _bioLabel = label; });
    }
  }

  Future<void> _loginWithBiometric() async {
    setState(() => _bioLoading = true);
    ref.read(authErrorProvider.notifier).state = null;
    try {
      final success = await BiometricService().authenticateAndSignIn();
      if (!success && mounted) {
        ref.read(authErrorProvider.notifier).state = "Authentification biométrique annulée";
      }
    } catch (e) {
      if (mounted) ref.read(authErrorProvider.notifier).state = "Erreur biométrique. Utilisez votre mot de passe";
    } finally {
      if (mounted) setState(() => _bioLoading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  String _buildFullPhone() {
    final raw = _phoneCtrl.text.trim().replaceAll(RegExp(r'[\s\-]'), '');
    if (raw.startsWith('+')) return raw;
    if (raw.startsWith('0')) return '+${_selectedCountry.dialCode}${raw.substring(1)}';
    return '+${_selectedCountry.dialCode}$raw';
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    ref.read(authErrorProvider.notifier).state = null;
    ref.read(authLoadingProvider.notifier).state = true;

    try {
      if (_usePhone) {
        final phone = _buildFullPhone();
        await ref.read(authServiceProvider).signIn(
              phone: phone,
              password: _passwordCtrl.text,
            );
      } else {
        await ref.read(authServiceProvider).signIn(
              email: _emailCtrl.text.trim(),
              password: _passwordCtrl.text,
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
    if (msg.contains('invalid login credentials') || msg.contains('invalid_credentials')) {
      return _usePhone
          ? "Numéro ou mot de passe incorrect"
          : "Email ou mot de passe incorrect";
    }
    if (msg.contains('email not confirmed')) {
      return "Veuillez confirmer votre email";
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
              // Phone login with country selector
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
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _passwordCtrl,
                label: "Mot de passe",
                hint: "••••••••",
                prefixIcon: Icons.lock_outline,
                isPassword: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _login(),
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
                  onPressed: isLoading ? null : _login,
                  child: isLoading
                      ? const SizedBox(
                          height: 22, width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.background),
                        )
                      : const Text("Se connecter"),
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
                onFieldSubmitted: (_) => _login,
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
                  onPressed: isLoading ? null : _login,
                  child: isLoading
                      ? const SizedBox(
                          height: 22, width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.background),
                        )
                      : const Text("Se connecter"),
                ),
              ),
            ],
            if (_canBiometric) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(child: Divider(color: AppColors.surfaceLight)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text("ou", style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: 12)),
                  ),
                  const Expanded(child: Divider(color: AppColors.surfaceLight)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: (isLoading || _bioLoading) ? null : _loginWithBiometric,
                  icon: _bioLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold))
                      : const Icon(Icons.fingerprint, size: 22),
                  label: Text(_bioLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side: const BorderSide(color: AppColors.gold, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
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
