import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/user_db_service.dart';
import '../dashboard/dashboard_screen.dart';
import '../tickets/eticket_boarding_pass_screen.dart';

class TransactionStatusScreen extends StatelessWidget {
  final BookingModel booking;
  final String transactionNumber;
  final String paymentMethod;
  final int paidAmount;
  final String seatNumber;
  final String passengerName;
  final String passengerNik;
  final List<Map<String, String>>? passengers;

  const TransactionStatusScreen({
    super.key,
    required this.booking,
    required this.transactionNumber,
    required this.paymentMethod,
    required this.paidAmount,
    required this.seatNumber,
    required this.passengerName,
    required this.passengerNik,
    this.passengers,
  });

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label $text berhasil disalin!'),
        backgroundColor: const Color(0xFF0256B8),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  String _formatCurrency(int amount) {
    return 'Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeStr =
        '${now.day} Nov ${now.year}, ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} WIB';
    final simpleTimeStr =
        '${now.day} Nov ${now.year}, ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} WIB';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF062056),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'TKA',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Status Transaksi',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF062056),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, size: 12, color: Color(0xFFEA580C)),
                SizedBox(width: 4),
                Text(
                  'SECURE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEA580C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        child: Column(
          children: [
            // 1. Ikon Sukses Terverifikasi (Pulsing Green Checkmark)
            Center(
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF86EFAC), width: 3),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF16A34A),
                  size: 38,
                ),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF16A34A),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    'Sistem Pembayaran Terverifikasi',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            const Text(
              'Pembayaran Berhasil & Terverifikasi',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Terima kasih, pembayaran Anda telah divalidasi oleh sistem payment gateway TKA. E-Ticket resmi telah diterbitkan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 14),

            // Pill Waktu Verifikasi Gateway
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 2,
                children: [
                  Text(
                    'Waktu Verifikasi Gateway',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. Card INFORMASI TRANSAKSI (Badge LUNAS)
            _buildTransactionInfoCard(context, simpleTimeStr),

            const SizedBox(height: 14),

            // 3. Card SIKLUS STATUS TRANSAKSI (Stepper Horisontal)
            _buildStatusLifecycleCard(),

            const SizedBox(height: 14),

            // 4. Card RINGKASAN TIKET DIAMANKAN
            _buildSecuredTicketCard(),

            const SizedBox(height: 14),

            // 5. Card Sinkronisasi Otomatis Real-Time
            _buildRealtimeSyncCard(),

            const SizedBox(height: 20),

            // 6. Tombol Aksi Bawah
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF062056),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  // Buka Gambar 5: ETicket & Boarding Pass
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ETicketBoardingPassScreen(
                        booking: booking,
                        passengerName: passengerName,
                        passengerNik: passengerNik,
                        seatNumber: seatNumber,
                        passengers: passengers,
                      ),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.download_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                label: const Text(
                  'Lihat & Unduh E-Ticket (PDF)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const DashboardScreen(initialTabIndex: 0),
                  ),
                  (route) => false,
                );
              },
              icon: const Icon(
                Icons.home_outlined,
                size: 16,
                color: Color(0xFF64748B),
              ),
              label: const Text(
                'Kembali ke Beranda',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SUB WIDGETS
  // ===========================================================================

  Widget _buildTransactionInfoCard(BuildContext context, String simpleTimeStr) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.receipt_rounded,
                      size: 16,
                      color: Color(0xFF0256B8),
                    ),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'INFORMASI TRANSAKSI',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 10,
                      color: Color(0xFF16A34A),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'LUNAS',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 18),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kode Booking (PNR)',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            booking.bookingId,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.copy_rounded,
                            size: 13,
                            color: Colors.grey,
                          ),
                          onPressed: () => _copyToClipboard(
                            context,
                            booking.bookingId,
                            'Kode Booking',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Nomor Transaksi',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            transactionNumber,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.copy_rounded,
                            size: 13,
                            color: Colors.grey,
                          ),
                          onPressed: () => _copyToClipboard(
                            context,
                            transactionNumber,
                            'Nomor Transaksi',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Metode Pembayaran',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    Text(
                      paymentMethod,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Text(
                      '(Otomatis Webhook)',
                      style: TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Total Nominal',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    Text(
                      _formatCurrency(paidAmount),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Waktu Transaksi',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    Text(
                      simpleTimeStr,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Batas Waktu Bayar',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    Text(
                      'Tervalidasi Lebih Cepat',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusLifecycleCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SIKLUS STATUS TRANSAKSI',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLifecycleStep('Menunggu', isDone: true),
              _buildLifecycleDivider(isDone: true),
              _buildLifecycleStep('Berhasil', isDone: true, isCurrent: true),
              _buildLifecycleDivider(isDone: false),
              _buildLifecycleStep('Gagal', isDone: false),
              _buildLifecycleDivider(isDone: false),
              _buildLifecycleStep('Refund', isDone: false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLifecycleStep(
    String label, {
    required bool isDone,
    bool isCurrent = false,
  }) {
    return Column(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: isCurrent
                ? const Color(0xFF16A34A)
                : (isDone ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9)),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDone ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
            ),
          ),
          child: Icon(
            Icons.check,
            size: 11,
            color: isCurrent
                ? Colors.white
                : (isDone ? const Color(0xFF16A34A) : Colors.grey),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
            color: isCurrent ? const Color(0xFF16A34A) : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildLifecycleDivider({required bool isDone}) {
    return Expanded(
      child: Container(
        height: 2,
        color: isDone ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
      ),
    );
  }

  Widget _buildSecuredTicketCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'RINGKASAN TIKET DIAMANKAN',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '1 Kursi',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.trainName,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      booking.trainClass,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'NO. KURSI',
                    style: TextStyle(fontSize: 8.5, color: Colors.grey),
                  ),
                  Text(
                    booking.seatNumber,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0256B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${booking.departureTime} • ${booking.originName} (${booking.originCode})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 12,
                  color: Colors.grey,
                ),
              ),
              Expanded(
                child: Text(
                  '${booking.arrivalTime} • ${booking.destName} (${booking.destCode})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Manifest Terdaftar
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DAFTAR PENUMPANG TERDAFTAR',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (passengers != null && passengers!.isNotEmpty)
                        ...passengers!.asMap().entries.map((entry) {
                          final i = entry.key;
                          final p = entry.value;
                          final name = p['name'] ?? passengerName;
                          final seat = p['seat'] ?? seatNumber;
                          return Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '${i + 1}. $name • Dewasa • Kursi $seat',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          );
                        })
                      else
                        Text(
                          '1. $passengerName • Dewasa • Kursi $seatNumber',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Siap Boarding',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealtimeSyncCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sync_rounded, size: 18, color: Color(0xFF0256B8)),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sinkronisasi Otomatis Real-Time',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Status pemesanan telah tersinkronisasi langsung dengan Admin Dashboard TKA & Sistem Boarding Stasiun PT Kereta Api. Cukup pindai barcode e-ticket saat memasuki peron stasiun.',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF3B82F6),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
