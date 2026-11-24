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

  // ================= TRANSACTIONAL EMAIL DISPATCH METHODS =================

  /// Kirim email kustom langsung via Brevo Transactional API v3 (`/v3/smtp/email`).
  static Future<({bool success, String? messageId, String? error})>
      sendCustomEmail({
    required String recipientEmail,
    String? recipientName,
    required String subject,
    required String htmlContent,
  }) async {
    final apiKey = AppEnv.brevoApiKey;
    if (apiKey.isEmpty) {
      debugPrint('⚠️ [Brevo] BREVO_API_KEY belum dikonfigurasi di file .env.');
      return (
        success: false,
        messageId: null,
        error: 'BREVO_API_KEY belum dikonfigurasi di file .env',
      );
    }

    final cleanRecipient = recipientEmail.trim();
    if (!cleanRecipient.contains('@')) {
      return (
        success: false,
        messageId: null,
        error: 'Format email penerima tidak valid ($cleanRecipient)',
      );
    }

    final targetName = (recipientName != null && recipientName.trim().isNotEmpty)
        ? recipientName.trim()
        : cleanRecipient.split('@').first;

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
                  'email': cleanRecipient,
                  'name': targetName,
                }
              ],
              'subject': subject,
              'htmlContent': htmlContent,
            }),
          )
          .timeout(const Duration(seconds: 14));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decoded = jsonDecode(resp.body);
        final msgId = decoded['messageId']?.toString();
        debugPrint(
          '✅ [Brevo API] Email "$subject" berhasil terkirim ke $cleanRecipient (ID: $msgId)',
        );
        return (success: true, messageId: msgId, error: null);
      }

      final errorMsg = 'HTTP ${resp.statusCode}: ${resp.body}';
      debugPrint('❌ [Brevo API Error] $errorMsg');
      return (success: false, messageId: null, error: errorMsg);
    } catch (e) {
      debugPrint('❌ [Brevo API Exception] $e');
      return (success: false, messageId: null, error: e.toString());
    }
  }

  /// Kirim Kode OTP Pemulihan Kata Sandi via Brevo API v3
  static Future<({bool success, String? messageId, String? error})>
      sendPasswordResetOtpEmail({
    required String recipientEmail,
    required String otpCode,
    String? userName,
  }) async {
    final name = (userName != null && userName.trim().isNotEmpty)
        ? userName.trim()
        : 'Pelanggan TKA';
    final timestampWib = IndonesiaTimeService.formatDateTime(
      DateTime.now().toUtc(),
      withSeconds: true,
    );

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Reset Kata Sandi TKA</title>
</head>
<body style="margin:0;padding:24px 12px;background:#f8fafc;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <div style="max-width:540px;margin:0 auto;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.06);border:1px solid #e2e8f0;">
    <div style="background:#062056;padding:28px 24px;text-align:center;">
      <div style="display:inline-block;background:#F26716;color:#ffffff;font-size:12px;font-weight:bold;letter-spacing:1.5px;padding:4px 12px;border-radius:20px;text-transform:uppercase;margin-bottom:12px;">
        Keamanan Akun TKA
      </div>
      <h1 style="color:#ffffff;font-size:22px;margin:0;font-weight:800;">Pemulihan Kata Sandi</h1>
      <p style="color:#94a3b8;font-size:13px;margin:6px 0 0;">Layanan Tiket Kereta Api Indonesia</p>
    </div>
    <div style="padding:28px 24px;color:#1e293b;">
      <p style="font-size:14px;line-height:1.6;margin:0 0 16px;">
        Halo <strong>$name</strong>,
      </p>
      <p style="font-size:14px;line-height:1.6;margin:0 0 20px;">
        Kami menerima permintaan untuk mengatur ulang kata sandi akun TKA Anda. Gunakan kode verifikasi (OTP) berikut untuk melanjutkan proses reset password di aplikasi:
      </p>
      <div style="background:#f1f5f9;border:2px dashed #cbd5e1;border-radius:12px;padding:20px;text-align:center;margin:24px 0;">
        <div style="font-size:11px;color:#64748b;font-weight:bold;text-transform:uppercase;letter-spacing:1px;margin-bottom:8px;">
          Kode Verifikasi (OTP)
        </div>
        <div style="font-size:36px;font-weight:900;letter-spacing:10px;color:#062056;font-family:'Courier New',Courier,monospace;">
          $otpCode
        </div>
        <div style="font-size:12px;color:#ef4444;font-weight:600;margin-top:10px;">
          ⏱ Berlaku selama 15 menit
        </div>
      </div>
      <div style="background:#fff7ed;border-left:4px solid #f97316;padding:12px 16px;border-radius:6px;margin-bottom:20px;">
        <p style="font-size:12.5px;color:#9a3412;margin:0;line-height:1.5;">
          <strong>PENTING:</strong> Jangan berikan kode ini kepada siapa pun, termasuk pihak yang mengatasnamakan TKA Rail. Jika Anda tidak merasa melakukan permintaan ini, abaikan email ini dan amankan akun Anda.
        </p>
      </div>
      <div style="font-size:11.5px;color:#94a3b8;line-height:1.5;border-top:1px solid #f1f5f9;padding-top:16px;">
        Waktu Permintaan: <strong>$timestampWib</strong><br/>
        Email Penerima: <strong>$recipientEmail</strong>
      </div>
    </div>
    <div style="background:#f8fafc;padding:16px 24px;text-align:center;border-top:1px solid #e2e8f0;">
      <p style="font-size:11px;color:#64748b;margin:0;">
        © 2026 TKA Rail Mobile • PT Kereta Api Indonesia (Persero)<br/>
        Email transaksi ini dikirim otomatis melalui Brevo.
      </p>
    </div>
  </div>
</body>
</html>
''';

    return sendCustomEmail(
      recipientEmail: recipientEmail,
      recipientName: userName,
      subject: '[TKA Rail] $otpCode adalah Kode Verifikasi Reset Password Anda',
      htmlContent: htmlContent,
    );
  }

  /// Kirim Tiket Konfirmasi / E-Ticket Resmi via Brevo
  static Future<({bool success, String? messageId, String? error})>
      sendTicketConfirmationEmail({
    required String recipientEmail,
    required String bookingCode,
    required String trainName,
    required String trainClass,
    required String originStation,
    required String destStation,
    required String travelDate,
    required String departureTime,
    required String arrivalTime,
    required String passengerName,
    required String seatNumber,
    required int totalAmount,
    String? paymentMethod,
  }) async {
    final timestampWib = IndonesiaTimeService.formatDateTime(
      DateTime.now().toUtc(),
      withSeconds: true,
    );
    final formattedPrice =
        'Rp ${totalAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>E-Ticket Resmi TKA Rail</title>
</head>
<body style="margin:0;padding:24px 12px;background:#f8fafc;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <div style="max-width:560px;margin:0 auto;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.06);border:1px solid #e2e8f0;">
    <div style="background:#062056;padding:26px 24px;color:#ffffff;">
      <table style="width:100%;border-collapse:collapse;">
        <tr>
          <td>
            <span style="background:#16a34a;color:#ffffff;font-size:11px;font-weight:bold;letter-spacing:1px;padding:3px 10px;border-radius:12px;text-transform:uppercase;">
              LUNAS / TERKONFIRMASI
            </span>
            <h1 style="color:#ffffff;font-size:20px;margin:8px 0 0;font-weight:800;">E-Ticket Resmi TKA Rail</h1>
          </td>
          <td style="text-align:right;">
            <div style="font-size:11px;color:#94a3b8;text-transform:uppercase;">Kode Booking</div>
            <div style="font-size:18px;font-weight:900;color:#F26716;letter-spacing:1px;">$bookingCode</div>
          </td>
        </tr>
      </table>
    </div>
    <div style="padding:24px;color:#1e293b;">
      <div style="background:#f1f5f9;border-radius:12px;padding:16px;margin-bottom:20px;">
        <div style="font-size:15px;font-weight:bold;color:#062056;margin-bottom:4px;">
          $trainName <span style="font-size:12px;font-weight:normal;color:#64748b;">($trainClass)</span>
        </div>
        <div style="font-size:12.5px;color:#64748b;margin-bottom:12px;">Tanggal Keberangkatan: <strong>$travelDate</strong></div>
        <table style="width:100%;border-collapse:collapse;font-size:13px;">
          <tr>
            <td style="width:45%;vertical-align:top;">
              <div style="font-size:11px;color:#94a3b8;">BERANGKAT</div>
              <div style="font-size:16px;font-weight:bold;color:#062056;">$departureTime</div>
              <div style="font-weight:600;color:#1e293b;">$originStation</div>
            </td>
            <td style="width:10%;text-align:center;font-size:18px;color:#F26716;">➔</td>
            <td style="width:45%;vertical-align:top;text-align:right;">
              <div style="font-size:11px;color:#94a3b8;">TIBA</div>
              <div style="font-size:16px;font-weight:bold;color:#062056;">$arrivalTime</div>
              <div style="font-weight:600;color:#1e293b;">$destStation</div>
            </td>
          </tr>
        </table>
      </div>
      <table style="width:100%;border-collapse:collapse;font-size:13px;margin-bottom:20px;border-bottom:1px solid #f1f5f9;padding-bottom:12px;">
        <tr>
          <td style="padding:6px 0;color:#64748b;">Nama Penumpang</td>
          <td style="padding:6px 0;text-align:right;font-weight:bold;color:#062056;">$passengerName</td>
        </tr>
        <tr>
          <td style="padding:6px 0;color:#64748b;">Nomor Kursi</td>
          <td style="padding:6px 0;text-align:right;font-weight:bold;color:#F26716;">$seatNumber</td>
        </tr>
        <tr>
          <td style="padding:6px 0;color:#64748b;">Metode Pembayaran</td>
          <td style="padding:6px 0;text-align:right;font-weight:600;color:#1e293b;">${paymentMethod ?? 'Online Payment'}</td>
        </tr>
        <tr>
          <td style="padding:8px 0;color:#062056;font-size:14px;font-weight:bold;">Total Pembayaran</td>
          <td style="padding:8px 0;text-align:right;font-size:16px;font-weight:900;color:#16a34a;">$formattedPrice</td>
        </tr>
      </table>
      <div style="background:#eff6ff;border-left:4px solid #3b82f6;padding:12px 14px;border-radius:6px;font-size:12px;color:#1e40af;line-height:1.5;">
        <strong>Petunjuk Boarding:</strong> Tunjukkan E-Ticket ini beserta kartu identitas resmi saat boarding di stasiun keberangkatan minimal 30 menit sebelum jadwal.
      </div>
    </div>
    <div style="background:#f8fafc;padding:16px 24px;text-align:center;border-top:1px solid #e2e8f0;font-size:11px;color:#64748b;">
      Diterbitkan otomatis oleh TKA Rail Ticketing System pada $timestampWib.<br/>
      ID Booking: <code>$bookingCode</code> • Dukungan: support@tka-rail.id
    </div>
  </div>
</body>
</html>
''';

    return sendCustomEmail(
      recipientEmail: recipientEmail,
      recipientName: passengerName,
      subject:
          '[TKA Rail] E-Ticket Berhasil Diterbitkan ($bookingCode) - $trainName',
      htmlContent: htmlContent,
    );
  }

  /// Kirim Notifikasi Pembatalan Tiket & Pengajuan Refund via Brevo
  static Future<({bool success, String? messageId, String? error})>
      sendRefundConfirmationEmail({
    required String recipientEmail,
    required String bookingCode,
    required String trainName,
    required int refundAmount,
    required String reason,
    String? passengerName,
  }) async {
    final timestampWib = IndonesiaTimeService.formatDateTime(
      DateTime.now().toUtc(),
      withSeconds: true,
    );
    final formattedRefund =
        'Rp ${refundAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Pengajuan Refund Tiket TKA</title>
</head>
<body style="margin:0;padding:24px 12px;background:#f8fafc;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <div style="max-width:540px;margin:0 auto;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.06);border:1px solid #e2e8f0;">
    <div style="background:#062056;padding:26px 24px;color:#ffffff;text-align:center;">
      <span style="background:#f59e0b;color:#ffffff;font-size:11px;font-weight:bold;letter-spacing:1px;padding:3px 10px;border-radius:12px;text-transform:uppercase;">
        REFUND DIPROSES
      </span>
      <h1 style="color:#ffffff;font-size:20px;margin:10px 0 0;font-weight:800;">Konfirmasi Pembatalan Tiket</h1>
    </div>
    <div style="padding:24px;color:#1e293b;">
      <p style="font-size:14px;line-height:1.6;margin:0 0 16px;">
        Halo <strong>${passengerName ?? 'Pelanggan TKA'}</strong>,
      </p>
      <p style="font-size:13.5px;line-height:1.6;margin:0 0 20px;color:#475569;">
        Permohonan pembatalan perjalanan dan pengembalian dana (refund) untuk tiket Anda telah kami terima dan tercatat dalam sistem TKA Rail.
      </p>
      <div style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:10px;padding:16px;margin-bottom:20px;font-size:13px;">
        <table style="width:100%;border-collapse:collapse;">
          <tr>
            <td style="padding:4px 0;color:#64748b;">Kode Booking</td>
            <td style="padding:4px 0;text-align:right;font-weight:bold;color:#062056;">$bookingCode</td>
          </tr>
          <tr>
            <td style="padding:4px 0;color:#64748b;">Kereta Api</td>
            <td style="padding:4px 0;text-align:right;font-weight:600;color:#1e293b;">$trainName</td>
          </tr>
          <tr>
            <td style="padding:4px 0;color:#64748b;">Alasan Pembatalan</td>
            <td style="padding:4px 0;text-align:right;color:#1e293b;">$reason</td>
          </tr>
          <tr>
            <td style="padding:8px 0 4px;color:#062056;font-weight:bold;">Estimasi Pengembalian (75%)</td>
            <td style="padding:8px 0 4px;text-align:right;font-weight:900;color:#16a34a;font-size:15px;">$formattedRefund</td>
          </tr>
        </table>
      </div>
      <div style="background:#f0fdf4;border-left:4px solid #22c55e;padding:12px 14px;border-radius:6px;font-size:12px;color:#15803d;line-height:1.5;">
        Dana pengembalian akan ditransfer ke rekening bank / metode pembayaran asal dalam waktu <strong>14–30 hari kerja</strong> sesuai regulasi pembatalan tiket KAI.
      </div>
      <div style="font-size:11.5px;color:#94a3b8;margin-top:20px;border-top:1px solid #f1f5f9;padding-top:14px;">
        Waktu Pengajuan: <strong>$timestampWib</strong>
      </div>
    </div>
    <div style="background:#f8fafc;padding:16px 24px;text-align:center;border-top:1px solid #e2e8f0;font-size:11px;color:#64748b;">
      © 2026 TKA Rail Ticketing System • PT Kereta Api Indonesia (Persero)
    </div>
  </div>
</body>
</html>
''';

    return sendCustomEmail(
      recipientEmail: recipientEmail,
      recipientName: passengerName,
      subject: '[TKA Rail] Permohonan Refund Tiket ($bookingCode) Diterima',
      htmlContent: htmlContent,
    );
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

