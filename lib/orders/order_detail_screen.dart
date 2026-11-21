import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'refund_screen.dart';
import '../services/user_db_service.dart';
import '../tickets/eticket_boarding_pass_screen.dart';
import '../tracking/live_tracking_screen.dart';

class OrderDetailScreen extends StatelessWidget {
  final String orderId;
  final String bookingCode;
  final String status;
  final String trainName;
  final String trainClass;
  final String origin;
  final String dest;
  final String departureTime;
  final String arrivalTime;
  final String passengerName;
  final String passengerNik;
  final String seat;
  final int totalAmount;
  final String paymentMethod;
  final String vaNumber;
  final String travelDate;
  final List<Map<String, String>>? passengers;
  final VoidCallback? onViewTicket;
  final VoidCallback? onPayNow;

  const OrderDetailScreen({
    super.key,
    this.orderId = 'ORD-20241025-9921',
    this.bookingCode = 'TKA-9921XB',
    this.status = 'Sudah Dibayar',
    this.trainName = 'KA Argo Bromo Anggrek',
    this.trainClass = 'KA 2 • Eksekutif',
    this.origin = 'Stasiun Gambir (GMR)',
    this.dest = 'Stasiun Surabaya Pasarturi (SBI)',
    this.departureTime = '08:20 WIB',
    this.arrivalTime = '16:25 WIB',
    this.passengerName = 'Samuel',
    this.passengerNik = '3514062607090001',
    this.seat = 'Gerbong EKS-2 / Kursi 5C',
    this.totalAmount = 640000,
    this.paymentMethod = 'BCA Virtual Account',
    this.vaNumber = 'VA-9001842910',
    this.travelDate = 'Jum, 25 Okt 2024',
    this.passengers,
    this.onViewTicket,
    this.onPayNow,
  });

  factory OrderDetailScreen.fromBooking(
    BookingModel b, {
    VoidCallback? onViewTicket,
    VoidCallback? onPayNow,
  }) {
    return OrderDetailScreen(
      bookingCode: b.bookingId,
      orderId: 'ORD-${b.bookingId.replaceAll('TKA-', '')}',
      status: b.status,
      trainName: b.trainName,
      trainClass: b.trainClass,
      origin: '${b.originName} (${b.originCode})',
      dest: '${b.destName} (${b.destCode})',
      departureTime: b.departureTime,
      arrivalTime: b.arrivalTime,
      passengerName: b.passengerName,
      passengerNik: b.passengerNik,
      seat: b.seatNumber,
      totalAmount: b.totalAmount,
      paymentMethod: b.paymentMethod,
      vaNumber: b.vaNumber,
      travelDate: b.travelDate,
      passengers: b.passengers,
      onViewTicket: onViewTicket,
      onPayNow: onPayNow,
    );
  }

  /// Otomatis melacak seluruh data manifest penumpang
  List<Map<String, String>> _resolveManifest() {
    if (passengers != null && passengers!.isNotEmpty) {
      return passengers!;
    }

    try {
      final all = UserDatabaseService.getCachedBookings();
      final siblings = all.where((b) {
        if (b.bookingId == bookingCode) return true;
        if (bookingCode.contains('-') &&
            b.bookingId.startsWith(bookingCode.split('-')[0])) {
          return true;
        }
        final sameTrain =
            b.trainName.toLowerCase().trim() == trainName.toLowerCase().trim();
        final sameDate = b.travelDate.trim() == travelDate.trim();
        final sameTime = b.departureTime.trim() == departureTime.trim();
        return sameTrain && sameDate && sameTime;
      }).toList();

      if (siblings.length > 1) {
        // Urutkan Penumpang 1 lebih dahulu dari Penumpang 2
        siblings.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return siblings.map((s) => {
          'name': s.passengerName,
          'id': s.passengerNik,
          'seat': s.seatNumber,
          'type': 'Dewasa (Adult)',
        }).toList();
      }
    } catch (_) {}

    return [
      {
        'name': passengerName,
        'id': passengerNik,
        'seat': seat,
        'type': 'Dewasa (Adult)',
      }
    ];
  }

  int _resolveTotalAmount(List<Map<String, String>> manifest) {
    if (manifest.length <= 1) return totalAmount;
    try {
      final all = UserDatabaseService.getCachedBookings();
      final siblings = all.where((b) {
        if (b.bookingId == bookingCode) return true;
        final sameTrain =
            b.trainName.toLowerCase().trim() == trainName.toLowerCase().trim();
        final sameDate = b.travelDate.trim() == travelDate.trim();
        final sameTime = b.departureTime.trim() == departureTime.trim();
        return sameTrain && sameDate && sameTime;
      }).toList();
      if (siblings.length > 1) {
        final sum =
            siblings.fold<int>(0, (prev, elem) => prev + elem.totalAmount);
        if (sum > totalAmount) return sum;
      }
    } catch (_) {}
    if (totalAmount < 300000 && manifest.length > 1) {
      return totalAmount * manifest.length;
    }
    return totalAmount;
  }

  String _resolveSeats(List<Map<String, String>> manifest) {
    final seatList = manifest
        .map((p) => p['seat'] ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    if (seatList.isNotEmpty) {
      return seatList.join(', ');
    }
    return seat;
  }

  String _formatCurrency(int amount) {
    return 'Rp${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label berhasil disalin!'),
        backgroundColor: const Color(0xFF062056),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manifest = _resolveManifest();
    final resolvedTotal = _resolveTotalAmount(manifest);
    final displaySeats = _resolveSeats(manifest);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF062056)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Detail Pesanan',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF062056),
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & Order Number
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        status,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Lunas: 24 Okt 2024, 18:32 WIB',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Text(
                  'NOMOR TRANSAKSI: $orderId',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 15,
                    color: Colors.grey,
                  ),
                  onPressed: () =>
                      _copyToClipboard(context, orderId, 'Nomor Transaksi'),
                ),
              ],
            ),

            // Card PNR Booking Code
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF062056),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'KODE BOOKING (PNR)',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        bookingCode,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () =>
                        _copyToClipboard(context, bookingCode, 'Kode Booking'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Salin',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Card Detail Kereta & Perjalanan
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF062056),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.train_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trainName,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF062056),
                              ),
                            ),
                            Text(
                              trainClass,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Direct',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  // Timeline Keberangkatan & Kedatangan
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          const Icon(
                            Icons.circle,
                            size: 10,
                            color: Color(0xFF062056),
                          ),
                          Container(
                            width: 2,
                            height: 38,
                            color: Colors.grey.shade300,
                          ),
                          const Icon(
                            Icons.circle,
                            size: 10,
                            color: Color(0xFFF26716),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  departureTime,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF062056),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Peron 3',
                                    style: TextStyle(fontSize: 10.5),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              origin,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Text(
                              'Jum, 25 Okt 2024',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.grey,
                              ),
                            ),

                            const SizedBox(height: 10),
                            Text(
                              'Estimasi 8j 05m',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 10),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  arrivalTime,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF062056),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Peron 1',
                                    style: TextStyle(fontSize: 10.5),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              dest,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Text(
                              'Jum, 25 Okt 2024',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Icon(
                        Icons.event_seat_rounded,
                        size: 18,
                        color: Color(0xFF062056),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Posisi Tempat Duduk: $displaySeats',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Card Data Penumpang
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.person_rounded,
                        size: 18,
                        color: Color(0xFF062056),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'DATA PENUMPANG',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${manifest.length} Penumpang',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                  for (int i = 0; i < manifest.length; i++) ...[
                    if (i > 0) const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8F1FC),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      'Penumpang ${i + 1}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0256B8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      manifest[i]['name'] ??
                                          'Penumpang ${i + 1}',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF062056),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${manifest[i]['type'] ?? 'Dewasa (Adult)'} • No. Identitas: ${manifest[i]['id'] ?? passengerNik}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.grey,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (manifest[i]['seat'] != null &&
                                  manifest[i]['seat']!.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.event_seat_rounded,
                                      size: 13,
                                      color: Color(0xFFF26716),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Kursi: ${manifest[i]['seat']}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFF26716),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Terverifikasi',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Card Rincian Pembayaran
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'RINCIAN PEMBAYARAN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        paymentMethod,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF062056),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Metode Pembayaran',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        paymentMethod,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'No. Referensi / VA',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        vaNumber,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tarif Tiket (${manifest.length} Penumpang)',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        _formatCurrency(resolvedTotal),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Biaya Layanan & Penanganan',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        'Gratis',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Pembayaran',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF062056),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            _formatCurrency(resolvedTotal),
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF062056),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: status == 'Menunggu Pembayaran'
                                  ? const Color(0xFFFFF7ED)
                                  : status == 'Dibatalkan'
                                  ? const Color(0xFFFEE2E2)
                                  : const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status == 'Menunggu Pembayaran'
                                  ? 'Menunggu Bayar'
                                  : status == 'Dibatalkan'
                                  ? 'Dibatalkan'
                                  : 'Lunas',
                              style: TextStyle(
                                fontSize: 10,
                                color: status == 'Menunggu Pembayaran'
                                    ? const Color(0xFFC2410C)
                                    : status == 'Dibatalkan'
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF2E7D32),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Card Informasi Penting
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF16A34A),
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informasi Keberangkatan Penting',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF166534),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Pintu keberangkatan (boarding gate) dibuka 45 menit sebelum jadwal keberangkatan kereta. Wajib menunjukkan kartu identitas asli (e-KTP/Paspor) yang masih berlaku saat proses boarding pass.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF166534),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Tombol Aksi Utama
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: status == 'Menunggu Pembayaran'
                      ? const Color(0xFFF26716)
                      : const Color(0xFF062056),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  if (status == 'Menunggu Pembayaran') {
                    if (onPayNow != null) {
                      onPayNow!();
                    }
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ETicketBoardingPassScreen(
                          booking: BookingModel(
                            bookingId: bookingCode,
                            passengerName:
                                manifest.first['name'] ?? passengerName,
                            passengerEmail: 'user@tka.co.id',
                            passengerPhone: '+62 857-4849-4469',
                            passengerNik:
                                manifest.first['id'] ?? passengerNik,
                            trainName: trainName,
                            trainClass: trainClass,
                            originCode: origin.contains('(')
                                ? origin.split('(').last.replaceAll(')', '')
                                : 'BD',
                            originName: origin,
                            originCity: origin,
                            destCode: dest.contains('(')
                                ? dest.split('(').last.replaceAll(')', '')
                                : 'BOO',
                            destName: dest,
                            destCity: dest,
                            travelDate: travelDate,
                            departureTime: departureTime,
                            arrivalTime: arrivalTime,
                            seatNumber: displaySeats,
                            totalAmount: resolvedTotal,
                            status: status,
                            paymentMethod: paymentMethod,
                            vaNumber: vaNumber,
                            createdAt: DateTime.now(),
                            passengers: manifest,
                          ),
                          passengerName:
                              manifest.first['name'] ?? passengerName,
                          passengerNik:
                              manifest.first['id'] ?? passengerNik,
                          seatNumber: manifest.first['seat'] ?? seat,
                          passengers: manifest,
                        ),
                      ),
                    );
                  }
                },
                child: Text(
                  status == 'Menunggu Pembayaran'
                      ? 'Bayar Sekarang'
                      : 'Lihat E-Ticket & Boarding Pass',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            if (status != 'Menunggu Pembayaran') ...[
              const SizedBox(height: 10),
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
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LiveTrackingScreen(
                          trainName: trainName,
                          origin: origin,
                          destination: dest,
                          departureTime: departureTime,
                          arrivalTime: arrivalTime,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.my_location_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    'Lacak Kereta Langsung (Live)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF062056)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mengunduh Invoice Transaksi (PDF)...'),
                      backgroundColor: Color(0xFF062056),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Text(
                  'Unduh Bukti Transaksi (Invoice)',
                  style: TextStyle(
                    color: Color(0xFF062056),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Center(
              child: TextButton(
                onPressed: () async {
                  final res = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => RefundScreen(
                        bookingCode: bookingCode,
                        trainName: trainName,
                        originalPrice: totalAmount,
                        passengerName: passengerName,
                      ),
                    ),
                  );
                  if (res == true && context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
                child: const Text(
                  'Butuh Bantuan atau Ajukan Pembatalan',
                  style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
