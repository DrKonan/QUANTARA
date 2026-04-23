abstract class AppConstants {
  static const appName = 'Nakora';
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

  // Plan prices (base XOF/XAF)
  static const priceStarter = 1000;
  static const pricePro = 2000;
  static const priceVip = 4000;

  /// Map plan → base price (XOF)
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

  // ── Currency conversion ──
  // Base prices are in XOF. Other currencies use rounded conversions.
  static const currencySymbols = {
    'XOF': 'F',
    'XAF': 'F',
    'GNF': 'GNF',
    'CDF': 'FC',
  };

  /// Price multipliers relative to XOF (rounded to nice numbers)
  /// XOF = XAF (1:1 parity, CFA franc zones)
  /// GNF ≈ 14× XOF → 1000 XOF = 14000 GNF
  /// CDF ≈ 3.5× XOF → 1000 XOF = 3500 CDF
  static const _currencyMultipliers = {
    'XOF': 1.0,
    'XAF': 1.0,
    'GNF': 14.0,
    'CDF': 3.5,
  };

  /// Get the price for a plan in a specific currency (always rounded)
  static int getPriceInCurrency(String plan, String currency) {
    final basePrice = planPrices[plan] ?? 0;
    final multiplier = _currencyMultipliers[currency] ?? 1.0;
    final raw = basePrice * multiplier;
    // Round to nearest 500 for cleaner numbers
    return ((raw / 500).round() * 500).clamp(500, 999999);
  }

  /// Format price with currency symbol
  static String formatPrice(int amount, String currency) {
    final symbol = currencySymbols[currency] ?? currency;
    final formatted = _formatNumber(amount);
    return '$formatted $symbol';
  }

  /// Format a plan price for display in a given currency
  static String planPriceLabel(String plan, String currency) {
    final amount = getPriceInCurrency(plan, currency);
    return '${formatPrice(amount, currency)}/mois';
  }

  static String _formatNumber(int n) {
    if (n < 1000) return '$n';
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  /// Get currency for a country code
  static String currencyForCountry(String countryCode) {
    switch (countryCode) {
      case 'CI': case 'SN': case 'ML': case 'BF':
      case 'BJ': case 'TG': case 'NE':
        return 'XOF';
      case 'CM': case 'GA': case 'CG':
        return 'XAF';
      case 'GN':
        return 'GNF';
      case 'CD':
        return 'CDF';
      default:
        return 'XOF';
    }
  }

  /// Detect country from a phone number (with or without +).
  /// Matches longest dial code first for accuracy.
  static PaymentCountry? countryFromPhone(String? phone) {
    if (phone == null || phone.isEmpty) return null;
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    // Try longest dial codes first (3 digits) then 2
    for (final len in [3, 2]) {
      if (digits.length < len) continue;
      final prefix = digits.substring(0, len);
      for (final country in supportedCountries) {
        if (country.dialCode == prefix) return country;
      }
    }
    return null;
  }

  /// Get currency from a phone number
  static String currencyFromPhone(String? phone) {
    final country = countryFromPhone(phone);
    if (country == null) return 'XOF';
    return currencyForCountry(country.code);
  }

  // PawaPay correspondents (legacy keys)
  static const correspondentOrangeCi = 'orange_ci';
  static const correspondentMtnCi = 'mtn_ci';

  // ── Supported countries with their payment methods ──
  // Each country lists the mobile money providers available via PawaPay.
  // The `correspondent` key is sent to the backend.
  static const supportedCountries = [
    PaymentCountry(
      code: 'CI', name: "Côte d'Ivoire", dialCode: '225', flag: '🇨🇮', localDigits: 10,
      methods: [
        PaymentMethod(id: 'orange_ci', name: 'Orange Money', correspondent: 'ORANGE_CIV', color: 0xFFFF6600, icon: 'phone'),
        PaymentMethod(id: 'mtn_ci', name: 'MTN MoMo', correspondent: 'MTN_MOMO_CIV', color: 0xFFFFCC00, icon: 'phone'),
      ],
    ),
    PaymentCountry(
      code: 'SN', name: 'Sénégal', dialCode: '221', flag: '🇸🇳', localDigits: 9,
      methods: [
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
    // Strip + or 00 international prefix
    if (cleaned.startsWith('+')) cleaned = cleaned.substring(1);
    if (cleaned.startsWith('00')) cleaned = cleaned.substring(2);
    // Prepend country code only if not already present
    // NOTE: do NOT strip a leading 0 — in West Africa the 0 is part of the local number
    if (!cleaned.startsWith(countryCode)) {
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
