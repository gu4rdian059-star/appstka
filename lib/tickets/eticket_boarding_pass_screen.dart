import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/user_db_service.dart';
import '../services/supabase_storage_service.dart';
import '../orders/refund_screen.dart';
import '../tracking/live_tracking_screen.dart';

class ETicketBoardingPassScreen extends StatefulWidget {
  final BookingModel booking;
  final String? passengerName;
  final String? passengerNik;
  final String? seatNumber;
  final List<Map<String, String>>? passengers;

  const ETicketBoardingPassScreen({
    super.key,
    required this.booking,
    this.passengerName,
    this.passengerNik,
    this.seatNumber,
    this.passengers,
  });

  @override
  State<ETicketBoardingPassScreen> createState() =>
      _ETicketBoardingPassScreenState();
}

class _ETicketBoardingPassScreenState extends State<ETicketBoardingPassScreen> {
  int _qrRefreshSeconds = 48;
  Timer? _qrTimer;
  bool _isHighBrightness = false;
  bool _isDownloadingPdf = false;
  int _activePassengerIdx = 0;

  @override
  void initState() {
    super.initState();
    _startQrTimer();
    SupabaseStorageService.ensureTicketQrUploaded(
      bookingId: widget.booking.bookingId,
      pnr: widget.booking.bookingId,
      trainName: widget.booking.trainName,
      seatNumber: widget.booking.seatNumber,
    );
  }

  void _startQrTimer() {
    _qrTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_qrRefreshSeconds > 1) {
        setState(() => _qrRefreshSeconds--);
      } else {
        setState(() => _qrRefreshSeconds = 50);
      }
    });
  }

  @override
  void dispose() {
    _qrTimer?.cancel();
    super.dispose();
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Kode PNR $text berhasil disalin!'),
        backgroundColor: const Color(0xFF0256B8),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  void _toggleBrightness() {
    setState(() => _isHighBrightness = !_isHighBrightness);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isHighBrightness
              ? 'Kecerahan layar ditingkatkan untuk pemindaian gate.'
              : 'Kecerahan layar normal.',
        ),
        backgroundColor: const Color(0xFF062056),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  void _showEnlargedQr() {
    final qrUrl = widget.booking.qrCodeUrl ??
        SupabaseStorageService.getTicketQrUrl(widget.booking.bookingId);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Scan Barcode di Boarding Gate',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF062056),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  qrUrl,
                  width: 220,
                  height: 220,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => CustomPaint(
                    size: const Size(220, 220),
                    painter: _RealisticQrCodePainter(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Kode Booking: ${widget.booking.bookingId}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'QR Dinamis berganti dalam $_qrRefreshSeconds detik',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFEA580C),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF062056),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Tutup',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _downloadPdf() async {
    setState(() => _isDownloadingPdf = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _isDownloadingPdf = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'E-Ticket PDF (${widget.booking.bookingId}.pdf) berhasil disimpan ke folder Download.',
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareTicket() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'E-Ticket ${widget.booking.bookingId} siap dibagikan via WhatsApp, Email atau Pesan.',
        ),
        backgroundColor: const Color(0xFF062056),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    String name = widget.passengerName ?? b.passengerName;
    String nik = widget.passengerNik ?? b.passengerNik;
    String seat = widget.seatNumber ?? b.seatNumber;

    if (widget.passengers != null && widget.passengers!.isNotEmpty) {
      final safeIdx = _activePassengerIdx.clamp(
        0,
        widget.passengers!.length - 1,
      );
      final pData = widget.passengers![safeIdx];
      name = pData['name'] ?? name;
      nik = pData['id'] ?? nik;
      seat = pData['seat'] ?? seat;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF062056)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TRANSIT PASS',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFFEA580C),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'ETicket & Boarding Pass',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF062056),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.share_outlined,
              color: Color(0xFF062056),
              size: 20,
            ),
            onPressed: _shareTicket,
          ),
          IconButton(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Color(0xFF062056),
              size: 20,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(
          children: [
            // 0. Tabs Pemilih Tiket Penumpang (jika > 1 penumpang)
            _buildMultiPassengerTicketTabs(),

            // 1. Banner STATUS PERJALANAN (Hitam/Navy Gelap Persis Gambar 5)
            _buildTopStatusBanner(),

            const SizedBox(height: 12),

            // 2. Card KODE BOOKING (PNR)
            _buildPnrCodeCard(b.bookingId),

            const SizedBox(height: 12),

            // 3. Card Utama Tiket Kereta (Header Biru Tua + Rute + Penumpang)
            _buildMainTicketCard(b, name, nik, seat),

            const SizedBox(height: 12),

            // 4. Card TKA Face Recognition Gate AKTIF
            _buildFaceRecognitionCard(),

            const SizedBox(height: 12),

            // 5. Card QR Code Dinamis Boarding
            _buildQrCodeCard(),

            const SizedBox(height: 14),

            // 6. Section Panduan Stasiun Real-Time (Live Gate)
            _buildStationGuideCard(b),

            const SizedBox(height: 14),

            // 7. Section Layanan & Fasilitas Termasuk
            _buildIncludedServicesCard(),

            const SizedBox(height: 20),

            // 8. Tombol Download PDF & Bagikan
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF26716),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isDownloadingPdf ? null : _downloadPdf,
                      icon: _isDownloadingPdf
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.download_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                      label: Text(
                        _isDownloadingPdf
                            ? 'Mengunduh...'
                            : 'Download PDF Tiket',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF062056),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _shareTicket,
                      icon: const Icon(
                        Icons.share_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      label: const Text(
                        'Bagikan',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Tombol Ubah Jadwal & Batalkan & Refund
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: Colors.white,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Layanan ubah jadwal tersedia di loket stasiun atau menu tiket.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.history_rounded,
                      size: 16,
                      color: Color(0xFF0F172A),
                    ),
                    label: const Text(
                      'Ubah Jadwal',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFFECDD3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RefundScreen(
                            bookingCode: b.bookingId,
                            trainName: b.trainName,
                            originalPrice: b.totalAmount,
                            passengerName: name,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.cancel_outlined,
                      size: 16,
                      color: Color(0xFFDC2626),
                    ),
                    label: const Text(
                      'Batalkan & Refund',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Tombol Lacak Posisi Kereta Live
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0256B8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LiveTrackingScreen(booking: b),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.my_location_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text(
                  'Lacak Posisi Kereta Secara Live',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Card Bantuan Kondektur
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.support_agent_rounded,
                    size: 18,
                    color: Color(0xFF0256B8),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Butuh bantuan di perjalanan?',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                  Spacer(),
                  Text(
                    'Hubungi Kondektur ➔',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEA580C),
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

  // ===========================================================================
  // SUB WIDGETS
  // ===========================================================================

  Widget _buildMultiPassengerTicketTabs() {
    if (widget.passengers == null || widget.passengers!.length <= 1) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TIKET PENUMPANG (${_activePassengerIdx + 1}/${widget.passengers!.length})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.3,
                ),
              ),
              const Text(
                'Ketuk untuk ganti tiket',
                style: TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF0256B8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(widget.passengers!.length, (idx) {
                final isActive = _activePassengerIdx == idx;
                final pData = widget.passengers![idx];
                final pName = pData['name'] ?? 'Penumpang ${idx + 1}';
                final pSeat = pData['seat'] ?? '';

                return GestureDetector(
                  onTap: () => setState(() => _activePassengerIdx = idx),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF062056)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFF062056)
                            : const Color(0xFFCBD5E1),
                        width: isActive ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFFF26716)
                                : const Color(0xFF94A3B8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'P${idx + 1}',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          pName.length > 12
                              ? '${pName.substring(0, 11)}...'
                              : pName,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                        ),
                        if (pSeat.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              pSeat,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: isActive
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopStatusBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF041738),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF041738).withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'Plus Jakarta Sans',
                      ),
                      children: [
                        TextSpan(
                          text: 'STATUS: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                        TextSpan(
                          text: 'SIAP BOARDING',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF4ADE80),
                          ),
                        ),
                        TextSpan(
                          text: ' • Pintu 07:45',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 11,
                  color: Color(0xFFF97316),
                ),
                SizedBox(width: 4),
                Text(
                  '2j 45m lagi',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFF97316),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPnrCodeCard(String pnr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.confirmation_number_outlined,
              size: 18,
              color: Color(0xFF0256B8),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'KODE BOOKING (PNR)',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      pnr,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _copyToClipboard(pnr),
                      child: const Icon(
                        Icons.copy_rounded,
                        size: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              children: [
                Icon(Icons.bolt_rounded, size: 13, color: Color(0xFFEA580C)),
                SizedBox(width: 2),
                Text(
                  'Instant Pay',
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
    );
  }

  Widget _buildMainTicketCard(
    BookingModel b,
    String name,
    String nik,
    String seat,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Header Biru Tua (TKA VELOCITY Argo Bromo Anggrek)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF062056),
              borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'TKA VELOCITY',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF062056),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0256B8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'KA 2',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              b.trainName.replaceAll('KA ', ''),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
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
                        color: const Color(0xFFEA580C),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Luxury Sleeper',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildPillTag('Bogie K9 Smooth Ride'),
                    _buildPillTag('Wi-Fi Ultra 5G'),
                    _buildPillTag('Recline 140°'),
                  ],
                ),
              ],
            ),
          ),

          // Rute Berangkat & Tiba
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BERANGKAT',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      b.departureTime,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '${b.originName} (${b.originCode})',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const Text(
                      'Jalur 03 • Peron Eksekutif',
                      style: TextStyle(fontSize: 9.5, color: Colors.grey),
                    ),
                    Text(
                      b.travelDate,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text(
                      '8j 05m',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEA580C),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 26,
                          height: 1,
                          color: Colors.grey.shade300,
                        ),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0256B8),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Langsung',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'TIBA',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      b.arrivalTime,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '${b.destName} (${b.destCode})',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const Text(
                      'Peron 1 Kedatangan',
                      style: TextStyle(fontSize: 9.5, color: Colors.grey),
                    ),
                    Text(
                      b.travelDate,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Detail Penumpang & Kursi
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NAMA PENUMPANG',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'NIK: $nik (Dewasa)',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: const [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.window_rounded,
                                size: 11,
                                color: Color(0xFF0256B8),
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Jendela (Window)',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.navigation_rounded,
                                size: 11,
                                color: Color(0xFF0256B8),
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Searah KA',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'GERBONG',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const Text(
                        'EKS-2',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF062056),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'KURSI',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        seat.contains('/') ? seat.split('/').last.trim() : seat,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
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

  Widget _buildPillTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 8.5, color: Colors.white),
      ),
    );
  }

  Widget _buildFaceRecognitionCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.face_retouching_natural_rounded,
            size: 20,
            color: Color(0xFF16A34A),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'TKA Face Recognition Gate',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF14532D),
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'AKTIF',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Langsung lewat gate tanpa scan ponsel cukup hadapkan wajah.',
                  style: TextStyle(fontSize: 10, color: Color(0xFF15803D)),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
        ],
      ),
    );
  }

  Widget _buildQrCodeCard() {
    final qrUrl = widget.booking.qrCodeUrl ??
        SupabaseStorageService.getTicketQrUrl(widget.booking.bookingId);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // QR Barcode Realistis dari Supabase Storage (tickets-qr)
          Center(
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  qrUrl,
                  width: 180,
                  height: 180,
                  fit: BoxFit.contain,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF062056),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, _, _) => CustomPaint(
                    size: const Size(180, 180),
                    painter: _RealisticQrCodePainter(),
                  ),
                ),
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
                  color: Color(0xFFEA580C),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'QR Dinamis berganti dalam ${_qrRefreshSeconds}s',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFEA580C),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.refresh_rounded,
                size: 13,
                color: Color(0xFFEA580C),
              ),
            ],
          ),

          const SizedBox(height: 4),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.cloud_done_rounded,
                      size: 11,
                      color: Color(0xFF1D4ED8),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Supabase Storage (tickets-qr)',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: Color(0xFF1D4ED8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '• Enkripsi Level 3',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _toggleBrightness,
                  icon: const Icon(
                    Icons.brightness_medium_rounded,
                    size: 14,
                    color: Color(0xFF0F172A),
                  ),
                  label: const Text(
                    'Kecerahan Maksimal',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF062056),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _showEnlargedQr,
                  icon: const Icon(
                    Icons.fullscreen_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Perbesar QR',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStationGuideCard(BookingModel b) {
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
              const Row(
                children: [
                  Icon(
                    Icons.directions_subway_rounded,
                    size: 16,
                    color: Color(0xFFEA580C),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Panduan Stasiun Real-Time',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Live Gate',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.train_outlined,
                    color: Color(0xFFEA580C),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Stasiun ${b.originName} (${b.originCode})',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF062056),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'Jalur 3',
                              style: TextStyle(
                                fontSize: 8.5,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Rangkaian KA telah bersandar di Jalur 3. Boarding gate siap dibuka pukul 07:45 WIB melalui Lantai 2 Hall Eksekutif.',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 13,
                        color: Color(0xFF062056),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Peta Akses Peron',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF062056),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.coffee_rounded,
                        size: 13,
                        color: Color(0xFF062056),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Lounge Eksekutif',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF062056),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncludedServicesCard() {
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
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.card_giftcard_rounded,
                    size: 16,
                    color: Color(0xFFEA580C),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Layanan & Fasilitas Termasuk',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Text(
                '4 Layanan Aktif',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildServiceItem(
            icon: Icons.restaurant_rounded,
            title: 'Nasi Rames Nusantara TKA',
            badge: 'Pre-order',
            subtitle: 'Diantar ke Kursi 5C pukul 12:00 WIB',
            isChecked: true,
          ),
          const SizedBox(height: 8),
          _buildServiceItem(
            icon: Icons.luggage_rounded,
            title: 'Free TKA Porter Service',
            badge: 'Gratis',
            subtitle: 'Tunjukkan e-ticket ini ke petugas berseragam TKA',
            isChecked: true,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.work_outline_rounded,
                        size: 14,
                        color: Color(0xFF0256B8),
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bagasi 20 Kg',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Otomatis Terdaftar',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 8.5,
                                color: Color(0xFF16A34A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.power_rounded,
                        size: 14,
                        color: Color(0xFF0256B8),
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Colokan 220V + USB',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Di Sandaran Kursi',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 8.5,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceItem({
    required IconData icon,
    required String title,
    required String badge,
    required String subtitle,
    required bool isChecked,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: const Color(0xFFEA580C), size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0256B8),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          if (isChecked)
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF16A34A),
              size: 18,
            ),
        ],
      ),
    );
  }
}

/// Custom Painter untuk QR Code Realistis dengan Logo TKA di Tengah
class _RealisticQrCodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF062056)
      ..style = PaintingStyle.fill;

    const int matrix = 25;
    final blockSize = size.width / matrix;

    // Gambar pola QR Matrix
    for (int r = 0; r < matrix; r++) {
      for (int c = 0; c < matrix; c++) {
        // Tiga kotak finder pattern di pojok
        final isTopLeftFinder = r < 7 && c < 7;
        final isTopRightFinder = r < 7 && c >= matrix - 7;
        final isBottomLeftFinder = r >= matrix - 7 && c < 7;
        final isCenterLogo = r >= 10 && r <= 14 && c >= 10 && c <= 14;

        if (isTopLeftFinder || isTopRightFinder || isBottomLeftFinder) {
          final isBorder =
              r == 0 ||
              r == 6 ||
              c == 0 ||
              c == 6 ||
              r == 0 ||
              r == 6 ||
              c == matrix - 1 ||
              c == matrix - 7 ||
              r == matrix - 1 ||
              r == matrix - 7 ||
              c == 0 ||
              c == 6;
          final isCenter =
              (r >= 2 && r <= 4 && c >= 2 && c <= 4) ||
              (r >= 2 && r <= 4 && c >= matrix - 5 && c <= matrix - 3) ||
              (r >= matrix - 5 && r <= matrix - 3 && c >= 2 && c <= 4);

          if (isBorder || isCenter) {
            canvas.drawRect(
              Rect.fromLTWH(c * blockSize, r * blockSize, blockSize, blockSize),
              paint,
            );
          }
        } else if (isCenterLogo) {
          // Biarkan kosong untuk logo tengah
        } else {
          // Data bits pseudo-acak deterministik
          final val = (r * 7 + c * 13 + (r % 3) * (c % 5)) % 5;
          if (val == 0 || val == 2) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(
                  c * blockSize + 0.5,
                  r * blockSize + 0.5,
                  blockSize - 1,
                  blockSize - 1,
                ),
                const Radius.circular(1.5),
              ),
              paint,
            );
          }
        }
      }
    }

    // Logo TKA Oranye di Tengah
    final center = Offset(size.width / 2, size.height / 2);
    final logoBgPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, 18, logoBgPaint);

    final logoCirclePaint = Paint()..color = const Color(0xFFF26716);
    canvas.drawCircle(center, 15, logoCirclePaint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Z',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
