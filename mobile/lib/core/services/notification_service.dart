import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Top-level handler for background messages (must be top-level function).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[Quantara] Background message: ${message.notification?.title}');
}

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
    description: 'Notifications de pronostics et r\u00e9sultats',
    importance: Importance.high,
  );

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Request permission (iOS shows system dialog, Android auto-grants)
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

    // Setup local notifications for foreground display
    await _setupLocalNotifications();

    // Listen to foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Listen to notification taps (app in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a notification (terminated state)
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Register token with backend
    await registerToken();

    // Listen for token refresh
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

    // Create Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[Quantara] Foreground message: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    // Show local notification (Firebase doesn't auto-show in foreground)
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
    // Navigation to match detail can be handled here via a global navigator key
    // For now, the auto-refresh will pick up new data
  }

  /// Register FCM token with Supabase backend.
  Future<void> registerToken() async {
    try {
      // On simulateur iOS, getToken() peut échouer (pas d'APNs)
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
