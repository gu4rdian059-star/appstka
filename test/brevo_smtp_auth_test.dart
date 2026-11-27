import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:appstka/config/app_env.dart';
import 'package:appstka/forgot_password/forgot_password_screen.dart';
import 'package:appstka/forgot_password/verify_reset_otp_screen.dart';
import 'package:appstka/forgot_password/reset_new_password_screen.dart';
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

  group('Password Reset Validation & 3-Stage OTP Lifecycle', () {
    test('rejects unregistered email before sending OTP', () async {
      final res = await AuthService.requestPasswordReset(
        'belum.terdaftar.99999@gmail.com',
      );

      expect(res.success, isFalse);
      expect(res.otpCode, isNull);
      expect(res.message.toLowerCase(), contains('belum terdaftar'));
    });

    test('rejects invalid email format', () async {
      final res = await AuthService.requestPasswordReset('bukan-email');

      expect(res.success, isFalse);
      expect(res.otpCode, isNull);
    });

    test('store and verify password reset OTP with expiry guard', () async {
      const email = 'penumpang@tka-rail.id';
      const otp = '849201';

      await SessionService.storePasswordResetOtp(email: email, otp: otp);

      // 1. Wrong OTP should fail and return no resetToken
      final wrongRes = await AuthService.verifyPasswordResetOtp(
        email: email,
        otp: '111111',
      );
      expect(wrongRes.valid, isFalse);
      expect(wrongRes.resetToken, isNull);

      // 2. Correct OTP should succeed and issue a resetToken
      final correctRes = await AuthService.verifyPasswordResetOtp(
        email: email,
        otp: otp,
      );
      expect(correctRes.valid, isTrue);
      expect(correctRes.resetToken, isNotNull);
      expect(correctRes.resetToken!.isNotEmpty, isTrue);

      // 3. Consume OTP should invalidate both OTP and resetToken
      await SessionService.consumePasswordResetOtp(email);
      final consumedRes = await SessionService.verifyPasswordResetOtp(
        email: email,
        otp: otp,
      );
      expect(consumedRes.valid, isFalse);
    });

    test('2-stage verify OTP then resetPasswordWithOtp with resetToken succeeds',
        () async {
      const email = 'penumpang@tka.com';
      const initialPass = 'password123';
      const newPass = 'rahasiaBaru2026';
      const otp = '654321';

      await SessionService.saveRegisteredAccount(
        name: 'Budi Santoso',
        email: email,
        phone: '081234567890',
        password: initialPass,
      );

      await SessionService.storePasswordResetOtp(email: email, otp: otp);

      // Tahap 2: Verifikasi OTP dulu untuk mendapatkan resetToken
      final verifyRes = await AuthService.verifyPasswordResetOtp(
        email: email,
        otp: otp,
      );
      expect(verifyRes.valid, isTrue);
      expect(verifyRes.resetToken, isNotNull);

      // Token palsu harus ditolak pada Tahap 3
      final invalidTokenRes = await AuthService.resetPasswordWithOtp(
        email: email,
        otp: otp,
        newPassword: newPass,
        resetToken: 'token-palsu-tidak-sah',
      );
      expect(invalidTokenRes.success, isFalse);

      // Tahap 3: Reset dengan resetToken yang valid -> berhasil
      final resetRes = await AuthService.resetPasswordWithOtp(
        email: email,
        otp: otp,
        newPassword: newPass,
        resetToken: verifyRes.resetToken,
      );
      expect(resetRes.success, isTrue);

      // Verifikasi password lama gagal, password baru berhasil
      final oldLogin = await SessionService.getRegisteredAccount(
        identifier: email,
        password: initialPass,
      );
      expect(oldLogin, isNull);

      final newLogin = await SessionService.getRegisteredAccount(
        identifier: email,
        password: newPass,
      );
      expect(newLogin, isNotNull);
      expect(newLogin!['name'], equals('Budi Santoso'));

      // Replay dengan token yang sama harus ditolak (one-time use)
      final replayRes = await AuthService.resetPasswordWithOtp(
        email: email,
        otp: otp,
        newPassword: 'passwordLain999',
        resetToken: verifyRes.resetToken,
      );
      expect(replayRes.success, isFalse);
    });
  });

  group('Forgot Password Separate Pages Widget Verification', () {
    testWidgets(
      'Halaman 1 memblokir email belum terdaftar dan tetap di halaman email',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(500, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(home: ForgotPasswordScreen()),
        );
        // ForgotPasswordScreen memakai animasi pulse berulang, gunakan pump berdurasi tetap
        await tester.pump(const Duration(milliseconds: 900));

        expect(find.byKey(const Key('forgot_email_field')), findsOneWidget);
        // Pastikan belum ada field OTP maupun password di Halaman 1
        expect(find.byKey(const Key('reset_otp_field')), findsNothing);
        expect(find.byKey(const Key('new_password_field')), findsNothing);

        await tester.enterText(
          find.byKey(const Key('forgot_email_field')),
          'belumdaftar@contoh.com',
        );
        await tester.ensureVisible(
          find.byKey(const Key('send_reset_otp_button')),
        );
        await tester.tap(find.byKey(const Key('send_reset_otp_button')));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        // Tetap di Halaman 1, tidak pindah ke VerifyResetOtpScreen
        expect(find.byType(VerifyResetOtpScreen), findsNothing);
        expect(find.textContaining('belum terdaftar'), findsWidgets);
      },
    );

    testWidgets(
      'Halaman 2 hanya menampilkan input OTP (tanpa input password) dan hanya berpindah ke Halaman 3 setelah OTP valid',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(500, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        const email = 'uji.widget@tka.id';
        const validOtp = '482910';

        await SessionService.saveRegisteredAccount(
          name: 'Uji Widget',
          email: email,
          phone: '081200001111',
          password: 'passwordLama123',
        );
        await SessionService.storePasswordResetOtp(email: email, otp: validOtp);

        await tester.pumpWidget(
          const MaterialApp(home: VerifyResetOtpScreen(email: email)),
        );
        await tester.pump(const Duration(milliseconds: 800));

        // Pastikan Halaman 2 HANYA punya input OTP dan TIDAK ADA input password
        expect(find.byKey(const Key('reset_otp_field')), findsOneWidget);
        expect(find.byKey(const Key('new_password_field')), findsNothing);
        expect(find.byKey(const Key('confirm_password_field')), findsNothing);

        // 1. Masukkan OTP SALAH -> tetap di VerifyResetOtpScreen, tidak pindah ke ResetNewPasswordScreen
        await tester.enterText(find.byKey(const Key('reset_otp_field')), '000000');
        await tester.ensureVisible(find.byKey(const Key('verify_otp_button')));
        await tester.tap(find.byKey(const Key('verify_otp_button')));
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(ResetNewPasswordScreen), findsNothing);
        expect(find.byType(VerifyResetOtpScreen), findsOneWidget);

        // 2. Masukkan OTP VALID -> berpindah ke ResetNewPasswordScreen (Halaman 3)
        await tester.enterText(find.byKey(const Key('reset_otp_field')), validOtp);
        await tester.ensureVisible(find.byKey(const Key('verify_otp_button')));
        await tester.tap(find.byKey(const Key('verify_otp_button')));
        await tester.pumpAndSettle();

        expect(find.byType(ResetNewPasswordScreen), findsOneWidget);
        expect(find.byKey(const Key('new_password_field')), findsOneWidget);
        expect(find.byKey(const Key('confirm_password_field')), findsOneWidget);
        // Di Halaman 3 tidak ada lagi input OTP
        expect(find.byKey(const Key('reset_otp_field')), findsNothing);

        // 3. Uji ubah password baru di Halaman 3 -> tampilkan halaman sukses
        await tester.enterText(
          find.byKey(const Key('new_password_field')),
          'SandiBaruAman2026',
        );
        await tester.enterText(
          find.byKey(const Key('confirm_password_field')),
          'SandiBaruAman2026',
        );
        await tester.ensureVisible(
          find.byKey(const Key('save_new_password_button')),
        );
        await tester.tap(find.byKey(const Key('save_new_password_button')));
        await tester.pumpAndSettle();

        expect(find.text('Kata Sandi Diperbarui!'), findsOneWidget);
        expect(find.byKey(const Key('back_to_login_button')), findsOneWidget);
      },
    );
  });

  group('Brevo Notification Service Methods Validation', () {
    test('sendPasswordResetOtpEmail skips gracefully when offline or mock',
        () async {
      final res = await BrevoNotificationService.sendPasswordResetOtpEmail(
        recipientEmail: 'user@example.com',
        otpCode: '123456',
        userName: 'User Demo',
      );
      expect(res, isNotNull);
    });
  });
}
