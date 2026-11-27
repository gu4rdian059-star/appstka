import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../config/app_env.dart';
import '../intercity/antar_kota_screen.dart';
import '../models/tracking_models.dart';
import '../services/indonesia_time_service.dart';
import '../services/user_db_service.dart';
import 'widgets/tracking_status_badge.dart';

class LiveTrackingScreen extends StatefulWidget {
  final String? trainName;
  final String? trainNumber;
  final String? origin;
  final String? destination;
  final String? departureTime;
  final String? arrivalTime;
  final BookingModel? booking;

  const LiveTrackingScreen({
    super.key,
    this.trainName,
    this.trainNumber,
    this.origin,
    this.destination,
    this.departureTime,
    this.arrivalTime,
    this.booking,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  static const String _routeSourceId = 'ticket-route-source';
  static const String _passedRouteSourceId = 'ticket-passed-route-source';
  static const String _stationsSourceId = 'ticket-stations-source';
  static const String _trainSourceId = 'ticket-train-source';

  static const String _routeCasingLayerId = 'ticket-route-casing-layer';
  static const String _routeLineLayerId = 'ticket-route-line-layer';
  static const String _passedRouteLayerId = 'ticket-passed-route-layer';
  static const String _stationsCircleLayerId = 'ticket-stations-circle-layer';
  static const String _stationsLabelLayerId = 'ticket-stations-label-layer';
  static const String _trainHaloLayerId = 'ticket-train-halo-layer';
  static const String _trainCircleLayerId = 'ticket-train-circle-layer';
  static const String _trainLabelLayerId = 'ticket-train-label-layer';

  // Koordinat nyata stasiun-stasiun kereta api di Indonesia
  static const Map<String, LatLng> _stationCoordinates = {
    'GMR': LatLng(-6.1766, 106.8306), // Gambir
    'PSE': LatLng(-6.1747, 106.8444), // Pasar Senen
    'JNG': LatLng(-6.2153, 106.8706), // Jatinegara
    'MRI': LatLng(-6.2099, 106.8502), // Manggarai
    'JAKK': LatLng(-6.1376, 106.8146), // Jakarta Kota
    'THB': LatLng(-6.1857, 106.8108), // Tanah Abang
    'BKS': LatLng(-6.2361, 106.9995), // Bekasi
    'BOO': LatLng(-6.5956, 106.7905), // Bogor
    'CKR': LatLng(-6.2555, 107.1453), // Cikarang
    'KW': LatLng(-6.3052, 107.3001), // Karawang
    'CKP': LatLng(-6.4063, 107.4589), // Cikampek
    'PWK': LatLng(-6.5529, 107.4472), // Purwakarta
    'CMI': LatLng(-6.8858, 107.5364), // Cimahi
    'BD': LatLng(-6.9126, 107.6024), // Bandung
    'KAC': LatLng(-6.9250, 107.6464), // Kiaracondong
    'CPD': LatLng(-7.0984, 108.1173), // Cipeundeuy
    'TSM': LatLng(-7.3235, 108.2241), // Tasikmalaya
    'BJG': LatLng(-7.3452, 108.5326), // Banjar
    'CN': LatLng(-6.7058, 108.5554), // Cirebon Kejaksan
    'CNP': LatLng(-6.7128, 108.5639), // Cirebon Prujakan
    'TG': LatLng(-6.8673, 109.1428), // Tegal
    'PML': LatLng(-6.8878, 109.3804), // Pemalang
    'PK': LatLng(-6.8898, 109.6644), // Pekalongan
    'WLR': LatLng(-6.9702, 110.0706), // Weleri
    'SMT': LatLng(-6.9644, 110.4278), // Semarang Tawang
    'SMC': LatLng(-6.9731, 110.4150), // Semarang Poncol
    'NBO': LatLng(-7.0945, 110.9098), // Ngrombo
    'CU': LatLng(-7.1528, 111.5908), // Cepu
    'BJN': LatLng(-7.1636, 111.8869), // Bojonegoro
    'LMG': LatLng(-7.1167, 112.4186), // Lamongan
    'SBI': LatLng(-7.2492, 112.7308), // Surabaya Pasarturi
    'SGU': LatLng(-7.2654, 112.7519), // Surabaya Gubeng
    'WO': LatLng(-7.3025, 112.7385), // Wonokromo
    'SDA': LatLng(-7.4569, 112.7136), // Sidoarjo
    'BG': LatLng(-7.5994, 112.7830), // Bangil
    'PS': LatLng(-7.6383, 112.9078), // Pasuruan
    'PB': LatLng(-7.7433, 113.2155), // Probolinggo
    'JR': LatLng(-8.1656, 113.7031), // Jember
    'KTG': LatLng(-8.1404, 114.3983), // Ketapang Banyuwangi
    'LW': LatLng(-7.8359, 112.6978), // Lawang
    'ML': LatLng(-7.9774, 112.6370), // Malang Kota Baru
    'MLK': LatLng(-7.9949, 112.6311), // Malang Kotalama
    'KPN': LatLng(-8.1322, 112.5728), // Kepanjen
    'BL': LatLng(-8.1014, 112.1628), // Blitar
    'TA': LatLng(-8.0642, 111.9056), // Tulungagung
    'KD': LatLng(-7.8172, 112.0153), // Kediri
    'KTS': LatLng(-7.5917, 112.1003), // Kertosono
    'NJ': LatLng(-7.6003, 111.9036), // Nganjuk
    'MN': LatLng(-7.6186, 111.5239), // Madiun
    'NGW': LatLng(-7.4408, 111.3803), // Ngawi
    'SR': LatLng(-7.4278, 111.0189), // Sragen
    'SLO': LatLng(-7.5572, 110.8214), // Solo Balapan
    'PWS': LatLng(-7.5628, 110.7933), // Purwosari
    'KT': LatLng(-7.7128, 110.6033), // Klaten
    'LPN': LatLng(-7.7903, 110.3753), // Lempuyangan
    'YK': LatLng(-7.7892, 110.3636), // Yogyakarta Tugu
    'WT': LatLng(-7.8586, 110.1583), // Wates
    'KTA': LatLng(-7.7258, 109.9078), // Kutoarjo
    'KM': LatLng(-7.6808, 109.6622), // Kebumen
    'GB': LatLng(-7.6078, 109.5122), // Gombong
    'KYA': LatLng(-7.6308, 109.2533), // Kroya
    'PWT': LatLng(-7.4192, 109.2219), // Purwokerto
    'BMA': LatLng(-7.2564, 109.0078), // Bumiayu
    'PPK': LatLng(-7.1239, 108.9728), // Prupuk
    'MDN': LatLng(3.5912, 98.6775), // Medan
    'KNM': LatLng(3.6422, 98.8783), // Bandara Kualanamu
    'KPT': LatLng(-3.0049, 104.7495), // Kertapati Palembang
    'TNK': LatLng(-5.4094, 105.2581), // Tanjung Karang Lampung
  };

  MapLibreMapController? _mapController;
  bool _mapReadyToMount = false;
  bool _mapStyleLoaded = false;
  bool _mapLoadError = false;
  String? _mapErrorMessage;
  bool _autoFollow = false;

  Timer? _movementTimer;
  Timer? _mountMapTimer;
  IndonesiaTimezone _timezone = IndonesiaTimeService.currentTimezone.value;

  // Progress perjalanan kereta di sepanjang rute (0.0 -> 1.0)
  double _trainProgress = 0.42;
  int _currentSpeed = 104;
  final int _delayMinutes = 0;
  final TrainDataStatus _trackingStatus = TrainDataStatus.live;

  // Daftar tiket aktif dari database
  List<BookingModel> _activeTickets = [];
  BookingModel? _selectedBooking;
  bool _isLoadingTickets = true;

  // Rute stasiun pemberhentian dari tiket yang dipilih
  List<Map<String, dynamic>> _stations = [];

  // Popup info ketika marker di peta diklik
  Map<String, dynamic>? _selectedMapPopup;

  String get _activeTrainName =>
      _selectedBooking?.trainName ??
      widget.trainName ??
      'KA Argo Bromo Anggrek';

  String get _activeTrainNumber {
    if (widget.trainNumber != null && widget.trainNumber!.trim().isNotEmpty) {
      return widget.trainNumber!;
    }
    final name = _activeTrainName;
    final match = RegExp(r'\((\d+[A-Z]?)\)').firstMatch(name);
    if (match != null) return 'KA-${match.group(1)}';
    final numMatch = RegExp(r'KA\s*(\d+)').firstMatch(name);
    if (numMatch != null) return 'KA-${numMatch.group(1)}';
    return 'KA-02';
  }

  String get _activeOriginName =>
      _selectedBooking != null
          ? '${_selectedBooking!.originName} (${_selectedBooking!.originCode})'
          : (widget.origin ?? 'Gambir (GMR)');

  String get _activeDestName =>
      _selectedBooking != null
          ? '${_selectedBooking!.destName} (${_selectedBooking!.destCode})'
          : (widget.destination ?? 'Surabaya Pasarturi (SBI)');

  String get _activeDepartureTime =>
      _selectedBooking?.departureTime ?? widget.departureTime ?? '08:20';

  String get _activeArrivalTime =>
      _selectedBooking?.arrivalTime ?? widget.arrivalTime ?? '18:50';

  @override
  void initState() {
    super.initState();
    // Langsung bangun rute awal dari widget props / cache agar layar tidak kosong di frame 0
    _rebuildRouteStations();
    _initTicketAndRoute();

    // Tunda mount MapLibre WebGL hingga animasi transisi halaman selesai (~180ms)
    // agar klik tombol Live Tracking terasa instan & bebas lag!
    _mountMapTimer = Timer(const Duration(milliseconds: 180), () {
      if (mounted) {
        setState(() => _mapReadyToMount = true);
      }
    });

    // Pergerakan posisi kereta setiap 5 detik (hemat CPU/GPU & hanya update layer dinamis)
    _movementTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _stations.length < 2) return;
      setState(() {
        _trainProgress += 0.006;
        if (_trainProgress > 0.96) _trainProgress = 0.14;
        _currentSpeed = 96 + (DateTime.now().second % 19);
        _refreshStationStopStatuses();
      });
      _syncMapGeoJson(
        updateStaticSources: false,
        followCamera: _autoFollow,
      );
    });
  }

  Future<void> _initTicketAndRoute() async {
    // Tampilkan data dari cache memori terlebih dahulu secara instan (0ms)
    final cached = UserDatabaseService.getCachedBookings()
        .where((b) => b.status == 'Sudah Dibayar')
        .toList();
    if (cached.isNotEmpty) {
      _applyLoadedBookings(cached);
    }

    final bookings = await UserDatabaseService.getBookings(
      statusFilter: 'Sudah Dibayar',
    );
    if (!mounted) return;
    _applyLoadedBookings(bookings);

    if (_mapStyleLoaded) {
      await _syncMapGeoJson(updateStaticSources: true, fitRouteBounds: true);
    }
  }

  void _applyLoadedBookings(List<BookingModel> bookings) {
    setState(() {
      _activeTickets = bookings;
      if (widget.booking != null) {
        _selectedBooking = widget.booking;
      } else if (widget.trainName != null) {
        final match = bookings.where((b) => b.trainName == widget.trainName);
        if (match.isNotEmpty) {
          _selectedBooking = match.first;
        } else if (bookings.isNotEmpty) {
          _selectedBooking = null;
        }
      } else if (bookings.isNotEmpty) {
        _selectedBooking = bookings.first;
      }
      _isLoadingTickets = false;
      _rebuildRouteStations();
    });
  }

  void _selectBookedTicket(BookingModel booking) {
    setState(() {
      _selectedBooking = booking;
      _selectedMapPopup = null;
      _rebuildRouteStations();
    });
    _syncMapGeoJson(fitRouteBounds: true);
  }

  String _extractStationCode(String raw, String fallback) {
    final match = RegExp(r'\(([A-Z]{2,4})\)').firstMatch(raw);
    if (match != null) return match.group(1)!;
    final upper = raw.trim().toUpperCase();
    if (_stationCoordinates.containsKey(upper)) return upper;
    for (final entry in _stationCoordinates.keys) {
      if (upper.contains(entry)) return entry;
    }
    return fallback;
  }

  void _rebuildRouteStations() {
    final originCode = _selectedBooking?.originCode ??
        _extractStationCode(widget.origin ?? 'Gambir (GMR)', 'GMR');
    final destCode = _selectedBooking?.destCode ??
        _extractStationCode(
          widget.destination ?? 'Surabaya Pasarturi (SBI)',
          'SBI',
        );

    final originName = _selectedBooking != null
        ? '${_selectedBooking!.originName} (${_selectedBooking!.originCode})'
        : (widget.origin ?? 'Gambir (GMR)');
    final destName = _selectedBooking != null
        ? '${_selectedBooking!.destName} (${_selectedBooking!.destCode})'
        : (widget.destination ?? 'Surabaya Pasarturi (SBI)');

    final dep = _activeDepartureTime;
    final arr = _activeArrivalTime;

    List<Map<String, dynamic>> rawStops;

    if (originCode == 'GMR' && (destCode == 'BD' || destCode == 'KAC')) {
      rawStops = [
        {'code': originCode, 'name': originName, 'city': 'Jakarta Pusat', 'time': dep, 'platform': 'Jalur 3', 'pos': 0.0},
        {'code': 'BKS', 'name': 'Bekasi (BKS)', 'city': 'Bekasi', 'time': _addTime(dep, 0, 32), 'platform': 'Jalur 2', 'pos': 0.25},
        {'code': 'PWK', 'name': 'Purwakarta (PWK)', 'city': 'Purwakarta', 'time': _addTime(dep, 1, 25), 'platform': 'Jalur 1', 'pos': 0.55},
        {'code': 'CMI', 'name': 'Cimahi (CMI)', 'city': 'Cimahi', 'time': _addTime(dep, 2, 25), 'platform': 'Jalur 2', 'pos': 0.85},
        {'code': destCode, 'name': destName, 'city': 'Bandung', 'time': arr, 'platform': 'Jalur 1', 'pos': 1.0},
      ];
    } else if ((originCode == 'BD' || originCode == 'KAC') &&
        originCode != destCode &&
        destCode == 'GMR') {
      rawStops = [
        {'code': originCode, 'name': originName, 'city': 'Bandung', 'time': dep, 'platform': 'Jalur 1', 'pos': 0.0},
        {'code': 'CMI', 'name': 'Cimahi (CMI)', 'city': 'Cimahi', 'time': _addTime(dep, 0, 22), 'platform': 'Jalur 2', 'pos': 0.22},
        {'code': 'PWK', 'name': 'Purwakarta (PWK)', 'city': 'Purwakarta', 'time': _addTime(dep, 1, 20), 'platform': 'Jalur 1', 'pos': 0.52},
        {'code': 'JNG', 'name': 'Jatinegara (JNG)', 'city': 'Jakarta Timur', 'time': _addTime(dep, 2, 25), 'platform': 'Jalur 3', 'pos': 0.84},
        {'code': destCode, 'name': destName, 'city': 'Jakarta Pusat', 'time': arr, 'platform': 'Jalur 2', 'pos': 1.0},
      ];
    } else if ((originCode == 'GMR' || originCode == 'PSE') &&
        (destCode == 'YK' || destCode == 'LPN' || destCode == 'SLO')) {
      rawStops = [
        {'code': originCode, 'name': originName, 'city': 'Jakarta Pusat', 'time': dep, 'platform': 'Jalur 2', 'pos': 0.0},
        {'code': 'CN', 'name': 'Cirebon Kejaksan (CN)', 'city': 'Cirebon', 'time': _addTime(dep, 2, 35), 'platform': 'Jalur 1', 'pos': 0.34},
        {'code': 'PWT', 'name': 'Purwokerto (PWT)', 'city': 'Banyumas', 'time': _addTime(dep, 4, 25), 'platform': 'Jalur 2', 'pos': 0.62},
        {'code': 'KTA', 'name': 'Kutoarjo (KTA)', 'city': 'Purworejo', 'time': _addTime(dep, 5, 45), 'platform': 'Jalur 1', 'pos': 0.82},
        {'code': destCode, 'name': destName, 'city': destCode == 'SLO' ? 'Surakarta' : 'Yogyakarta', 'time': arr, 'platform': 'Jalur 3', 'pos': 1.0},
      ];
    } else if ((originCode == 'YK' || originCode == 'LPN' || originCode == 'SLO') &&
        (destCode == 'GMR' || destCode == 'PSE')) {
      rawStops = [
        {'code': originCode, 'name': originName, 'city': originCode == 'SLO' ? 'Surakarta' : 'Yogyakarta', 'time': dep, 'platform': 'Jalur 2', 'pos': 0.0},
        {'code': 'KTA', 'name': 'Kutoarjo (KTA)', 'city': 'Purworejo', 'time': _addTime(dep, 0, 55), 'platform': 'Jalur 1', 'pos': 0.22},
        {'code': 'PWT', 'name': 'Purwokerto (PWT)', 'city': 'Banyumas', 'time': _addTime(dep, 2, 30), 'platform': 'Jalur 2', 'pos': 0.48},
        {'code': 'CN', 'name': 'Cirebon Kejaksan (CN)', 'city': 'Cirebon', 'time': _addTime(dep, 4, 20), 'platform': 'Jalur 1', 'pos': 0.74},
        {'code': destCode, 'name': destName, 'city': 'Jakarta Pusat', 'time': arr, 'platform': 'Jalur 3', 'pos': 1.0},
      ];
    } else if ((originCode == 'GMR' || originCode == 'PSE') &&
        (destCode == 'SBI' || destCode == 'SGU')) {
      rawStops = [
        {'code': originCode, 'name': originName, 'city': 'Jakarta Pusat', 'time': dep, 'platform': 'Jalur 4', 'pos': 0.0},
        {'code': 'CN', 'name': 'Cirebon Kejaksan (CN)', 'city': 'Cirebon', 'time': _addTime(dep, 2, 30), 'platform': 'Jalur 1', 'pos': 0.25},
        {'code': 'PK', 'name': 'Pekalongan (PK)', 'city': 'Pekalongan', 'time': _addTime(dep, 4, 10), 'platform': 'Jalur 2', 'pos': 0.44},
        {'code': 'SMT', 'name': 'Semarang Tawang (SMT)', 'city': 'Semarang', 'time': _addTime(dep, 5, 25), 'platform': 'Jalur 1', 'pos': 0.62},
        {'code': 'BJN', 'name': 'Bojonegoro (BJN)', 'city': 'Bojonegoro', 'time': _addTime(dep, 7, 30), 'platform': 'Jalur 2', 'pos': 0.83},
        {'code': destCode, 'name': destName, 'city': 'Surabaya', 'time': arr, 'platform': 'Jalur 2', 'pos': 1.0},
      ];
    } else if ((originCode == 'GMR' || originCode == 'PSE') &&
        (destCode == 'ML' || destCode == 'MLK')) {
      rawStops = [
        {'code': originCode, 'name': originName, 'city': 'Jakarta Pusat', 'time': dep, 'platform': 'Jalur 2', 'pos': 0.0},
        {'code': 'CN', 'name': 'Cirebon Kejaksan (CN)', 'city': 'Cirebon', 'time': _addTime(dep, 2, 40), 'platform': 'Jalur 1', 'pos': 0.24},
        {'code': 'PWT', 'name': 'Purwokerto (PWT)', 'city': 'Banyumas', 'time': _addTime(dep, 4, 30), 'platform': 'Jalur 2', 'pos': 0.45},
        {'code': 'MN', 'name': 'Madiun (MN)', 'city': 'Madiun', 'time': _addTime(dep, 7, 40), 'platform': 'Jalur 1', 'pos': 0.72},
        {'code': 'KD', 'name': 'Kediri (KD)', 'city': 'Kediri', 'time': _addTime(dep, 9, 10), 'platform': 'Jalur 2', 'pos': 0.86},
        {'code': destCode, 'name': destName, 'city': 'Malang', 'time': arr, 'platform': 'Jalur 1', 'pos': 1.0},
      ];
    } else if ((originCode == 'SGU' || originCode == 'SBI') &&
        (destCode == 'ML' || destCode == 'MLK')) {
      rawStops = [
        {'code': originCode, 'name': originName, 'city': 'Surabaya', 'time': dep, 'platform': 'Jalur 2', 'pos': 0.0},
        {'code': 'WO', 'name': 'Wonokromo (WO)', 'city': 'Surabaya', 'time': _addTime(dep, 0, 12), 'platform': 'Jalur 1', 'pos': 0.16},
        {'code': 'SDA', 'name': 'Sidoarjo (SDA)', 'city': 'Sidoarjo', 'time': _addTime(dep, 0, 32), 'platform': 'Jalur 2', 'pos': 0.36},
        {'code': 'BG', 'name': 'Bangil (BG)', 'city': 'Pasuruan', 'time': _addTime(dep, 0, 58), 'platform': 'Jalur 1', 'pos': 0.60},
        {'code': 'LW', 'name': 'Lawang (LW)', 'city': 'Malang', 'time': _addTime(dep, 1, 35), 'platform': 'Jalur 2', 'pos': 0.82},
        {'code': destCode, 'name': destName, 'city': 'Malang', 'time': arr, 'platform': 'Jalur 1', 'pos': 1.0},
      ];
    } else if ((originCode == 'ML' || originCode == 'MLK') &&
        (destCode == 'SGU' || destCode == 'SBI')) {
      rawStops = [
        {'code': originCode, 'name': originName, 'city': 'Malang', 'time': dep, 'platform': 'Jalur 1', 'pos': 0.0},
        {'code': 'LW', 'name': 'Lawang (LW)', 'city': 'Malang', 'time': _addTime(dep, 0, 24), 'platform': 'Jalur 2', 'pos': 0.22},
        {'code': 'BG', 'name': 'Bangil (BG)', 'city': 'Pasuruan', 'time': _addTime(dep, 1, 00), 'platform': 'Jalur 1', 'pos': 0.50},
        {'code': 'SDA', 'name': 'Sidoarjo (SDA)', 'city': 'Sidoarjo', 'time': _addTime(dep, 1, 26), 'platform': 'Jalur 2', 'pos': 0.74},
        {'code': destCode, 'name': destName, 'city': 'Surabaya', 'time': arr, 'platform': 'Jalur 2', 'pos': 1.0},
      ];
    } else if ((originCode == 'BD' || originCode == 'KAC') &&
        (destCode == 'YK' || destCode == 'SLO' || destCode == 'SGU')) {
      rawStops = [
        {'code': originCode, 'name': originName, 'city': 'Bandung', 'time': dep, 'platform': 'Jalur 2', 'pos': 0.0},
        {'code': 'TSM', 'name': 'Tasikmalaya (TSM)', 'city': 'Tasikmalaya', 'time': _addTime(dep, 2, 30), 'platform': 'Jalur 1', 'pos': 0.26},
        {'code': 'KYA', 'name': 'Kroya (KYA)', 'city': 'Cilacap', 'time': _addTime(dep, 4, 45), 'platform': 'Jalur 2', 'pos': 0.54},
        {'code': 'YK', 'name': 'Yogyakarta (YK)', 'city': 'Yogyakarta', 'time': destCode == 'YK' ? arr : _addTime(dep, 6, 40), 'platform': 'Jalur 2', 'pos': destCode == 'YK' ? 1.0 : 0.76},
        if (destCode != 'YK')
          {'code': destCode, 'name': destName, 'city': destCode == 'SLO' ? 'Surakarta' : 'Surabaya', 'time': arr, 'platform': 'Jalur 1', 'pos': 1.0},
      ];
    } else {
      // Fallback rute dinamis berdasarkan stasiun asal & tujuan tiket
      final originLatLng =
          _stationCoordinates[originCode] ?? const LatLng(-6.1766, 106.8306);
      final destLatLng =
          _stationCoordinates[destCode] ?? const LatLng(-7.2492, 112.7308);

      final midStops = <Map<String, dynamic>>[];
      final candidates = ['CN', 'PWT', 'SMT', 'YK', 'SLO', 'MN', 'BJN'];
      for (final c in candidates) {
        if (c == originCode || c == destCode) continue;
        final pt = _stationCoordinates[c]!;
        final minLng = math.min(originLatLng.longitude, destLatLng.longitude);
        final maxLng = math.max(originLatLng.longitude, destLatLng.longitude);
        if (pt.longitude > minLng + 0.35 && pt.longitude < maxLng - 0.35) {
          midStops.add({
            'code': c,
            'name': '$c Station ($c)',
            'city': 'Stasiun Transit',
            'lng': pt.longitude,
          });
        }
      }
      midStops.sort((a, b) {
        final goingEast = destLatLng.longitude >= originLatLng.longitude;
        final cmp = (a['lng'] as double).compareTo(b['lng'] as double);
        return goingEast ? cmp : -cmp;
      });
      final selectedMids = midStops.take(3).toList();

      rawStops = [
        {
          'code': originCode,
          'name': originName,
          'city': _selectedBooking?.originName ?? 'Stasiun Asal',
          'time': dep,
          'platform': 'Jalur 1',
          'pos': 0.0,
        },
        for (int i = 0; i < selectedMids.length; i++)
          {
            'code': selectedMids[i]['code'],
            'name': _stationDisplayName(selectedMids[i]['code'] as String),
            'city': _stationCityName(selectedMids[i]['code'] as String),
            'time': _addTime(dep, (i + 1) * 2, 15),
            'platform': 'Jalur ${(i % 2) + 1}',
            'pos': (i + 1) / (selectedMids.length + 1),
          },
        {
          'code': destCode,
          'name': destName,
          'city': _selectedBooking?.destName ?? 'Stasiun Tujuan',
          'time': arr,
          'platform': 'Jalur 2',
          'pos': 1.0,
        },
      ];
    }

    final originFallback =
        _stationCoordinates[originCode] ?? const LatLng(-6.1766, 106.8306);
    final destFallback =
        _stationCoordinates[destCode] ?? const LatLng(-7.2492, 112.7308);

    _stations = List.generate(rawStops.length, (i) {
      final item = Map<String, dynamic>.from(rawStops[i]);
      final code = item['code'] as String;
      final progress = (item['pos'] as num).toDouble();
      final coord = _stationCoordinates[code] ??
          LatLng(
            originFallback.latitude +
                (destFallback.latitude - originFallback.latitude) * progress,
            originFallback.longitude +
                (destFallback.longitude - originFallback.longitude) * progress,
          );
      item['lat'] = coord.latitude;
      item['lng'] = coord.longitude;
      return item;
    });

    _refreshStationStopStatuses();
  }

  String _stationDisplayName(String code) {
    const names = {
      'CN': 'Cirebon Kejaksan (CN)',
      'PWT': 'Purwokerto (PWT)',
      'SMT': 'Semarang Tawang (SMT)',
      'YK': 'Yogyakarta (YK)',
      'SLO': 'Solo Balapan (SLO)',
      'MN': 'Madiun (MN)',
      'BJN': 'Bojonegoro (BJN)',
    };
    return names[code] ?? 'Stasiun $code ($code)';
  }

  String _stationCityName(String code) {
    const cities = {
      'CN': 'Cirebon',
      'PWT': 'Banyumas',
      'SMT': 'Semarang',
      'YK': 'Yogyakarta',
      'SLO': 'Surakarta',
      'MN': 'Madiun',
      'BJN': 'Bojonegoro',
    };
    return cities[code] ?? 'Indonesia';
  }

  void _refreshStationStopStatuses() {
    bool foundNext = false;
    for (final st in _stations) {
      final pos = (st['pos'] as num).toDouble();
      if (pos <= _trainProgress) {
        st['status'] = 'passed';
      } else if (!foundNext) {
        st['status'] = 'next';
        foundNext = true;
      } else {
        st['status'] = 'upcoming';
      }
    }
  }

  String _addTime(String baseTime, int addHours, int addMins) {
    try {
      final clean = baseTime.split(' ').first;
      final parts = clean.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final totalMins = (h * 60 + m + addHours * 60 + addMins) % (24 * 60);
      final nh = (totalMins ~/ 60).toString().padLeft(2, '0');
      final nm = (totalMins % 60).toString().padLeft(2, '0');
      return '$nh:$nm';
    } catch (_) {
      return '12:00';
    }
  }

  Map<String, dynamic> get _nextStation {
    for (final st in _stations) {
      if (st['status'] == 'next') return st;
    }
    return _stations.isNotEmpty
        ? _stations.last
        : {
            'code': 'SBI',
            'name': _activeDestName,
            'city': 'Tujuan',
            'time': _activeArrivalTime,
            'platform': 'Jalur 2',
            'lat': -7.2492,
            'lng': 112.7308,
          };
  }

  /// Hitung posisi [LatLng] kereta saat ini berdasarkan interpolasi di sepanjang segmen stasiun rute
  LatLng get _currentTrainLatLng {
    if (_stations.isEmpty) return const LatLng(-6.9126, 107.6024);
    if (_stations.length == 1) {
      return LatLng(
        _stations.first['lat'] as double,
        _stations.first['lng'] as double,
      );
    }

    for (int i = 0; i < _stations.length - 1; i++) {
      final s0 = _stations[i];
      final s1 = _stations[i + 1];
      final p0 = (s0['pos'] as num).toDouble();
      final p1 = (s1['pos'] as num).toDouble();
      if (_trainProgress >= p0 && _trainProgress <= p1) {
        final span = (p1 - p0) <= 0.0001 ? 1.0 : (p1 - p0);
        final t = ((_trainProgress - p0) / span).clamp(0.0, 1.0);
        final lat =
            (s0['lat'] as double) +
            ((s1['lat'] as double) - (s0['lat'] as double)) * t;
        final lng =
            (s0['lng'] as double) +
            ((s1['lng'] as double) - (s0['lng'] as double)) * t;
        return LatLng(lat, lng);
      }
    }
    final last = _stations.last;
    return LatLng(last['lat'] as double, last['lng'] as double);
  }

  int get _remainingDistanceKm {
    if (_stations.length < 2) return 45;
    final first = _stations.first;
    final last = _stations.last;
    final dLat = (last['lat'] as double) - (first['lat'] as double);
    final dLng = (last['lng'] as double) - (first['lng'] as double);
    final approxTotalKm =
        (math.sqrt(dLat * dLat + dLng * dLng) * 111.0 * 1.18).round();
    final rem = (approxTotalKm * (1.0 - _trainProgress)).round();
    return rem < 5 ? 5 : rem;
  }

  @override
  void dispose() {
    FocusManager.instance.primaryFocus?.unfocus();
    _mountMapTimer?.cancel();
    _movementTimer?.cancel();
    _mapController?.onFeatureTapped.remove(_onFeatureTapped);
    super.dispose();
  }

  // ===========================================================================
  // MAPLIBRE GL + MAPTILER HANDLERS
  // ===========================================================================

  Future<void> _onMapCreated(MapLibreMapController controller) async {
    _mapController = controller;
    controller.onFeatureTapped.add(_onFeatureTapped);
  }

  Future<void> _onStyleLoaded() async {
    final controller = _mapController;
    if (controller == null) return;

    try {
      // Tambahkan semua 4 GeoJSON source secara PARALEL (lebih cepat ~3x di WebGL/Native bridge)
      await Future.wait([
        controller.addGeoJsonSource(_routeSourceId, _buildFullRouteGeoJson()),
        controller.addGeoJsonSource(
          _passedRouteSourceId,
          _buildPassedRouteGeoJson(),
        ),
        controller.addGeoJsonSource(_stationsSourceId, _buildStationsGeoJson()),
        controller.addGeoJsonSource(_trainSourceId, _buildTrainGeoJson()),
      ]);

      // 1. Layer jalur rute penuh
      await controller.addLineLayer(
        _routeSourceId,
        _routeCasingLayerId,
        const LineLayerProperties(
          lineColor: '#062056',
          lineWidth: 7.0,
          lineOpacity: 0.30,
          lineCap: 'round',
          lineJoin: 'round',
        ),
        enableInteraction: false,
      );
      await controller.addLineLayer(
        _routeSourceId,
        _routeLineLayerId,
        const LineLayerProperties(
          lineColor: '#0256B8',
          lineWidth: 4.0,
          lineOpacity: 0.85,
          lineCap: 'round',
          lineJoin: 'round',
        ),
        enableInteraction: false,
      );

      // 2. Layer segmen jalur yang sudah dilewati kereta (hijau)
      await controller.addLineLayer(
        _passedRouteSourceId,
        _passedRouteLayerId,
        const LineLayerProperties(
          lineColor: '#10B981',
          lineWidth: 5.0,
          lineOpacity: 0.95,
          lineCap: 'round',
          lineJoin: 'round',
        ),
        enableInteraction: false,
      );

      // 3. Layer stasiun pemberhentian di sepanjang rute
      await controller.addCircleLayer(
        _stationsSourceId,
        _stationsCircleLayerId,
        const CircleLayerProperties(
          circleRadius: 7.0,
          circleColor: ['get', 'color'],
          circleStrokeWidth: 2.5,
          circleStrokeColor: '#FFFFFF',
        ),
      );
      await controller.addSymbolLayer(
        _stationsSourceId,
        _stationsLabelLayerId,
        const SymbolLayerProperties(
          textField: ['get', 'label'],
          textSize: 11.0,
          textOffset: [0, 1.35],
          textColor: '#062056',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 1.8,
          textFont: ['Metropolis Semi Bold', 'Noto Sans Semi Bold'],
          textOptional: true,
        ),
      );

      // 4. Layer marker posisi kereta saat ini
      await controller.addCircleLayer(
        _trainSourceId,
        _trainHaloLayerId,
        const CircleLayerProperties(
          circleRadius: 18.0,
          circleColor: ['get', 'color'],
          circleOpacity: 0.25,
        ),
      );
      await controller.addCircleLayer(
        _trainSourceId,
        _trainCircleLayerId,
        const CircleLayerProperties(
          circleRadius: 10.5,
          circleColor: ['get', 'color'],
          circleStrokeWidth: 3.0,
          circleStrokeColor: '#FFFFFF',
        ),
      );
      await controller.addSymbolLayer(
        _trainSourceId,
        _trainLabelLayerId,
        const SymbolLayerProperties(
          textField: ['get', 'label'],
          textSize: 11.5,
          textOffset: [0, -1.75],
          textColor: '#062056',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 2.0,
          textFont: ['Metropolis Semi Bold', 'Noto Sans Semi Bold'],
          textAllowOverlap: true,
          textIgnorePlacement: true,
        ),
      );

      if (mounted) {
        setState(() {
          _mapStyleLoaded = true;
          _mapLoadError = false;
        });
      }

      await _fitRouteBounds();
    } catch (e) {
      if (mounted) {
        setState(() {
          _mapLoadError = true;
          _mapErrorMessage = 'Gagal memuat layer peta rute: $e';
        });
      }
    }
  }

  Future<void> _syncMapGeoJson({
    bool updateStaticSources = true,
    bool fitRouteBounds = false,
    bool followCamera = false,
  }) async {
    final controller = _mapController;
    if (controller == null || !_mapStyleLoaded) return;

    try {
      // Hanya perbarui source dinamis (kereta & jalur terlewati) saat tick berjalan;
      // rute penuh & stasiun hanya di-upload ulang ketika rute/tiket berganti!
      final tasks = <Future<void>>[
        controller.setGeoJsonSource(
          _passedRouteSourceId,
          _buildPassedRouteGeoJson(),
        ),
        controller.setGeoJsonSource(_trainSourceId, _buildTrainGeoJson()),
        if (updateStaticSources) ...[
          controller.setGeoJsonSource(_routeSourceId, _buildFullRouteGeoJson()),
          controller.setGeoJsonSource(
            _stationsSourceId,
            _buildStationsGeoJson(),
          ),
        ],
      ];
      await Future.wait(tasks);

      if (fitRouteBounds) {
        await _fitRouteBounds();
      } else if (followCamera) {
        await controller.animateCamera(
          CameraUpdate.newLatLng(_currentTrainLatLng),
          duration: const Duration(milliseconds: 400),
        );
      }
    } catch (_) {}
  }

  Future<void> _fitRouteBounds() async {
    final controller = _mapController;
    if (controller == null || _stations.isEmpty) return;

    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final st in _stations) {
      final lat = st['lat'] as double;
      final lng = st['lng'] as double;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    final padLat = math.max((maxLat - minLat) * 0.22, 0.08);
    final padLng = math.max((maxLng - minLng) * 0.22, 0.08);

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - padLat, minLng - padLng),
          northeast: LatLng(maxLat + padLat, maxLng + padLng),
        ),
        left: 36,
        top: 56,
        right: 36,
        bottom: 36,
      ),
    );
  }

  void _onFeatureTapped(
    math.Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    final trainPos = _currentTrainLatLng;
    final distToTrain =
        (trainPos.latitude - coordinates.latitude).abs() +
        (trainPos.longitude - coordinates.longitude).abs();

    if (layerId == _trainCircleLayerId ||
        layerId == _trainHaloLayerId ||
        layerId == _trainLabelLayerId ||
        distToTrain < 0.08) {
      setState(() {
        _selectedMapPopup = {
          'type': 'train',
          'title': '$_activeTrainName ($_activeTrainNumber)',
          'subtitle': '$_activeOriginName ➔ $_activeDestName',
          'detail':
              'Kecepatan $_currentSpeed km/j • ETA ${_nextStation['time']} ${_timezone.code} di ${_nextStation['name']} • ${_delayMinutes > 0 ? 'Terlambat +$_delayMinutes mnt' : 'Tepat Waktu'}',
          'coords':
              '${trainPos.latitude.toStringAsFixed(4)}, ${trainPos.longitude.toStringAsFixed(4)}',
        };
      });
      return;
    }

    Map<String, dynamic>? nearestStation;
    double bestDist = 999;
    for (final st in _stations) {
      final d = ((st['lat'] as double) - coordinates.latitude).abs() +
          ((st['lng'] as double) - coordinates.longitude).abs();
      if (d < bestDist) {
        bestDist = d;
        nearestStation = st;
      }
    }

    if (nearestStation != null && bestDist < 0.35) {
      final statusLabel = nearestStation['status'] == 'passed'
          ? 'Sudah Dilewati'
          : nearestStation['status'] == 'next'
              ? 'Stasiun Pemberhentian Berikutnya'
              : 'Stasiun Akan Datang';
      setState(() {
        _selectedMapPopup = {
          'type': 'station',
          'title': nearestStation!['name'],
          'subtitle': '${nearestStation['city']} • ${nearestStation['platform']}',
          'detail':
              'Jadwal ${nearestStation['time']} ${_timezone.code} • Status: $statusLabel',
          'coords':
              '${(nearestStation['lat'] as double).toStringAsFixed(4)}, ${(nearestStation['lng'] as double).toStringAsFixed(4)}',
        };
      });
    }
  }

  Map<String, dynamic> _buildFullRouteGeoJson() {
    final coords = _stations
        .map((st) => [st['lng'] as double, st['lat'] as double])
        .toList();
    return {
      'type': 'FeatureCollection',
      'features': [
        if (coords.length >= 2)
          {
            'type': 'Feature',
            'properties': {'name': _activeTrainName},
            'geometry': {
              'type': 'LineString',
              'coordinates': coords,
            },
          },
      ],
    };
  }

  Map<String, dynamic> _buildPassedRouteGeoJson() {
    final passedCoords = <List<double>>[];
    for (final st in _stations) {
      final pos = (st['pos'] as num).toDouble();
      if (pos <= _trainProgress) {
        passedCoords.add([st['lng'] as double, st['lat'] as double]);
      }
    }
    final currentPos = _currentTrainLatLng;
    passedCoords.add([currentPos.longitude, currentPos.latitude]);

    return {
      'type': 'FeatureCollection',
      'features': [
        if (passedCoords.length >= 2)
          {
            'type': 'Feature',
            'properties': {},
            'geometry': {
              'type': 'LineString',
              'coordinates': passedCoords,
            },
          },
      ],
    };
  }

  Map<String, dynamic> _buildStationsGeoJson() {
    final features = <Map<String, dynamic>>[];
    for (final st in _stations) {
      final status = st['status'] as String? ?? 'upcoming';
      final color = status == 'passed'
          ? '#10B981'
          : status == 'next'
              ? '#F26716'
              : '#0256B8';
      features.add({
        'type': 'Feature',
        'id': st['code'],
        'properties': {
          'code': st['code'],
          'name': st['name'],
          'label': '${st['code']} (${st['time']})',
          'color': color,
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [st['lng'] as double, st['lat'] as double],
        },
      });
    }
    return {
      'type': 'FeatureCollection',
      'features': features,
    };
  }

  Map<String, dynamic> _buildTrainGeoJson() {
    final pos = _currentTrainLatLng;
    final colorHex = _trackingStatus == TrainDataStatus.delayed
        ? '#DC2626'
        : _trackingStatus == TrainDataStatus.demo
            ? '#7C3AED'
            : '#16A34A';

    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'id': 'active-train',
          'properties': {
            'label': '$_activeTrainNumber • $_currentSpeed km/j',
            'color': colorHex,
          },
          'geometry': {
            'type': 'Point',
            'coordinates': [pos.longitude, pos.latitude],
          },
        },
      ],
    };
  }

  Future<void> _focusStationOnMap(Map<String, dynamic> st) async {
    setState(() {
      _autoFollow = false;
      _selectedMapPopup = {
        'type': 'station',
        'title': st['name'],
        'subtitle': '${st['city']} • ${st['platform']}',
        'detail': 'Jadwal ${st['time']} ${_timezone.code}',
        'coords':
            '${(st['lat'] as double).toStringAsFixed(4)}, ${(st['lng'] as double).toStringAsFixed(4)}',
      };
    });
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(st['lat'] as double, st['lng'] as double),
        10.2,
      ),
    );
  }

  Future<void> _focusTrainOnMap() async {
    final pos = _currentTrainLatLng;
    setState(() {
      _autoFollow = true;
      _selectedMapPopup = {
        'type': 'train',
        'title': '$_activeTrainName ($_activeTrainNumber)',
        'subtitle': '$_activeOriginName ➔ $_activeDestName',
        'detail':
            'Kecepatan $_currentSpeed km/j • ETA ${_nextStation['time']} ${_timezone.code} di ${_nextStation['name']}',
        'coords':
            '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}',
      };
    });
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(pos, 9.6),
    );
  }

  // ===========================================================================
  // BUILD SPLIT SCREEN: BAGIAN ATAS PETA RUTE + BAGIAN BAWAH INFORMASI TIKET
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final nextSt = _nextStation;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062056),
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    _activeTrainName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TrainStatusBadge(
                  status: _trackingStatus,
                  delayMinutes: _delayMinutes,
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Rute Tiket: $_activeOriginName ➔ $_activeDestName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFBFDBFE),
              ),
            ),
          ],
        ),
        actions: [
          // Jam Real-Time Zona Waktu Indonesia (WIB / WITA / WIT)
          PopupMenuButton<IndonesiaTimezone>(
            tooltip: 'Pilih Zona Waktu Indonesia',
            onSelected: (tz) async {
              await IndonesiaTimeService.setTimezone(tz);
              if (mounted) setState(() => _timezone = tz);
            },
            itemBuilder: (_) => IndonesiaTimezone.values
                .map(
                  (tz) => PopupMenuItem(
                    value: tz,
                    child: Text('${tz.code} (${tz.fullName})'),
                  ),
                )
                .toList(),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time_filled_rounded,
                    size: 13,
                    color: Color(0xFFF26716),
                  ),
                  const SizedBox(width: 5),
                  // Jam terisolasi dalam StreamBuilder sehingga TIDAK memicu rebuild MapLibre tiap detik!
                  StreamBuilder<DateTime>(
                    stream: IndonesiaTimeService.clockStream(_timezone),
                    initialData: IndonesiaTimeService.now(_timezone),
                    builder: (_, snapshot) {
                      final dt = snapshot.data ?? IndonesiaTimeService.now(_timezone);
                      return Text(
                        IndonesiaTimeService.formatWallClock(
                          dt,
                          withSeconds: true,
                          zone: _timezone,
                        ),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ==================== BAGIAN ATAS: PETA RUTE KERETA (MAPLIBRE + MAPTILER) ====================
          Expanded(
            flex: 46,
            child: _buildTopRouteMapSection(),
          ),

          // ==================== BAGIAN BAWAH: INFORMASI PERJALANAN, TIKET, ETA & STASIUN ====================
          Expanded(
            flex: 54,
            child: _buildBottomInformationSection(nextSt),
          ),
        ],
      ),
    );
  }

  Widget _buildTopRouteMapSection() {
    final initPos = _stations.isNotEmpty
        ? _currentTrainLatLng
        : const LatLng(-6.9126, 107.6024);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF062056).withValues(alpha: 0.14),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF062056).withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.5),
        child: Stack(
          children: [
            // 1. Peta MapLibre GL terisolasi RepaintBoundary & deferred mount setelah transisi
            if (_mapReadyToMount)
              RepaintBoundary(
                child: MapLibreMap(
                  key: const ValueKey('live_tracking_maplibre'),
                  styleString: AppEnv.mapTilerStyleUrl,
                  initialCameraPosition: CameraPosition(
                    target: initPos,
                    zoom: 7.4,
                  ),
                  cameraTargetBounds: CameraTargetBounds(
                    LatLngBounds(
                      southwest: const LatLng(-11.2, 94.8),
                      northeast: const LatLng(6.3, 141.2),
                    ),
                  ),
                  minMaxZoomPreference: const MinMaxZoomPreference(4.8, 16.0),
                  onMapCreated: _onMapCreated,
                  onStyleLoadedCallback: _onStyleLoaded,
                  compassEnabled: false,
                  rotateGesturesEnabled: false,
                  scrollGesturesEnabled: true,
                  zoomGesturesEnabled: true,
                  tiltGesturesEnabled: false,
                  trackCameraPosition: false,
                ),
              )
            else
              Container(
                color: const Color(0xFFE2E8F0),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Color(0xFF062056),
                  ),
                ),
              ),

            // 2. Pill Info Rute & Koordinat Kereta di Kiri Atas Peta
            Positioned(
              top: 10,
              left: 10,
              right: 58,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  GestureDetector(
                    onTap: _focusTrainOnMap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF062056).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.train_rounded,
                            size: 14,
                            color: Color(0xFFF26716),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$_activeTrainNumber • $_currentSpeed km/j',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${(_trainProgress * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedBooking != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        'PNR: ${_selectedBooking!.bookingId}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF062056),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 3. Tombol Kontrol Peta (Zoom In, Zoom Out, Fit Rute, Auto-Follow Kereta)
            Positioned(
              right: 10,
              top: 10,
              child: Column(
                children: [
                  _buildMapControlBtn(
                    icon: Icons.add_rounded,
                    tooltip: 'Perbesar Peta',
                    onTap: () => _mapController?.animateCamera(
                      CameraUpdate.zoomIn(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildMapControlBtn(
                    icon: Icons.remove_rounded,
                    tooltip: 'Perkecil Peta',
                    onTap: () => _mapController?.animateCamera(
                      CameraUpdate.zoomOut(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildMapControlBtn(
                    icon: Icons.route_rounded,
                    tooltip: 'Tampilkan Seluruh Rute Tiket',
                    onTap: () {
                      setState(() => _autoFollow = false);
                      _fitRouteBounds();
                    },
                  ),
                  const SizedBox(height: 6),
                  _buildMapControlBtn(
                    icon: _autoFollow
                        ? Icons.gps_fixed_rounded
                        : Icons.gps_not_fixed_rounded,
                    tooltip: _autoFollow
                        ? 'Auto-Follow Kereta Aktif'
                        : 'Fokus ke Posisi Kereta',
                    active: _autoFollow,
                    onTap: _focusTrainOnMap,
                  ),
                ],
              ),
            ),

            // 4. Popup Detail Ketika Marker Kereta / Stasiun di Peta Diklik
            if (_selectedMapPopup != null)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _selectedMapPopup!['type'] == 'train'
                              ? const Color(0xFF062056)
                              : const Color(0xFFF26716),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _selectedMapPopup!['type'] == 'train'
                              ? Icons.directions_train_rounded
                              : Icons.location_on_rounded,
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
                            Text(
                              '${_selectedMapPopup!['title']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF062056),
                              ),
                            ),
                            Text(
                              '${_selectedMapPopup!['detail']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF334155),
                              ),
                            ),
                            Text(
                              'Koordinat: ${_selectedMapPopup!['coords']}',
                              style: const TextStyle(
                                fontSize: 9.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close_rounded, size: 16),
                        onPressed: () =>
                            setState(() => _selectedMapPopup = null),
                      ),
                    ],
                  ),
                ),
              ),

            // 5. Loading / Error Overlay pada Peta
            if (!_mapStyleLoaded && !_mapLoadError)
              Positioned(
                bottom: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Memuat peta rute MapTiler...',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF062056),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (_mapLoadError)
              Center(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFDC2626),
                        size: 28,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _mapErrorMessage ?? 'Gagal memuat peta rute.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _onStyleLoaded,
                        icon: const Icon(Icons.refresh_rounded, size: 15),
                        label: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapControlBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? const Color(0xFF062056) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(
              icon,
              size: 17,
              color: active ? Colors.white : const Color(0xFF062056),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // BAGIAN BAWAH: PANEL INFORMASI PERJALANAN, TIKET, ETA & STASIUN PEMBERHENTIAN
  // ===========================================================================

  Widget _buildBottomInformationSection(Map<String, dynamic> nextSt) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF062056).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Pilihan Tiket Aktif (Jika pengguna memiliki tiket yang sudah dipesan)
              if (_activeTickets.length > 1) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Pilih Tiket Anda untuk Dilihat Rutenya:',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF062056),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_activeTickets.length} Tiket Aktif',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF26716),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _activeTickets.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final t = _activeTickets[idx];
                      final isSelected =
                          _selectedBooking?.bookingId == t.bookingId;
                      return GestureDetector(
                        onTap: () => _selectBookedTicket(t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF062056)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF062056)
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.confirmation_number_rounded,
                                size: 13,
                                color: isSelected
                                    ? const Color(0xFFF26716)
                                    : const Color(0xFF062056),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${t.originCode} ➔ ${t.destCode} (${t.trainName.split(' ').take(2).join(' ')})',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
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
                const SizedBox(height: 12),
              ] else if (!_isLoadingTickets &&
                  _activeTickets.isEmpty &&
                  widget.booking == null &&
                  widget.trainName == null) ...[
                // Info jika belum ada tiket aktif yang dipesan
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFFEA580C),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Anda belum memiliki tiket aktif. Menampilkan pratinjau rute kereta. Pesan tiket untuk melacak rute perjalanan tiket Anda.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9A3412),
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFF26716),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                        ),
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AntarKotaScreen(),
                            ),
                          );
                          _initTicketAndRoute();
                        },
                        child: const Text(
                          'Pesan Tiket',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 2. Kartu Ringkasan Rute Tiket & Progress Perjalanan
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_activeTrainName ($_activeTrainNumber)',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF062056),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _selectedBooking != null
                                    ? '${_selectedBooking!.trainClass} • Kursi ${_selectedBooking!.seatNumber} • ${_selectedBooking!.travelDate}'
                                    : 'Eksekutif • Jadwal $_activeDepartureTime - $_activeArrivalTime ${_timezone.code}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _delayMinutes > 0
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _delayMinutes > 0
                                ? 'Terlambat +$_delayMinutes mnt'
                                : 'Tepat Waktu',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: _delayMinutes > 0
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$_activeOriginName ($_activeDepartureTime)',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: Color(0xFFF26716),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '$_activeDestName ($_activeArrivalTime)',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _trainProgress,
                        minHeight: 7,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 3. Baris Metrik Telemetri (Kecepatan, ETA, Sisa Jarak)
              Row(
                children: [
                  _buildMetricTile(
                    icon: Icons.speed_rounded,
                    label: 'Kecepatan',
                    value: '$_currentSpeed km/j',
                    color: const Color(0xFF0256B8),
                  ),
                  const SizedBox(width: 8),
                  _buildMetricTile(
                    icon: Icons.schedule_rounded,
                    label: 'ETA Tujuan',
                    value: '$_activeArrivalTime ${_timezone.code}',
                    color: const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 8),
                  _buildMetricTile(
                    icon: Icons.straighten_rounded,
                    label: 'Sisa Jarak',
                    value: '$_remainingDistanceKm km',
                    color: const Color(0xFFF26716),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 4. Kartu Highlight Stasiun Pemberhentian Berikutnya
              InkWell(
                onTap: () => _focusStationOnMap(nextSt),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF062056), Color(0xFF0A3282)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.next_plan_rounded,
                          color: Color(0xFFFBBF24),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'STASIUN PEMBERHENTIAN BERIKUTNYA',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF93C5FD),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${nextSt['name']}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${nextSt['city']} • ${nextSt['platform']} (Ketuk untuk lihat di peta)',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFFCBD5E1),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'ETA Tiba',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: Color(0xFF93C5FD),
                            ),
                          ),
                          Text(
                            '${nextSt['time']} ${_timezone.code}',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF4ADE80),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 5. Daftar Stasiun Pemberhentian di Sepanjang Rute Tiket
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Stasiun Pemberhentian',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF062056),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_stations.length} Stasiun',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              ...List.generate(_stations.length, (i) {
                final st = _stations[i];
                final isPassed = st['status'] == 'passed';
                final isNext = st['status'] == 'next';
                final isLast = i == _stations.length - 1;

                final dotColor = isPassed
                    ? const Color(0xFF10B981)
                    : isNext
                        ? const Color(0xFFF26716)
                        : const Color(0xFF94A3B8);

                return InkWell(
                  onTap: () => _focusStationOnMap(st),
                  borderRadius: BorderRadius.circular(10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 48,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '${st['time']}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: isNext
                                  ? const Color(0xFFF26716)
                                  : isPassed
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                      Column(
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
                                  color: dotColor.withValues(alpha: 0.35),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: isPassed
                                ? const Icon(
                                    Icons.check,
                                    size: 8,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          if (!isLast)
                            Container(
                              width: 2.2,
                              height: 36,
                              color: isPassed
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFE2E8F0),
                            ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            '${st['name']}',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: isNext
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                              color: isNext
                                                  ? const Color(0xFF062056)
                                                  : const Color(0xFF1E293B),
                                            ),
                                          ),
                                        ),
                                        if (isNext) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 1.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFEDD5),
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                            child: const Text(
                                              'Berikutnya',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFEA580C),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${st['city']} • ${st['platform']}',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.my_location_rounded,
                                size: 15,
                                color: Color(0xFF0256B8),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9.5,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF062056),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
