import 'package:flutter/material.dart';

import '../services/session_service.dart';
import '../services/user_db_service.dart';
import 'qris_payment_screen.dart';
import 'transaction_status_screen.dart';

class PaymentMethodScreen extends StatefulWidget {
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

  const PaymentMethodScreen({
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
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  String _selectedMethod = 'BCA Virtual Account'; // Default
  int _userBalance = 0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final bal = await SessionService.getUserBalance();
    if (mounted) setState(() => _userBalance = bal);
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

  void _processPayment() async {
    if (_isProcessing) return;

    // Jika metode QRIS dipilih, arahkan ke layar QRIS khusus sesuai permintaan pengguna
    if (_selectedMethod == 'QRIS') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QrisPaymentScreen(
            bookingCode: widget.bookingCode,
            train: widget.train,
            origin: widget.origin,
            dest: widget.dest,
            travelDate: widget.travelDate,
            bookerName: widget.bookerName,
            bookerEmail: widget.bookerEmail,
            bookerPhone: widget.bookerPhone,
            passengerName:
                _manifestPassengers[0]['name'] ?? widget.passengerName,
            passengerNik: _manifestPassengers[0]['id'] ?? widget.passengerNik,
            passengers: _manifestPassengers,
            selectedSeat: widget.selectedSeat,
            seatSide: widget.seatSide,
            totalAmount: widget.totalAmount,
          ),
        ),
      );
      return;
    }

    // Validasi saldo jika memilih TKAPay
    if (_selectedMethod == 'TKAPay' && _userBalance < widget.totalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Saldo TKAPay Anda tidak mencukupi. Silakan pilih metode lain atau lakukan Top Up.',
          ),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    // Dialog Animasi Memproses Pembayaran
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              const CircularProgressIndicator(color: Color(0xFF0256B8)),
              const SizedBox(height: 20),
              const Text(
                'Memverifikasi Pembayaran',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF062056),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Menghubungkan ke gateway $_selectedMethod & menyinkronkan data ${_manifestPassengers.length} penumpang ke Supabase...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 1400));

    // 1. Simpan booking ke UserDatabaseService untuk SELURUH penumpang (Lokal & Supabase DB)
    final referenceNumber =
        'TRX-${DateTime.now().millisecondsSinceEpoch.toString().substring(3)}';
    final vaNumber =
        'VA-900${(1000000 + DateTime.now().millisecondsSinceEpoch % 9000000)}';

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
        paymentMethod: _selectedMethod,
        vaNumber: vaNumber,
        totalFare: widget.totalAmount,
      );

      // 3. Potong saldo jika bayar pakai TKAPay
      if (_selectedMethod == 'TKAPay') {
        final newBal = _userBalance - widget.totalAmount;
        await SessionService.setUserBalance(newBal);
      }

      if (!mounted) return;
      Navigator.of(context).pop(); // Tutup dialog loading
      setState(() => _isProcessing = false);

      // Pindah ke Gambar 4 Kolom 3: Status Transaksi & Pembayaran
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              TransactionStatusScreen(
                booking: primaryBooking,
                transactionNumber: referenceNumber,
                paymentMethod: _selectedMethod,
                paidAmount: widget.totalAmount,
                seatNumber: widget.selectedSeat,
                passengerName:
                    _manifestPassengers[0]['name'] ?? widget.passengerName,
                passengerNik:
                    _manifestPassengers[0]['id'] ?? widget.passengerNik,
                passengers: _manifestPassengers,
              ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kendala saat pembayaran: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showTopUpSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Isi Ulang Saldo TKAPay',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF062056),
              ),
            ),
            const SizedBox(height: 12),
            ...[50000, 100000, 200000, 500000, 1000000].map(
              (nominal) => ListTile(
                leading: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Color(0xFFF26716),
                ),
                title: Text(
                  _formatCurrency(nominal),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () async {
                  final newBal = _userBalance + nominal;
                  await SessionService.setUserBalance(newBal);
                  if (!mounted) return;
                  setState(() => _userBalance = newBal);
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Top Up ${_formatCurrency(nominal)} berhasil! Saldo TKAPay bertambah.',
                      ),
                      backgroundColor: const Color(0xFF16A34A),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF062056)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Payment Method',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF062056),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Card TKAPay (Persis Gambar 4 Kolom 2)
                  _buildTkaPayCard(),

                  const SizedBox(height: 18),

                  // 2. Section QRIS
                  _buildSectionTitle('QRIS'),
                  _buildMethodItem(
                    id: 'QRIS',
                    title: 'QRIS',
                    subtitle: 'GoPay, OVO, DANA, BCA, Livin\', ShopeePay',
                    customLeading: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'QRIS',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 3. Section E-WALLET
                  _buildSectionTitle('E-WALLET'),
                  _buildMethodItem(
                    id: 'MOTIONPAY',
                    title: 'MOTIONPAY',
                    icon: Icons.wallet_rounded,
                  ),
                  _buildMethodItem(
                    id: 'OVO',
                    title: 'OVO',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  _buildMethodItem(
                    id: 'SHOPEEPAY',
                    title: 'SHOPEEPAY',
                    icon: Icons.shopping_bag_outlined,
                  ),

                  const SizedBox(height: 18),

                  // 4. Section VIRTUAL ACCOUNT
                  _buildSectionTitle('VIRTUAL ACCOUNT'),
                  _buildMethodItem(
                    id: 'BCA Virtual Account',
                    title: 'BCA Virtual Account',
                    subtitle: 'Verifikasi Otomatis',
                    bankBadge: 'BCA',
                  ),
                  _buildMethodItem(
                    id: 'Mandiri Virtual Account',
                    title: 'Mandiri Virtual Account',
                    subtitle: 'Livin\' by Mandiri',
                    bankBadge: 'MDR',
                  ),
                  _buildMethodItem(
                    id: 'BNI Virtual Account',
                    title: 'BNI Virtual Account',
                    subtitle: 'BNI Mobile Banking',
                    bankBadge: 'BNI',
                  ),
                  _buildMethodItem(
                    id: 'BRI Virtual Account (BRIVA)',
                    title: 'BRI Virtual Account (BRIVA)',
                    subtitle: 'BRImo & ATM BRI',
                    bankBadge: 'BRI',
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Sticky Bottom Bar: Total Price & Button "Pay"
          _buildStickyBottomBar(),
        ],
      ),
    );
  }

  // ===========================================================================
  // SUB WIDGETS
  // ===========================================================================

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTkaPayCard() {
    final isSelected = _selectedMethod == 'TKAPay';

    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = 'TKAPay'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0256B8)
                : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF7ED),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Color(0xFFEA580C),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TKAPay',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _formatCurrency(_userBalance),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 1),
                  const Text(
                    'co-Branding with KASPRO',
                    style: TextStyle(fontSize: 9.5, color: Colors.grey),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF0256B8)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
              ),
              onPressed: _showTopUpSheet,
              child: const Text(
                'Top Up',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0256B8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodItem({
    required String id,
    required String title,
    String? subtitle,
    IconData? icon,
    Widget? customLeading,
    String? bankBadge,
  }) {
    final isSelected = _selectedMethod == id;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? const Color(0xFF0256B8) : const Color(0xFFE2E8F0),
          width: isSelected ? 1.8 : 1,
        ),
      ),
      child: ListTile(
        onTap: () => setState(() => _selectedMethod = id),
        leading:
            customLeading ??
            (bankBadge != null
                ? Container(
                    width: 36,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      bankBadge,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  )
                : Icon(
                    icon ?? Icons.credit_card_rounded,
                    color: const Color(0xFF0256B8),
                    size: 22,
                  )),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
              )
            : null,
        trailing: isSelected
            ? const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF0256B8),
                size: 20,
              )
            : const Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey,
                size: 20,
              ),
      ),
    );
  }

  Widget _buildStickyBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Text(
                      'Total Price',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 14,
                      color: Colors.grey,
                    ),
                  ],
                ),
                Text(
                  _formatCurrency(widget.totalAmount),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0256B8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onPressed: _isProcessing ? null : _processPayment,
              child: _isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _selectedMethod == 'QRIS'
                          ? 'Bayar QRIS'
                          : 'Bayar Sekarang',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
