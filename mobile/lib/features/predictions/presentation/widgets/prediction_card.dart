import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../predictions/domain/prediction_model.dart';
import '../../../predictions/domain/match_model.dart';

class PredictionCard extends StatelessWidget {
  final Prediction prediction;
  final Match match;
  final bool isLocked;
  final VoidCallback? onTap;

  const PredictionCard({
    super.key,
    required this.prediction,
    required this.match,
    this.isLocked = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: match.status == MatchStatus.live
              ? Border.all(color: AppColors.error.withValues(alpha: 0.4), width: 1)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // League + time
            _buildHeader(),
            const SizedBox(height: 12),

            // Teams + score
            _buildTeams(),
            const SizedBox(height: 14),

            // Predicted event
            _buildEvent(),
            const SizedBox(height: 10),

            // Confidence bar
            _buildConfidence(),
            const SizedBox(height: 12),

            // Analysis or locked
            if (isLocked)
              _buildLocked()
            else
              _buildAnalysis(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final timeStr = match.status == MatchStatus.upcoming
        ? DateFormat('HH:mm').format(match.dateTime)
        : match.statusLabel;

    return Row(
      children: [
        if (match.league.flagEmoji != null) ...[
          Text(match.league.flagEmoji!, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            "${match.league.name} · ${match.league.country}",
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (match.status == MatchStatus.live) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  timeStr,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Text(
            timeStr,
            style: TextStyle(
              color: match.status == MatchStatus.finished
                  ? AppColors.textSecondary
                  : AppColors.gold,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        if (prediction.result != PredictionResult.pending) ...[
          const SizedBox(width: 8),
          Text(prediction.resultEmoji, style: const TextStyle(fontSize: 14)),
        ],
      ],
    );
  }

  Widget _buildTeams() {
    return Row(
      children: [
        Expanded(
          child: Text(
            "${match.homeTeam.name}  vs  ${match.awayTeam.name}",
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (match.score != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "${match.score!.home} - ${match.score!.away}",
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEvent() {
    return Row(
      children: [
        const Icon(Icons.gps_fixed_rounded, color: AppColors.gold, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            prediction.event,
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfidence() {
    final percent = prediction.confidencePercent;
    final color = prediction.confidenceColor;

    return Row(
      children: [
        // Progress bar
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: prediction.confidence,
              backgroundColor: AppColors.surfaceLight,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Percent
        Text(
          "$percent%",
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          prediction.confidenceLabel,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysis() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          prediction.analysis,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              "Voir l'analyse complète",
              style: TextStyle(
                color: AppColors.gold.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.gold.withValues(alpha: 0.8),
              size: 14,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocked() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_rounded, color: AppColors.gold, size: 16),
          SizedBox(width: 8),
          Text(
            "Débloquer avec Premium",
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
