import 'package:supabase_flutter/supabase_flutter.dart';

enum PaymentType { redirect, deeplink, ussd, otpRequired, inProgress, completed }
enum PaymentStatus { pending, submitted, completed, failed, cancelled }

class Subscription {
  final String id;
  final String plan;
  final DateTime expiresAt;
  final bool isActive;

  const Subscription({
    required this.id,
    required this.plan,
    required this.expiresAt,
    required this.isActive,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    final expiry = DateTime.parse(json['end_date'] as String? ?? json['expires_at'] as String);
    return Subscription(
      id: json['id'].toString(),
      plan: json['plan'] as String,
      expiresAt: expiry,
      isActive: expiry.isAfter(DateTime.now()),
    );
  }

  DateTime get endDate => expiresAt;

  int get remainingDays {
    final diff = expiresAt.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }
}

class PaymentResult {
  final String paymentId;
  final PaymentStatus status;
  final String? checkoutUrl;
  final PaymentType paymentType;
  final String? paymentMethodName;
  final String? ussdMessage;
  final String? otpInstructions;

  const PaymentResult({
    required this.paymentId,
    required this.status,
    this.checkoutUrl,
    this.paymentType = PaymentType.redirect,
    this.paymentMethodName,
    this.ussdMessage,
    this.otpInstructions,
  });
}

class PaymentService {
  final SupabaseClient _client;
  PaymentService(this._client);

  Future<PaymentResult> createPayment({
    required String plan,
    required String phone,
    required String paymentMethod,
    String currency = 'XOF',
    String? otp,
  }) async {
    final body = <String, dynamic>{
      'plan': plan,
      'phone': phone,
      'payment_method': paymentMethod,
      'currency': currency,
      if (otp != null) 'otp': otp,
    };

    final response = await _client.functions.invoke(
      'create-payment',
      body: body,
    );

    final data = response.data as Map<String, dynamic>?;
    if (data == null) throw Exception('Réponse invalide du serveur');

    // Check for error in response data (FunctionsException may not always throw for 4xx)
    if (data.containsKey('error')) {
      throw Exception(data['error'] as String);
    }

    final type = data['payment_type'] as String? ?? 'redirect';
    return PaymentResult(
      paymentId: data['payment_id'] as String? ?? '',
      status: PaymentStatus.pending,
      checkoutUrl: data['checkout_url'] as String?,
      paymentType: _parseType(type),
      paymentMethodName: data['payment_method_name'] as String?,
      ussdMessage: data['ussd_message'] as String?,
      otpInstructions: data['otp_instructions'] as String?,
    );
  }

  PaymentType _parseType(String type) => switch (type) {
    'deeplink'     => PaymentType.deeplink,
    'ussd'         => PaymentType.ussd,
    'otp_required' => PaymentType.otpRequired,
    'in_progress'  => PaymentType.inProgress,
    'completed'    => PaymentType.completed,
    _              => PaymentType.redirect,
  };

  Future<PaymentStatus> checkPaymentStatus(String paymentId) async {
    final data = await _client
        .from('payments')
        .select('status')
        .eq('id', paymentId)
        .maybeSingle();
    if (data == null) return PaymentStatus.pending;
    return _parseStatus(data['status'] as String? ?? 'pending');
  }

  PaymentStatus _parseStatus(String s) => switch (s) {
    'completed' => PaymentStatus.completed,
    'failed'    => PaymentStatus.failed,
    'cancelled' => PaymentStatus.cancelled,
    'submitted' => PaymentStatus.submitted,
    _           => PaymentStatus.pending,
  };

  Future<Subscription?> getActiveSubscription() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;
      final data = await _client
          .from('subscriptions')
          .select('id, plan, end_date')
          .eq('user_id', userId)
          .eq('status', 'active')
          .order('end_date', ascending: false)
          .limit(1)
          .maybeSingle();
      if (data == null) return null;
      return Subscription.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}
