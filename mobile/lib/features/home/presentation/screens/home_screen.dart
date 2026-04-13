import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../predictions/domain/match_model.dart';
import '../../../predictions/domain/mock_data.dart';
import '../../../predictions/presentation/widgets/prediction_card.dart';
import '../widgets/stats_card.dart';
import '../widgets/section_header.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Split predictions by category
    final livePredictions = mockPredictions.where((p) => p.isLive).toList();
    final todayPredictions = mockPredictions
        .where((p) => !p.isLive && getMatchForPrediction(p).status == MatchStatus.upcoming)
        .toList();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(child: _buildHeader()),

            // Stats
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: StatsCard(),
              ),
            ),

            // Live section
            if (livePredictions.isNotEmpty) ...[
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
                      final match = getMatchForPrediction(pred);
                      return PredictionCard(prediction: pred, match: match);
                    },
                    childCount: livePredictions.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],

            // Today section
            if (todayPredictions.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: SectionHeader(
                    emoji: "📅",
                    title: "AUJOURD'HUI",
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
                      final match = getMatchForPrediction(pred);
                      return PredictionCard(prediction: pred, match: match);
                    },
                    childCount: todayPredictions.length,
                  ),
                ),
              ),
            ],

            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
                const Text(
                  "Bonjour 👋",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Notification bell
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                const Center(
                  child: Icon(Icons.notifications_outlined, color: AppColors.textPrimary, size: 22),
                ),
                Positioned(
                  top: 8,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
