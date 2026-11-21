import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/user_db_service.dart';
import 'transaction_status_screen.dart';

class QrisPaymentScreen extends StatefulWidget {
  final String bookingCode;
  final TrainScheduleModel train;
  final StationModel origin;
  final StationModel dest;
  final DateTime travelDate;
  final String bookerName;
  final String bookerEmail;
  final String bookerPhone;
  final String passengerName;
  final String passengerNik;
  final List<Map<String, String>>? passengers;
  final String selectedSeat;
  final String seatSide;
  final int totalAmount;

  const QrisPaymentScreen({
    super.key,
    required this.bookingCode,
    required this.train,
    required this.origin,
    required this.dest,
    required this.travelDate,
    required this.bookerName,
    required this.bookerEmail,
    required this.bookerPhone,
    required this.passengerName,
    required this.passengerNik,
    this.passengers,
    required this.selectedSeat,
    required this.seatSide,
    required this.totalAmount,
  });

  @override
  State<QrisPaymentScreen> createState() => _QrisPaymentScreenState();
}

class _QrisPaymentScreenState extends State<QrisPaymentScreen> {
  late Timer _countdownTimer;
  int _remainingSeconds = 15 * 60; // 15 Menit
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        if (mounted) setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    super.dispose();
  }

  String _formatTimer(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatCurrency(int amount) {
    return 'Rp${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  String _formatDate(DateTime d) {
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  List<Map<String, String>> get _manifestPassengers {
    if (widget.passengers != null && widget.passengers!.isNotEmpty) {
      return widget.passengers!;
    }
    return [
      {
        'name': widget.passengerName,
        'id': widget.passengerNik,
        'seat': widget.selectedSeat,
        'seatSide': widget.seatSide,
      },
    ];
  }

  void _checkPaymentStatus() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            const CircularProgressIndicator(color: Color(0xFF0256B8)),
            const SizedBox(height: 20),
            const Text(
              'Memeriksa Pembayaran QRIS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF062056),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Menghubungi jaringan QRIS Nasional & menyinkronkan data ${_manifestPassengers.length} tiket ke Supabase...',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 1600));

    // 1. Simpan booking ke database untuk seluruh penumpang
    final referenceNumber =
        'QRIS-${DateTime.now().millisecondsSinceEpoch.toString().substring(3)}';

    try {
      // 1. Simpan order lengkap (semua penumpang tersimpan di Supabase dan lokal)
      final primaryBooking = await UserDatabaseService.createBookingOrder(
        schedule: widget.train,
        selectedClass: widget.train.availableClasses.first,
        bookerName: widget.passengerName,
        bookerEmail: widget.bookerEmail,
        bookerPhone: widget.bookerPhone,
        manifestPassengers: _manifestPassengers,
        travelDate: _formatDate(widget.travelDate),
        status: 'Sudah Dibayar',
        paymentMethod: 'QRIS Instant',
        vaNumber: 'NMID: ID1020089218201',
        totalFare: widget.totalAmount,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Tutup dialog loading
      setState(() => _isChecking = false);

      // 3. Navigasikan ke TransactionStatusScreen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TransactionStatusScreen(
            booking: primaryBooking,
            transactionNumber: referenceNumber,
            paymentMethod: 'QRIS Instant',
            paidAmount: widget.totalAmount,
            seatNumber: widget.selectedSeat,
            passengerName:
                _manifestPassengers[0]['name'] ?? widget.passengerName,
            passengerNik: _manifestPassengers[0]['id'] ?? widget.passengerNik,
            passengers: _manifestPassengers,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() => _isChecking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan verifikasi: $e'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _copyAmount() {
    Clipboard.setData(ClipboardData(text: widget.totalAmount.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nominal pembayaran berhasil disalin ke clipboard'),
        backgroundColor: Color(0xFF0256B8),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _saveQrImage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kode QRIS berhasil disimpan ke Galeri ponsel Anda'),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062056),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Pembayaran QRIS',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'TKA VELOCITY • Standar Pembayaran Nasional',
              style: TextStyle(fontSize: 10, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Timer Bar & Nominal
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFFFB74D).withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        color: Color(0xFFE65100),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selesaikan Dalam Waktu',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFFE65100),
                            ),
                          ),
                          Text(
                            _formatTimer(_remainingSeconds),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE65100),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Total Pembayaran',
                        style: TextStyle(fontSize: 10.5, color: Colors.grey),
                      ),
                      Row(
                        children: [
                          Text(
                            _formatCurrency(widget.totalAmount),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF062056),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: _copyAmount,
                            child: const Icon(
                              Icons.copy_rounded,
                              size: 14,
                              color: Color(0xFF0256B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Card QRIS Resmi
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header QRIS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Badge QRIS Merah Resmi
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFED1C24),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'QRIS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      // Badge GPN
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F4C81),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'GPN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Merchant Name & NMID
                  const Text(
                    'PT KERETA API TKA INDONESIA (PERSERO)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF062056),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'NMID : ID1020089218201 • A01',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Render QR Code Visual Canvas yang Rapi
                  Container(
                    width: 220,
                    height: 220,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.15),
                        width: 1.2,
                      ),
                    ),
                    child: CustomPaint(
                      painter: _QrisPainter(),
                      child: Center(
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF062056),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                          child: const Icon(
                            Icons.train_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Petunjuk Scan
                  Text(
                    'Pindai QR ini melalui aplikasi Mobile Banking atau E-Wallet apa saja yang mendukung QRIS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      height: 1.35,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Tombol Unduh QR
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0256B8),
                      side: const BorderSide(color: Color(0xFF0256B8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    onPressed: _saveQrImage,
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text(
                      'Unduh / Simpan Gambar QR',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Supported E-Wallets & Banks Chips
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mendukung Semua Pembayaran:',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF062056),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildPartnerChip('BCA Mobile'),
                      _buildPartnerChip('Livin\' Mandiri'),
                      _buildPartnerChip('BRImo'),
                      _buildPartnerChip('BNI Mobile'),
                      _buildPartnerChip('GoPay'),
                      _buildPartnerChip('OVO'),
                      _buildPartnerChip('DANA'),
                      _buildPartnerChip('ShopeePay'),
                      _buildPartnerChip('LinkAja'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // Tombol Cek Pembayaran
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0256B8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isChecking ? null : _checkPaymentStatus,
                icon: const Icon(
                  Icons.verified_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                label: const Text(
                  'Cek Status Pembayaran',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text(
                      'Batalkan Pembayaran?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF062056),
                      ),
                    ),
                    content: const Text(
                      'Tiket yang belum dibayar akan otomatis dibatalkan.',
                      style: TextStyle(fontSize: 12),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Tetap di Halaman Ini'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Batalkan',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              },
              child: const Text(
                'Batalkan Pesanan Ini',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPartnerChip(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Text(
        name,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF334155),
        ),
      ),
    );
  }
}

class _QrisPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // Corner Finder Patterns
    _drawFinder(canvas, 0, 0, 48, paint);
    _drawFinder(canvas, size.width - 48, 0, 48, paint);
    _drawFinder(canvas, 0, size.height - 48, 48, paint);

    // Timing patterns & simulated data points
    final dotPaint = Paint()..color = const Color(0xFF1E293B);
    const int grid = 21;
    final double step = size.width / grid;

    for (int r = 0; r < grid; r++) {
      for (int c = 0; c < grid; c++) {
        // Skip corner finder areas
        if ((r < 7 && c < 7) ||
            (r < 7 && c > grid - 8) ||
            (r > grid - 8 && c < 7)) {
          continue;
        }
        // Skip center logo area
        if (r >= 8 && r <= 12 && c >= 8 && c <= 12) {
          continue;
        }

        // Pseudo-random deterministic dots for authentic QR look
        if ((r * 7 + c * 13 + (r % 3)) % 2 == 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(c * step + 1, r * step + 1, step - 2, step - 2),
              const Radius.circular(1.5),
            ),
            dotPaint,
          );
        }
      }
    }
  }

  void _drawFinder(Canvas canvas, double x, double y, double s, Paint paint) {
    // Outer black box
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, s, s),
        const Radius.circular(6),
      ),
      paint,
    );
    // Inner white box
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + 7, y + 7, s - 14, s - 14),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.white,
    );
    // Inner black box
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + 14, y + 14, s - 28, s - 28),
        const Radius.circular(3),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
