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

  // Plan prices (FCFA)
  static const priceStarter = 990;
  static const pricePro = 1990;
  static const priceVip = 3990;

  /// Map plan → price
  static const planPrices = {
    planStarter: priceStarter,
    planPro: pricePro,
    planVip: priceVip,
  };

  /// Human-readable plan labels
  static const planLabels = {
    planFree: 'Gratuit',
    planStarter: 'Starter',
    planPro: 'Pro',
    planVip: 'VIP',
  };

  // Daily match limits per plan
  static const matchLimitFree = 1;
  static const matchLimitStarter = 5;
  static const matchLimitPro = 15;
  static const matchLimitVip = -1; // unlimited

  // Combo limits per plan
  static const comboLimitFree = 0;
  static const comboLimitStarter = 0;
  static const comboLimitPro = 1;
  static const comboLimitVip = 3;

  // Plan hierarchy for comparison
  static const planHierarchy = {'free': 0, 'starter': 1, 'pro': 2, 'vip': 3};

  /// Check if [userPlan] is at least [requiredPlan]
  static bool planMeetsRequirement(String userPlan, String requiredPlan) {
    return (planHierarchy[userPlan] ?? 0) >= (planHierarchy[requiredPlan] ?? 0);
  }

  // PawaPay correspondents
  static const correspondentOrangeCi = 'orange_ci';
  static const correspondentMtnCi = 'mtn_ci';

  /// Format phone number for PawaPay (Ivory Coast MSISDN)
  static String formatPhoneForPawapay(String phone) {
    var cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    // Remove leading + if present
    if (cleaned.startsWith('+')) cleaned = cleaned.substring(1);
    // Add country code if not present
    if (cleaned.startsWith('0')) {
      cleaned = '225${cleaned.substring(1)}';
    } else if (!cleaned.startsWith('225')) {
      cleaned = '225$cleaned';
    }
    return cleaned;
  }

  /// Validate Ivory Coast phone number
  static bool isValidIvoryCoastPhone(String phone) {
    final cleaned = formatPhoneForPawapay(phone);
    // Ivory Coast numbers: 225 + 10 digits (01/05/07/25/27 prefixes)
    return RegExp(r'^225(01|05|07|25|27)\d{8}$').hasMatch(cleaned);
  }
}
