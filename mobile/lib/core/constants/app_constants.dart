import 'dart:io' show Platform;

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
      for (final country in allPhoneCountries) {
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

  // ── Supported countries with their payment methods ──
  // Methods listed here are informational (displayed in UI).
  // Actual payment method selection happens on PayDunya's hosted checkout page.
  static const supportedCountries = [
    PaymentCountry(
      code: 'SN', name: 'Sénégal', dialCode: '221', flag: '🇸🇳',
      methods: [
        PaymentMethod(id: 'wave_sn', name: 'Wave', color: 0xFF1BA8F0, icon: 'waves'),
        PaymentMethod(id: 'orange_sn', name: 'Orange Money', color: 0xFFFF6600, icon: 'phone'),
        PaymentMethod(id: 'free_sn', name: 'Free Money', color: 0xFF00C896, icon: 'phone'),
      ],
    ),
    PaymentCountry(
      code: 'CI', name: "Côte d'Ivoire", dialCode: '225', flag: '🇨🇮',
      localDigits: 10, keepLeadingZero: true,
      methods: [
        PaymentMethod(id: 'wave_ci', name: 'Wave', color: 0xFF1BA8F0, icon: 'waves'),
        PaymentMethod(id: 'orange_ci', name: 'Orange Money', color: 0xFFFF6600, icon: 'phone'),
        PaymentMethod(id: 'mtn_ci', name: 'MTN MoMo', color: 0xFFFFCC00, icon: 'phone'),
        PaymentMethod(id: 'moov_ci', name: 'Moov Money', color: 0xFF0066CC, icon: 'phone'),
      ],
    ),
    PaymentCountry(
      code: 'ML', name: 'Mali', dialCode: '223', flag: '🇲🇱',
      methods: [
        PaymentMethod(id: 'orange_ml', name: 'Orange Money', color: 0xFFFF6600, icon: 'phone'),
        PaymentMethod(id: 'moov_ml', name: 'Moov Money', color: 0xFF0066CC, icon: 'phone'),
      ],
    ),
    PaymentCountry(
      code: 'BF', name: 'Burkina Faso', dialCode: '226', flag: '🇧🇫',
      methods: [
        PaymentMethod(id: 'orange_bf', name: 'Orange Money', color: 0xFFFF6600, icon: 'phone'),
        PaymentMethod(id: 'moov_bf', name: 'Moov Money', color: 0xFF0066CC, icon: 'phone'),
      ],
    ),
    PaymentCountry(
      code: 'BJ', name: 'Bénin', dialCode: '229', flag: '🇧🇯',
      methods: [
        PaymentMethod(id: 'mtn_bj', name: 'MTN MoMo', color: 0xFFFFCC00, icon: 'phone'),
        PaymentMethod(id: 'moov_bj', name: 'Moov Money', color: 0xFF0066CC, icon: 'phone'),
      ],
    ),
    PaymentCountry(
      code: 'TG', name: 'Togo', dialCode: '228', flag: '🇹🇬',
      methods: [
        PaymentMethod(id: 'moov_tg', name: 'Moov Money', color: 0xFF0066CC, icon: 'phone'),
      ],
    ),
    PaymentCountry(
      code: 'NE', name: 'Niger', dialCode: '227', flag: '🇳🇪',
      methods: [
        PaymentMethod(id: 'airtel_ne', name: 'Airtel Money', color: 0xFFED1C24, icon: 'phone'),
      ],
    ),
    PaymentCountry(
      code: 'GN', name: 'Guinée', dialCode: '224', flag: '🇬🇳',
      methods: [
        PaymentMethod(id: 'orange_gn', name: 'Orange Money', color: 0xFFFF6600, icon: 'phone'),
        PaymentMethod(id: 'mtn_gn', name: 'MTN MoMo', color: 0xFFFFCC00, icon: 'phone'),
      ],
    ),
    PaymentCountry(
      code: 'CM', name: 'Cameroun', dialCode: '237', flag: '🇨🇲',
      methods: [
        PaymentMethod(id: 'orange_cm', name: 'Orange Money', color: 0xFFFF6600, icon: 'phone'),
        PaymentMethod(id: 'mtn_cm', name: 'MTN MoMo', color: 0xFFFFCC00, icon: 'phone'),
      ],
    ),
    PaymentCountry(
      code: 'GA', name: 'Gabon', dialCode: '241', flag: '🇬🇦',
      methods: [
        PaymentMethod(id: 'airtel_ga', name: 'Airtel Money', color: 0xFFED1C24, icon: 'phone'),
      ],
    ),
    PaymentCountry(
      code: 'CG', name: 'Congo', dialCode: '242', flag: '🇨🇬',
      methods: [
        PaymentMethod(id: 'airtel_cg', name: 'Airtel Money', color: 0xFFED1C24, icon: 'phone'),
        PaymentMethod(id: 'mtn_cg', name: 'MTN MoMo', color: 0xFFFFCC00, icon: 'phone'),
      ],
    ),
    PaymentCountry(
      code: 'CD', name: 'RD Congo', dialCode: '243', flag: '🇨🇩',
      methods: [
        PaymentMethod(id: 'orange_cd', name: 'Orange Money', color: 0xFFFF6600, icon: 'phone'),
        PaymentMethod(id: 'airtel_cd', name: 'Airtel Money', color: 0xFFED1C24, icon: 'phone'),
        PaymentMethod(id: 'vodacom_cd', name: 'Vodacom M-Pesa', color: 0xFFE60000, icon: 'phone'),
      ],
    ),
  ];

  /// All world countries for phone selection (login/register).
  static const allPhoneCountries = [
    PaymentCountry(code: 'AF', name: 'Afghanistan', dialCode: '93', flag: '🇦🇫', methods: []),
    PaymentCountry(code: 'ZA', name: 'Afrique du Sud', dialCode: '27', flag: '🇿🇦', methods: []),
    PaymentCountry(code: 'AL', name: 'Albanie', dialCode: '355', flag: '🇦🇱', methods: []),
    PaymentCountry(code: 'DZ', name: 'Algerie', dialCode: '213', flag: '🇩🇿', methods: []),
    PaymentCountry(code: 'DE', name: 'Allemagne', dialCode: '49', flag: '🇩🇪', methods: []),
    PaymentCountry(code: 'AD', name: 'Andorre', dialCode: '376', flag: '🇦🇩', methods: []),
    PaymentCountry(code: 'AO', name: 'Angola', dialCode: '244', flag: '🇦🇴', methods: []),
    PaymentCountry(code: 'AI', name: 'Anguilla', dialCode: '1264', flag: '🇦🇮', methods: []),
    PaymentCountry(code: 'AG', name: 'Antigua-et-Barbuda', dialCode: '1268', flag: '🇦🇬', methods: []),
    PaymentCountry(code: 'SA', name: 'Arabie saoudite', dialCode: '966', flag: '🇸🇦', methods: []),
    PaymentCountry(code: 'AR', name: 'Argentine', dialCode: '54', flag: '🇦🇷', methods: []),
    PaymentCountry(code: 'AM', name: 'Armenie', dialCode: '374', flag: '🇦🇲', methods: []),
    PaymentCountry(code: 'AW', name: 'Aruba', dialCode: '297', flag: '🇦🇼', methods: []),
    PaymentCountry(code: 'AU', name: 'Australie', dialCode: '61', flag: '🇦🇺', methods: []),
    PaymentCountry(code: 'AT', name: 'Autriche', dialCode: '43', flag: '🇦🇹', methods: []),
    PaymentCountry(code: 'AZ', name: 'Azerbaidjan', dialCode: '994', flag: '🇦🇿', methods: []),
    PaymentCountry(code: 'BS', name: 'Bahamas', dialCode: '1242', flag: '🇧🇸', methods: []),
    PaymentCountry(code: 'BH', name: 'Bahrein', dialCode: '973', flag: '🇧🇭', methods: []),
    PaymentCountry(code: 'BD', name: 'Bangladesh', dialCode: '880', flag: '🇧🇩', methods: []),
    PaymentCountry(code: 'BB', name: 'Barbade', dialCode: '1246', flag: '🇧🇧', methods: []),
    PaymentCountry(code: 'BE', name: 'Belgique', dialCode: '32', flag: '🇧🇪', methods: []),
    PaymentCountry(code: 'BZ', name: 'Belize', dialCode: '501', flag: '🇧🇿', methods: []),
    PaymentCountry(code: 'BJ', name: 'Benin', dialCode: '229', flag: '🇧🇯', methods: []),
    PaymentCountry(code: 'BM', name: 'Bermudes', dialCode: '1441', flag: '🇧🇲', methods: []),
    PaymentCountry(code: 'BT', name: 'Bhoutan', dialCode: '975', flag: '🇧🇹', methods: []),
    PaymentCountry(code: 'BY', name: 'Bielorussie', dialCode: '375', flag: '🇧🇾', methods: []),
    PaymentCountry(code: 'BO', name: 'Bolivie', dialCode: '591', flag: '🇧🇴', methods: []),
    PaymentCountry(code: 'BA', name: 'Bosnie-Herzegovine', dialCode: '387', flag: '🇧🇦', methods: []),
    PaymentCountry(code: 'BW', name: 'Botswana', dialCode: '267', flag: '🇧🇼', methods: []),
    PaymentCountry(code: 'BR', name: 'Bresil', dialCode: '55', flag: '🇧🇷', methods: []),
    PaymentCountry(code: 'BN', name: 'Brunei', dialCode: '673', flag: '🇧🇳', methods: []),
    PaymentCountry(code: 'BG', name: 'Bulgarie', dialCode: '359', flag: '🇧🇬', methods: []),
    PaymentCountry(code: 'BF', name: 'Burkina Faso', dialCode: '226', flag: '🇧🇫', methods: []),
    PaymentCountry(code: 'BI', name: 'Burundi', dialCode: '257', flag: '🇧🇮', methods: []),
    PaymentCountry(code: 'KH', name: 'Cambodge', dialCode: '855', flag: '🇰🇭', methods: []),
    PaymentCountry(code: 'CM', name: 'Cameroun', dialCode: '237', flag: '🇨🇲', methods: []),
    PaymentCountry(code: 'CA', name: 'Canada', dialCode: '1', flag: '🇨🇦', methods: []),
    PaymentCountry(code: 'CV', name: 'Cap-Vert', dialCode: '238', flag: '🇨🇻', methods: []),
    PaymentCountry(code: 'CF', name: 'Centrafrique', dialCode: '236', flag: '🇨🇫', methods: []),
    PaymentCountry(code: 'CL', name: 'Chili', dialCode: '56', flag: '🇨🇱', methods: []),
    PaymentCountry(code: 'CN', name: 'Chine', dialCode: '86', flag: '🇨🇳', methods: []),
    PaymentCountry(code: 'CY', name: 'Chypre', dialCode: '357', flag: '🇨🇾', methods: []),
    PaymentCountry(code: 'CO', name: 'Colombie', dialCode: '57', flag: '🇨🇴', methods: []),
    PaymentCountry(code: 'KM', name: 'Comores', dialCode: '269', flag: '🇰🇲', methods: []),
    PaymentCountry(code: 'CG', name: 'Congo', dialCode: '242', flag: '🇨🇬', methods: []),
    PaymentCountry(code: 'KP', name: 'Coree du Nord', dialCode: '850', flag: '🇰🇵', methods: []),
    PaymentCountry(code: 'KR', name: 'Coree du Sud', dialCode: '82', flag: '🇰🇷', methods: []),
    PaymentCountry(code: 'CR', name: 'Costa Rica', dialCode: '506', flag: '🇨🇷', methods: []),
    PaymentCountry(code: 'CI', name: 'Cote d Ivoire', dialCode: '225', flag: '🇨🇮', methods: []),
    PaymentCountry(code: 'HR', name: 'Croatie', dialCode: '385', flag: '🇭🇷', methods: []),
    PaymentCountry(code: 'CU', name: 'Cuba', dialCode: '53', flag: '🇨🇺', methods: []),
    PaymentCountry(code: 'DK', name: 'Danemark', dialCode: '45', flag: '🇩🇰', methods: []),
    PaymentCountry(code: 'DJ', name: 'Djibouti', dialCode: '253', flag: '🇩🇯', methods: []),
    PaymentCountry(code: 'DM', name: 'Dominique', dialCode: '1767', flag: '🇩🇲', methods: []),
    PaymentCountry(code: 'EG', name: 'Egypte', dialCode: '20', flag: '🇪🇬', methods: []),
    PaymentCountry(code: 'SV', name: 'El Salvador', dialCode: '503', flag: '🇸🇻', methods: []),
    PaymentCountry(code: 'AE', name: 'Emirats arabes unis', dialCode: '971', flag: '🇦🇪', methods: []),
    PaymentCountry(code: 'EC', name: 'Equateur', dialCode: '593', flag: '🇪🇨', methods: []),
    PaymentCountry(code: 'ER', name: 'Erythree', dialCode: '291', flag: '🇪🇷', methods: []),
    PaymentCountry(code: 'ES', name: 'Espagne', dialCode: '34', flag: '🇪🇸', methods: []),
    PaymentCountry(code: 'EE', name: 'Estonie', dialCode: '372', flag: '🇪🇪', methods: []),
    PaymentCountry(code: 'SZ', name: 'Eswatini', dialCode: '268', flag: '🇸🇿', methods: []),
    PaymentCountry(code: 'US', name: 'Etats-Unis', dialCode: '1', flag: '🇺🇸', methods: []),
    PaymentCountry(code: 'ET', name: 'Ethiopie', dialCode: '251', flag: '🇪🇹', methods: []),
    PaymentCountry(code: 'FJ', name: 'Fidji', dialCode: '679', flag: '🇫🇯', methods: []),
    PaymentCountry(code: 'FI', name: 'Finlande', dialCode: '358', flag: '🇫🇮', methods: []),
    PaymentCountry(code: 'FR', name: 'France', dialCode: '33', flag: '🇫🇷', methods: []),
    PaymentCountry(code: 'GA', name: 'Gabon', dialCode: '241', flag: '🇬🇦', methods: []),
    PaymentCountry(code: 'GM', name: 'Gambie', dialCode: '220', flag: '🇬🇲', methods: []),
    PaymentCountry(code: 'GE', name: 'Georgie', dialCode: '995', flag: '🇬🇪', methods: []),
    PaymentCountry(code: 'GH', name: 'Ghana', dialCode: '233', flag: '🇬🇭', methods: []),
    PaymentCountry(code: 'GR', name: 'Grece', dialCode: '30', flag: '🇬🇷', methods: []),
    PaymentCountry(code: 'GD', name: 'Grenade', dialCode: '1473', flag: '🇬🇩', methods: []),
    PaymentCountry(code: 'GL', name: 'Groenland', dialCode: '299', flag: '🇬🇱', methods: []),
    PaymentCountry(code: 'GP', name: 'Guadeloupe', dialCode: '590', flag: '🇬🇵', methods: []),
    PaymentCountry(code: 'GU', name: 'Guam', dialCode: '1671', flag: '🇬🇺', methods: []),
    PaymentCountry(code: 'GT', name: 'Guatemala', dialCode: '502', flag: '🇬🇹', methods: []),
    PaymentCountry(code: 'GN', name: 'Guinee', dialCode: '224', flag: '🇬🇳', methods: []),
    PaymentCountry(code: 'GQ', name: 'Guinee equatoriale', dialCode: '240', flag: '🇬🇶', methods: []),
    PaymentCountry(code: 'GW', name: 'Guinee-Bissau', dialCode: '245', flag: '🇬🇼', methods: []),
    PaymentCountry(code: 'GY', name: 'Guyana', dialCode: '592', flag: '🇬🇾', methods: []),
    PaymentCountry(code: 'GF', name: 'Guyane francaise', dialCode: '594', flag: '🇬🇫', methods: []),
    PaymentCountry(code: 'HT', name: 'Haiti', dialCode: '509', flag: '🇭🇹', methods: []),
    PaymentCountry(code: 'HN', name: 'Honduras', dialCode: '504', flag: '🇭🇳', methods: []),
    PaymentCountry(code: 'HK', name: 'Hong Kong', dialCode: '852', flag: '🇭🇰', methods: []),
    PaymentCountry(code: 'HU', name: 'Hongrie', dialCode: '36', flag: '🇭🇺', methods: []),
    PaymentCountry(code: 'KY', name: 'Iles Caiman', dialCode: '1345', flag: '🇰🇾', methods: []),
    PaymentCountry(code: 'CK', name: 'Iles Cook', dialCode: '682', flag: '🇨🇰', methods: []),
    PaymentCountry(code: 'MH', name: 'Iles Marshall', dialCode: '692', flag: '🇲🇭', methods: []),
    PaymentCountry(code: 'SB', name: 'Iles Salomon', dialCode: '677', flag: '🇸🇧', methods: []),
    PaymentCountry(code: 'IN', name: 'Inde', dialCode: '91', flag: '🇮🇳', methods: []),
    PaymentCountry(code: 'ID', name: 'Indonesie', dialCode: '62', flag: '🇮🇩', methods: []),
    PaymentCountry(code: 'IQ', name: 'Irak', dialCode: '964', flag: '🇮🇶', methods: []),
    PaymentCountry(code: 'IR', name: 'Iran', dialCode: '98', flag: '🇮🇷', methods: []),
    PaymentCountry(code: 'IE', name: 'Irlande', dialCode: '353', flag: '🇮🇪', methods: []),
    PaymentCountry(code: 'IS', name: 'Islande', dialCode: '354', flag: '🇮🇸', methods: []),
    PaymentCountry(code: 'IL', name: 'Israel', dialCode: '972', flag: '🇮🇱', methods: []),
    PaymentCountry(code: 'IT', name: 'Italie', dialCode: '39', flag: '🇮🇹', methods: []),
    PaymentCountry(code: 'JM', name: 'Jamaique', dialCode: '1876', flag: '🇯🇲', methods: []),
    PaymentCountry(code: 'JP', name: 'Japon', dialCode: '81', flag: '🇯🇵', methods: []),
    PaymentCountry(code: 'JO', name: 'Jordanie', dialCode: '962', flag: '🇯🇴', methods: []),
    PaymentCountry(code: 'KZ', name: 'Kazakhstan', dialCode: '7', flag: '🇰🇿', methods: []),
    PaymentCountry(code: 'KE', name: 'Kenya', dialCode: '254', flag: '🇰🇪', methods: []),
    PaymentCountry(code: 'KG', name: 'Kirghizistan', dialCode: '996', flag: '🇰🇬', methods: []),
    PaymentCountry(code: 'KI', name: 'Kiribati', dialCode: '686', flag: '🇰🇮', methods: []),
    PaymentCountry(code: 'KW', name: 'Koweit', dialCode: '965', flag: '🇰🇼', methods: []),
    PaymentCountry(code: 'LA', name: 'Laos', dialCode: '856', flag: '🇱🇦', methods: []),
    PaymentCountry(code: 'LS', name: 'Lesotho', dialCode: '266', flag: '🇱🇸', methods: []),
    PaymentCountry(code: 'LV', name: 'Lettonie', dialCode: '371', flag: '🇱🇻', methods: []),
    PaymentCountry(code: 'LB', name: 'Liban', dialCode: '961', flag: '🇱🇧', methods: []),
    PaymentCountry(code: 'LR', name: 'Liberia', dialCode: '231', flag: '🇱🇷', methods: []),
    PaymentCountry(code: 'LY', name: 'Libye', dialCode: '218', flag: '🇱🇾', methods: []),
    PaymentCountry(code: 'LI', name: 'Liechtenstein', dialCode: '423', flag: '🇱🇮', methods: []),
    PaymentCountry(code: 'LT', name: 'Lituanie', dialCode: '370', flag: '🇱🇹', methods: []),
    PaymentCountry(code: 'LU', name: 'Luxembourg', dialCode: '352', flag: '🇱🇺', methods: []),
    PaymentCountry(code: 'MO', name: 'Macao', dialCode: '853', flag: '🇲🇴', methods: []),
    PaymentCountry(code: 'MK', name: 'Macedoine du Nord', dialCode: '389', flag: '🇲🇰', methods: []),
    PaymentCountry(code: 'MG', name: 'Madagascar', dialCode: '261', flag: '🇲🇬', methods: []),
    PaymentCountry(code: 'MY', name: 'Malaisie', dialCode: '60', flag: '🇲🇾', methods: []),
    PaymentCountry(code: 'MW', name: 'Malawi', dialCode: '265', flag: '🇲🇼', methods: []),
    PaymentCountry(code: 'MV', name: 'Maldives', dialCode: '960', flag: '🇲🇻', methods: []),
    PaymentCountry(code: 'ML', name: 'Mali', dialCode: '223', flag: '🇲🇱', methods: []),
    PaymentCountry(code: 'MT', name: 'Malte', dialCode: '356', flag: '🇲🇹', methods: []),
    PaymentCountry(code: 'MA', name: 'Maroc', dialCode: '212', flag: '🇲🇦', methods: []),
    PaymentCountry(code: 'MQ', name: 'Martinique', dialCode: '596', flag: '🇲🇶', methods: []),
    PaymentCountry(code: 'MU', name: 'Maurice', dialCode: '230', flag: '🇲🇺', methods: []),
    PaymentCountry(code: 'MR', name: 'Mauritanie', dialCode: '222', flag: '🇲🇷', methods: []),
    PaymentCountry(code: 'MX', name: 'Mexique', dialCode: '52', flag: '🇲🇽', methods: []),
    PaymentCountry(code: 'FM', name: 'Micronesie', dialCode: '691', flag: '🇫🇲', methods: []),
    PaymentCountry(code: 'MD', name: 'Moldavie', dialCode: '373', flag: '🇲🇩', methods: []),
    PaymentCountry(code: 'MC', name: 'Monaco', dialCode: '377', flag: '🇲🇨', methods: []),
    PaymentCountry(code: 'MN', name: 'Mongolie', dialCode: '976', flag: '🇲🇳', methods: []),
    PaymentCountry(code: 'ME', name: 'Montenegro', dialCode: '382', flag: '🇲🇪', methods: []),
    PaymentCountry(code: 'MZ', name: 'Mozambique', dialCode: '258', flag: '🇲🇿', methods: []),
    PaymentCountry(code: 'MM', name: 'Myanmar', dialCode: '95', flag: '🇲🇲', methods: []),
    PaymentCountry(code: 'NA', name: 'Namibie', dialCode: '264', flag: '🇳🇦', methods: []),
    PaymentCountry(code: 'NR', name: 'Nauru', dialCode: '674', flag: '🇳🇷', methods: []),
    PaymentCountry(code: 'NP', name: 'Nepal', dialCode: '977', flag: '🇳🇵', methods: []),
    PaymentCountry(code: 'NI', name: 'Nicaragua', dialCode: '505', flag: '🇳🇮', methods: []),
    PaymentCountry(code: 'NE', name: 'Niger', dialCode: '227', flag: '🇳🇪', methods: []),
    PaymentCountry(code: 'NG', name: 'Nigeria', dialCode: '234', flag: '🇳🇬', methods: []),
    PaymentCountry(code: 'NO', name: 'Norvege', dialCode: '47', flag: '🇳🇴', methods: []),
    PaymentCountry(code: 'NZ', name: 'Nouvelle-Zelande', dialCode: '64', flag: '🇳🇿', methods: []),
    PaymentCountry(code: 'OM', name: 'Oman', dialCode: '968', flag: '🇴🇲', methods: []),
    PaymentCountry(code: 'UG', name: 'Ouganda', dialCode: '256', flag: '🇺🇬', methods: []),
    PaymentCountry(code: 'UZ', name: 'Ouzbekistan', dialCode: '998', flag: '🇺🇿', methods: []),
    PaymentCountry(code: 'PK', name: 'Pakistan', dialCode: '92', flag: '🇵🇰', methods: []),
    PaymentCountry(code: 'PW', name: 'Palaos', dialCode: '680', flag: '🇵🇼', methods: []),
    PaymentCountry(code: 'PS', name: 'Palestine', dialCode: '970', flag: '🇵🇸', methods: []),
    PaymentCountry(code: 'PA', name: 'Panama', dialCode: '507', flag: '🇵🇦', methods: []),
    PaymentCountry(code: 'PG', name: 'Papouasie-Nlle-Guinee', dialCode: '675', flag: '🇵🇬', methods: []),
    PaymentCountry(code: 'PY', name: 'Paraguay', dialCode: '595', flag: '🇵🇾', methods: []),
    PaymentCountry(code: 'NL', name: 'Pays-Bas', dialCode: '31', flag: '🇳🇱', methods: []),
    PaymentCountry(code: 'PE', name: 'Perou', dialCode: '51', flag: '🇵🇪', methods: []),
    PaymentCountry(code: 'PH', name: 'Philippines', dialCode: '63', flag: '🇵🇭', methods: []),
    PaymentCountry(code: 'PL', name: 'Pologne', dialCode: '48', flag: '🇵🇱', methods: []),
    PaymentCountry(code: 'PF', name: 'Polynesie francaise', dialCode: '689', flag: '🇵🇫', methods: []),
    PaymentCountry(code: 'PR', name: 'Porto Rico', dialCode: '1787', flag: '🇵🇷', methods: []),
    PaymentCountry(code: 'PT', name: 'Portugal', dialCode: '351', flag: '🇵🇹', methods: []),
    PaymentCountry(code: 'QA', name: 'Qatar', dialCode: '974', flag: '🇶🇦', methods: []),
    PaymentCountry(code: 'CD', name: 'RD Congo', dialCode: '243', flag: '🇨🇩', methods: []),
    PaymentCountry(code: 'DO', name: 'Rep. dominicaine', dialCode: '1809', flag: '🇩🇴', methods: []),
    PaymentCountry(code: 'RO', name: 'Roumanie', dialCode: '40', flag: '🇷🇴', methods: []),
    PaymentCountry(code: 'GB', name: 'Royaume-Uni', dialCode: '44', flag: '🇬🇧', methods: []),
    PaymentCountry(code: 'RU', name: 'Russie', dialCode: '7', flag: '🇷🇺', methods: []),
    PaymentCountry(code: 'RW', name: 'Rwanda', dialCode: '250', flag: '🇷🇼', methods: []),
    PaymentCountry(code: 'KN', name: 'Saint-Kitts-et-Nevis', dialCode: '1869', flag: '🇰🇳', methods: []),
    PaymentCountry(code: 'SM', name: 'Saint-Marin', dialCode: '378', flag: '🇸🇲', methods: []),
    PaymentCountry(code: 'VC', name: 'Saint-Vincent-et-Grenadines', dialCode: '1784', flag: '🇻🇨', methods: []),
    PaymentCountry(code: 'LC', name: 'Sainte-Lucie', dialCode: '1758', flag: '🇱🇨', methods: []),
    PaymentCountry(code: 'WS', name: 'Samoa', dialCode: '685', flag: '🇼🇸', methods: []),
    PaymentCountry(code: 'AS', name: 'Samoa americaines', dialCode: '1684', flag: '🇦🇸', methods: []),
    PaymentCountry(code: 'ST', name: 'Sao Tome-et-Principe', dialCode: '239', flag: '🇸🇹', methods: []),
    PaymentCountry(code: 'SN', name: 'Senegal', dialCode: '221', flag: '🇸🇳', methods: []),
    PaymentCountry(code: 'RS', name: 'Serbie', dialCode: '381', flag: '🇷🇸', methods: []),
    PaymentCountry(code: 'SC', name: 'Seychelles', dialCode: '248', flag: '🇸🇨', methods: []),
    PaymentCountry(code: 'SL', name: 'Sierra Leone', dialCode: '232', flag: '🇸🇱', methods: []),
    PaymentCountry(code: 'SG', name: 'Singapour', dialCode: '65', flag: '🇸🇬', methods: []),
    PaymentCountry(code: 'SK', name: 'Slovaquie', dialCode: '421', flag: '🇸🇰', methods: []),
    PaymentCountry(code: 'SI', name: 'Slovenie', dialCode: '386', flag: '🇸🇮', methods: []),
    PaymentCountry(code: 'SO', name: 'Somalie', dialCode: '252', flag: '🇸🇴', methods: []),
    PaymentCountry(code: 'SD', name: 'Soudan', dialCode: '249', flag: '🇸🇩', methods: []),
    PaymentCountry(code: 'SS', name: 'Soudan du Sud', dialCode: '211', flag: '🇸🇸', methods: []),
    PaymentCountry(code: 'LK', name: 'Sri Lanka', dialCode: '94', flag: '🇱🇰', methods: []),
    PaymentCountry(code: 'SE', name: 'Suede', dialCode: '46', flag: '🇸🇪', methods: []),
    PaymentCountry(code: 'CH', name: 'Suisse', dialCode: '41', flag: '🇨🇭', methods: []),
    PaymentCountry(code: 'SR', name: 'Suriname', dialCode: '597', flag: '🇸🇷', methods: []),
    PaymentCountry(code: 'SY', name: 'Syrie', dialCode: '963', flag: '🇸🇾', methods: []),
    PaymentCountry(code: 'TJ', name: 'Tadjikistan', dialCode: '992', flag: '🇹🇯', methods: []),
    PaymentCountry(code: 'TW', name: 'Taiwan', dialCode: '886', flag: '🇹🇼', methods: []),
    PaymentCountry(code: 'TZ', name: 'Tanzanie', dialCode: '255', flag: '🇹🇿', methods: []),
    PaymentCountry(code: 'TD', name: 'Tchad', dialCode: '235', flag: '🇹🇩', methods: []),
    PaymentCountry(code: 'CZ', name: 'Tchequie', dialCode: '420', flag: '🇨🇿', methods: []),
    PaymentCountry(code: 'TH', name: 'Thailande', dialCode: '66', flag: '🇹🇭', methods: []),
    PaymentCountry(code: 'TL', name: 'Timor-Leste', dialCode: '670', flag: '🇹🇱', methods: []),
    PaymentCountry(code: 'TG', name: 'Togo', dialCode: '228', flag: '🇹🇬', methods: []),
    PaymentCountry(code: 'TO', name: 'Tonga', dialCode: '676', flag: '🇹🇴', methods: []),
    PaymentCountry(code: 'TT', name: 'Trinite-et-Tobago', dialCode: '1868', flag: '🇹🇹', methods: []),
    PaymentCountry(code: 'TN', name: 'Tunisie', dialCode: '216', flag: '🇹🇳', methods: []),
    PaymentCountry(code: 'TM', name: 'Turkmenistan', dialCode: '993', flag: '🇹🇲', methods: []),
    PaymentCountry(code: 'TR', name: 'Turquie', dialCode: '90', flag: '🇹🇷', methods: []),
    PaymentCountry(code: 'TV', name: 'Tuvalu', dialCode: '688', flag: '🇹🇻', methods: []),
    PaymentCountry(code: 'UA', name: 'Ukraine', dialCode: '380', flag: '🇺🇦', methods: []),
    PaymentCountry(code: 'UY', name: 'Uruguay', dialCode: '598', flag: '🇺🇾', methods: []),
    PaymentCountry(code: 'VU', name: 'Vanuatu', dialCode: '678', flag: '🇻🇺', methods: []),
    PaymentCountry(code: 'VE', name: 'Venezuela', dialCode: '58', flag: '🇻🇪', methods: []),
    PaymentCountry(code: 'VN', name: 'Viet Nam', dialCode: '84', flag: '🇻🇳', methods: []),
    PaymentCountry(code: 'YE', name: 'Yemen', dialCode: '967', flag: '🇾🇪', methods: []),
    PaymentCountry(code: 'ZM', name: 'Zambie', dialCode: '260', flag: '🇿🇲', methods: []),
    PaymentCountry(code: 'ZW', name: 'Zimbabwe', dialCode: '263', flag: '🇿🇼', methods: []),
  ];

  static PaymentCountry get defaultCountry => supportedCountries.first;

  /// Detect country from device locale (e.g., "fr_SN" → Sénégal).
  /// Falls back to [defaultCountry] if no match found.
  static PaymentCountry countryFromLocale() {
    try {
      final locale = Platform.localeName; // e.g. "fr_SN", "en-CI"
      final parts = locale.split(RegExp(r'[_\-]'));
      if (parts.length >= 2) {
        final code = parts.last.toUpperCase();
        return allPhoneCountries.firstWhere(
          (c) => c.code == code,
          orElse: () => defaultCountry,
        );
      }
    } catch (_) {}
    return defaultCountry;
  }
}

/// A supported country with its available payment methods
class PaymentCountry {
  final String code;
  final String name;
  final String dialCode;
  final String flag;
  final List<PaymentMethod> methods;
  final int localDigits;
  /// Quand `true`, le 0 initial du numéro local fait partie du numéro
  /// abonné (pas un indicatif national) et ne doit PAS être supprimé
  /// lors de la construction du format E.164.
  /// Ex: Côte d'Ivoire — 0707123456 → +2250707123456 (pas +225707123456)
  final bool keepLeadingZero;

  const PaymentCountry({
    required this.code,
    required this.name,
    required this.dialCode,
    required this.flag,
    required this.methods,
    this.localDigits = 9,
    this.keepLeadingZero = false,
  });

  String get label => '$flag +$dialCode';
  String get fullLabel => '$flag $name (+$dialCode)';
}

/// A payment method available in a country (informational — user picks on PayDunya page)
class PaymentMethod {
  final String id;
  final String name;
  final int color;
  final String icon; // 'waves' or 'phone'

  const PaymentMethod({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
  });

  bool get isWave => icon == 'waves';
}
