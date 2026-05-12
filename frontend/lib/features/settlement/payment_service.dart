import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
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
    required String fromUserId,
    required String toUserId,
    required double amount,
  }) async {
    final response = await _dio.post('/payments', data: {
      'bill_id': billId,
      'from_user_id': fromUserId,
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

// Cloudinary upload helper (Signed)
Future<String> uploadSlipToCloudinary(Uint8List imageBytes) async {
  final apiKey = cloudinaryApiKey;
  final apiSecret = cloudinaryApiSecret;
  final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  // Generate SHA1 signature: apiSecret + timestamp + "image/upload" + preset name
  final params = 'timestamp=$timestamp&upload_preset=billgang_slips';
  final toSign = '$apiSecret$params';
  final signature = sha1.convert(utf8.encode(toSign)).toString();

  final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 30)));
  final formData = FormData.fromMap({
    'file': MultipartFile.fromBytes(
      imageBytes,
      filename: 'slip_${DateTime.now().millisecondsSinceEpoch}.jpg',
    ),
    'api_key': apiKey,
    'timestamp': timestamp,
    'upload_preset': 'billgang_slips',
    'signature': signature,
  });

  try {
    final response = await dio.post(
      cloudinaryUploadUrl,
      data: formData,
    );

    final data = response.data as Map<String, dynamic>;
    return data['secure_url'] as String;
  } on DioException catch (e) {
    final status = e.response?.statusCode;
    final body = e.response?.data;
    throw Exception('Cloudinary $status → $body');
  }
}
