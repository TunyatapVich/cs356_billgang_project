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
  // Injected via --dart-define for security (CI/CD/prod). Fallback to placeholder for dev.
  // Example: flutter run --dart-define=CLOUDINARY_CLOUD_NAME=xxx
  const cloudName = String.fromEnvironment('CLOUDINARY_CLOUD_NAME', defaultValue: '');
  if (cloudName.isEmpty) {
    throw Exception('CLOUDINARY_CLOUD_NAME not configured. Run with --dart-define=CLOUDINARY_CLOUD_NAME=your_cloud_name');
  }
  return cloudName;
}

// Cloudinary upload preset — injected via --dart-define
String get cloudinaryUploadPreset {
  const preset = String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET', defaultValue: '');
  if (preset.isEmpty) {
    throw Exception('CLOUDINARY_UPLOAD_PRESET not configured. Run with --dart-define=CLOUDINARY_UPLOAD_PRESET=your_preset');
  }
  return preset;
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
