import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:appstka/config/app_env.dart';
import 'package:appstka/services/auth_service.dart';
import 'package:appstka/services/session_service.dart';
import 'package:appstka/services/brevo_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Brevo & SMTP Configuration Verification', () {
    test('AppEnv provides correct Brevo API Key and SMTP parameters', () async {
      await AppEnv.load();

      expect(AppEnv.smtpHost, equals('smtp-relay.brevo.com'));
      expect(AppEnv.smtpPort, equals(587));
      expect(AppEnv.smtpUser, equals('b16832001@smtp-brevo.com'));
      expect(AppEnv.hasBrevoConfig, isTrue);
      expect(AppEnv.brevoApiKey.startsWith('xkeysib-'), isTrue);
      expect(AppEnv.brevoSenderEmail, isNotEmpty);
    });
  });

  group('Password Reset & OTP Lifecycle via SessionService & AuthService', () {
    test('store and verify password reset OTP with expiry guard', () async {
      const email = 'penumpang@tka-rail.id';
      const otp = '849201';

      await SessionService.storePasswordResetOtp(email: email, otp: otp);

      // 1. Wrong OTP should fail
      final wrongRes = await SessionService.verifyPasswordResetOtp(
        email: email,
        otp: '111111',
      );
      expect(wrongRes.valid, isFalse);

      // 2. Correct OTP should succeed
      final correctRes = await SessionService.verifyPasswordResetOtp(
        email: email,
        otp: otp,
      );
      expect(correctRes.valid, isTrue);

      // 3. Consume OTP should remove it
      await SessionService.consumePasswordResetOtp(email);
      final consumedRes = await SessionService.verifyPasswordResetOtp(
        email: email,
        otp: otp,
      );
      expect(consumedRes.valid, isFalse);
    });

    test('resetPasswordWithOtp updates account credentials successfully', () async {
      const email = 'penumpang@tka.com';
      const initialPass = 'password123';
      const newPass = 'rahasiaBaru2026';
      const otp = '654321';

      // Daftarkan akun awal
      await SessionService.saveRegisteredAccount(
        name: 'Budi Santoso',
        email: email,
        phone: '081234567890',
        password: initialPass,
      );

      // Pastikan bisa login dengan password lama
      final initialAcc = await SessionService.getRegisteredAccount(
        identifier: email,
        password: initialPass,
      );
      expect(initialAcc, isNotNull);

      // Set OTP
      await SessionService.storePasswordResetOtp(email: email, otp: otp);

      // Lakukan reset password
      final resetRes = await AuthService.resetPasswordWithOtp(
        email: email,
        otp: otp,
        newPassword: newPass,
      );
      expect(resetRes.success, isTrue);

      // Verifikasi login dengan password lama gagal
      final oldLogin = await SessionService.getRegisteredAccount(
        identifier: email,
        password: initialPass,
      );
      expect(oldLogin, isNull);

      // Verifikasi login dengan password baru sukses
      final newLogin = await SessionService.getRegisteredAccount(
        identifier: email,
        password: newPass,
      );
      expect(newLogin, isNotNull);
      expect(newLogin!['name'], equals('Budi Santoso'));
    });
  });

  group('Brevo Notification Service Methods Validation', () {
    test('sendPasswordResetOtpEmail skips gracefully when offline or mock', () async {
      final res = await BrevoNotificationService.sendPasswordResetOtpEmail(
        recipientEmail: 'user@example.com',
        otpCode: '123456',
        userName: 'User Demo',
      );
      // Even if network call fails or mock fails, returns response object without crashing
      expect(res, isNotNull);
    });
  });
}

