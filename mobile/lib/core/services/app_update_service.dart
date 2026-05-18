import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of an update availability check.
class UpdateInfo {
  final bool isUpdateAvailable;
  final bool isForced;
  final String latestVersion;
  final String storeUrl;

  const UpdateInfo({
    required this.isUpdateAvailable,
    required this.isForced,
    required this.latestVersion,
    required this.storeUrl,
  });

  static const noUpdate = UpdateInfo(
    isUpdateAvailable: false,
    isForced: false,
    latestVersion: '',
    storeUrl: '',
  );
}

class AppUpdateService {
  static Future<UpdateInfo> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version; // e.g. "2.0.0"

      final isAndroid = !kIsWeb && Platform.isAndroid;

      final latestKey = isAndroid ? 'android_latest_version' : 'ios_latest_version';
      final minKey    = isAndroid ? 'android_min_version'    : 'ios_min_version';
      final urlKey    = isAndroid ? 'android_store_url'      : 'ios_store_url';

      final rows = await Supabase.instance.client
          .from('app_config')
          .select('key, value')
          .inFilter('key', [latestKey, minKey, urlKey]);

      if (rows.isEmpty) return UpdateInfo.noUpdate;

      final kv = <String, String>{
        for (final r in rows) r['key'] as String: r['value'] as String,
      };

      final latestVersion = kv[latestKey] ?? currentVersion;
      final minVersion    = kv[minKey]    ?? '1.0.0';
      final storeUrl      = kv[urlKey]    ?? '';

      final hasNewerVersion = _compare(latestVersion, currentVersion) > 0;
      final isBelowMin = _compare(currentVersion, minVersion) < 0;

      if (!hasNewerVersion && !isBelowMin) return UpdateInfo.noUpdate;

      return UpdateInfo(
        isUpdateAvailable: true,
        isForced: isBelowMin,
        latestVersion: latestVersion,
        storeUrl: storeUrl,
      );
    } catch (e) {
      // Network errors must not crash the app at startup
      debugPrint('[AppUpdateService] check failed (non-blocking): $e');
      return UpdateInfo.noUpdate;
    }
  }

  /// Compares two semver strings (major.minor.patch).
  /// Returns > 0 if a > b, < 0 if a < b, 0 if equal.
  static int _compare(String a, String b) {
    final ap = _parse(a);
    final bp = _parse(b);
    for (int i = 0; i < 3; i++) {
      final diff = ap[i] - bp[i];
      if (diff != 0) return diff;
    }
    return 0;
  }

  static List<int> _parse(String v) {
    final parts = v.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    while (parts.length < 3) { parts.add(0); }
    return parts;
  }
}
