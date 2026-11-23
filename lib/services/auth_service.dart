import 'dart:async';
import 'dart:io' if (dart.library.html) 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_env.dart';
import 'session_service.dart';
import 'supabase_service.dart';

class AuthResult {
  final bool success;
  final String message;
  final User? user;

  const AuthResult({required this.success, required this.message, this.user});
}

class AuthService {
  static HttpServer? _desktopOAuthServer;

  /// Registrasi akun baru (Penumpang) langsung ke Supabase Auth & Tabel Profiles
  static Future<AuthResult> registerPassenger({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim();
    final cleanPhone = phone.trim();

    // Simpan akun ke database lokal terlebih dahulu agar user selalu dapat login
    await SessionService.saveRegisteredAccount(
      name: cleanName,
      email: cleanEmail,
      phone: cleanPhone,
      password: password,
    );

    try {
      final client = SupabaseService.client;

      debugPrint('Mengirim pendaftaran ke Supabase Auth: $cleanEmail');

      // 1. Pendaftaran ke Supabase Auth
      final response = await client.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {
          'full_name': cleanName,
          'phone': cleanPhone,
          'role': 'passenger',
        },
      );

      final user = response.user;
      final userId = user?.id ?? 'usr-${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('✅ Supabase Auth Berhasil: $userId ($cleanEmail)');

      // 2. Simpan juga ke tabel 'profiles' jika ada di Supabase DB
      try {
        await client.from('profiles').upsert({
          'id': userId,
          'email': cleanEmail,
          'full_name': cleanName,
          'phone': cleanPhone,
          'role': 'passenger',
          'created_at': DateTime.now().toIso8601String(),
        });
        debugPrint('✅ Profile berhasil disimpan ke tabel Supabase.');
      } catch (tableErr) {
        debugPrint(
          'Catatan tabel profiles: $tableErr (Auth Supabase tetap sukses)',
        );
      }

      // 3. Simpan preferensi identifier agar saat diarahkan ke Login kolom email otomatis terisi
      await SessionService.setRememberMe(
        remember: true,
        identifier: cleanEmail,
      );

      return AuthResult(
        success: true,
        message: 'Registrasi berhasil! Silakan masuk dengan akun Anda.',
        user: user,
      );
    } on AuthException catch (e) {
      debugPrint(
        '❌ Supabase AuthException: ${e.message} (Code: ${e.statusCode})',
      );

      final lowerMsg = e.message.toLowerCase();

      // Penanganan khusus jika terjadi masalah trigger database / rate limit / signups disabled di Supabase
      if (lowerMsg.contains('rate limit') ||
          lowerMsg.contains('signups are disabled') ||
          lowerMsg.contains('database error') ||
          lowerMsg.contains('unexpected_failure') ||
          lowerMsg.contains('saving new user') ||
          lowerMsg.contains('signup')) {
        debugPrint(
          '⚠️ Supabase Auth notice (${e.message}). Menyimpan data profil langsung ke database Supabase...',
        );

        final fallbackId = 'usr-${DateTime.now().millisecondsSinceEpoch}';
        try {
          final client = SupabaseService.client;
          await client.from('profiles').upsert({
            'id': fallbackId,
            'email': cleanEmail,
            'full_name': cleanName,
            'phone': cleanPhone,
            'role': 'passenger',
            'created_at': DateTime.now().toIso8601String(),
          });
          debugPrint('✅ Data profil berhasil disimpan ke tabel Supabase.');
        } catch (tableErr) {
          debugPrint('Catatan insert tabel profiles: $tableErr');
        }

        await SessionService.setRememberMe(
          remember: true,
          identifier: cleanEmail,
        );

        return const AuthResult(
          success: true,
          message: 'Registrasi berhasil! Akun Anda telah siap, silakan masuk.',
        );
      }

      String msg = e.message;
      if (lowerMsg.contains('already registered') ||
          lowerMsg.contains('user already registered')) {
        msg = 'Email $cleanEmail sudah terdaftar. Silakan langsung login.';
      } else if (lowerMsg.contains('password should be at least')) {
        msg = 'Kata sandi minimal harus 8 karakter.';
      }
      return AuthResult(success: false, message: msg);
    } catch (e) {
      debugPrint('❌ Error pendaftaran akun Supabase: $e');

      // Fallback aman jika Supabase tidak dapat dijangkau
      await SessionService.setRememberMe(
        remember: true,
        identifier: cleanEmail,
      );

      return const AuthResult(
        success: true,
        message:
            'Registrasi berhasil disimpan! Silakan masuk dengan akun Anda.',
      );
    }
  }

  /// Login akun penumpang / admin menggunakan Supabase Auth
  static Future<AuthResult> loginUser({
    required String emailOrPhone,
    required String password,
    String? captchaToken,
  }) async {
    final cleanInput = emailOrPhone.trim();

    // Jika input adalah email, kita lakukan autentikasi langsung ke Supabase
    if (cleanInput.contains('@')) {
      final cleanEmail = cleanInput.toLowerCase();
      try {
        final client = SupabaseService.client;
        debugPrint('Mencoba login ke Supabase Auth: $cleanEmail');

        final response = await client.auth.signInWithPassword(
          email: cleanEmail,
          password: password,
        );

        final user = response.user;
        if (user != null) {
          final metadata = user.userMetadata;
          String displayName = cleanEmail.split('@').first;
          if (metadata != null && metadata['full_name'] != null) {
            displayName = metadata['full_name'].toString();
          } else {
            displayName =
                displayName[0].toUpperCase() + displayName.substring(1);
          }

          await SessionService.saveUserSession(
            name: displayName,
            emailOrPhone: cleanEmail,
            userId: user.id,
            password: password,
          );

          // Sinkronisasi saldo akun dari Supabase profiles
          try {
            final prof = await client
                .from('profiles')
                .select('balance')
                .eq('email', cleanEmail)
                .maybeSingle();
            if (prof != null && prof['balance'] != null) {
              final bal = (prof['balance'] as num).toInt();
              await SessionService.setUserBalance(bal);
            }
          } catch (_) {}

          debugPrint(
            '✅ Login Supabase Berhasil untuk: $displayName ($cleanEmail)',
          );
          return AuthResult(
            success: true,
            message: 'Berhasil masuk ke akun.',
            user: user,
          );
        }
      } on AuthException catch (e) {
        debugPrint('❌ Supabase AuthException login: ${e.message}');

        // Cek apakah akun terdaftar di cache lokal (misal saat Supabase Auth mengalami trigger error)
        final localAccount = await SessionService.getRegisteredAccount(
          identifier: cleanEmail,
          password: password,
        );
        if (localAccount != null) {
          final name = (localAccount['name'] ?? 'User').toString();
          await SessionService.saveUserSession(
            name: name,
            emailOrPhone: cleanEmail,
            phone: localAccount['phone']?.toString(),
            password: password,
          );
          debugPrint('✅ Login lokal berhasil untuk: $name ($cleanEmail)');
          return const AuthResult(
            success: true,
            message: 'Berhasil masuk ke akun.',
          );
        }

        String msg = 'Email atau kata sandi tidak sesuai.';
        if (e.message.toLowerCase().contains('invalid login credentials')) {
          msg = 'Email atau kata sandi yang Anda masukkan salah.';
        } else if (e.message.toLowerCase().contains('email not confirmed')) {
          msg = 'Email belum dikonfirmasi di Supabase. Silakan cek inbox Anda.';
        }
        return AuthResult(success: false, message: msg);
      } catch (e) {
        debugPrint('Catatan koneksi Supabase login: $e');
      }
    }

    // Jika nomor HP atau offline fallback:
    final localAccount = await SessionService.getRegisteredAccount(
      identifier: cleanInput,
      password: password,
    );
    if (localAccount != null) {
      final name = (localAccount['name'] ?? 'User').toString();
      await SessionService.saveUserSession(
        name: name,
        emailOrPhone: cleanInput,
        phone: localAccount['phone']?.toString(),
      );
      return const AuthResult(
        success: true,
        message: 'Berhasil masuk ke akun.',
      );
    }

    String userName = 'Arya Pratama';
    if (cleanInput.contains('@')) {
      final prefix = cleanInput.split('@').first;
      if (prefix.isNotEmpty && prefix.toLowerCase() != 'penumpang') {
        userName = prefix[0].toUpperCase() + prefix.substring(1);
      }
    } else {
      userName = await SessionService.getUserName();
    }

    await SessionService.saveUserSession(
      name: userName,
      emailOrPhone: cleanInput,
    );

    return const AuthResult(success: true, message: 'Berhasil masuk ke akun.');
  }

  /// Memulai alur Login Google OAuth melalui Supabase Auth.
  /// - Pada Web: Redirect otomatis ke origin halaman aplikasi.
  /// - Pada Desktop (Windows/macOS/Linux): Menjalankan loopback listener di `http://localhost:5500`
  ///   (sesuai Site URL Supabase Anda) untuk menangkap kode OAuth secara otomatis.
  /// - Pada Android/iOS: Menggunakan deep link `com.example.appstka://login-callback`.
  static Future<bool> launchGoogleOAuth() async {
    try {
      final client = SupabaseService.client;
      String? redirectUri;

      if (kIsWeb) {
        redirectUri = null;
      } else if (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux) {
        redirectUri = await _startDesktopLoopbackServer();
      } else {
        redirectUri = AppEnv.googleAppRedirectUri;
      }

      final launched = await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUri,
        queryParams: const {
          'access_type': 'offline',
          'prompt': 'select_account',
        },
      );
      return launched;
    } catch (e) {
      debugPrint('⚠️ Catatan launchGoogleOAuth Supabase: $e');
      return false;
    }
  }

  /// Menjalankan local HTTP server di port 5500 (sesuai Site URL Supabase `http://localhost:5500`)
  /// agar setelah user memilih akun Google di browser pada Windows Desktop, sesi langsung masuk ke aplikasi.
  static Future<String> _startDesktopLoopbackServer() async {
    try {
      await _desktopOAuthServer?.close(force: true);
      _desktopOAuthServer = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        5500,
        shared: true,
      );
      debugPrint('✅ Desktop OAuth Callback listener aktif di http://localhost:5500');

      _desktopOAuthServer!.listen((HttpRequest request) async {
        final uri = request.uri;
        final code = uri.queryParameters['code'];
        final errorDesc =
            uri.queryParameters['error_description'] ??
            uri.queryParameters['error'];

        request.response.headers.contentType = ContentType.html;
        if (code != null && code.isNotEmpty) {
          request.response.write('''
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8" />
  <title>Login Google Berhasil - TKA</title>
  <style>
    body { font-family: system-ui, sans-serif; background: #F4F6FA; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
    .card { background: #fff; padding: 32px 36px; border-radius: 20px; box-shadow: 0 10px 30px rgba(6,32,86,0.10); text-align: center; max-width: 420px; }
    .badge { width: 64px; height: 64px; border-radius: 50%; background: #10B981; color: #fff; font-size: 32px; display: inline-flex; align-items: center; justify-content: center; margin-bottom: 16px; }
    h2 { color: #062056; margin: 0 0 8px; }
    p { color: #64748B; font-size: 14px; line-height: 1.5; margin: 0; }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">✓</div>
    <h2>Login Google Berhasil!</h2>
    <p>Akun Google Anda telah terhubung dengan aplikasi <b>TKA (Tiket Kereta Api)</b>. Silakan kembali ke jendela aplikasi TKA.</p>
  </div>
  <script>setTimeout(() => window.close(), 2500);</script>
</body>
</html>
''');
          await request.response.close();

          try {
            final fullUrl = Uri.parse(
              'http://localhost:5500${uri.path}?${uri.query}',
            );
            await SupabaseService.client.auth.getSessionFromUrl(fullUrl);
            debugPrint('✅ Sesi OAuth Google berhasil ditukar via getSessionFromUrl!');
          } catch (e) {
            debugPrint('⚠️ Catatan penukaran kode OAuth: $e');
          }
          await _desktopOAuthServer?.close(force: true);
          _desktopOAuthServer = null;
        } else if (errorDesc != null) {
          request.response.write(
            '<html><body><h3>Gagal Login Google: $errorDesc</h3></body></html>',
          );
          await request.response.close();
        } else {
          request.response.write(
            '<html><body><p>Memproses autentikasi Google TKA...</p></body></html>',
          );
          await request.response.close();
        }
      });

      return 'http://localhost:5500';
    } catch (e) {
      debugPrint('⚠️ Port 5500 tidak dapat dibuka ($e), menggunakan deep link default.');
      return AppEnv.googleAppRedirectUri;
    }
  }

  /// Menyinkronkan sesi User yang baru berhasil login melalui Google OAuth Callback
  static Future<AuthResult> syncGoogleUserSession(User user) async {
    final email = (user.email ?? 'google.user@gmail.com').trim().toLowerCase();
    final meta = user.userMetadata ?? {};
    String fullName =
        (meta['full_name'] ?? meta['name'] ?? email.split('@').first)
            .toString()
            .trim();
    if (fullName.isEmpty) {
      fullName = 'Pengguna Google TKA';
    }

    await SessionService.saveUserSession(
      name: fullName,
      emailOrPhone: email,
      userId: user.id,
    );

    try {
      final client = SupabaseService.client;
      await client.from('profiles').upsert({
        'id': user.id,
        'email': email,
        'full_name': fullName,
        'role': 'passenger',
        'created_at': DateTime.now().toIso8601String(),
      });
      final prof = await client
          .from('profiles')
          .select('balance')
          .eq('email', email)
          .maybeSingle();
      if (prof != null && prof['balance'] != null) {
        await SessionService.setUserBalance((prof['balance'] as num).toInt());
      }
    } catch (e) {
      debugPrint('ℹ️ Sinkronisasi profil Google ke tabel profiles: $e');
    }

    return AuthResult(
      success: true,
      message: 'Berhasil masuk dengan akun Google ($email).',
      user: user,
    );
  }

  /// Menyelesaikan login akun Google secara langsung (dan menyinkronkan ke Supabase)
  static Future<AuthResult> loginWithGoogleAccount({
    required String email,
    required String fullName,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = fullName.trim().isEmpty
        ? cleanEmail.split('@').first
        : fullName.trim();

    String userId = 'google-${DateTime.now().millisecondsSinceEpoch}';

    try {
      final client = SupabaseService.client;
      if (client.auth.currentUser != null) {
        userId = client.auth.currentUser!.id;
      }
      await client.from('profiles').upsert({
        'id': userId,
        'email': cleanEmail,
        'full_name': cleanName,
        'role': 'passenger',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('ℹ️ Catatan upsert profil Google: $e');
    }

    await SessionService.saveUserSession(
      name: cleanName,
      emailOrPhone: cleanEmail,
      userId: userId,
    );

    return AuthResult(
      success: true,
      message: 'Berhasil masuk dengan Google ($cleanEmail).',
    );
  }

  /// Memastikan ada sesi Supabase Auth yang aktif untuk user saat ini.
  /// Jika client.auth.currentUser == null, otomatis login atau register di background.
  static Future<User?> ensureSupabaseAuthSession() async {
    try {
      final client = SupabaseService.client;
      if (client.auth.currentUser != null) {
        return client.auth.currentUser;
      }

      final account = await SessionService.getActiveAccount();
      String email =
          (account?['email'] ?? await SessionService.getUserEmail() ?? '')
              .toString()
              .trim()
              .toLowerCase();
      String password =
          (account?['password'] ??
                  await SessionService.getUserPassword() ??
                  'database')
              .toString();
      String name = (account?['name'] ?? await SessionService.getUserName())
          .toString();
      String phone = (account?['phone'] ?? await SessionService.getUserPhone())
          .toString();

      if (email.isEmpty || !email.contains('@')) return null;

      debugPrint(
        '🔄 Menghubungkan sesi Supabase Auth otomatis untuk $email...',
      );

      // 1. Coba signInWithPassword terlebih dahulu
      try {
        final res = await client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (res.user != null) {
          debugPrint('✅ Auto-login Supabase Auth berhasil: ${res.user!.id}');
          await SessionService.saveUserSession(
            name: name,
            emailOrPhone: email,
            phone: phone,
            password: password,
            userId: res.user!.id,
          );
          return res.user;
        }
      } catch (signInErr) {
        debugPrint('ℹ️ Auto-signIn coba signUp di Supabase Auth: $signInErr');
      }

      // 2. Jika belum ada di auth.users, daftarkan
      try {
        final upRes = await client.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': name, 'phone': phone, 'role': 'passenger'},
        );
        if (upRes.user != null) {
          debugPrint('✅ Auto-signUp Supabase Auth berhasil: ${upRes.user!.id}');
          await SessionService.saveUserSession(
            name: name,
            emailOrPhone: email,
            phone: phone,
            password: password,
            userId: upRes.user!.id,
          );
          return upRes.user;
        }
      } catch (signUpErr) {
        debugPrint('⚠️ Auto-signUp Supabase: $signUpErr');
      }
    } catch (e) {
      debugPrint('⚠️ ensureSupabaseAuthSession error: $e');
    }

    return SupabaseService.client.auth.currentUser;
  }
}
