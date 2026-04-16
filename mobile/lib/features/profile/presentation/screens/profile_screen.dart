import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final authUser = ref.watch(currentUserProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.surface,
          onRefresh: () async => ref.invalidate(userProfileProvider),
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
                  onTap: () => _showComingSoon(context, "Paramètres de notifications"),
                ),
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
                  onTap: () => _showComingSoon(context, "Politique de confidentialité"),
                ),
                _buildMenuItem(
                  icon: Icons.help_outline_rounded,
                  title: "Aide & Support",
                  onTap: () => _showComingSoon(context, "Centre d'aide"),
                ),
                _buildMenuItem(
                  icon: Icons.info_outline_rounded,
                  title: "À propos de Quantara",
                  onTap: () => _showAbout(context),
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

                // Version
                const Text(
                  "Quantara v1.0.0",
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

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.gold, AppColors.gold.withValues(alpha: 0.6)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              "Quantara",
              style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text("v1.0.0", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            const Text(
              "Prédictions sportives alimentées par l'Intelligence Artificielle.\n\nFoot · Basket · Hockey",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 20),
            const Text(
              "© 2026 Quantara — Tous droits réservés",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Fermer", style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }
}
