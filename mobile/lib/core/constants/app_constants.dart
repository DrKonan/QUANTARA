abstract class AppConstants {
  static const appName = 'Quantara';
  static const trialDurationDays = 3;
  static const minConfidenceThreshold = 0.80;

  // Confidence labels
  static const confidenceExcellentThreshold = 0.92;
  static const confidenceVeryHighThreshold = 0.85;
  static const confidenceHighThreshold = 0.80;

  // Subscription plans
  static const planFree = 'free';
  static const planStarter = 'starter';
  static const planPro = 'pro';
  static const planVip = 'vip';

  // Daily match limits per plan
  static const matchLimitFree = 1;
  static const matchLimitStarter = 5;
  static const matchLimitPro = 15;
  static const matchLimitVip = -1; // unlimited
}
