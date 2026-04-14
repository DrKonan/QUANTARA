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
                    final isPremium = profile?.isPremium ?? false;
                    final hasAccess = profile?.hasAccess ?? false;

                    return Column(
                      children: [
                        // Avatar
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
                        Text(
                          email,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
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
                  icon: Icons.notifications_outlined,
                  title: "Notifications",
                  onTap: () {},
                ),
                _buildMenuItem(
                  icon: Icons.language_rounded,
                  title: "Langue",
                  trailing: "Français",
                  onTap: () {},
                ),
                _buildMenuItem(
                  icon: Icons.shield_outlined,
                  title: "Confidentialité",
                  onTap: () {},
                ),
                _buildMenuItem(
                  icon: Icons.help_outline_rounded,
                  title: "Aide & Support",
                  onTap: () {},
                ),
                _buildMenuItem(
                  icon: Icons.info_outline_rounded,
                  title: "À propos de Quantara",
                  onTap: () {},
                ),

                const SizedBox(height: 16),

                // Logout
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await ref.read(authServiceProvider).signOut();
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
        trailing: trailing != null
            ? Text(trailing, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))
            : const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }
}
