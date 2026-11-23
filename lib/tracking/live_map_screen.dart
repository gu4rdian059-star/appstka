import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../config/app_env.dart';
import '../models/tracking_models.dart';
import '../notifications/notifications_screen.dart';
import '../services/brevo_notification_service.dart';
import '../services/indonesia_time_service.dart';
import '../services/train_tracking_service.dart';
import 'global_search_screen.dart';
import 'station_detail_screen.dart';
import 'train_detail_screen.dart';
import 'widgets/tracking_status_badge.dart';

/// Request fokus kamera dari tab lain (Jadwal / Favorit / Search / Stasiun).
class MapFocusRequest {
  final String? tripId;
  final String? stationCode;
  final int nonce;

  const MapFocusRequest({
    this.tripId,
    this.stationCode,
    required this.nonce,
  });
}

/// A. Live Map Screen — Halaman Utama Aplikasi TKA Mobile.
/// Menggunakan MapLibre GL + MapTiler style dari `.env` + Supabase Realtime.
class LiveMapScreen extends StatefulWidget {
  final ValueNotifier<MapFocusRequest?>? focusRequestNotifier;
  final VoidCallback? onOpenTickets;
  final VoidCallback? onOpenOrders;

  const LiveMapScreen({
    super.key,
    this.focusRequestNotifier,
    this.onOpenTickets,
    this.onOpenOrders,
  });

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  static const LatLng _indonesiaCenter = LatLng(-6.95, 109.45);
  static const double _indonesiaZoom = 5.8;

  static const String _srcRoutes = 'tka-routes-src';
  static const String _srcSelectedRoute = 'tka-selected-route-src';
  static const String _srcStations = 'tka-stations-src';
  static const String _srcTrains = 'tka-trains-src';

  static const String _lyrRoutesCasing = 'tka-routes-casing';
  static const String _lyrRoutesLine = 'tka-routes-line';
  static const String _lyrSelectedRouteLine = 'tka-selected-route-line';
  static const String _lyrStationsCircle = 'tka-stations-circle';
  static const String _lyrStationsLabel = 'tka-stations-label';
  static const String _lyrTrainsHalo = 'tka-trains-halo';
  static const String _lyrTrainsCore = 'tka-trains-core';
  static const String _lyrTrainsLabel = 'tka-trains-label';

  MapLibreMapController? _mapController;
  bool _styleLoaded = false;
  bool _layersAdded = false;

  bool _isLoading = true;
  String? _errorMessage;

  String _selectedRegion = 'Semua Wilayah';
  TrainDataStatus? _statusFilter;
  String? _selectedTripId;
  bool _autoFollowSelected = true;
  bool _showLegend = false;
  int _unreadNotifications = 0;

  bool get _supportsMapLibre =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    TrainTrackingService.tripsNotifier.addListener(_onDataUpdated);
    TrainTrackingService.stationsNotifier.addListener(_onDataUpdated);
    widget.focusRequestNotifier?.addListener(_onExternalFocusRequest);
    _initializeData();
  }

  @override
  void dispose() {
    TrainTrackingService.tripsNotifier.removeListener(_onDataUpdated);
    TrainTrackingService.stationsNotifier.removeListener(_onDataUpdated);
    widget.focusRequestNotifier?.removeListener(_onExternalFocusRequest);
    _mapController?.onFeatureTapped.remove(_onMapFeatureTapped);
    super.dispose();
  }

  Future<void> _initializeData({bool allowDemoFallback = true}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      await TrainTrackingService.loadTrackingData(
        allowDemoFallback: allowDemoFallback,
      );
      await BrevoNotificationService.ensureInitialSeedIfEmpty();
      await _refreshUnreadNotifCount();

      final prefs = TrainTrackingService.preferencesNotifier.value;
      if (mounted) {
        setState(() {
          _autoFollowSelected = prefs.autoFollowTrain;
          _isLoading = false;
          _errorMessage = null;
        });
      }
      await _syncGeoJsonToMap();
      _onExternalFocusRequest();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Gagal memuat data tracking kereta dari Supabase.\nDetail: $e';
        });
      }
    }
  }

  Future<void> _refreshUnreadNotifCount() async {
    try {
      final list = await BrevoNotificationService.getNotifications();
      if (mounted) {
        setState(() {
          _unreadNotifications = list.where((n) => !n.isRead).length;
        });
      }
    } catch (_) {}
  }

  void _onExternalFocusRequest() {
    final req = widget.focusRequestNotifier?.value;
    if (req == null) return;
    if (req.tripId != null) {
      _selectTrip(req.tripId!, animate: true);
    } else if (req.stationCode != null) {
      _focusStationOnMap(req.stationCode!);
    }
  }

  void _onDataUpdated() {
    if (!mounted) return;
    setState(() {});
    _syncGeoJsonToMap();

    // Auto-follow selected train ketika koordinatnya berubah
    if (_autoFollowSelected && _selectedTripId != null) {
      final trip = _findSelectedTrip();
      if (trip != null && trip.hasValidPosition) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(trip.currentLat!, trip.currentLng!)),
          duration: const Duration(milliseconds: 700),
        );
      }
    }
  }

  List<TrainTripModel> get _filteredTrips {
    return TrainTrackingService.tripsNotifier.value.where((t) {
      if (_selectedRegion != 'Semua Wilayah' && t.region != _selectedRegion) {
        return false;
      }
      if (_statusFilter != null && t.dataStatus != _statusFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  List<TrackStationModel> get _filteredStations {
    return TrainTrackingService.stationsNotifier.value.where((s) {
      if (_selectedRegion != 'Semua Wilayah' && s.region != _selectedRegion) {
        return false;
      }
      return true;
    }).toList();
  }

  TrainTripModel? _findSelectedTrip() {
    if (_selectedTripId == null) return null;
    for (final t in TrainTrackingService.tripsNotifier.value) {
      if (t.id == _selectedTripId) return t;
    }
    return null;
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    controller.onFeatureTapped.add(_onMapFeatureTapped);
  }

  Future<void> _onStyleLoaded() async {
    _styleLoaded = true;
    _layersAdded = false;
    await _setupMapLayers();
    await _syncGeoJsonToMap();
  }

  Future<void> _setupMapLayers() async {
    final ctrl = _mapController;
    if (ctrl == null || !_styleLoaded || _layersAdded) return;

    try {
      await ctrl.addGeoJsonSource(_srcRoutes, _emptyFeatureCollection());
      await ctrl.addGeoJsonSource(_srcSelectedRoute, _emptyFeatureCollection());
      await ctrl.addGeoJsonSource(
        _srcStations,
        _emptyFeatureCollection(),
        promoteId: 'id',
      );
      await ctrl.addGeoJsonSource(
        _srcTrains,
        _emptyFeatureCollection(),
        promoteId: 'id',
      );

      // 1. Jalur rel semua kereta (casing putih + garis warna status)
      await ctrl.addLineLayer(
        _srcRoutes,
        _lyrRoutesCasing,
        const LineLayerProperties(
          lineColor: '#FFFFFF',
          lineWidth: 4.5,
          lineOpacity: 0.75,
          lineCap: 'round',
          lineJoin: 'round',
        ),
        enableInteraction: false,
      );

      await ctrl.addLineLayer(
        _srcRoutes,
        _lyrRoutesLine,
        const LineLayerProperties(
          lineColor: [
            'match',
            ['get', 'status'],
            'LIVE',
            '#10B981',
            'DELAYED',
            '#EF4444',
            'SCHEDULED',
            '#2563EB',
            'DEMO',
            '#7C3AED',
            '#64748B',
          ],
          lineWidth: 2.4,
          lineOpacity: 0.75,
          lineCap: 'round',
          lineJoin: 'round',
        ),
        enableInteraction: false,
      );

      // 2. Jalur kereta yang sedang dipilih (tebal & menonjol warna oranye TKA)
      await ctrl.addLineLayer(
        _srcSelectedRoute,
        _lyrSelectedRouteLine,
        const LineLayerProperties(
          lineColor: '#F26716',
          lineWidth: 4.8,
          lineOpacity: 0.95,
          lineCap: 'round',
          lineJoin: 'round',
        ),
        enableInteraction: false,
      );

      // 3. Marker stasiun (lingkaran putih dengan bingkai navy + label kode)
      await ctrl.addCircleLayer(
        _srcStations,
        _lyrStationsCircle,
        const CircleLayerProperties(
          circleRadius: 5.5,
          circleColor: '#FFFFFF',
          circleStrokeColor: '#062056',
          circleStrokeWidth: 2.2,
        ),
        enableInteraction: true,
      );

      await ctrl.addSymbolLayer(
        _srcStations,
        _lyrStationsLabel,
        const SymbolLayerProperties(
          textField: ['get', 'code'],
          textFont: ['Metropolis Semi Bold', 'Noto Sans Semi Bold'],
          textSize: 10.0,
          textOffset: [0, 1.35],
          textColor: '#062056',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 1.4,
          textOptional: true,
        ),
        minzoom: 5.5,
        enableInteraction: true,
      );

      // 4. Marker kereta — visual berbeda untuk LIVE / DELAYED / SCHEDULED / DEMO / UNAVAILABLE
      await ctrl.addCircleLayer(
        _srcTrains,
        _lyrTrainsHalo,
        const CircleLayerProperties(
          circleRadius: [
            'case',
            ['==', ['get', 'selected'], true],
            20.0,
            ['==', ['get', 'status'], 'LIVE'],
            16.5,
            ['==', ['get', 'status'], 'DELAYED'],
            16.5,
            13.5,
          ],
          circleColor: [
            'match',
            ['get', 'status'],
            'LIVE',
            '#10B981',
            'DELAYED',
            '#EF4444',
            'SCHEDULED',
            '#2563EB',
            'DEMO',
            '#7C3AED',
            '#64748B',
          ],
          circleOpacity: 0.25,
        ),
        enableInteraction: true,
      );

      await ctrl.addCircleLayer(
        _srcTrains,
        _lyrTrainsCore,
        const CircleLayerProperties(
          circleRadius: [
            'case',
            ['==', ['get', 'selected'], true],
            10.5,
            8.5,
          ],
          circleColor: [
            'match',
            ['get', 'status'],
            'LIVE',
            '#10B981',
            'DELAYED',
            '#EF4444',
            'SCHEDULED',
            '#2563EB',
            'DEMO',
            '#7C3AED',
            '#64748B',
          ],
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 2.6,
        ),
        enableInteraction: true,
      );

      await ctrl.addSymbolLayer(
        _srcTrains,
        _lyrTrainsLabel,
        const SymbolLayerProperties(
          textField: ['get', 'badge'],
          textFont: ['Metropolis Semi Bold', 'Noto Sans Semi Bold'],
          textSize: 10.5,
          textOffset: [0, -1.75],
          textColor: '#0F172A',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 1.8,
          textAllowOverlap: true,
          textIgnorePlacement: false,
        ),
        enableInteraction: true,
      );

      _layersAdded = true;
    } catch (e) {
      debugPrint('⚠️ Gagal menambahkan layer MapLibre: $e');
    }
  }

  Future<void> _syncGeoJsonToMap() async {
    final ctrl = _mapController;
    if (ctrl == null || !_styleLoaded || !_layersAdded) return;

    final trips = _filteredTrips;
    final stations = _filteredStations;
    final selectedTrip = _findSelectedTrip();

    // GeoJSON Routes
    final routeFeatures = <Map<String, dynamic>>[];
    for (final trip in trips) {
      if (trip.routeGeometry.length < 2) continue;
      routeFeatures.add({
        'type': 'Feature',
        'id': 'route-${trip.id}',
        'geometry': {
          'type': 'LineString',
          'coordinates':
              trip.routeGeometry.map((p) => p.toLngLatJson()).toList(),
        },
        'properties': {
          'id': trip.id,
          'status': trip.dataStatus.code,
        },
      });
    }

    // GeoJSON Selected Route
    final selectedRouteFeatures = <Map<String, dynamic>>[];
    if (selectedTrip != null && selectedTrip.routeGeometry.length >= 2) {
      selectedRouteFeatures.add({
        'type': 'Feature',
        'id': 'sel-${selectedTrip.id}',
        'geometry': {
          'type': 'LineString',
          'coordinates':
              selectedTrip.routeGeometry.map((p) => p.toLngLatJson()).toList(),
        },
        'properties': {'id': selectedTrip.id},
      });
    }

    // GeoJSON Stations
    final stationFeatures = stations.map((s) {
      return {
        'type': 'Feature',
        'id': s.code,
        'geometry': {
          'type': 'Point',
          'coordinates': [s.longitude, s.latitude],
        },
        'properties': {
          'id': s.code,
          'code': s.code,
          'name': s.name,
        },
      };
    }).toList();

    // GeoJSON Trains (hanya yang memiliki koordinat valid; UNAVAILABLE tetap dapat dipilih dari daftar)
    final trainFeatures = <Map<String, dynamic>>[];
    for (final trip in trips) {
      if (!trip.hasValidPosition) continue;
      final tag = trip.dataStatus == TrainDataStatus.delayed &&
              trip.delayMinutes > 0
          ? '${trip.trainNumber} • +${trip.delayMinutes}m'
          : '${trip.trainNumber} • ${trip.dataStatus.code}';
      trainFeatures.add({
        'type': 'Feature',
        'id': trip.id,
        'geometry': {
          'type': 'Point',
          'coordinates': [trip.currentLng!, trip.currentLat!],
        },
        'properties': {
          'id': trip.id,
          'badge': tag,
          'status': trip.dataStatus.code,
          'selected': trip.id == _selectedTripId,
        },
      });
    }

    try {
      await ctrl.setGeoJsonSource(_srcRoutes, {
        'type': 'FeatureCollection',
        'features': routeFeatures,
      });
      await ctrl.setGeoJsonSource(_srcSelectedRoute, {
        'type': 'FeatureCollection',
        'features': selectedRouteFeatures,
      });
      await ctrl.setGeoJsonSource(_srcStations, {
        'type': 'FeatureCollection',
        'features': stationFeatures,
      });
      await ctrl.setGeoJsonSource(_srcTrains, {
        'type': 'FeatureCollection',
        'features': trainFeatures,
      });
    } catch (e) {
      debugPrint('⚠️ Catatan update GeoJSON MapLibre: $e');
    }
  }

  void _onMapFeatureTapped(
    math.Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (layerId == _lyrTrainsCore ||
        layerId == _lyrTrainsHalo ||
        layerId == _lyrTrainsLabel) {
      _selectTrip(id, animate: true);
      return;
    }

    if (layerId == _lyrStationsCircle || layerId == _lyrStationsLabel) {
      final matches = TrainTrackingService.stationsNotifier.value
          .where((s) => s.code == id);
      if (matches.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StationDetailScreen(
              station: matches.first,
              onFocusOnLiveMap: _focusStationOnMap,
              onTrackTrainOnMap: (tripId) => _selectTrip(tripId, animate: true),
            ),
          ),
        );
      }
    }
  }

  void _selectTrip(String tripId, {bool animate = true}) {
    setState(() {
      _selectedTripId = tripId;
      // Pastikan filter wilayah tidak menyembunyikan kereta yang dipilih
      final match = TrainTrackingService.tripsNotifier.value
          .where((t) => t.id == tripId);
      if (match.isNotEmpty &&
          _selectedRegion != 'Semua Wilayah' &&
          match.first.region != _selectedRegion) {
        _selectedRegion = 'Semua Wilayah';
      }
    });
    _syncGeoJsonToMap();

    final trip = _findSelectedTrip();
    if (animate && trip != null) {
      if (trip.hasValidPosition) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(trip.currentLat!, trip.currentLng!),
            9.2,
          ),
          duration: const Duration(milliseconds: 750),
        );
      } else if (trip.routeGeometry.isNotEmpty) {
        final origin = trip.routeGeometry.first;
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(origin.lat, origin.lng), 8.5),
          duration: const Duration(milliseconds: 750),
        );
      }
    }
  }

  void _focusStationOnMap(String stationCode) {
    final matches = TrainTrackingService.stationsNotifier.value
        .where((s) => s.code == stationCode.toUpperCase());
    if (matches.isEmpty) return;
    final st = matches.first;
    setState(() {
      _selectedRegion = 'Semua Wilayah';
    });
    _syncGeoJsonToMap();
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(st.latitude, st.longitude), 13.0),
      duration: const Duration(milliseconds: 750),
    );
  }

  void _selectRegion(String region) {
    setState(() {
      _selectedRegion = region;
    });
    _syncGeoJsonToMap();

    // Fokus kamera ke wilayah yang dipilih
    final CameraPosition target;
    switch (region) {
      case 'Jabodetabek':
        target = const CameraPosition(target: LatLng(-6.28, 106.86), zoom: 10.2);
      case 'Jawa Barat':
        target = const CameraPosition(target: LatLng(-6.82, 107.75), zoom: 8.4);
      case 'Jawa Tengah & DIY':
        target = const CameraPosition(target: LatLng(-7.35, 110.15), zoom: 8.2);
      case 'Jawa Timur':
        target = const CameraPosition(target: LatLng(-7.65, 112.65), zoom: 8.1);
      case 'Sumatera':
        target = const CameraPosition(target: LatLng(-0.85, 102.2), zoom: 5.8);
      default:
        target = const CameraPosition(target: _indonesiaCenter, zoom: _indonesiaZoom);
    }

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(target),
      duration: const Duration(milliseconds: 700),
    );
  }

  void _zoomIn() {
    _mapController?.animateCamera(
      CameraUpdate.zoomIn(),
      duration: const Duration(milliseconds: 280),
    );
  }

  void _zoomOut() {
    _mapController?.animateCamera(
      CameraUpdate.zoomOut(),
      duration: const Duration(milliseconds: 280),
    );
  }

  void _recenterIndonesia() {
    setState(() {
      _selectedRegion = 'Semua Wilayah';
      _statusFilter = null;
    });
    _syncGeoJsonToMap();
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(target: _indonesiaCenter, zoom: _indonesiaZoom),
      ),
      duration: const Duration(milliseconds: 650),
    );
  }

  void _openGlobalSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GlobalSearchScreen(
          onTrackTrainOnMap: (tripId) => _selectTrip(tripId, animate: true),
          onFocusStationOnMap: _focusStationOnMap,
        ),
      ),
    );
  }

  void _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(
          onOpenTickets: widget.onOpenTickets,
          onOpenOrders: widget.onOpenOrders,
        ),
      ),
    );
    _refreshUnreadNotifCount();
  }

  void _openTrainListSheet() {
    final trips = _filteredTrips;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 8),
              child: Row(
                children: [
                  const Icon(Icons.train_rounded, color: Color(0xFF062056)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Daftar Kereta Aktif (${trips.length})',
                      style: const TextStyle(
                        fontSize: 15.5,
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
            ),
            const Divider(height: 1),
            Expanded(
              child: trips.isEmpty
                  ? const Center(
                      child: Text(
                        'Tidak ada kereta pada filter saat ini.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(14),
                      itemCount: trips.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final trip = trips[i];
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: trip.id == _selectedTripId
                                  ? const Color(0xFFF26716)
                                  : const Color(0xFFE2E8F0),
                              width: trip.id == _selectedTripId ? 1.8 : 1,
                            ),
                          ),
                          leading: CircleAvatar(
                            backgroundColor:
                                trip.dataStatus.color.withValues(alpha: 0.14),
                            child: Icon(trip.dataStatus.icon,
                                color: trip.dataStatus.color, size: 18),
                          ),
                          title: Text(
                            '${trip.trainNumber} • ${trip.trainName}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF062056),
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${trip.originCode} → ${trip.destinationCode} • ${trip.region}',
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              const SizedBox(height: 4),
                              TrainStatusBadge(
                                status: trip.dataStatus,
                                delayMinutes: trip.delayMinutes,
                                compact: true,
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.gps_fixed_rounded,
                              size: 18, color: Color(0xFF062056)),
                          onTap: () {
                            Navigator.pop(ctx);
                            _selectTrip(trip.id, animate: true);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _emptyFeatureCollection() => {
        'type': 'FeatureCollection',
        'features': <Map<String, dynamic>>[],
      };

  @override
  Widget build(BuildContext context) {
    final trips = _filteredTrips;
    final selectedTrip = _findSelectedTrip();
    final hasAnySimulated = trips.any(
      (t) => t.isSimulated || t.dataStatus == TrainDataStatus.demo,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFE2E8F0),
      body: Stack(
        children: [
          // ==================== 1. MAPLIBRE GL MAP CANVAS ====================
          Positioned.fill(
            child: _buildMapSurface(),
          ),

          // ==================== 2. TOP OVERLAY (CLOCK, SEARCH, FILTERS) ====================
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Baris atas: Logo + Jam Indonesia Real-Time + Tombol Notif
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF062056),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.train_rounded,
                                  color: Color(0xFFF26716), size: 15),
                              const SizedBox(width: 5),
                              const Text(
                                'TKA Map',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 6),
                              ValueListenableBuilder<bool>(
                                valueListenable:
                                    TrainTrackingService.realtimeConnected,
                                builder: (_, connected, _) => Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: connected
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF7C3AED),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const IndonesiaClockPill(),
                        const Spacer(),
                        // Tombol Notifikasi dengan badge jumlah unread
                        Material(
                          color: Colors.white,
                          elevation: 3,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _openNotifications,
                            child: Padding(
                              padding: const EdgeInsets.all(9),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const Icon(Icons.notifications_outlined,
                                      size: 20, color: Color(0xFF062056)),
                                  if (_unreadNotifications > 0)
                                    Positioned(
                                      top: -4,
                                      right: -4,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFEF4444),
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: const BoxConstraints(
                                            minWidth: 16, minHeight: 16),
                                        child: Text(
                                          _unreadNotifications > 9
                                              ? '9+'
                                              : '$_unreadNotifications',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Search Bar Global
                    Material(
                      color: Colors.white,
                      elevation: 3,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _openGlobalSearch,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          child: Row(
                            children: [
                              const Icon(Icons.search_rounded,
                                  size: 20, color: Color(0xFF062056)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Cari kereta, nomor KA, stasiun, atau rute...',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () =>
                                    setState(() => _showLegend = !_showLegend),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        size: 13,
                                        color: _showLegend
                                            ? const Color(0xFFF26716)
                                            : const Color(0xFF062056),
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Legenda',
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
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Filter Wilayah (Horizontal)
                    SizedBox(
                      height: 32,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: TrainTrackingService.availableRegions.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 6),
                        itemBuilder: (_, i) {
                          final reg = TrainTrackingService.availableRegions[i];
                          final sel = _selectedRegion == reg;
                          return Material(
                            color: sel ? const Color(0xFF062056) : Colors.white,
                            elevation: 2,
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _selectRegion(reg),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                child: Text(
                                  reg,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: sel
                                        ? Colors.white
                                        : const Color(0xFF062056),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Filter Status Data (LIVE / DELAYED / SCHEDULED / DEMO / UNAVAILABLE)
                    SizedBox(
                      height: 28,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _statusFilterPill(null, 'Semua (${TrainTrackingService.tripsNotifier.value.length})'),
                          ...TrainDataStatus.values.map(
                            (st) => _statusFilterPill(st, st.code),
                          ),
                        ],
                      ),
                    ),

                    // Banner Jujur Mode Demo / Simulasi (jika ada data simulasi)
                    if (!_isLoading && _errorMessage == null && hasAnySimulated) ...[
                      const SizedBox(height: 8),
                      DemoDataDisclaimerBanner(
                        customMessage:
                            'Sebagian data berstatus DEMO / SIMULASI (bukan posisi real-time). Marker LIVE hanya aktif dari telemetri GPS nyata.',
                        onRetryLive: () => _initializeData(allowDemoFallback: true),
                      ),
                    ],

                    // Legenda Status Marker (bisa di-toggle)
                    if (_showLegend) ...[
                      const SizedBox(height: 8),
                      _buildStatusLegendCard(),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ==================== 3. FLOATING MAP CONTROLS (KANAN) ====================
          Positioned(
            right: 12,
            bottom: selectedTrip != null ? 226 : 92,
            child: Column(
              children: [
                _mapControlBtn(
                  icon: Icons.add_rounded,
                  tooltip: 'Perbesar (Zoom In)',
                  onTap: _zoomIn,
                ),
                const SizedBox(height: 6),
                _mapControlBtn(
                  icon: Icons.remove_rounded,
                  tooltip: 'Perkecil (Zoom Out)',
                  onTap: _zoomOut,
                ),
                const SizedBox(height: 6),
                _mapControlBtn(
                  icon: Icons.public_rounded,
                  tooltip: 'Reset Peta Indonesia',
                  onTap: _recenterIndonesia,
                ),
                const SizedBox(height: 6),
                _mapControlBtn(
                  icon: _autoFollowSelected
                      ? Icons.gps_fixed_rounded
                      : Icons.gps_not_fixed_rounded,
                  tooltip: _autoFollowSelected
                      ? 'Auto-Follow Kereta: AKTIF'
                      : 'Auto-Follow Kereta: NONAKTIF',
                  active: _autoFollowSelected,
                  onTap: () {
                    setState(() => _autoFollowSelected = !_autoFollowSelected);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _autoFollowSelected
                              ? 'Auto-Follow kereta terpilih diaktifkan.'
                              : 'Auto-Follow kereta dimatikan.',
                        ),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                ValueListenableBuilder<bool>(
                  valueListenable: TrainTrackingService.demoMovementRunning,
                  builder: (_, running, _) => _mapControlBtn(
                    icon: running
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    tooltip: running
                        ? 'Hentikan Simulasi Gerak Demo'
                        : 'Jalankan Simulasi Gerak Demo (Bukan Real-Time)',
                    active: running,
                    activeColor: const Color(0xFF7C3AED),
                    onTap: () {
                      TrainTrackingService.setDemoMovementEnabled(!running);
                    },
                  ),
                ),
                const SizedBox(height: 6),
                _mapControlBtn(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Muat Ulang Data Supabase',
                  onTap: () => _initializeData(allowDemoFallback: true),
                ),
              ],
            ),
          ),

          // ==================== 4. TOMBOL DAFTAR KERETA (KIRI BAWAH) ====================
          if (selectedTrip == null && !_isLoading && _errorMessage == null)
            Positioned(
              left: 12,
              bottom: 16,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF062056),
                  foregroundColor: Colors.white,
                  elevation: 4,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _openTrainListSheet,
                icon: const Icon(Icons.format_list_bulleted_rounded, size: 18),
                label: Text(
                  'Daftar Kereta (${trips.length})',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
              ),
            ),

          // ==================== 5. BOTTOM CARD DETAIL KERETA SAAT MARKER DIKLIK ====================
          if (selectedTrip != null && !_isLoading && _errorMessage == null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _buildSelectedTrainCard(selectedTrip),
            ),

          // ==================== 6. LOADING / ERROR / EMPTY STATES ====================
          if (_isLoading) _buildLoadingOverlay(),
          if (!_isLoading && _errorMessage != null) _buildErrorOverlay(),
          if (!_isLoading && _errorMessage == null && trips.isEmpty)
            _buildEmptyStateCard(),
        ],
      ),
    );
  }

  Widget _buildMapSurface() {
    if (!_supportsMapLibre) {
      return Container(
        color: const Color(0xFFE2E8F0),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.map_rounded,
                      size: 48, color: Color(0xFF062056)),
                  const SizedBox(height: 10),
                  const Text(
                    'MapLibre GL aktif di Android, iOS, & Chrome Web',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Color(0xFF062056)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Jalankan dengan `flutter run -d chrome` atau perangkat Android/iOS untuk melihat peta vektor interaktif MapTiler.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!AppEnv.hasMapTilerConfig) {
      return Container(
        color: const Color(0xFFE2E8F0),
        child: const Center(
          child: Text(
            'MAPTILER_STYLE_URL belum diatur di file .env',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
        ),
      );
    }

    return MapLibreMap(
      styleString: AppEnv.mapTilerStyleUrl,
      initialCameraPosition: const CameraPosition(
        target: _indonesiaCenter,
        zoom: _indonesiaZoom,
      ),
      minMaxZoomPreference: const MinMaxZoomPreference(4.0, 17.5),
      onMapCreated: _onMapCreated,
      onStyleLoadedCallback: _onStyleLoaded,
      onMapClick: (_, _) {
        if (_selectedTripId != null) {
          setState(() => _selectedTripId = null);
          _syncGeoJsonToMap();
        }
      },
      compassEnabled: true,
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      tiltGesturesEnabled: true,
      trackCameraPosition: true,
    );
  }

  Widget _statusFilterPill(TrainDataStatus? status, String label) {
    final sel = _statusFilter == status;
    final color = status?.color ?? const Color(0xFF062056);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: sel ? color : Colors.white.withValues(alpha: 0.94),
        elevation: 1.5,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() => _statusFilter = status);
            _syncGeoJsonToMap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status != null) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: sel ? Colors.white : status.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: sel ? Colors.white : color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusLegendCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Legenda Status Data Marker Kereta',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF062056),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: TrainDataStatus.values.map((st) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: st.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${st.code}: ${st.description}',
                    style: const TextStyle(fontSize: 10.5),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _mapControlBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool active = false,
    Color activeColor = const Color(0xFFF26716),
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? activeColor : Colors.white,
        elevation: 3,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 20,
              color: active ? Colors.white : const Color(0xFF062056),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTrainCard(TrainTripModel trip) {
    final eta = trip.computedEta;
    final isFav = TrainTrackingService.isTripFavorite(trip);

    return Material(
      color: Colors.white,
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: trip.dataStatus.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.train_rounded,
                      color: trip.dataStatus.color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${trip.trainNumber} • ${trip.trainName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF062056),
                        ),
                      ),
                      Text(
                        '${trip.originName} (${trip.originCode}) → ${trip.destinationName} (${trip.destinationCode})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: isFav ? 'Hapus Favorit' : 'Simpan Favorit',
                  icon: Icon(
                    isFav
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFav ? const Color(0xFFF26716) : Colors.grey,
                    size: 20,
                  ),
                  onPressed: () async {
                    await TrainTrackingService.toggleFavorite(trip);
                    if (mounted) setState(() {});
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 19),
                  onPressed: () {
                    setState(() => _selectedTripId = null);
                    _syncGeoJsonToMap();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TrainStatusBadge(
                  status: trip.dataStatus,
                  delayMinutes: trip.delayMinutes,
                  compact: true,
                ),
                Text(
                  trip.speedKmh != null
                      ? 'Kecepatan: ${trip.speedKmh!.toStringAsFixed(0)} km/j'
                      : 'Kecepatan: -',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155)),
                ),
                Text(
                  'ETA: ${eta != null ? IndonesiaTimeService.formatTime(eta) : 'Tidak tersedia'}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF26716)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${trip.tripStatus} • Update: ${IndonesiaTimeService.formatRelative(trip.lastUpdatedAt)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF062056),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      setState(() => _autoFollowSelected = !_autoFollowSelected);
                    },
                    icon: Icon(
                      _autoFollowSelected
                          ? Icons.gps_fixed_rounded
                          : Icons.gps_not_fixed_rounded,
                      size: 16,
                      color: _autoFollowSelected
                          ? const Color(0xFFF26716)
                          : const Color(0xFF062056),
                    ),
                    label: Text(
                      _autoFollowSelected ? 'Auto-Follow ON' : 'Auto-Follow OFF',
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF062056),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TrainDetailScreen(
                            trip: trip,
                            onTrackOnMap: (id) =>
                                _selectTrip(id, animate: true),
                            onFocusStationOnMap: _focusStationOnMap,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.info_outline_rounded, size: 16),
                    label: const Text(
                      'Detail Lengkap',
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.bold),
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

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.white.withValues(alpha: 0.72),
        child: const Center(
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFFF26716)),
                  SizedBox(height: 14),
                  Text(
                    'Memuat Peta & Data Kereta Indonesia...',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF062056),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.35),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Card(
            elevation: 8,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      size: 46, color: Color(0xFFEF4444)),
                  const SizedBox(height: 12),
                  const Text(
                    'Gagal Memuat Data Tracking',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF062056),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _errorMessage ?? 'Terjadi kesalahan koneksi jaringan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF062056),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () =>
                            _initializeData(allowDemoFallback: false),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Coba Lagi'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          TrainTrackingService.loadDemoDatasetExplicitly();
                          setState(() => _errorMessage = null);
                          _syncGeoJsonToMap();
                        },
                        icon: const Icon(Icons.science_rounded, size: 16),
                        label: const Text('Mode Demo'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 84,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.train_outlined,
                  size: 36, color: Color(0xFF64748B)),
              const SizedBox(height: 8),
              const Text(
                'Tidak Ada Kereta yang Ditampilkan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF062056),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _selectedRegion != 'Semua Wilayah' || _statusFilter != null
                    ? 'Tidak ada kereta yang cocok dengan filter wilayah/status saat ini.'
                    : 'Belum ada data perjalanan kereta di Supabase.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF062056),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedRegion = 'Semua Wilayah';
                        _statusFilter = null;
                      });
                      _initializeData(allowDemoFallback: true);
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Reset & Muat Ulang'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      TrainTrackingService.loadDemoDatasetExplicitly();
                      setState(() {
                        _selectedRegion = 'Semua Wilayah';
                        _statusFilter = null;
                      });
                      _syncGeoJsonToMap();
                    },
                    icon: const Icon(Icons.science_rounded, size: 16),
                    label: const Text('Muat Data Demo'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

