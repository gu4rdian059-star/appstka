import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/session_service.dart';
import '../services/user_db_service.dart';
import '../dashboard/dashboard_screen.dart';
import '../tickets/my_tickets_screen.dart';

class PaymentScreen extends StatefulWidget {
  final TrainScheduleModel? schedule;
  final StationModel? origin;
  final StationModel? dest;
  final String? selectedClass;
  final int? fare;
  final String? passengerName;
  final String? passengerEmail;
  final String? passengerPhone;
  final String? passengerNik;
  final String? travelDate;
  final String? seat;
  final BookingModel? existingBooking;

  const PaymentScreen({
    super.key,
    this.schedule,
    this.origin,
    this.dest,
    this.selectedClass,
    this.fare,
    this.passengerName,
    this.passengerEmail,
    this.passengerPhone,
    this.passengerNik,
    this.travelDate,
    this.seat,
    this.existingBooking,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  // Metode pembayaran yang dipilih
  String _selectedMethod = 'QRIS'; // 'QRIS', 'TKAPay', 'BCA VA', 'Mandiri VA', 'BRI VA', 'BNI VA', 'GoPay', 'OVO', 'DANA', 'ShopeePay'
  
  // Saldo pengguna aktif
  int _userBalance = 0;
  bool _isLoadingBalance = true;

  // Timer countdown pembayaran (15 menit = 900 detik)
  late int _remainingSeconds;
  Timer? _countdownTimer;

  // Sedang memproses bayar
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = 900;
    _startTimer();
    _loadBalance();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _loadBalance() async {
    final balance = await SessionService.getUserBalance();
    if (mounted) {
      setState(() {
        _userBalance = balance;
        _isLoadingBalance = false;
      });
    }
  }

  String get _timerFormatted {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  int get _totalAmount {
    if (widget.existingBooking != null) {
      return widget.existingBooking!.totalAmount;
    }
    return widget.fare ?? widget.schedule?.baseFare ?? 250000;
  }

  String get _trainName => widget.existingBooking?.trainName ?? widget.schedule?.name ?? 'KA Argo Bromo Anggrek';
  String get _trainClass => widget.existingBooking?.trainClass ?? widget.selectedClass ?? 'Eksekutif';
  String get _originCode => widget.existingBooking?.originCode ?? widget.origin?.code ?? widget.schedule?.originCode ?? 'GMR';
  String get _originCity => widget.existingBooking?.originCity ?? widget.origin?.city ?? widget.schedule?.originCity ?? 'Jakarta Pusat';
  String get _destCode => widget.existingBooking?.destCode ?? widget.dest?.code ?? widget.schedule?.destCode ?? 'SBI';
  String get _destCity => widget.existingBooking?.destCity ?? widget.dest?.city ?? widget.schedule?.destCity ?? 'Surabaya';
  String get _departureTime => widget.existingBooking?.departureTime ?? widget.schedule?.departureTime ?? '08:20 WIB';
  String get _arrivalTime => widget.existingBooking?.arrivalTime ?? widget.schedule?.arrivalTime ?? '16:25 WIB';
  String get _travelDate => widget.existingBooking?.travelDate ?? widget.travelDate ?? 'Besok';
  String get _passengerName => widget.existingBooking?.passengerName ?? widget.passengerName ?? 'Penumpang TKA';
  String get _passengerNik => widget.existingBooking?.passengerNik ?? widget.passengerNik ?? '3514062607090001';
  String get _passengerPhone => widget.existingBooking?.passengerPhone ?? widget.passengerPhone ?? '+62 812-3456-7890';
  String get _seatNumber => widget.existingBooking?.seatNumber ?? widget.seat ?? 'Gerbong 2 / Kursi 7A';

  String _formatCurrency(int amount) {
    return 'Rp${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label berhasil disalin ke clipboard!'),
        backgroundColor: const Color(0xFF062056),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _generateVaOrRef() {
    final now = DateTime.now().millisecondsSinceEpoch.toString();
    switch (_selectedMethod) {
      case 'QRIS':
        return 'NMID-938210948${now.substring(now.length - 4)}';
      case 'TKAPay':
        return 'TKAPAY-${now.substring(now.length - 8)}';
      case 'BCA VA':
        return '8277 0812 ${now.substring(now.length - 6)}';
      case 'Mandiri VA':
        return '8870 0812 ${now.substring(now.length - 6)}';
      case 'BRI VA':
        return '1023 0812 ${now.substring(now.length - 6)}';
      case 'BNI VA':
        return '9881 0812 ${now.substring(now.length - 6)}';
      case 'GoPay':
      case 'OVO':
      case 'DANA':
      case 'ShopeePay':
        return '${_selectedMethod.toUpperCase()}-$now';
      default:
        return 'VA-$now';
    }
  }

  // Buka Sheet Top Up jika saldo TKAPay kurang
  void _openTopUpSheet() {
    final amounts = [50000, 100000, 200000, 500000, 1000000];
    int selectedAmount = _totalAmount > _userBalance ? (_totalAmount - _userBalance).clamp(50000, 1000000) : 100000;
    
    // Sesuaikan pilihan terdekat dengan harga tiket
    if (!amounts.contains(selectedAmount)) {
      amounts.add(selectedAmount);
      amounts.sort();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Top Up Saldo TKAPay Instan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF062056)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Saldo saat ini: ${_formatCurrency(_userBalance)}. Pilih nominal untuk menambah saldo secara instan:',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: amounts.map((amt) {
                  final isSelected = selectedAmount == amt;
                  return ChoiceChip(
                    label: Text(_formatCurrency(amt)),
                    selected: isSelected,
                    selectedColor: const Color(0xFF062056),
                    backgroundColor: const Color(0xFFF1F4F9),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF062056),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    onSelected: (val) {
                      if (val) setModalState(() => selectedAmount = amt);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF062056),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    final newBal = _userBalance + selectedAmount;
                    await SessionService.setUserBalance(newBal);
                    setState(() {
                      _userBalance = newBal;
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Top Up ${_formatCurrency(selectedAmount)} Berhasil! Saldo sekarang: ${_formatCurrency(newBal)}'),
                          backgroundColor: const Color(0xFF10B981),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: Text(
                    'Top Up ${_formatCurrency(selectedAmount)} Sekarang',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Eksekusi Pembayaran Sukses
  Future<void> _processPayment() async {
    // Validasi saldo jika pakai TKAPay
    if (_selectedMethod == 'TKAPay' && _userBalance < _totalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saldo TKAPay Anda kurang ${_formatCurrency(_totalAmount - _userBalance)}. Silakan Top Up terlebih dahulu.'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Top Up',
            textColor: Colors.white,
            onPressed: _openTopUpSheet,
          ),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    // Tampilkan modal pemrosesan realistis
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF062056)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Memproses Pembayaran...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF062056),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Menghubungkan ke gateway $_selectedMethod & memverifikasi transaksi tiket...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Simulasi delay gateway 1.2 detik
    await Future.delayed(const Duration(milliseconds: 1200));

    final refCode = _generateVaOrRef();
    BookingModel finalBooking;

    if (widget.existingBooking != null) {
      // Pembayaran pesanan yang sudah ada (dari status Menunggu Pembayaran)
      final res = await UserDatabaseService.payBooking(
        bookingId: widget.existingBooking!.bookingId,
        paymentMethod: _selectedMethod,
        vaNumber: refCode,
      );
      finalBooking = res ?? widget.existingBooking!.copyWith(status: 'Sudah Dibayar');
    } else {
      // Buat booking baru yang langsung berstatus Sudah Dibayar
      finalBooking = await UserDatabaseService.createBooking(
        schedule: widget.schedule!,
        selectedClass: widget.selectedClass ?? 'Eksekutif',
        passengerName: _passengerName,
        passengerEmail: widget.passengerEmail ?? 'user@tka.co.id',
        passengerPhone: _passengerPhone,
        passengerNik: _passengerNik,
        travelDate: _travelDate,
        status: 'Sudah Dibayar',
        paymentMethod: _selectedMethod,
        vaNumber: refCode,
        customFare: _totalAmount,
        customSeat: _seatNumber,
      );
    }

    // Jika bayar pakai TKAPay, potong saldo
    if (_selectedMethod == 'TKAPay') {
      final newBal = (_userBalance - _totalAmount).clamp(0, 999999999);
      await SessionService.setUserBalance(newBal);
      setState(() => _userBalance = newBal);
    }

    // Berikan reward poin loyalitas (2 poin per Rp 1.000)
    final earnedPoints = (_totalAmount ~/ 1000) * 2;
    final currentPoints = await SessionService.getUserPoints();
    await SessionService.setUserPoints(currentPoints + earnedPoints);

    if (!mounted) return;
    Navigator.of(context).pop(); // Tutup dialog loading
    setState(() => _isProcessing = false);

    // Tampilkan Dialog Sukses Pembayaran
    _showPaymentSuccessDialog(finalBooking, earnedPoints);
  }

  // Simpan Sebagai Pesanan Menunggu Pembayaran (Bayar Nanti)
  Future<void> _saveAsPendingOrder() async {
    setState(() => _isProcessing = true);
    final refCode = _generateVaOrRef();

    BookingModel pendingBooking;
    if (widget.existingBooking != null) {
      pendingBooking = widget.existingBooking!;
    } else {
      pendingBooking = await UserDatabaseService.createBooking(
        schedule: widget.schedule!,
        selectedClass: widget.selectedClass ?? 'Eksekutif',
        passengerName: _passengerName,
        passengerEmail: widget.passengerEmail ?? 'user@tka.co.id',
        passengerPhone: _passengerPhone,
        passengerNik: _passengerNik,
        travelDate: _travelDate,
        status: 'Menunggu Pembayaran',
        paymentMethod: _selectedMethod,
        vaNumber: refCode,
        customFare: _totalAmount,
        customSeat: _seatNumber,
      );
    }

    if (!mounted) return;
    setState(() => _isProcessing = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.schedule_rounded, color: Color(0xFFF26716), size: 24),
            SizedBox(width: 10),
            Text('Pesanan Disimpan!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF062056))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reservasi kode booking ${pendingBooking.bookingId} telah disimpan.',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFEDD5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Metode: $_selectedMethod', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text('Kode Bayar / VA: $refCode', style: const TextStyle(fontSize: 11, color: Color(0xFFC2410C))),
                  const SizedBox(height: 4),
                  const Text('Silakan selesaikan pembayaran sebelum waktu habis di menu Pesanan.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF062056),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop(); // Tutup dialog
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const DashboardScreen(initialTabIndex: 1)), // Tab Pesanan
                (route) => false,
              );
            },
            child: const Text('Ke Daftar Pesanan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPaymentSuccessDialog(BookingModel booking, int earnedPoints) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon Sukses
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
                  ),
                  child: const Center(
                    child: Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 38),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Pembayaran Berhasil!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF062056)),
                ),
                const SizedBox(height: 4),
                const Text(
                  'E-Ticket resmi Anda telah terbit dan tersimpan di database.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),

                // Detail Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFD),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Kode Booking (PNR)', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                          Text(
                            booking.bookingId,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF062056)),
                          ),
                        ],
                      ),
                      const Divider(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Kereta & Kursi', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                          Text(
                            '${booking.trainName} • ${booking.seatNumber}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Metode Pembayaran', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                          Text(
                            booking.paymentMethod,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF10B981)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Pembayaran', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                          Text(
                            _formatCurrency(booking.totalAmount),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Color(0xFFF26716)),
                          ),
                        ],
                      ),
                      if (earnedPoints > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Poin Diperoleh', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                            Text(
                              '+$earnedPoints TKA Poin',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFFF26716)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Tombol Aksi
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF062056),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const DashboardScreen(initialTabIndex: 2)), // Tab Tiket Saya
                        (route) => false,
                      );
                    },
                    child: const Text(
                      'Lihat E-Ticket & Boarding Pass',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const DashboardScreen(initialTabIndex: 0)), // Beranda
                      (route) => false,
                    );
                  },
                  child: const Text(
                    'Kembali ke Beranda',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062056),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Pembayaran Reservasi',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, size: 14, color: Color(0xFFFFB74D)),
                const SizedBox(width: 5),
                Text(
                  _timerFormatted,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner Batas Pembayaran
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF7ED),
              border: Border(bottom: BorderSide(color: Color(0xFFFFEDD5))),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFF26716)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Selesaikan pembayaran dalam $_timerFormatted agar tiket tidak kedaluwarsa.',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFFC2410C), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          // Body Konten
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Ringkasan Perjalanan & Kereta
                  _buildTripSummaryCard(),

                  const SizedBox(height: 16),

                  // 2. Pilih Metode Pembayaran
                  const Text(
                    'PILIH METODE PEMBAYARAN',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF062056),
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Option 1: QRIS
                  _buildPaymentOptionCard(
                    id: 'QRIS',
                    title: 'QRIS (Instant Pay)',
                    subtitle: 'BCA, Mandiri, BRI, BNI, GoPay, OVO, ShopeePay, DANA',
                    icon: Icons.qr_code_scanner_rounded,
                    iconBg: const Color(0xFFF0FDF4),
                    iconColor: const Color(0xFF16A34A),
                    badge: 'Rekomendasi',
                    badgeColor: const Color(0xFF10B981),
                    child: _buildQrisDetail(),
                  ),

                  const SizedBox(height: 10),

                  // Option 2: TKAPay (Saldo Akun)
                  _buildPaymentOptionCard(
                    id: 'TKAPay',
                    title: 'TKAPay (Saldo Akun)',
                    subtitle: _isLoadingBalance ? 'Memuat saldo...' : 'Saldo Anda: ${_formatCurrency(_userBalance)}',
                    icon: Icons.account_balance_wallet_rounded,
                    iconBg: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF0284C7),
                    badge: _userBalance >= _totalAmount ? 'Saldo Cukup' : 'Saldo Kurang',
                    badgeColor: _userBalance >= _totalAmount ? const Color(0xFF10B981) : const Color(0xFFF26716),
                    child: _buildTkaPayDetail(),
                  ),

                  const SizedBox(height: 10),

                  // Option 3: Virtual Account BCA
                  _buildPaymentOptionCard(
                    id: 'BCA VA',
                    title: 'BCA Virtual Account',
                    subtitle: 'Verifikasi instan otomatis 24 Jam',
                    icon: Icons.account_balance_rounded,
                    iconBg: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF005BAC),
                    child: _buildVaDetail('BCA Virtual Account', '8277 0812 3456 7890'),
                  ),

                  const SizedBox(height: 10),

                  // Option 4: Virtual Account Mandiri
                  _buildPaymentOptionCard(
                    id: 'Mandiri VA',
                    title: 'Mandiri Virtual Account',
                    subtitle: 'Transfer via Livin\' by Mandiri & ATM',
                    icon: Icons.account_balance_rounded,
                    iconBg: const Color(0xFFFFFBEB),
                    iconColor: const Color(0xFFD97706),
                    child: _buildVaDetail('Mandiri Virtual Account', '8870 0812 9845 2311'),
                  ),

                  const SizedBox(height: 10),

                  // Option 5: Virtual Account BRI (BRIVA)
                  _buildPaymentOptionCard(
                    id: 'BRI VA',
                    title: 'BRI Virtual Account (BRIVA)',
                    subtitle: 'Transfer via BRImo & ATM BRI',
                    icon: Icons.account_balance_rounded,
                    iconBg: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF0284C7),
                    child: _buildVaDetail('BRI Virtual Account', '1023 0812 7741 0924'),
                  ),

                  const SizedBox(height: 10),

                  // Option 6: Virtual Account BNI
                  _buildPaymentOptionCard(
                    id: 'BNI VA',
                    title: 'BNI Virtual Account',
                    subtitle: 'Transfer via BNI Mobile Banking & ATM',
                    icon: Icons.account_balance_rounded,
                    iconBg: const Color(0xFFF0FDF4),
                    iconColor: const Color(0xFF059669),
                    child: _buildVaDetail('BNI Virtual Account', '9881 0812 6542 3319'),
                  ),

                  const SizedBox(height: 10),

                  // Option 7: E-Wallet (GoPay / DANA)
                  _buildPaymentOptionCard(
                    id: 'GoPay',
                    title: 'GoPay / GoPay Later',
                    subtitle: 'Nomor: $_passengerPhone',
                    icon: Icons.phone_android_rounded,
                    iconBg: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF00AED6),
                    child: _buildEWalletDetail('GoPay'),
                  ),

                  const SizedBox(height: 10),

                  _buildPaymentOptionCard(
                    id: 'DANA',
                    title: 'DANA Dompet Digital',
                    subtitle: 'Nomor: $_passengerPhone',
                    icon: Icons.account_balance_wallet_outlined,
                    iconBg: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF118EEA),
                    child: _buildEWalletDetail('DANA'),
                  ),

                  const SizedBox(height: 20),

                  // 3. Rincian Biaya
                  _buildPriceBreakdownCard(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Bottom Bar & Tombol Bayar
          _buildBottomBar(),
        ],
      ),
    );
  }

  // 1. Card Ringkasan Kereta (Dengan layout responsif anti-overflow)
  Widget _buildTripSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(14),
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF062056),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.train_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _trainName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF062056),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _trainClass,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF062056)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Timeline Stasiun Tanpa Overflow
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_departureTime, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF062056))),
                  const SizedBox(height: 1),
                  Text(_originCode, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFF062056), shape: BoxShape.circle)),
                          Expanded(child: Container(height: 1, color: Colors.grey.shade300)),
                          const Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF062056)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text('Langsung', style: TextStyle(fontSize: 9, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_arrivalTime, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF062056))),
                  const SizedBox(height: 1),
                  Text(_destCode, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
                ],
              ),
            ],
          ),
          
          const Divider(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Penumpang: $_passengerName • $_seatNumber',
                  style: const TextStyle(fontSize: 11.5, color: Colors.black87, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _travelDate,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. Card Opsi Metode Pembayaran
  Widget _buildPaymentOptionCard({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    String? badge,
    Color? badgeColor,
    Widget? child,
  }) {
    final isSelected = _selectedMethod == id;

    return InkWell(
      onTap: () => setState(() => _selectedMethod = id),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF9FBFF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF062056) : Colors.grey.shade200,
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF062056).withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B1E28),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (badgeColor ?? const Color(0xFF10B981)).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                badge,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: badgeColor ?? const Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: isSelected ? const Color(0xFF062056) : Colors.grey.shade400,
                  size: 20,
                ),
              ],
            ),

            // Detail Accordion jika opsi ini terpilih
            if (isSelected && child != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              child,
            ],
          ],
        ),
      ),
    );
  }

  // Detail Khusus QRIS
  Widget _buildQrisDetail() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              // Mock QR Code Graphic
              Container(
                width: 150,
                height: 150,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Grid motif QR
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        7,
                        (row) => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                            7,
                            (col) => Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: ((row + col) % 2 == 0 || (row < 2 && col < 2) || (row > 4 && col < 2) || (row < 2 && col > 4))
                                    ? const Color(0xFF062056)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Logo TKA Tengah
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF062056), width: 1.5),
                      ),
                      child: const Text(
                        'TKA',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF062056)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'PT KERETA API TKA INDONESIA',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF062056)),
              ),
              const Text(
                'NMID: ID1020083921094',
                style: TextStyle(fontSize: 10.5, color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '1. Buka aplikasi BCA, Mandiri, BRI, BNI, GoPay, OVO, atau DANA.\n2. Pilih menu Scan QRIS dan arahkan ke kode QR di atas.\n3. Periksa nominal pembayaran dan konfirmasi transaksi.',
          style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.4),
        ),
      ],
    );
  }

  // Detail Khusus TKAPay
  Widget _buildTkaPayDetail() {
    final isEnough = _userBalance >= _totalAmount;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isEnough ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isEnough ? const Color(0xFFBBF7D0) : const Color(0xFFFFEDD5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Saldo TKAPay Anda: ${_formatCurrency(_userBalance)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isEnough ? const Color(0xFF166534) : const Color(0xFFC2410C),
                ),
              ),
              if (!isEnough)
                TextButton(
                  onPressed: _openTopUpSheet,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('+ Top Up Saldo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF062056))),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isEnough
                ? 'Saldo mencukupi! Pembayaran akan dipotong langsung dari saldo TKAPay Anda saat menekan tombol Bayar Sekarang.'
                : 'Saldo tidak mencukupi untuk tiket ini. Silakan tekan + Top Up Saldo untuk mengisi saldo secara instan.',
            style: TextStyle(fontSize: 11, color: isEnough ? const Color(0xFF166534) : const Color(0xFFC2410C), height: 1.3),
          ),
        ],
      ),
    );
  }

  // Detail Khusus Virtual Account
  Widget _buildVaDetail(String bankName, String vaNumber) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nomor Virtual Account', style: TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                vaNumber,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  color: Color(0xFF062056),
                ),
              ),
              InkWell(
                onTap: () => _copyToClipboard(vaNumber.replaceAll(' ', ''), 'Nomor Virtual Account'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF062056),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.copy_rounded, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Salin', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Transfer tepat sejumlah ${_formatCurrency(_totalAmount)}. Transaksi akan terverifikasi otomatis dalam 1 menit.',
            style: const TextStyle(fontSize: 11, color: Colors.grey, height: 1.3),
          ),
        ],
      ),
    );
  }

  // Detail Khusus E-Wallet
  Widget _buildEWalletDetail(String walletName) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_outlined, size: 18, color: Color(0xFF062056)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Notifikasi persetujuan transaksi $walletName akan dikirimkan ke nomor ponsel $_passengerPhone saat Anda menekan Bayar Sekarang.',
              style: const TextStyle(fontSize: 11, color: Colors.black87, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Card Rincian Biaya
  Widget _buildPriceBreakdownCard() {
    return Container(
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
            'RINCIAN PEMBAYARAN',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.grey,
              letterSpacing: 0.8,
            ),
          ),
          const Divider(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tarif Tiket ($_trainClass)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(_formatCurrency(_totalAmount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Biaya Layanan & Pemesanan', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('Gratis (Rp 0)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
            ],
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Biaya Penanganan Gateway', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('Gratis (Rp 0)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
            ],
          ),
          const Divider(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Tagihan',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF062056),
                ),
              ),
              Text(
                _formatCurrency(_totalAmount),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFF26716),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 4. Floating Bottom Bar
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Pembayaran', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(
                    _formatCurrency(_totalAmount),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFF26716),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Tombol Bayar Nanti (Simpan Pesanan)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Color(0xFF062056)),
                    ),
                    onPressed: _isProcessing ? null : _saveAsPendingOrder,
                    child: const Text(
                      'Bayar Nanti',
                      style: TextStyle(
                        color: Color(0xFF062056),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Tombol Bayar Sekarang (Konfirmasi)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF062056),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    onPressed: _isProcessing ? null : _processPayment,
                    child: const Text(
                      'Bayar Sekarang',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
