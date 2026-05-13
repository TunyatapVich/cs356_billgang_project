import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

class PaymentService {
  final Dio _dio;
  const PaymentService(this._dio);

  Future<Map<String, dynamic>> listByBill(String billId) async {
    final response = await _dio.get('/payments', queryParameters: {'bill_id': billId});
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> create({
    required String billId,
    required String fromUserId,
    required String toUserId,
    required double amount,
  }) async {
    final response = await _dio.post(
      '/payments',
      data: {
        'bill_id': billId,
        'from_user_id': fromUserId,
        'to_user_id': toUserId,
        'amount': amount,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Confirms a payment, optionally uploading a slip image to the backend.
  /// The backend handles R2 storage — the frontend just sends raw bytes.
  Future<Map<String, dynamic>> confirm(
    String paymentId, {
    Uint8List? slipBytes,
  }) async {
    final data = FormData.fromMap(
      slipBytes != null
          ? {
              'slip': MultipartFile.fromBytes(
                slipBytes,
                filename: 'slip_${DateTime.now().millisecondsSinceEpoch}.jpg',
                contentType: DioMediaType('image', 'jpeg'),
              ),
            }
          : {},
    );
    final response = await _dio.put('/payments/$paymentId/confirm', data: data);
    return response.data as Map<String, dynamic>;
  }
}

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService(ref.read(authDioProvider));
});
