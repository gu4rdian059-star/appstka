import 'package:flutter/material.dart';

import '../login/login_screen.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeTerms = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animController.forward(from: 0.0);
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty) {
      _showWarning('Nama lengkap wajib diisi sesuai KTP.');
      return;
    }

    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      _showWarning('Format email tidak valid (contoh: nama@email.com).');
      return;
    }

    final phoneRegex = RegExp(r'^(?:\+628|628|08)[0-9]{8,11}$');
    if (!phoneRegex.hasMatch(phone)) {
      _showWarning('Nomor telepon tidak valid (diawali 08/628, min 10 digit).');
      return;
    }

    if (password.length < 8) {
      _showWarning('Kata sandi minimal 8 karakter.');
      return;
    }

    if (confirmPassword != password) {
      _showWarning('Konfirmasi kata sandi tidak cocok.');
      return;
    }

    if (!_agreeTerms) {
      _showWarning('Silakan setujui Syarat & Ketentuan terlebih dahulu.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await AuthService.registerPassenger(
        name: name,
        email: email,
        phone: phone,
        password: password,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(result.message)),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 650),
            pageBuilder: (_, _, _) => const LoginScreen(alreadyAnimated: true),
            transitionsBuilder: (_, animation, _, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(result.message)),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showWarning('Terjadi kendala saat registrasi: $e');
    }
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFF26716),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
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
        title: Image.asset(
          'assets/images/logo_tka_full.png',
          height: 28,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==================== JUDUL & SUBJUDUL ====================
                _buildAnimatedField(
                  intervalStart: 0.0,
                  intervalEnd: 0.35,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daftar Akun',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF062056),
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Lengkapi data berikut untuk membuat akun baru.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ==================== FIELD 1: NAMA LENGKAP ====================
                _buildAnimatedField(
                  intervalStart: 0.10,
                  intervalEnd: 0.45,
                  child: _buildFormField(
                    label: 'Nama Lengkap',
                    hint: 'Nama lengkap sesuai KTP',
                    icon: Icons.person_outline_rounded,
                    controller: _nameController,
                  ),
                ),

                const SizedBox(height: 16),

                // ==================== FIELD 2: EMAIL ====================
                _buildAnimatedField(
                  intervalStart: 0.20,
                  intervalEnd: 0.55,
                  child: _buildFormField(
                    label: 'Email',
                    hint: 'nama@email.com',
                    icon: Icons.mail_outline_rounded,
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),

                const SizedBox(height: 16),

                // ==================== FIELD 3: NOMOR TELEPON ====================
                _buildAnimatedField(
                  intervalStart: 0.30,
                  intervalEnd: 0.65,
                  child: _buildFormField(
                    label: 'Nomor Telepon',
                    hint: '081234567890',
                    icon: Icons.phone_outlined,
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                  ),
                ),

                const SizedBox(height: 16),

                // ==================== FIELD 4: KATA SANDI ====================
                _buildAnimatedField(
                  intervalStart: 0.40,
                  intervalEnd: 0.75,
                  child: _buildFormField(
                    label: 'Kata Sandi',
                    hint: 'Masukkan kata sandi',
                    icon: Icons.lock_outline_rounded,
                    controller: _passwordController,
                    obscure: _obscurePassword,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF9EA3AE),
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ==================== FIELD 5: KONFIRMASI KATA SANDI ====================
                _buildAnimatedField(
                  intervalStart: 0.50,
                  intervalEnd: 0.85,
                  child: _buildFormField(
                    label: 'Konfirmasi Kata Sandi',
                    hint: 'Ulangi kata sandi',
                    icon: Icons.lock_reset_rounded,
                    controller: _confirmPasswordController,
                    obscure: _obscureConfirmPassword,
                    suffix: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF9EA3AE),
                        size: 20,
                      ),
                      onPressed: () => setState(
                          () => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ==================== CHECKBOX SYARAT & KETENTUAN ====================
                _buildAnimatedField(
                  intervalStart: 0.60,
                  intervalEnd: 0.90,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: _agreeTerms,
                          activeColor: const Color(0xFFF26716),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          onChanged: (v) => setState(() => _agreeTerms = v ?? false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _agreeTerms = !_agreeTerms),
                          child: const Text.rich(
                            TextSpan(
                              text: 'Saya menyetujui ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4A5568),
                                height: 1.4,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Syarat & Ketentuan',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF062056),
                                  ),
                                ),
                                TextSpan(text: ' dan '),
                                TextSpan(
                                  text: 'Kebijakan Privasi TKA.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF062056),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ==================== TOMBOL DAFTAR ====================
                _buildAnimatedField(
                  intervalStart: 0.68,
                  intervalEnd: 0.96,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleRegister,
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
                              'Daftar',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // ==================== FOOTER: SUDAH PUNYA AKUN? MASUK ====================
                _buildAnimatedField(
                  intervalStart: 0.75,
                  intervalEnd: 1.0,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Sudah punya akun? ',
                          style: TextStyle(fontSize: 13, color: Color(0xFF6E7582)),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: const Text(
                            'Masuk',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF26716),
                            ),
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

  Widget _buildFormField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
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
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF062056)),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFA6ABB8)),
              prefixIcon: Icon(icon, color: const Color(0xFF9EA3AE), size: 20),
              suffixIcon: suffix,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
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

