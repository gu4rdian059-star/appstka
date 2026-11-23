import 'package:flutter/material.dart';
import '../models/tracking_models.dart';
import '../services/brevo_notification_service.dart';
import '../services/indonesia_time_service.dart';
import '../services/session_service.dart';
import '../services/train_tracking_service.dart';

/// E. Notifications Screen — Terintegrasi Brevo API & Deduplikasi Supabase Postgres.
/// Mendukung 5 jenis notifikasi:
/// 1. Train delay (TRAIN_DELAY)
/// 2. Schedule changes (SCHEDULE_CHANGE)
/// 3. Service disruption (SERVICE_DISRUPTION)
/// 4. Arrival information (ARRIVAL_INFO)
/// 5. Trip status changes (TRIP_STATUS_CHANGE)
/// Menjamin tidak pernah mengirim notifikasi duplikat untuk kejadian yang sama.
class NotificationsScreen extends StatefulWidget {
  final VoidCallback? onOpenTickets;
  final VoidCallback? onOpenOrders;

  const NotificationsScreen({
    super.key,
    this.onOpenTickets,
    this.onOpenOrders,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  TrainNotificationEventType? _selectedType; // null = Semua
  List<TrainNotificationModel> _items = [];
  bool _isLoading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMsg = null;
      });
    }
    try {
      await BrevoNotificationService.ensureInitialSeedIfEmpty();
      final list = await BrevoNotificationService.getNotifications();
      if (mounted) {
        setState(() {
          _items = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Gagal memuat notifikasi: $e';
        });
      }
    }
  }

  List<TrainNotificationModel> get _filtered {
    if (_selectedType == null) return _items;
    return _items.where((n) => n.eventType == _selectedType).toList();
  }

  Future<void> _markAllRead() async {
    await BrevoNotificationService.markAllAsRead();
    await _loadNotifications();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Semua notifikasi telah ditandai dibaca.'),
        backgroundColor: Color(0xFF062056),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openBrevoTestDialog() async {
    final savedEmail = await SessionService.getUserEmail() ?? '';
    if (!mounted) return;

    final emailCtrl = TextEditingController(text: savedEmail);
    final incidentCtrl = TextEditingController(
      text: 'INCIDENT_${IndonesiaTimeService.now().day}_KA40',
    );
    TrainNotificationEventType chosenType =
        TrainNotificationEventType.trainDelay;
    final trips = TrainTrackingService.tripsNotifier.value;
    String selectedTripId =
        trips.isNotEmpty ? trips.first.id : 'TRIP-KA40-AP';
    bool sendEmail = true;
    bool sending = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Kirim / Uji Notifikasi Brevo (Anti-Duplikasi)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF062056),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Text(
                  'Kirim notifikasi perjalanan ke email via Brevo API. Jika Anda mengirim 2x dengan Kode Kejadian yang sama, sistem otomatis memblokir duplikat.',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 14),
                const Text('Jenis Notifikasi',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<TrainNotificationEventType>(
                  initialValue: chosenType,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: TrainNotificationEventType.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.label,
                                style: const TextStyle(fontSize: 12.5)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => chosenType = v);
                  },
                ),
                const SizedBox(height: 10),
                if (trips.isNotEmpty) ...[
                  const Text('Kereta Terkait',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedTripId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    items: trips
                        .map((t) => DropdownMenuItem(
                              value: t.id,
                              child: Text(
                                '${t.trainNumber} • ${t.trainName}',
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => selectedTripId = v);
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                const Text('Email Penerima (Brevo)',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'contoh: user@gmail.com',
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Kode Kejadian Unik (Anti-Duplikasi)',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: incidentCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Misal: DELAY_18M_20NOV',
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: const Color(0xFFF26716),
                  title: const Text(
                    'Kirim Email Transaksional via Brevo API',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  value: sendEmail,
                  onChanged: (v) => setModalState(() => sendEmail = v),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF062056),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: sending
                        ? null
                        : () async {
                            setModalState(() => sending = true);
                            final trip = trips.where((t) => t.id == selectedTripId);
                            final matched = trip.isNotEmpty ? trip.first : null;
                            final res = await BrevoNotificationService
                                .dispatchNotification(
                              eventType: chosenType,
                              tripId: selectedTripId,
                              incidentCode: incidentCtrl.text.trim().isEmpty
                                  ? 'EVENT_DEFAULT'
                                  : incidentCtrl.text.trim(),
                              title:
                                  '${chosenType.label}: ${matched?.trainName ?? selectedTripId}',
                              message:
                                  'Pembaruan ${chosenType.label.toLowerCase()} untuk ${matched?.trainNumber ?? ''} ${matched?.trainName ?? ''} pada ${IndonesiaTimeService.formatDateTime(DateTime.now().toUtc())}.',
                              trainNumber: matched?.trainNumber,
                              trainName: matched?.trainName,
                              overrideRecipientEmail: emailCtrl.text.trim(),
                              sendEmail: sendEmail,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            await _loadNotifications();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res.message),
                                backgroundColor: res.isDuplicate
                                    ? const Color(0xFFF59E0B)
                                    : (res.brevoStatus == 'SENT'
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF062056)),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                    icon: sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 17),
                    label: Text(
                      sending ? 'Mengirim...' : 'Kirim Notifikasi',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
    final list = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062056),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Pusat Notifikasi & Brevo',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Kirim / Uji Notifikasi Brevo',
            icon: const Icon(Icons.mark_email_unread_outlined),
            onPressed: _openBrevoTestDialog,
          ),
          IconButton(
            tooltip: 'Tandai Semua Dibaca',
            icon: const Icon(Icons.done_all_rounded),
            onPressed: _markAllRead,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Kategori Event Notifikasi
          Container(
            color: Colors.white,
            height: 50,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                _filterChip(null, 'Semua (${_items.length})'),
                ...TrainNotificationEventType.values.map((type) {
                  final count = _items.where((n) => n.eventType == type).length;
                  return _filterChip(type, '${type.shortTag} ($count)');
                }),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body: Loading / Error / Empty / List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFF26716)),
                  )
                : _errorMsg != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  size: 46, color: Color(0xFFEF4444)),
                              const SizedBox(height: 10),
                              Text(_errorMsg!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _loadNotifications,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : list.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.notifications_off_outlined,
                                      size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Belum ada notifikasi pada kategori ini.',
                                    style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: _openBrevoTestDialog,
                                    icon: const Icon(
                                        Icons.mark_email_read_outlined,
                                        size: 16),
                                    label: const Text('Uji Kirim via Brevo'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadNotifications,
                            color: const Color(0xFFF26716),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(14),
                              itemCount: list.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) =>
                                  _buildNotificationCard(list[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(TrainNotificationEventType? type, String label) {
    final sel = _selectedType == type;
    final color = type?.color ?? const Color(0xFF062056);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: sel ? color : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: sel ? Colors.white : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(TrainNotificationModel n) {
    final color = n.eventType.color;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        if (!n.isRead) {
          await BrevoNotificationService.markAsRead(n.id);
          _loadNotifications();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: n.isRead ? Colors.white : const Color(0xFFFFFBF5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: n.isRead
                ? const Color(0xFFE2E8F0)
                : color.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(n.eventType.icon, size: 12, color: color),
                      const SizedBox(width: 4),
                      Text(
                        n.eventType.shortTag,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _brevoStatusPill(n.brevoStatus),
                const Spacer(),
                Text(
                  IndonesiaTimeService.formatRelative(n.createdAt),
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              n.title,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF062056),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              n.message,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            const Divider(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Dedup: ${n.eventDedupKey}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
                if (!n.isRead)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF26716),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _brevoStatusPill(String status) {
    final Color c;
    final String label;
    switch (status) {
      case 'SENT':
        c = const Color(0xFF10B981);
        label = 'Brevo Terkirim';
      case 'FAILED':
        c = const Color(0xFFEF4444);
        label = 'Brevo Gagal';
      case 'PENDING':
        c = const Color(0xFFF59E0B);
        label = 'Brevo Pending';
      default:
        c = const Color(0xFF64748B);
        label = 'In-App';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: c),
      ),
    );
  }
}
