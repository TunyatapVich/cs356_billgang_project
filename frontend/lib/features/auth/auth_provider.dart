import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/storage/token_storage.dart';
import 'auth_service.dart';

// User model — matches the shape your backend returns (minus password_hash)
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

// AuthNotifier — same as a Zustand store or useReducer auth context in React
// AsyncNotifier<User?> means state is one of: loading | error | User | null (logged out)
class AuthNotifier extends AsyncNotifier<User?> {
  // build() runs once on startup — restore session if token exists
  @override
  Future<User?> build() async {
    final token = await TokenStorage.read();
    if (token == null) return null;

    // Validate token and restore user state
    final result = await ref.read(authServiceProvider).getProfile();
      return User.fromJson(result['user'] as Map<String, dynamic>);
  }

  // login() — calls AuthService (which calls the API), saves token, updates state
  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final data = await ref.read(authServiceProvider).login(email, password);
      await TokenStorage.save(data['token']);
      return User.fromJson(data['user'] as Map<String, dynamic>);
    });
  }

  // register() — same as login but for new account creation
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

  // logout() — clear token, set state back to null

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
    state = await AsyncValue.guard(() async {
      final data = await ref.read(authServiceProvider).updateProfile(
        displayName: displayName,
        avatarUrl: avatarUrl,
        promptpayNumber: promptpayNumber,
      );
      return User.fromJson(data['user'] as Map<String, dynamic>);
    });
  }
}

// The provider — exposes AuthNotifier to any widget via ref.watch / ref.read
// Same as: export const useAuthStore = create(...) in Zustand
final authProvider = AsyncNotifierProvider<AuthNotifier, User?>(
  AuthNotifier.new,
);
