import 'package:dio/dio.dart';

class ApiClient {
  static const _baseUrl = 'http://localhost:3000';

  static Dio create({String? token}) {
    final dio = Dio(BaseOptions(baseUrl: _baseUrl));

    if (token != null) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            options.headers['Authorization'] = 'Bearer $token';
            handler.next(options);
          },
        ),
      );
    }

    return dio;
  }
}
