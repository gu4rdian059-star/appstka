import 'package:flutter/foundation.dart';
import 'env_loader_stub.dart' if (dart.library.io) 'env_loader_io.dart';

/// Konfigurasi environment aplikasi TKA yang diamankan:
/// 1. Tidak pernah menanamkan (hardcode) URL Supabase, Anon Key, atau Secret Key di kode sumber.
/// 2. Pada Flutter Web, seluruh request diarahkan melalui Secure API Gateway (`API_GATEWAY_URL`,
///    default `http://localhost:8787`) sehingga URL proyek Supabase & Secret Key tetap tersembunyi di server.
/// 3. Pada lingkungan non-Web / pengujian (`dart:io`), membaca `.env` dari sistem file lokal tanpa membundelnya ke `assets/`.
class AppEnv {
  static bool _loaded = false;
  static final Map<String, String> _localEnv = <String, String>{};

  /// Endpoint proxy gateway lokal/backend untuk menyembunyikan URL & kunci Supabase di browser.
  static String get apiGatewayUrl => _read(
        'API_GATEWAY_URL',
        defineValue: const String.fromEnvironment('API_GATEWAY_URL'),
        fallback: 'http://localhost:8787',
      );

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final map = await loadLocalEnvFile();
      _localEnv
        ..clear()
        ..addAll(map);
      _loaded = true;
      if (_localEnv.isNotEmpty) {
        debugPrint('✅ Konfigurasi environment lokal berhasil dimuat secara aman.');
      }
    } catch (e) {
      debugPrint('ℹ️ Mode environment terproteksi aktif: $e');
    }
  }

  static String _read(
    String key, {
    String defineValue = '',
    String fallback = '',
  }) {
    if (defineValue.isNotEmpty) return defineValue;
    final val = _localEnv[key];
    if (val != null && val.trim().isNotEmpty) {
      return val.trim();
    }
    return fallback;
  }

  /// URL proyek Supabase (TIDAK di-hardcode; pada Web otomatis memakai Gateway jika tidak di-inject).
  static String get supabaseUrl => _read(
        'SUPABASE_URL',
        defineValue: const String.fromEnvironment('SUPABASE_URL'),
        fallback: kIsWeb ? apiGatewayUrl : '',
      );

  /// Publishable/Anon Key (pada Web digantikan token sesi Gateway sehingga key asli tidak terekspos).
  static String get supabaseAnonKey => _read(
        'SUPABASE_ANON_KEY',
        defineValue: const String.fromEnvironment('SUPABASE_ANON_KEY'),
        fallback: kIsWeb ? 'tka-gateway-protected-client' : '',
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

  /// Secret OAuth hanya boleh dibaca di sisi server/gateway, tidak pernah di Web.
  static String get googleClientSecret => kIsWeb
      ? ''
      : _read(
          'GOOGLE_CLIENT_SECRET',
          defineValue: const String.fromEnvironment('GOOGLE_CLIENT_SECRET'),
        );

  static String get googleSupabaseCallbackUrl => _read(
        'GOOGLE_SUPABASE_CALLBACK_URL',
        defineValue:
            const String.fromEnvironment('GOOGLE_SUPABASE_CALLBACK_URL'),
        fallback: '${supabaseUrl.isNotEmpty ? supabaseUrl : apiGatewayUrl}/auth/v1/callback',
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

  /// Secret Turnstile tidak pernah diekspos ke Web client.
  static String get turnstileSecretKey => kIsWeb
      ? ''
      : _read(
          'TURNSTILE_SECRET_KEY',
          defineValue: const String.fromEnvironment('TURNSTILE_SECRET_KEY'),
        );

  // ================= MAPTILER & BREVO CONFIGURATION =================
  static String get mapTilerApiKey => _read(
        'MAPTILER_API_KEY',
        defineValue: const String.fromEnvironment('MAPTILER_API_KEY'),
      );

  /// Pada Web, style JSON MapTiler disajikan lewat cache RAM Gateway (`/api/map/style.json`)
  /// agar termuat < 1ms sekaligus tidak mengekspos API key mentah pada URL style.
  static String get mapTilerStyleUrl => _read(
        'MAPTILER_STYLE_URL',
        defineValue: const String.fromEnvironment('MAPTILER_STYLE_URL'),
        fallback: kIsWeb ? '$apiGatewayUrl/api/map/style.json' : '',
      );

  /// Pada Web, pengiriman email diarahkan ke endpoint proxy `/brevo/v3/smtp/email`
  /// sehingga BREVO_API_KEY rahasia tidak pernah dikirim dari browser.
  static String get brevoApiKey {
    if (kIsWeb) return '';
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
      );

  static String get smtpPass => kIsWeb
      ? ''
      : _read(
          'SMTP_PASS',
          defineValue: const String.fromEnvironment('SMTP_PASS'),
        );

  static String get brevoSenderEmail {
    final email = _read(
      'BREVO_SENDER_EMAIL',
      defineValue: const String.fromEnvironment('BREVO_SENDER_EMAIL'),
      fallback: 'noreply@tka-rail.id',
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
  static bool get hasBrevoConfig => kIsWeb || brevoApiKey.isNotEmpty;
  static bool get hasSmtpConfig => smtpUser.isNotEmpty && smtpPass.isNotEmpty;
}
