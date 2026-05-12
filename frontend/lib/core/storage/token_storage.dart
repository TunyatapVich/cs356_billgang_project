import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _lastLoginKey = 'last_login';
  static const _expiryDays = 30;

  static Future<void> save(String token) => _storage.write(key: _tokenKey, value: token);
  static Future<String?> read() => _storage.read(key: _tokenKey);
  static Future<void> delete() => _storage.delete(key: _tokenKey);

  static Future<void> saveLastLogin() async {
    await _storage.write(key: _lastLoginKey, value: DateTime.now().toIso8601String());
  }

  static Future<DateTime?> readLastLogin() async {
    final str = await _storage.read(key: _lastLoginKey);
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  static Future<bool> isTokenExpired() async {
    final lastLogin = await readLastLogin();
    if (lastLogin == null) return true;
    final expiry = lastLogin.add(const Duration(days: _expiryDays));
    return DateTime.now().isAfter(expiry);
  }
}
