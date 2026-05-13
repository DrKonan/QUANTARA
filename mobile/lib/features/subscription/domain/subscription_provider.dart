import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/domain/auth_provider.dart';
import '../data/payment_service.dart';

final paymentServiceProvider = Provider<PaymentService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return PaymentService(client);
});

final activeSubscriptionProvider = FutureProvider<Subscription?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.read(paymentServiceProvider).getActiveSubscription();
});

final isPremiumProvider = Provider<bool>((ref) {
  final sub = ref.watch(activeSubscriptionProvider).valueOrNull;
  if (sub?.isActive ?? false) return true;
  final profile = ref.watch(userProfileProvider).valueOrNull;
  return profile?.isPremium ?? false;
});

final currentPlanProvider = Provider<String>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  return profile?.effectivePlan ?? 'free';
});

final hasComboAccessProvider = Provider<bool>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  return profile?.hasComboAccess ?? false;
});

final hasLiveAccessProvider = Provider<bool>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  return profile?.hasLiveAccess ?? false;
});

final userCurrencyProvider = Provider<String>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  return AppConstants.currencyFromPhone(profile?.phone);
});

enum PaymentPhase { idle, creating, waitingConfirmation, otpRequired, success, error }

class PaymentState {
  final PaymentPhase phase;
  final PaymentResult? result;
  final String? errorMessage;
  final PaymentStatus? lastStatus;
  final String? pendingPlan;
  final String? pendingPhone;
  final String? pendingMethod;
  final String? pendingCurrency;

  const PaymentState({
    this.phase = PaymentPhase.idle,
    this.result,
    this.errorMessage,
    this.lastStatus,
    this.pendingPlan,
    this.pendingPhone,
    this.pendingMethod,
    this.pendingCurrency,
  });

  PaymentState copyWith({
    PaymentPhase? phase,
    PaymentResult? result,
    String? errorMessage,
    PaymentStatus? lastStatus,
    String? pendingPlan,
    String? pendingPhone,
    String? pendingMethod,
    String? pendingCurrency,
  }) =>
      PaymentState(
        phase: phase ?? this.phase,
        result: result ?? this.result,
        errorMessage: errorMessage ?? this.errorMessage,
        lastStatus: lastStatus ?? this.lastStatus,
        pendingPlan: pendingPlan ?? this.pendingPlan,
        pendingPhone: pendingPhone ?? this.pendingPhone,
        pendingMethod: pendingMethod ?? this.pendingMethod,
        pendingCurrency: pendingCurrency ?? this.pendingCurrency,
      );
}

class PaymentNotifier extends StateNotifier<PaymentState> {
  final PaymentService _service;
  final Ref _ref;
  Timer? _pollTimer;

  PaymentNotifier(this._service, this._ref) : super(const PaymentState());

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> initiatePayment({
    required String plan,
    String? phone,
    String? paymentMethod,
    String currency = 'XOF',
    String? otp,
  }) async {
    state = PaymentState(
      phase: PaymentPhase.creating,
      pendingPlan: plan,
      pendingPhone: phone,
      pendingMethod: paymentMethod,
      pendingCurrency: currency,
    );
    try {
      final result = await _service.createPayment(
        plan: plan,
        phone: phone ?? '',
        paymentMethod: paymentMethod ?? 'unknown',
        currency: currency,
        otp: otp,
      );

      if (result.paymentType == PaymentType.otpRequired) {
        state = state.copyWith(
          phase: PaymentPhase.otpRequired,
          result: result,
        );
        return;
      }

      // USSD/OTP payment confirmed immediately by the server
      if (result.paymentType == PaymentType.completed) {
        state = state.copyWith(phase: PaymentPhase.success, result: result, lastStatus: PaymentStatus.completed);
        _ref.invalidate(activeSubscriptionProvider);
        _ref.invalidate(userProfileProvider);
        return;
      }

      state = state.copyWith(
        phase: PaymentPhase.waitingConfirmation,
        result: result,
        lastStatus: result.status,
      );
      _startPolling(result.paymentId);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(
        phase: PaymentPhase.error,
        errorMessage: msg.isNotEmpty ? msg : 'Erreur de paiement.',
      );
    }
  }

  Future<void> submitOtp(String otp) async {
    final plan     = state.pendingPlan;
    final phone    = state.pendingPhone;
    final method   = state.pendingMethod;
    final currency = state.pendingCurrency ?? 'XOF';
    if (plan == null || phone == null || method == null) {
      state = state.copyWith(phase: PaymentPhase.error, errorMessage: 'Données de paiement manquantes.');
      return;
    }
    await initiatePayment(plan: plan, phone: phone, paymentMethod: method, currency: currency, otp: otp);
  }

  void _startPolling(String paymentId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await forceCheckNow();
    });
  }

  Future<void> forceCheckNow() async {
    final paymentId = state.result?.paymentId;
    if (paymentId == null || paymentId.isEmpty) return;
    if (state.phase != PaymentPhase.waitingConfirmation) {
      _pollTimer?.cancel();
      return;
    }
    try {
      final status = await _service.checkPaymentStatus(paymentId);
      _handleStatus(status);
    } catch (_) {}
  }

  void _handleStatus(PaymentStatus status) {
    if (state.phase != PaymentPhase.waitingConfirmation) return;
    state = state.copyWith(lastStatus: status);
    if (status == PaymentStatus.completed) {
      _pollTimer?.cancel();
      state = state.copyWith(phase: PaymentPhase.success);
      _ref.invalidate(activeSubscriptionProvider);
      _ref.invalidate(userProfileProvider);
    } else if (status == PaymentStatus.failed || status == PaymentStatus.cancelled) {
      _pollTimer?.cancel();
      state = state.copyWith(
        phase: PaymentPhase.error,
        errorMessage: 'Le paiement a échoué. Veuillez réessayer.',
      );
    }
  }

  void handleDeepLinkReturn(String status, String paymentId) {
    if (status == 'completed') {
      _pollTimer?.cancel();
      state = state.copyWith(phase: PaymentPhase.success, lastStatus: PaymentStatus.completed);
      _ref.invalidate(activeSubscriptionProvider);
      _ref.invalidate(userProfileProvider);
    } else if (status == 'cancelled' || status == 'failed') {
      _pollTimer?.cancel();
      state = state.copyWith(
        phase: PaymentPhase.error,
        errorMessage: 'Le paiement a été annulé.',
        lastStatus: PaymentStatus.cancelled,
      );
    } else {
      // Unknown / pending status → trigger an immediate check
      if (paymentId.isNotEmpty && state.phase == PaymentPhase.waitingConfirmation) {
        forceCheckNow();
      }
    }
  }

  void handleCancel() {
    _pollTimer?.cancel();
    if (state.phase == PaymentPhase.waitingConfirmation) {
      state = state.copyWith(phase: PaymentPhase.error, errorMessage: 'Paiement annulé.');
    }
  }

  void reset() {
    _pollTimer?.cancel();
    state = const PaymentState();
  }
}

final paymentNotifierProvider =
    StateNotifierProvider.autoDispose<PaymentNotifier, PaymentState>((ref) {
  final service = ref.watch(paymentServiceProvider);
  return PaymentNotifier(service, ref);
});

// Daily match view tracking
 
class DailyViewState {
  final Set<String> viewedMatchIds;
  final String date;

  const DailyViewState({this.viewedMatchIds = const {}, this.date = ''});

  int get viewedCount => viewedMatchIds.length;

  DailyViewState copyWith({Set<String>? viewedMatchIds, String? date}) =>
      DailyViewState(
        viewedMatchIds: viewedMatchIds ?? this.viewedMatchIds,
        date: date ?? this.date,
      );
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
    }
  }

  bool recordView(String matchId) {
    _ensureToday();
    if (state.viewedMatchIds.contains(matchId)) return false;
    state = state.copyWith(viewedMatchIds: {...state.viewedMatchIds, matchId});
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
  final s = ref.watch(dailyViewProvider);
  final now = DateTime.now();
  final today =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  if (s.date != today) return true;
  if (s.viewedMatchIds.contains(matchId)) return true;
  return s.viewedMatchIds.length < limit;
});

final comboLimitProvider = Provider<int>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  return profile?.comboLimit ?? 0;
});
