import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._();
  factory AnalyticsService() => _instance;
  AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  Future<void> initialize() async {
    await _crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
    FlutterError.onError = _crashlytics.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      _crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
  }

  void setUserId(String? userId) {
    _analytics.setUserId(id: userId);
    if (userId != null) {
      _crashlytics.setUserIdentifier(userId);
    }
  }

  void setUserPlan(String plan) {
    _analytics.setUserProperty(name: 'plan', value: plan);
  }

  void setUserCountry(String countryCode) {
    _analytics.setUserProperty(name: 'country', value: countryCode);
  }

  // ── Screen views ──
  void logScreenView(String screenName) {
    _analytics.logScreenView(screenName: screenName);
  }

  // ── Auth events ──
  void logSignUp(String method) {
    _analytics.logSignUp(signUpMethod: method);
  }

  void logLogin(String method) {
    _analytics.logLogin(loginMethod: method);
  }

  void logDeleteAccount() {
    _analytics.logEvent(name: 'delete_account');
  }

  // ── Subscription events ──
  void logViewSubscription() {
    _analytics.logEvent(name: 'view_subscription');
  }

  void logStartPayment(String plan, String provider) {
    _analytics.logEvent(name: 'start_payment', parameters: {
      'plan': plan,
      'provider': provider,
    });
  }

  void logPaymentSuccess(String plan, String provider) {
    _analytics.logEvent(name: 'payment_success', parameters: {
      'plan': plan,
      'provider': provider,
    });
  }

  void logPaymentFailure(String plan, String reason) {
    _analytics.logEvent(name: 'payment_failure', parameters: {
      'plan': plan,
      'reason': reason,
    });
  }

  // ── Prediction events ──
  void logViewPrediction(String matchId) {
    _analytics.logEvent(name: 'view_prediction', parameters: {
      'match_id': matchId,
    });
  }

  void logViewCombo(String comboId) {
    _analytics.logEvent(name: 'view_combo', parameters: {
      'combo_id': comboId,
    });
  }

  // ── Engagement ──
  void logTrialStart() {
    _analytics.logEvent(name: 'trial_start');
  }

  void logAccessGateHit(String requiredPlan) {
    _analytics.logEvent(name: 'access_gate_hit', parameters: {
      'required_plan': requiredPlan,
    });
  }
}
