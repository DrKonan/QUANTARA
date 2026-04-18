import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  // Check active subscription first
  final sub = ref.watch(activeSubscriptionProvider).valueOrNull;
  if (sub?.isActive ?? false) return true;
  // Fallback to user profile plan
  final profile = ref.watch(userProfileProvider).valueOrNull;
  return profile?.isPremium ?? false;
});

// ── Current plan tier ──
final currentPlanProvider = Provider<String>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  return profile?.plan ?? 'free';
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
  Timer? _pollTimer;

  PaymentNotifier(this._service, this._ref) : super(const PaymentState());

  Future<void> initiatePayment({
    required String plan,
    required PaymentProvider provider,
    String? phone,
    String? correspondent,
  }) async {
    state = const PaymentState(phase: PaymentPhase.creating);

    try {
      final result = await _service.createPayment(
        plan: plan,
        provider: provider,
        phone: phone,
        correspondent: correspondent,
      );

      state = PaymentState(
        phase: PaymentPhase.waitingConfirmation,
        result: result,
        lastStatus: result.status,
      );

      // Start polling for payment status
      _startPolling(result.paymentId);
    } catch (e) {
      state = PaymentState(
        phase: PaymentPhase.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void _startPolling(String paymentId) {
    _pollTimer?.cancel();
    int attempts = 0;
    const maxAttempts = 60; // 5 minutes at 5s interval

    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      attempts++;
      if (attempts > maxAttempts) {
        timer.cancel();
        state = state.copyWith(
          phase: PaymentPhase.error,
          errorMessage: 'Le paiement a expiré. Vérifiez votre compte et réessayez.',
        );
        return;
      }

      try {
        final status = await _service.checkPaymentStatus(paymentId);
        state = state.copyWith(lastStatus: status);

        if (status == PaymentStatus.completed) {
          timer.cancel();
          state = state.copyWith(phase: PaymentPhase.success);
          // Refresh subscription state
          _ref.invalidate(activeSubscriptionProvider);
          _ref.invalidate(userProfileProvider);
        } else if (status == PaymentStatus.failed) {
          timer.cancel();
          state = state.copyWith(
            phase: PaymentPhase.error,
            errorMessage: 'Le paiement a échoué. Veuillez réessayer.',
          );
        }
      } catch (_) {
        // Ignore polling errors, will retry
      }
    });
  }

  void reset() {
    _pollTimer?.cancel();
    state = const PaymentState();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
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
      debugPrint('[Quantara] Daily views reset for $_today');
    }
  }

  /// Record that a match was viewed. Returns true if this was a new view.
  bool recordView(String matchId) {
    _ensureToday();
    if (state.viewedMatchIds.contains(matchId)) return false;
    state = state.copyWith(
      viewedMatchIds: {...state.viewedMatchIds, matchId},
    );
    return true;
  }

  /// Check if user can view more matches given their plan limit.
  /// Returns true if the match was already viewed or limit not reached.
  bool canView(String matchId, int limit) {
    _ensureToday();
    if (limit < 0) return true; // unlimited
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

/// Whether the user can view a specific match (based on daily limit)
final canViewMatchProvider = Provider.family<bool, String>((ref, matchId) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  final limit = profile?.dailyMatchLimit ?? 1;
  final notifier = ref.watch(dailyViewProvider.notifier);
  return notifier.canView(matchId, limit);
});

/// Combo limit for the user's current plan
final comboLimitProvider = Provider<int>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  return profile?.comboLimit ?? 0;
});
