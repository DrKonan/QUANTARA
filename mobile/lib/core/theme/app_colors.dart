import 'package:flutter/material.dart';

abstract class AppColors {
  // Backgrounds
  static const background = Color(0xFF0D0D0D);
  static const surface = Color(0xFF1A1A2E);
  static const surfaceLight = Color(0xFF252540);

  // Accents
  static const gold = Color(0xFFD4AF37);
  static const emerald = Color(0xFF00C896);

  // Text
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFA0A0B0);

  // Status
  static const success = Color(0xFF2ED573);
  static const error = Color(0xFFFF4757);
  static const warning = Color(0xFFFFA502);
  static const info = Color(0xFF1E90FF);

  // Confidence levels
  static const confidenceLow = error;        // < 65%
  static const confidenceMedium = warning;   // 65–74%
  static const confidenceHigh = info;        // 75–84%
  static const confidenceVeryHigh = success; // ≥ 85%
  static const confidenceExcellent = gold;   // ≥ 92%
}
