import 'package:flutter/material.dart';
import 'order_detail_screen.dart';
import 'refund_screen.dart';
import '../intercity/antar_kota_screen.dart';
import '../payment/payment_screen.dart';
import '../services/user_db_service.dart';

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
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
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
    return _bookings.where((item) {
      // 1. Filter Chip
      if (_selectedFilterIndex == 1 && item.status != 'Menunggu Pembayaran') return false;
      if (_selectedFilterIndex == 2 && item.status != 'Sudah Dibayar') return false;
      if (_selectedFilterIndex == 3 && item.status != 'Dibatalkan' && item.status != 'Kedaluwarsa') return false;
      if (_selectedFilterIndex == 4 && item.status != 'Perjalanan Selesai') return false;

      // 2. Search Query
      if (_searchQuery.isNotEmpty) {
        final id = item.bookingId.toLowerCase();
        final name = item.trainName.toLowerCase();
        if (!id.contains(_searchQuery) && !name.contains(_searchQuery)) {
          return false;
        }
      }

      return true;
    }).toList();
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
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          existingBooking: item,
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOrders;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: widget.embedded
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF062056)),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daftar Pesanan',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF062056),
              ),
            ),
            Text(
              'Pantau dan kelola tiket perjalanan kereta Anda',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pusat Bantuan Pemesanan Tiket TKA siap 24/7.'),
                  backgroundColor: Color(0xFF062056),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.headset_mic_outlined, size: 16, color: Color(0xFF062056)),
            label: const Text(
              'Bantuan',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF062056)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Baris Pencarian & Filter
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F4F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: 'Cari kode booking atau nama KA...',
                              hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () => _searchController.clear(),
                            child: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF062056), size: 22),
                  onPressed: _loadBookings,
                ),
              ],
            ),
          ),

          // Chips Filter
          Container(
            color: Colors.white,
            height: 44,
            padding: const EdgeInsets.only(bottom: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final isSelected = _selectedFilterIndex == i;
                final count = i == 0
                    ? _bookings.length
                    : i == 1
                        ? _bookings.where((b) => b.status == 'Menunggu Pembayaran').length
                        : i == 2
                            ? _bookings.where((b) => b.status == 'Sudah Dibayar').length
                            : i == 3
                                ? _bookings.where((b) => b.status == 'Dibatalkan' || b.status == 'Kedaluwarsa').length
                                : _bookings.where((b) => b.status == 'Perjalanan Selesai').length;

                return GestureDetector(
                  onTap: () => setState(() => _selectedFilterIndex = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF062056) : const Color(0xFFF1F4F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_filters[i]} ($count)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ),
                );
              },
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
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AntarKotaScreen()),
                );
                _loadBookings();
              },
              child: const Text(
                'Cari Tiket Kereta',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 14, color: Color(0xFFF26716)),
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
                      style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                    ),
                    Text(
                      item.departureTime,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const Column(
                  children: [
                    Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey),
                    Text('1 Penumpang', style: TextStyle(fontSize: 10, color: Colors.grey)),
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
                      style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                    ),
                    Text(
                      item.arrivalTime,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
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
                      _formatCurrency(isCancelled && item.refundAmount != null ? item.refundAmount! : item.totalAmount),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _openPayment(item),
                    child: const Text(
                      'Bayar Sekarang',
                      style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  )
                else if (isPaid)
                  Row(
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: const BorderSide(color: Color(0xFF062056)),
                        ),
                        onPressed: () => _openDetail(item),
                        child: const Text(
                          'Detail Pesanan',
                          style: TextStyle(fontSize: 11, color: Color(0xFF062056), fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF062056),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          widget.onNavigateToTickets?.call();
                        },
                        child: const Text(
                          'Lihat Tiket',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  )
                else if (isCompleted)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF062056),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AntarKotaScreen()),
                      );
                      _loadBookings();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 14, color: Colors.white),
                    label: const Text('Pesan Lagi', style: TextStyle(fontSize: 11, color: Colors.white)),
                  )
                else if (isCancelled)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _openDetail(item),
                    child: const Text('Rincian', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  )
                else if (isExpired)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AntarKotaScreen()),
                      );
                      _loadBookings();
                    },
                    child: const Text('Cari Jadwal Baru', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
