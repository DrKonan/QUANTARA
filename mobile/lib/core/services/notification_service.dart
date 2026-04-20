import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/notifications/presentation/screens/notification_center_screen.dart';

/// Top-level handler for background messages (must be top-level function).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[Quantara] Background message: ${message.notification?.title}');
}

// Preference keys (must match notification_settings_screen.dart)
const _kMaster = 'notif_master';
const _kPredictions = 'notif_predictions';
const _kResults = 'notif_results';
const _kLive = 'notif_live';
const _kCombos = 'notif_combos';
// ignore: unused_element
const _kPromos = 'notif_promos';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'quantara_predictions',
    'Pronos Quantara',
    description: 'Notifications de pronostics et résultats',
    importance: Importance.high,
  );

  bool _initialized = false;

  // Track known IDs to only notify on truly new items
  final Set<String> _knownPredictionIds = {};
  final Set<String> _knownComboIds = {};
  final Set<String> _knownLiveIds = {};

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('[Quantara] Notification permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[Quantara] Notifications denied by user');
      return;
    }

    await _setupLocalNotifications();

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    await registerToken();
    _messaging.onTokenRefresh.listen((_) => registerToken());
  }

  Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        debugPrint('[Quantara] Local notification tapped: ${response.payload}');
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
  }

  // ── Preference-aware local notification triggers ──

  Future<bool> _isEnabled(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final masterOn = prefs.getBool(_kMaster) ?? true;
    if (!masterOn) return false;
    return prefs.getBool(key) ?? true;
  }

  Future<void> _showLocal({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? type,
  }) async {
    // Store in notification center
    NotificationStore.add(NotificationItem(
      title: title,
      body: body,
      timestamp: DateTime.now().toIso8601String(),
      type: type,
    ));

    await _localNotifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  /// Called on each refresh: detect new official predictions and notify.
  Future<void> notifyNewPredictions(List<dynamic> predictions) async {
    if (!await _isEnabled(_kPredictions)) return;

    final newPreds = <dynamic>[];
    for (final p in predictions) {
      final id = _extractId(p);
      if (id != null && _knownPredictionIds.add(id)) {
        newPreds.add(p);
      }
    }

    if (_knownPredictionIds.length == predictions.length && newPreds.length == predictions.length) {
      // First load — seed the set without notifying
      return;
    }

    if (newPreds.isEmpty) return;

    final count = newPreds.length;
    final matchName = _extractMatchName(newPreds.first);
    final title = count == 1
        ? '🎯 Nouveau prono disponible'
        : '🎯 $count nouveaux pronos disponibles';
    final body = count == 1 && matchName != null
        ? matchName
        : '$count pronostics officiels viennent d\'être publiés';

    debugPrint('[Quantara] Notifying $count new predictions');
    await _showLocal(id: 1001, title: title, body: body, type: 'prediction');
  }

  /// Called when live predictions arrive.
  Future<void> notifyLivePrediction(dynamic prediction) async {
    if (!await _isEnabled(_kLive)) return;

    final id = _extractId(prediction);
    if (id == null || !_knownLiveIds.add(id)) return;

    // Skip first load notification
    if (_knownLiveIds.length <= 1 && _knownPredictionIds.isEmpty) return;

    final matchName = _extractMatchName(prediction) ?? 'Match en cours';
    debugPrint('[Quantara] Notifying live prediction: $matchName');
    await _showLocal(
      id: 2001,
      title: '⚡ Prono LIVE disponible',
      body: matchName,
      payload: id,
      type: 'live',
    );
  }

  /// Called when combos are detected.
  Future<void> notifyCombosAvailable(List<dynamic> combos) async {
    if (!await _isEnabled(_kCombos)) return;

    final newCombos = <dynamic>[];
    for (final c in combos) {
      final id = _extractId(c);
      if (id != null && _knownComboIds.add(id)) {
        newCombos.add(c);
      }
    }

    if (_knownComboIds.length == combos.length && newCombos.length == combos.length) {
      return; // First load
    }

    if (newCombos.isEmpty) return;

    final count = newCombos.length;
    debugPrint('[Quantara] Notifying $count new combos');
    await _showLocal(
      id: 3001,
      title: '🔥 ${count == 1 ? "Combinaison" : "$count Combinaisons"} disponible${count > 1 ? "s" : ""}',
      body: 'Une nouvelle combinaison a été générée par notre IA',
      type: 'combo',
    );
  }

  /// Called when a prediction result arrives (won/lost).
  Future<void> notifyResult({
    required String matchName,
    required bool won,
  }) async {
    if (!await _isEnabled(_kResults)) return;

    debugPrint('[Quantara] Notifying result: $matchName ${won ? "WON" : "LOST"}');
    await _showLocal(
      id: 4000 + matchName.hashCode.abs() % 1000,
      title: won ? '✅ Prono gagné !' : '❌ Prono perdu',
      body: matchName,
      type: 'result',
    );
  }

  // ── Helpers ──

  String? _extractId(dynamic item) {
    if (item is Map) return item['id']?.toString();
    try {
      return (item as dynamic).id?.toString();
    } catch (_) {
      return null;
    }
  }

  String? _extractMatchName(dynamic item) {
    try {
      if (item is Map) {
        final match = item['match'] ?? item['matches'];
        if (match is Map) {
          final home = match['home_team'] ?? '';
          final away = match['away_team'] ?? '';
          if (home.toString().isNotEmpty && away.toString().isNotEmpty) {
            return '$home vs $away';
          }
        }
        return null;
      }
      final match = (item as dynamic).match;
      if (match != null) {
        return '${match.homeTeam} vs ${match.awayTeam}';
      }
    } catch (_) {}
    return null;
  }

  // ── Firebase push handling ──

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[Quantara] Foreground message: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    // Store in notification center
    NotificationStore.add(NotificationItem(
      title: notification.title ?? '',
      body: notification.body ?? '',
      timestamp: DateTime.now().toIso8601String(),
      type: message.data['type'],
    ));

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['match_id']?.toString(),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[Quantara] Notification tapped: ${message.data}');
  }

  /// Register FCM token with Supabase backend.
  Future<void> registerToken() async {
    try {
      final token = await _messaging.getToken().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
      if (token == null) {
        debugPrint('[Quantara] No FCM token available (simulator?)');
        return;
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        debugPrint('[Quantara] No authenticated user, skipping token registration');
        return;
      }

      final platform = Platform.isIOS ? 'ios' : 'android';

      debugPrint('[Quantara] Registering push token ($platform): ${token.substring(0, 20)}...');

      await Supabase.instance.client.functions.invoke(
        'register-push-token',
        body: {'token': token, 'platform': platform},
      );

      debugPrint('[Quantara] Push token registered successfully');
    } catch (e) {
      debugPrint('[Quantara] Failed to register push token: $e');
    }
  }
}
