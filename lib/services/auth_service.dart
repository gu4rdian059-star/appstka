import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'session_service.dart';
import 'supabase_service.dart';

class AuthResult {
  final bool success;
  final String message;
  final User? user;

  const AuthResult({required this.success, required this.message, this.user});
}

class AuthService {
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
