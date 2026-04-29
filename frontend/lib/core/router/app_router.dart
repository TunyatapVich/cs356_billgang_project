import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const Placeholder()),
    GoRoute(path: '/profile-setup', builder: (_, __) => const Placeholder()),
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

// AuthService only knows about HTTP calls — no Dio.create(), no token logic here
// Same as: lib/api/auth.ts in Next.js that just calls axios.post(...)
class AuthService {
  final Dio _dio;
  const AuthService(this._dio);

  // TODO 1: implement login
  // - POST /auth/login with { email, password }
  // - return response.data on 200
  // - throw Exception(response.data['message']) on error (401 = wrong credentials)
  //
  // Future<Map<String, dynamic>> login(String email, String password) async {
  //   final response = await _dio.post('/auth/login', data: {
  //     'email': email,
  //     'password': password,
  //   });
  //   return response.data as Map<String, dynamic>;
  // }
}

// Riverpod provider for AuthService — Dio is injected from dioProvider
// Same as: singleton service in Next.js that shares one axios instance
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(dioProvider));
});

    // main (leave as Placeholder until those screens are built)
    GoRoute(path: '/home', builder: (_, __) => const Placeholder()),
    GoRoute(path: '/bill/create', builder: (_, __) => const Placeholder()),
    GoRoute(path: '/bill/:id/items', builder: (_, __) => const Placeholder()),
    GoRoute(path: '/bill/:id/ocr', builder: (_, __) => const Placeholder()),
    GoRoute(path: '/bill/:id/invite', builder: (_, __) => const Placeholder()),
    GoRoute(path: '/bill/:id/assign', builder: (_, __) => const Placeholder()),
    GoRoute(
      path: '/bill/:id/settlement',
      builder: (_, __) => const Placeholder(),
    ),
    GoRoute(path: '/join', builder: (_, __) => const Placeholder()),
  ],
);
