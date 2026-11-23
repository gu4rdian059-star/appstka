import 'package:flutter/material.dart';

import '../admin/admin_dashboard_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../forgot_password/forgot_password_screen.dart';
import '../register/register_screen.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';

class LoginScreen extends StatefulWidget {
  final bool alreadyAnimated;
  final Animation<double>? externalEntranceAnimation;

  const LoginScreen({
    super.key,
    this.alreadyAnimated = false,
    this.externalEntranceAnimation,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _rememberMe = true;
  bool _obscurePassword = true;
  bool _isLoading = false;

  // Status Validasi Dinamis
  bool _isRegistered = false;
  String? _identifierError;
  String? _passwordError;
  bool _hasTouchedIdentifier = false;
  bool _hasTouchedPassword = false;

  Animation<double> get _effectiveAnim =>
      widget.externalEntranceAnimation ?? _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    _loadSavedPreferences();

    if (widget.externalEntranceAnimation == null) {
      if (widget.alreadyAnimated) {
        _animController.value = 1.0;
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _animController.forward(from: 0.0);
          }
        });
      }
    }

    _identifierController.addListener(_onIdentifierChanged);
    _passwordController.addListener(_onPasswordChanged);
  }

  Future<void> _loadSavedPreferences() async {
    final remember = await SessionService.getRememberMe();
    final savedId = await SessionService.getSavedIdentifier();
    if (mounted) {
      setState(() {
        _rememberMe = remember;
        if (remember && savedId != null && savedId.isNotEmpty) {
          _identifierController.text = savedId;
          _onIdentifierChanged();
        }
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _identifierController.removeListener(_onIdentifierChanged);
    _passwordController.removeListener(_onPasswordChanged);
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onIdentifierChanged() {
    final text = _identifierController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _isRegistered = false;
        _identifierError = _hasTouchedIdentifier ? 'Email atau no. handphone wajib diisi' : null;
      });
      return;
    }

    // Cek apakah angka / telepon
    final isPhoneDigits = RegExp(r'^\+?[0-9]+$').hasMatch(text);
    if (isPhoneDigits) {
      // Validasi nomor HP: diawali 08, 628, atau +628, panjang 10-13 digit
      final isValidPhone = RegExp(r'^(?:\+628|628|08)[0-9]{8,11}$').hasMatch(text);
      setState(() {
        if (isValidPhone) {
          _isRegistered = true;
          _identifierError = null;
        } else {
          _isRegistered = false;
          if (_hasTouchedIdentifier) {
            if (text.length >= 4 &&
                !text.startsWith('08') &&
                !text.startsWith('628') &&
                !text.startsWith('+62')) {
              _identifierError = 'Nomor HP harus diawali 08 atau 628';
            } else if (text.length < 10) {
              _identifierError = 'Nomor HP minimal 10 digit (${text.length}/10)';
            } else if (text.length > 13) {
              _identifierError = 'Nomor HP maksimal 13 digit';
            } else {
              _identifierError = 'Format nomor HP tidak valid';
            }
          } else {
            _identifierError = null;
          }
        }
      });
      return;
    }

    // Cek apakah format Email
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (emailRegex.hasMatch(text)) {
      setState(() {
        _isRegistered = true;
        _identifierError = null;
      });
    } else {
      setState(() {
        _isRegistered = false;
        if (_hasTouchedIdentifier) {
          if (text.contains('@')) {
            _identifierError = 'Format email belum lengkap (contoh: nama@tka.id)';
          } else if (text.length > 3) {
            _identifierError = 'Gunakan format email (@...) atau no. HP (08...)';
          } else {
            _identifierError = null;
          }
        } else {
          _identifierError = null;
        }
      });
    }
  }

  void _onPasswordChanged() {
    final text = _passwordController.text;
    if (text.isEmpty) {
      setState(() {
        _passwordError = _hasTouchedPassword ? 'Kata sandi wajib diisi' : null;
      });
      return;
    }

    setState(() {
      if (text.length < 8) {
        if (_hasTouchedPassword) {
          _passwordError = 'Kata sandi minimal 8 karakter (${text.length}/8)';
        } else {
          _passwordError = null;
        }
      } else {
        _passwordError = null;
      }
    });
  }

  void _handleLogin() {
    final id = _identifierController.text.trim();
    final pw = _passwordController.text;

    setState(() {
      _hasTouchedIdentifier = true;
      _hasTouchedPassword = true;
    });

    bool hasError = false;

    // Validasi ID
    if (id.isEmpty) {
      setState(() => _identifierError = 'Email atau no. handphone wajib diisi');
      hasError = true;
    } else {
      final isValidPhone = RegExp(r'^(?:\+628|628|08)[0-9]{8,11}$').hasMatch(id);
      final isValidEmail = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(id);
      if (isValidPhone || isValidEmail) {
        setState(() {
          _isRegistered = true;
          _identifierError = null;
        });
      } else {
        setState(() {
          _isRegistered = false;
          _identifierError = 'Format email atau no. handphone tidak valid';
        });
        hasError = true;
      }
    }

    // Validasi Password: minimal 8 karakter
    if (pw.isEmpty) {
      setState(() => _passwordError = 'Kata sandi wajib diisi');
      hasError = true;
    } else if (pw.length < 8) {
      setState(() => _passwordError = 'Kata sandi minimal 8 karakter (${pw.length}/8)');
      hasError = true;
    } else {
      setState(() => _passwordError = null);
    }

    if (hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap lengkapi email/no HP dan kata sandi dengan benar.'),
          backgroundColor: Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    Future.delayed(const Duration(milliseconds: 300), () async {
      if (!mounted) return;

      // Simpan preferensi Ingat Saya secara nyata
      await SessionService.setRememberMe(
        remember: _rememberMe,
        identifier: _rememberMe ? id : null,
      );

      final isAdmin = id.toLowerCase().contains('admin');
      if (isAdmin) {
        final adminName = (id.toLowerCase() == 'admin@tka.id')
            ? 'Bambang Sudiro, M.T.'
            : (id.contains('@')
                ? '${id.split('@').first[0].toUpperCase()}${id.split('@').first.substring(1)} (Admin)'
                : 'Administrator TKA');

        await SessionService.saveUserSession(
          name: adminName,
          emailOrPhone: id,
        );

        if (!mounted) return;
        setState(() => _isLoading = false);

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 650),
            pageBuilder: (_, _, _) => AdminDashboardScreen(
              adminEmail: id,
              adminName: adminName,
            ),
            transitionsBuilder: (_, animation, _, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
        return;
      }

      // Autentikasi Penumpang via Supabase Auth
      final authResult = await AuthService.loginUser(
        emailOrPhone: id,
        password: pw,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (authResult.success) {
        final userName = await SessionService.getUserName();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 650),
            pageBuilder: (_, _, _) => DashboardScreen(userName: userName),
            transitionsBuilder: (_, animation, _, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authResult.message),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  void _showBiometricDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF062056).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fingerprint_rounded,
                  size: 46,
                  color: Color(0xFF062056),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Autentikasi Sidik Jari',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF062056),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sentuh sensor sidik jari perangkat Anda untuk masuk ke akun TKA dengan cepat.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF6E7582)),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Batal',
                    style: TextStyle(
                      color: Color(0xFF062056),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseAnim = _effectiveAnim;

    // 1. Animasi Header dari atas
    final headerSlide = CurvedAnimation(
      parent: baseAnim,
      curve: const Interval(0.0, 0.60, curve: Curves.easeOutCubic),
    );

    // 2. Animasi Logo Pop
    final logoScale = CurvedAnimation(
      parent: baseAnim,
      curve: const Interval(0.28, 0.80, curve: Curves.elasticOut),
    );

    // 3. Animasi Form meluncur tinggi dari bawah (560px)
    final formSlide = CurvedAnimation(
      parent: baseAnim,
      curve: const Interval(0.15, 0.90, curve: Curves.easeOutCubic),
    );

    // 4. Animasi Footer
    final footerFade = CurvedAnimation(
      parent: baseAnim,
      curve: const Interval(0.62, 1.0, curve: Curves.easeOut),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // ==================== HEADER BIRU NAVY DENGAN LENGKUNGAN ====================
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.6),
                    end: Offset.zero,
                  ).animate(headerSlide),
                  child: _buildNavyHeader(context),
                ),

                const SizedBox(height: 14),

                // ==================== LOGO TKA TRANSPARAN (TANPA BACKGROUND PUTIH) ====================
                ScaleTransition(
                  scale: Tween<double>(begin: 0.0, end: 1.0).animate(logoScale),
                  child: Image.asset(
                    'assets/images/logo_tka_full.png',
                    height: 42,
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 14),

                // ==================== KARTU FORM LOGIN (MELUNCUR DARI BAWAH) ====================
                AnimatedBuilder(
                  animation: formSlide,
                  builder: (context, child) {
                    final p = formSlide.value;
                    return Transform.translate(
                      offset: Offset(0, 520 * (1 - p)),
                      child: Opacity(
                        opacity: p.clamp(0.0, 1.0),
                        child: child,
                      ),
                    );
                  },
                  child: _buildFormCard(context),
                ),

                const SizedBox(height: 20),

                // ==================== FOOTER ====================
                FadeTransition(
                  opacity: footerFade,
                  child: _buildFooter(context),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavyHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 12,
        20,
        24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF062056), Color(0xFF0B2D6E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          // Garis-garis rel dekoratif abstrak di latar header
          Positioned.fill(
            child: CustomPaint(
              painter: _HeaderCurvedLinesPainter(),
            ),
          ),

          Column(
            children: [
              // Baris Navigasi Atas (Kembali)
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    shape: const CircleBorder(),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Judul & Subjudul
              const Text(
                'Selamat Datang',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Masuk untuk pesan tiket dan nikmati perjalanan\nnyaman bersama TKA',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.82),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF062056).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= Field 1: Email / No. HP =================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Email atau No. Handphone',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF062056),
                ),
              ),
              // BADGE HANYA MUNCUL KETIKA SUDAH VALID / TERDAFTAR
              AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _isRegistered ? 1.0 : 0.0,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 250),
                  scale: _isRegistered ? 1.0 : 0.7,
                  curve: Curves.easeOutBack,
                  child: _isRegistered
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFA5D6A7), width: 0.8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 11,
                                color: Color(0xFF2E7D32),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Terdaftar di KAI/TKA',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _identifierController,
            keyboardType: TextInputType.emailAddress,
            onTap: () => setState(() => _hasTouchedIdentifier = true),
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF062056),
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'contoh: penumpang@tka.id',
              hintStyle: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFFACB1C0),
              ),
              prefixIcon: const Icon(
                Icons.mail_outline_rounded,
                color: Color(0xFF8E95A5),
                size: 20,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              filled: true,
              fillColor: const Color(0xFFF9FAFC),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: _identifierError != null
                      ? const Color(0xFFE53935)
                      : const Color(0xFFE2E6EF),
                  width: 1.2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: _identifierError != null
                      ? const Color(0xFFE53935)
                      : const Color(0xFF062056),
                  width: 1.5,
                ),
              ),
            ),
          ),
          if (_identifierError != null) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 13,
                  color: Color(0xFFE53935),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _identifierError!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFE53935),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 18),

          // ================= Field 2: Kata Sandi (Minimal 8 Karakter) =================
          const Text(
            'Kata Sandi',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF062056),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            onTap: () => setState(() => _hasTouchedPassword = true),
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF062056),
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Masukkan kata sandi akun',
              hintStyle: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFFACB1C0),
              ),
              prefixIcon: const Icon(
                Icons.lock_outline_rounded,
                color: Color(0xFF8E95A5),
                size: 20,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFF8E95A5),
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              filled: true,
              fillColor: const Color(0xFFF9FAFC),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: _passwordError != null
                      ? const Color(0xFFE53935)
                      : const Color(0xFFE2E6EF),
                  width: 1.2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: _passwordError != null
                      ? const Color(0xFFE53935)
                      : const Color(0xFF062056),
                  width: 1.5,
                ),
              ),
            ),
          ),
          if (_passwordError != null) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 13,
                  color: Color(0xFFE53935),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _passwordError!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFE53935),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // ================= Baris: Ingat Saya & Lupa Kata Sandi =================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () async {
                  final newVal = !_rememberMe;
                  setState(() => _rememberMe = newVal);
                  await SessionService.setRememberMe(
                    remember: newVal,
                    identifier: newVal ? _identifierController.text.trim() : null,
                  );
                },
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: _rememberMe,
                        activeColor: const Color(0xFFF26716),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) async {
                          final newVal = val ?? false;
                          setState(() => _rememberMe = newVal);
                          await SessionService.setRememberMe(
                            remember: newVal,
                            identifier: newVal ? _identifierController.text.trim() : null,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Ingat Saya',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF062056),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 400),
                      pageBuilder: (_, _, _) => const ForgotPasswordScreen(),
                      transitionsBuilder: (_, anim, _, child) {
                        return SlideTransition(
                          position: Tween(
                            begin: const Offset(1, 0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                          child: child,
                        );
                      },
                    ),
                  );
                },
                child: const Text(
                  'Lupa Kata Sandi?',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF062056),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ================= Baris: Tombol Masuk + Tombol Biometrik =================
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF062056),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Masuk ke Akun',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Tombol Biometrik (Fingerprint)
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F4F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.fingerprint_rounded,
                    color: Color(0xFF062056),
                    size: 28,
                  ),
                  onPressed: _showBiometricDialog,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ================= Pembatas "atau masuk dengan" =================
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade300, thickness: 0.8)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'atau masuk dengan',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF8E95A5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300, thickness: 0.8)),
            ],
          ),

          const SizedBox(height: 16),

          // ================= Tombol: Lanjutkan dengan Google =================
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Menghubungkan dengan Google Auth...'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300, width: 1.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                backgroundColor: Colors.white,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildGoogleIcon(),
                  const SizedBox(width: 10),
                  const Text(
                    'Lanjutkan dengan Google',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF062056),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            fontFamily: 'Roboto',
            foreground: Paint()
              ..shader = const LinearGradient(
                colors: [
                  Color(0xFF4285F4),
                  Color(0xFFEA4335),
                  Color(0xFFFBBC05),
                  Color(0xFF34A853),
                ],
              ).createShader(const Rect.fromLTWH(0, 0, 22, 22)),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Column(
      children: [
        // Ajakan Daftar Akun Baru
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Belum punya akun TKA? ',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6E7582),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    transitionDuration: const Duration(milliseconds: 400),
                    pageBuilder: (_, _, _) => const RegisterScreen(),
                    transitionsBuilder: (_, anim, _, child) {
                      return SlideTransition(
                        position: Tween(
                          begin: const Offset(1, 0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                        child: child,
                      );
                    },
                  ),
                );
              },
              child: const Text(
                'Daftar Sekarang',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFF26716),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Akses Cepat Live Map tanpa Login
        TextButton.icon(
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const DashboardScreen(initialTabIndex: 0),
              ),
            );
          },
          icon: const Icon(Icons.map_rounded, size: 16, color: Color(0xFF062056)),
          label: const Text(
            'Jelajahi Live Map Indonesia (Tanpa Login)',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF062056),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Butuh Bantuan Layanan Pelanggan
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.headset_mic_outlined,
              size: 15,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              'Butuh Bantuan Layanan Pelanggan?',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Badge Keamanan SSL 256-bit
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_rounded,
              size: 13,
              color: Colors.grey.shade500,
            ),
            const SizedBox(width: 5),
            Text(
              'Sistem Keamanan Terenkripsi SSL 256-Bit Resmi TKA',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Painter garis-garis melengkung dekoratif abstrak di header
class _HeaderCurvedLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path1 = Path();
    path1.moveTo(0, size.height * 0.35);
    path1.cubicTo(
      size.width * 0.3,
      size.height * 0.2,
      size.width * 0.7,
      size.height * 0.55,
      size.width,
      size.height * 0.4,
    );
    canvas.drawPath(path1, paint);

    final path2 = Path();
    path2.moveTo(0, size.height * 0.65);
    path2.cubicTo(
      size.width * 0.35,
      size.height * 0.5,
      size.width * 0.65,
      size.height * 0.85,
      size.width,
      size.height * 0.7,
    );
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
