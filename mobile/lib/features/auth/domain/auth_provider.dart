import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/device_fingerprint_service.dart';
import '../../profile/domain/user_profile_model.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.valueOrNull?.session?.user;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

final authLoadingProvider = StateProvider<bool>((ref) => false);
final authErrorProvider = StateProvider<String?>((ref) => null);

// User profile from public.users table
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('users')
      .select()
      .eq('id', user.id)
      .maybeSingle();

  if (data == null) return null;
  return UserProfile.fromJson(data);
});

class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  /// Convert phone to a deterministic email for Supabase auth.
  /// Users without a real email use this as their auth identifier.
  static String phoneToAuthEmail(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    return '$cleaned@phone.quantara.app';
  }

  /// Register with phone + password + optional email.
  /// Supabase auth uses email/password under the hood.
  /// Returns a SignUpResult with the auth response and trial info.
  Future<SignUpResult> signUpWithPhone({
    required String phone,
    required String password,
    required String username,
    String? email,
  }) async {
    // Check if this device already used a trial
    final trialCheck = await DeviceFingerprintService().checkTrialUsed();
    final trialAllowed = trialCheck == null;

    final authEmail = email?.isNotEmpty == true ? email! : phoneToAuthEmail(phone);
    final hasRealEmail = email?.isNotEmpty == true;

    debugPrint('[Quantara] signUp authEmail=$authEmail hasRealEmail=$hasRealEmail');

    final response = await _client.auth.signUp(
      email: authEmail,
      password: password,
      data: {
        'username': username,
        'phone': phone,
      },
    );

    debugPrint('[Quantara] signUp response: user=${response.user?.id}, session=${response.session != null}, identities=${response.user?.identities?.length}');

    // Supabase may return a user without session if email confirmation is on.
    // For phone-derived emails we auto-login immediately after signup.
    if (response.session == null && response.user != null) {
      debugPrint('[Quantara] No session after signUp, trying auto-login...');
      try {
        final loginResponse = await _client.auth.signInWithPassword(
          email: authEmail,
          password: password,
        );
        debugPrint('[Quantara] Auto-login OK');
        await _upsertProfile(
          userId: loginResponse.user!.id,
          username: username,
          phone: phone,
          email: hasRealEmail ? email : null,
          grantTrial: trialAllowed,
        );
        NotificationService().registerToken();
        AnalyticsService().logSignUp(hasRealEmail ? 'email' : 'phone');
        AnalyticsService().setUserId(loginResponse.user?.id);
        if (trialAllowed) AnalyticsService().logTrialStart();
        _saveBiometricCredentials(authEmail, password);
        // Register device trial
        await DeviceFingerprintService().registerTrial(
          userId: loginResponse.user!.id,
          phone: phone,
          email: hasRealEmail ? email : null,
        );
        return SignUpResult(
          response: loginResponse,
          trialGranted: trialAllowed,
          previousContact: trialCheck?.displayContact,
        );
      } catch (loginErr) {
        debugPrint('[Quantara] Auto-login FAILED: $loginErr');
        if (response.user != null) {
          await _upsertProfileAnon(
            userId: response.user!.id,
            username: username,
            phone: phone,
            email: hasRealEmail ? email : null,
            grantTrial: trialAllowed,
          );
        }
        if (hasRealEmail) {
          throw Exception('email_confirmation_required');
        }
        throw Exception('signup_blocked_confirm_email');
      }
    }

    // Session exists — normal flow
    if (response.user != null) {
      debugPrint('[Quantara] Session exists, upserting profile...');
      try {
        await _upsertProfile(
          userId: response.user!.id,
          username: username,
          phone: phone,
          email: hasRealEmail ? email : null,
          grantTrial: trialAllowed,
        );
        debugPrint('[Quantara] Profile upsert OK');
      } catch (upsertErr) {
        debugPrint('[Quantara] Profile upsert FAILED: $upsertErr');
        rethrow;
      }
    }

    NotificationService().registerToken();
    AnalyticsService().logSignUp(hasRealEmail ? 'email' : 'phone');
    AnalyticsService().setUserId(response.user?.id);
    if (trialAllowed) AnalyticsService().logTrialStart();
    _saveBiometricCredentials(authEmail, password);

    // Register device trial
    if (response.user != null) {
      await DeviceFingerprintService().registerTrial(
        userId: response.user!.id,
        phone: phone,
        email: hasRealEmail ? email : null,
      );
    }

    return SignUpResult(
      response: response,
      trialGranted: trialAllowed,
      previousContact: trialCheck?.displayContact,
    );
  }

  Future<void> _upsertProfile({
    required String userId,
    required String username,
    required String phone,
    String? email,
    bool grantTrial = true,
  }) async {
    final data = <String, dynamic>{
      'id': userId,
      'username': username,
      'phone': phone,
      'email': email,
      'plan': 'free',
    };

    if (grantTrial) {
      final trialEnd = DateTime.now().add(const Duration(days: AppConstants.trialDurationDays));
      data['trial_used'] = true;
      data['trial_ends_at'] = trialEnd.toIso8601String();
    } else {
      data['trial_used'] = true;
      data['trial_ends_at'] = DateTime.now().toIso8601String(); // Already expired
    }

    await _client.from('users').upsert(data);
  }

  /// Upsert profile using service role or without RLS (for pre-auth scenarios)
  Future<void> _upsertProfileAnon({
    required String userId,
    required String username,
    required String phone,
    String? email,
    bool grantTrial = true,
  }) async {
    try {
      final data = <String, dynamic>{
        'id': userId,
        'username': username,
        'phone': phone,
        'email': email,
        'plan': 'free',
      };

      if (grantTrial) {
        final trialEnd = DateTime.now().add(const Duration(days: AppConstants.trialDurationDays));
        data['trial_used'] = true;
        data['trial_ends_at'] = trialEnd.toIso8601String();
      } else {
        data['trial_used'] = true;
        data['trial_ends_at'] = DateTime.now().toIso8601String();
      }

      await _client.from('users').upsert(data);
    } catch (_) {
      // Silently fail — profile will be created on first login
    }
  }

  /// Login with phone or email + password.
  Future<AuthResponse> signIn({
    String? phone,
    String? email,
    required String password,
  }) async {
    final authEmail = email?.isNotEmpty == true
        ? email!
        : phoneToAuthEmail(phone ?? '');

    final response = await _client.auth.signInWithPassword(
      email: authEmail,
      password: password,
    );

    NotificationService().registerToken();
    AnalyticsService().logLogin(email?.isNotEmpty == true ? 'email' : 'phone');
    AnalyticsService().setUserId(response.user?.id);

    // Save credentials for biometric re-login
    _saveBiometricCredentials(authEmail, password);

    return response;
  }

  /// Silently offer to save credentials for biometric login.
  void _saveBiometricCredentials(String authEmail, String password) {
    BiometricService().isDeviceSupported.then((supported) {
      if (supported) {
        BiometricService().saveCredentials(
          authEmail: authEmail,
          password: password,
        );
      }
    });
  }

  Future<void> signOut() async {
    AnalyticsService().setUserId(null);
    await _client.auth.signOut();
  }

  Future<void> deleteAccount() async {
    AnalyticsService().logDeleteAccount();
    await _client.functions.invoke('delete-account', method: HttpMethod.post);
    AnalyticsService().setUserId(null);
    await BiometricService().disable();
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  Future<void> updateProfile({
    String? username,
    String? avatarUrl,
    String? phone,
    String? email,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final updates = <String, dynamic>{};
    if (username != null) updates['username'] = username;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (phone != null) updates['phone'] = phone;
    if (email != null) updates['email'] = email;

    if (updates.isNotEmpty) {
      await _client.from('users').update(updates).eq('id', userId);
    }
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthService(client);
});

/// Result of a signup attempt, includes trial eligibility info.
class SignUpResult {
  final AuthResponse response;
  final bool trialGranted;
  final String? previousContact;

  const SignUpResult({
    required this.response,
    required this.trialGranted,
    this.previousContact,
  });
}
