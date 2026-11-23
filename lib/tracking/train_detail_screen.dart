import 'package:flutter/material.dart';
import '../intercity/antar_kota_screen.dart';
import '../models/tracking_models.dart';
import '../services/indonesia_time_service.dart';
import '../services/train_tracking_service.dart';
import 'station_detail_screen.dart';
import 'widgets/tracking_status_badge.dart';

/// B. Train Detail Screen
/// Menampilkan secara lengkap:
/// - Nama kereta, Nomor kereta, Jenis layanan (jika tersedia)
/// - Stasiun asal & tujuan
/// - Daftar stasiun pemberhentian (interaktif -> StationDetailScreen)
/// - Posisi terakhir & Waktu update terakhir
/// - Kecepatan jika tersedia
/// - Jadwal keberangkatan, Jadwal kedatangan, ETA jika dapat dihitung
/// - Status perjalanan & Informasi keterlambatan
class TrainDetailScreen extends StatefulWidget {
  final TrainTripModel trip;
  final void Function(String tripId)? onTrackOnMap;
  final void Function(String stationCode)? onFocusStationOnMap;

  const TrainDetailScreen({
    super.key,
    required this.trip,
    this.onTrackOnMap,
    this.onFocusStationOnMap,
  });

  @override
  State<TrainDetailScreen> createState() => _TrainDetailScreenState();
}

class _TrainDetailScreenState extends State<TrainDetailScreen> {
  TrainTripModel _resolveLatestTrip(List<TrainTripModel> all) {
    for (final t in all) {
      if (t.id == widget.trip.id) return t;
    }
    return widget.trip;
  }

  Future<void> _toggleFavorite(TrainTripModel trip) async {
    final added = await TrainTrackingService.toggleFavorite(trip);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? '${trip.trainName} (${trip.trainNumber}) ditambahkan ke Favorit.'
              : '${trip.trainName} dihapus dari Favorit.',
        ),
        backgroundColor: added ? const Color(0xFF10B981) : const Color(0xFF062056),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openStation(String stationCode) {
    final stations = TrainTrackingService.stationsNotifier.value;
    final match = stations.where((s) => s.code == stationCode.toUpperCase());
    if (match.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StationDetailScreen(
          station: match.first,
          onFocusOnLiveMap: widget.onFocusStationOnMap,
          onTrackTrainOnMap: widget.onTrackOnMap,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<TrainTripModel>>(
      valueListenable: TrainTrackingService.tripsNotifier,
      builder: (context, allTrips, _) {
        final trip = _resolveLatestTrip(allTrips);
        final eta = trip.computedEta;

        return ValueListenableBuilder<List<FavoriteTrainModel>>(
          valueListenable: TrainTrackingService.favoritesNotifier,
          builder: (context, _, _) {
            final isFav = TrainTrackingService.isTripFavorite(trip);

            return Scaffold(
              backgroundColor: const Color(0xFFF4F6FA),
              appBar: AppBar(
                backgroundColor: const Color(0xFF062056),
                foregroundColor: Colors.white,
                elevation: 0,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.trainName,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${trip.trainNumber} • ${trip.originCode} → ${trip.destinationCode}',
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    tooltip: isFav ? 'Hapus dari Favorit' : 'Simpan ke Favorit',
                    icon: Icon(
                      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isFav ? const Color(0xFFF97316) : Colors.white,
                    ),
                    onPressed: () => _toggleFavorite(trip),
                  ),
                ],
              ),
              body: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Peringatan jujur bila data simulasi/demo
                    if (trip.isSimulated || trip.dataStatus == TrainDataStatus.demo)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DemoDataDisclaimerBanner(
                          customMessage:
                              'Perhatian: Posisi kereta ini berasal dari "${trip.dataSourceLabel}" (Mode Demo / Simulasi) dan BUKAN sinyal GPS real-time.',
                        ),
                      ),

                    // Kartu Header Kereta & Status Perjalanan
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                  color: trip.dataStatus.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.train_rounded,
                                  color: trip.dataStatus.color,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      trip.trainName,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF062056),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Nomor Kereta: ${trip.trainNumber}'
                                      '${trip.serviceType != null && trip.serviceType!.isNotEmpty ? ' • ${trip.serviceType}' : ''}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              TrainStatusBadge(
                                status: trip.dataStatus,
                                delayMinutes: trip.delayMinutes,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Wilayah: ${trip.region}',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: trip.dataStatus == TrainDataStatus.delayed
                                  ? const Color(0xFFFEF2F2)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: trip.dataStatus == TrainDataStatus.delayed
                                    ? const Color(0xFFFECACA)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Status Perjalanan: ${trip.tripStatus}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: trip.dataStatus == TrainDataStatus.delayed
                                        ? const Color(0xFFB91C1C)
                                        : const Color(0xFF062056),
                                  ),
                                ),
                                if (trip.delayReason != null &&
                                    trip.delayReason!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Catatan: ${trip.delayReason}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Asal & Tujuan (bisa diklik ke StationDetailScreen)
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _openStation(trip.originCode),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('STASIUN ASAL',
                                            style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.grey.shade500)),
                                        const SizedBox(height: 4),
                                        Text(
                                          trip.originCode,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF062056),
                                          ),
                                        ),
                                        Text(
                                          trip.originName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          IndonesiaTimeService.formatTime(
                                              trip.scheduledDeparture),
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFF26716),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(Icons.arrow_forward_rounded,
                                    color: Color(0xFF062056)),
                              ),
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () =>
                                      _openStation(trip.destinationCode),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('STASIUN TUJUAN',
                                            style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.grey.shade500)),
                                        const SizedBox(height: 4),
                                        Text(
                                          trip.destinationCode,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF062056),
                                          ),
                                        ),
                                        Text(
                                          trip.destinationName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          IndonesiaTimeService.formatTime(
                                              trip.scheduledArrival),
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Grid Telemetri (ETA, Kecepatan, Posisi Terakhir, Update Terakhir)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
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
                          const Text(
                            'Telemetri & Estimasi Kedatangan',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF062056),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _metricTile(
                                  icon: Icons.timer_outlined,
                                  color: const Color(0xFFF26716),
                                  label: 'Estimasi Tiba (ETA)',
                                  value: eta != null
                                      ? IndonesiaTimeService.formatTime(eta)
                                      : 'Tidak dapat dihitung',
                                  sub: eta != null
                                      ? IndonesiaTimeService
                                          .formatRemainingToEta(eta)
                                      : 'Posisi belum tersedia',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _metricTile(
                                  icon: Icons.speed_rounded,
                                  color: const Color(0xFF2563EB),
                                  label: 'Kecepatan',
                                  value: trip.speedKmh != null
                                      ? '${trip.speedKmh!.toStringAsFixed(0)} km/j'
                                      : 'Tidak tersedia',
                                  sub: trip.heading != null
                                      ? 'Arah ${trip.heading!.toStringAsFixed(0)}°'
                                      : 'Sensor kecepatan off',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _metricTile(
                                  icon: Icons.my_location_rounded,
                                  color: const Color(0xFF10B981),
                                  label: 'Posisi Terakhir',
                                  value: trip.hasValidPosition
                                      ? '${trip.currentLat!.toStringAsFixed(4)}, ${trip.currentLng!.toStringAsFixed(4)}'
                                      : 'Tidak tersedia',
                                  sub: trip.currentStationCode != null &&
                                          trip.nextStationCode != null
                                      ? 'Segmen ${trip.currentStationCode} → ${trip.nextStationCode}'
                                      : 'Belum ada koordinat',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _metricTile(
                                  icon: Icons.update_rounded,
                                  color: const Color(0xFF7C3AED),
                                  label: 'Update Terakhir',
                                  value: IndonesiaTimeService.formatTime(
                                    trip.lastUpdatedAt,
                                    withSeconds: true,
                                  ),
                                  sub: IndonesiaTimeService.formatRelative(
                                    trip.lastUpdatedAt,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Daftar Stasiun Pemberhentian
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Daftar Stasiun Pemberhentian',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF062056),
                                ),
                              ),
                              Text(
                                '${trip.stops.length} Stasiun',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (trip.stops.isEmpty)
                            Text(
                              'Daftar stasiun pemberhentian tidak tersedia untuk perjalanan ini.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                            )
                          else
                            Column(
                              children: List.generate(trip.stops.length, (i) {
                                final st = trip.stops[i];
                                final isLast = i == trip.stops.length - 1;
                                final isPassed = st.stopStatus == 'PASSED';
                                final isHere = st.stopStatus == 'AT_STATION';
                                final dotColor = isHere
                                    ? const Color(0xFFF26716)
                                    : (isPassed
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFCBD5E1));

                                return InkWell(
                                  onTap: () => _openStation(st.stationCode),
                                  child: IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        SizedBox(
                                          width: 26,
                                          child: Column(
                                            children: [
                                              Container(
                                                width: 14,
                                                height: 14,
                                                decoration: BoxDecoration(
                                                  color: dotColor,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 2,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: dotColor
                                                          .withValues(alpha: 0.4),
                                                      blurRadius: 4,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (!isLast)
                                                Expanded(
                                                  child: Container(
                                                    width: 2.5,
                                                    color: isPassed
                                                        ? const Color(0xFF10B981)
                                                        : const Color(0xFFE2E8F0),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 16),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        '${st.stationName} (${st.stationCode})',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: isPassed
                                                              ? Colors
                                                                  .grey.shade600
                                                              : const Color(
                                                                  0xFF062056),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        '${st.city}${st.platform != null ? ' • ${st.platform}' : ''}',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors
                                                              .grey.shade600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    if (st.scheduledArrival !=
                                                        null)
                                                      Text(
                                                        'Tiba ${IndonesiaTimeService.formatTime(st.estimatedArrival ?? st.scheduledArrival, showZone: false)}',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              Color(0xFF062056),
                                                        ),
                                                      ),
                                                    if (st.scheduledDeparture !=
                                                        null)
                                                      Text(
                                                        'Brkt ${IndonesiaTimeService.formatTime(st.estimatedDeparture ?? st.scheduledDeparture, showZone: false)}',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors
                                                              .grey.shade600,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Tombol Aksi (Ikuti di Peta & Pesan Tiket)
                    Row(
                      children: [
                        if (widget.onTrackOnMap != null)
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF062056),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                                widget.onTrackOnMap!(trip.id);
                              },
                              icon: const Icon(Icons.gps_fixed_rounded,
                                  size: 18),
                              label: const Text(
                                'Ikuti di Peta',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        if (widget.onTrackOnMap != null)
                          const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF26716),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AntarKotaScreen(
                                    initialOrigin:
                                        '${trip.originName} (${trip.originCode})',
                                    initialDestination:
                                        '${trip.destinationName} (${trip.destinationCode})',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.confirmation_number_rounded,
                                size: 18),
                            label: const Text(
                              'Pesan Tiket',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _metricTile({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String sub,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF062056),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

