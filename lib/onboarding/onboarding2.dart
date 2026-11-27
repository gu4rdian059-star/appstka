import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'widgets/onboarding_common.dart';

/// Onboarding 2 — "Cari & Pilih Perjalanan Favorit"
/// Animasi: kartu pencarian rute melayang di stasiun, garis rute tergambar
/// dengan ikon kereta berjalan, jadwal kereta meluncur masuk lalu satu jadwal
/// terpilih (centang + hati), chip kursi melayang, lampu stasiun berpendar.
class Onboarding2 extends StatefulWidget {
  final bool isActive;
  final double pageOffset;

  const Onboarding2({
    super.key,
    required this.isActive,
    required this.pageOffset,
  });

  @override
  State<Onboarding2> createState() => _Onboarding2State();
}

class _Onboarding2State extends State<Onboarding2>
    with TickerProviderStateMixin, OnboardingAnimationMixin {
  static const _bgAsset = 'assets/images/onboarding/ob2_background.jpg';

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
  void didUpdateWidget(covariant Onboarding2 oldWidget) {
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
      title: 'Cari & Pilih\nPerjalanan Favorit',
      description:
          'Temukan rute, pilih jadwal, dan\nkursi sesuai kebutuhan Anda.',
      illustrationBuilder: _buildScene,
    );
  }

  Widget _buildScene(BuildContext context, Size size) {
    final rect = coverRect(size, 896 / 1200);
    final topPadding = MediaQuery.paddingOf(context).top;

    return AnimatedBuilder(
      animation: Listenable.merge([intro, ambient]),
      builder: (context, _) {
        final t = intro.value;
        final a = ambient.value;
        final kenBurns = 1.08 - 0.08 * Curves.easeOutCubic.transform(t);
        final offset = widget.pageOffset * size.width;

        return Stack(
          children: [
            // Latar stasiun + efek ambient
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(offset * 0.35, 0),
                child: Transform.scale(
                  scale: kenBurns,
                  child: Stack(
                    children: [
                      Positioned.fromRect(
                        rect: rect,
                        child: Image.asset(
                          _bgAsset,
                          fit: BoxFit.fill,
                          cacheWidth: 960,
                        ),
                      ),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _Scene2Painter(
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

            // Kartu-kartu pencarian yang melayang
            Positioned(
              top: topPadding + 78,
              left: 18,
              right: 18,
              bottom: 48,
              child: Transform.translate(
                offset: Offset(-offset * 0.15, 0),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: _SearchCards(intro: t, ambient: a),
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

// ============================================================ Kartu-kartu UI

class _SearchCards extends StatelessWidget {
  final double intro;
  final double ambient;

  const _SearchCards({required this.intro, required this.ambient});

  static const _w = 320.0;
  static const _h = 320.0;

  @override
  Widget build(BuildContext context) {
    final t = intro;
    final a = ambient;
    final groupBob = math.sin(a * math.pi * 2 * 5) * 2.5;

    // Kartu rute
    final routeP = const Interval(
      0.0,
      0.4,
      curve: Curves.easeOutBack,
    ).transform(t);
    final routeO = const Interval(0.0, 0.25).transform(t);
    final lineP = const Interval(
      0.25,
      0.55,
      curve: Curves.easeInOut,
    ).transform(t);

    // Tombol cari
    final fabP = const Interval(
      0.35,
      0.6,
      curve: Curves.elasticOut,
    ).transform(t);

    // Jadwal
    final cardAP = const Interval(
      0.45,
      0.7,
      curve: Curves.easeOutCubic,
    ).transform(t);
    final cardBP = const Interval(
      0.55,
      0.8,
      curve: Curves.easeOutCubic,
    ).transform(t);
    final selectP = const Interval(
      0.8,
      0.95,
      curve: Curves.easeOut,
    ).transform(t);
    final checkP = const Interval(
      0.82,
      1.0,
      curve: Curves.elasticOut,
    ).transform(t);

    // Chip kursi
    final chipP = const Interval(
      0.68,
      0.9,
      curve: Curves.easeOutBack,
    ).transform(t);
    final chipBob = math.sin(a * math.pi * 2 * 8) * 3;

    return SizedBox(
      width: _w,
      height: _h,
      child: Transform.translate(
        offset: Offset(0, groupBob),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Jadwal A
            Positioned(
              top: 164,
              left: 0,
              width: 292,
              child: _slideIn(
                cardAP,
                const _ScheduleCard(
                  name: 'Parahyangan',
                  time: '06:15  →  09:05 · 2j 50m',
                  price: 'Rp120rb',
                  kelas: 'Ekonomi',
                  selectP: 0,
                  checkP: 0,
                  glow: 0,
                ),
              ),
            ),

            // Jadwal B (terpilih)
            Positioned(
              top: 238,
              left: 28,
              width: 292,
              child: _slideIn(
                cardBP,
                _ScheduleCard(
                  name: 'Argo Parahyangan',
                  time: '08:30  →  11:15 · 2j 45m',
                  price: 'Rp150rb',
                  kelas: 'Eksekutif',
                  selectP: selectP,
                  checkP: checkP,
                  glow: t >= 1.0
                      ? 0.5 + 0.5 * math.sin(a * math.pi * 2 * 6)
                      : selectP,
                ),
              ),
            ),

            // Hati melayang dari jadwal terpilih (favorit)
            if (t >= 0.95)
              for (int i = 0; i < 3; i++) _buildHeart(i, a),

            // Kartu rute
            Positioned(
              top: 14,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: routeO,
                child: Transform.translate(
                  offset: Offset(0, 30 * (1 - routeP)),
                  child: Transform.scale(
                    scale: 0.85 + 0.15 * routeP,
                    child: _RouteCard(lineProgress: lineP, ambient: a),
                  ),
                ),
              ),
            ),

            // Tombol cari dengan riak
            Positioned(
              top: 122,
              right: 20,
              child: Transform.scale(
                scale: fabP,
                child: CustomPaint(
                  painter: _RipplePainter(
                    t: (a * 12.5) % 1.0,
                    color: TkaColors.orange,
                  ),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [TkaColors.orange, Color(0xFFFF9E40)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: TkaColors.orange.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),

            // Chip kursi (ditaruh di sisi kiri atas agar lega dan tidak bertabrakan dengan tombol Lewati di kanan)
            Positioned(
              top: 0 + chipBob,
              left: 14,
              child: Transform.scale(
                scale: chipP,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: TkaColors.navy,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: TkaColors.navy.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event_seat_rounded,
                        color: TkaColors.orange,
                        size: 15,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Kursi 7A',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
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
    );
  }

  Widget _slideIn(double p, Widget child) {
    return Opacity(
      opacity: p.clamp(0.0, 1.0),
      child: Transform.translate(offset: Offset(70 * (1 - p), 0), child: child),
    );
  }

  Widget _buildHeart(int i, double a) {
    final p = (a * 6 + i / 3) % 1.0;
    final alpha = math.sin(p * math.pi);
    return Positioned(
      top: 236 - p * 46,
      right: 4 + i * 12 + math.sin(p * math.pi * 3 + i) * 6,
      child: Opacity(
        opacity: alpha.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.6 + 0.5 * p,
          child: Icon(
            Icons.favorite_rounded,
            size: 14,
            color: i == 1 ? const Color(0xFFFF6B6B) : TkaColors.orange,
          ),
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration({Color? borderColor, double glow = 0}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: borderColor ?? Colors.transparent, width: 1.6),
    boxShadow: [
      BoxShadow(
        color: TkaColors.navy.withValues(alpha: 0.13),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
      if (glow > 0)
        BoxShadow(
          color: TkaColors.orange.withValues(alpha: 0.28 * glow),
          blurRadius: 18,
          spreadRadius: 1,
        ),
    ],
  );
}

class _RouteCard extends StatelessWidget {
  final double lineProgress;
  final double ambient;

  const _RouteCard({required this.lineProgress, required this.ambient});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: _cardDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const _CityLabel(
                label: 'Dari',
                city: 'Jakarta',
                station: 'Gambir · GMR',
                alignEnd: false,
              ),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: CustomPaint(
                    painter: _RouteLinePainter(
                      progress: lineProgress,
                      trainT: (ambient * 8) % 1.0,
                    ),
                  ),
                ),
              ),
              const _CityLabel(
                label: 'Ke',
                city: 'Bandung',
                station: 'Bandung · BD',
                alignEnd: true,
              ),
            ],
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 12),
            color: const Color(0xFFEEF1F6),
          ),
          const Row(
            children: [
              _InfoPill(
                icon: Icons.calendar_month_rounded,
                text: 'Sen, 18 Nov',
              ),
              SizedBox(width: 8),
              _InfoPill(icon: Icons.person_rounded, text: '1 Dewasa'),
            ],
          ),
        ],
      ),
    );
  }
}

class _CityLabel extends StatelessWidget {
  final String label;
  final String city;
  final String station;
  final bool alignEnd;

  const _CityLabel({
    required this.label,
    required this.city,
    required this.station,
    required this.alignEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: TkaColors.grey),
        ),
        const SizedBox(height: 2),
        Text(
          city,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: TkaColors.navy,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          station,
          style: const TextStyle(fontSize: 10.5, color: TkaColors.grey),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: TkaColors.navy),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: TkaColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final String name;
  final String time;
  final String price;
  final String kelas;
  final double selectP;
  final double checkP;
  final double glow;

  const _ScheduleCard({
    required this.name,
    required this.time,
    required this.price,
    required this.kelas,
    required this.selectP,
    required this.checkP,
    required this.glow,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: _cardDecoration(
            borderColor: Color.lerp(
              Colors.transparent,
              TkaColors.orange,
              selectP,
            ),
            glow: glow * selectP,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: TkaColors.orange.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.train_rounded,
                  color: TkaColors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: TkaColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 11,
                        color: TkaColors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    price,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: TkaColors.orange,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    kelas,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: TkaColors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (checkP > 0)
          Positioned(
            top: -8,
            right: -8,
            child: Transform.scale(
              scale: checkP,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: TkaColors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ================================================================ Painter

/// Garis rute putus-putus yang tergambar + ikon kereta yang berjalan
class _RouteLinePainter extends CustomPainter {
  final double progress;
  final double trainT;

  _RouteLinePainter({required this.progress, required this.trainT});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    const pad = 12.0;
    final startX = pad;
    final endX = size.width - pad;
    final curX = startX + (endX - startX) * progress;

    final dash = Paint()
      ..color = TkaColors.navy.withValues(alpha: 0.35)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (double x = startX; x < curX; x += 7) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 3.5, curX), y), dash);
    }

    canvas.drawCircle(Offset(startX, y), 4, Paint()..color = TkaColors.navy);
    if (progress > 0.98) {
      canvas.drawCircle(Offset(endX, y), 5, Paint()..color = TkaColors.orange);
      canvas.drawCircle(Offset(endX, y), 2.2, Paint()..color = Colors.white);
    }

    // Ikon kereta kecil berjalan di sepanjang rute
    if (progress >= 1.0) {
      final eased = Curves.easeInOut.transform(trainT);
      final x = startX + 8 + (endX - startX - 16) * eased;
      final alpha = math.sin(trainT * math.pi).clamp(0.0, 1.0);
      final body = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y - 1), width: 18, height: 11),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        body,
        Paint()..color = TkaColors.orange.withValues(alpha: alpha),
      );
      canvas.drawRect(
        Rect.fromCenter(center: Offset(x + 1, y - 3), width: 11, height: 3.5),
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
      // Jejak angin di belakang kereta
      canvas.drawLine(
        Offset(x - 22, y - 1),
        Offset(x - 12, y - 1),
        Paint()
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..color = TkaColors.orange.withValues(alpha: 0.4 * alpha),
      );
    } else {
      // Ujung garis yang sedang tergambar
      canvas.drawCircle(Offset(curX, y), 3, Paint()..color = TkaColors.orange);
    }
  }

  @override
  bool shouldRepaint(covariant _RouteLinePainter old) =>
      old.progress != progress || old.trainT != trainT;
}

class _RipplePainter extends CustomPainter {
  final double t;
  final Color color;

  _RipplePainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (int i = 0; i < 2; i++) {
      final p = (t + i * 0.5) % 1.0;
      canvas.drawCircle(
        c,
        size.width / 2 + p * 16,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: 0.45 * (1 - p)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter old) => old.t != t;
}

class _Scene2Painter extends CustomPainter {
  final Rect rect;
  final double intro;
  final double ambient;

  _Scene2Painter({
    required this.rect,
    required this.intro,
    required this.ambient,
  });

  Offset _img(double x, double y) => Offset(
    rect.left + x / 896.0 * rect.width,
    rect.top + y / 1200.0 * rect.height,
  );

  double get _s => rect.width / 414.0;

  @override
  void paint(Canvas canvas, Size size) {
    DriftingCloudsPainter(t: ambient, maxY: 0.35).paint(canvas, size);
    FlyingBirdsPainter(
      t: (ambient + 0.4) % 1.0,
      opacity: const Interval(0.3, 0.7).transform(intro),
    ).paint(canvas, size);

    // Papan stasiun berpendar
    final signPulse = 0.5 + 0.5 * math.sin(ambient * math.pi * 2 * 7);
    final signRect = Rect.fromLTRB(
      _img(672, 350).dx,
      _img(672, 350).dy,
      _img(856, 510).dx,
      _img(856, 510).dy,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        signRect.inflate(4 * _s),
        Radius.circular(10 * _s),
      ),
      Paint()
        ..color = const Color(0xFF6FA8FF).withValues(alpha: 0.25 * signPulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Lampu peron berkedip lembut
    for (final p in const [
      [250.0, 705.0, 0.0],
      [500.0, 705.0, 0.5],
    ]) {
      final c = _img(p[0], p[1]);
      final pulse = 0.5 + 0.5 * math.sin((ambient * 10 + p[2]) * math.pi * 2);
      final r = 16 * _s * (0.8 + 0.4 * pulse);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = ui.Gradient.radial(c, r, [
            const Color(0xFFFFC46B).withValues(alpha: 0.75),
            const Color(0x00FFC46B),
          ]),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Scene2Painter old) =>
      old.intro != intro || old.ambient != ambient || old.rect != rect;
}
