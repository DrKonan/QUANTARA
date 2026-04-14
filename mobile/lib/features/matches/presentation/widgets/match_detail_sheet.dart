import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../predictions/domain/today_match_model.dart';
import '../../../predictions/domain/match_model.dart';

class MatchDetailSheet extends StatelessWidget {
  final TodayMatch todayMatch;
  const MatchDetailSheet({super.key, required this.todayMatch});

  @override
  Widget build(BuildContext context) {
    final match = todayMatch.match;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              const SizedBox(height: 12),
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Match info card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: match.status == MatchStatus.live
                      ? Border.all(color: AppColors.error.withValues(alpha: 0.3))
                      : null,
                ),
                child: Column(
                  children: [
                    // League
                    Text(
                      match.league.name,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    // Teams + score
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            match.homeTeam.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: match.score != null
                              ? Text(
                                  "${match.score!.home} - ${match.score!.away}",
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              : Text(
                                  DateFormat('HH:mm').format(match.dateTime.toLocal()),
                                  style: const TextStyle(
                                    color: AppColors.gold,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                        Expanded(
                          child: Text(
                            match.awayTeam.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Status
                    if (match.status == MatchStatus.live)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "EN DIRECT ${match.statusLabel}",
                              style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      )
                    else if (match.status == MatchStatus.finished)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "TERMIN\u00c9",
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    if (match.tier == 1) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "⭐ TOP LEAGUE",
                          style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Predictions section
              if (todayMatch.isFinished && todayMatch.hasPredictions) ...[
                const Text(
                  "R\u00e9sultats des pr\u00e9dictions",
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ...todayMatch.predictions.map((pred) => _buildFinishedPredictionTile(pred)),
              ] else if (todayMatch.isFinished && !todayMatch.hasPredictions) ...[
                _buildFinishedNoPredCard(),
              ] else if (todayMatch.hasPredictions) ...[
                const Text(
                  "Pr\u00e9dictions",
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ...todayMatch.predictions.map((pred) => _buildPredictionTile(pred)),
              ] else ...[
                // No predictions yet — explain why
                _buildWaitingCard(),
              ],

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPredictionTile(TodayPrediction pred) {
    if (pred.isLocked) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_rounded, color: AppColors.gold, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _typeLabel(pred.predictionType),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    "Réservé aux abonnés Premium",
                    style: TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final confidence = pred.confidencePercent;
    final color = _confidenceColor(pred.confidence ?? 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type + confidence
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _typeLabel(pred.predictionType),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              if (pred.isLive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "LIVE",
                    style: TextStyle(color: AppColors.error, fontSize: 9, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Event
          Row(
            children: [
              const Icon(Icons.gps_fixed_rounded, color: AppColors.gold, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pred.eventLabel,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Confidence bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pred.confidence ?? 0,
                    backgroundColor: AppColors.surfaceLight,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "$confidence%",
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
              ),
              if (pred.confidenceLabel != null) ...[
                const SizedBox(width: 4),
                Text(
                  pred.confidenceLabel!,
                  style: TextStyle(color: color, fontSize: 10),
                ),
              ],
            ],
          ),
          // Analysis
          if (pred.analysisText != null && pred.analysisText!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              pred.analysisText!,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWaitingCard() {
    final status = todayMatch.predictionStatus;
    IconData icon;
    Color color;
    String title;

    switch (status) {
      case 'generating':
        icon = Icons.autorenew_rounded;
        color = AppColors.gold;
        title = "Génération en cours";
      case 'pending_live':
        icon = Icons.autorenew_rounded;
        color = AppColors.warning;
        title = "Analyse live en cours";
      case 'waiting_lineups':
        icon = Icons.people_rounded;
        color = AppColors.info;
        title = "En attente des compositions";
      default:
        icon = Icons.schedule_rounded;
        color = AppColors.textSecondary;
        title = "Prédiction pas encore disponible";
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            todayMatch.predictionMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
          ),
          if (todayMatch.estimatedWaitMinutes != null && todayMatch.estimatedWaitMinutes! > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "⏱ Estimé dans ${todayMatch.waitLabel}",
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            "Notre IA analyse les compositions officielles,\nles statistiques et la forme des équipes\npour générer des prédictions fiables.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildFinishedPredictionTile(TodayPrediction pred) {
    final correct = pred.isCorrect;
    final resultIcon = correct == true
        ? const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20)
        : correct == false
            ? const Icon(Icons.cancel_rounded, color: AppColors.error, size: 20)
            : const Icon(Icons.help_outline_rounded, color: AppColors.textSecondary, size: 20);
    final resultLabel = correct == true
        ? "Correct"
        : correct == false
            ? "Incorrect"
            : "En attente";
    final resultColor = correct == true
        ? AppColors.success
        : correct == false
            ? AppColors.error
            : AppColors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: correct != null
            ? Border.all(
                color: (correct ? AppColors.success : AppColors.error).withValues(alpha: 0.25),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _typeLabel(pred.predictionType),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              resultIcon,
              const SizedBox(width: 6),
              Text(resultLabel, style: TextStyle(color: resultColor, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.gps_fixed_rounded, color: AppColors.gold, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pred.eventLabel,
                  style: const TextStyle(color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (pred.confidence != null) ...[
            const SizedBox(height: 8),
            Text(
              "Confiance : ${pred.confidencePercent}%",
              style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7), fontSize: 11),
            ),
          ],
          if (pred.analysisText != null && pred.analysisText!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              pred.analysisText!,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinishedNoPredCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sports_score_rounded, color: AppColors.textSecondary, size: 28),
          ),
          const SizedBox(height: 14),
          const Text(
            "Match termin\u00e9",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            "Aucune pr\u00e9diction n'\u00e9tait disponible pour ce match.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'result': return 'RÉSULTAT';
      case 'btts': return 'BTTS';
      case 'over_under': return 'BUTS';
      case 'corners': return 'CORNERS';
      case 'cards': return 'CARTONS';
      case 'halftime': return 'MI-TEMPS';
      default: return type.toUpperCase();
    }
  }

  Color _confidenceColor(double confidence) {
    if (confidence >= 0.92) return AppColors.emerald;
    if (confidence >= 0.85) return AppColors.success;
    if (confidence >= 0.75) return AppColors.gold;
    if (confidence >= 0.65) return AppColors.warning;
    return AppColors.textSecondary;
  }
}
