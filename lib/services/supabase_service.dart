import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  /// URL proyek Supabase (didapat dari ID project: lbjpvbwmctzuhkqdidpt)
  static const String supabaseUrl = 'https://lbjpvbwmctzuhkqdidpt.supabase.co';

  /// Kunci Anon / Public Key dari dashboard Supabase Anda:
  /// Project Settings -> API -> Project API keys -> anon (public)
  static const String supabaseAnonKey =
      'sb_publishable_hjlSBckeJ06uoUd6BOdTHA_WhNjy8u1';

  /// Inisialisasi Supabase saat aplikasi Flutter pertama kali dibuka
  static Future<void> initialize() async {
    if (supabaseAnonKey == 'TEMPEL_ANON_KEY_DI_SINI' ||
        supabaseAnonKey.isEmpty) {
      debugPrint(
        '⚠️ Supabase Anon Key belum diisi di lib/services/supabase_service.dart. '
        'Aplikasi tetap berjalan normal, silakan isi anon key untuk mengaktifkan koneksi database.',
      );
      return;
    }

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );
      debugPrint('✅ Supabase berhasil terhubung: $supabaseUrl');
    } catch (e) {
      debugPrint('❌ Gagal inisialisasi Supabase: $e');
    }
  }

  /// Instance Supabase client untuk query data, auth, dll
  static SupabaseClient get client => Supabase.instance.client;
}
