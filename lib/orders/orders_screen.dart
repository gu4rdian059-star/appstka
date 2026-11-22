import 'package:flutter/material.dart';

import 'order_detail_screen.dart';
import '../intercity/antar_kota_screen.dart';
import '../payment/payment_screen.dart';
import '../services/user_db_service.dart';
import '../tickets/eticket_boarding_pass_screen.dart';

class OrdersScreen extends StatefulWidget {
  final bool embedded;
  final VoidCallback? onNavigateToTickets;

  const OrdersScreen({
    super.key,
    this.embedded = false,
    this.onNavigateToTickets,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  int _selectedFilterIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<BookingModel> _bookings = [];
  bool _isLoading = true;

  final List<String> _filters = [
    'Semua',
    'Menunggu Bayar',
    'Sudah Dibayar',
    'Dibatalkan',
    'Selesai',
  ];

  @override
  void initState() {
    super.initState();
    _loadBookings();
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      );
    });
  }

  Future<void> _loadBookings() async {
    final list = await UserDatabaseService.getBookings();
    if (mounted) {
      setState(() {
        _bookings = List.from(list);
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BookingModel> get _filteredOrders {
    final raw = _bookings.where((item) {
      if (_selectedFilterIndex == 1 && item.status != 'Menunggu Pembayaran') {
        return false;
      }
      if (_selectedFilterIndex == 2 && item.status != 'Sudah Dibayar') {
        return false;
      }
      if (_selectedFilterIndex == 3 &&
          item.status != 'Dibatalkan' &&
          item.status != 'Kedaluwarsa') {
        return false;
      }
      if (_selectedFilterIndex == 4 && item.status != 'Perjalanan Selesai') {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final id = item.bookingId.toLowerCase();
        final name = item.trainName.toLowerCase();
        final pName = item.passengerName.toLowerCase();
        if (!id.contains(_searchQuery) &&
            !name.contains(_searchQuery) &&
            !pName.contains(_searchQuery)) {
          return false;
        }
      }

      return true;
    }).toList();

    // Konsolidasi tiket rombongan / multi-penumpang hanya jika satu kode booking (misal TKA-12345 dan TKA-12345-2)
    final List<BookingModel> result = [];
    final Set<String> processed = {};

    for (final b in raw) {
      if (processed.contains(b.bookingId)) continue;

      // 1. Jika pesanan sudah memiliki manifes lengkap, langsung gunakan dan JANGAN digabung dengan pesanan lain!
      if (b.passengers != null && b.passengers!.isNotEmpty) {
        processed.add(b.bookingId);
        result.add(b);
        continue;
      }

      // 2. Hanya konsolidasi jika berbagi base ID booking yang SAMA PERSIS (misal TKA-12345 dan TKA-12345-2)
      final baseId = _getBaseBookingId(b.bookingId);
      final siblings = raw.where((other) {
        if (processed.contains(other.bookingId)) return false;
        final otherBase = _getBaseBookingId(other.bookingId);
        return otherBase == baseId && baseId.isNotEmpty && other.bookingId != b.bookingId;
      }).toList();

      if (siblings.isNotEmpty) {
        final allSiblings = [b, ...siblings];
        allSiblings.sort((x, y) => x.createdAt.compareTo(y.createdAt));
        for (final s in allSiblings) {
          processed.add(s.bookingId);
        }

        final manifest = allSiblings
            .map(
              (s) => {
                'name': s.passengerName,
                'id': s.passengerNik,
                'seat': s.seatNumber,
                'type': 'Dewasa (Adult)',
              },
            )
            .toList();

        final first = allSiblings.first;
        final totalAmount = allSiblings.fold<int>(
          0,
          (prev, elem) => prev + elem.totalAmount,
        );
        final allSeats = allSiblings.map((s) => s.seatNumber).join(', ');

        result.add(
          BookingModel(
            bookingId: first.bookingId,
            passengerName: allSiblings.map((s) => s.passengerName).join(', '),
            passengerEmail: first.passengerEmail,
            passengerPhone: first.passengerPhone,
            passengerNik: first.passengerNik,
            trainName: first.trainName,
            trainClass: first.trainClass,
            originCode: first.originCode,
            originName: first.originName,
            originCity: first.originCity,
            destCode: first.destCode,
            destName: first.destName,
            destCity: first.destCity,
            travelDate: first.travelDate,
            departureTime: first.departureTime,
            arrivalTime: first.arrivalTime,
            seatNumber: allSeats,
            totalAmount: totalAmount,
            status: first.status,
            paymentMethod: first.paymentMethod,
            vaNumber: first.vaNumber,
            createdAt: first.createdAt,
            cancelReason: first.cancelReason,
            refundAmount: first.refundAmount,
            passengers: manifest,
          ),
        );
      } else {
        processed.add(b.bookingId);
        result.add(b);
      }
    }

    return result;
  }

  static String _getBaseBookingId(String bookingId) {
    final match = RegExp(r'^(TKA-[A-Za-z0-9]+)-\d+$').firstMatch(bookingId);
    if (match != null) {
      return match.group(1)!;
    }
    return bookingId;
  }

  String _formatCurrency(int amount) {
    return 'Rp${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  void _openDetail(BookingModel item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(
          bookingCode: item.bookingId,
          trainName: item.trainName,
          trainClass: item.trainClass,
          status: item.status,
          totalAmount: item.totalAmount,
          origin: '${item.originName} (${item.originCode})',
          dest: '${item.destName} (${item.destCode})',
          departureTime: item.departureTime,
          arrivalTime: item.arrivalTime,
          passengerName: item.passengerName,
          passengerNik: item.passengerNik,
          paymentMethod: item.paymentMethod,
          vaNumber: item.vaNumber,
          travelDate: item.travelDate,
          seat: item.seatNumber,
          passengers: item.passengers,
          onViewTicket: () {
            Navigator.of(context).pop();
            widget.onNavigateToTickets?.call();
          },
          onPayNow: () async {
            Navigator.of(context).pop();
            _openPayment(item);
          },
        ),
      ),
    );
    _loadBookings();
  }

  void _openPayment(BookingModel item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PaymentScreen(existingBooking: item)),
    );
    _loadBookings();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Menunggu Pembayaran':
        return const Color(0xFFF26716);
      case 'Sudah Dibayar':
        return const Color(0xFF0284C7);
      case 'Perjalanan Selesai':
        return const Color(0xFF10B981);
      case 'Dibatalkan':
        return const Color(0xFFDC2626);
      default:
        return Colors.grey;
    }
  }

  void _showHelpBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
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
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.headset_mic_rounded,
                    color: Color(0xFF0256B8),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pusat Bantuan & Layanan Pelanggan',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF062056),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tim TKA Rail siap membantu kendala tiket Anda 24/7',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildHelpActionTile(
              icon: Icons.chat_bubble_rounded,
              iconColor: const Color(0xFF22C55E),
              bgColor: const Color(0xFFF0FDF4),
              title: 'Live Chat WhatsApp CS',
              subtitle: 'Respon cepat dalam < 2 menit oleh staf resmi',
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Menghubungkan ke WhatsApp CS TKA Rail...'),
                    backgroundColor: Color(0xFF16A34A),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _buildHelpActionTile(
              icon: Icons.phone_in_talk_rounded,
              iconColor: const Color(0xFF0256B8),
              bgColor: const Color(0xFFEFF6FF),
              title: 'Contact Center 121 (Bebas Pulsa)',
              subtitle: 'Layanan panggilan darurat 24 jam sehari',
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Memanggil Hotline Resmi 121...'),
                    backgroundColor: Color(0xFF062056),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _buildHelpActionTile(
              icon: Icons.help_outline_rounded,
              iconColor: const Color(0xFFF26716),
              bgColor: const Color(0xFFFFF7ED),
              title: 'Panduan Pembatalan & Ubah Jadwal',
              subtitle: 'Syarat & ketentuan refund dan reschedule tiket',
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Buka halaman panduan & ketentuan tiket.'),
                    backgroundColor: Color(0xFFF26716),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpActionTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF062056),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOrders;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: widget.embedded ? 0 : 52,
        leading: widget.embedded
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Center(
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Color(0xFF062056),
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),
              ),
        titleSpacing: widget.embedded ? 16 : 4,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF062056), Color(0xFF0256B8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0256B8).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.confirmation_number_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Daftar Pesanan',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF062056),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          '${_bookings.where((b) => b.status == 'Sudah Dibayar').length} Aktif',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0256B8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Pantau dan kelola tiket perjalanan kereta Anda',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: InkWell(
              onTap: () => _showHelpBottomSheet(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        const Icon(
                          Icons.headset_mic_rounded,
                          size: 15,
                          color: Color(0xFF15803D),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Color(0xFF22C55E),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Bantuan',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Card Pembungkus Pencarian & Filter Modern
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF062056).withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Column(
              children: [
                // Baris Pencarian & Refresh
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF0256B8),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF062056),
                                ),
                                decoration: const InputDecoration(
                                  hintText:
                                      'Cari kode booking (PNR) atau kereta...',
                                  hintStyle: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.normal,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              GestureDetector(
                                onTap: () => _searchController.clear(),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE2E8F0),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: _loadBookings,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Icon(
                          Icons.refresh_rounded,
                          color: Color(0xFF0256B8),
                          size: 21,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Chips Filter Interaktif Modern dengan Badge
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final isSelected = _selectedFilterIndex == i;
                      final count = i == 0
                          ? _bookings.length
                          : i == 1
                          ? _bookings
                                .where((b) => b.status == 'Menunggu Pembayaran')
                                .length
                          : i == 2
                          ? _bookings
                                .where((b) => b.status == 'Sudah Dibayar')
                                .length
                          : i == 3
                          ? _bookings
                                .where(
                                  (b) =>
                                      b.status == 'Dibatalkan' ||
                                      b.status == 'Kedaluwarsa',
                                )
                                .length
                          : _bookings
                                .where((b) => b.status == 'Perjalanan Selesai')
                                .length;

                      return InkWell(
                        onTap: () => setState(() => _selectedFilterIndex = i),
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF062056)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF062056)
                                  : const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF062056)
                                          .withValues(alpha: 0.18),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _filters[i],
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.22)
                                      : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF334155),
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
              ],
            ),
          ),

          const Divider(height: 1),

          // Daftar Kartu Pesanan
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadBookings,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return _buildOrderCard(item);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F1FC),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.luggage_outlined,
                size: 42,
                color: Color(0xFF062056),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum Ada Pesanan',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF062056),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Anda belum memiliki transaksi pemesanan tiket kereta pada kategori ini. Mulai perjalanan seru Anda bersama TKA sekarang.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF062056),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AntarKotaScreen()),
                );
                _loadBookings();
              },
              child: const Text(
                'Cari Tiket Kereta',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(BookingModel item) {
    final statusColor = _getStatusColor(item.status);
    final isWaiting = item.status == 'Menunggu Pembayaran';
    final isPaid = item.status == 'Sudah Dibayar';
    final isCompleted = item.status == 'Perjalanan Selesai';
    final isCancelled = item.status == 'Dibatalkan';
    final isExpired = item.status == 'Kedaluwarsa';

    return InkWell(
      onTap: () => _openDetail(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baris 1: Kode Booking, Tanggal & Badge Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      item.bookingId,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF062056),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• ${item.travelDate}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
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
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),

            if (isWaiting) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: Color(0xFFF26716),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Selesaikan pembayaran dalam: 18:19',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFC2410C),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Divider(height: 18),

            // Nama Kereta & Rute
            Text(
              item.trainName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B1E28),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.trainClass,
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            ),

            const SizedBox(height: 10),

            // Rute
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.originCode,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF062056),
                      ),
                    ),
                    Text(
                      item.originCity,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      item.departureTime,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: Colors.grey,
                    ),
                    Text(
                      '${item.passengerCount} Penumpang',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item.destCode,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF062056),
                      ),
                    ),
                    Text(
                      item.destCity,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      item.arrivalTime,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (isCancelled && item.cancelReason != null) ...[
              const SizedBox(height: 8),
              Text(
                'Alasan: ${item.cancelReason}. Dana pengembalian: ${_formatCurrency(item.refundAmount ?? 0)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626)),
              ),
            ],

            const Divider(height: 18),

            // Footer Kartu: Total Harga & Aksi
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isWaiting
                          ? 'TOTAL TAGIHAN'
                          : isCancelled
                          ? 'ESTIMASI REFUND'
                          : 'TOTAL PEMBAYARAN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      _formatCurrency(
                        isCancelled && item.refundAmount != null
                            ? item.refundAmount!
                            : item.totalAmount,
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF062056),
                      ),
                    ),
                  ],
                ),

                // Tombol aksi
                if (isWaiting)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF26716),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _openPayment(item),
                    child: const Text(
                      'Bayar Sekarang',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (isPaid)
                  Row(
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          side: const BorderSide(color: Color(0xFF062056)),
                        ),
                        onPressed: () => _openDetail(item),
                        child: const Text(
                          'Detail Pesanan',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF062056),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF062056),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ETicketBoardingPassScreen(
                                booking: item,
                                passengers: item.passengers,
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'Lihat Tiket',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  )
                else if (isCompleted)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF062056),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AntarKotaScreen(),
                        ),
                      );
                      _loadBookings();
                    },
                    icon: const Icon(
                      Icons.refresh_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Pesan Lagi',
                      style: TextStyle(fontSize: 11, color: Colors.white),
                    ),
                  )
                else if (isCancelled)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _openDetail(item),
                    child: const Text(
                      'Rincian',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (isExpired)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AntarKotaScreen(),
                        ),
                      );
                      _loadBookings();
                    },
                    child: const Text(
                      'Cari Jadwal Baru',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
