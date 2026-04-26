import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/domain/auth_provider.dart';
import '../data/payment_service.dart';

// ── Service Provider ──
final paymentServiceProvider = Provider<PaymentService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return PaymentService(client);
});

// ── Active Subscription ──
final activeSubscriptionProvider = FutureProvider<Subscription?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final service = ref.read(paymentServiceProvider);
  return service.getActiveSubscription();
});

// ── Is Premium (any paid plan: starter, pro, vip) ──
final isPremiumProvider = Provider<bool>((ref) {
  final sub = ref.watch(activeSubscriptionProvider).valueOrNull;
  if (sub?.isActive ?? false) return true;
  final profile = ref.watch(userProfileProvider).valueOrNull;
  return profile?.isPremium ?? false;
});

// ── Current plan tier ──
final currentPlanProvider = Provider<String>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  return profile?.effectivePlan ?? 'free';
});

// ── Has combo access (pro or vip) ──
final hasComboAccessProvider = Provider<bool>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  return profile?.hasComboAccess ?? false;
});

// ── Has LIVE access (pro or vip) ──
final hasLiveAccessProvider = Provider<bool>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  return profile?.hasLiveAccess ?? false;
});

// ── User currency (derived from phone country) ──
final userCurrencyProvider = Provider<String>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  return AppConstants.currencyFromPhone(profile?.phone);
});

// ── Payment State ──
enum PaymentPhase { idle, creating, waitingConfirmation, success, error }

class PaymentState {
  final PaymentPhase phase;
  final PaymentResult? result;
  final String? errorMessage;
  final PaymentStatus? lastStatus;

  const PaymentState({
    this.phase = PaymentPhase.idle,
    this.result,
    this.errorMessage,
    this.lastStatus,
  });

  PaymentState copyWith({
    PaymentPhase? phase,
    PaymentResult? result,
    String? errorMessage,
    PaymentStatus? lastStatus,
  }) {
    return PaymentState(
      phase: phase ?? this.phase,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      lastStatus: lastStatus ?? this.lastStatus,
    );
  }
}

class PaymentNotifier extends StateNotifier<PaymentState> {
  final PaymentService _service;
  final Ref _ref;
  Timer? _fallbackTimer;
  RealtimeChannel? _realtimeChannel;

  PaymentNotifier(this._service, this._ref) : super(const PaymentState());

  Future<void> initiatePayment({
    required String plan,
    String currency = 'XOF',
    String? phone,
    String? paymentMethod,
  }) async {
    state = const PaymentState(phase: PaymentPhase.creating);

    try {
      final result = await _service.createPayment(
        plan: plan,
        currency: currency,
        phone: phone,
        paymentMethod: paymentMethod,
      );

      state = PaymentState(
        phase: PaymentPhase.waitingConfirmation,
        result: result,
        lastStatus: result.status,
      );

      _startListening(result.paymentId);
    } catch (e) {
      state = PaymentState(
        phase: PaymentPhase.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void _startListening(String paymentId) {
    _cleanup();

    // Primary: Supabase Realtime — fires instantly when the webhook updates the DB
    final client = _ref.read(supabaseClientProvider);
    _realtimeChannel = client
        .channel('payment-$paymentId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'payments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: paymentId,
          ),
          callback: (payload) {
            final statusStr = payload.newRecord['status'] as String?;
            final status = parsePaymentStatus(statusStr);
            debugPrint('[PaymentNotifier] Realtime update: status=$statusStr');
            if (status != null) _handleStatus(status);
          },
        )
        .subscribe((status, [error]) {
          debugPrint('[PaymentNotifier] Realtime channel status: $status error=$error');
        });

    // Fallback: poll every 15s for 5 minutes in case Realtime misses an event
    int attempts = 0;
    _fallbackTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (state.phase != PaymentPhase.waitingConfirmation) {
        timer.cancel();
        return;
      }
      attempts++;
      if (attempts > 20) {
        timer.cancel();
        if (state.phase == PaymentPhase.waitingConfirmation) {
          _cleanup();
          state = state.copyWith(
            phase: PaymentPhase.error,
            errorMessage: 'Le paiement a expiré. Vérifiez votre compte et réessayez.',
          );
        }
        return;
      }
      try {
        final status = await _service.checkPaymentStatus(paymentId);
        debugPrint('[PaymentNotifier] Fallback poll: $status');
        _handleStatus(status);
      } catch (_) {}
    });
  }

  // Single entry point for all status updates (Realtime, poll, deep link, app resume)
  void _handleStatus(PaymentStatus status) {
    if (state.phase != PaymentPhase.waitingConfirmation) return;
    state = state.copyWith(lastStatus: status);

    if (status == PaymentStatus.completed) {
      _cleanup();
      state = state.copyWith(phase: PaymentPhase.success);
      _ref.invalidate(activeSubscriptionProvider);
      _ref.invalidate(userProfileProvider);
    } else if (status == PaymentStatus.failed) {
      _cleanup();
      state = state.copyWith(
        phase: PaymentPhase.error,
        errorMessage: 'Le paiement a échoué. Veuillez réessayer.',
      );
    }
  }

  void _cleanup() {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
  }

  /// Immediate DB check — called on deep link arrival, app resume, or user tap.
  /// Safe to call multiple times; guards against non-waiting state.
  Future<void> forceCheckNow() async {
    final paymentId = state.result?.paymentId;
    if (paymentId == null || state.phase != PaymentPhase.waitingConfirmation) return;
    try {
      final status = await _service.checkPaymentStatus(paymentId);
      debugPrint('[PaymentNotifier] forceCheckNow: $status');
      _handleStatus(status);
    } catch (_) {}
  }

  void handleCancelFromDeepLink() {
    if (state.phase != PaymentPhase.waitingConfirmation) return;
    _cleanup();
    state = state.copyWith(
      phase: PaymentPhase.error,
      errorMessage: 'Paiement annulé.',
    );
  }

  void reset() {
    _cleanup();
    state = const PaymentState();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}

final paymentNotifierProvider =
    StateNotifierProvider<PaymentNotifier, PaymentState>((ref) {
  final service = ref.watch(paymentServiceProvider);
  return PaymentNotifier(service, ref);
});

// ══════════════════════════════════════════════════════════════
// Daily match view tracking (client-side, resets each day)
// ══════════════════════════════════════════════════════════════

class DailyViewState {
  final Set<String> viewedMatchIds;
  final String date; // YYYY-MM-DD to detect day rollover

  const DailyViewState({this.viewedMatchIds = const {}, this.date = ''});

  int get viewedCount => viewedMatchIds.length;

  DailyViewState copyWith({Set<String>? viewedMatchIds, String? date}) {
    return DailyViewState(
      viewedMatchIds: viewedMatchIds ?? this.viewedMatchIds,
      date: date ?? this.date,
    );
  }
}

class DailyViewNotifier extends StateNotifier<DailyViewState> {
  DailyViewNotifier() : super(const DailyViewState());

  String get _today {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void _ensureToday() {
    if (state.date != _today) {
      state = DailyViewState(viewedMatchIds: {}, date: _today);
      debugPrint('[Nakora] Daily views reset for $_today');
    }
  }

  bool recordView(String matchId) {
    _ensureToday();
    if (state.viewedMatchIds.contains(matchId)) return false;
    state = state.copyWith(
      viewedMatchIds: {...state.viewedMatchIds, matchId},
    );
    return true;
  }

  bool canView(String matchId, int limit) {
    _ensureToday();
    if (limit < 0) return true;
    if (state.viewedMatchIds.contains(matchId)) return true;
    return state.viewedMatchIds.length < limit;
  }

  int get viewedCount {
    _ensureToday();
    return state.viewedMatchIds.length;
  }
}

final dailyViewProvider =
    StateNotifierProvider<DailyViewNotifier, DailyViewState>((ref) {
  return DailyViewNotifier();
});

final canViewMatchProvider = Provider.family<bool, String>((ref, matchId) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  final limit = profile?.dailyMatchLimit ?? 1;
  if (limit < 0) return true;

  final state = ref.watch(dailyViewProvider);

  final now = DateTime.now();
  final today =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  if (state.date != today) return true;

  if (state.viewedMatchIds.contains(matchId)) return true;
  return state.viewedMatchIds.length < limit;
});

final comboLimitProvider = Provider<int>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  return profile?.comboLimit ?? 0;
});
