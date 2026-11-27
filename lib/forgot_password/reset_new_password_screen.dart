import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'widgets/reset_password_stepper.dart';

/// HALAMAN 3: Khusus Membuat Kata Sandi Baru.
/// Halaman ini HANYA muncul setelah kode OTP dari email terverifikasi VALID di VerifyResetOtpScreen.
class ResetNewPasswordScreen extends StatefulWidget {
  final String email;
  final String verifiedOtp;
  final String? resetToken;

  const ResetNewPasswordScreen({
    super.key,
    required this.email,
    required this.verifiedOtp,
    this.resetToken,
  });

  @override
  State<ResetNewPasswordScreen> createState() => _ResetNewPasswordScreenState();
}

class _ResetNewPasswordScreenState extends State<ResetNewPasswordScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isSaving = false;
  bool _isSuccess = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _animController.forward(from: 0.0);
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  int _passwordStrengthScore(String password) {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 6) score++;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'[0-9]').hasMatch(password) ||
        RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(password)) {
      score++;
    }
    return score;
  }

  Future<void> _handleSaveNewPassword() async {
    final newPass = _passwordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (newPass.length < 6) {
      const msg = 'Kata sandi baru minimal harus 6 karakter.';
      setState(() => _errorMessage = msg);
      _showFeedback(msg, isError: true);
      return;
    }

    if (newPass != confirmPass) {
      const msg = 'Konfirmasi kata sandi baru tidak cocok.';
      setState(() => _errorMessage = msg);
      _showFeedback(msg, isError: true);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final res = await AuthService.resetPasswordWithOtp(
        email: widget.email,
        otp: widget.verifiedOtp,
        newPassword: newPass,
        resetToken: widget.resetToken,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (res.success) {
        _showFeedback(res.message, isError: false);
        setState(() => _isSuccess = true);
        _animController.forward(from: 0.0);
      } else {
        setState(() => _errorMessage = res.message);
        _showFeedback(res.message, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      final msg = 'Gagal memperbarui kata sandi: $e';
      setState(() {
        _isSaving = false;
        _errorMessage = msg;
      });
      _showFeedback(msg, isError: true);
    }
  }

  void _backToLogin() {
    // Tutup ResetNewPasswordScreen dan ForgotPasswordScreen agar kembali langsung ke halaman Login
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    }
    if (nav.canPop()) {
      nav.pop();
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
          onPressed: () {
            if (_isSuccess) {
              _backToLogin();
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
        title: Text(
          _isSuccess ? 'Kata Sandi Diperbarui' : 'Buat Kata Sandi Baru',
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
              decoration: BoxDecoration(
                color: _isSuccess
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF062056),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isSuccess ? Icons.check_rounded : Icons.lock_reset_rounded,
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
              child: _isSuccess ? _buildSuccessBody() : _buildPasswordForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordForm() {
    final pass = _passwordController.text;
    final strength = _passwordStrengthScore(pass);
    final strengthLabel = strength <= 1
        ? 'Lemah'
        : strength == 2
            ? 'Cukup'
            : strength == 3
                ? 'Baik'
                : 'Kuat';
    final strengthColor = strength <= 1
        ? const Color(0xFFDC2626)
        : strength == 2
            ? const Color(0xFFF59E0B)
            : strength == 3
                ? const Color(0xFF2563EB)
                : const Color(0xFF16A34A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const ResetPasswordStepper(currentStep: 2),
        const SizedBox(height: 22),

        // Badge Konfirmasi Email & OTP Sudah Valid
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_rounded,
                size: 16,
                color: Color(0xFF16A34A),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'OTP terverifikasi untuk ${widget.email}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        const Text(
          'Atur Kata Sandi Baru',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: Color(0xFF062056),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Buat kata sandi baru yang aman untuk akun TKA Anda.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 24),

        // Field Kata Sandi Baru
        Column(
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
                key: const Key('new_password_field'),
                controller: _passwordController,
                obscureText: _obscurePassword,
                onChanged: (_) => setState(() => _errorMessage = null),
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF062056),
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Minimal 6 karakter',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFA6ABB8),
                  ),
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
            if (pass.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (strength / 4).clamp(0.15, 1.0),
                        minHeight: 5,
                        backgroundColor: const Color(0xFFE2E8F0),
                        color: strengthColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    strengthLabel,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: strengthColor,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),

        const SizedBox(height: 16),

        // Field Konfirmasi Kata Sandi Baru
        Column(
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
                key: const Key('confirm_password_field'),
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                onChanged: (_) => setState(() => _errorMessage = null),
                onSubmitted: (_) {
                  if (!_isSaving) _handleSaveNewPassword();
                },
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF062056),
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Ulangi kata sandi baru',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFA6ABB8),
                  ),
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

        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          ResetErrorBanner(message: _errorMessage!),
        ],

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const Key('save_new_password_button'),
            onPressed: _isSaving ? null : _handleSaveNewPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF062056),
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isSaving
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
      ],
    );
  }

  Widget _buildSuccessBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const ResetPasswordStepper(currentStep: 3),
        const SizedBox(height: 30),
        Container(
          width: 88,
          height: 88,
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
            size: 50,
            color: Color(0xFF16A34A),
          ),
        ),
        const SizedBox(height: 22),
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Kata sandi untuk akun ${widget.email} telah berhasil diubah di sistem.\nSilakan masuk kembali dengan kata sandi baru Anda.',
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
            key: const Key('back_to_login_button'),
            onPressed: _backToLogin,
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
}

