import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/auth_provider.dart';
import '../../../predictions/domain/predictions_provider.dart';
import '../../../predictions/presentation/widgets/prediction_card.dart';
import '../widgets/stats_card.dart';
import '../widgets/section_header.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveAsync = ref.watch(homeLivePredictionsProvider);
    final todayAsync = ref.watch(homeTodayPredictionsProvider);
    final profile = ref.watch(userProfileProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            ref.invalidate(homeLivePredictionsProvider);
            ref.invalidate(homeTodayPredictionsProvider);
            ref.invalidate(monthlyStatsProvider);
            ref.invalidate(userProfileProvider);
          },
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: _buildHeader(
                  profile.valueOrNull?.username,
                ),
              ),

              // Stats
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: StatsCard(),
                ),
              ),

              // Live section
              liveAsync.when(
                data: (livePredictions) {
                  if (livePredictions.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                  return SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                          child: SectionHeader(
                            emoji: "🔴",
                            title: "LIVE",
                            badge: "${livePredictions.length} prono${livePredictions.length > 1 ? 's' : ''}",
                            badgeColor: AppColors.error,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final pred = livePredictions[index];
                              final match = pred.match;
                              if (match == null) return const SizedBox.shrink();
                              return PredictionCard(prediction: pred, match: match);
                            },
                            childCount: livePredictions.length,
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    ],
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
                  ),
                ),
                error: (e, st) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),

              // Today section
              todayAsync.when(
                data: (todayPredictions) {
                  if (todayPredictions.isEmpty) {
                    return SliverToBoxAdapter(child: _buildEmptyState());
                  }
                  return SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                          child: SectionHeader(
                            emoji: "📊",
                            title: "PRONOS DISPONIBLES",
                            badge: "${todayPredictions.length} prono${todayPredictions.length > 1 ? 's' : ''}",
                            badgeColor: AppColors.info,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final pred = todayPredictions[index];
                              final match = pred.match;
                              if (match == null) return const SizedBox.shrink();
                              return PredictionCard(prediction: pred, match: match);
                            },
                            childCount: todayPredictions.length,
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.wifi_off_rounded, color: AppColors.textSecondary, size: 40),
                        const SizedBox(height: 12),
                        const Text(
                          "Impossible de charger les données",
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          e.toString(),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String? username) {
    final greeting = username != null ? "Salut $username 👋" : "Bonjour 👋";
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'Q',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: 'uantara',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  greeting,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.notifications_outlined, color: AppColors.textPrimary, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.sports_soccer_rounded, color: AppColors.textSecondary.withValues(alpha: 0.4), size: 56),
          const SizedBox(height: 16),
          const Text(
            "Aucun prono disponible aujourd'hui",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            "Revenez plus tard ou tirez vers le bas pour actualiser",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
