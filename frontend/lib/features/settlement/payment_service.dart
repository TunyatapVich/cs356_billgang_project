import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

class PaymentService {
  final Dio _dio;
  const PaymentService(this._dio);

  Future<Map<String, dynamic>> listByBill(String billId) async {
    final response = await _dio.get('/bills/$billId/payments');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> create({
    required String billId,
    required String toUserId,
    required double amount,
  }) async {
    final response = await _dio.post('/payments', data: {
      'bill_id': billId,
      'to_user_id': toUserId,
      'amount': amount,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<void> confirm(String paymentId, {String? slipUrl}) async {
    await _dio.put('/payments/$paymentId/confirm', data: {
      if (slipUrl != null) 'slip_url': slipUrl,
    });
  }

  Future<List<Map<String, dynamic>>> getDebts(String billId) async {
    final response = await _dio.get('/bills/$billId/debts');
    final data = response.data as Map<String, dynamic>;
    return (data['debts'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
  }
}

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService(ref.read(authDioProvider));
});
