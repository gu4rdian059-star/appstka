import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'widgets/onboarding_common.dart';

/// Onboarding 3 — "Kelola Perjalanan dengan Fleksibel"
/// Fitur:
/// - Seluruh kartu kecil mengambang ("Ubah Jadwal", dll.) telah dihapus bersih.
/// - Menampilkan Smartphone E-Tiket Digital TKA berskala lega & proporsional (lebar 280px)
///   di bagian tengah dengan margin leluasa sehingga 100% BEBAS dari garis kuning (overflow).
/// - Header tiket rapi dengan logo kereta resmi TKA, rute Gambir -> Bandung,
///   data penumpang Arya Pratama, nomor kursi 07A, dan tombol "E-Tiket Siap Digunakan".
/// - Latar belakang gradasi pastel hangat pegunungan pagi yang menenangkan.
class Onboarding3 extends StatefulWidget {
  final bool isActive;
  final double pageOffset;

  const Onboarding3({
    super.key,
    required this.isActive,
    required this.pageOffset,
  });

  @override
  State<Onboarding3> createState() => _Onboarding3State();
}

class _Onboarding3State extends State<Onboarding3>
    with TickerProviderStateMixin, OnboardingAnimationMixin {
  @override
  Duration get introDuration => const Duration(milliseconds: 2800);

  @override
  bool get isActive => widget.isActive;

  @override
  void initState() {
    super.initState();
    initAnimations();
  }

  @override
  void didUpdateWidget(covariant Onboarding3 oldWidget) {
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
      title: 'Kelola Perjalanan\ndengan Fleksibel',
      description:
          'Cek tiket, ubah jadwal, atau batalkan\nkapan saja dengan jaminan 100% praktis.',
      illustrationBuilder: _buildScene,
    );
  }

  Widget _buildScene(BuildContext context, Size size) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return AnimatedBuilder(
      animation: Listenable.merge([intro, ambient]),
      builder: (context, _) {
        final t = intro.value;
        final a = ambient.value;
        final parallax = widget.pageOffset * size.width * 0.35;

        // Progres kemunculan kartu tiket
        final phoneP = const Interval(
          0.05,
          0.70,
          curve: Curves.easeOutBack,
        ).transform(t);

        // Goyangan melayang halus (ambient floating)
        final phoneBob = math.sin(a * math.pi * 2 * 3) * 4.0;

        return Stack(
          children: [
            // ==================== 1. LATAR BELAKANG PEMANDANGAN PASTEL ====================
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(parallax, 0),
                child: CustomPaint(
                  painter: _SoftPastelAtmospherePainter(
                    ambient: a,
                    intro: t,
                  ),
                ),
              ),
            ),

            // ==================== 2. SMARTPHONE E-TIKET UTAMA (CENTERPIECE HERO) ====================
            Positioned(
              top: topPadding + 14,
              left: 16,
              right: 16,
              bottom: 24,
              child: Align(
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Transform.translate(
                    offset: Offset(0, (1 - phoneP) * 80 + phoneBob),
                    child: Transform.scale(
                      scale: 0.88 + 0.12 * phoneP,
                      child: Opacity(
                        opacity: phoneP.clamp(0.0, 1.0),
                        child: _buildSmartphoneTicketCard(),
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

  /// Membangun Smartphone E-Tiket Digital Modern & Proporsional (Lebar 280px, Bebas Overflow)
  Widget _buildSmartphoneTicketCard() {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: TkaColors.navy.withValues(alpha: 0.22),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: TkaColors.orange.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Speaker / Dynamic Island di Atas
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              width: 48,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            // Header E-Tiket Resmi TKA (Deep Navy) dengan Spacer lega anti-overflow
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF062056), Color(0xFF0F357F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/logo_train.png',
                    height: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 7),
                  const Text(
                    'E-TIKET TKA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD54F),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'EKSEKUTIF',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF062056),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Rute Perjalanan: GMR (Gambir) -> BD (Bandung)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Asal: GMR
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'GMR',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: TkaColors.navy,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Gambir, JKT',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '08:30 WIB',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: TkaColors.orange,
                        ),
                      ),
                    ],
                  ),

                  // Garis Tengah: Durasi & Ikon Kereta
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '45 Menit',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.circle,
                                size: 5,
                                color: TkaColors.orange,
                              ),
                              Expanded(
                                child: Container(
                                  height: 1.5,
                                  color: const Color(0xFFCBD5E1),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: TkaColors.navy,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.train_rounded,
                                  size: 11,
                                  color: Colors.white,
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 1.5,
                                  color: const Color(0xFFCBD5E1),
                                ),
                              ),
                              const Icon(
                                Icons.circle,
                                size: 5,
                                color: TkaColors.navy,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Langsung',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tujuan: BD
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'BD',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: TkaColors.navy,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Bandung Kota',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '09:15 WIB',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: TkaColors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Garis Perforasi Tiket Bergerigi
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: List.generate(20, (i) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      height: 1.2,
                      color: const Color(0xFFE2E8F0),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 14),

            // Data Penumpang & Nomor Kursi
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              ),
              child: Row(
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Arya Pratama',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: TkaColors.navy,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Kursi 07A • KA 1024',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Tombol Hijau: "E-Tiket Siap Digunakan"
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.32),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_rounded, size: 15, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'E-Tiket Siap Digunakan',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Melukis Latar Belakang Gradasi Pemandangan Pagi yang Lembut, Cerah, dan Menenangkan
class _SoftPastelAtmospherePainter extends CustomPainter {
  final double ambient;
  final double intro;

  _SoftPastelAtmospherePainter({
    required this.ambient,
    required this.intro,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Langit Bergradasi Pagi Hangat
    final skyRect = Rect.fromLTWH(0, 0, w, h);
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFEBF4FE),
          Color(0xFFFFF2E6),
          Color(0xFFFFF9ED),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(skyRect);
    canvas.drawRect(skyRect, skyPaint);

    // 2. Matahari Bersinar Lembut di Kanan Atas
    final sunCenter = Offset(w * 0.82, h * 0.20);
    canvas.drawCircle(
      sunCenter,
      w * 0.32,
      Paint()
        ..color = const Color(0xFFFFE0B2).withValues(alpha: 0.40)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32),
    );

    // 3. Awan-Awan Halus Mengambang
    _drawCloud(
      canvas,
      Offset(w * 0.16 + math.sin(ambient * math.pi * 2) * 8, h * 0.15),
      28,
    );
    _drawCloud(
      canvas,
      Offset(w * 0.82 - math.cos(ambient * math.pi * 2) * 6, h * 0.12),
      22,
    );

    // 4. Lapisan Pegunungan Biru & Bukit Hijau di Latar Belakang
    final mountainPath = Path()
      ..moveTo(0, h * 0.65)
      ..quadraticBezierTo(w * 0.28, h * 0.52, w * 0.52, h * 0.60)
      ..quadraticBezierTo(w * 0.76, h * 0.48, w, h * 0.56)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      mountainPath,
      Paint()..color = const Color(0xFFC7DFF8).withValues(alpha: 0.45),
    );

    final hillPath = Path()
      ..moveTo(0, h * 0.72)
      ..quadraticBezierTo(w * 0.35, h * 0.62, w * 0.70, h * 0.70)
      ..quadraticBezierTo(w * 0.88, h * 0.74, w, h * 0.66)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      hillPath,
      Paint()..color = const Color(0xFFA7F3D0).withValues(alpha: 0.55),
    );

    // 5. Partikel Bintang Berpendar (Sparkles)
    final sparkles = [
      Offset(w * 0.12, h * 0.26),
      Offset(w * 0.88, h * 0.16),
      Offset(w * 0.08, h * 0.45),
      Offset(w * 0.92, h * 0.48),
    ];

    for (int i = 0; i < sparkles.length; i++) {
      final pulse = 0.55 + 0.45 * math.sin(ambient * math.pi * 2 * 3 + i * 1.5);
      final sp = sparkles[i];
      final paint = Paint()
        ..color = const Color(0xFFF59E0B).withValues(alpha: 0.75)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        sp.translate(-6.0 * pulse, 0),
        sp.translate(6.0 * pulse, 0),
        paint,
      );
      canvas.drawLine(
        sp.translate(0, -6.0 * pulse),
        sp.translate(0, 6.0 * pulse),
        paint,
      );
      canvas.drawCircle(sp, 1.8, Paint()..color = const Color(0xFFFDE68A));
    }
  }

  void _drawCloud(Canvas canvas, Offset center, double radius) {
    final cloudPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.70)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, radius, cloudPaint);
    canvas.drawCircle(
      center.translate(-radius * 0.65, radius * 0.2),
      radius * 0.65,
      cloudPaint,
    );
    canvas.drawCircle(
      center.translate(radius * 0.7, radius * 0.15),
      radius * 0.7,
      cloudPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SoftPastelAtmospherePainter old) =>
      old.ambient != ambient || old.intro != intro;
}
