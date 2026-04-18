import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

enum PaymentProvider { wave, pawapay }

enum PaymentStatus { pending, submitted, completed, failed }

class PaymentResult {
  final String paymentId;
  final PaymentProvider provider;
  final PaymentStatus status;
  final String? checkoutUrl; // Wave only
  final String? message;     // PawaPay confirmation message

  const PaymentResult({
    required this.paymentId,
    required this.provider,
    required this.status,
    this.checkoutUrl,
    this.message,
  });
}

class Subscription {
  final String id;
  final String plan;
  final String status;
  final DateTime startDate;
  final DateTime endDate;
  final String? provider;

  const Subscription({
    required this.id,
    required this.plan,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.provider,
  });

  bool get isActive => status == 'active' && endDate.isAfter(DateTime.now());

  int get remainingDays => endDate.difference(DateTime.now()).inDays;

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'].toString(),
      plan: json['plan'] as String,
      status: json['status'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      provider: json['provider'] as String?,
    );
  }
}

class PaymentService {
  final SupabaseClient _client;

  PaymentService(this._client);

  /// Initiate a payment via Wave or PawaPay
  Future<PaymentResult> createPayment({
    required String plan,
    required PaymentProvider provider,
    String? phone,
    String? correspondent, // 'orange_ci' | 'mtn_ci'
  }) async {
    final body = <String, dynamic>{
      'plan': plan,
      'provider': provider == PaymentProvider.wave ? 'wave' : 'pawapay',
    };
    if (phone != null) body['phone'] = phone;
    if (correspondent != null) body['correspondent'] = correspondent;

    final response = await _client.functions.invoke(
      'create-payment',
      body: body,
    );

    if (response.status != 200) {
      final data = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;
      throw Exception(data?['error'] ?? 'Erreur lors de la création du paiement');
    }

    final data = response.data is String
        ? jsonDecode(response.data as String) as Map<String, dynamic>
        : response.data as Map<String, dynamic>;

    return PaymentResult(
      paymentId: data['payment_id'] as String,
      provider: provider,
      status: provider == PaymentProvider.wave
          ? PaymentStatus.pending
          : _parseStatus(data['status'] as String?),
      checkoutUrl: data['checkout_url'] as String?,
      message: data['message'] as String?,
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

    switch (data['status'] as String) {
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

  /// Check if user has premium access
  Future<bool> isPremium() async {
    final sub = await getActiveSubscription();
    return sub?.isActive ?? false;
  }

  PaymentStatus _parseStatus(String? status) {
    switch (status) {
      case 'ACCEPTED':
      case 'SUBMITTED':
        return PaymentStatus.submitted;
      case 'COMPLETED':
        return PaymentStatus.completed;
      case 'FAILED':
        return PaymentStatus.failed;
      default:
        return PaymentStatus.pending;
    }
  }
}
