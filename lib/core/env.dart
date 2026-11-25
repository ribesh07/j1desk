import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Reads settings from the bundled `.env` file (see `.env.example`).
class Env {
  /// Loads `.env` once at startup. Missing file → defaults are used.
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // No .env bundled: fall back to defaults below.
    }
  }

  static String _get(String key, [String fallback = '']) {
    final value = dotenv.isInitialized ? dotenv.env[key]?.trim() : null;
    return (value == null || value.isEmpty) ? fallback : value;
  }

  /// Optional build-time override: flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3443
  static const _apiUrlOverride = String.fromEnvironment('API_BASE_URL');

  /// Server URL without trailing slash, e.g. https://tickets.j1soft.org
  static String get apiBaseUrl =>
      (_apiUrlOverride.isNotEmpty ? _apiUrlOverride : _get('API_BASE_URL', 'https://tickets.j1soft.org'))
          .replaceAll(RegExp(r'/+$'), '');

  // Firebase client config (public values, safe to ship in the app)
  static String get firebaseProjectId => _get('FIREBASE_PROJECT_ID');
  static String get firebaseSenderId => _get('FIREBASE_MESSAGING_SENDER_ID');
  static String get firebaseStorageBucket => _get('FIREBASE_STORAGE_BUCKET');
  static String get firebaseAndroidAppId => _get('FIREBASE_ANDROID_APP_ID');
  static String get firebaseAndroidApiKey => _get('FIREBASE_ANDROID_API_KEY');
  static String get firebaseIosAppId => _get('FIREBASE_IOS_APP_ID');
  static String get firebaseIosApiKey => _get('FIREBASE_IOS_API_KEY');
}
