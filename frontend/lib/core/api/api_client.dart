import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/token_storage.dart';

String get _baseUrl {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:3000';
  }

  return 'http://localhost:3000';
}

String get cloudinaryCloudName {
  const cloudName = String.fromEnvironment('CLOUDINARY_CLOUD_NAME', defaultValue: '');
  if (cloudName.isEmpty) {
    return 'ce514272ec89202990dbde5ac7eedf386b';
  }
  return cloudName;
}

String get cloudinaryApiKey {
  const apiKey = String.fromEnvironment('CLOUDINARY_API_KEY', defaultValue: '');
  if (apiKey.isEmpty) {
    throw Exception('CLOUDINARY_API_KEY not configured. Run with --dart-define=CLOUDINARY_API_KEY=your_api_key');
  }
  return apiKey;
}

String get cloudinaryApiSecret {
  const apiSecret = String.fromEnvironment('CLOUDINARY_API_SECRET', defaultValue: '');
  if (apiSecret.isEmpty) {
    throw Exception('CLOUDINARY_API_SECRET not configured. Run with --dart-define=CLOUDINARY_API_SECRET=your_api_secret');
  }
  return apiSecret;
}

String get cloudinaryUploadUrl =>
    'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload';

// Unauthenticated Dio — for login / register (no token needed)
// Same idea as: export const axios = axios.create({ baseURL }) in Next.js
final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(baseUrl: _baseUrl));
});

// Authenticated Dio — for protected endpoints (attaches JWT from storage)
// Use this in bill, assign, settlement services.
final authDioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(baseUrl: _baseUrl));

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await TokenStorage.read();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ),
  );

  return dio;
});
