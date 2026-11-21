import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

class SessionService {
  static const String _keyRememberMe = 'tka_remember_me';
  static const String _keyIdentifier = 'tka_saved_identifier';
  static const String _keyUserName = 'tka_user_name';
  static const String _keyUserEmail = 'tka_user_email';
  static const String _keyUserPhone = 'tka_user_phone';
  static const String _keyUserNik = 'tka_user_nik';
  static const String _keyUserPassword = 'tka_user_password';
  static const String _keyUserId = 'tka_user_id';
  static const String _keyIsLoggedIn = 'tka_is_logged_in';
  static const String _keyRegisteredUsers = 'tka_registered_users_json';
  static const String _keyUserBalancePrefix = 'tka_user_balance_';
  static const String _keyUserPointsPrefix = 'tka_user_points_';
  static const String _keyUserTierPrefix = 'tka_user_tier_';

  /// Simpan pengaturan "Ingat Saya" dan kredensial identifier
  static Future<void> setRememberMe({
    required bool remember,
    String? identifier,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRememberMe, remember);
    if (remember && identifier != null && identifier.isNotEmpty) {
      await prefs.setString(_keyIdentifier, identifier);
    } else if (!remember) {
      await prefs.remove(_keyIdentifier);
    }
  }

  /// Cek apakah "Ingat Saya" aktif
  static Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRememberMe) ?? true;
  }

  /// Ambil identifier (email / no HP) yang tersimpan
  static Future<String?> getSavedIdentifier() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyIdentifier);
  }

  /// Simpan sesi login user aktif
  static Future<void> saveUserSession({
    required String name,
    required String emailOrPhone,
    String? phone,
    String? nik,
    String? password,
    String? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
    if (emailOrPhone.isNotEmpty) {
      await prefs.setString(_keyUserEmail, emailOrPhone);
    }
    if (phone != null && phone.isNotEmpty) {
      await prefs.setString(_keyUserPhone, phone);
    }
    if (nik != null && nik.isNotEmpty) {
      await prefs.setString(_keyUserNik, nik);
    }
    if (password != null && password.isNotEmpty) {
      await prefs.setString(_keyUserPassword, password);
    }
    if (userId != null && userId.isNotEmpty) {
      await prefs.setString(_keyUserId, userId);
    }
    await prefs.setBool(_keyIsLoggedIn, true);
  }

  /// Ambil password user yang aktif tersimpan
  static Future<String?> getUserPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserPassword);
  }

  /// Ambil ID unik user (UUID Supabase atau ID lokal)
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  /// Ambil data akun yang sedang aktif dari registrasi
  static Future<Map<String, dynamic>?> getActiveAccount() async {
    final email = await getUserEmail();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyRegisteredUsers);
    if (raw == null) return null;
    try {
      final users = Map<String, dynamic>.from(jsonDecode(raw));
      if (email != null && email.isNotEmpty) {
        final user = users[email.trim().toLowerCase()];
        if (user != null && user is Map) {
          return Map<String, dynamic>.from(user);
        }
      }
      if (users.isNotEmpty) {
        final firstKey = users.keys.first;
        return Map<String, dynamic>.from(users[firstKey]);
      }
    } catch (_) {}
    return null;
  }

  /// Ambil nama user untuk ditampilkan di greeting dashboard dan pemesanan tiket
  static Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_keyUserName);
    if (name != null && name.trim().isNotEmpty) {
      return name;
    }
    return 'Pengguna TKA';
  }

  /// Ambil email / nomor telepon user yang aktif
  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail);
  }

  /// Ambil nomor telepon user yang aktif
  static Future<String> getUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserPhone) ?? '+62 812-3456-7890';
  }

  /// Ambil NIK user yang aktif
  static Future<String> getUserNik() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserNik) ?? '3514062607090001';
  }

  /// Ambil saldo TKAPay user aktif (User baru = 0, demo Samuel = 250000, sinkron ke Supabase)
  static Future<int> getUserBalance() async {
    final prefs = await SharedPreferences.getInstance();
    final email = (await getUserEmail())?.toLowerCase().trim() ?? '';
    final name = (await getUserName()).toLowerCase().trim();
    final isDemoSamuel = email == 'kocak@co.id' || name == 'samuel';
    final key = '$_keyUserBalancePrefix$email';

    int? localBal = prefs.getInt(key);

    // Jika belum ada atau bernilai 0 dan ada email, periksa ke database Supabase
    if ((localBal == null || localBal == 0) && email.isNotEmpty) {
      try {
        final client = SupabaseService.client;
        final res = await client
            .from('profiles')
            .select('balance')
            .eq('email', email)
            .maybeSingle();
        if (res != null && res['balance'] != null) {
          final dbBal = (res['balance'] as num).toInt();
          if (dbBal > 0) {
            await prefs.setInt(key, dbBal);
            return dbBal;
          }
        }
      } catch (e) {
        debugPrint('Catatan sinkronisasi saldo dari Supabase: $e');
      }
    }

    if (localBal == null) {
      final defaultBalance = isDemoSamuel ? 250000 : 0;
      await prefs.setInt(key, defaultBalance);
      return defaultBalance;
    }
    return localBal;
  }

  /// Update saldo TKAPay user aktif (disimpan ke lokal dan disinkronkan ke Supabase)
  static Future<void> setUserBalance(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final email = (await getUserEmail())?.toLowerCase().trim() ?? '';
    if (email.isNotEmpty) {
      await prefs.setInt('$_keyUserBalancePrefix$email', amount);
      // Sinkronkan ke tabel profiles di Supabase jika terhubung
      try {
        final client = SupabaseService.client;
        await client
            .from('profiles')
            .update({'balance': amount})
            .eq('email', email);
        debugPrint(
          '✅ [Supabase Balance] Saldo Rp$amount berhasil diperbarui di Supabase untuk $email',
        );
      } catch (e) {
        debugPrint('Catatan update saldo di Supabase: $e');
      }
    }
  }

  /// Ambil TKA Poin user aktif (User baru = 0, demo Samuel = 1450)
  static Future<int> getUserPoints() async {
    final prefs = await SharedPreferences.getInstance();
    final email = (await getUserEmail())?.toLowerCase().trim() ?? '';
    final name = (await getUserName()).toLowerCase().trim();
    final isDemoSamuel = email == 'kocak@co.id' || name == 'samuel';
    final key = '$_keyUserPointsPrefix$email';
    if (!prefs.containsKey(key)) {
      final defaultPoints = isDemoSamuel ? 1450 : 0;
      await prefs.setInt(key, defaultPoints);
      return defaultPoints;
    }
    return prefs.getInt(key) ?? (isDemoSamuel ? 1450 : 0);
  }

  /// Update TKA Poin user aktif
  static Future<void> setUserPoints(int points) async {
    final prefs = await SharedPreferences.getInstance();
    final email = (await getUserEmail())?.toLowerCase().trim() ?? '';
    await prefs.setInt('$_keyUserPointsPrefix$email', points);
  }

  /// Ambil status membership (User baru = Member Baru, demo Samuel = Member Gold)
  static Future<String> getUserTier() async {
    final prefs = await SharedPreferences.getInstance();
    final email = (await getUserEmail())?.toLowerCase().trim() ?? '';
    final name = (await getUserName()).toLowerCase().trim();
    final isDemoSamuel = email == 'kocak@co.id' || name == 'samuel';
    final key = '$_keyUserTierPrefix$email';
    if (!prefs.containsKey(key)) {
      final defaultTier = isDemoSamuel ? 'Member Gold' : 'Member Baru';
      await prefs.setString(key, defaultTier);
      return defaultTier;
    }
    return prefs.getString(key) ??
        (isDemoSamuel ? 'Member Gold' : 'Member Baru');
  }

  /// Simpan kredensial akun terdaftar untuk fallback login instan
  static Future<void> saveRegisteredAccount({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyRegisteredUsers);
    Map<String, dynamic> users = {};
    if (raw != null) {
      try {
        users = Map<String, dynamic>.from(jsonDecode(raw));
      } catch (_) {}
    }
    final cleanEmail = email.toLowerCase().trim();
    final cleanPhone = phone.trim();
    final record = {
      'name': name.trim(),
      'email': cleanEmail,
      'phone': cleanPhone,
      'password': password,
    };
    users[cleanEmail] = record;
    if (cleanPhone.isNotEmpty) {
      users[cleanPhone] = record;
    }
    await prefs.setString(_keyRegisteredUsers, jsonEncode(users));
  }

  /// Validasi kredensial login dari akun lokal yang terdaftar
  static Future<Map<String, dynamic>?> getRegisteredAccount({
    required String identifier,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyRegisteredUsers);
    if (raw == null) return null;
    try {
      final users = Map<String, dynamic>.from(jsonDecode(raw));
      final cleanId = identifier.trim().toLowerCase();
      final user = users[cleanId];
      if (user != null && user is Map && user['password'] == password) {
        return Map<String, dynamic>.from(user);
      }
    } catch (_) {}
    return null;
  }

  /// Hapus sesi login aktif (Logout tanpa menghapus saldo atau akun tersimpan)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_keyRememberMe) ?? false;
    final savedId = prefs.getString(_keyIdentifier);

    // Hapus hanya sesi kredensial login aktif pengguna
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserPhone);
    await prefs.remove(_keyUserNik);
    await prefs.remove(_keyUserPassword);
    await prefs.remove(_keyUserId);
    await prefs.setBool(_keyIsLoggedIn, false);

    // Pertahankan preferensi Ingat Saya jika sebelumnya dicentang
    if (remember && savedId != null) {
      await prefs.setBool(_keyRememberMe, true);
      await prefs.setString(_keyIdentifier, savedId);
    }
  }
}
