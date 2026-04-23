import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../auth/domain/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _bioSupported = false;
  bool _bioEnabled = false;
  String _bioLabel = 'Biométrie';

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final bio = BiometricService();
    final supported = await bio.isDeviceSupported;
    if (!supported) return;
    final enabled = await bio.isEnabled;
    final label = await bio.biometricLabel;
    if (mounted) setState(() { _bioSupported = true; _bioEnabled = enabled; _bioLabel = label; });
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      await BiometricService().enable();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$_bioLabel sera actif dès votre prochaine connexion"),
            backgroundColor: AppColors.surface,
          ),
        );
      }
    } else {
      await BiometricService().disable();
    }
    if (mounted) setState(() => _bioEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final authUser = ref.watch(currentUserProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.surface,
          onRefresh: () => ref.refresh(userProfileProvider.future),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Text(
                  "Profil",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 24),

                // Avatar + name
                profileAsync.when(
                  data: (profile) {
                    final username = profile?.username ?? "Utilisateur";
                    final email = authUser?.email ?? "";
                    final phone = profile?.phone;
                    final isPremium = profile?.isPremium ?? false;
                    final hasAccess = profile?.hasAccess ?? false;

                    return Column(
                      children: [
                        // Avatar — tap to edit
                        GestureDetector(
                          onTap: () => context.push('/profile/edit'),
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 44,
                                backgroundColor: AppColors.surface,
                                backgroundImage: profile?.avatarUrl != null
                                    ? NetworkImage(profile!.avatarUrl!)
                                    : null,
                                child: profile?.avatarUrl == null
                                    ? Text(
                                        username.isNotEmpty ? username[0].toUpperCase() : "?",
                                        style: const TextStyle(
                                          color: AppColors.gold,
                                          fontSize: 32,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0, right: 0,
                                child: Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(
                                    color: AppColors.gold,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.background, width: 2),
                                  ),
                                  child: const Icon(Icons.edit_rounded, color: Colors.black, size: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          username,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (email.isNotEmpty)
                          Text(
                            email,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        if (phone != null && phone.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            phone,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 12),

                        // Plan badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isPremium
                                ? AppColors.gold.withValues(alpha: 0.15)
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(20),
                            border: isPremium
                                ? Border.all(color: AppColors.gold.withValues(alpha: 0.4))
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPremium ? Icons.workspace_premium : Icons.star_border_rounded,
                                color: isPremium ? AppColors.gold : AppColors.textSecondary,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isPremium
                                    ? "Premium"
                                    : hasAccess
                                        ? "Essai gratuit"
                                        : "Gratuit",
                                style: TextStyle(
                                  color: isPremium ? AppColors.gold : AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Trial info
                        if (hasAccess && !isPremium && profile?.trialEndsAt != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            "Essai jusqu'au ${_formatDate(profile!.trialEndsAt!)}",
                            style: const TextStyle(color: AppColors.emerald, fontSize: 12),
                          ),
                        ],

                        const SizedBox(height: 32),

                        // Upgrade banner
                        if (!isPremium)
                          GestureDetector(
                            onTap: () => context.push('/subscription'),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.gold.withValues(alpha: 0.15),
                                    AppColors.gold.withValues(alpha: 0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.gold.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.rocket_launch_rounded, color: AppColors.gold, size: 20),
                                  ),
                                  const SizedBox(width: 14),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Passer à Premium",
                                          style: TextStyle(
                                            color: AppColors.gold,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          "Accédez à toutes les analyses",
                                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.gold, size: 16),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(height: 24),
                      ],
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: AppColors.gold),
                  ),
                  error: (e, st) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text("Erreur de chargement du profil", style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ),

                // Menu items
                _buildMenuItem(
                  icon: Icons.edit_rounded,
                  title: "Modifier le profil",
                  subtitle: "Nom, photo, téléphone",
                  onTap: () => context.push('/profile/edit'),
                ),
                _buildMenuItem(
                  icon: Icons.notifications_outlined,
                  title: "Notifications",
                  subtitle: "Gérer les alertes et catégories",
                  onTap: () => context.push('/profile/notifications'),
                ),
                _buildMenuItem(
                  icon: Icons.lock_outline_rounded,
                  title: "Mot de passe",
                  subtitle: "Changer votre mot de passe",
                  onTap: () => context.push('/profile/password'),
                ),
                if (_bioSupported)
                  _buildBiometricToggle(),
                _buildMenuItem(
                  icon: Icons.language_rounded,
                  title: "Langue",
                  trailing: "Français",
                  onTap: () => _showComingSoon(context, "Choix de la langue"),
                ),
                const SizedBox(height: 8),
                Divider(color: AppColors.surfaceLight.withValues(alpha: 0.5), height: 1),
                const SizedBox(height: 8),
                _buildMenuItem(
                  icon: Icons.shield_outlined,
                  title: "Confidentialité",
                  subtitle: "Politique de protection des données",
                  onTap: () => context.push('/profile/privacy'),
                ),
                _buildMenuItem(
                  icon: Icons.help_outline_rounded,
                  title: "Aide & Support",
                  subtitle: "FAQ et contact",
                  onTap: () => context.push('/profile/help'),
                ),
                _buildMenuItem(
                  icon: Icons.info_outline_rounded,
                  title: "À propos de Nakora",
                  onTap: () => context.push('/profile/about'),
                ),
                _buildMenuItem(
                  icon: Icons.gavel_rounded,
                  title: "Conditions d'utilisation",
                  subtitle: "CGU et mentions légales",
                  onTap: () => context.push('/profile/terms'),
                ),

                const SizedBox(height: 16),

                // Logout
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await _confirmLogout(context);
                      if (confirmed && context.mounted) {
                        await ref.read(authServiceProvider).signOut();
                      }
                    },
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text("Se déconnecter"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Delete account
                Divider(color: AppColors.surfaceLight.withValues(alpha: 0.5), height: 1),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmDeleteAccount(context, ref),
                    icon: const Icon(Icons.delete_forever_rounded, size: 18),
                    label: const Text("Supprimer mon compte"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error.withValues(alpha: 0.7),
                      side: BorderSide(color: AppColors.error.withValues(alpha: 0.2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Version
                const Text(
                  "Nakora v1.0.0",
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricToggle() {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.fingerprint, color: AppColors.gold, size: 20),
        ),
        title: Text(
          _bioLabel,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        ),
        subtitle: const Text(
          "Connexion rapide",
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        trailing: Switch.adaptive(
          value: _bioEnabled,
          activeTrackColor: AppColors.gold.withValues(alpha: 0.5),
          thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? AppColors.gold : null,
          ),
          onChanged: _toggleBiometric,
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    String? trailing,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.textPrimary, size: 18),
        ),
        title: Text(
          title,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        ),
        subtitle: subtitle != null
            ? Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11))
            : null,
        trailing: trailing != null
            ? Text(trailing, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))
            : const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 22),
              SizedBox(width: 8),
              Text("Supprimer votre compte ?", style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Cette action est irréversible.\n\n"
                "Toutes vos données seront supprimées :\n"
                "• Profil et préférences\n"
                "• Historique de prédictions\n"
                "• Abonnement actif\n\n"
                "Tapez SUPPRIMER pour confirmer :",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, letterSpacing: 2),
                decoration: InputDecoration(
                  hintText: "SUPPRIMER",
                  hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.3)),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Annuler", style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: controller.text == "SUPPRIMER" ? () => Navigator.pop(ctx, true) : null,
              child: Text(
                "Supprimer définitivement",
                style: TextStyle(
                  color: controller.text == "SUPPRIMER" ? AppColors.error : AppColors.textSecondary.withValues(alpha: 0.3),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
    );

    try {
      await ref.read(authServiceProvider).deleteAccount();
      if (context.mounted) Navigator.of(context).pop(); // dismiss loader
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // dismiss loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Erreur lors de la suppression. Réessayez."),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<bool> _confirmLogout(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Se déconnecter ?", style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
        content: const Text(
          "Vous devrez vous reconnecter pour accéder à vos pronostics.",
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler", style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Déconnexion", style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$feature — bientôt disponible"),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }
}
