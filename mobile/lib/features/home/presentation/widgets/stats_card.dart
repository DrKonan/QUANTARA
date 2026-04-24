import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../predictions/domain/predictions_provider.dart';
import '../../../predictions/domain/prediction_model.dart';

class StatsCard extends ConsumerWidget {
  const StatsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(recentResultsProvider);

    return historyAsync.when(
      data: (predictions) {
        // Filter to current month only
        final now = DateTime.now();
        final monthStart = DateTime(now.year, now.month, 1);
        final monthEnd = DateTime(now.year, now.month + 1, 1);

        final thisMonth = predictions.where((p) =>
            p.createdAt.isAfter(monthStart) &&
            p.createdAt.isBefore(monthEnd) &&
            p.result != PredictionResult.pending).toList();

        final total = thisMonth.length;
        final won = thisMonth.where((p) => p.result == PredictionResult.won).length;
        final lost = thisMonth.where((p) => p.result == PredictionResult.lost).length;
        final rate = total > 0 ? won / total : 0.0;
        final ratePercent = (rate * 100).round();

        return _buildCard(ratePercent, total, won, lost, rate);
      },
      loading: () => _buildCard(0, 0, 0, 0, 0.0),
      error: (e, st) => _buildCard(0, 0, 0, 0, 0.0),
    );
  }

  Widget _buildCard(int ratePercent, int total, int won, int lost, double rate) {
    final now = DateTime.now();
    const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
    final monthLabel = months[now.month - 1];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            AppColors.gold.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              Text(
                "Win Rate — $monthLabel ${now.year}",
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "$ratePercent%",
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatItem("Officiels", "$total", AppColors.textPrimary),
              const SizedBox(width: 24),
              _buildStatItem("Gagnés", "$won", AppColors.success),
              const SizedBox(width: 24),
              _buildStatItem("Perdus", "$lost", AppColors.error),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate,
              backgroundColor: AppColors.error.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
