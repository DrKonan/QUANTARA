class UserProfile {
  final String id;
  final String? username;
  final String? avatarUrl;
  final String? phone;
  final String plan; // 'free' | 'premium'
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

  bool get isPremium => plan == 'premium';

  bool get isTrialActive {
    if (!trialUsed || trialEndsAt == null) return false;
    return DateTime.now().isBefore(trialEndsAt!);
  }

  bool get hasAccess => isPremium || isTrialActive;

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
