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

// ── Shared interceptor setup ──────────────────────────────────────────────

/// Converts a raw [DioException] 4xx/5xx response into a readable [Exception].
/// This means every service (bill, auth, settlement…) gets clean error strings
/// for free — no per-screen DioException parsing needed.
void _addInterceptors(Dio dio) {
  // 🔍 Network logging — equivalent to the browser Network tab.
  // Shows full request/response bodies in the Flutter debug console.
  // Remove LogInterceptor before releasing to production.
  dio.interceptors.add(
    LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => debugPrint(obj.toString()),
    ),
  );

  // 🚨 Convert DioException → readable Exception so UI just does e.toString().
  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (DioException err, ErrorInterceptorHandler handler) {
        final body = err.response?.data;
        String? message;

        if (body is Map) {
          // Elysia / most backends: { message: "..." } or { error: "..." }
          message = (body['message'] ?? body['error'])?.toString();
        } else if (body is String && body.isNotEmpty) {
          message = body;
        }

        if (message != null && message.isNotEmpty) {
          handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              response: err.response,
              type: err.type,
              error: message,
              message: message,
            ),
          );
        } else {
          handler.next(err);
        }
      },
    ),
  );
}

// Unauthenticated Dio — for login / register (no token needed)
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(baseUrl: _baseUrl));
  _addInterceptors(dio);
  return dio;
});

// Authenticated Dio — for protected endpoints (attaches JWT from storage)
final authDioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(baseUrl: _baseUrl));
  _addInterceptors(dio);

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
