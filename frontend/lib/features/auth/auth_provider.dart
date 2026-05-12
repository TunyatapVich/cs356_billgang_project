import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/storage/token_storage.dart';
import 'auth_service.dart';

class User {
  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final String? promptpayNumber;

  const User({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    this.promptpayNumber,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'],
    email: json['email'],
    displayName: json['display_name'] ?? json['displayName'],
    avatarUrl: json['avatar_url'] ?? json['avatarUrl'],
    promptpayNumber: json['promptpay_number'] ?? json['promptpayNumber'],
  );
}

class AuthNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    final token = await TokenStorage.read();
    if (token == null) return null;
    try {
      final result = await ref.read(authServiceProvider).getProfile();
      return User.fromJson(result['user'] as Map<String, dynamic>);
    } catch (_) {
      await TokenStorage.delete();
      return null;
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final data = await ref.read(authServiceProvider).login(email, password);
      await TokenStorage.save(data['token']);
      return User.fromJson(data['user'] as Map<String, dynamic>);
    });
  }

  Future<void> register(
    String email,
    String phone,
    String password,
    String passwordConfirm,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final data = await ref
          .read(authServiceProvider)
          .register(email, phone, password, passwordConfirm);
      await TokenStorage.save(data['token']);
      return User.fromJson(data['user'] as Map<String, dynamic>);
    });
  }

  Future<void> logout() async {
    await TokenStorage.delete();
    state = const AsyncData(null);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() async {
      final data = await ref.read(authServiceProvider).getProfile();
      return User.fromJson(data['user'] as Map<String, dynamic>);
    });
  }

  Future<void> updateProfile({
    String? displayName,
    String? avatarUrl,
    String? promptpayNumber,
  }) async {
    final data = await ref
        .read(authServiceProvider)
        .updateProfile(
          displayName: displayName,
          avatarUrl: avatarUrl,
          promptpayNumber: promptpayNumber,
        );
    final userJson = data['user'] as Map<String, dynamic>?;
    if (userJson != null) {
      state = AsyncData(User.fromJson(userJson));
    }
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, User?>(
  AuthNotifier.new,
);

// // 30-day expiry system (commented out — uncomment to re-enable)
// // In TokenStorage:
// //   static const _lastLoginKey = 'last_login';
// //   static const _expiryDays = 30;
// //   static Future<void> saveLastLogin() async { ... }
// //   static Future<DateTime?> readLastLogin() async { ... }
// //   static Future<bool> isTokenExpired() async { ... }
// //
// // In AuthNotifier.build():
// //   if (await TokenStorage.isTokenExpired()) { await TokenStorage.delete(); return null; }
