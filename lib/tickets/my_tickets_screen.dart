import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../orders/refund_screen.dart';
import '../orders/order_detail_screen.dart';
import '../intercity/antar_kota_screen.dart';
import '../services/user_db_service.dart';
import '../services/supabase_storage_service.dart';

class MyTicketsScreen extends StatefulWidget {
  final bool embedded;
  final String? initialBookingId;

  const MyTicketsScreen({
    super.key,
    this.embedded = false,
    this.initialBookingId,
  });

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  int _activeTab = 0; // 0: Tiket Aktif, 1: Riwayat Tiket
  List<BookingModel> _allBookings = [];
  bool _isLoading = true;
  int _selectedTicketIndex = 0;
  int _selectedPassengerIndex = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    final list = await UserDatabaseService.getBookings();
    if (mounted) {
      setState(() {
        _allBookings = List.from(list);
        _isLoading = false;
        if (widget.initialBookingId != null) {
          final idx = _activeTickets.indexWhere(
            (b) => b.bookingId == widget.initialBookingId,
          );
          if (idx != -1) {
            _selectedTicketIndex = idx;
          }
        }
        if (_selectedTicketIndex >= _activeTickets.length) {
          _selectedTicketIndex = 0;
        }
      });
    }
  }

  List<BookingModel> get _activeTickets {
    return _allBookings.where((b) => b.status == 'Sudah Dibayar').toList();
  }

  List<BookingModel> get _historyTickets {
    return _allBookings.where((b) => b.status != 'Sudah Dibayar').toList();
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Kode booking $code berhasil disalin!'),
        backgroundColor: const Color(0xFF062056),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showCompleteTicketDialog(BookingModel ticket) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.task_alt_rounded,
                color: Color(0xFF10B981),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Selesaikan Perjalanan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF062056),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Simulasi verifikasi gate keluar stasiun untuk kereta ${ticket.trainName} (${ticket.originCode} ➔ ${ticket.destCode}).',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Color(0xFF0256B8),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Status tiket akan berubah menjadi "Perjalanan Selesai" dan otomatis dipindahkan ke tab Riwayat Tiket.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
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
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await UserDatabaseService.completeBooking(
                bookingCode: ticket.bookingId,
              );
              if (success && mounted) {
                await _loadTickets();
                setState(() => _activeTab = 1); // Beralih ke tab Riwayat Tiket
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '✅ Tiket ${ticket.bookingId} selesai! Sekarang berada di tab Riwayat Tiket.',
                    ),
                    backgroundColor: const Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text(
              'Tandai Selesai',
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

  void _showManualPnrDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Tambahkan Tiket Manual',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF062056),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan Kode Booking (PNR) 8 karakter untuk menyinkronkan e-ticket:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Contoh: TKA-9921XB',
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
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF062056),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tiket berhasil disinkronkan ke akun Anda!'),
                  backgroundColor: Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              _loadTickets();
            },
            child: const Text(
              'Sinkronkan',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _activeTickets.length;
    final historyCount = _historyTickets.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: widget.embedded
            ? null
            : IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Color(0xFF062056),
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo_tka_full.png',
              height: 24,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Text(
                'TKA',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF062056),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Tiket Saya',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF062056),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF062056), width: 1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _showManualPnrDialog,
              child: const Text(
                'Cek Kode Booking',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF062056),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Segmented Tabs: Tiket Aktif & Riwayat Tiket
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Container(
              height: 42,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F4F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTab = 0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _activeTab == 0
                              ? const Color(0xFF062056)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Tiket Aktif ($activeCount)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: _activeTab == 0
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTab = 1),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _activeTab == 1
                              ? const Color(0xFF062056)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Riwayat Tiket ($historyCount)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: _activeTab == 1
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // Konten Tab
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _activeTab == 0
                ? _buildActiveTicketView()
                : _buildHistoryTicketView(),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTicketView() {
    final activeList = _activeTickets;

    if (activeList.isEmpty) {
      return _buildEmptyActiveTicketsView();
    }

    if (_selectedTicketIndex >= activeList.length) {
      _selectedTicketIndex = 0;
    }

    final ticket = activeList[_selectedTicketIndex];
    final manifest = ticket.passengerList;
    if (_selectedPassengerIndex >= manifest.length) {
      _selectedPassengerIndex = 0;
    }
    final activePassenger = manifest[_selectedPassengerIndex];
    final displaySeat = activePassenger['seat'] ?? ticket.seatNumber;
    final displayPassengerName =
        activePassenger['name'] ?? ticket.passengerName;

    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selector jika ada lebih dari 1 tiket aktif
          if (activeList.length > 1) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.confirmation_number_rounded,
                      size: 16,
                      color: Color(0xFF062056),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Pilih Tiket Aktif (${activeList.length})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF062056),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F1FC),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Tiket ${_selectedTicketIndex + 1} dari ${activeList.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0256B8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: activeList.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final t = activeList[i];
                  final isSelected = _selectedTicketIndex == i;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedTicketIndex = i;
                        _selectedPassengerIndex = 0;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF062056)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF062056)
                              : Colors.grey.shade300,
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF062056)
                                      .withValues(alpha: 0.18),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.train_rounded,
                            size: 15,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF062056),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${t.originCode} ➔ ${t.destCode}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF062056),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.22)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              t.bookingId,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Selector Penumpang jika dalam 1 tiket ada beberapa orang
          if (manifest.length > 1) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pilih Penumpang untuk Boarding:',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF062056),
                  ),
                ),
                Text(
                  '${manifest.length} Penumpang',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: manifest.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, pIdx) {
                  final p = manifest[pIdx];
                  final isPSelected = _selectedPassengerIndex == pIdx;
                  return InkWell(
                    onTap: () => setState(() => _selectedPassengerIndex = pIdx),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isPSelected
                            ? const Color(0xFF0256B8)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isPSelected
                              ? const Color(0xFF0256B8)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_rounded,
                            size: 14,
                            color: isPSelected
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'P${pIdx + 1}: ${p['name'] ?? 'Penumpang'} (${p['seat'] ?? '-'})',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isPSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isPSelected
                                  ? Colors.white
                                  : const Color(0xFF062056),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
          ],

          // ================= KARTU BOARDING PASS UTAMA =================
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF062056).withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner Status Boarding (Dark Navy)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF062056),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.directions_train_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'STATUS BOARDING: Gate Dibuka 07:45 WIB',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
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
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF26716).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '-45 Mnt',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF26716),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sub Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TKA EXPRESS BOARDING',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 6,
                                  color: Color(0xFF2E7D32),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Siap Boarding',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Nama Kereta
                      Text(
                        ticket.trainName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF062056),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${ticket.trainClass} (Tepat Waktu)',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Rute & Jam
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ticket.departureTime,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF062056),
                                ),
                              ),
                              Text(
                                '${ticket.originName} (${ticket.originCode})',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                ticket.travelDate,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Text(
                                'Langsung',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 14,
                                    height: 1.5,
                                    color: Colors.grey.shade300,
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 14,
                                    color: Color(0xFF062056),
                                  ),
                                  Container(
                                    width: 14,
                                    height: 1.5,
                                    color: Colors.grey.shade300,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                ticket.arrivalTime,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF062056),
                                ),
                              ),
                              Text(
                                '${ticket.destName} (${ticket.destCode})',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                ticket.travelDate,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const Divider(height: 24),

                      // Kode Booking & Tempat Duduk
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'KODE BOOKING (PNR)',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    ticket.bookingId,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF062056),
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
                                    onPressed: () =>
                                        _copyCode(ticket.bookingId),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'TEMPAT DUDUK',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                displaySeat,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFF26716),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      Text(
                        'PENUMPANG: $displayPassengerName (Dewasa • NIK terverifikasi)',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ================= TAMPILAN QR CODE =================
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFD),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(
                                    ticket.qrCodeUrl ??
                                        SupabaseStorageService.getTicketQrUrl(
                                          ticket.bookingId,
                                        ),
                                    width: 150,
                                    height: 150,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (ctx, child, progress) {
                                      if (progress == null) return child;
                                      return const Center(
                                        child: SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Color(0xFF062056),
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, _, _) => Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        const Icon(
                                          Icons.qr_code_2_rounded,
                                          size: 132,
                                          color: Color(0xFF062056),
                                        ),
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.train_rounded,
                                            size: 15,
                                            color: Color(0xFFF26716),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Tunjukkan QR Code ini di boarding gate stasiun',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF062056),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFBFDBFE),
                                      ),
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
                                          'Supabase tickets-qr',
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
                                    '• Offline Ready',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Stasiun Keberangkatan Notice
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F1FC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 18,
                              color: Color(0xFF062056),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Stasiun Keberangkatan: ${ticket.originName}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF062056),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Pintu masuk Boarding Gate Jalur 3, Hall Eksekutif Lantai 2. Layanan cetak struk boarding pass mandiri tersedia di Kiosk B-12.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF334155),
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Tombol Unduh Tiket
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Tiket PDF berhasil diunduh ke perangkat Anda.',
                                ),
                                backgroundColor: Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.download_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Download Tiket (PDF)',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF062056)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'E-ticket telah dikirim ke ${ticket.passengerEmail}',
                                ),
                                backgroundColor: const Color(0xFF062056),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.share_rounded,
                            size: 16,
                            color: Color(0xFF062056),
                          ),
                          label: const Text(
                            'Kirim ke Email / Bagikan',
                            style: TextStyle(
                              color: Color(0xFF062056),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF0256B8)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    OrderDetailScreen.fromBooking(ticket),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.receipt_long_rounded,
                            size: 16,
                            color: Color(0xFF0256B8),
                          ),
                          label: const Text(
                            'Lihat Detail Pesanan & Penumpang',
                            style: TextStyle(
                              color: Color(0xFF0256B8),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      Center(
                        child: TextButton(
                          onPressed: () async {
                            final changed = await Navigator.of(context)
                                .push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => RefundScreen(
                                      bookingCode: ticket.bookingId,
                                      trainName: ticket.trainName,
                                      originalPrice: ticket.totalAmount,
                                    ),
                                  ),
                                );
                            if (changed == true) {
                              _loadTickets();
                            }
                          },
                          child: const Text(
                            'Ajukan Pembatalan / Ubah Jadwal',
                            style: TextStyle(
                              color: Color(0xFFF26716),
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 4),

                      Center(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF10B981)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                          icon: const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 16,
                            color: Color(0xFF10B981),
                          ),
                          label: const Text(
                            'Simulasi Selesai Perjalanan (Gate Keluar)',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () => _showCompleteTicketDialog(ticket),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ================= DAFTAR SEMUA TIKET AKTIF =================
          if (activeList.length > 1) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.airplane_ticket_rounded,
                      size: 18,
                      color: Color(0xFF062056),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Semua Tiket Aktif (${activeList.length})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF062056),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Ketuk untuk lihat QR',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeList.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final item = activeList[idx];
                final isCurrent = idx == _selectedTicketIndex;
                return _buildOtherActiveTicketCard(item, idx, isCurrent);
              },
            ),
            const SizedBox(height: 20),
          ],

          // ================= KETENTUAN KEBERANGKATAN =================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: Color(0xFF062056),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Ketentuan & Panduan Keberangkatan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF062056),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                _GuideItem(
                  title: 'Wajib Membawa Identitas Asli',
                  desc: 'Siapkan e-KTP fisik, Paspor, atau SIM yang masih berlaku sesuai nama pemegang tiket saat verifikasi gate.',
                ),
                SizedBox(height: 10),
                _GuideItem(
                  title: 'Batas Waktu Kedatangan',
                  desc: 'Tiba di stasiun selambat-lambatnya 30 menit sebelum jadwal keberangkatan KA.',
                ),
                SizedBox(height: 10),
                _GuideItem(
                  title: 'Ketentuan Bagasi Cuma-cuma',
                  desc: 'Maksimal 20 kg per penumpang dengan volume maksimal 100 dm3 (dimensi maksimal 70x48x30 cm).',
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildOtherActiveTicketCard(
    BookingModel item,
    int idx,
    bool isCurrent,
  ) {
    final manifest = item.passengerList;
    final pCount = manifest.isNotEmpty ? manifest.length : 1;
    final primaryName = manifest.isNotEmpty
        ? (manifest.first['name'] ?? item.passengerName)
        : item.passengerName;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedTicketIndex = idx;
          _selectedPassengerIndex = 0;
        });
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isCurrent ? const Color(0xFFF0F6FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrent ? const Color(0xFF0256B8) : Colors.grey.shade200,
            width: isCurrent ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? const Color(0xFF0256B8)
                            : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Tiket ${idx + 1}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isCurrent
                              ? Colors.white
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.bookingId,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF062056),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isCurrent
                            ? Icons.check_circle_rounded
                            : Icons.arrow_upward_rounded,
                        size: 12,
                        color: isCurrent
                            ? const Color(0xFF2E7D32)
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isCurrent ? 'Sedang Tampil' : 'Ketuk Tampilkan',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isCurrent
                              ? const Color(0xFF2E7D32)
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.trainName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF062056),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.originCode} (${item.originName}) ➔ ${item.destCode} (${item.destName})',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item.departureTime,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF062056),
                      ),
                    ),
                    Text(
                      item.travelDate,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      pCount > 1
                          ? '$primaryName (+$pCount Penumpang)'
                          : primaryName,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.seatNumber,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF26716),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => OrderDetailScreen.fromBooking(item),
                          ),
                        );
                      },
                      child: const Text(
                        'Rincian',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0256B8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (!isCurrent)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF062056),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedTicketIndex = idx;
                            _selectedPassengerIndex = 0;
                          });
                          _scrollController.animateTo(
                            0,
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                          );
                        },
                        child: const Row(
                          children: [
                            Icon(
                              Icons.qr_code_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Pilih QR',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyActiveTicketsView() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F1FC),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.confirmation_number_outlined,
              size: 48,
              color: Color(0xFF062056),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Belum Ada Tiket Aktif',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF062056),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Anda belum memiliki tiket kereta aktif untuk perjalanan saat ini atau mendatang. Pesan tiket sekarang untuk memulai petualangan Anda.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF062056),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AntarKotaScreen()),
              );
              _loadTickets();
            },
            child: const Text(
              'Cari & Pesan Tiket Kereta',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _showManualPnrDialog,
            child: const Text(
              'Tambahkan Tiket Manual (PNR)',
              style: TextStyle(
                color: Color(0xFF062056),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTicketView() {
    final history = _historyTickets;

    if (history.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada riwayat tiket perjalanan.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final item = history[i];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.bookingId,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF062056),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: item.status == 'Dibatalkan'
                          ? const Color(0xFFFEE2E2)
                          : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.status,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: item.status == 'Dibatalkan'
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              Text(
                item.trainName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B1E28),
                ),
              ),
              Text(
                '${item.trainClass} • Kursi ${item.seatNumber}',
                style: const TextStyle(fontSize: 11.5, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              Text(
                '${item.originName} (${item.originCode}) ➔ ${item.destName} (${item.destCode})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.travelDate,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  Text(
                    'Rp${item.totalAmount}',
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
        );
      },
    );
  }
}

class _GuideItem extends StatelessWidget {
  final String title;
  final String desc;

  const _GuideItem({required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle_outline_rounded,
          size: 16,
          color: Color(0xFF10B981),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B1E28),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
