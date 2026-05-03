import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _baseUrl = 'http://localhost:3000';

// Unauthenticated Dio — for login / register (no token needed)
// Same idea as: export const axios = axios.create({ baseURL }) in Next.js
final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(baseUrl: _baseUrl));
});

// Authenticated Dio — for protected endpoints (attaches JWT from storage)
// Use this in bill, assign, settlement services once auth is done
//
// final authDioProvider = Provider<Dio>((ref) {
//   final token = ref.watch(/* tokenProvider — wire up after auth is done */);
//   final dio = Dio(BaseOptions(baseUrl: _baseUrl));
//   if (token != null) {
//     dio.interceptors.add(
//       InterceptorsWrapper(
//         onRequest: (options, handler) {
//           options.headers['Authorization'] = 'Bearer $token';
//           handler.next(options);
//         },
//       ),
//     );
//   }
//   return dio;
// });
