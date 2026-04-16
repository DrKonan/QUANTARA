import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import 'match_model.dart';

enum PredictionResult { pending, won, lost }

class Prediction {
  final String id;
  final String matchId;
  final String event;
  final double confidence;
  final String analysis;
  final PredictionResult result;
  final bool isLive;
  final bool isPremium;
  final bool isTopPick;
  final DateTime createdAt;
  final Match? match; // populated when joined

  const Prediction({
    required this.id,
    required this.matchId,
    required this.event,
    required this.confidence,
    required this.analysis,
    this.result = PredictionResult.pending,
    this.isLive = false,
    this.isPremium = false,
    this.isTopPick = false,
    required this.createdAt,
    this.match,
  });

  int get confidencePercent => (confidence * 100).round();

  String get confidenceLabel {
    if (confidence >= AppConstants.confidenceExcellentThreshold) return "Excellent";
    if (confidence >= AppConstants.confidenceVeryHighThreshold) return "Très élevé";
    if (confidence >= AppConstants.confidenceHighThreshold) return "Élevé";
    if (confidence >= 0.65) return "Moyen";
    return "Faible";
  }

  Color get confidenceColor {
    if (confidence >= AppConstants.confidenceExcellentThreshold) return AppColors.confidenceExcellent;
    if (confidence >= AppConstants.confidenceVeryHighThreshold) return AppColors.confidenceVeryHigh;
    if (confidence >= AppConstants.confidenceHighThreshold) return AppColors.confidenceHigh;
    if (confidence >= 0.65) return AppColors.confidenceMedium;
    return AppColors.confidenceLow;
  }

  String get resultEmoji {
    switch (result) {
      case PredictionResult.won:
        return "✅";
      case PredictionResult.lost:
        return "❌";
      case PredictionResult.pending:
        return "";
    }
  }
}
