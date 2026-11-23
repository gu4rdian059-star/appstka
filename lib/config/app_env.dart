import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Konfigurasi environment aplikasi TKA.
/// Membaca kredensial dari file `.env` (via flutter_dotenv) atau `--dart-define`.
class AppEnv {
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      await dotenv.load(fileName: '.env');
      _loaded = true;
      debugPrint('✅ File .env berhasil dimuat.');
    } catch (e) {
      debugPrint('⚠️ Catatan memuat .env (menggunakan dart-define/fallback): $e');
    }
  }

  static String _read(String key, {String defineValue = '', String fallback = ''}) {
    if (defineValue.isNotEmpty) return defineValue;
    if (_loaded) {
      final val = dotenv.maybeGet(key);
      if (val != null && val.trim().isNotEmpty) {
        return val.trim();
      }
    }
    return fallback;
  }

  static String get supabaseUrl => _read(
        'SUPABASE_URL',
        defineValue: const String.fromEnvironment('SUPABASE_URL'),
        fallback: 'https://lbjpvbwmctzuhkqdidpt.supabase.co',
      );

  static String get supabaseAnonKey => _read(
        'SUPABASE_ANON_KEY',
        defineValue: const String.fromEnvironment('SUPABASE_ANON_KEY'),
        fallback: 'sb_publishable_hjlSBckeJ06uoUd6BOdTHA_WhNjy8u1',
      );

  static String get mapTilerApiKey => _read(
        'MAPTILER_API_KEY',
        defineValue: const String.fromEnvironment('MAPTILER_API_KEY'),
      );

  static String get mapTilerStyleUrl => _read(
        'MAPTILER_STYLE_URL',
        defineValue: const String.fromEnvironment('MAPTILER_STYLE_URL'),
      );

  static String get brevoApiKey => _read(
        'BREVO_API_KEY',
        defineValue: const String.fromEnvironment('BREVO_API_KEY'),
      );

  static String get brevoSenderEmail => _read(
        'BREVO_SENDER_EMAIL',
        defineValue: const String.fromEnvironment('BREVO_SENDER_EMAIL'),
        fallback: 'noreply@tka-rail.id',
      );

  static String get brevoSenderName => _read(
        'BREVO_SENDER_NAME',
        defineValue: const String.fromEnvironment('BREVO_SENDER_NAME'),
        fallback: 'TKA Rail Tracking',
      );

  static String get defaultTimezone => _read(
        'DEFAULT_TIMEZONE',
        defineValue: const String.fromEnvironment('DEFAULT_TIMEZONE'),
        fallback: 'WIB',
      );

  static bool get hasMapTilerConfig => mapTilerStyleUrl.isNotEmpty;
  static bool get hasBrevoConfig => brevoApiKey.isNotEmpty;
}

