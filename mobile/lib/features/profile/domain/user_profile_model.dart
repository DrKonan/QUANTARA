class UserProfile {
  final String id;
  final String? username;
  final String? avatarUrl;
  final String? phone;
  final String plan; // 'free' | 'starter' | 'pro' | 'vip'
  final bool trialUsed;
  final DateTime? trialEndsAt;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    this.username,
    this.avatarUrl,
    this.phone,
    this.plan = 'free',
    this.trialUsed = false,
    this.trialEndsAt,
    required this.createdAt,
  });

  bool get isFree => plan == 'free';
  bool get isStarter => plan == 'starter';
  bool get isPro => plan == 'pro';
  bool get isVip => plan == 'vip';

  /// Has any paid subscription (starter, pro, or vip)
  bool get isPremium => isStarter || isPro || isVip;

  /// Has access to combo predictions (pro + vip or trial)
  bool get hasComboAccess => isPro || isVip || isTrialActive;

  /// Has access to live predictions (pro + vip or trial)
  bool get hasLiveAccess => isPro || isVip || isTrialActive;

  /// Max combos visible per day
  int get comboLimit {
    if (isTrialActive) return 1; // Trial = same access as Pro
    switch (plan) {
      case 'pro': return 1;
      case 'vip': return 3;
      default: return 0;
    }
  }

  /// Check if user's effective plan meets a required plan level
  bool meetsRequirement(String requiredPlan) {
    const hierarchy = {'free': 0, 'starter': 1, 'pro': 2, 'vip': 3};
    return (hierarchy[effectivePlan] ?? 0) >= (hierarchy[requiredPlan] ?? 0);
  }

  bool get isTrialActive {
    if (!trialUsed || trialEndsAt == null) return false;
    return DateTime.now().isBefore(trialEndsAt!);
  }

  bool get hasAccess => isPremium || isTrialActive;

  /// Effective plan: VIP during trial, actual plan otherwise
  String get effectivePlan => isTrialActive ? 'vip' : plan;

  /// Daily match limit based on effective plan (-1 = unlimited)
  int get dailyMatchLimit {
    switch (effectivePlan) {
      case 'starter': return 5;
      case 'pro': return 15;
      case 'vip': return -1;
      default: return 1;
    }
  }

  String get planLabel {
    if (isTrialActive && isFree) return 'VIP (Essai)';
    switch (plan) {
      case 'starter': return 'Starter';
      case 'pro': return 'Pro';
      case 'vip': return 'VIP';
      default: return 'Gratuit';
    }
  }

  String get planEmoji {
    if (isTrialActive && isFree) return '🎁';
    switch (plan) {
      case 'starter': return '⚡';
      case 'pro': return '💎';
      case 'vip': return '👑';
      default: return '🆓';
    }
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      phone: json['phone'] as String?,
      plan: json['plan'] as String? ?? 'free',
      trialUsed: json['trial_used'] as bool? ?? false,
      trialEndsAt: json['trial_ends_at'] != null
          ? DateTime.parse(json['trial_ends_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
