import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../config/app_env.dart';
import '../../models/tracking_models.dart';
import '../../services/indonesia_time_service.dart';
import '../../services/train_tracking_service.dart';
import 'train_detail_screen.dart';
import 'widgets/tracking_status_badge.dart';

/// D. Station Information Screen
/// Menampilkan:
/// - Station name, code, address, latitude, longitude
/// - Station location on map (MapLibre + MapTiler)
/// - Arrival schedules & Departure schedules
/// - Available train information
/// - Station facilities jika tersedia
class StationDetailScreen extends StatefulWidget {
  final TrackStationModel station;
  final void Function(String stationCode)? onFocusOnLiveMap;
  final void Function(String tripId)? onTrackTrainOnMap;

  const StationDetailScreen({
    super.key,
    required this.station,
    this.onFocusOnLiveMap,
    this.onTrackTrainOnMap,
  });

  @override
  State<StationDetailScreen> createState() => _StationDetailScreenState();
}

class _StationDetailScreenState extends State<StationDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  MapLibreMapController? _miniMapController;
  bool _mapReadyToMount = false;
  Timer? _mountMapTimer;

  bool get _supportsMapLibre =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _mountMapTimer = Timer(const Duration(milliseconds: 80), () {
      if (mounted) setState(() => _mapReadyToMount = true);
    });
  }

  @override
  void dispose() {
    FocusManager.instance.primaryFocus?.unfocus();
    _mountMapTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _onMiniMapStyleLoaded() async {
    final ctrl = _miniMapController;
    if (ctrl == null) return;
    try {
      await ctrl.addGeoJsonSource('station-pin-src', {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'id': widget.station.code,
            'geometry': {
              'type': 'Point',
              'coordinates': [widget.station.longitude, widget.station.latitude],
            },
            'properties': {
              'code': widget.station.code,
              'name': widget.station.name,
            },
          },
        ],
      });
      await ctrl.addCircleLayer(
        'station-pin-src',
        'station-pin-halo',
        const CircleLayerProperties(
          circleRadius: 16,
          circleColor: '#F26716',
          circleOpacity: 0.22,
        ),
      );
      await ctrl.addCircleLayer(
        'station-pin-src',
        'station-pin-core',
        const CircleLayerProperties(
          circleRadius: 8,
          circleColor: '#062056',
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 2.5,
        ),
      );
    } catch (e) {
      debugPrint('Catatan mini map layer stasiun: $e');
    }
  }

  void _copyCoordinates() {
    final coords =
        '${widget.station.latitude.toStringAsFixed(6)}, ${widget.station.longitude.toStringAsFixed(6)}';
    Clipboard.setData(ClipboardData(text: coords));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Koordinat disalin: $coords'),
        backgroundColor: const Color(0xFF062056),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final station = widget.station;
    final arrivals = TrainTrackingService.getStationArrivals(station.code);
    final departures = TrainTrackingService.getStationDepartures(station.code);
    final servingTrains = TrainTrackingService.getTrainsServingStation(station.code);

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
              station.name,
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
            ),
            Text(
              'Kode ${station.code} • ${station.city} (${station.region})',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (widget.onFocusOnLiveMap != null)
            IconButton(
              tooltip: 'Lihat di Live Map',
              icon: const Icon(Icons.map_rounded),
              onPressed: () {
                Navigator.of(context).pop();
                widget.onFocusOnLiveMap!(station.code);
              },
            ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Mini Map Lokasi Stasiun
                SizedBox(
                  height: 210,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      if (_supportsMapLibre &&
                          AppEnv.hasMapTilerConfig &&
                          _mapReadyToMount)
                        RepaintBoundary(
                          child: MapLibreMap(
                            key: ValueKey('station_minimap_${station.code}'),
                            styleString: AppEnv.mapTilerStyleUrl,
                            initialCameraPosition: CameraPosition(
                              target:
                                  LatLng(station.latitude, station.longitude),
                              zoom: 13.8,
                            ),
                            cameraTargetBounds: CameraTargetBounds(
                              LatLngBounds(
                                southwest: const LatLng(-11.2, 94.8),
                                northeast: const LatLng(6.3, 141.2),
                              ),
                            ),
                            minMaxZoomPreference:
                                const MinMaxZoomPreference(5.0, 16.0),
                            onMapCreated: (c) => _miniMapController = c,
                            onStyleLoadedCallback: _onMiniMapStyleLoaded,
                            compassEnabled: false,
                            rotateGesturesEnabled: false,
                            tiltGesturesEnabled: false,
                            trackCameraPosition: false,
                          ),
                        )
                      else
                        Container(
                          color: const Color(0xFFE2E8F0),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on_rounded,
                                    size: 38, color: Color(0xFF062056)),
                                const SizedBox(height: 6),
                                Text(
                                  '${station.latitude.toStringAsFixed(5)}, ${station.longitude.toStringAsFixed(5)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF062056),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF062056),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Text(
                            '${station.code} • ${station.timezone}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      if (widget.onFocusOnLiveMap != null)
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF26716),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onFocusOnLiveMap!(station.code);
                            },
                            icon: const Icon(Icons.my_location_rounded, size: 15),
                            label: const Text(
                              'Buka di Live Map',
                              style: TextStyle(
                                  fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // 2. Informasi Stasiun (Alamat, Koordinat, Fasilitas)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
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
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF062056),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    station.code,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        station.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF062056),
                                        ),
                                      ),
                                      Text(
                                        '${station.city} • ${station.region}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 22),
                            _infoRow(
                              Icons.location_on_outlined,
                              'Alamat',
                              station.address.isNotEmpty
                                  ? station.address
                                  : 'Alamat belum tersedia',
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _infoRow(
                                    Icons.explore_outlined,
                                    'Koordinat GPS',
                                    'Lat: ${station.latitude.toStringAsFixed(6)}\nLng: ${station.longitude.toStringAsFixed(6)}',
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _copyCoordinates,
                                  icon: const Icon(Icons.copy_rounded, size: 14),
                                  label: const Text('Salin',
                                      style: TextStyle(fontSize: 11.5)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF062056),
                                    side: const BorderSide(
                                        color: Color(0xFFCBD5E1)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Fasilitas Stasiun
                      Container(
                        width: double.infinity,
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
                            const Row(
                              children: [
                                Icon(Icons.domain_verification_rounded,
                                    size: 18, color: Color(0xFFF26716)),
                                SizedBox(width: 8),
                                Text(
                                  'Fasilitas Stasiun',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF062056),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (station.facilities.isEmpty)
                              Text(
                                'Informasi fasilitas stasiun belum tersedia.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: station.facilities.map((fac) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check_circle_rounded,
                                            size: 13, color: Color(0xFF10B981)),
                                        const SizedBox(width: 5),
                                        Text(
                                          fac,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Tab Bar Jadwal Kedatangan, Keberangkatan, Kereta Tersedia
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF062056),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: const Color(0xFFF26716),
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                    tabs: [
                      Tab(text: 'Keberangkatan (${departures.length})'),
                      Tab(text: 'Kedatangan (${arrivals.length})'),
                      Tab(text: 'Kereta (${servingTrains.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildScheduleList(departures, isDeparture: true),
            _buildScheduleList(arrivals, isDeparture: false),
            _buildAvailableTrainsList(servingTrains),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleList(
    List<({TrainTripModel trip, DateTime? time, String? platform})> items, {
    required bool isDeparture,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.train_outlined, size: 44, color: Colors.grey.shade400),
              const SizedBox(height: 10),
              Text(
                isDeparture
                    ? 'Belum ada jadwal keberangkatan tercatat di stasiun ini.'
                    : 'Belum ada jadwal kedatangan tercatat di stasiun ini.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final item = items[i];
        final trip = item.trip;
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TrainDetailScreen(
                  trip: trip,
                  onTrackOnMap: widget.onTrackTrainOnMap,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 74,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        IndonesiaTimeService.formatTime(
                          item.time,
                          showZone: false,
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF062056),
                        ),
                      ),
                      Text(
                        IndonesiaTimeService.currentTimezone.value.code,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${trip.trainNumber} • ${trip.trainName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF062056),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isDeparture
                            ? 'Tujuan: ${trip.destinationName} (${trip.destinationCode})'
                            : 'Asal: ${trip.originName} (${trip.originCode})',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TrainStatusBadge(
                            status: trip.dataStatus,
                            delayMinutes: trip.delayMinutes,
                            compact: true,
                          ),
                          if (item.platform != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.platform!,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFC2410C),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvailableTrainsList(List<TrainTripModel> trains) {
    if (trains.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada data kereta melayani stasiun ini saat ini.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: trains.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final trip = trains[i];
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TrainDetailScreen(
                  trip: trip,
                  onTrackOnMap: widget.onTrackTrainOnMap,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(14),
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
                    Expanded(
                      child: Text(
                        '${trip.trainNumber} — ${trip.trainName}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF062056),
                        ),
                      ),
                    ),
                    TrainStatusBadge(
                      status: trip.dataStatus,
                      delayMinutes: trip.delayMinutes,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${trip.originName} (${trip.originCode}) → ${trip.destinationName} (${trip.destinationCode})',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                if (trip.serviceType != null && trip.serviceType!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Layanan: ${trip.serviceType}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF26716),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

