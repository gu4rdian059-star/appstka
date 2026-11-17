import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback? onAnimationComplete;

  const SplashScreen({super.key, this.onAnimationComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _ambientController;

  late final List<_SmokeParticle> _smokeParticles;
  late final List<_SparkParticle> _sparkParticles;
  late final List<_SpeedLine> _speedLines;
  late final List<_AmbientSparkle> _ambientSparkles;

  static const double _logoWidth = 228.0;
  static const double _trainAspectRatio = 1024.0 / 276.0;
  static const double _tkaTextAspectRatio = 1024.0 / 274.0;

  // Batas waktu perjalanan kereta (0.00 -> 0.62 dari total 5.2 detik = ~3.2 detik perjalanan kereta)
  static const double _trainStopT = 0.62;

  @override
  void initState() {
    super.initState();

    _smokeParticles = _generateSmokeParticles();
    _sparkParticles = _generateSparkParticles();
    _speedLines = _generateSpeedLines();
    _ambientSparkles = _generateAmbientSparkles();

    // Total durasi 5.2 detik: perjalanan kereta ~3.2 detik sehingga gerakan melambatnya sangat jelas terlihat
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    );

    // Animasi ambient ringan setelah kereta berhenti
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    _introController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            _navigateToOnboarding();
          }
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/images/logo_train.png'), context);
      precacheImage(const AssetImage('assets/images/logo_tka_text.png'), context);
      precacheImage(const AssetImage('assets/images/logo_tka_full.png'), context);
      if (mounted) {
        _introController.forward(from: 0.0);
      }
    });
  }

  void _navigateToOnboarding() {
    if (!mounted) return;
    if (widget.onAnimationComplete != null) {
      widget.onAnimationComplete?.call();
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (_, _, _) => const OnboardingScreen(),
          transitionsBuilder: (_, animation, _, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  List<_SmokeParticle> _generateSmokeParticles() {
    final rng = math.Random(42);
    final particles = <_SmokeParticle>[];

    // 1. Kepulan asap di sepanjang perjalanan kereta dari kiri ke tengah (0.02 -> 0.58)
    for (int i = 0; i < 34; i++) {
      final spawnT = 0.02 + (i / 34.0) * 0.56;
      final isOrangeAccent = i % 3 == 0;
      particles.add(
        _SmokeParticle(
          spawnTime: spawnT,
          lifeSpan: 0.14 + rng.nextDouble() * 0.09,
          offsetXFromTrainTail: -10.0 + rng.nextDouble() * 40.0,
          offsetYFromTrainBase: -2.0 - rng.nextDouble() * 18.0,
          driftX: -48.0 - rng.nextDouble() * 52.0,
          driftY: -12.0 + (rng.nextDouble() - 0.45) * 24.0,
          startRadius: 5.5 + rng.nextDouble() * 5.0,
          endRadius: 19.0 + rng.nextDouble() * 18.0,
          maxOpacity: isOrangeAccent
              ? 0.32 + rng.nextDouble() * 0.14
              : 0.36 + rng.nextDouble() * 0.16,
          isWarmAccent: isOrangeAccent,
        ),
      );
    }

    // 2. Hembusan uap pengereman saat kereta hampir berhenti di tengah (0.54 -> 0.65)
    for (int i = 0; i < 18; i++) {
      final spawnT = 0.54 + (i / 18.0) * 0.11;
      final spreadLeft = i < 11;
      final isOrangeAccent = i % 3 == 0;
      particles.add(
        _SmokeParticle(
          spawnTime: spawnT,
          lifeSpan: 0.16 + rng.nextDouble() * 0.10,
          offsetXFromTrainTail: spreadLeft
              ? 5.0 + rng.nextDouble() * 80.0
              : 90.0 + rng.nextDouble() * 80.0,
          offsetYFromTrainBase: -1.0 + rng.nextDouble() * 5.0,
          driftX: spreadLeft
              ? -40.0 - rng.nextDouble() * 50.0
              : 20.0 + rng.nextDouble() * 40.0,
          driftY: -6.0 - rng.nextDouble() * 18.0,
          startRadius: 6.0 + rng.nextDouble() * 5.5,
          endRadius: 22.0 + rng.nextDouble() * 18.0,
          maxOpacity: isOrangeAccent ? 0.32 : 0.38,
          isWarmAccent: isOrangeAccent,
        ),
      );
    }

    return particles;
  }

  List<_SparkParticle> _generateSparkParticles() {
    final rng = math.Random(77);
    final sparks = <_SparkParticle>[];

    // Percikan roda saat kereta mengerem perlahan (0.30 -> 0.59)
    for (int i = 0; i < 24; i++) {
      final spawnT = 0.30 + (i / 24.0) * 0.29;
      sparks.add(
        _SparkParticle(
          spawnTime: spawnT,
          lifeSpan: 0.07 + rng.nextDouble() * 0.07,
          originXRatio: 0.18 + rng.nextDouble() * 0.55,
          velocityX: -48.0 - rng.nextDouble() * 70.0,
          velocityY: -16.0 - rng.nextDouble() * 28.0,
          gravity: 95.0 + rng.nextDouble() * 55.0,
          size: 1.8 + rng.nextDouble() * 1.8,
          isGold: i.isEven,
        ),
      );
    }
    return sparks;
  }

  List<_SpeedLine> _generateSpeedLines() {
    final rng = math.Random(99);
    return List.generate(12, (i) {
      return _SpeedLine(
        startT: 0.03 + (i * 0.04),
        endT: 0.48 + rng.nextDouble() * 0.12,
        yOffsetRatio: -0.04 + (i / 12.0) * 0.92,
        length: 50.0 + rng.nextDouble() * 65.0,
        thickness: 1.6 + rng.nextDouble() * 1.8,
        isOrange: i % 2 == 0,
      );
    });
  }

  List<_AmbientSparkle> _generateAmbientSparkles() {
    final rng = math.Random(123);
    return List.generate(6, (i) {
      return _AmbientSparkle(
        dxRatio: -0.06 + rng.nextDouble() * 1.12,
        dyRatio: -0.08 + rng.nextDouble() * 1.06,
        phaseOffset: i / 6.0,
        maxRadius: 3.2 + rng.nextDouble() * 3.0,
        isOrange: i.isEven,
      );
    });
  }

  /// Posisi X kereta: masuk dengan kecepatan yang nyaman diikuti mata,
  /// lalu melambat (deselerasi) secara bertahap dan halus hingga berhenti di tengah.
  double _computeTrainOffsetX(double t, double maxSlideDistance) {
    const moveStart = 0.0;
    const moveEnd = _trainStopT;
    if (t <= moveStart) return -maxSlideDistance;
    if (t >= moveEnd) return 0.0;

    final raw = (t - moveStart) / (moveEnd - moveStart);
    // Kurva deselerasi bertahap (tidak langsung melompat cepat di awal)
    final eased = const Cubic(0.22, 0.58, 0.32, 1.0).transform(raw);
    return -maxSlideDistance * (1.0 - eased);
  }

  double _computeTrainPitchAngle(double t) {
    if (t < 0.30) {
      final p = (t / 0.30).clamp(0.0, 1.0);
      return 0.015 * math.sin(p * math.pi * 0.5);
    } else if (t < _trainStopT) {
      final p = ((t - 0.30) / (_trainStopT - 0.30)).clamp(0.0, 1.0);
      return 0.015 * (1.0 - p) - 0.025 * math.sin(p * math.pi);
    } else if (t < 0.72) {
      final p = ((t - _trainStopT) / (0.72 - _trainStopT)).clamp(0.0, 1.0);
      return 0.009 * math.sin(p * math.pi * 2.0) * (1.0 - p);
    }
    return 0.0;
  }

  double _computeTrainBounceY(double t) {
    if (t < _trainStopT - 0.02) {
      return math.sin(t * 110.0) * 0.9 * (1.0 - (t / _trainStopT));
    } else if (t < 0.72) {
      final p = (t - (_trainStopT - 0.02)) / (0.72 - (_trainStopT - 0.02));
      return 2.2 * math.sin(p * math.pi) * (1.0 - p * 0.5);
    }
    return 0.0;
  }

  @override
  void dispose() {
    _introController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxSlideDistance = math.max(screenWidth * 0.78, 300.0);

    final trainHeight = _logoWidth / _trainAspectRatio;
    final tkaTextHeight = _logoWidth / _tkaTextAspectRatio;

    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _navigateToOnboarding,
        child: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _introController,
                _ambientController,
              ]),
              builder: (context, _) {
                final t = _introController.value;
                final ambientT = _ambientController.value;

                // 1. Posisi, rotasi, dan pantulan suspensi kereta
                final trainDx = _computeTrainOffsetX(t, maxSlideDistance);
                final trainDy = _computeTrainBounceY(t);
                final trainPitch = _computeTrainPitchAngle(t);

                double scaleX = 1.0;
                double scaleY = 1.0;
                if (t < 0.42) {
                  final speedStretch = math.sin((t / 0.42) * math.pi) * 0.025;
                  scaleX = 1.0 + speedStretch;
                  scaleY = 1.0 - speedStretch * 0.4;
                } else if (t >= 0.59 && t <= 0.74) {
                  final p = (t - 0.59) / (0.74 - 0.59);
                  final bounce = math.sin(p * math.pi * 1.5) * (1.0 - p);
                  scaleX = 1.0 - 0.032 * bounce;
                  scaleY = 1.0 + 0.044 * bounce;
                }

                // 2. Animasi kemunculan teks logo "TKA" tepat saat kereta berhenti (0.58 -> 0.78)
                final tkaProgress = const Interval(
                  0.58,
                  0.78,
                  curve: Curves.easeOutBack,
                ).transform(t);
                final tkaOpacity = const Interval(
                  0.58,
                  0.70,
                  curve: Curves.easeOut,
                ).transform(t);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Area Logo & Animasi Kereta
                    SizedBox(
                      width: _logoWidth,
                      height: trainHeight + tkaTextHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _TrainEffectsPainter(
                                progress: t,
                                ambientProgress: ambientT,
                                trainDx: trainDx,
                                trainDy: trainDy,
                                logoWidth: _logoWidth,
                                trainHeight: trainHeight,
                                tkaTextHeight: tkaTextHeight,
                                maxSlideDistance: maxSlideDistance,
                                smokeParticles: _smokeParticles,
                                sparkParticles: _sparkParticles,
                                speedLines: _speedLines,
                                ambientSparkles: _ambientSparkles,
                                computeTrainDx: (time) =>
                                    _computeTrainOffsetX(
                                      time,
                                      maxSlideDistance,
                                    ),
                              ),
                            ),
                          ),

                          // Bagian Bawah Logo: "TKA" (Muncul saat kereta berhenti di tengah)
                          Positioned(
                            top: trainHeight,
                            width: _logoWidth,
                            height: tkaTextHeight,
                            child: Opacity(
                              opacity: tkaOpacity.clamp(0.0, 1.0),
                              child: Transform.translate(
                                offset: Offset(
                                  0.0,
                                  16.0 * (1.0 - tkaProgress),
                                ),
                                child: Transform.scale(
                                  scale: 0.86 + (0.14 * tkaProgress),
                                  alignment: Alignment.topCenter,
                                  child: Image.asset(
                                    'assets/images/logo_tka_text.png',
                                    width: _logoWidth,
                                    height: tkaTextHeight,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Bagian Atas Logo: Kereta yang meluncur dari kiri ke tengah
                          Positioned(
                            top: 0,
                            width: _logoWidth,
                            height: trainHeight,
                            child: Transform.translate(
                              offset: Offset(trainDx, trainDy),
                              child: Transform.rotate(
                                angle: trainPitch,
                                alignment: Alignment.bottomCenter,
                                child: Transform.scale(
                                  scaleX: scaleX,
                                  scaleY: scaleY,
                                  alignment: Alignment.bottomCenter,
                                  child: Image.asset(
                                    'assets/images/logo_train.png',
                                    width: _logoWidth,
                                    height: trainHeight,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // 4. Animasi Judul "Tiket Kereta Api" yang Ringan, Halus & Menarik Perhatian
                    _buildLightweightAttractiveTitle(t, ambientT),

                    const SizedBox(height: 10),

                    // 5. Animasi Keterangan dengan Highlight Kata Kunci yang Halus
                    _buildLightweightAttractiveSubtitle(t, ambientT),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLightweightAttractiveTitle(double t, double ambientT) {
    final enterCurve = const Interval(
      0.66,
      0.86,
      curve: Curves.easeOutBack,
    ).transform(t);
    final opacity = const Interval(
      0.66,
      0.78,
      curve: Curves.easeOut,
    ).transform(t);

    final letterSpacing = 2.2 - (2.6 * enterCurve.clamp(0.0, 1.0));
    final dy = 14.0 * (1.0 - enterCurve);
    final scale = 0.92 + (0.08 * enterCurve);

    double shimmerPos = -1.5;
    if (t >= 0.76 && t <= 0.96) {
      final p = (t - 0.76) / (0.96 - 0.76);
      shimmerPos = -1.2 + (p * 2.4);
    } else if (t > 0.96) {
      final idleCycle = ((ambientT + 0.35) % 1.0);
      if (idleCycle < 0.55) {
        shimmerPos = -1.2 + ((idleCycle / 0.55) * 2.4);
      }
    }

    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0.0, dy),
        child: Transform.scale(
          scale: scale,
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment(shimmerPos - 0.45, -0.3),
                end: Alignment(shimmerPos + 0.45, 0.3),
                colors: const [
                  Color(0xFF062056),
                  Color(0xFFF26716),
                  Color(0xFFFF9E40),
                  Color(0xFF062056),
                ],
                stops: const [0.0, 0.45, 0.55, 1.0],
              ).createShader(bounds);
            },
            child: Text(
              'Tiket Kereta Api',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF062056),
                letterSpacing: letterSpacing,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLightweightAttractiveSubtitle(double t, double ambientT) {
    final enterProgress = const Interval(
      0.74,
      0.94,
      curve: Curves.easeOutCubic,
    ).transform(t);

    final dy = 12.0 * (1.0 - enterProgress);

    double keywordGlow = 0.0;
    if (t >= 0.78 && t <= 0.98) {
      keywordGlow = math.sin(((t - 0.78) / 0.20) * math.pi);
    } else if (t > 0.98) {
      keywordGlow = 0.22 * (0.5 + 0.5 * math.sin(ambientT * math.pi * 2));
    }

    final keywordColor =
        Color.lerp(
          const Color(0xFF6E7582),
          const Color(0xFFF26716),
          (keywordGlow * 0.75).clamp(0.0, 1.0),
        ) ??
        const Color(0xFF6E7582);

    return Opacity(
      opacity: enterProgress.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0.0, dy),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Text.rich(
            TextSpan(
              text: 'Pemesanan tiket kereta ',
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6E7582),
                height: 1.45,
              ),
              children: [
                TextSpan(
                  text: 'resmi, cepat,',
                  style: TextStyle(
                    color: keywordColor,
                    fontWeight: keywordGlow > 0.25
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                const TextSpan(text: ' dan\n'),
                TextSpan(
                  text: 'mudah',
                  style: TextStyle(
                    color: keywordColor,
                    fontWeight: keywordGlow > 0.25
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _SmokeParticle {
  final double spawnTime;
  final double lifeSpan;
  final double offsetXFromTrainTail;
  final double offsetYFromTrainBase;
  final double driftX;
  final double driftY;
  final double startRadius;
  final double endRadius;
  final double maxOpacity;
  final bool isWarmAccent;

  const _SmokeParticle({
    required this.spawnTime,
    required this.lifeSpan,
    required this.offsetXFromTrainTail,
    required this.offsetYFromTrainBase,
    required this.driftX,
    required this.driftY,
    required this.startRadius,
    required this.endRadius,
    required this.maxOpacity,
    required this.isWarmAccent,
  });
}

class _SparkParticle {
  final double spawnTime;
  final double lifeSpan;
  final double originXRatio;
  final double velocityX;
  final double velocityY;
  final double gravity;
  final double size;
  final bool isGold;

  const _SparkParticle({
    required this.spawnTime,
    required this.lifeSpan,
    required this.originXRatio,
    required this.velocityX,
    required this.velocityY,
    required this.gravity,
    required this.size,
    required this.isGold,
  });
}

class _SpeedLine {
  final double startT;
  final double endT;
  final double yOffsetRatio;
  final double length;
  final double thickness;
  final bool isOrange;

  const _SpeedLine({
    required this.startT,
    required this.endT,
    required this.yOffsetRatio,
    required this.length,
    required this.thickness,
    required this.isOrange,
  });
}

class _AmbientSparkle {
  final double dxRatio;
  final double dyRatio;
  final double phaseOffset;
  final double maxRadius;
  final bool isOrange;

  const _AmbientSparkle({
    required this.dxRatio,
    required this.dyRatio,
    required this.phaseOffset,
    required this.maxRadius,
    required this.isOrange,
  });
}

class _TrainEffectsPainter extends CustomPainter {
  final double progress;
  final double ambientProgress;
  final double trainDx;
  final double trainDy;
  final double logoWidth;
  final double trainHeight;
  final double tkaTextHeight;
  final double maxSlideDistance;
  final List<_SmokeParticle> smokeParticles;
  final List<_SparkParticle> sparkParticles;
  final List<_SpeedLine> speedLines;
  final List<_AmbientSparkle> ambientSparkles;
  final double Function(double t) computeTrainDx;

  _TrainEffectsPainter({
    required this.progress,
    required this.ambientProgress,
    required this.trainDx,
    required this.trainDy,
    required this.logoWidth,
    required this.trainHeight,
    required this.tkaTextHeight,
    required this.maxSlideDistance,
    required this.smokeParticles,
    required this.sparkParticles,
    required this.speedLines,
    required this.ambientSparkles,
    required this.computeTrainDx,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintArrivalShockwaves(canvas, size);
    _paintAnimatedRailwayTrack(canvas, size);
    _paintHeadlightCone(canvas, size);
    _paintSmokePuffs(canvas, size);
    _paintBrakingSparks(canvas, size);
    _paintSonicWindArc(canvas, size);
    _paintSpeedLines(canvas, size);
    _paintHeadlightGleam(canvas, size);
    _paintAmbientSparkles(canvas, size);
  }

  void _paintArrivalShockwaves(Canvas canvas, Size size) {
    if (progress < 0.58 || progress > 0.86) return;

    for (int ring = 0; ring < 2; ring++) {
      final start = 0.58 + ring * 0.05;
      final end = 0.81 + ring * 0.05;
      if (progress < start || progress > end) continue;

      final p = ((progress - start) / (end - start)).clamp(0.0, 1.0);
      final easeP = Curves.easeOutQuart.transform(p);
      final alpha = (1.0 - p) * (ring == 0 ? 0.28 : 0.22);

      final center = Offset(logoWidth * 0.52, trainHeight * 0.75);
      final radiusX = logoWidth * (0.35 + 0.48 * easeP);
      final radiusY = trainHeight * (0.38 + 0.65 * easeP);

      final rect = Rect.fromCenter(
        center: center,
        width: radiusX * 2,
        height: radiusY * 2,
      );

      final color = ring == 0
          ? const Color(0xFFF26716)
          : const Color(0xFF062056);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (3.0 - ring * 0.8) * (1.0 - p * 0.6)
        ..color = color.withValues(alpha: alpha);

      canvas.drawOval(rect, paint);
    }
  }

  void _paintAnimatedRailwayTrack(Canvas canvas, Size size) {
    if (progress <= 0.01 || progress >= 0.70) return;

    final fadeOut = progress > 0.56
        ? (1.0 - ((progress - 0.56) / (0.70 - 0.56))).clamp(0.0, 1.0)
        : 1.0;

    final trackY = trainHeight - 1.5;
    final leftStart = trainDx - 120.0;
    final rightEnd = math.min(logoWidth * 1.05, trainDx + logoWidth * 0.98);
    if (rightEnd <= leftStart) return;

    final rect = Rect.fromLTRB(leftStart, trackY - 2, rightEnd, trackY + 4);
    final railPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFF26716).withValues(alpha: 0.0),
          const Color(0xFFF26716).withValues(alpha: 0.55 * fadeOut),
          const Color(0xFF062056).withValues(alpha: 0.75 * fadeOut),
          const Color(0xFFF26716).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.35, 0.88, 1.0],
      ).createShader(rect)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(leftStart, trackY),
      Offset(rightEnd, trackY),
      railPaint,
    );

    final sleeperPaint = Paint()
      ..color = const Color(0xFF062056).withValues(alpha: 0.28 * fadeOut)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    const spacing = 14.0;
    final startIdx = (leftStart / spacing).floor();
    final endIdx = (rightEnd / spacing).ceil();

    for (int i = startIdx; i <= endIdx; i++) {
      final x = i * spacing;
      if (x < leftStart + 10 || x > rightEnd - 6) continue;
      final distRatio = ((x - leftStart) / (rightEnd - leftStart)).clamp(
        0.0,
        1.0,
      );
      final edgeAlpha = math.sin(distRatio * math.pi) * 0.32 * fadeOut;
      sleeperPaint.color = const Color(
        0xFF062056,
      ).withValues(alpha: edgeAlpha);

      canvas.drawLine(
        Offset(x, trackY + 2.5),
        Offset(x - 4.5, trackY + 6.5),
        sleeperPaint,
      );
    }
  }

  void _paintHeadlightCone(Canvas canvas, Size size) {
    if (progress < 0.06 || progress > 0.72) return;

    double intensity = 1.0;
    if (progress < 0.20) {
      intensity = (progress - 0.06) / 0.14;
    } else if (progress > 0.58) {
      intensity = 1.0 - ((progress - 0.58) / (0.72 - 0.58));
    }
    intensity = intensity.clamp(0.0, 1.0);
    if (intensity <= 0.01) return;

    final nosePos = Offset(
      trainDx + logoWidth * 0.82,
      trainDy + trainHeight * 0.68,
    );
    final coneLength = 80.0 * intensity;

    final path = Path()
      ..moveTo(nosePos.dx, nosePos.dy - 2.0)
      ..lineTo(nosePos.dx + coneLength, nosePos.dy - 18.0)
      ..lineTo(nosePos.dx + coneLength, nosePos.dy + 15.0)
      ..lineTo(nosePos.dx, nosePos.dy + 3.0)
      ..close();

    final rect = Rect.fromLTWH(
      nosePos.dx,
      nosePos.dy - 20.0,
      coneLength,
      38.0,
    );

    final conePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFFF9800).withValues(alpha: 0.34 * intensity),
          const Color(0xFFFFCC80).withValues(alpha: 0.12 * intensity),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);

    canvas.drawPath(path, conePaint);
  }

  void _paintSmokePuffs(Canvas canvas, Size size) {
    for (final p in smokeParticles) {
      if (progress < p.spawnTime || progress > p.spawnTime + p.lifeSpan) {
        continue;
      }

      final lifeT = ((progress - p.spawnTime) / p.lifeSpan).clamp(0.0, 1.0);
      final easeLife = Curves.easeOutCubic.transform(lifeT);

      final spawnTrainDx = computeTrainDx(p.spawnTime);
      final originX = spawnTrainDx + p.offsetXFromTrainTail;
      final originY = trainHeight + p.offsetYFromTrainBase;

      final currentX = originX + p.driftX * easeLife;
      final currentY =
          originY + p.driftY * easeLife - (8.0 * math.sin(lifeT * math.pi));
      final radius =
          p.startRadius + (p.endRadius - p.startRadius) * easeLife;

      final fadeIn = (lifeT / 0.20).clamp(0.0, 1.0);
      final fadeOut = math.pow(1.0 - lifeT, 1.4).toDouble();
      final alpha = (p.maxOpacity * fadeIn * fadeOut).clamp(0.0, 1.0);

      if (alpha <= 0.005) continue;

      final baseColor = p.isWarmAccent
          ? const Color(0xFFF47B2A)
          : const Color(0xFFA8BBD6);

      final cloudPaint = Paint()
        ..color = baseColor.withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);

      canvas.drawCircle(Offset(currentX, currentY), radius, cloudPaint);
      canvas.drawCircle(
        Offset(currentX - radius * 0.45, currentY + radius * 0.15),
        radius * 0.72,
        cloudPaint,
      );
    }
  }

  void _paintBrakingSparks(Canvas canvas, Size size) {
    for (final s in sparkParticles) {
      if (progress < s.spawnTime || progress > s.spawnTime + s.lifeSpan) {
        continue;
      }

      final lifeT = ((progress - s.spawnTime) / s.lifeSpan).clamp(0.0, 1.0);
      final spawnTrainDx = computeTrainDx(s.spawnTime);

      final startX = spawnTrainDx + logoWidth * s.originXRatio;
      final startY = trainHeight - 2.0;

      final dx = s.velocityX * lifeT;
      double dy = s.velocityY * lifeT + 0.5 * s.gravity * lifeT * lifeT;
      if (dy > 0) {
        dy = -dy * 0.45;
      }

      final currentPos = Offset(startX + dx, startY + dy);
      final prevT = (lifeT - 0.18).clamp(0.0, 1.0);
      final prevDx = s.velocityX * prevT;
      double prevDy = s.velocityY * prevT + 0.5 * s.gravity * prevT * prevT;
      if (prevDy > 0) prevDy = -prevDy * 0.45;
      final tailPos = Offset(startX + prevDx, startY + prevDy);

      final alpha = (1.0 - lifeT).clamp(0.0, 1.0);
      final sparkColor = s.isGold
          ? const Color(0xFFFFB300)
          : const Color(0xFFF26716);

      final sparkPaint = Paint()
        ..color = sparkColor.withValues(alpha: alpha)
        ..strokeWidth = s.size * (1.0 - lifeT * 0.4)
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(tailPos, currentPos, sparkPaint);
    }
  }

  void _paintSonicWindArc(Canvas canvas, Size size) {
    if (progress < 0.04 || progress > 0.58) return;

    final p = ((progress - 0.04) / (0.58 - 0.04)).clamp(0.0, 1.0);
    final alpha = math.sin(p * math.pi) * 0.42;
    if (alpha <= 0.01) return;

    final noseX = trainDx + logoWidth * 0.94;
    final noseY = trainDy + trainHeight * 0.58;

    final arcRect = Rect.fromCenter(
      center: Offset(noseX - 8.0, noseY),
      width: 34.0,
      height: trainHeight * 0.85,
    );

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF062056).withValues(alpha: 0.0),
          const Color(0xFFF26716).withValues(alpha: alpha),
          const Color(0xFF062056).withValues(alpha: alpha),
          const Color(0xFF062056).withValues(alpha: 0.0),
        ],
      ).createShader(arcRect);

    canvas.drawArc(arcRect, -math.pi * 0.38, math.pi * 0.76, false, arcPaint);
  }

  void _paintSpeedLines(Canvas canvas, Size size) {
    for (final line in speedLines) {
      if (progress < line.startT || progress > line.endT) continue;

      final localT =
          ((progress - line.startT) / (line.endT - line.startT)).clamp(
            0.0,
            1.0,
          );
      final alpha = math.sin(localT * math.pi) * 0.68;
      if (alpha <= 0.01) continue;

      final y = trainHeight * line.yOffsetRatio;
      final currentLength = line.length * math.sin(localT * math.pi);
      final rightX = trainDx + 32.0 - (localT * 42.0);
      final leftX = rightX - currentLength;

      final color = line.isOrange
          ? const Color(0xFFF26716)
          : const Color(0xFF062056);

      final rect = Rect.fromLTRB(leftX, y - 2, rightX, y + 2);
      final paint = Paint()
        ..strokeWidth = line.thickness
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            color.withValues(alpha: 0.0),
            color.withValues(alpha: alpha),
          ],
        ).createShader(rect);

      canvas.drawLine(Offset(leftX, y), Offset(rightX, y), paint);
    }
  }

  void _paintHeadlightGleam(Canvas canvas, Size size) {
    if (progress < 0.58) return;

    double intensity = 0.0;
    if (progress <= 0.84) {
      final p = ((progress - 0.58) / (0.84 - 0.58)).clamp(0.0, 1.0);
      intensity = math.sin(p * math.pi);
    } else {
      intensity = 0.25 + 0.25 * math.sin(ambientProgress * math.pi * 2);
    }

    if (intensity <= 0.01) return;

    final headlightPos = Offset(
      trainDx + logoWidth * 0.80,
      trainDy + trainHeight * 0.70,
    );

    final glowPaint = Paint()
      ..color = const Color(0xFFF26716).withValues(alpha: 0.35 * intensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
    canvas.drawCircle(headlightPos, 11.0 * intensity, glowPaint);

    final starPaint = Paint()
      ..color = Colors.white.withValues(
        alpha: (0.95 * intensity).clamp(0.0, 1.0),
      )
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final arm = 10.5 * intensity;
    canvas.drawLine(
      headlightPos.translate(-arm, 0),
      headlightPos.translate(arm, 0),
      starPaint,
    );
    canvas.drawLine(
      headlightPos.translate(0, -arm),
      headlightPos.translate(0, arm),
      starPaint,
    );
  }

  void _paintAmbientSparkles(Canvas canvas, Size size) {
    if (progress < 0.66) return;

    final masterFade = ((progress - 0.66) / 0.22).clamp(0.0, 1.0);

    for (final s in ambientSparkles) {
      final localPhase = (ambientProgress + s.phaseOffset) % 1.0;
      final pulse = math.sin(localPhase * math.pi);
      final alpha = pulse * 0.62 * masterFade;
      if (alpha <= 0.02) continue;

      final pos = Offset(
        logoWidth * s.dxRatio,
        (trainHeight + tkaTextHeight) * s.dyRatio,
      );
      final r = s.maxRadius * pulse;

      final color = s.isOrange
          ? const Color(0xFFF26716)
          : const Color(0xFF062056);

      final paint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(pos.translate(-r, 0), pos.translate(r, 0), paint);
      canvas.drawLine(pos.translate(0, -r), pos.translate(0, r), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrainEffectsPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.ambientProgress != ambientProgress ||
        oldDelegate.trainDx != trainDx;
  }
}
