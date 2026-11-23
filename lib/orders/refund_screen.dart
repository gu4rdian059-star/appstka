import 'package:flutter/material.dart';

import '../services/user_db_service.dart';

class RefundScreen extends StatefulWidget {
  final String bookingCode;
  final String trainName;
  final String route;
  final int originalPrice;
  final String passengerName;

  const RefundScreen({
    super.key,
    this.bookingCode = 'TKA-9921XB',
    this.trainName = 'KA Argo Bromo Anggrek',
    this.route = 'Gambir (GMR) ➔ Surabaya Pasarturi (SBI)',
    this.originalPrice = 640000,
    this.passengerName = 'Samuel',
  });

  @override
  State<RefundScreen> createState() => _RefundScreenState();
}

class _RefundScreenState extends State<RefundScreen> {
  int _selectedReason = 0;
  bool _agreed = false;
  bool _isSubmitting = false;

  final List<String> _reasons = [
    'Perubahan rencana perjalanan',
    'Sakit / Kondisi darurat keluarga',
    'Kesalahan memilih jadwal / rute stasiun',
    'Alasan operasional lainnya',
  ];

  void _submitRefund() async {
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Silakan setujui ketentuan pembatalan terlebih dahulu.',
          ),
          backgroundColor: Color(0xFFF26716),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    await UserDatabaseService.cancelBookingWithRefund(
      bookingCode: widget.bookingCode,
      reason: _reasons[_selectedReason],
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF10B981),
                size: 28,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pengajuan Berhasil',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF062056),
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Permohonan pembatalan tiket Anda telah diterima. Estimasi dana pengembalian (75%) akan dikirimkan ke rekening tujuan dalam 14–30 hari kerja.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(true);
              },
              child: const Text(
                'Selesai',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF062056),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatCurrency(int amount) {
    return 'Rp${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    final fee = (widget.originalPrice * 0.25).round();
    final refundEstimate = widget.originalPrice - fee;

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
          'Pembatalan Dan Pengembalian Dana',
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF062056),
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.help_outline_rounded,
              color: Color(0xFF062056),
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tahap 1 dari 2
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F1FC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF062056),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Tahap 1 dari 2: Verifikasi Pengajuan Refund',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF062056),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Card Tiket Terdaftar
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
                        'TIKET TERDAFTAR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF062056),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.bookingCode,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Text(
                    widget.trainName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF062056),
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'KA 2 • Eksekutif • Kursi EKS-2 / 5C',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.train_rounded,
                        size: 16,
                        color: Color(0xFF062056),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.route,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1B1E28),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Penumpang: ${widget.passengerName}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        _formatCurrency(widget.originalPrice),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF062056),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Card Ketentuan & Regulasi
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.gavel_rounded,
                        size: 18,
                        color: Color(0xFFD97706),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Ketentuan & Regulasi Operasional TKA',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Pembatalan tiket tunduk penuh pada regulasi operasional TKA dan aturan operator perkeretaapian. Permohonan pembatalan dapat diajukan maksimal 2 jam sebelum jadwal keberangkatan kereta api.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF92400E),
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Penting: Pengembalian dana (refund) diproses melalui verifikasi manual dan sistem kliring perbankan mitra dalam 14–30 hari kerja sesuai metode pembayaran asal.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF92400E),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Simulasi Perhitungan Dana
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
                  const Text(
                    'Simulasi Perhitungan Dana',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF062056),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Harga Tiket Awal (1 Penumpang)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        _formatCurrency(widget.originalPrice),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Bea Pembatalan Resmi (25%)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      Text(
                        '-${_formatCurrency(fee)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Estimasi Pengembalian',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF062056),
                        ),
                      ),
                      Text(
                        _formatCurrency(refundEstimate),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFD),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.account_balance_rounded,
                          size: 18,
                          color: Color(0xFF062056),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tujuan Rekening: BCA 1234567890 a/n Mukhammad Safid M',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Alasan Pembatalan
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
                  const Text(
                    'Alasan Pembatalan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF062056),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(_reasons.length, (i) {
                    return RadioListTile<int>(
                      contentPadding: EdgeInsets.zero,
                      value: i,
                      groupValue: _selectedReason,
                      activeColor: const Color(0xFF062056),
                      title: Text(
                        _reasons[i],
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedReason = val);
                      },
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Checkbox persetujuan
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _agreed,
                    activeColor: const Color(0xFF062056),
                    onChanged: (val) => setState(() => _agreed = val ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Saya telah membaca, memahami, dan menyetujui seluruh ketentuan pemotongan bea administrasi 25% serta estimasi jangka waktu kliring perbankan 14–30 hari kerja sesuai regulasi resmi perkeretaapian TKA.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // Tombol Ajukan Pembatalan
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF062056),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSubmitting ? null : _submitRefund,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Ajukan Pembatalan Tiket',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 10),

            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text(
                  'Batalkan & Kembali ke E-Ticket',
                  style: TextStyle(
                    color: Color(0xFF062056),
                    fontSize: 13,
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
