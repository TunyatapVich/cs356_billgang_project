import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

// AuthService only knows about HTTP calls — no Dio.create(), no token logic here
// Same as: lib/api/auth.ts in Next.js that just calls axios.post(...)
class AuthService {
  final Dio _dio;
  const AuthService(this._dio);

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> register(
    String email,
    String phone,
    String password,
    String passwordConfirm,
  ) async {
    final response = await _dio.post(
      '/auth/register',
      data: {
        'email': email,
        'promptpay_number': phone,
        'password': password,
        'password_confirm': passwordConfirm,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile({
    String? displayName,
    String? avatarUrl,
    String? promptpayNumber,
  }) async {
    final response = await _dio.put(
      '/auth/profile',
      data: {
        if (displayName != null) 'display_name': displayName,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (promptpayNumber != null) 'promptpay_number': promptpayNumber,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(dioProvider));
});
