import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/analytics_service.dart';
import '../services/notification_service.dart';

class BiometricService {
  BiometricService._();
  static final BiometricService _instance = BiometricService._();
  factory BiometricService() => _instance;

  final _auth = LocalAuthentication();
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyEmail = 'bio_auth_email';
  static const _keyPassword = 'bio_auth_password';
  static const _keyEnabled = 'bio_auth_enabled';

  /// Check if device supports biometrics (Face ID / Touch ID / fingerprint).
  Future<bool> get isDeviceSupported async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Check if user has previously enabled biometric login.
  Future<bool> get isEnabled async {
    final val = await _storage.read(key: _keyEnabled);
    return val == 'true';
  }

  /// Check if real credentials are stored (= biometric login is ready).
  Future<bool> get hasStoredCredentials async {
    final email = await _storage.read(key: _keyEmail);
    final password = await _storage.read(key: _keyPassword);
    return email != null && email.isNotEmpty && email != '_pending_' &&
           password != null && password.isNotEmpty && password != '_pending_';
  }

  /// Get a user-friendly label for the available biometric type.
  Future<String> get biometricLabel async {
    try {
      final types = await _auth.getAvailableBiometrics();
      if (types.contains(BiometricType.face)) return 'Face ID';
      if (types.contains(BiometricType.fingerprint)) return 'Touch ID';
      if (types.contains(BiometricType.strong)) return 'Biométrie';
      return 'Biométrie';
    } catch (_) {
      return 'Biométrie';
    }
  }

  /// Enable biometric login (flag only).
  Future<void> enable() async {
    await _storage.write(key: _keyEnabled, value: 'true');
    debugPrint('[Nakora] Biometric enabled');
  }

  /// Save credentials securely. Called after a successful password login
  /// ONLY if the user has already enabled biometric.
  Future<void> saveCredentials({
    required String authEmail,
    required String password,
  }) async {
    await _storage.write(key: _keyEmail, value: authEmail);
    await _storage.write(key: _keyPassword, value: password);
    debugPrint('[Nakora] Biometric credentials saved');
  }

  /// Enable biometric and immediately verify + save credentials via Supabase.
  /// Returns true on success, false if password is wrong.
  Future<bool> enableWithCredentials({
    required String authEmail,
    required String password,
  }) async {
    try {
      // Re-authenticate to verify the password is correct
      await Supabase.instance.client.auth.signInWithPassword(
        email: authEmail,
        password: password,
      );
      await enable();
      await saveCredentials(authEmail: authEmail, password: password);
      debugPrint('[Nakora] Biometric enabled + credentials saved');
      return true;
    } catch (e) {
      debugPrint('[Nakora] enableWithCredentials failed: $e');
      return false;
    }
  }

  /// Disable biometric login and clear stored credentials.
  Future<void> disable() async {
    await _storage.delete(key: _keyEmail);
    await _storage.delete(key: _keyPassword);
    await _storage.write(key: _keyEnabled, value: 'false');
    debugPrint('[Nakora] Biometric credentials cleared');
  }

  /// Just verify biometrics (no sign-in). Used when enabling biometric login.
  Future<bool> authenticateBiometricOnly() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Vérifiez votre identité pour activer la connexion biométrique',
        // biometricOnly: false = accepte aussi PIN/schéma comme fallback lors de l'activation
        biometricOnly: false,
        persistAcrossBackgrounding: false,
      );
    } catch (e) {
      debugPrint('[Nakora] Biometric check failed: $e');
      return false;
    }
  }

  /// Authenticate with biometrics then sign in via Supabase.
  /// Returns true on success, false on cancellation/failure.
  Future<bool> authenticateAndSignIn() async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Connectez-vous à Nakora',
        biometricOnly: false,
        persistAcrossBackgrounding: false,
      );

      if (!authenticated) return false;

      final email = await _storage.read(key: _keyEmail);
      final password = await _storage.read(key: _keyPassword);

      if (email == null || password == null) {
        debugPrint('[Nakora] Biometric auth OK but no stored credentials');
        return false;
      }

      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      NotificationService().registerToken();
      AnalyticsService().logLogin('biometric');
      AnalyticsService().setUserId(Supabase.instance.client.auth.currentUser?.id);

      debugPrint('[Nakora] Biometric sign-in successful');
      return true;
    } catch (e) {
      debugPrint('[Nakora] Biometric sign-in failed: $e');
      return false;
    }
  }
}
