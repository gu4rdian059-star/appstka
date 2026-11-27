import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_env.dart';

class TurnstileVerifyResult {
  final bool verified;
  final String? token;
  final String message;

  const TurnstileVerifyResult({
    required this.verified,
    this.token,
    required this.message,
  });
}

/// Layanan verifikasi Cloudflare Turnstile untuk halaman Login TKA.
/// Mendukung Testing Dummy Keys resmi Cloudflare:
/// - Site Key (Always Pass): `1x00000000000000000000AA`
/// - Secret Key (Always Pass): `1x0000000000000000000000000000000AA`
class TurnstileService {
  static const String _siteVerifyUrl =
      'https://challenges.cloudflare.com/turnstile/v0/siteverify';

  static bool get isEnabled => AppEnv.turnstileEnabled;
  static String get siteKey => AppEnv.turnstileSiteKey;
  static String get secretKey => AppEnv.turnstileSecretKey;

  /// Menjalankan verifikasi token Turnstile melalui Secure API Gateway (server-side siteverify)
  /// agar pada Flutter Web tidak terkena CORS dan TURNSTILE_SECRET_KEY tidak terekspos ke browser.
  static Future<TurnstileVerifyResult> verifyChallenge({String? responseToken}) async {
    if (!isEnabled) {
      return const TurnstileVerifyResult(
        verified: true,
        token: 'turnstile-disabled',
        message: 'Cloudflare Turnstile dinonaktifkan.',
      );
    }

    final currentSiteKey = siteKey;
    final currentSecretKey = secretKey;

    // Jika menggunakan dummy key resmi Cloudflare untuk skenario Always-Block (2x0000...)
    if (currentSiteKey.startsWith('2x0000') ||
        currentSecretKey.startsWith('2x0000')) {
      return const TurnstileVerifyResult(
        verified: false,
        message:
            'Verifikasi Cloudflare Turnstile ditolak (Mode Testing Always-Fail).',
      );
    }

    final tokenToVerify = (responseToken != null && responseToken.trim().isNotEmpty)
        ? responseToken.trim()
        : 'cf.turnstile.XXXX.DUMMY.TOKEN.${DateTime.now().millisecondsSinceEpoch}';

    // 1. Jalur Utama (WAJIB untuk Web & disarankan untuk semua platform):
    //    Verifikasi melalui TKA Secure API Gateway -> server memanggil Cloudflare siteverify tanpa CORS
    try {
      final gatewayUri = Uri.parse(
        '${AppEnv.apiGatewayUrl}/api/security/turnstile/verify',
      );
      final gwResp = await http
          .post(
            gatewayUri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'response': tokenToVerify}),
          )
          .timeout(const Duration(seconds: 8));

      final gwData = jsonDecode(gwResp.body);
      if (gwData is Map) {
        final ok = gwResp.statusCode >= 200 &&
            gwResp.statusCode < 300 &&
            (gwData['verified'] == true || gwData['success'] == true);
        final msg = (gwData['message'] ?? '').toString();
        if (ok) {
          debugPrint(
            '✅ Cloudflare Turnstile terverifikasi lewat Secure API Gateway (hostname: ${gwData['hostname'] ?? 'local'})',
          );
          return TurnstileVerifyResult(
            verified: true,
            token: tokenToVerify,
            message: msg.isNotEmpty
                ? msg
                : 'Verifikasi Cloudflare Turnstile berhasil.',
          );
        }
        return TurnstileVerifyResult(
          verified: false,
          message: msg.isNotEmpty
              ? msg
              : 'Verifikasi Cloudflare Turnstile gagal.',
        );
      }
    } catch (e) {
      debugPrint('ℹ️ Gateway Turnstile (${AppEnv.apiGatewayUrl}) tidak terjangkau: $e');
      if (kIsWeb) {
        // Pada Web, JANGAN panggil challenges.cloudflare.com langsung (pasti diblokir CORS).
        // Jika menggunakan official testing sitekey lokal saat Gateway mati, tetap izinkan testing lokal yang jelas.
        if (currentSiteKey == '1x00000000000000000000AA') {
          return TurnstileVerifyResult(
            verified: true,
            token: tokenToVerify,
            message: 'Verifikasi Turnstile (Mode Testing Lokal — Gateway offline).',
          );
        }
        return TurnstileVerifyResult(
          verified: false,
          message:
              'Tidak dapat terhubung ke Secure API Gateway (${AppEnv.apiGatewayUrl}) untuk verifikasi Turnstile.',
        );
      }
    }

    // 2. Jalur Fallback Native (Android/iOS/Desktop) ketika Gateway lokal tidak berjalan:
    if (currentSecretKey.isNotEmpty) {
      try {
        final response = await http
            .post(
              Uri.parse(_siteVerifyUrl),
              headers: const {
                'Content-Type': 'application/x-www-form-urlencoded',
              },
              body: {
                'secret': currentSecretKey,
                'response': tokenToVerify,
              },
            )
            .timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final success = data['success'] == true;
          if (success) {
            debugPrint(
              '✅ Cloudflare Turnstile siteverify native berhasil (hostname: ${data['hostname'] ?? 'local'})',
            );
            return TurnstileVerifyResult(
              verified: true,
              token: tokenToVerify,
              message: 'Verifikasi Cloudflare Turnstile berhasil.',
            );
          } else {
            final errCodes = data['error-codes'] ?? [];
            debugPrint('❌ Cloudflare Turnstile siteverify gagal: $errCodes');
            return TurnstileVerifyResult(
              verified: false,
              message: 'Verifikasi Turnstile gagal ($errCodes).',
            );
          }
        }
      } catch (e) {
        debugPrint('ℹ️ Koneksi native siteverify Cloudflare gagal: $e');
      }
    }

    // Validasi Testing Dummy Key Resmi Cloudflare pada lingkungan offline/test
    if (currentSiteKey == '1x00000000000000000000AA' &&
        currentSecretKey == '1x0000000000000000000000000000000AA') {
      await Future.delayed(const Duration(milliseconds: 250));
      return TurnstileVerifyResult(
        verified: true,
        token: tokenToVerify,
        message: 'Verifikasi Cloudflare Turnstile (Testing Key) berhasil.',
      );
    }

    return const TurnstileVerifyResult(
      verified: false,
      message: 'Konfigurasi TURNSTILE_SITE_KEY / SECRET_KEY belum lengkap.',
    );
  }
}

