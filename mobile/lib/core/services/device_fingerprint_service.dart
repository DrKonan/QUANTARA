import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Generates and persists a unique installation ID in secure storage.
/// On iOS, Keychain persists across app reinstalls.
/// On Android, Keystore persists across app reinstalls (unless factory reset).
class DeviceFingerprintService {
  static const _storageKey = 'quantara_installation_id';
  static final _storage = FlutterSecureStorage();

  static DeviceFingerprintService? _instance;
  String? _cachedId;

  DeviceFingerprintService._();
  factory DeviceFingerprintService() => _instance ??= DeviceFingerprintService._();

  /// Get or create the installation ID.
  Future<String> getInstallationId() async {
    if (_cachedId != null) return _cachedId!;

    var id = await _storage.read(key: _storageKey);
    if (id == null || id.isEmpty) {
      // Generate a UUID-like ID without external package
      id = _generateUuid();
      await _storage.write(key: _storageKey, value: id);
      debugPrint('[Nakora] New installation ID generated: ${id.substring(0, 8)}...');
    }
    _cachedId = id;
    return id;
  }

  /// Check if this device already used a trial.
  /// Returns the masked contact info of the previous account, or null if no trial was used.
  Future<TrialCheckResult?> checkTrialUsed() async {
    try {
      final installId = await getInstallationId();
      final client = Supabase.instance.client;

      final data = await client
          .from('device_trials')
          .select('phone, email')
          .eq('installation_id', installId)
          .limit(1)
          .maybeSingle();

      if (data == null) return null;

      final phone = data['phone'] as String?;
      final email = data['email'] as String?;

      return TrialCheckResult(
        maskedPhone: phone != null ? _maskPhone(phone) : null,
        maskedEmail: email != null ? _maskEmail(email) : null,
      );
    } catch (e) {
      debugPrint('[Nakora] Trial check error: $e');
      return null; // On error, allow trial (fail open)
    }
  }

  /// Register this device's trial usage after a successful signup.
  Future<void> registerTrial({
    required String userId,
    String? phone,
    String? email,
  }) async {
    try {
      final installId = await getInstallationId();
      final client = Supabase.instance.client;

      await client.from('device_trials').upsert({
        'installation_id': installId,
        'user_id': userId,
        'phone': phone,
        'email': email,
      });
      debugPrint('[Nakora] Device trial registered');
    } catch (e) {
      debugPrint('[Nakora] Device trial registration error: $e');
    }
  }

  String _maskPhone(String phone) {
    if (phone.length <= 6) return '***${phone.substring(phone.length - 2)}';
    return '${phone.substring(0, 4)}${'*' * (phone.length - 6)}${phone.substring(phone.length - 2)}';
  }

  String _maskEmail(String email) {
    if (email.endsWith('@phone.nakora.app')) return '';
    final parts = email.split('@');
    if (parts.length != 2) return '***';
    final name = parts[0];
    if (name.length <= 2) return '$name@${parts[1]}';
    return '${name.substring(0, 2)}${'*' * (name.length - 2)}@${parts[1]}';
  }

  /// Simple UUID v4 generator (no external dependency)
  String _generateUuid() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final chars = '0123456789abcdef';
    final buf = StringBuffer();
    for (var i = 0; i < 32; i++) {
      if (i == 8 || i == 12 || i == 16 || i == 20) buf.write('-');
      final idx = ((now >> (i * 2)) ^ (i * 7 + now ~/ (i + 1))) & 0xF;
      buf.write(chars[idx % chars.length]);
    }
    return buf.toString();
  }
}

class TrialCheckResult {
  final String? maskedPhone;
  final String? maskedEmail;

  const TrialCheckResult({this.maskedPhone, this.maskedEmail});

  String get displayContact {
    if (maskedPhone != null && maskedPhone!.isNotEmpty) return maskedPhone!;
    if (maskedEmail != null && maskedEmail!.isNotEmpty) return maskedEmail!;
    return 'un compte précédent';
  }
}
