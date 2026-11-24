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

  static String _read(
    String key, {
    String defineValue = '',
    String fallback = '',
  }) {
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

  // ================= GOOGLE OAUTH CONFIGURATION =================
  static String get googleWebClientId => _read(
        'GOOGLE_WEB_CLIENT_ID',
        defineValue: const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
      );

  static String get googleAndroidClientId => _read(
        'GOOGLE_ANDROID_CLIENT_ID',
        defineValue: const String.fromEnvironment('GOOGLE_ANDROID_CLIENT_ID'),
      );

  static String get googleClientSecret => _read(
        'GOOGLE_CLIENT_SECRET',
        defineValue: const String.fromEnvironment('GOOGLE_CLIENT_SECRET'),
      );

  static String get googleSupabaseCallbackUrl => _read(
        'GOOGLE_SUPABASE_CALLBACK_URL',
        defineValue:
            const String.fromEnvironment('GOOGLE_SUPABASE_CALLBACK_URL'),
        fallback: 'https://lbjpvbwmctzuhkqdidpt.supabase.co/auth/v1/callback',
      );

  static String get googleLocalCallbackUrl => _read(
        'GOOGLE_LOCAL_CALLBACK_URL',
        defineValue: const String.fromEnvironment('GOOGLE_LOCAL_CALLBACK_URL'),
        fallback: 'http://127.0.0.1:8000/auth/google/callback',
      );

  static String get googleAppRedirectUri => _read(
        'GOOGLE_APP_REDIRECT_URI',
        defineValue: const String.fromEnvironment('GOOGLE_APP_REDIRECT_URI'),
        fallback: 'com.example.appstka://login-callback',
      );

  // ================= CLOUDFLARE TURNSTILE CONFIGURATION =================
  static bool get turnstileEnabled {
    final raw = _read(
      'TURNSTILE_ENABLED',
      defineValue: const String.fromEnvironment('TURNSTILE_ENABLED'),
      fallback: 'true',
    ).toLowerCase();
    return raw == 'true' || raw == '1' || raw == 'yes';
  }

  static String get turnstileSiteKey => _read(
        'TURNSTILE_SITE_KEY',
        defineValue: const String.fromEnvironment('TURNSTILE_SITE_KEY'),
        fallback: '1x00000000000000000000AA',
      );

  static String get turnstileSecretKey => _read(
        'TURNSTILE_SECRET_KEY',
        defineValue: const String.fromEnvironment('TURNSTILE_SECRET_KEY'),
        fallback: '1x0000000000000000000000000000000AA',
      );

  // ================= MAPTILER & BREVO CONFIGURATION =================
  static String get mapTilerApiKey => _read(
        'MAPTILER_API_KEY',
        defineValue: const String.fromEnvironment('MAPTILER_API_KEY'),
      );

  static String get mapTilerStyleUrl => _read(
        'MAPTILER_STYLE_URL',
        defineValue: const String.fromEnvironment('MAPTILER_STYLE_URL'),
      );

  static String get brevoApiKey {
    final key = _read(
      'BREVO_API_KEY',
      defineValue: const String.fromEnvironment('BREVO_API_KEY'),
    );
    if (key.isNotEmpty) return key;
    final smtpPass = _read(
      'SMTP_PASS',
      defineValue: const String.fromEnvironment('SMTP_PASS'),
    );
    if (smtpPass.startsWith('xkeysib-') || smtpPass.startsWith('xsmtpsib-')) {
      return smtpPass;
    }
    return '';
  }

  static String get smtpHost => _read(
        'SMTP_HOST',
        defineValue: const String.fromEnvironment('SMTP_HOST'),
        fallback: 'smtp-relay.brevo.com',
      );

  static int get smtpPort =>
      int.tryParse(_read(
        'SMTP_PORT',
        defineValue: const String.fromEnvironment('SMTP_PORT'),
        fallback: '587',
      )) ??
      587;

  static String get smtpUser => _read(
        'SMTP_USER',
        defineValue: const String.fromEnvironment('SMTP_USER'),
        fallback: 'b16832001@smtp-brevo.com',
      );

  static String get smtpPass => _read(
        'SMTP_PASS',
        defineValue: const String.fromEnvironment('SMTP_PASS'),
      );

  static String get brevoSenderEmail {
    final email = _read(
      'BREVO_SENDER_EMAIL',
      defineValue: const String.fromEnvironment('BREVO_SENDER_EMAIL'),
      fallback: 'samawwalazhar@gmail.com',
    );
    if (email.contains('samawwalaxhar')) {
      return email.replaceAll('samawwalaxhar', 'samawwalazhar');
    }
    return email;
  }

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
  static bool get hasSmtpConfig => smtpUser.isNotEmpty && smtpPass.isNotEmpty;
}
