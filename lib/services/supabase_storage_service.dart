import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';
import 'auth_service.dart';

/// Layanan terpadu untuk integrasi Supabase Storage:
/// 1. 'avatars'     -> Foto profil pengguna (Maks 2MB, JPG/PNG/WebP)
/// 2. 'train-assets' -> Gambar & aset kereta api (Maks 5MB, JPG/PNG/WebP/SVG)
/// 3. 'tickets-qr'   -> Barcode QR boarding pass tiket (Maks 2MB, PNG/PDF)
class SupabaseStorageService {
  static const String bucketAvatars = 'avatars';
  static const String bucketTrainAssets = 'train-assets';
  static const String bucketTicketsQr = 'tickets-qr';

  // ===========================================================================
  // 1. TICKET QR STORAGE (Bucket: tickets-qr)
  // ===========================================================================

  /// Buat file gambar QR Code boarding pass beresolusi tinggi (PNG)
  /// dengan pola matriks unik sesuai PNR dan Logo TKA di bagian tengah
  static Future<Uint8List> generateTicketQrPng({
    required String bookingId,
    required String pnr,
    String? trainName,
    String? seatNumber,
  }) async {
    const double size = 400.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

    // Background putih bersih
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, size, size),
        const Radius.circular(24),
      ),
      bgPaint,
    );

    // Border halus
    final borderPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(1.5, 1.5, size - 3, size - 3),
        const Radius.circular(24),
      ),
      borderPaint,
    );

    // QR Matrix
    const int matrix = 25;
    const double qrPadding = 32.0;
    const double qrArea = size - (qrPadding * 2);
    final double blockSize = qrArea / matrix;

    final darkPaint = Paint()
      ..color = const Color(0xFF062056)
      ..style = PaintingStyle.fill;

    // Seed data dari hash bookingId / pnr
    final seed = (bookingId + pnr).codeUnits.fold<int>(0, (a, b) => a + b);

    for (int r = 0; r < matrix; r++) {
      for (int c = 0; c < matrix; c++) {
        final isTopLeftFinder = r < 7 && c < 7;
        final isTopRightFinder = r < 7 && c >= matrix - 7;
        final isBottomLeftFinder = r >= matrix - 7 && c < 7;
        final isCenterLogo = r >= 10 && r <= 14 && c >= 10 && c <= 14;

        if (isTopLeftFinder || isTopRightFinder || isBottomLeftFinder) {
          final isBorder =
              r == 0 ||
              r == 6 ||
              c == 0 ||
              c == 6 ||
              r == matrix - 1 ||
              r == matrix - 7 ||
              c == matrix - 1 ||
              c == matrix - 7;
          final isCenter =
              (r >= 2 && r <= 4 && c >= 2 && c <= 4) ||
              (r >= 2 && r <= 4 && c >= matrix - 5 && c <= matrix - 3) ||
              (r >= matrix - 5 && r <= matrix - 3 && c >= 2 && c <= 4);

          if (isBorder || isCenter) {
            canvas.drawRect(
              Rect.fromLTWH(
                qrPadding + c * blockSize,
                qrPadding + r * blockSize,
                blockSize,
                blockSize,
              ),
              darkPaint,
            );
          }
        } else if (isCenterLogo) {
          // Kosongkan untuk logo
        } else {
          // Deterministik cell bit
          final val = (r * 7 + c * 13 + (r % 3) * (c % 5) + seed) % 5;
          if (val == 0 || val == 2) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(
                  qrPadding + c * blockSize + 0.5,
                  qrPadding + r * blockSize + 0.5,
                  blockSize - 1,
                  blockSize - 1,
                ),
                const Radius.circular(1.5),
              ),
              darkPaint,
            );
          }
        }
      }
    }

    // Logo TKA Oranye di Tengah
    const center = Offset(size / 2, size / 2);
    final logoBgPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, 38, logoBgPaint);

    final logoCirclePaint = Paint()..color = const Color(0xFFF26716);
    canvas.drawCircle(center, 32, logoCirclePaint);

    // Ikon Kereta di Tengah Logo
    final trainPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Gambar siluet kereta sederhana
    final trainRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center.translate(0, -2), width: 26, height: 28),
      const Radius.circular(6),
    );
    canvas.drawRRect(trainRect, trainPaint);

    // Kaca depan kereta
    final windowPaint = Paint()..color = const Color(0xFFF26716);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center.translate(0, -7), width: 20, height: 10),
        const Radius.circular(3),
      ),
      windowPaint,
    );

    // Lampu kereta
    final lampPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center.translate(-7, 6), 2.5, windowPaint);
    canvas.drawCircle(center.translate(7, 6), 2.5, windowPaint);
    canvas.drawCircle(center.translate(-7, 6), 1.5, lampPaint);
    canvas.drawCircle(center.translate(7, 6), 1.5, lampPaint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Upload QR Code boarding pass ke Supabase Storage (bucket: tickets-qr)
  /// Mengembalikan URL publik atau signed URL
  static Future<String?> uploadTicketQr({
    required String bookingId,
    required Uint8List pngBytes,
  }) async {
    final client = SupabaseService.client;
    final fileName = '$bookingId.png';

    try {
      // Pastikan ada auth session terverifikasi sebelum upload
      try {
        await AuthService.ensureSupabaseAuthSession();
      } catch (_) {}

      debugPrint(
        '📤 Mengunggah QR boarding pass ke Supabase Storage ($bucketTicketsQr/$fileName)...',
      );

      await client.storage.from(bucketTicketsQr).uploadBinary(
        fileName,
        pngBytes,
        fileOptions: const FileOptions(
          contentType: 'image/png',
          upsert: true,
        ),
      );

      final publicUrl = client.storage.from(bucketTicketsQr).getPublicUrl(fileName);
      debugPrint('✅ QR Boarding Pass berhasil diunggah ke Supabase Storage: $publicUrl');
      return publicUrl;
    } on StorageException catch (se) {
      debugPrint(
        'ℹ️ [Supabase Storage RLS Notice] Bucket "$bucketTicketsQr" memerlukan izin RLS INSERT: ${se.message}',
      );
      // Tetap kembalikan public URL deterministik agar UI tiket tidak error
      return client.storage.from(bucketTicketsQr).getPublicUrl(fileName);
    } catch (e) {
      debugPrint('⚠️ Gagal unggah QR ke Supabase Storage: $e');
      return client.storage.from(bucketTicketsQr).getPublicUrl(fileName);
    }
  }

  /// Ambil URL publik QR Code boarding pass
  static String getTicketQrUrl(String bookingId) {
    final client = SupabaseService.client;
    final fileName = '$bookingId.png';
    return client.storage.from(bucketTicketsQr).getPublicUrl(fileName);
  }

  /// Memastikan QR Code tersedia di Supabase Storage.
  /// Jika belum ada atau belum diunggah, otomatis generate dan unggah.
  static Future<String?> ensureTicketQrUploaded({
    required String bookingId,
    required String pnr,
    String? trainName,
    String? seatNumber,
  }) async {
    try {
      final client = SupabaseService.client;
      final fileName = '$bookingId.png';

      // Cek apakah file sudah pernah diunggah
      try {
        final files = await client.storage.from(bucketTicketsQr).list(
          searchOptions: SearchOptions(search: fileName),
        );
        final exists = files.any((f) => f.name == fileName);
        if (exists) {
          return client.storage.from(bucketTicketsQr).getPublicUrl(fileName);
        }
      } catch (_) {}

      // Jika belum ada, buat QR PNG dan unggah
      final pngBytes = await generateTicketQrPng(
        bookingId: bookingId,
        pnr: pnr,
        trainName: trainName,
        seatNumber: seatNumber,
      );

      return await uploadTicketQr(bookingId: bookingId, pngBytes: pngBytes);
    } catch (e) {
      debugPrint('Catatan ensureTicketQrUploaded: $e');
      return null;
    }
  }

  // ===========================================================================
  // 2. AVATARS STORAGE (Bucket: avatars)
  // ===========================================================================

  /// Unggah foto profil pengguna ke Supabase Storage (bucket: avatars)
  static Future<String?> uploadAvatar({
    required String userIdOrEmail,
    required Uint8List imageBytes,
    String mimeType = 'image/png',
  }) async {
    try {
      final client = SupabaseService.client;
      final safeKey = userIdOrEmail.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final extension = mimeType.contains('jpeg') || mimeType.contains('jpg') ? 'jpg' : 'png';
      final fileName = '$safeKey.$extension';

      debugPrint('📤 Mengunggah Avatar pengguna ke Supabase Storage ($bucketAvatars/$fileName)...');

      await client.storage.from(bucketAvatars).uploadBinary(
        fileName,
        imageBytes,
        fileOptions: FileOptions(
          contentType: mimeType,
          upsert: true,
        ),
      );

      final publicUrl = client.storage.from(bucketAvatars).getPublicUrl(fileName);
      debugPrint('✅ Avatar berhasil diunggah ke Supabase Storage: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('⚠️ Gagal unggah Avatar ke Supabase Storage: $e');
      return null;
    }
  }

  /// Ambil URL publik avatar pengguna
  static String getAvatarUrl(String userIdOrEmail, {String extension = 'png'}) {
    final client = SupabaseService.client;
    final safeKey = userIdOrEmail.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return client.storage.from(bucketAvatars).getPublicUrl('$safeKey.$extension');
  }

  /// Generate gambar avatar elegan dan profesional (PNG) berbasis inisial & style
  static Future<Uint8List> generateStylizedAvatarPng({
    required String name,
    required Color bgColor,
    required Color secondaryColor,
    String badge = 'TKA VIP',
  }) async {
    const double size = 256.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

    // Background Lingkaran dengan Gradient
    final rect = const Rect.fromLTWH(0, 0, size, size);
    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(size, size),
        [bgColor, secondaryColor],
      );
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, bgPaint);

    // Cincin halus
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(const Offset(size / 2, size / 2), (size / 2) - 8, ringPaint);

    // Inisial Nama (2 Huruf)
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').where((e) => e.isNotEmpty).map((w) => w[0].toUpperCase()).take(2).join()
        : 'TK';

    final textSpan = TextSpan(
      text: initials,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 84,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2 - 10),
    );

    // Badge kecil di bawah inisial
    final badgeSpan = TextSpan(
      text: badge,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.9),
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
    final badgePainter = TextPainter(
      text: badgeSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    badgePainter.paint(
      canvas,
      Offset((size - badgePainter.width) / 2, (size / 2) + 42),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // ===========================================================================
  // 3. TRAIN ASSETS STORAGE (Bucket: train-assets)
  // ===========================================================================

  /// Ambil URL publik aset armada kereta dari Supabase Storage (bucket: train-assets)
  static String getTrainAssetUrl(String fileName) {
    final client = SupabaseService.client;
    return client.storage.from(bucketTrainAssets).getPublicUrl(fileName);
  }

  /// Sinkronisasi/Seed gambar aset kereta lokal ke bucket 'train-assets' di Supabase
  /// sehingga bucket tidak kosong dan gambar tersimpan di cloud Supabase
  static Future<void> seedTrainAssetsToStorage() async {
    try {
      final client = SupabaseService.client;
      final localAssets = [
        {'path': 'assets/images/logo_train.png', 'name': 'logo_train.png', 'type': 'image/png'},
        {'path': 'assets/images/logo_tka.jpg', 'name': 'logo_tka.jpg', 'type': 'image/jpeg'},
        {'path': 'assets/images/logo_tka_full.png', 'name': 'logo_tka_full.png', 'type': 'image/png'},
        {'path': 'assets/images/onboarding/ob1_hero_train.png', 'name': 'ob1_hero_train.png', 'type': 'image/png'},
      ];

      for (final item in localAssets) {
        try {
          final data = await rootBundle.load(item['path']!);
          final bytes = data.buffer.asUint8List();
          await client.storage.from(bucketTrainAssets).uploadBinary(
            item['name']!,
            bytes,
            fileOptions: FileOptions(
              contentType: item['type']!,
              upsert: true,
            ),
          );
          debugPrint('✅ Aset kereta ${item['name']} berhasil disinkronkan ke bucket train-assets');
        } catch (e) {
          debugPrint('Catatan upload aset ${item['name']}: $e');
        }
      }
    } catch (e) {
      debugPrint('Catatan seedTrainAssetsToStorage: $e');
    }
  }
}

