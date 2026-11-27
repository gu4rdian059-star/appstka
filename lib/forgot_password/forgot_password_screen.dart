import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/security_guard.dart';
import 'verify_reset_otp_screen.dart';
import 'widgets/reset_password_stepper.dart';

/// HALAMAN 1: Lupa Kata Sandi — Input & Validasi Alamat Email Terdaftar.
/// Sistem WAJIB memverifikasi bahwa email benar-benar terdaftar di database
/// sebelum mengirim 6 digit kode OTP ke email masing-masing pengguna.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  late final AnimationController _animController;
  late final AnimationController _pulseController;

  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animController.forward(from: 0.0);
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _pulseController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Langkah 1: Validasi email terdaftar di database & kirim kode OTP ke email user
  Future<void> _handleRequestReset() async {
    final cleanEmail = SecurityGuard.sanitizeEmail(_emailController.text);
    if (cleanEmail.isEmpty) {
      const msg =
          'Harap masukkan alamat email yang valid (contoh: nama@email.com).';
      setState(() => _errorMessage = msg);
      _showFeedback(msg, isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await AuthService.requestPasswordReset(cleanEmail);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res.success) {
        _showFeedback(res.message, isError: false);
        // Pindah ke Halaman 2 KHUSUS Verifikasi Kode OTP
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VerifyResetOtpScreen(email: cleanEmail),
          ),
        );
      } else {
        // Email belum terdaftar atau pengiriman gagal -> blokir dan tetap di Halaman 1
        setState(() => _errorMessage = res.message);
        _showFeedback(res.message, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      final msg = 'Gagal memproses permintaan reset kata sandi: $e';
      setState(() {
        _isLoading = false;
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
          'Lupa Kata Sandi',
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
                Icons.security_rounded,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const ResetPasswordStepper(currentStep: 0),
                const SizedBox(height: 24),

                _buildAnimatedField(
                  intervalStart: 0.0,
                  intervalEnd: 0.35,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale = 1.0 +
                          0.05 * math.sin(_pulseController.value * math.pi);
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [Color(0xFFFFF2E6), Color(0xFFFFE8D1)],
                          center: Alignment.center,
                          radius: 0.85,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF26716)
                                .withValues(alpha: 0.18),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_reset_rounded,
                              size: 28,
                              color: Color(0xFF062056),
                            ),
                          ),
                          Positioned(
                            bottom: 10,
                            right: 10,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF26716),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.mail_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                _buildAnimatedField(
                  intervalStart: 0.15,
                  intervalEnd: 0.45,
                  child: Column(
                    children: [
                      const Text(
                        'Lupa Kata Sandi?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF062056),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'Masukkan alamat email akun TKA yang sudah terdaftar. Sistem akan memvalidasi email Anda lalu mengirimkan kode verifikasi OTP 6 digit ke kotak masuk email Anda.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                _buildAnimatedField(
                  intervalStart: 0.25,
                  intervalEnd: 0.60,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Alamat Email Terdaftar',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF062056),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _errorMessage != null
                                ? const Color(0xFFDC2626)
                                : const Color(0xFFE2E6EE),
                            width: _errorMessage != null ? 1.5 : 1,
                          ),
                        ),
                        child: TextField(
                          key: const Key('forgot_email_field'),
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (_) {
                            if (_errorMessage != null) {
                              setState(() => _errorMessage = null);
                            }
                          },
                          onSubmitted: (_) {
                            if (!_isLoading) _handleRequestReset();
                          },
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF062056),
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'nama@email.com',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Color(0xFFA6ABB8),
                            ),
                            prefixIcon: Icon(
                              Icons.mail_outline_rounded,
                              color: Color(0xFF9EA3AE),
                              size: 20,
                            ),
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  ResetErrorBanner(message: _errorMessage!),
                ],

                const SizedBox(height: 14),

                _buildAnimatedField(
                  intervalStart: 0.35,
                  intervalEnd: 0.70,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E9F4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 18,
                          color: Color(0xFF062056),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Hanya email yang sudah terdaftar di akun TKA yang dapat menerima kode OTP. Setelah menerima kode, verifikasi kode OTP terlebih dahulu untuk membuka halaman ubah kata sandi.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey.shade700,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                _buildAnimatedField(
                  intervalStart: 0.45,
                  intervalEnd: 0.85,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      key: const Key('send_reset_otp_button'),
                      onPressed: _isLoading ? null : _handleRequestReset,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF062056),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
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
                                  'Kirim Kode OTP ke Email',
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
                ),

                const SizedBox(height: 22),

                _buildAnimatedField(
                  intervalStart: 0.55,
                  intervalEnd: 0.95,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_back_rounded,
                          size: 16,
                          color: Color(0xFF062056),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Kembali ke Halaman Masuk',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF062056),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedField({
    required double intervalStart,
    required double intervalEnd,
    required Widget child,
  }) {
    final animation = CurvedAnimation(
      parent: _animController,
      curve: Interval(intervalStart, intervalEnd, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final p = animation.value;
        return Opacity(
          opacity: p.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - p)),
            child: child,
          ),
        );
      },
    );
  }
}
