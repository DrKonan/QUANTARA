import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/notification_service.dart';
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
  Future<AuthResponse> signUpWithPhone({
    required String phone,
    required String password,
    required String username,
    String? email,
  }) async {
    final authEmail = email?.isNotEmpty == true ? email! : phoneToAuthEmail(phone);

    final response = await _client.auth.signUp(
      email: authEmail,
      password: password,
      data: {
        'username': username,
        'phone': phone,
      },
    );

    if (response.user != null) {
      await _client.from('users').upsert({
        'id': response.user!.id,
        'username': username,
        'phone': phone,
        'email': email?.isNotEmpty == true ? email : null,
        'plan': 'free',
      });
    }

    NotificationService().registerToken();
    return response;
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
    return response;
  }

  Future<void> signOut() async {
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
