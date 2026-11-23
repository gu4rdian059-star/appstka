import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  static const String _keyUserAvatarPrefix = 'tka_user_avatar_';
  static const String _keyUserBirthDate = 'tka_user_birth_date';
  static const String _keyUserGender = 'tka_user_gender';
  static const String _keyUserDocType = 'tka_user_doc_type';

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
    DateTime? birthDate,
    int? gender,
    int? docType,
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
    if (birthDate != null) {
      await prefs.setString(_keyUserBirthDate, birthDate.toIso8601String());
    }
    if (gender != null) {
      await prefs.setInt(_keyUserGender, gender);
    }
    if (docType != null) {
      await prefs.setInt(_keyUserDocType, docType);
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

  /// Ambil Tanggal Lahir user yang aktif
  static Future<DateTime?> getUserBirthDate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyUserBirthDate);
    if (raw != null && raw.isNotEmpty) {
      try {
        return DateTime.parse(raw);
      } catch (_) {}
    }
    return DateTime(1994, 6, 26);
  }

  /// Ambil jenis kelamin user (0: Laki-laki, 1: Perempuan)
  static Future<int> getUserGender() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyUserGender) ?? 0;
  }

  /// Ambil tipe dokumen identitas user (0: KTP/NIK, 1: Paspor)
  static Future<int> getUserDocType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyUserDocType) ?? 0;
  }

  /// Sinkronkan pembaruan data profil pengguna ke tabel 'profiles' di Supabase
  static Future<bool> syncUserProfileToSupabase({
    required String name,
    required String email,
    String? phone,
    String? nik,
    DateTime? birthDate,
    int? gender,
    int? docType,
    String? avatarUrl,
  }) async {
    final cleanEmail = email.toLowerCase().trim();
    if (cleanEmail.isEmpty) return false;

    try {
      final client = SupabaseService.client;
      final currentUserId = client.auth.currentUser?.id ?? await getUserId();

      Map<String, dynamic> updateData = {
        'full_name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (avatarUrl != null &&
            avatarUrl.isNotEmpty &&
            avatarUrl.startsWith('http'))
          'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (nik != null && nik.isNotEmpty) updateData['nik'] = nik;
      if (gender != null) {
        updateData['gender'] = gender == 0 ? 'Laki-laki' : 'Perempuan';
      }
      if (docType != null) {
        updateData['document_type'] = docType == 0 ? 'KTP / NIK' : 'Paspor';
      }
      if (birthDate != null) {
        updateData['birth_date'] = birthDate.toIso8601String().split('T').first;
      }

      debugPrint('🔄 Menyelaraskan profil ke Supabase profiles untuk: $cleanEmail');

      int attempts = 0;
      bool success = false;
      while (updateData.isNotEmpty && attempts < 3) {
        attempts++;
        try {
          // 1. Coba update record yang sudah ada
          final query = client.from('profiles').update(updateData);
          if (currentUserId != null &&
              currentUserId.isNotEmpty &&
              !currentUserId.startsWith('usr-')) {
            await query.eq('id', currentUserId);
          } else {
            await query.eq('email', cleanEmail);
          }

          debugPrint(
            '✅ [Supabase DB] Profil berhasil diperbarui di Supabase: $updateData',
          );
          success = true;
          break;
        } on PostgrestException catch (pe) {
          final msg = pe.message.toLowerCase();
          bool removedAny = false;

          // Tangani PGRST204: Could not find the 'avatar_url' column of 'profiles' in the schema cache
          final pgrstMatch = RegExp(
            r"could not find the '([a-zA-Z0-9_]+)' column",
          ).firstMatch(msg);
          if (pgrstMatch != null) {
            final col = pgrstMatch.group(1);
            if (col != null && updateData.containsKey(col)) {
              debugPrint(
                'ℹ️ Kolom "$col" belum ada di schema profiles Supabase. Melepas kolom tersebut...',
              );
              updateData.remove(col);
              removedAny = true;
            }
          }

          // Tangani 42703: column profiles.xyz does not exist
          final colMatch = RegExp(
            r"column (?:profiles\.)?([a-zA-Z0-9_]+) does not exist",
          ).firstMatch(msg);
          if (colMatch != null) {
            final col = colMatch.group(1);
            if (col != null && updateData.containsKey(col)) {
              debugPrint(
                'ℹ️ Kolom "$col" belum ada di tabel profiles Supabase. Melepas kolom tersebut...',
              );
              updateData.remove(col);
              removedAny = true;
            }
          }

          if (!removedAny) {
            if (updateData.containsKey('avatar_url')) {
              updateData.remove('avatar_url');
            } else if (updateData.containsKey('document_type')) {
              updateData.remove('document_type');
            } else if (updateData.containsKey('birth_date')) {
              updateData.remove('birth_date');
            } else if (updateData.containsKey('gender')) {
              updateData.remove('gender');
            } else if (updateData.containsKey('nik')) {
              updateData.remove('nik');
            } else {
              break;
            }
          }
        } catch (e) {
          debugPrint('Catatan error update profiles: $e');
          break;
        }
      }

      return success;
    } catch (e) {
      debugPrint('Error syncUserProfileToSupabase: $e');
      return false;
    }
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
        // Jika kolom balance belum ada di tabel profiles Supabase, fallback hening ke storage lokal
        final errStr = e.toString();
        if (!errStr.contains('42703') && !errStr.contains('balance does not exist')) {
          debugPrint('Catatan sinkronisasi saldo dari Supabase: $e');
        }
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
        final errStr = e.toString();
        if (!errStr.contains('42703') && !errStr.contains('balance does not exist')) {
          debugPrint('Catatan update saldo di Supabase: $e');
        }
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

  /// Ambil URL avatar profil user yang aktif (dari cache lokal atau tabel profiles di Supabase)
  static Future<String?> getUserAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final email = (await getUserEmail())?.toLowerCase().trim() ?? '';
    if (email.isEmpty) return null;

    final localAvatar = prefs.getString('$_keyUserAvatarPrefix$email');
    if (localAvatar != null && localAvatar.isNotEmpty) {
      return localAvatar;
    }

    // Periksa ke tabel profiles di Supabase jika belum ada di lokal
    try {
      final client = SupabaseService.client;
      final res = await client
          .from('profiles')
          .select('avatar_url')
          .eq('email', email)
          .maybeSingle();
      if (res != null && res['avatar_url'] != null) {
        final url = res['avatar_url'].toString();
        if (url.isNotEmpty) {
          await prefs.setString('$_keyUserAvatarPrefix$email', url);
          return url;
        }
      }
    } catch (e) {
      debugPrint('Catatan ambil avatar dari Supabase: $e');
    }

    return null;
  }

  /// Simpan URL avatar user aktif ke lokal dan sinkronkan ke tabel profiles di Supabase
  static Future<void> setUserAvatar(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final email = (await getUserEmail())?.toLowerCase().trim() ?? '';
    if (email.isNotEmpty) {
      await prefs.setString('$_keyUserAvatarPrefix$email', url);
      try {
        final client = SupabaseService.client;
        await client
            .from('profiles')
            .update({'avatar_url': url})
            .eq('email', email);
        debugPrint(
          '✅ [Supabase Avatar] Avatar URL berhasil diperbarui di Supabase untuk $email: $url',
        );
      } catch (e) {
        debugPrint('Catatan update avatar di Supabase: $e');
      }
    }
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
