import 'package:flutter/material.dart';

import '../services/user_db_service.dart';

class NotificationsScreen extends StatefulWidget {
  final VoidCallback? onOpenTickets;
  final VoidCallback? onOpenOrders;

  const NotificationsScreen({super.key, this.onOpenTickets, this.onOpenOrders});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _activeFilter =
      0; // 0: Semua, 1: Transaksi, 2: Perjalanan, 3: Info Sistem

  List<String> _filters = [
    'Semua (5)',
    'Transaksi (4)',
    'Perjalanan (1)',
    'Info Sistem (0)',
  ];

  @override
  void initState() {
    super.initState();
    _syncNotificationsFromPostgrest();
  }

  Future<void> _syncNotificationsFromPostgrest() async {
    try {
      final results = await Future.wait([
        UserDatabaseService.getBookings(refreshRemote: true),
        UserDatabaseService.getPaymentsFromSupabase(),
      ]);
      final bookings = results[0] as List<BookingModel>;
      final payments = results[1] as List<Map<String, dynamic>>;
      final dynamicItems = <Map<String, dynamic>>[];

      for (final p in payments.take(3)) {
        final bid = (p['booking_id'] ?? '').toString();
        final ref = (p['reference_number'] ?? p['payment_id'] ?? '').toString();
        final amt = int.tryParse(p['amount']?.toString() ?? '0') ?? 0;
        final isTopUp = bid.toUpperCase().contains('TOPUP') || ref.startsWith('TOP-');
        if (isTopUp) {
          dynamicItems.add({
            'type': 'transaksi',
            'tag': 'TOP UP',
            'tagColor': const Color(0xFF10B981),
            'icon': Icons.account_balance_wallet_rounded,
            'time': 'Baru saja',
            'title': 'Top Up Saldo TKAPay Berhasil',
            'desc':
                'Pengisian saldo sebesar Rp$amt via ${p['payment_method'] ?? 'Virtual Account'} telah masuk ke akun Anda.',
            'subInfo': 'Ref: $ref • Berhasil',
          });
        }
      }

      for (final b in bookings.take(5)) {
        final isPaid = b.status == 'Sudah Dibayar';
        final isCancelled = b.status == 'Dibatalkan';
        dynamicItems.add({
          'type': 'transaksi',
          'tag': isCancelled ? 'REFUND' : (isPaid ? 'TIKET' : 'RESERVASI'),
          'tagColor': isCancelled
              ? const Color(0xFFEF4444)
              : (isPaid ? const Color(0xFF0284C7) : const Color(0xFFF26716)),
          'icon': isCancelled
              ? Icons.assignment_return_rounded
              : Icons.confirmation_number_outlined,
          'time': b.travelDate,
          'title': isCancelled
              ? 'Pembatalan Tiket (${b.bookingId})'
              : 'Tiket ${b.trainName} (${b.bookingId})',
          'desc':
              'Rute ${b.originName} (${b.originCode}) ➔ ${b.destName} (${b.destCode}) • Status: ${b.status}.',
          'subInfo': 'Kursi: ${b.seatNumber}',
          if (isPaid) 'action': 'Lihat Tiket',
          if (isPaid) 'isTicket': true,
        });
      }

      if (dynamicItems.isNotEmpty && mounted) {
        setState(() {
          _allNotifications
            ..removeWhere((n) => n['isDynamic'] == true)
            ..insertAll(
              0,
              dynamicItems.map((e) => {...e, 'isDynamic': true}),
            );
          final txCount = _allNotifications.where((n) => n['type'] == 'transaksi').length;
          final tripCount = _allNotifications.where((n) => n['type'] == 'perjalanan').length;
          _filters = [
            'Semua (${_allNotifications.length})',
            'Transaksi ($txCount)',
            'Perjalanan ($tripCount)',
            'Info Sistem (0)',
          ];
        });
      }
    } catch (_) {}
  }

  final List<Map<String, dynamic>> _allNotifications = [
    {
      'type': 'transaksi',
      'tag': 'TIKET',
      'tagColor': Color(0xFF0284C7),
      'icon': Icons.confirmation_number_outlined,
      'time': '10 menit lalu',
      'title': 'E-Ticket Telah Diterbitkan (PNR: TKA-9921XB)',
      'desc': 'Pembayaran berhasil dikonfirmasi. E-Ticket KA Argo Bromo Anggrek siap digunakan untuk keberangkatan 25 Okt 2024 pukul 08:20 WIB.',
      'subInfo': 'Gerbong EKS-2 / Kursi 7A',
      'action': 'Lihat Tiket',
      'isTicket': true,
    },
    {
      'type': 'transaksi',
      'tag': 'BATAS BAYAR',
      'tagColor': Color(0xFFF26716),
      'icon': Icons.access_time_filled_rounded,
      'time': '45 menit lalu',
      'title': 'Selesaikan Pembayaran Reservasi TKA-8832KL',
      'desc': 'Segera selesaikan pembayaran tiket KA Taksaka sebelum pukul 15:30 WIB agar kode booking tidak kedaluwarsa.',
      'subInfo': 'Tersisa 32 Menit',
      'action': 'Bayar Sekarang',
      'isPayment': true,
    },
    {
      'type': 'transaksi',
      'tag': 'RESERVASI',
      'tagColor': Color(0xFF64748B),
      'icon': Icons.receipt_long_rounded,
      'time': '1 jam lalu',
      'title': 'Kode Booking Sementara Berhasil Dibuat',
      'desc': 'Pemesanan tiket Anda telah dicatat sistem. Silakan lanjutkan ke pembayaran dalam batas waktu 60 menit.',
      'subInfo': 'KODE: TKA-8832KL • Instruksi Transfer',
    },
    {
      'type': 'perjalanan',
      'tag': 'OPERASIONAL',
      'tagColor': Color(0xFF062056),
      'icon': Icons.train_rounded,
      'time': '3 jam lalu',
      'title': 'Pemberitahuan Peron Keberangkatan KA 2',
      'desc': 'Rangkaian KA Argo Bromo Anggrek siap boarding di Peron 3 Stasiun Gambir. Harap merapat ke hall eksekutif.',
      'subInfo': 'Peron 3 • Stasiun Gambir (GMR)',
    },
    {
      'type': 'transaksi',
      'tag': 'SELESAI',
      'tagColor': Color(0xFF10B981),
      'icon': Icons.check_circle_outline_rounded,
      'time': 'Kemarin, 14:15',
      'title': 'Pembayaran Virtual Account Terverifikasi',
      'desc': 'Pembayaran sebesar Rp640.000 melalui BCA Virtual Account telah berhasil diverifikasi oleh sistem TKA.',
      'subInfo': 'Ref: VA-9901842910 • Lunas',
    },
  ];

  List<Map<String, dynamic>> get _filtered {
    if (_activeFilter == 1) {
      return _allNotifications.where((n) => n['type'] == 'transaksi').toList();
    }
    if (_activeFilter == 2) {
      return _allNotifications.where((n) => n['type'] == 'perjalanan').toList();
    }
    if (_activeFilter == 3) {
      return [];
    }
    return _allNotifications;
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;

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
          'Pusat Notifikasi',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF062056),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Semua notifikasi telah ditandai dibaca.'),
                  backgroundColor: Color(0xFF062056),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(
              Icons.done_all_rounded,
              size: 16,
              color: Color(0xFF062056),
            ),
            label: const Text(
              'Tandai Semua Dibaca',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF062056),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: Colors.white,
            height: 48,
            padding: const EdgeInsets.only(bottom: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final isSelected = _activeFilter == i;
                return GestureDetector(
                  onTap: () => setState(() => _activeFilter = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF062056)
                          : const Color(0xFFF1F4F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _filters[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1),

          // Daftar Notifikasi
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Tidak ada notifikasi pada kategori ini.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = list[index];
                      final tagColor = item['tagColor'] as Color;
                      final action = item['action'] as String?;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
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
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tagColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item['tag'] as String,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: tagColor,
                                    ),
                                  ),
                                ),
                                Text(
                                  item['time'] as String,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item['title'] as String,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B1E28),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['desc'] as String,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade700,
                                height: 1.35,
                              ),
                            ),
                            const Divider(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item['subInfo'] as String,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF062056),
                                  ),
                                ),
                                if (action != null)
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: item['isPayment'] == true
                                          ? const Color(0xFFF26716)
                                          : const Color(0xFF062056),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      minimumSize: Size.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).maybePop();
                                      if (item['isTicket'] == true) {
                                        widget.onOpenTickets?.call();
                                      } else if (item['isPayment'] == true) {
                                        widget.onOpenOrders?.call();
                                      }
                                    },
                                    child: Text(
                                      action,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
