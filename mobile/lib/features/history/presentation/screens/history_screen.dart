import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../predictions/domain/predictions_provider.dart';
import '../../../predictions/domain/prediction_model.dart';
import '../../../predictions/presentation/widgets/prediction_card.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(recentResultsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.surface,
          onRefresh: () async => ref.invalidate(recentResultsProvider),
          child: CustomScrollView(
            slivers: [
              // Title + stats summary
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    "Historique",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),

              resultsAsync.when(
                data: (results) {
                  if (results.isEmpty) {
                    return SliverFillRemaining(child: _buildEmpty());
                  }

                  final won = results.where((p) => p.result == PredictionResult.won).length;
                  final lost = results.where((p) => p.result == PredictionResult.lost).length;
                  final total = won + lost;
                  final rate = total > 0 ? (won / total * 100).round() : 0;

                  return SliverMainAxisGroup(
                    slivers: [
                      // Quick stats
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Row(
                            children: [
                              _StatChip(label: "Taux", value: "$rate%", color: AppColors.success),
                              const SizedBox(width: 10),
                              _StatChip(label: "Gagnés", value: "$won", color: AppColors.success),
                              const SizedBox(width: 10),
                              _StatChip(label: "Perdus", value: "$lost", color: AppColors.error),
                              const SizedBox(width: 10),
                              _StatChip(label: "Total", value: "${results.length}", color: AppColors.textPrimary),
                            ],
                          ),
                        ),
                      ),

                      // List
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final pred = results[index];
                              final match = pred.match;
                              if (match == null) return const SizedBox.shrink();
                              return PredictionCard(prediction: pred, match: match);
                            },
                            childCount: results.length,
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
                ),
                error: (e, st) => SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off_rounded, color: AppColors.textSecondary, size: 40),
                        const SizedBox(height: 12),
                        const Text(
                          "Impossible de charger l'historique",
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, color: AppColors.textSecondary.withValues(alpha: 0.3), size: 56),
          const SizedBox(height: 16),
          const Text(
            "Aucun résultat pour le moment",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 6),
          const Text(
            "Les résultats des pronos apparaîtront ici",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
