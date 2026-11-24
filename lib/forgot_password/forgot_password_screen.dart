import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../services/auth_service.dart';

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
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // 0: Masukkan Email, 1: Masukkan Kode OTP & Kata Sandi Baru, 2: Sukses
  int _step = 0;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  int _resendCountdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
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
    _countdownTimer?.cancel();
    _animController.dispose();
    _pulseController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

  /// Langkah 1: Kirim permintaan reset password (OTP via Brevo & Supabase Auth)
  Future<void> _handleRequestReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showFeedback(
        'Harap masukkan alamat email yang valid.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await AuthService.requestPasswordReset(email);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res.success) {
        _showFeedback(res.message, isError: false);
        _startResendTimer();
        setState(() {
          _step = 1;
        });
        _animController.forward(from: 0.0);
      } else {
        _showFeedback(res.message, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showFeedback('Gagal mengirim permintaan reset: $e', isError: true);
    }
  }

  /// Langkah 2: Verifikasi OTP dan Simpan Kata Sandi Baru
  Future<void> _handleVerifyAndSave() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    final newPass = _passwordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (otp.length != 6) {
      _showFeedback('Masukkan 6 digit kode OTP verifikasi.', isError: true);
      return;
    }

    if (newPass.length < 6) {
      _showFeedback('Kata sandi baru minimal harus 6 karakter.', isError: true);
      return;
    }

    if (newPass != confirmPass) {
      _showFeedback('Konfirmasi kata sandi tidak cocok.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await AuthService.resetPasswordWithOtp(
        email: email,
        otp: otp,
        newPassword: newPass,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res.success) {
        _showFeedback(res.message, isError: false);
        setState(() => _step = 2);
        _animController.forward(from: 0.0);
      } else {
        _showFeedback(res.message, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showFeedback('Gagal memperbarui kata sandi: $e', isError: true);
    }
  }

  void _showFeedback(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFF26716) : const Color(0xFF16A34A),
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
          onPressed: () {
            if (_step == 1) {
              setState(() => _step = 0);
              _animController.forward(from: 0.0);
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
        title: Text(
          _step == 0
              ? 'Lupa Kata Sandi'
              : _step == 1
                  ? 'Verifikasi & Reset'
                  : 'Berhasil Diperbarui',
          style: const TextStyle(
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
            painter: _DottedDividerPainter(),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: _step == 0
                ? _buildEmailStep()
                : _step == 1
                    ? _buildOtpStep()
                    : _buildSuccessStep(),
          ),
        ),
      ),
    );
  }

  // ==================== STEP 0: MASUKKAN EMAIL ====================
  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildAnimatedField(
          intervalStart: 0.0,
          intervalEnd: 0.35,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale =
                  1.0 + 0.05 * math.sin(_pulseController.value * math.pi);
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
                    color: const Color(0xFFF26716).withValues(alpha: 0.18),
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
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'Masukkan alamat email akun TKA Anda. Kami akan mengirimkan 6 digit kode verifikasi OTP melalui Brevo Transactional Email.',
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

        const SizedBox(height: 26),

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
                  border: Border.all(color: const Color(0xFFE2E6EE)),
                ),
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
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
                    'Didukung layanan Brevo SMTP & API. Kode OTP akan dikirimkan langsung ke kotak masuk email Anda.',
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
                          'Kirim Kode Reset OTP',
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
    );
  }

  // ==================== STEP 1: MASUKKAN OTP & PASSWORD BARU ====================
  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildAnimatedField(
          intervalStart: 0.0,
          intervalEnd: 0.35,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFC7D2FE), width: 2),
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              size: 38,
              color: Color(0xFF4338CA),
            ),
          ),
        ),

        const SizedBox(height: 18),

        _buildAnimatedField(
          intervalStart: 0.10,
          intervalEnd: 0.40,
          child: Column(
            children: [
              const Text(
                'Periksa Email Anda',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF062056),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'Kode verifikasi 6 digit telah dikirim ke:\n${_emailController.text}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade600,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // FIELD KODE OTP 6 DIGIT
        _buildAnimatedField(
          intervalStart: 0.20,
          intervalEnd: 0.50,
          child: Column(
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
              const SizedBox(height: 7),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF062056), width: 1.5),
                ),
                child: TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 10,
                    color: Color(0xFF062056),
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    hintText: '123456',
                    hintStyle: TextStyle(
                      fontSize: 20,
                      letterSpacing: 8,
                      color: Color(0xFFCBD5E1),
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // FIELD KATA SANDI BARU
        _buildAnimatedField(
          intervalStart: 0.30,
          intervalEnd: 0.60,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kata Sandi Baru',
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
                  border: Border.all(color: const Color(0xFFE2E6EE)),
                ),
                child: TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF062056)),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Minimal 6 karakter',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFA6ABB8)),
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: Color(0xFF9EA3AE),
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF9EA3AE),
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // FIELD KONFIRMASI KATA SANDI BARU
        _buildAnimatedField(
          intervalStart: 0.40,
          intervalEnd: 0.70,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Konfirmasi Kata Sandi Baru',
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
                  border: Border.all(color: const Color(0xFFE2E6EE)),
                ),
                child: TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF062056)),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Ulangi kata sandi baru',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFA6ABB8)),
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: Color(0xFF9EA3AE),
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF9EA3AE),
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        // TOMBOL SIMPAN KATA SANDI BARU
        _buildAnimatedField(
          intervalStart: 0.50,
          intervalEnd: 0.85,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleVerifyAndSave,
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
                  : const Text(
                      'Simpan Kata Sandi Baru',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // RESEND OTP BUTTON
        _buildAnimatedField(
          intervalStart: 0.60,
          intervalEnd: 0.95,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Tidak menerima kode? ',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
              ),
              GestureDetector(
                onTap: _resendCountdown > 0 || _isLoading
                    ? null
                    : _handleRequestReset,
                child: Text(
                  _resendCountdown > 0
                      ? 'Kirim ulang ($_resendCountdown s)'
                      : 'Kirim Ulang OTP',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: _resendCountdown > 0
                        ? Colors.grey.shade400
                        : const Color(0xFFF26716),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== STEP 2: SUKSES ====================
  Widget _buildSuccessStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            size: 48,
            color: Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Kata Sandi Diperbarui!',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF062056),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Kata sandi untuk akun ${_emailController.text} telah berhasil diubah.\nSilakan masuk kembali dengan kata sandi baru Anda.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF062056),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Masuk Sekarang',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
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

class _DottedDividerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF062056).withValues(alpha: 0.2)
      ..strokeWidth = 1.5;

    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 1), Offset(x + 4, 1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
