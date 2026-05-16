import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

class ProfileService {
  ProfileService(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> updateProfile({
    String? displayName,
    String? promptpayNumber,
  }) async {
    final response = await _dio.put('/profile', data: {
      'display_name': displayName,
      'promptpay_number': promptpayNumber,
    });
    return response.data as Map<String, dynamic>;
  }
}

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService(ref.read(dioProvider));
});
