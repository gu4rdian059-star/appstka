import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'widgets/onboarding_common.dart';

/// Onboarding 1 — "Pesan Tiket Kereta Jadi Lebih Mudah"
/// Fitur:
/// - Latar pemandangan viaduk jembatan pegunungan beresolusi tinggi (ob1_background.jpg).
/// - Kereta telah dihapus sesuai permintaan pengguna, digantikan dengan objek animasi yang indah & hidup:
///   1. Balon Udara Wisata TKA (Hot Air Balloons) warna oranye-navy yang melayang anggun di langit pegunungan.
///   2. Kawanan burung (Flock of Birds) yang mengepakkan sayap dan terbang melintasi langit menuju matahari terbit.
///   3. Sinar matahari pagi (Sunbeams & Glow) yang berpendar hangat dengan partikel kilau keemasan.
///   4. Daun dan kelopak bunga yang melayang lembut tertiup semilir angin pegunungan.
/// - Logo TKA resmi bersih di pill bagian atas tengah.
class Onboarding1 extends StatefulWidget {
  final bool isActive;
  final double pageOffset;

  const Onboarding1({
    super.key,
    required this.isActive,
    required this.pageOffset,
  });

  @override
  State<Onboarding1> createState() => _Onboarding1State();
}

class _Onboarding1State extends State<Onboarding1>
    with TickerProviderStateMixin, OnboardingAnimationMixin {
  static const _bgAsset = 'assets/images/onboarding/ob1_background.jpg';

  @override
  Duration get introDuration => const Duration(milliseconds: 3200);

  @override
  bool get isActive => widget.isActive;

  @override
  void initState() {
    super.initState();
    initAnimations();
  }

  @override
  void didUpdateWidget(covariant Onboarding1 oldWidget) {
    super.didUpdateWidget(oldWidget);
    onActiveChanged(oldWidget.isActive);
  }

  @override
  void dispose() {
    disposeAnimations();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingPageLayout(
      isActive: widget.isActive,
      pageOffset: widget.pageOffset,
      title: 'Pesan Tiket Kereta\nJadi Lebih Mudah',
      description:
          'Temukan, pesan, dan kelola tiket\nkereta api dalam satu aplikasi.',
      illustrationBuilder: _buildScene,
    );
  }

  Widget _buildScene(BuildContext context, Size size) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final rect = coverRect(
      size,
      896 / 1200,
      alignment: const Alignment(0, 0.20),
    );

    return AnimatedBuilder(
      animation: Listenable.merge([intro, ambient]),
      builder: (context, _) {
        final t = intro.value;
        final a = ambient.value;
        final kenBurns = 1.04 - 0.04 * Curves.easeOutCubic.transform(t);
        final parallax = widget.pageOffset * size.width * 0.35;

        final logoP = const Interval(
          0.05,
          0.45,
          curve: Curves.easeOutBack,
        ).transform(t);

        return Stack(
          children: [
            // ==================== 1. LATAR PEMANDANGAN ALAM & ANIMASI LANGIT ====================
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(parallax, 0),
                child: Transform.scale(
                  scale: kenBurns,
                  child: Stack(
                    children: [
                      // Gambar latar jembatan viaduk & pegunungan yang bersih & tajam
                      Positioned.fromRect(
                        rect: rect,
                        child: Image.asset(
                          _bgAsset,
                          fit: BoxFit.fill,
                          alignment: const Alignment(0, 0.20),
                        ),
                      ),

                      // Animasi Objek Hidup: Balon Udara, Burung Terbang, Sinar Matahari, & Kelopak Daun
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ScenicAtmospherePainter(
                            rect: rect,
                            intro: t,
                            ambient: a,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ==================== 2. LOGO TKA RESMI DI ATAS TENGAH ====================
            Positioned(
              top: topPadding + 10,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: logoP.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, -18 * (1 - logoP)),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: TkaColors.navy.withValues(alpha: 0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/logo_tka_full.png',
                        height: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Melukis elemen animasi pemandangan alam yang hidup & estetik:
/// - Balon Udara Wisata TKA (Hot Air Balloon)
/// - Kawanan Burung Terbang Melayang (Flying Birds)
/// - Sinar Matahari Hangat & Partikel Kilau Keemasan
/// - Daun & Kelopak Bunga Tertiup Semilir Angin
class _ScenicAtmospherePainter extends CustomPainter {
  final Rect rect;
  final double intro;
  final double ambient;

  _ScenicAtmospherePainter({
    required this.rect,
    required this.intro,
    required this.ambient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;

    // ==================== 1. SINAR & KILAU MATAHARI PAGI ====================
    final sunCenter = Offset(
      rect.left + rect.width * 0.74,
      rect.top + rect.height * 0.28,
    );
    final sunPulse = 0.88 + 0.12 * math.sin(ambient * math.pi * 2 * 3);

    // Pancaran Cahaya Lembut Matahari
    canvas.drawCircle(
      sunCenter,
      rect.width * 0.28 * sunPulse,
      Paint()
        ..color = const Color(0xFFFFE0B2).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
    );

    // ==================== 2. BALON UDARA WISATA TKA (HOT AIR BALLOONS) ====================
    // Balon Utama (Besar, Dekat Pegunungan Kiri)
    final b1BaseX = rect.left + rect.width * 0.28;
    final b1BaseY = rect.top + rect.height * 0.32;
    final b1Float = math.sin(ambient * math.pi * 2 * 2) * 6.0;
    final b1Drift = math.sin(ambient * math.pi * 2) * 12.0;

    _drawHotAirBalloon(
      canvas: canvas,
      center: Offset(b1BaseX + b1Drift, b1BaseY + b1Float),
      width: 38.0,
      height: 48.0,
      scale: 0.95 + 0.05 * intro,
    );

    // Balon Kedua (Kecil, Kejauhan di Dekat Matahari)
    final b2BaseX = rect.left + rect.width * 0.82;
    final b2BaseY = rect.top + rect.height * 0.22;
    final b2Float = math.sin(ambient * math.pi * 2 * 2 + 1.8) * 4.5;
    final b2Drift = -math.cos(ambient * math.pi * 2) * 8.0;

    _drawHotAirBalloon(
      canvas: canvas,
      center: Offset(b2BaseX + b2Drift, b2BaseY + b2Float),
      width: 20.0,
      height: 26.0,
      scale: 0.85,
    );

    // ==================== 3. KAWANAN BURUNG TERBANG MELAYANG (FLOCK OF BIRDS) ====================
    // Kawanan burung terbang anggun melintasi langit pegunungan menuju matahari
    final birdFlockSpeed = (ambient * 1.8) % 1.0;
    final flockBaseX = rect.left - 60 + birdFlockSpeed * (w + 140);
    final flockBaseY = rect.top + rect.height * 0.20;

    final birdOffsets = [
      const Offset(0, 0),
      const Offset(-22, 10),
      const Offset(-16, -12),
      const Offset(-38, 6),
      const Offset(-42, -8),
    ];

    for (int i = 0; i < birdOffsets.length; i++) {
      final birdPos = Offset(
        flockBaseX + birdOffsets[i].dx,
        flockBaseY +
            birdOffsets[i].dy +
            math.sin(ambient * math.pi * 2 * 3 + i) * 3,
      );
      if (birdPos.dx > -30 && birdPos.dx < w + 30) {
        _drawFlyingBird(
          canvas: canvas,
          position: birdPos,
          wingPhase: ambient * math.pi * 2 * 10 + i * 1.2,
          size: i == 0 ? 11.0 : 8.5,
        );
      }
    }

    // ==================== 4. KELOPAK BUNGA & DAUN MELAYANG TERTUP ANGIN ====================
    for (int i = 0; i < 7; i++) {
      final p = (ambient * 1.5 + i * 0.16) % 1.0;
      final px =
          rect.left +
          rect.width * 0.05 +
          p * rect.width * 0.85 +
          math.sin(p * math.pi * 3 + i) * 20;
      final py =
          rect.top +
          rect.height * 0.10 +
          p * rect.height * 0.70 +
          math.cos(p * math.pi * 2 + i) * 15;
      final alpha = math.sin(p * math.pi).clamp(0.0, 1.0) * 0.75;
      if (alpha <= 0.02) continue;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p * math.pi * 4 + i);

      final petalPaint = Paint()
        ..color =
            (i % 2 == 0 ? const Color(0xFFF26716) : const Color(0xFF10B981))
                .withValues(alpha: alpha);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 8.0, height: 4.0),
        petalPaint,
      );
      canvas.restore();
    }

    // ==================== 5. PARTIKEL KILAU EMAS (GOLDEN SPARKLES) ====================
    final sparkles = [
      Offset(rect.left + rect.width * 0.65, rect.top + rect.height * 0.24),
      Offset(rect.left + rect.width * 0.84, rect.top + rect.height * 0.18),
      Offset(rect.left + rect.width * 0.76, rect.top + rect.height * 0.36),
      Offset(rect.left + rect.width * 0.45, rect.top + rect.height * 0.16),
    ];

    for (int i = 0; i < sparkles.length; i++) {
      final pulse = 0.55 + 0.45 * math.sin(ambient * math.pi * 2 * 4 + i * 1.7);
      _drawSparkleStar(canvas, sparkles[i], 6.0 * pulse);
    }
  }

  /// Melukis satu Balon Udara Wisata TKA yang anggun & penuh warna
  void _drawHotAirBalloon({
    required Canvas canvas,
    required Offset center,
    required double width,
    required double height,
    required double scale,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);

    final halfW = width * 0.5;
    final envelopeH = height * 0.78;

    // 1. Bentuk Balon Udara (Kubah atas melengkung membulat, mengerucut ke leher bawah)
    final balloonPath = Path()
      ..moveTo(0, -envelopeH * 0.5)
      ..cubicTo(
        halfW * 1.25,
        -envelopeH * 0.5,
        halfW * 1.05,
        envelopeH * 0.15,
        halfW * 0.40,
        envelopeH * 0.50,
      )
      ..lineTo(-halfW * 0.40, envelopeH * 0.50)
      ..cubicTo(
        -halfW * 1.05,
        envelopeH * 0.15,
        -halfW * 1.25,
        -envelopeH * 0.5,
        0,
        -envelopeH * 0.5,
      )
      ..close();

    // Warna Dasar Balon Udara (Putih Gading)
    canvas.drawPath(balloonPath, Paint()..color = const Color(0xFFFFFBEB));

    // Garis Kontur Halus Balon
    canvas.drawPath(
      balloonPath,
      Paint()
        ..color = const Color(0xFF062056).withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Garis Garis Warna Khas TKA (Garis Balap Oranye & Navy di Balon)
    canvas.save();
    canvas.clipPath(balloonPath);

    // Jalur Tengah Oranye TKA
    final stripeOrange = Path()
      ..moveTo(-halfW * 0.22, -envelopeH * 0.5)
      ..lineTo(halfW * 0.22, -envelopeH * 0.5)
      ..lineTo(halfW * 0.12, envelopeH * 0.50)
      ..lineTo(-halfW * 0.12, envelopeH * 0.50)
      ..close();
    canvas.drawPath(stripeOrange, Paint()..color = TkaColors.orange);

    // Jalur Kiri & Kanan Navy
    final stripeNavyLeft = Path()
      ..moveTo(-halfW * 0.65, -envelopeH * 0.45)
      ..lineTo(-halfW * 0.32, -envelopeH * 0.48)
      ..lineTo(-halfW * 0.18, envelopeH * 0.50)
      ..lineTo(-halfW * 0.36, envelopeH * 0.50)
      ..close();
    canvas.drawPath(stripeNavyLeft, Paint()..color = TkaColors.navy);

    final stripeNavyRight = Path()
      ..moveTo(halfW * 0.32, -envelopeH * 0.48)
      ..lineTo(halfW * 0.65, -envelopeH * 0.45)
      ..lineTo(halfW * 0.36, envelopeH * 0.50)
      ..lineTo(halfW * 0.18, envelopeH * 0.50)
      ..close();
    canvas.drawPath(stripeNavyRight, Paint()..color = TkaColors.navy);

    // Efek Pencahayaan 3D Balon (Kilau Sisi Kiri)
    final highlightPath = Path()
      ..moveTo(-halfW * 0.85, -envelopeH * 0.25)
      ..quadraticBezierTo(
        -halfW * 0.95,
        -envelopeH * 0.05,
        -halfW * 0.70,
        envelopeH * 0.15,
      )
      ..quadraticBezierTo(
        -halfW * 0.55,
        -envelopeH * 0.05,
        -halfW * 0.75,
        -envelopeH * 0.25,
      )
      ..close();
    canvas.drawPath(
      highlightPath,
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );

    canvas.restore();

    // 2. Tali Gantung Keranjang Balon
    final ropePaint = Paint()
      ..color = const Color(0xFF475569)
      ..strokeWidth = 0.8;
    final basketY = envelopeH * 0.66;
    canvas.drawLine(
      Offset(-halfW * 0.30, envelopeH * 0.50),
      Offset(-halfW * 0.18, basketY),
      ropePaint,
    );
    canvas.drawLine(
      Offset(halfW * 0.30, envelopeH * 0.50),
      Offset(halfW * 0.18, basketY),
      ropePaint,
    );

    // 3. Keranjang Anyaman Penumpang (Wicker Basket)
    final basketRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, basketY + 3.0),
        width: halfW * 0.44,
        height: 6.5,
      ),
      const Radius.circular(1.5),
    );
    canvas.drawRRect(basketRect, Paint()..color = const Color(0xFF92400E));

    // Cahaya Nyala Api Pemanas Balon (Burner Flicker)
    final burnerPulse = 0.7 + 0.3 * math.sin(ambient * math.pi * 2 * 12);
    canvas.drawCircle(
      Offset(0, envelopeH * 0.52),
      2.0 * burnerPulse,
      Paint()..color = const Color(0xFFFFD54F),
    );

    canvas.restore();
  }

  /// Melukis satu burung yang terbang melayang dengan kepakan sayap alami
  void _drawFlyingBird({
    required Canvas canvas,
    required Offset position,
    required double wingPhase,
    required double size,
  }) {
    canvas.save();
    canvas.translate(position.dx, position.dy);

    // Ayunan sayap naik-turun halus (flapping wing arc)
    final wingY = math.sin(wingPhase) * (size * 0.55);

    final birdPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    final birdPath = Path();
    // Sayap Kiri
    birdPath.moveTo(-size, wingY);
    birdPath.quadraticBezierTo(-size * 0.45, -size * 0.25, 0, 0);
    // Sayap Kanan
    birdPath.quadraticBezierTo(size * 0.45, -size * 0.25, size, wingY);

    canvas.drawPath(birdPath, birdPaint);
    canvas.restore();
  }

  /// Melukis partikel kilau bintang keemasan
  void _drawSparkleStar(Canvas canvas, Offset center, double starSize) {
    final p = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.85)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      center.translate(-starSize, 0),
      center.translate(starSize, 0),
      p,
    );
    canvas.drawLine(
      center.translate(0, -starSize),
      center.translate(0, starSize),
      p,
    );
    canvas.drawCircle(center, 1.8, Paint()..color = const Color(0xFFFEF08A));
  }

  @override
  bool shouldRepaint(covariant _ScenicAtmospherePainter old) =>
      old.ambient != ambient || old.intro != intro;
}
