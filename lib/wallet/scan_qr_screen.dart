import 'package:flutter/material.dart';

import '../services/session_service.dart';
import '../services/user_db_service.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  bool _isTorchOn = false;
  int _activeScanMode = 0; // 0: Boarding Pass, 1: QRIS Merchant
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _laserController.dispose();
    super.dispose();
  }

  void _onScanSuccess(String code, {bool isMerchant = false}) {
    if (!_isScanning) return;
    setState(() => _isScanning = false);

    if (isMerchant) {
      _showMerchantPaymentDialog(code);
    } else {
      _showBoardingPassValidDialog(code);
    }
  }

  void _showBoardingPassValidDialog(String code) async {
    // Cari data tiket nyata jika ada di UserDatabaseService
    final bookings = await UserDatabaseService.getBookings();
    BookingModel? matched;
    for (final b in bookings) {
      if (b.bookingId.toUpperCase() == code.toUpperCase()) {
        matched = b;
        break;
      }
    }

    final bookingCode = matched?.bookingId ?? code;
    final trainName = matched?.trainName ?? 'KA Argo Bromo Anggrek';
    final passengerName = matched?.passengerName ?? 'M. SAFID MAULANA';
    final seat = matched?.seatNumber ?? 'EKS-2 / 12A';
    final route = matched != null
        ? '${matched.originName} → ${matched.destName}'
        : 'Gambir (GMR) → Surabaya Pasarturi (SBI)';

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF10B981),
                size: 38,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'BOARDING PASS TERVERIFIKASI',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pintu Masuk Peron Terbuka • Gate 03 Stasiun',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Kode Booking',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      Text(
                        bookingCode,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF062056),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Nama Penumpang',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      Text(
                        passengerName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF062056),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Kereta Api',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      Text(
                        trainName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0256B8),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Rute & Kursi',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      Text(
                        '$route • $seat',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF062056),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0256B8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _isScanning = true);
                },
                child: const Text(
                  'Scan Tiket Lain',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showMerchantPaymentDialog(String merchantName) async {
    final balance = await SessionService.getUserBalance();
    const amount = 28000;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.store_rounded,
                    color: Color(0xFFF26716),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pembayaran QRIS Merchant',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      Text(
                        merchantName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF062056),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Total Tagihan',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        'Rp28.000',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF062056),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sumber Dana',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        'TKAPay (Saldo: Rp${balance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')})',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0256B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0256B8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  final sm = ScaffoldMessenger.of(context);
                  if (balance >= amount) {
                    await SessionService.setUserBalance(balance - amount);
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    sm.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Pembayaran Rp28.000 ke $merchantName BERHASIL!',
                        ),
                        backgroundColor: const Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    setState(() => _isScanning = true);
                  } else {
                    Navigator.pop(ctx);
                    sm.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Saldo TKAPay tidak mencukupi untuk pembayaran ini.',
                        ),
                        backgroundColor: Color(0xFFDC2626),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    setState(() => _isScanning = true);
                  }
                },
                child: const Text(
                  'Konfirmasi & Bayar Sekarang',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showManualInputDialog() {
    final controller = TextEditingController(text: 'TKA-B947XQ');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Input Kode Tiket Manual',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF062056),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan 8 karakter kode booking tiket kereta Anda:',
              style: TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Contoh: TKA-B947XQ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0256B8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _onScanSuccess(controller.text.trim());
            },
            child: const Text(
              'Verifikasi',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _pickFromGallery() {
    // Simulasi memilih QR dari Galeri foto
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih File Gambar / E-Tiket dari Galeri',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF062056),
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(
                Icons.confirmation_number_rounded,
                color: Color(0xFF0256B8),
              ),
              title: const Text(
                'Screenshot Boarding Pass TKA-B947XQ',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Argo Bromo Anggrek • Hari Ini',
                style: TextStyle(fontSize: 11),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _onScanSuccess('TKA-B947XQ');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.store_rounded,
                color: Color(0xFFF26716),
              ),
              title: const Text(
                'QRIS Resto Kereta Api Stasiun',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'PT Reska Multi Usaha',
                style: TextStyle(fontSize: 11),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _onScanSuccess('KAI Resto Stasiun Gambir', isMerchant: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Kamera Simulasi (Grid Gelap Bersih)
          Container(
            color: _isTorchOn ? const Color(0xFF1E293B) : Colors.black,
            child: Center(
              child: Opacity(
                opacity: _isTorchOn ? 0.35 : 0.15,
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 260,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Viewfinder Cutout
          SafeArea(
            child: Column(
              children: [
                // Top App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          _activeScanMode == 0
                              ? 'Scan Boarding Pass'
                              : 'Scan Merchant QRIS',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _isTorchOn
                                  ? Icons.flash_on_rounded
                                  : Icons.flash_off_rounded,
                              color: _isTorchOn
                                  ? const Color(0xFFFFD166)
                                  : Colors.white,
                            ),
                            onPressed: () =>
                                setState(() => _isTorchOn = !_isTorchOn),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.image_outlined,
                              color: Colors.white,
                            ),
                            onPressed: _pickFromGallery,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Kotak Pemindai dengan Laser
                Center(
                  child: SizedBox(
                    width: 260,
                    height: 260,
                    child: Stack(
                      children: [
                        // Border Sudut Target
                        _buildScannerCorner(
                          top: 0,
                          left: 0,
                          isTop: true,
                          isLeft: true,
                        ),
                        _buildScannerCorner(
                          top: 0,
                          right: 0,
                          isTop: true,
                          isLeft: false,
                        ),
                        _buildScannerCorner(
                          bottom: 0,
                          left: 0,
                          isTop: false,
                          isLeft: true,
                        ),
                        _buildScannerCorner(
                          bottom: 0,
                          right: 0,
                          isTop: false,
                          isLeft: false,
                        ),

                        // Laser Scanning Line Animasi
                        if (_isScanning)
                          AnimatedBuilder(
                            animation: _laserAnimation,
                            builder: (ctx, child) {
                              return Positioned(
                                top: _laserAnimation.value * 240,
                                left: 10,
                                right: 10,
                                child: Container(
                                  height: 2.5,
                                  decoration: BoxDecoration(
                                    color: _activeScanMode == 0
                                        ? const Color(0xFF00E5FF)
                                        : const Color(0xFFF26716),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _activeScanMode == 0
                                            ? const Color(0xFF00E5FF)
                                            : const Color(0xFFF26716),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                        // Center Target Hint
                        Center(
                          child: Icon(
                            _activeScanMode == 0
                                ? Icons.qr_code_2_rounded
                                : Icons.qr_code_scanner_rounded,
                            size: 48,
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),
                Text(
                  _activeScanMode == 0
                      ? 'Arahkan kamera ke QR code tiket kereta Anda'
                      : 'Arahkan kamera ke QRIS pembayaran merchant',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const Spacer(),

                // Tombol Simulasi Scan Langsung (Cepat untuk pengujian)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                          onPressed: _showManualInputDialog,
                          icon: const Icon(Icons.keyboard_rounded, size: 16),
                          label: const Text(
                            'Kode Manual',
                            style: TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0256B8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                          onPressed: () {
                            if (_activeScanMode == 0) {
                              _onScanSuccess('TKA-B947XQ');
                            } else {
                              _onScanSuccess(
                                'KAI Resto Stasiun Gambir',
                                isMerchant: true,
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.camera_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Tes Scan',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Selector Mode (Boarding Pass vs QRIS Merchant)
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeScanMode = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _activeScanMode == 0
                                  ? const Color(0xFF0256B8)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: const Center(
                              child: Text(
                                'Tiket Boarding',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeScanMode = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _activeScanMode == 1
                                  ? const Color(0xFFF26716)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: const Center(
                              child: Text(
                                'QRIS Bayar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerCorner({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required bool isTop,
    required bool isLeft,
  }) {
    final borderColor = _activeScanMode == 0
        ? const Color(0xFF00E5FF)
        : const Color(0xFFF26716);

    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          border: Border(
            top: isTop
                ? BorderSide(color: borderColor, width: 3.5)
                : BorderSide.none,
            bottom: !isTop
                ? BorderSide(color: borderColor, width: 3.5)
                : BorderSide.none,
            left: isLeft
                ? BorderSide(color: borderColor, width: 3.5)
                : BorderSide.none,
            right: !isLeft
                ? BorderSide(color: borderColor, width: 3.5)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
