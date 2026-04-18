import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../predictions/domain/today_match_model.dart';
import '../../../predictions/domain/match_model.dart';

class MatchDetailSheet extends StatefulWidget {
  final TodayMatch todayMatch;
  const MatchDetailSheet({super.key, required this.todayMatch});

  @override
  State<MatchDetailSheet> createState() => _MatchDetailSheetState();
}

class _MatchDetailSheetState extends State<MatchDetailSheet> {
  TodayMatch get todayMatch => widget.todayMatch;

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
              _buildMatchInfoCard(match),
              const SizedBox(height: 20),
              ..._buildPredictionsSection(),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMatchInfoCard(Match match) {
    return Container(
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
          Text(
            match.league.name,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  match.homeTeam.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600,
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
                          color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800,
                        ),
                      )
                    : Text(
                        DateFormat('HH:mm').format(match.dateTime.toLocal()),
                        style: const TextStyle(
                          color: AppColors.gold, fontSize: 18, fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              Expanded(
                child: Text(
                  match.awayTeam.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
                "TERMINÉ",
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
    );
  }

  List<Widget> _buildPredictionsSection() {
    final home = todayMatch.match.homeTeam.name;
    final away = todayMatch.match.awayTeam.name;

    // ── FINISHED ──
    if (todayMatch.isFinished && todayMatch.hasOfficialPredictions) {
      return [
        const Text(
          "Résultats — Coupon Officiel",
          style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ...todayMatch.officialPredictions.map((pred) => _buildFinishedPredictionTile(pred, home, away)),
      ];
    }

    if (todayMatch.isFinished && !todayMatch.hasOfficialPredictions) {
      return [_buildFinishedNoPredCard()];
    }

    // ── LIVE or POST-COMPO with official predictions ──
    if (todayMatch.hasOfficialPredictions) {
      return _buildOfficialSection(home, away);
    }

    // ── PRE-COMPO: show tendances if available ──
    if (!todayMatch.hasLineup && todayMatch.hasTendances) {
      return [
        _buildWaitingCard(),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text("📊", style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                "Tendances fortes détectées",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          "Sera confirmé ou ajusté avec les compositions officielles",
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 10),
        ...todayMatch.tendancePredictions.map((p) => _buildHintTile(p, home, away)),
      ];
    }

    // ── No prediction available yet ──
    return [_buildWaitingCard()];
  }

  /// Build the official "Notre Pronostic" section (post-compo / live)
  List<Widget> _buildOfficialSection(String home, String away) {
    final livePreds = todayMatch.officialPredictions.where((p) => p.isLive).toList();
    final prematchPreds = todayMatch.officialPredictions.where((p) => !p.isLive).toList();

    final widgets = <Widget>[];

    widgets.addAll([
      Row(
        children: [
          const Text("⭐", style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          const Text(
            "Notre Pronostic",
            style: TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              "${todayMatch.officialPredictions.length} pari${todayMatch.officialPredictions.length > 1 ? 's' : ''}",
              style: const TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      const Text(
        "Sélection validée par notre IA — à jouer en confiance",
        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
      ),
      const SizedBox(height: 12),
    ]);

    // Live predictions first
    if (livePreds.isNotEmpty) {
      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("💡", style: TextStyle(fontSize: 14)),
              SizedBox(width: 6),
              Text(
                "Pari Live",
                style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
      widgets.addAll(livePreds.map((p) => _buildTopPickTile(p, home, away)));
    }

    // Prematch refined picks
    widgets.addAll(prematchPreds.map((p) => _buildTopPickTile(p, home, away)));

    return widgets;
  }

  Widget _buildTopPickTile(TodayPrediction pred, String home, String away) {
    final confidence = pred.confidencePercent;
    final color = _confidenceColor(pred.confidence ?? 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(pred.typeIcon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  pred.typeLabel,
                  style: const TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
              if (pred.isRefined) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "Affiné ✓",
                    style: TextStyle(color: AppColors.info, fontSize: 9, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              if (pred.isLive) ...[
                const SizedBox(width: 6),
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
              const Spacer(),
              Text(
                "$confidence%",
                style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            pred.eventLabelWith(home: home, away: away),
            style: const TextStyle(
              color: AppColors.gold, fontSize: 15, fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pred.confidence ?? 0,
              backgroundColor: AppColors.surfaceLight,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
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

  /// Subtle hint tile for strong secondary signals (≥80%) — not an official bet
  Widget _buildHintTile(TodayPrediction pred, String home, String away) {
    final confidence = pred.confidencePercent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Text(pred.typeIcon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              pred.eventLabelWith(home: home, away: away),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            "$confidence%",
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.7),
              fontSize: 12, fontWeight: FontWeight.w600,
            ),
          ),
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
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700),
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

  Widget _buildFinishedPredictionTile(TodayPrediction pred, String home, String away) {
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
              Text(pred.typeIcon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  pred.typeLabel,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
              if (pred.isTopPick) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "⭐ TOP",
                    style: TextStyle(color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              const Spacer(),
              resultIcon,
              const SizedBox(width: 6),
              Text(resultLabel, style: TextStyle(color: resultColor, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            pred.eventLabelWith(home: home, away: away),
            style: const TextStyle(color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.w600),
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
            "Match terminé",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            "Aucune prédiction n'était disponible pour ce match.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Color _confidenceColor(double confidence) {
    if (confidence >= 0.80) return AppColors.gold;
    if (confidence >= 0.65) return AppColors.success;
    if (confidence >= 0.50) return AppColors.warning;
    return AppColors.textSecondary;
  }
}
