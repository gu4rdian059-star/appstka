import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_env.dart';

class SupabaseService {
  static bool _initialized = false;

  /// URL proyek Supabase (dibaca dari .env via AppEnv)
  static String get supabaseUrl => AppEnv.supabaseUrl;

  /// Kunci Anon / Publishable Key (dibaca dari .env via AppEnv)
  static String get supabaseAnonKey => AppEnv.supabaseAnonKey;

  static bool get isInitialized => _initialized;

  /// Inisialisasi Supabase saat aplikasi Flutter pertama kali dibuka
  static Future<void> initialize() async {
    if (_initialized) return;

    await AppEnv.load();

    if (supabaseAnonKey == 'TEMPEL_ANON_KEY_DI_SINI' || supabaseAnonKey.isEmpty) {
      debugPrint(
        '⚠️ Supabase Anon Key belum diisi di .env. '
        'Aplikasi berjalan dengan mode fallback lokal.',
      );
      return;
    }

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );
      _initialized = true;
      debugPrint('✅ Supabase berhasil terhubung: $supabaseUrl');
    } catch (e) {
      debugPrint('❌ Gagal inisialisasi Supabase: $e');
    }
  }

  /// Instance Supabase client untuk query data, auth, realtime, dll
  static SupabaseClient get client => Supabase.instance.client;
}
