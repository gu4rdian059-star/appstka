import 'package:flutter/material.dart';
import '../models/tracking_models.dart';
import '../services/brevo_notification_service.dart';
import '../services/indonesia_time_service.dart';
import '../services/train_tracking_service.dart';
import 'train_detail_screen.dart';
import 'widgets/tracking_status_badge.dart';

/// G. Favorites Screen
/// Pengguna dapat menyimpan kereta atau perjalanan favorit dan mengatur
/// preferensi notifikasi Brevo/In-App untuk setiap perjalanan favorit.
class FavoritesScreen extends StatefulWidget {
  final void Function(String tripId)? onTrackTrainOnMap;
  final void Function(String stationCode)? onFocusStationOnMap;

  const FavoritesScreen({
    super.key,
    this.onTrackTrainOnMap,
    this.onFocusStationOnMap,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  TrainTripModel? _findLiveTrip(
      FavoriteTrainModel fav, List<TrainTripModel> trips) {
    for (final t in trips) {
      if (fav.tripId != null && t.id == fav.tripId) return t;
      if (t.trainNumber.toUpperCase() == fav.trainNumber.toUpperCase() &&
          t.originCode == fav.originCode &&
          t.destinationCode == fav.destinationCode) {
        return t;
      }
    }
    return null;
  }

  void _openAddFavoritePicker(List<TrainTripModel> trips) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tambah Kereta Favorit',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF062056),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  itemCount: trips.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final trip = trips[i];
                    final isFav = TrainTrackingService.isTripFavorite(trip);
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      leading: Icon(Icons.train_rounded,
                          color: trip.dataStatus.color),
                      title: Text(
                        '${trip.trainNumber} • ${trip.trainName}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${trip.originCode} → ${trip.destinationCode} • ${trip.region}',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      trailing: Icon(
                        isFav
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFav ? const Color(0xFFF26716) : Colors.grey,
                      ),
                      onTap: () async {
                        await TrainTrackingService.toggleFavorite(trip);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFavoriteNotifSettings(FavoriteTrainModel fav) {
    FavoriteTrainModel working = fav;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pengaturan Notifikasi Favorit',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF062056),
                          ),
                        ),
                        Text(
                          '${working.trainNumber} • ${working.trainName} (${working.originCode} → ${working.destinationCode})',
                          style: TextStyle(
                              fontSize: 11.5, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 18),
              _switchRow(
                'Keterlambatan Kereta (Train Delay)',
                working.notifyDelay,
                (v) => setModalState(() => working = working.copyWith(notifyDelay: v)),
              ),
              _switchRow(
                'Perubahan Jadwal (Schedule Change)',
                working.notifyScheduleChange,
                (v) => setModalState(
                    () => working = working.copyWith(notifyScheduleChange: v)),
              ),
              _switchRow(
                'Gangguan Layanan (Service Disruption)',
                working.notifyServiceDisruption,
                (v) => setModalState(
                    () => working = working.copyWith(notifyServiceDisruption: v)),
              ),
              _switchRow(
                'Informasi Kedatangan (Arrival Info)',
                working.notifyArrivalInfo,
                (v) => setModalState(
                    () => working = working.copyWith(notifyArrivalInfo: v)),
              ),
              _switchRow(
                'Perubahan Status Perjalanan',
                working.notifyStatusChange,
                (v) => setModalState(
                    () => working = working.copyWith(notifyStatusChange: v)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final res =
                            await BrevoNotificationService.dispatchNotification(
                          eventType: TrainNotificationEventType.arrivalInfo,
                          tripId: working.tripId ?? working.trainNumber,
                          incidentCode:
                              'FAV_ALERT_${IndonesiaTimeService.now().day}_${IndonesiaTimeService.now().hour}',
                          title: 'Pengingat Perjalanan ${working.trainName}',
                          message:
                              'Notifikasi aktif untuk kereta favorit ${working.trainNumber} (${working.originCode} → ${working.destinationCode}).',
                          trainNumber: working.trainNumber,
                          trainName: working.trainName,
                          sendEmail: true,
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res.message),
                            backgroundColor: res.isDuplicate
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF062056),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.mark_email_read_outlined, size: 16),
                      label: const Text('Uji Brevo',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF062056),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        await TrainTrackingService.updateFavorite(working);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Pengaturan notifikasi favorit disimpan.'),
                            backgroundColor: Color(0xFF10B981),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: const Text('Simpan',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _switchRow(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      activeThumbColor: const Color(0xFFF26716),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<TrainTripModel>>(
      valueListenable: TrainTrackingService.tripsNotifier,
      builder: (context, trips, _) {
        return ValueListenableBuilder<List<FavoriteTrainModel>>(
          valueListenable: TrainTrackingService.favoritesNotifier,
          builder: (context, favorites, _) {
            return Scaffold(
              backgroundColor: const Color(0xFFF4F6FA),
              appBar: AppBar(
                backgroundColor: const Color(0xFF062056),
                foregroundColor: Colors.white,
                elevation: 0,
                automaticallyImplyLeading: false,
                title: Text(
                  'Kereta Favorit (${favorites.length})',
                  style: const TextStyle(
                      fontSize: 16.5, fontWeight: FontWeight.bold),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Tambah Favorit',
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    onPressed: () => _openAddFavoritePicker(trips),
                  ),
                ],
              ),
              body: favorites.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.favorite_border_rounded,
                                  size: 46, color: Color(0xFFF26716)),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Belum Ada Kereta Favorit',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF062056),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Simpan kereta atau rute langganan Anda untuk memantau status perjalanan & menerima notifikasi keterlambatan via Brevo.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.grey.shade600,
                                  height: 1.4),
                            ),
                            const SizedBox(height: 18),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF26716),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => _openAddFavoritePicker(trips),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text(
                                'Pilih Kereta Favorit',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: favorites.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final fav = favorites[i];
                        final liveTrip = _findLiveTrip(fav, trips);
                        final activeAlerts = [
                          if (fav.notifyDelay) 'Delay',
                          if (fav.notifyScheduleChange) 'Jadwal',
                          if (fav.notifyServiceDisruption) 'Gangguan',
                          if (fav.notifyArrivalInfo) 'Kedatangan',
                          if (fav.notifyStatusChange) 'Status',
                        ];

                        return Card(
                          margin: EdgeInsets.zero,
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.favorite_rounded,
                                        color: Color(0xFFF26716), size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${fav.trainNumber} • ${fav.trainName}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF062056),
                                        ),
                                      ),
                                    ),
                                    if (liveTrip != null)
                                      TrainStatusBadge(
                                        status: liveTrip.dataStatus,
                                        delayMinutes: liveTrip.delayMinutes,
                                        compact: true,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Rute: ${fav.originCode} → ${fav.destinationCode}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: activeAlerts.isEmpty
                                      ? [
                                          Text(
                                            'Semua notifikasi dimatikan',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade500),
                                          )
                                        ]
                                      : activeAlerts
                                          .map(
                                            (a) => Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                'Notif: $a',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF062056),
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                ),
                                const Divider(height: 18),
                                Row(
                                  children: [
                                    TextButton.icon(
                                      onPressed: () =>
                                          _openFavoriteNotifSettings(fav),
                                      icon: const Icon(
                                          Icons.notifications_active_outlined,
                                          size: 15),
                                      label: const Text('Atur Notif',
                                          style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    if (liveTrip != null) ...[
                                      TextButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => TrainDetailScreen(
                                                trip: liveTrip,
                                                onTrackOnMap:
                                                    widget.onTrackTrainOnMap,
                                                onFocusStationOnMap:
                                                    widget.onFocusStationOnMap,
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                            Icons.info_outline_rounded,
                                            size: 15),
                                        label: const Text('Detail',
                                            style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                      if (widget.onTrackTrainOnMap != null)
                                        TextButton.icon(
                                          onPressed: () => widget
                                              .onTrackTrainOnMap!(liveTrip.id),
                                          icon: const Icon(
                                              Icons.gps_fixed_rounded,
                                              size: 15,
                                              color: Color(0xFFF26716)),
                                          label: const Text(
                                            'Peta',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFF26716),
                                            ),
                                          ),
                                        ),
                                    ],
                                    const Spacer(),
                                    IconButton(
                                      tooltip: 'Hapus Favorit',
                                      icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 19,
                                          color: Color(0xFFDC2626)),
                                      onPressed: () =>
                                          TrainTrackingService.removeFavorite(
                                              fav),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            );
          },
        );
      },
    );
  }
}

