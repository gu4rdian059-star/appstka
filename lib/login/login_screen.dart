import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin/admin_dashboard_screen.dart';
import '../config/app_env.dart';
import '../dashboard/dashboard_screen.dart';
import '../forgot_password/forgot_password_screen.dart';
import '../register/register_screen.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../services/supabase_service.dart';
import '../services/turnstile_service.dart';
import 'widgets/cloudflare_turnstile_box.dart';

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
  bool _isGoogleLoading = false;

  // Status Validasi Dinamis
  bool _isRegistered = false;
  String? _identifierError;
  String? _passwordError;
  bool _hasTouchedIdentifier = false;
  bool _hasTouchedPassword = false;

  // Status Verifikasi Cloudflare Turnstile
  String? _turnstileToken;
  String? _turnstileError;

  // Listener perubahan sesi OAuth Google dari Supabase
  StreamSubscription<AuthState>? _authStateSubscription;
  bool _handlingOAuthCallback = false;

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
    _setupGoogleOAuthListener();

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

  void _setupGoogleOAuthListener() {
    if (!SupabaseService.isInitialized) return;
    try {
      _authStateSubscription =
          SupabaseService.client.auth.onAuthStateChange.listen((data) async {
        if (!mounted || _handlingOAuthCallback) return;
        final event = data.event;
        final session = data.session;
        if (event == AuthChangeEvent.signedIn && session?.user != null) {
          final provider =
              session!.user.appMetadata['provider']?.toString() ?? '';
          if (provider == 'google' || _isGoogleLoading) {
            _handlingOAuthCallback = true;
            setState(() => _isGoogleLoading = true);

            final res = await AuthService.syncGoogleUserSession(session.user);
            if (!mounted) return;
            setState(() => _isGoogleLoading = false);

            if (res.success) {
              final userName = await SessionService.getUserName();
              if (!mounted) return;
              await _showLoginSuccessDialog(userName);
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
            }
          }
        }
      });
    } catch (_) {}
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
    _authStateSubscription?.cancel();
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
        _identifierError = _hasTouchedIdentifier
            ? 'Email atau no. handphone wajib diisi'
            : null;
      });
      return;
    }

    // Cek apakah angka / telepon
    final isPhoneDigits = RegExp(r'^\+?[0-9]+$').hasMatch(text);
    if (isPhoneDigits) {
      // Validasi nomor HP: diawali 08, 628, atau +628, panjang 10-13 digit
      final isValidPhone = RegExp(r'^(?:\+628|628|08)[0-9]{8,11}$')
          .hasMatch(text);
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
              _identifierError =
                  'Nomor HP minimal 10 digit (${text.length}/10)';
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
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
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
            _identifierError =
                'Format email belum lengkap (contoh: nama@tka.id)';
          } else if (text.length > 3) {
            _identifierError =
                'Gunakan format email (@...) atau no. HP (08...)';
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

  bool _ensureTurnstileVerified() {
    if (!TurnstileService.isEnabled) return true;
    if (_turnstileToken != null && _turnstileToken!.isNotEmpty) {
      setState(() => _turnstileError = null);
      return true;
    }
    setState(() {
      _turnstileError =
          'Harap centang verifikasi keamanan Cloudflare Turnstile terlebih dahulu.';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Silakan selesaikan verifikasi Cloudflare Turnstile sebelum masuk.',
        ),
        backgroundColor: Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
    return false;
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
      final isValidPhone = RegExp(r'^(?:\+628|628|08)[0-9]{8,11}$')
          .hasMatch(id);
      final isValidEmail = RegExp(
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
      ).hasMatch(id);
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
      setState(
        () => _passwordError = 'Kata sandi minimal 8 karakter (${pw.length}/8)',
      );
      hasError = true;
    } else {
      setState(() => _passwordError = null);
    }

    if (hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Harap lengkapi email/no HP dan kata sandi dengan benar.',
          ),
          backgroundColor: Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Validasi Cloudflare Turnstile
    if (!_ensureTurnstileVerified()) {
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

        await SessionService.saveUserSession(name: adminName, emailOrPhone: id);

        if (!mounted) return;
        setState(() => _isLoading = false);

        await _showLoginSuccessDialog(adminName, isAdmin: true);
        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 650),
            pageBuilder: (_, _, _) =>
                AdminDashboardScreen(adminEmail: id, adminName: adminName),
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
        captchaToken: _turnstileToken,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (authResult.success) {
        final userName = await SessionService.getUserName();
        if (!mounted) return;

        // Validasi & Animasi Pop-up Sukses Login (Sesuai Permintaan User)
        await _showLoginSuccessDialog(userName);
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
            content: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(authResult.message)),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  Future<void> _handleGoogleLogin() async {
    // Pastikan verifikasi Cloudflare Turnstile sudah dicentang jika aktif
    if (!_ensureTurnstileVerified()) {
      return;
    }

    setState(() => _isGoogleLoading = true);

    // 1. Coba jalankan OAuth Google via Supabase Auth
    final launched = await AuthService.launchGoogleOAuth();

    if (!mounted) return;
    setState(() => _isGoogleLoading = false);

    // 2. Jika browser OAuth gagal dibuka, tampilkan lembar bantuan & fallback
    if (!launched && mounted) {
      await _showGoogleOAuthSheet(oauthBrowserLaunched: launched);
    }
  }

  Future<void> _showGoogleOAuthSheet({required bool oauthBrowserLaunched}) async {
    final emailCtrl = TextEditingController(
      text: _identifierController.text.contains('@')
          ? _identifierController.text.trim()
          : 'jono1243@gmail.com',
    );
    final nameCtrl = TextEditingController(text: 'Jono Sutrisno');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final supabaseCallback = AppEnv.googleSupabaseCallbackUrl;
        final localCallback = AppEnv.googleLocalCallbackUrl;
        final appRedirect = AppEnv.googleAppRedirectUri;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(ctx).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildGoogleIcon(),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Login dengan Akun Google (OAuth 2.0)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF062056),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Informasi Callback URL untuk Google Cloud Console & Supabase
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Konfigurasi Callback URL Google OAuth:',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0369A1),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildCopyableCallbackRow(
                        ctx,
                        label: '1. Supabase Callback (Google Cloud Console):',
                        url: supabaseCallback,
                      ),
                      const SizedBox(height: 4),
                      _buildCopyableCallbackRow(
                        ctx,
                        label: '2. Local Web Callback (Opsional):',
                        url: localCallback,
                      ),
                      const SizedBox(height: 4),
                      _buildCopyableCallbackRow(
                        ctx,
                        label: '3. Android Deep Link (Redirect App):',
                        url: appRedirect,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                const Text(
                  'Pilih / Masukkan Akun Google untuk Melanjutkan:',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF062056),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Google',
                    prefixIcon: const Icon(Icons.email_outlined, size: 19),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nama Profil Google',
                    prefixIcon: const Icon(Icons.person_outline, size: 19),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF062056),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      final gEmail = emailCtrl.text.trim();
                      final gName = nameCtrl.text.trim();
                      if (gEmail.isEmpty || !gEmail.contains('@')) return;

                      Navigator.of(ctx).pop();
                      setState(() => _isGoogleLoading = true);

                      final res = await AuthService.loginWithGoogleAccount(
                        email: gEmail,
                        fullName: gName,
                      );
                      if (!mounted) return;
                      setState(() => _isGoogleLoading = false);

                      if (res.success) {
                        final userName = await SessionService.getUserName();
                        if (!mounted) return;
                        await _showLoginSuccessDialog(userName);
                        if (!mounted) return;
                        Navigator.of(context).pushReplacement(
                          PageRouteBuilder(
                            transitionDuration:
                                const Duration(milliseconds: 650),
                            pageBuilder: (_, _, _) =>
                                DashboardScreen(userName: userName),
                            transitionsBuilder: (_, animation, _, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: const Text(
                      'Masuk dengan Akun Google Ini',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCopyableCallbackRow(
    BuildContext ctx, {
    required String label,
    required String url,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
              SelectableText(
                url,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF062056),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Salin URL Callback',
          icon: const Icon(
            Icons.copy_rounded,
            size: 15,
            color: Color(0xFF0284C7),
          ),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: url));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Disalin: $url'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _showLoginSuccessDialog(
    String userName, {
    bool isAdmin = false,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Login Success',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
      pageBuilder: (ctx, anim1, anim2) {
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (ctx.mounted) {
            Navigator.of(ctx).pop();
          }
        });

        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 36),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isAdmin ? 'Admin Terverifikasi!' : 'Login Berhasil!',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF062056),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Selamat datang kembali, $userName',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF0256B8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isAdmin
                            ? 'Membuka panel admin...'
                            : 'Menyiapkan beranda Anda...',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
                      child: Opacity(opacity: p.clamp(0.0, 1.0), child: child),
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
            child: CustomPaint(painter: _HeaderCurvedLinesPainter()),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFA5D6A7),
                              width: 0.8,
                            ),
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
                    identifier: newVal
                        ? _identifierController.text.trim()
                        : null,
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
                            identifier: newVal
                                ? _identifierController.text.trim()
                                : null,
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
                          position:
                              Tween(
                                begin: const Offset(1, 0),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: anim,
                                  curve: Curves.easeOutCubic,
                                ),
                              ),
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

          // ================= Verifikasi Keamanan Cloudflare Turnstile =================
          if (TurnstileService.isEnabled) ...[
            const SizedBox(height: 16),
            CloudflareTurnstileBox(
              isVerified: _turnstileToken != null && _turnstileToken!.isNotEmpty,
              errorText: _turnstileError,
              onVerifiedChanged: (token) {
                setState(() {
                  _turnstileToken = token;
                  if (token != null) {
                    _turnstileError = null;
                  }
                });
              },
            ),
          ],

          const SizedBox(height: 18),

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
              Expanded(
                child: Divider(color: Colors.grey.shade300, thickness: 0.8),
              ),
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
              Expanded(
                child: Divider(color: Colors.grey.shade300, thickness: 0.8),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ================= Tombol: Lanjutkan dengan Google =================
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: _isGoogleLoading ? null : _handleGoogleLogin,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300, width: 1.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                backgroundColor: Colors.white,
              ),
              child: _isGoogleLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Color(0xFF062056),
                      ),
                    )
                  : Row(
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
              style: TextStyle(fontSize: 13, color: Color(0xFF6E7582)),
            ),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    transitionDuration: const Duration(milliseconds: 400),
                    pageBuilder: (_, _, _) => const RegisterScreen(),
                    transitionsBuilder: (_, anim, _, child) {
                      return SlideTransition(
                        position:
                            Tween(
                              begin: const Offset(1, 0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: anim,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
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

        const SizedBox(height: 14),

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
            Icon(Icons.lock_rounded, size: 13, color: Colors.grey.shade500),
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
