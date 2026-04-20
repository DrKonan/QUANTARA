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

  // PawaPay correspondents (legacy keys)
  static const correspondentOrangeCi = 'orange_ci';
  static const correspondentMtnCi = 'mtn_ci';

  // ── Supported countries with their payment methods ──
  // Each country lists the mobile money providers available via PawaPay
  // + Wave where supported. The `correspondent` key is sent to the backend.
  static const supportedCountries = [
    PaymentCountry(
      code: 'CI', name: "Côte d'Ivoire", dialCode: '225', flag: '🇨🇮', localDigits: 10,
      methods: [
        PaymentMethod(id: 'wave', name: 'Wave', correspondent: null, color: 0xFF1DC2FF, icon: 'waves'),
        PaymentMethod(id: 'orange_ci', name: 'Orange Money', correspondent: 'ORANGE_CIV', color: 0xFFFF6600, icon: 'phone'),
        PaymentMethod(id: 'mtn_ci', name: 'MTN MoMo', correspondent: 'MTN_MOMO_CIV', color: 0xFFFFCC00, icon: 'phone'),
      ],
    ),
    PaymentCountry(
      code: 'SN', name: 'Sénégal', dialCode: '221', flag: '🇸🇳', localDigits: 9,
      methods: [
        PaymentMethod(id: 'wave', name: 'Wave', correspondent: null, color: 0xFF1DC2FF, icon: 'waves'),
        PaymentMethod(id: 'orange_sn', name: 'Orange Money', correspondent: 'ORANGE_SEN', color: 0xFFFF6600, icon: 'phone'),
        PaymentMethod(id: 'free_sn', name: 'Free Money', correspondent: 'FREE_SEN', color: 0xFF00C896, icon: 'phone'),
      ],
    ),
    PaymentCountry(
      code: 'ML', name: 'Mali', dialCode: '223', flag: '🇲🇱', localDigits: 8,
      methods: [
        PaymentMethod(id: 'orange_ml', name: 'Orange Money', correspondent: 'ORANGE_MLI', color: 0xFFFF6600, icon: 'phone'),
        PaymentMethod(id: 'moov_ml', name: 'Moov Money', correspondent: 'MOOV_MLI', color: 0xFF0066CC, icon: 'phone'),
      ],
    ),
    PaymentCountry(
      code: 'BF', name: 'Burkina Faso', dialCode: '226', flag: '🇧🇫', localDigits: 8,
      methods: [
        PaymentMethod(id: 'orange_bf', name: 'Orange Money', correspondent: 'ORANGE_BFA', color: 0xFFFF6600, icon: 'phone'),
        PaymentMethod(id: 'moov_bf', name: 'Moov Money', correspondent: 'MOOV_BFA', color: 0xFF0066CC, icon: 'phone'),
      ],
    ),
    PaymentCountry(
      code: 'BJ', name: 'Bénin', dialCode: '229', flag: '🇧🇯', localDigits: 8,
      methods: [
        PaymentMethod(id: 'mtn_bj', name: 'MTN MoMo', correspondent: 'MTN_MOMO_BEN', color: 0xFFFFCC00, icon: 'phone'),
        PaymentMethod(id: 'moov_bj', name: 'Moov Money', correspondent: 'MOOV_BEN', color: 0xFF0066CC, icon: 'phone'),
      ],
    ),
    PaymentCountry(
      code: 'TG', name: 'Togo', dialCode: '228', flag: '🇹🇬', localDigits: 8,
      methods: [
        PaymentMethod(id: 'moov_tg', name: 'Moov Money', correspondent: 'MOOV_TGO', color: 0xFF0066CC, icon: 'phone'),
      ],
    ),
    PaymentCountry(
      code: 'NE', name: 'Niger', dialCode: '227', flag: '🇳🇪', localDigits: 8,
      methods: [
        PaymentMethod(id: 'airtel_ne', name: 'Airtel Money', correspondent: 'AIRTEL_NER', color: 0xFFED1C24, icon: 'phone'),
      ],
    ),
    PaymentCountry(
      code: 'GN', name: 'Guinée', dialCode: '224', flag: '🇬🇳', localDigits: 9,
      methods: [
        PaymentMethod(id: 'orange_gn', name: 'Orange Money', correspondent: 'ORANGE_GIN', color: 0xFFFF6600, icon: 'phone'),
        PaymentMethod(id: 'mtn_gn', name: 'MTN MoMo', correspondent: 'MTN_MOMO_GIN', color: 0xFFFFCC00, icon: 'phone'),
      ],
    ),
    PaymentCountry(
      code: 'CM', name: 'Cameroun', dialCode: '237', flag: '🇨🇲', localDigits: 9,
      methods: [
        PaymentMethod(id: 'orange_cm', name: 'Orange Money', correspondent: 'ORANGE_CMR', color: 0xFFFF6600, icon: 'phone'),
        PaymentMethod(id: 'mtn_cm', name: 'MTN MoMo', correspondent: 'MTN_MOMO_CMR', color: 0xFFFFCC00, icon: 'phone'),
      ],
    ),
    PaymentCountry(
      code: 'GA', name: 'Gabon', dialCode: '241', flag: '🇬🇦', localDigits: 7,
      methods: [
        PaymentMethod(id: 'airtel_ga', name: 'Airtel Money', correspondent: 'AIRTEL_GAB', color: 0xFFED1C24, icon: 'phone'),
      ],
    ),
    PaymentCountry(
      code: 'CG', name: 'Congo', dialCode: '242', flag: '🇨🇬', localDigits: 9,
      methods: [
        PaymentMethod(id: 'airtel_cg', name: 'Airtel Money', correspondent: 'AIRTEL_COG', color: 0xFFED1C24, icon: 'phone'),
        PaymentMethod(id: 'mtn_cg', name: 'MTN MoMo', correspondent: 'MTN_MOMO_COG', color: 0xFFFFCC00, icon: 'phone'),
      ],
    ),
    PaymentCountry(
      code: 'CD', name: 'RD Congo', dialCode: '243', flag: '🇨🇩', localDigits: 9,
      methods: [
        PaymentMethod(id: 'orange_cd', name: 'Orange Money', correspondent: 'ORANGE_COD', color: 0xFFFF6600, icon: 'phone'),
        PaymentMethod(id: 'airtel_cd', name: 'Airtel Money', correspondent: 'AIRTEL_COD', color: 0xFFED1C24, icon: 'phone'),
        PaymentMethod(id: 'vodacom_cd', name: 'Vodacom M-Pesa', correspondent: 'VODACOM_COD', color: 0xFFE60000, icon: 'phone'),
      ],
    ),
  ];

  static PaymentCountry get defaultCountry => supportedCountries.first;

  /// Format phone number for PawaPay with country code
  static String formatPhoneForPawapay(String phone, {String countryCode = '225'}) {
    var cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.startsWith('+')) cleaned = cleaned.substring(1);
    if (cleaned.startsWith('0')) {
      cleaned = '$countryCode${cleaned.substring(1)}';
    } else if (!cleaned.startsWith(countryCode)) {
      cleaned = '$countryCode$cleaned';
    }
    return cleaned;
  }

  /// Validate phone number for a given country
  static bool isValidPhone(String phone, PaymentCountry country) {
    final cleaned = formatPhoneForPawapay(phone, countryCode: country.dialCode);
    final expectedLength = country.dialCode.length + country.localDigits;
    return RegExp(r'^\d+$').hasMatch(cleaned) && cleaned.length == expectedLength;
  }

  /// Legacy — still works for CI
  static bool isValidIvoryCoastPhone(String phone) {
    return isValidPhone(phone, defaultCountry);
  }
}

/// A supported country with its available payment methods
class PaymentCountry {
  final String code;
  final String name;
  final String dialCode;
  final String flag;
  final int localDigits;
  final List<PaymentMethod> methods;

  const PaymentCountry({
    required this.code,
    required this.name,
    required this.dialCode,
    required this.flag,
    required this.localDigits,
    required this.methods,
  });

  String get label => '$flag +$dialCode';
  String get fullLabel => '$flag $name (+$dialCode)';
  bool get hasWave => methods.any((m) => m.id == 'wave');
}

/// A mobile money payment method for a country
class PaymentMethod {
  final String id;
  final String name;
  final String? correspondent; // PawaPay correspondent code (null for Wave)
  final int color;
  final String icon; // 'waves' or 'phone'

  const PaymentMethod({
    required this.id,
    required this.name,
    required this.correspondent,
    required this.color,
    required this.icon,
  });

  bool get isWave => correspondent == null;
}
