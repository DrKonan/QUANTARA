import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/onboarding_slide.dart';

class OnboardingSlideWidget extends StatelessWidget {
  final OnboardingSlide slide;
  final bool isLast;

  const OnboardingSlideWidget({
    super.key,
    required this.slide,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon container
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.gold.withValues(alpha: 0.2),
                  AppColors.gold.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Icon(
              slide.icon,
              size: 52,
              color: isLast ? AppColors.emerald : AppColors.gold,
            ),
          ),
          const SizedBox(height: 48),
          // Title
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          // Subtitle
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              height: 1.6,
            ),
          ),
          if (isLast) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.emerald.withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Sans carte bancaire requise',
                    style: TextStyle(color: AppColors.emerald, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
