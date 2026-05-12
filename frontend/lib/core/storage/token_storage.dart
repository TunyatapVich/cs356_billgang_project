import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _storage = FlutterSecureStorage();
  static const _key = 'auth_token';

  static Future<void> save(String token) => _storage.write(key: _key, value: token);
  static Future<String?> read() => _storage.read(key: _key);
  static Future<void> delete() => _storage.delete(key: _key);
}

// static Future<void> saveLastLogin() async {
//   await _storage.write(key: _lastLoginKey, value: DateTime.now().toIso8601String());
// }

// static Future<DateTime?> readLastLogin() async {
//   final str = await _storage.read(key: _lastLoginKey);
//   if (str == null) return null;
//   return DateTime.tryParse(str);
// }

// static Future<bool> isTokenExpired() async {
//   final lastLogin = await readLastLogin();
//   if (lastLogin == null) return true;
//   final expiry = lastLogin.add(const Duration(days: _expiryDays));
//   return DateTime.now().isAfter(expiry);
// }