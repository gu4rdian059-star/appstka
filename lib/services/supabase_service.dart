import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_env.dart';
import 'auth_service.dart';
import 'session_service.dart';

class SupabaseService {
  static bool _initialized = false;
  static const String _prefPendingGoogleOAuth = 'tka_pending_google_oauth';

  /// Jika aplikasi baru saja dimuat ulang dari redirect Google OAuth (?code=...),
  /// field ini berisi nama user Google agar aplikasi langsung membuka Beranda (DashboardScreen)
  /// tanpa terpental kembali ke SplashScreen / OnboardingScreen.
  static String? initialOAuthUserName;

  /// Menyimpan apakah URL awal saat aplikasi dibuka mengandung parameter callback OAuth (?code=...)
  static bool launchedFromOAuthCallback = false;

  /// URL proyek Supabase (dibaca dari .env via AppEnv)
  static String get supabaseUrl => AppEnv.supabaseUrl;

  /// Kunci Anon / Publishable Key (dibaca dari .env via AppEnv)
  static String get supabaseAnonKey => AppEnv.supabaseAnonKey;

  static bool get isInitialized => _initialized;

  static Future<void> setPendingGoogleOAuth(bool pending) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefPendingGoogleOAuth, pending);
    } catch (_) {}
  }

  static Future<bool> consumePendingGoogleOAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getBool(_prefPendingGoogleOAuth) ?? false;
      if (val) {
        await prefs.remove(_prefPendingGoogleOAuth);
      }
      return val;
    } catch (_) {
      return false;
    }
  }

  /// Inisialisasi Supabase saat aplikasi Flutter pertama kali dibuka
  /// sekaligus menangani callback OAuth Google (`?code=...` atau `#access_token=...`).
  static Future<void> initialize() async {
    if (_initialized) return;

    await AppEnv.load();

    if (supabaseAnonKey == 'TEMPEL_ANON_KEY_DI_SINI' ||
        supabaseAnonKey.isEmpty) {
      debugPrint(
        '⚠️ Supabase Anon Key belum diisi di .env. '
        'Aplikasi berjalan dengan mode fallback lokal.',
      );
      return;
    }

    // PENTING: Ambil Uri.base SEBELUM Supabase.initialize() dipanggil!
    // Karena pada Flutter Web, Supabase.initialize() otomatis memanggil
    // clearAuthUrlParameters() yang menghapus `?code=...` dari address bar browser.
    final initialUri = Uri.base;
    final hasOAuthCodeBeforeInit =
        initialUri.queryParameters.containsKey('code') ||
        initialUri.fragment.contains('access_token=') ||
        initialUri.queryParameters.containsKey('access_token');
    launchedFromOAuthCallback = hasOAuthCodeBeforeInit;

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );
      _initialized = true;
      debugPrint('✅ Supabase berhasil terhubung: $supabaseUrl');

      final hadPendingOAuth = await consumePendingGoogleOAuth();

      // Jika di URL awal ada ?code=... namun sesi belum tertukar otomatis, tukar secara eksplisit
      if (hasOAuthCodeBeforeInit && client.auth.currentUser == null) {
        try {
          debugPrint(
            '🔄 Menukar kode OAuth Google dari URL awal: $initialUri',
          );
          await client.auth.getSessionFromUrl(initialUri);
        } catch (e) {
          debugPrint('ℹ️ Catatan getSessionFromUrl saat startup: $e');
        }
      }

      final currentUser = client.auth.currentUser;
      final isGoogleProvider =
          currentUser?.appMetadata['provider']?.toString() == 'google';

      if (currentUser != null &&
          (hasOAuthCodeBeforeInit || hadPendingOAuth || isGoogleProvider)) {
        await AuthService.syncGoogleUserSession(currentUser);
        initialOAuthUserName = await SessionService.getUserName();
        debugPrint(
          '✅ Redirect Google OAuth berhasil! Langsung membuka Beranda untuk: $initialOAuthUserName',
        );
      }
    } catch (e) {
      debugPrint('❌ Gagal inisialisasi Supabase: $e');
    }
  }

  /// Instance Supabase client untuk query data, auth, realtime, dll
  static SupabaseClient get client => Supabase.instance.client;
}
