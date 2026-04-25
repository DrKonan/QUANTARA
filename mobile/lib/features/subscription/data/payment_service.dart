import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';

enum PaymentStatus { pending, submitted, completed, failed }

class PaymentResult {
  final String paymentId;
  final PaymentStatus status;
  final String? checkoutUrl; // PayDunya hosted checkout URL

  const PaymentResult({
    required this.paymentId,
    required this.status,
    this.checkoutUrl,
  });
}

class Subscription {
  final String id;
  final String plan;
  final String status;
  final DateTime startDate;
  final DateTime endDate;
  final String? provider;
  final int? amount;

  const Subscription({
    required this.id,
    required this.plan,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.provider,
    this.amount,
  });

  bool get isActive => status == 'active' && endDate.isAfter(DateTime.now());

  int get remainingDays => endDate.difference(DateTime.now()).inDays;

  String get planLabel => AppConstants.planLabels[plan] ?? plan;

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'].toString(),
      plan: json['plan'] as String,
      status: json['status'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      provider: json['provider'] as String?,
      amount: json['amount'] as int?,
    );
  }
}

class PaymentService {
  final SupabaseClient _client;

  PaymentService(this._client);

  /// Initiate a PayDunya hosted checkout payment
  Future<PaymentResult> createPayment({
    required String plan,
    String currency = 'XOF',
  }) async {
    if (!AppConstants.planPrices.containsKey(plan)) {
      throw Exception('Plan invalide: $plan');
    }

    final body = <String, dynamic>{
      'plan': plan,
      'provider': 'paydunya',
      'currency': currency,
    };

    debugPrint('[PaymentService] Creating PayDunya payment: plan=$plan, currency=$currency');

    late Map<String, dynamic> data;
    try {
      final response = await _client.functions.invoke(
        'create-payment',
        body: body,
      );
      data = response.data is String
          ? jsonDecode(response.data as String) as Map<String, dynamic>
          : response.data as Map<String, dynamic>;
    } on FunctionException catch (e) {
      debugPrint('[PaymentService] FunctionException status=${e.status} details=${e.details}');
      String errorMsg = 'Erreur lors du paiement (${e.status})';
      final details = e.details;
      if (details is Map<String, dynamic>) {
        errorMsg = (details['error'] as String?) ?? errorMsg;
      } else if (details is String && details.isNotEmpty) {
        try {
          final decoded = jsonDecode(details) as Map<String, dynamic>;
          errorMsg = (decoded['error'] as String?) ?? errorMsg;
        } catch (_) {
          errorMsg = details;
        }
      }
      throw Exception(errorMsg);
    }

    debugPrint('[PaymentService] PayDunya checkout created: ${data['payment_id']}');

    return PaymentResult(
      paymentId: data['payment_id'] as String,
      status: PaymentStatus.pending,
      checkoutUrl: data['checkout_url'] as String?,
    );
  }

  /// Check payment status by polling the payments table
  Future<PaymentStatus> checkPaymentStatus(String paymentId) async {
    final data = await _client
        .from('payments')
        .select('status')
        .eq('id', paymentId)
        .maybeSingle();

    if (data == null) return PaymentStatus.pending;

    final status = data['status'] as String;
    debugPrint('[PaymentService] Poll status for $paymentId: $status');

    switch (status) {
      case 'completed':
        return PaymentStatus.completed;
      case 'failed':
        return PaymentStatus.failed;
      case 'submitted':
        return PaymentStatus.submitted;
      default:
        return PaymentStatus.pending;
    }
  }

  /// Get user's active subscription
  Future<Subscription?> getActiveSubscription() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await _client
        .from('subscriptions')
        .select()
        .eq('user_id', userId)
        .eq('status', 'active')
        .gte('end_date', DateTime.now().toUtc().toIso8601String())
        .order('end_date', ascending: false)
        .limit(1)
        .maybeSingle();

    if (data == null) return null;
    return Subscription.fromJson(data);
  }

  /// Get payment history for the current user
  Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await _client
        .from('payments')
        .select('id, plan, amount, provider, status, created_at, completed_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(20);

    return List<Map<String, dynamic>>.from(data);
  }

  /// Check if user has premium access
  Future<bool> isPremium() async {
    final sub = await getActiveSubscription();
    return sub?.isActive ?? false;
  }
}
