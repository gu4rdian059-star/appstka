import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Warna brand TKA
class TkaColors {
  static const navy = Color(0xFF062056);
  static const orange = Color(0xFFF26716);
  static const grey = Color(0xFF6E7582);
  static const lightGrey = Color(0xFFD5DAE3);
}

/// Menghitung area tempat gambar dirender dengan mode `BoxFit.cover`,
/// supaya sprite (kereta, karakter, HP) bisa diposisikan tepat di atas
/// elemen tertentu pada gambar latar (misalnya rel kereta).
Rect coverRect(
  Size area,
  double imageAspect, {
  Alignment alignment = Alignment.center,
}) {
  final areaAspect = area.width / area.height;
  double w, h;
  if (areaAspect > imageAspect) {
    w = area.width;
    h = w / imageAspect;
  } else {
    h = area.height;
    w = h * imageAspect;
  }
  final dx = (area.width - w) / 2 * (1 + alignment.x);
  final dy = (area.height - h) / 2 * (1 + alignment.y);
  return Rect.fromLTWH(dx, dy, w, h);
}

/// Mixin untuk halaman onboarding: memutar ulang animasi intro setiap kali
/// halaman menjadi aktif, dan menjalankan animasi ambient secara terus-menerus.
mixin OnboardingAnimationMixin<T extends StatefulWidget>
    on State<T>, TickerProviderStateMixin<T> {
  late final AnimationController intro;
  late final AnimationController ambient;

  Duration get introDuration;
  Duration get ambientDuration => const Duration(seconds: 20);
  bool get isActive;

  void initAnimations() {
    intro = AnimationController(vsync: this, duration: introDuration);
    ambient = AnimationController(vsync: this, duration: ambientDuration)
      ..repeat();
    if (isActive) intro.forward(from: 0);
  }

  void onActiveChanged(bool wasActive) {
    if (isActive && !wasActive) {
      intro.forward(from: 0);
    }
  }

  void disposeAnimations() {
    intro.dispose();
    ambient.dispose();
  }
}

/// Layout umum satu halaman onboarding:
/// ilustrasi di atas + kartu putih bergelombang berisi judul & deskripsi.
class OnboardingPageLayout extends StatefulWidget {
  final Widget Function(BuildContext context, Size size) illustrationBuilder;
  final String title;
  final String description;
  final bool isActive;
  final double pageOffset;

  const OnboardingPageLayout({
    super.key,
    required this.illustrationBuilder,
    required this.title,
    required this.description,
    required this.isActive,
    required this.pageOffset,
  });

  /// Tinggi area ilustrasi berdasarkan tinggi layar
  static double illustrationHeightFor(double screenHeight) {
    return (screenHeight - 330).clamp(240.0, screenHeight * 0.62);
  }

  @override
  State<OnboardingPageLayout> createState() => _OnboardingPageLayoutState();
}

class _OnboardingPageLayoutState extends State<OnboardingPageLayout>
    with TickerProviderStateMixin {
  late final AnimationController _textController;
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    if (widget.isActive) _textController.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant OnboardingPageLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _textController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final illH = OnboardingPageLayout.illustrationHeightFor(size.height);
        const waveOverlap = 44.0;

        return Stack(
          children: [
            // Ilustrasi
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: illH + waveOverlap,
              child: ClipRect(
                child: widget.illustrationBuilder(
                  context,
                  Size(size.width, illH + waveOverlap),
                ),
              ),
            ),

            // Kartu putih bergelombang + teks
            Positioned(
              top: illH - waveOverlap * 0.4,
              left: 0,
              right: 0,
              bottom: 0,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _WaveCardPainter(animation: _waveController),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 58, 28, 0),
                    child: _buildTexts(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTexts() {
    final offset = widget.pageOffset;
    final swipeFade = (1.0 - offset.abs() * 1.4).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _textController,
      builder: (context, _) {
        final t = _textController.value;
        final titleP = const Interval(
          0.0,
          0.6,
          curve: Curves.easeOutCubic,
        ).transform(t);
        final descP = const Interval(
          0.25,
          0.85,
          curve: Curves.easeOutCubic,
        ).transform(t);

        // Garis aksen oranye kecil di atas judul
        final accentP = const Interval(
          0.1,
          0.7,
          curve: Curves.easeOutBack,
        ).transform(t);

        return Opacity(
          opacity: swipeFade,
          child: Transform.translate(
            offset: Offset(-offset * 60, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34 * accentP.clamp(0.0, 1.2),
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(
                      colors: [TkaColors.orange, Color(0xFFFF9E40)],
                    ),
                  ),
                ),
                Opacity(
                  opacity: titleP.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - titleP)),
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: TkaColors.navy,
                        height: 1.25,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Opacity(
                  opacity: descP.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, 16 * (1 - descP)),
                    child: Text(
                      widget.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: TkaColors.grey,
                        height: 1.5,
                      ),
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
}

/// Kartu putih dengan tepi atas bergelombang yang bergerak pelan
class _WaveCardPainter extends CustomPainter {
  final Animation<double> animation;

  _WaveCardPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final phase = animation.value * math.pi * 2;
    final w = size.width;
    const base = 26.0;
    final a1 = 9.0 + 3.0 * math.sin(phase);
    final a2 = 8.0 + 3.0 * math.cos(phase);

    final path = Path()..moveTo(0, base - a1 * 0.2);
    path.cubicTo(
      w * 0.25,
      base - a1 * 2.0,
      w * 0.45,
      base + a2 * 1.4,
      w * 0.70,
      base - a2 * 0.6,
    );
    path.cubicTo(
      w * 0.82,
      base - a1 * 1.4,
      w * 0.92,
      base - a1 * 0.6,
      w,
      base - a2 * 1.6,
    );
    path
      ..lineTo(w, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawShadow(path, const Color(0x33062056), 8, false);
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _WaveCardPainter oldDelegate) => false;
}

/// Awan lembut yang bergerak pelan melintasi langit
class DriftingCloudsPainter extends CustomPainter {
  final double t; // 0..1 (berulang)
  final double opacity;
  final double maxY;

  DriftingCloudsPainter({
    required this.t,
    this.opacity = 1.0,
    this.maxY = 0.35,
  });

  static const _clouds = [
    // [posisi awal x (0..1), y (0..1 dari maxY), skala, kecepatan]
    [0.05, 0.20, 1.0, 1.0],
    [0.55, 0.55, 0.7, 1.6],
    [0.85, 0.10, 0.85, 1.25],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    for (final c in _clouds) {
      final scale = c[2] * (size.width / 400);
      final cloudW = 120 * scale;
      final travel = size.width + cloudW * 2;
      final x = ((c[0] + t * c[3]) % 1.0) * travel - cloudW;
      final y = c[1] * size.height * maxY + 10;

      canvas.drawCircle(Offset(x, y), 18 * scale, paint);
      canvas.drawCircle(Offset(x + 24 * scale, y - 10 * scale), 24 * scale, paint);
      canvas.drawCircle(Offset(x + 52 * scale, y - 2 * scale), 19 * scale, paint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 6 * scale, y, 80 * scale, 16 * scale),
          Radius.circular(8 * scale),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DriftingCloudsPainter old) =>
      old.t != t || old.opacity != opacity;
}

/// Burung kecil yang terbang mengepakkan sayap
class FlyingBirdsPainter extends CustomPainter {
  final double t; // 0..1 berulang
  final double opacity;

  FlyingBirdsPainter({required this.t, this.opacity = 1.0});

  static const _birds = [
    // [offset fase, y (0..1), skala, kecepatan]
    [0.00, 0.16, 1.0, 1.0],
    [0.06, 0.20, 0.75, 1.0],
    [0.11, 0.13, 0.6, 1.0],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final paint = Paint()
      ..color = TkaColors.navy.withValues(alpha: 0.55 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < _birds.length; i++) {
      final b = _birds[i];
      final p = ((t * 2.0 * b[3]) - b[0]) % 1.0;
      final x = -30 + p * (size.width + 60);
      final y = b[1] * size.height + math.sin(p * math.pi * 4) * 6;
      final s = b[2] * 9;
      final flap = math.sin((t * 160 + i * 1.7)) * 0.6;

      final path = Path()
        ..moveTo(x - s, y - s * (0.3 + flap))
        ..quadraticBezierTo(x - s * 0.45, y - s * 0.55, x, y)
        ..quadraticBezierTo(x + s * 0.45, y - s * 0.55, x + s, y - s * (0.3 + flap));
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant FlyingBirdsPainter old) => old.t != t;
}

