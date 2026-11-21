import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../login/login_screen.dart';
import 'onboarding1.dart';
import 'onboarding2.dart';
import 'onboarding3.dart';
import 'widgets/onboarding_common.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  static const _pageCount = 3;

  final PageController _pageController = PageController();
  late final AnimationController _ctaController;
  late final AnimationController _transitionController;
  late final Animation<double> _loginSyncAnimation;

  int _currentPage = 0;
  bool _pressed = false;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    // Animasi panah tombol & pulsing glow tombol "Mulai Sekarang"
    _ctaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    // Animasi Transisi TKA Express (Glide & Elevation Fade: 750ms)
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    // Sinkronisasi komponen form Login saat transisi berjalan
    _loginSyncAnimation = CurvedAnimation(
      parent: _transitionController,
      curve: const Interval(0.25, 1.0, curve: Curves.easeOutCubic),
    );

    _transitionController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, _, _) => const LoginScreen(alreadyAnimated: true),
            transitionDuration: Duration.zero,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ctaController.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  bool get _isLastPage => _currentPage == _pageCount - 1;

  double _pageOffsetFor(int index) {
    double page = _currentPage.toDouble();
    if (_pageController.hasClients && _pageController.position.haveDimensions) {
      page = _pageController.page ?? page;
    }
    return page - index;
  }

  void _next() {
    if (_isLastPage) {
      _startJourneyTransition();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _skip() {
    _startJourneyTransition();
  }

  void _startJourneyTransition() {
    if (_isTransitioning) return;
    setState(() {
      _isTransitioning = true;
    });
    _transitionController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF062056),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // ==============================================================
              // JIKA BELUM TRANSISI: Tampilkan PageView Onboarding interaktif
              // ==============================================================
              if (!_isTransitioning) {
                return ColoredBox(
                  color: Colors.white,
                  child: Stack(
                    children: [
                      AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, _) {
                          return PageView(
                            controller: _pageController,
                            onPageChanged: (i) =>
                                setState(() => _currentPage = i),
                            children: [
                              Onboarding1(
                                isActive: _currentPage == 0,
                                pageOffset: _pageOffsetFor(0),
                              ),
                              Onboarding2(
                                isActive: _currentPage == 1,
                                pageOffset: _pageOffsetFor(1),
                              ),
                              Onboarding3(
                                isActive: _currentPage == 2,
                                pageOffset: _pageOffsetFor(2),
                              ),
                            ],
                          );
                        },
                      ),

                      // Tombol "Lewati"
                      Positioned(
                        top: 0,
                        right: 0,
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 10, 14, 0),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: _isLastPage ? 0 : 1,
                              child: IgnorePointer(
                                ignoring: _isLastPage,
                                child: Material(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(20),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: _skip,
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 7,
                                      ),
                                      child: Text(
                                        'Lewati',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: TkaColors.navy,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Indikator titik + tombol aksi utama
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildDots(),
                                const SizedBox(height: 26),
                                _buildButton(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // ==============================================================
              // ANIMASI TRANSISI MODERN TKA EXPRESS (ELEVATION GLIDE & FADE-IN)
              // ==============================================================
              return ClipRect(
                child: AnimatedBuilder(
                  animation: _transitionController,
                  builder: (context, _) {
                    final t = _transitionController.value;

                    // 1. Animasi Keluar Onboarding (Zoom maju halus & dissolve fade-out)
                    final exitOpacity =
                        (1.0 -
                                const Interval(
                                  0.0,
                                  0.55,
                                  curve: Curves.easeInOutCubic,
                                ).transform(t))
                            .clamp(0.0, 1.0);
                    final exitScale =
                        1.0 +
                        0.08 *
                            const Interval(
                              0.0,
                              0.65,
                              curve: Curves.easeOutQuad,
                            ).transform(t);
                    final exitTranslateY =
                        -24.0 *
                        const Interval(
                          0.0,
                          0.65,
                          curve: Curves.easeOutQuad,
                        ).transform(t);

                    // 2. Animasi Masuk Login (Glides up dari bawah + scale 0.94 -> 1.0 + fade in)
                    final enterOpacity = const Interval(
                      0.20,
                      1.0,
                      curve: Curves.easeOutCubic,
                    ).transform(t);
                    final enterScale =
                        0.94 +
                        0.06 *
                            const Interval(
                              0.20,
                              1.0,
                              curve: Curves.easeOutCubic,
                            ).transform(t);
                    final enterTranslateY =
                        55.0 *
                        (1.0 -
                            const Interval(
                              0.20,
                              1.0,
                              curve: Curves.easeOutCubic,
                            ).transform(t));

                    // 3. Efek cahaya transisi oranye lembut di latar
                    final glowOpacity = (math.sin(t * math.pi) * 0.35).clamp(
                      0.0,
                      0.35,
                    );

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background dasar putih bersih
                        const ColoredBox(color: Colors.white),

                        // Pancaran cahaya hangat saat kereta meluncur
                        if (glowOpacity > 0.01)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment.center,
                                  radius: 0.95,
                                  colors: [
                                    TkaColors.orange.withValues(
                                      alpha: glowOpacity,
                                    ),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),

                        // HALAMAN LOGIN TIBA (FADE IN & GLIDE NAIK SECARA ELEGAN)
                        Opacity(
                          opacity: enterOpacity,
                          child: Transform.translate(
                            offset: Offset(0, enterTranslateY),
                            child: Transform.scale(
                              scale: enterScale,
                              child: LoginScreen(
                                externalEntranceAnimation: _loginSyncAnimation,
                              ),
                            ),
                          ),
                        ),

                        // HALAMAN ONBOARDING MENINGGALKAN LAYAR (ZOOM MAJU & FADE OUT)
                        if (exitOpacity > 0.005)
                          IgnorePointer(
                            child: Opacity(
                              opacity: exitOpacity,
                              child: Transform.translate(
                                offset: Offset(0, exitTranslateY),
                                child: Transform.scale(
                                  scale: exitScale,
                                  child: _buildOnboarding3FrozenView(),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Tampilan statis Onboarding 3 saat transisi berlangsung
  Widget _buildOnboarding3FrozenView() {
    return ColoredBox(
      color: Colors.white,
      child: Stack(
        children: [
          const Onboarding3(isActive: true, pageOffset: 0.0),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStaticDots(activeIndex: 2),
                    const SizedBox(height: 26),
                    _buildStaticButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaticDots({required int activeIndex}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_pageCount, (i) {
        final active = i == activeIndex;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? TkaColors.orange : TkaColors.lightGrey,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }

  Widget _buildStaticButton() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: TkaColors.orange,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: TkaColors.orange.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Mulai Sekarang',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: 10),
          Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_pageCount, (i) {
        final active = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? TkaColors.orange : TkaColors.lightGrey,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }

  Widget _buildButton() {
    final color = _isLastPage ? TkaColors.orange : TkaColors.navy;

    return AnimatedBuilder(
      animation: _ctaController,
      builder: (context, child) {
        final v = _ctaController.value;
        final nudge = math.max(0.0, math.sin(v * math.pi * 2)) * 5;
        final glow = _isLastPage ? 0.5 + 0.5 * math.sin(v * math.pi * 2) : 0.0;

        return AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOut,
            height: 54,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.28 + 0.2 * glow),
                  blurRadius: 14 + 10 * glow,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: _next,
                onTapDown: (_) => setState(() => _pressed = true),
                onTapCancel: () => setState(() => _pressed = false),
                onTapUp: (_) => setState(() => _pressed = false),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.4),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: Text(
                        _isLastPage ? 'Mulai Sekarang' : 'Selanjutnya',
                        key: ValueKey(_isLastPage),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Transform.translate(
                      offset: Offset(nudge, 0),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
