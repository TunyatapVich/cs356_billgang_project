import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Application configuration read purely from environment (.env or --dart-define).
/// NO hardcoded URLs!
class AppConfig {
  AppConfig._();

  /// Reads API Base URL strictly from environment.
  /// Checks .env file (API_BASE_URL or API_URL),
  /// or compile-time environment variables (--dart-define).
  static String get baseUrl {
    final envUrl = _getEnvVar('API_BASE_URL') ?? _getEnvVar('API_URL');

    if (envUrl != null && envUrl.trim().isNotEmpty) {
      return envUrl.trim();
    }

    throw StateError(
      '❌ [AppConfig] API_BASE_URL is not configured!\n'
      'Please specify API_BASE_URL in your frontend/.env file.\n'
      'Example:\n'
      '  API_BASE_URL=https://billgang.onrender.com\n'
      '  or\n'
      '  API_BASE_URL=http://localhost:3000\n',
    );
  }

  /// Reads WebSocket Base URL strictly from environment.
  /// If WS_BASE_URL is not set, converts baseUrl (http -> ws, https -> wss).
  static String get wsBaseUrl {
    final envWs = _getEnvVar('WS_BASE_URL') ?? _getEnvVar('WS_URL');

    if (envWs != null && envWs.trim().isNotEmpty) {
      return envWs.trim();
    }

    final base = baseUrl;
    if (base.startsWith('https://')) {
      return base.replaceFirst('https://', 'wss://');
    }
    if (base.startsWith('http://')) {
      return base.replaceFirst('http://', 'ws://');
    }
    return base;
  }

  static String? _getEnvVar(String key) {
    if (dotenv.isInitialized) {
      try {
        final val = dotenv.maybeGet(key);
        if (val != null && val.trim().isNotEmpty) return val.trim();
      } catch (_) {}
    }
    return _fromDartDefine(key);
  }

  static String? _fromDartDefine(String key) {
    if (bool.hasEnvironment(key)) {
      final value = String.fromEnvironment(key);
      if (value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }
}
