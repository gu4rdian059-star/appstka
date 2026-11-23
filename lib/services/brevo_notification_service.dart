import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_env.dart';
import '../models/tracking_models.dart';
import 'indonesia_time_service.dart';
import 'session_service.dart';
import 'supabase_service.dart';

class NotificationDispatchResult {
  final bool sent;
  final bool isDuplicate;
  final String brevoStatus;
  final String message;
  final TrainNotificationModel? notification;

  const NotificationDispatchResult({
    required this.sent,
    required this.isDuplicate,
    required this.brevoStatus,
    required this.message,
    this.notification,
  });
}

/// Service Notifikasi Kereta dengan Brevo Transactional API + Deduplikasi Ketat.
///
/// Menjamin:
/// 1. Tidak pernah mengirim notifikasi duplikat untuk kejadian (`eventDedupKey`) yang sama.
/// 2. Mencatat riwayat notifikasi ke tabel Supabase `train_notifications` + cache lokal.
/// 3. Mengirim email transaksi melalui Brevo API (lewat Supabase Edge Function jika tersedia,
///    atau langsung ke `https://api.brevo.com/v3/smtp/email` menggunakan `BREVO_API_KEY` dari `.env`).
class BrevoNotificationService {
  static const String _prefNotifListPrefix = 'tka_train_notifs_';
  static const String _prefDedupSetPrefix = 'tka_notif_dedup_keys_';

  /// Bangun kunci deduplikasi deterministik berdasarkan tipe kejadian, ID trip, dan pembeda kejadian.
  /// Contoh: `TRAIN_DELAY:TRIP-KA40-AP:DELAY_18M_20261120`
  static String buildDedupKey({
    required TrainNotificationEventType eventType,
    required String tripId,
    required String incidentCode,
  }) {
    final cleanTrip = tripId.trim().toUpperCase();
    final cleanCode = incidentCode
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9_-]'), '_');
    return '${eventType.code}:$cleanTrip:$cleanCode';
  }

  static Future<String> _resolveUserId() async {
    try {
      if (SupabaseService.isInitialized) {
        final authUser = SupabaseService.client.auth.currentUser;
        if (authUser != null && authUser.id.isNotEmpty) {
          return authUser.id;
        }
      }
    } catch (_) {}
    final savedId = await SessionService.getUserId();
    if (savedId != null && savedId.isNotEmpty) return savedId;
    final email = await SessionService.getUserEmail();
    if (email != null && email.isNotEmpty) return 'local_${email.toLowerCase()}';
    return 'guest_device';
  }

  static Future<String?> _resolveUserEmail() async {
    try {
      if (SupabaseService.isInitialized) {
        final authEmail = SupabaseService.client.auth.currentUser?.email;
        if (authEmail != null && authEmail.contains('@')) return authEmail;
      }
    } catch (_) {}
    final saved = await SessionService.getUserEmail();
    if (saved != null && saved.contains('@')) return saved;
    return null;
  }

  /// Ambil daftar notifikasi user dari Supabase (fallback ke cache lokal jika offline / tabel belum dimigrasi).
  static Future<List<TrainNotificationModel>> getNotifications() async {
    final userId = await _resolveUserId();
    final localList = await _loadLocalNotifications(userId);

    if (SupabaseService.isInitialized) {
      try {
        final rows = await SupabaseService.client
            .from('train_notifications')
            .select('*')
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(80);

        final remote = rows
            .map((e) => TrainNotificationModel.fromMap(Map<String, dynamic>.from(e)))
            .toList();

        // Gabungkan remote + lokal unik berdasarkan eventDedupKey
        final Map<String, TrainNotificationModel> merged = {};
        for (final item in localList) {
          merged[item.eventDedupKey] = item;
        }
        for (final item in remote) {
          merged[item.eventDedupKey] = item;
        }

        final combined = merged.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        await _saveLocalNotifications(userId, combined);
        return combined;
      } catch (e) {
        debugPrint('Catatan ambil train_notifications Supabase: $e');
      }
    }

    return localList;
  }

  /// Kirim notifikasi perjalanan dengan jaminan ANTI-DUPLIKASI + Brevo Email Dispatch.
  static Future<NotificationDispatchResult> dispatchNotification({
    required TrainNotificationEventType eventType,
    required String tripId,
    required String incidentCode,
    required String title,
    required String message,
    String? trainNumber,
    String? trainName,
    String? overrideRecipientEmail,
    bool sendEmail = true,
  }) async {
    final userId = await _resolveUserId();
    final recipientEmail =
        (overrideRecipientEmail != null && overrideRecipientEmail.contains('@'))
            ? overrideRecipientEmail.trim()
            : await _resolveUserEmail();
    final recipientName = await SessionService.getUserName();

    final dedupKey = buildDedupKey(
      eventType: eventType,
      tripId: tripId,
      incidentCode: incidentCode,
    );

    // 1. CEK DEDUPLIKASI LOKAL
    final localDedupKeys = await _loadLocalDedupKeys(userId);
    if (localDedupKeys.contains(dedupKey)) {
      return NotificationDispatchResult(
        sent: false,
        isDuplicate: true,
        brevoStatus: 'SKIPPED',
        message:
            'Duplikat dicegah! Notifikasi untuk kejadian ($dedupKey) sudah pernah dikirim.',
      );
    }

    // 2. CEK & SIMPAN KE SUPABASE (ATOMIC UNIQUE CONSTRAINT ON (user_id, event_dedup_key))
    String notificationId = 'notif-${DateTime.now().millisecondsSinceEpoch}';
    if (SupabaseService.isInitialized) {
      try {
        final existing = await SupabaseService.client
            .from('train_notifications')
            .select('id')
            .eq('user_id', userId)
            .eq('event_dedup_key', dedupKey)
            .maybeSingle();

        if (existing != null) {
          localDedupKeys.add(dedupKey);
          await _saveLocalDedupKeys(userId, localDedupKeys);
          return NotificationDispatchResult(
            sent: false,
            isDuplicate: true,
            brevoStatus: 'SKIPPED',
            message:
                'Duplikat dicegah (Database)! Kejadian ($dedupKey) sudah tercatat sebelumnya.',
          );
        }

        final inserted = await SupabaseService.client
            .from('train_notifications')
            .insert({
              'user_id': userId,
              'recipient_email': recipientEmail,
              'trip_id': tripId,
              'train_number': trainNumber,
              'train_name': trainName,
              'event_type': eventType.code,
              'event_dedup_key': dedupKey,
              'title': title,
              'message': message,
              'is_read': false,
              'brevo_status':
                  (sendEmail && recipientEmail != null) ? 'PENDING' : 'SKIPPED',
            })
            .select('id')
            .single();

        notificationId = inserted['id'].toString();
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('23505') || errStr.contains('duplicate')) {
          localDedupKeys.add(dedupKey);
          await _saveLocalDedupKeys(userId, localDedupKeys);
          return NotificationDispatchResult(
            sent: false,
            isDuplicate: true,
            brevoStatus: 'SKIPPED',
            message:
                'Duplikat dicegah oleh constraint UNIQUE PostgreSQL ($dedupKey).',
          );
        }
        debugPrint('Catatan insert train_notifications Supabase: $e');
      }
    }

    // Catat kunci deduplikasi di cache lokal segera agar panggilan beruntun tidak lolos
    localDedupKeys.add(dedupKey);
    await _saveLocalDedupKeys(userId, localDedupKeys);

    // 3. KIRIM EMAIL VIA BREVO (jika aktif & ada email penerima)
    String brevoStatus = 'SKIPPED';
    String? brevoMessageId;
    String? brevoError;

    if (sendEmail && recipientEmail != null && recipientEmail.contains('@')) {
      final emailResult = await _sendViaBrevo(
        recipientEmail: recipientEmail,
        recipientName: recipientName,
        eventType: eventType,
        title: title,
        message: message,
        trainName: trainName,
        trainNumber: trainNumber,
        dedupKey: dedupKey,
      );
      brevoStatus = emailResult.status;
      brevoMessageId = emailResult.messageId;
      brevoError = emailResult.error;

      // Update status Brevo di Supabase jika tersedia
      if (SupabaseService.isInitialized && !notificationId.startsWith('notif-')) {
        try {
          await SupabaseService.client
              .from('train_notifications')
              .update({
                'brevo_status': brevoStatus,
                'brevo_message_id': brevoMessageId,
                'brevo_error': brevoError,
              })
              .eq('id', notificationId);
        } catch (_) {}
      }
    }

    final model = TrainNotificationModel(
      id: notificationId,
      userId: userId,
      recipientEmail: recipientEmail,
      tripId: tripId,
      trainNumber: trainNumber,
      trainName: trainName,
      eventType: eventType,
      eventDedupKey: dedupKey,
      title: title,
      message: message,
      isRead: false,
      brevoStatus: brevoStatus,
      brevoMessageId: brevoMessageId,
      brevoError: brevoError,
      createdAt: DateTime.now().toUtc(),
    );

    final currentList = await _loadLocalNotifications(userId);
    currentList.insert(0, model);
    await _saveLocalNotifications(userId, currentList);

    final summaryMsg = brevoStatus == 'SENT'
        ? 'Notifikasi tersimpan & email Brevo berhasil dikirim ke $recipientEmail.'
        : brevoStatus == 'FAILED'
            ? 'Notifikasi in-app tersimpan. Pengiriman email Brevo gagal: ${brevoError ?? "periksa pengirim/CORS"}.'
            : 'Notifikasi in-app berhasil disimpan (email dilewati).';

    return NotificationDispatchResult(
      sent: true,
      isDuplicate: false,
      brevoStatus: brevoStatus,
      message: summaryMsg,
      notification: model,
    );
  }

  /// Kirim email transaksi menggunakan Brevo API v3 (`/v3/smtp/email`).
  static Future<({String status, String? messageId, String? error})>
      _sendViaBrevo({
    required String recipientEmail,
    required String recipientName,
    required TrainNotificationEventType eventType,
    required String title,
    required String message,
    String? trainName,
    String? trainNumber,
    required String dedupKey,
  }) async {
    final apiKey = AppEnv.brevoApiKey;
    if (apiKey.isEmpty) {
      return (
        status: 'SKIPPED',
        messageId: null,
        error: 'BREVO_API_KEY belum diatur di .env',
      );
    }

    final timestampWib = IndonesiaTimeService.formatDateTime(
      DateTime.now().toUtc(),
      withSeconds: true,
    );

    final htmlBody = '''
<div style="font-family:Segoe UI,Arial,sans-serif;max-width:560px;margin:0 auto;border:1px solid #e2e8f0;border-radius:14px;overflow:hidden;">
  <div style="background:#062056;color:#ffffff;padding:18px 24px;">
    <div style="font-size:11px;letter-spacing:1px;opacity:0.85;text-transform:uppercase;">${eventType.label}</div>
    <h2 style="margin:6px 0 0;font-size:18px;">TKA Rail Live Tracking</h2>
  </div>
  <div style="padding:20px 24px;color:#1e293b;background:#ffffff;">
    <h3 style="margin:0 0 10px;color:#062056;font-size:16px;">$title</h3>
    <p style="margin:0 0 16px;line-height:1.6;font-size:14px;">$message</p>
    ${trainName != null ? '<div style="background:#f8fafc;border-left:4px solid #F26716;padding:12px 14px;border-radius:6px;font-size:13px;margin-bottom:14px;"><strong>Kereta:</strong> $trainName (${trainNumber ?? "-"})<br/><strong>Waktu Indonesia:</strong> $timestampWib</div>' : ''}
    <div style="font-size:11px;color:#64748b;border-top:1px solid #f1f5f9;padding-top:12px;">
      Notifikasi ini dikirim otomatis melalui Brevo untuk layanan TKA Mobile.<br/>
      ID Kejadian (Anti-Duplikat): <code>$dedupKey</code>
    </div>
  </div>
</div>
''';

    try {
      final resp = await http
          .post(
            Uri.parse('https://api.brevo.com/v3/smtp/email'),
            headers: {
              'accept': 'application/json',
              'content-type': 'application/json',
              'api-key': apiKey,
            },
            body: jsonEncode({
              'sender': {
                'name': AppEnv.brevoSenderName,
                'email': AppEnv.brevoSenderEmail,
              },
              'to': [
                {
                  'email': recipientEmail,
                  'name': recipientName,
                }
              ],
              'subject': '[TKA ${eventType.shortTag}] $title',
              'htmlContent': htmlBody,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decoded = jsonDecode(resp.body);
        return (
          status: 'SENT',
          messageId: decoded['messageId']?.toString(),
          error: null,
        );
      }

      return (
        status: 'FAILED',
        messageId: null,
        error: 'HTTP ${resp.statusCode}: ${resp.body}',
      );
    } catch (e) {
      return (
        status: 'FAILED',
        messageId: null,
        error: e.toString(),
      );
    }
  }

  /// Tandai satu notifikasi telah dibaca.
  static Future<void> markAsRead(String notificationId) async {
    final userId = await _resolveUserId();
    final list = await _loadLocalNotifications(userId);
    final updated = list
        .map((n) => n.id == notificationId ? n.copyWith(isRead: true) : n)
        .toList();
    await _saveLocalNotifications(userId, updated);

    if (SupabaseService.isInitialized && !notificationId.startsWith('notif-')) {
      try {
        await SupabaseService.client
            .from('train_notifications')
            .update({'is_read': true})
            .eq('id', notificationId);
      } catch (_) {}
    }
  }

  /// Tandai semua notifikasi sebagai sudah dibaca.
  static Future<void> markAllAsRead() async {
    final userId = await _resolveUserId();
    final list = await _loadLocalNotifications(userId);
    final updated = list.map((n) => n.copyWith(isRead: true)).toList();
    await _saveLocalNotifications(userId, updated);

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.client
            .from('train_notifications')
            .update({'is_read': true})
            .eq('user_id', userId);
      } catch (_) {}
    }
  }

  /// Seed notifikasi contoh awal jika belum ada notifikasi sama sekali agar inbox langsung informatif.
  static Future<void> ensureInitialSeedIfEmpty() async {
    final userId = await _resolveUserId();
    final existing = await _loadLocalNotifications(userId);
    if (existing.isNotEmpty) return;

    final now = DateTime.now().toUtc();
    final seed = [
      TrainNotificationModel(
        id: 'seed-delay-ka40',
        userId: userId,
        tripId: 'TRIP-KA40-AP',
        trainNumber: 'KA 40',
        trainName: 'KA Argo Parahyangan',
        eventType: TrainNotificationEventType.trainDelay,
        eventDedupKey: 'TRAIN_DELAY:TRIP-KA40-AP:SEED_18M',
        title: 'KA 40 Argo Parahyangan Terlambat 18 Menit',
        message:
            'Terjadi antrean persilangan jalur tunggal di lintas Purwakarta - Cimahi. Estimasi tiba di Bandung diperbarui menjadi +18 menit.',
        isRead: false,
        brevoStatus: 'SKIPPED',
        createdAt: now.subtract(const Duration(minutes: 14)),
      ),
      TrainNotificationModel(
        id: 'seed-arrival-ka2',
        userId: userId,
        tripId: 'TRIP-KA2-ABA',
        trainNumber: 'KA 2',
        trainName: 'KA Argo Bromo Anggrek',
        eventType: TrainNotificationEventType.arrivalInfo,
        eventDedupKey: 'ARRIVAL_INFO:TRIP-KA2-ABA:SEED_PK',
        title: 'Informasi Kedatangan Stasiun Pekalongan',
        message:
            'KA 2 Argo Bromo Anggrek dijadwalkan memasuki Stasiun Pekalongan (PK) pada Jalur 2.',
        isRead: false,
        brevoStatus: 'SKIPPED',
        createdAt: now.subtract(const Duration(minutes: 42)),
      ),
      TrainNotificationModel(
        id: 'seed-status-ars12',
        userId: userId,
        tripId: 'TRIP-KA-ARS12',
        trainNumber: 'KA U12',
        trainName: 'KA Bandara Kualanamu (Srilelawangsa)',
        eventType: TrainNotificationEventType.tripStatusChange,
        eventDedupKey: 'TRIP_STATUS_CHANGE:TRIP-KA-ARS12:SEED_UNAVAILABLE',
        title: 'Telemetri Posisi KA U12 Tidak Tersedia',
        message:
            'Status data posisi KA U12 berubah menjadi UNAVAILABLE karena sinyal GPS tidak terdeteksi.',
        isRead: true,
        brevoStatus: 'SKIPPED',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
    ];

    await _saveLocalNotifications(userId, seed);
    final dedup = await _loadLocalDedupKeys(userId);
    for (final s in seed) {
      dedup.add(s.eventDedupKey);
    }
    await _saveLocalDedupKeys(userId, dedup);
  }

  static Future<List<TrainNotificationModel>> _loadLocalNotifications(
      String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefNotifListPrefix$userId');
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => TrainNotificationModel.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveLocalNotifications(
    String userId,
    List<TrainNotificationModel> items,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trimmed = items.take(100).map((e) => e.toMap()).toList();
      await prefs.setString('$_prefNotifListPrefix$userId', jsonEncode(trimmed));
    } catch (_) {}
  }

  static Future<Set<String>> _loadLocalDedupKeys(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('$_prefDedupSetPrefix$userId');
      return list != null ? list.toSet() : <String>{};
    } catch (_) {
      return <String>{};
    }
  }

  static Future<void> _saveLocalDedupKeys(String userId, Set<String> keys) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('$_prefDedupSetPrefix$userId', keys.toList());
    } catch (_) {}
  }
}

