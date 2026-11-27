import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import 'reset_new_password_screen.dart';
import 'widgets/reset_password_stepper.dart';

/// HALAMAN 2: Khusus Verifikasi Kode OTP 6 Digit yang dikirim ke email user.
/// Tidak ada form password di halaman ini — pengguna WAJIB memverifikasi OTP valid
/// terlebih dahulu sebelum berpindah ke halaman Ubah Kata Sandi Baru.
class VerifyResetOtpScreen extends StatefulWidget {
  final String email;

  const VerifyResetOtpScreen({
    super.key,
    required this.email,
  });

  @override
  State<VerifyResetOtpScreen> createState() => _VerifyResetOtpScreenState();
}

class _VerifyResetOtpScreenState extends State<VerifyResetOtpScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  final TextEditingController _otpController = TextEditingController();

  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;

  int _resendCountdown = 60;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _startResendTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _animController.forward(from: 0.0);
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _countdownTimer?.cancel();
    setState(() => _resendCountdown = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown <= 1) {
        timer.cancel();
        setState(() => _resendCountdown = 0);
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _otpController.text.trim();

    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      const msg = 'Harap masukkan 6 digit angka kode OTP dari email Anda.';
      setState(() => _errorMessage = msg);
      _showFeedback(msg, isError: true);
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final res = await AuthService.verifyPasswordResetOtp(
        email: widget.email,
        otp: otp,
      );

      if (!mounted) return;
      setState(() => _isVerifying = false);

      if (res.valid) {
        _showFeedback(res.message, isError: false);
        // OTP VALID -> Barulah berpindah ke halaman khusus Ubah Kata Sandi Baru!
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ResetNewPasswordScreen(
              email: widget.email,
              verifiedOtp: otp,
              resetToken: res.resetToken,
            ),
          ),
        );
      } else {
        setState(() => _errorMessage = res.message);
        _showFeedback(res.message, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      final msg = 'Gagal memverifikasi kode OTP: $e';
      setState(() {
        _isVerifying = false;
        _errorMessage = msg;
      });
      _showFeedback(msg, isError: true);
    }
  }

  Future<void> _handleResendOtp() async {
    if (_resendCountdown > 0 || _isResending || _isVerifying) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final res = await AuthService.requestPasswordReset(widget.email);
      if (!mounted) return;
      setState(() => _isResending = false);

      if (res.success) {
        _otpController.clear();
        _startResendTimer();
        _showFeedback(res.message, isError: false);
      } else {
        setState(() => _errorMessage = res.message);
        _showFeedback(res.message, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      final msg = 'Gagal mengirim ulang kode OTP: $e';
      setState(() {
        _isResending = false;
        _errorMessage = msg;
      });
      _showFeedback(msg, isError: true);
    }
  }

  void _showFeedback(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF062056),
            size: 22,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Verifikasi Kode OTP',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF062056),
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF062056),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: CustomPaint(
            size: const Size(double.infinity, 2),
            painter: ResetDottedDividerPainter(),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _animController,
                curve: Curves.easeOut,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const ResetPasswordStepper(currentStep: 1),
                  const SizedBox(height: 24),

                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFC7D2FE),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.mark_email_read_rounded,
                      size: 40,
                      color: Color(0xFF062056),
                    ),
                  ),
                  const SizedBox(height: 18),

                  const Text(
                    'Masukkan Kode Verifikasi',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF062056),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.5,
                        ),
                        children: [
                          const TextSpan(
                            text:
                                'Kami telah mengirimkan kode OTP 6 digit ke alamat email Anda:\n',
                          ),
                          TextSpan(
                            text: widget.email,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF062056),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Input Kode OTP 6 Digit
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kode OTP 6 Digit',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF062056),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _errorMessage != null
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF062056),
                            width: 1.6,
                          ),
                        ),
                        child: TextField(
                          key: const Key('reset_otp_field'),
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          textAlign: TextAlign.center,
                          onChanged: (_) {
                            if (_errorMessage != null) {
                              setState(() => _errorMessage = null);
                            }
                          },
                          onSubmitted: (_) {
                            if (!_isVerifying) _handleVerifyOtp();
                          },
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 12,
                            color: Color(0xFF062056),
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: '••••••',
                            hintStyle: TextStyle(
                              fontSize: 24,
                              letterSpacing: 10,
                              color: Color(0xFFCBD5E1),
                            ),
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    ResetErrorBanner(message: _errorMessage!),
                  ],

                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFED7AA)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 18,
                          color: Color(0xFFEA580C),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Kode OTP berlaku selama 15 menit. Setelah kode terverifikasi valid, Anda akan diarahkan ke halaman untuk membuat kata sandi baru.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF9A3412),
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Tombol Verifikasi Kode OTP
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      key: const Key('verify_otp_button'),
                      onPressed: _isVerifying ? null : _handleVerifyOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF062056),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isVerifying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Verifikasi Kode OTP',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 18),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Tombol Kirim Ulang OTP (Wrap agar aman di layar kecil tanpa overflow)
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Tidak menerima email kode?',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      GestureDetector(
                        onTap: _resendCountdown > 0 || _isResending
                            ? null
                            : _handleResendOtp,
                        child: Text(
                          _isResending
                              ? 'Mengirim...'
                              : _resendCountdown > 0
                                  ? 'Kirim ulang (${_resendCountdown}s)'
                                  : 'Kirim Ulang OTP',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: _resendCountdown > 0 || _isResending
                                ? Colors.grey.shade400
                                : const Color(0xFFF26716),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Ganti Alamat Email
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: Color(0xFF062056),
                    ),
                    label: const Text(
                      'Ganti Alamat Email',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF062056),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
