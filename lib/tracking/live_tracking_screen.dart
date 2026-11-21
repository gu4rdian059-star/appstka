import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/user_db_service.dart';

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

class _LiveTrackingScreenState extends State<LiveTrackingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _trainAnimController;

  // Nilai progress pergerakan kereta (0.0 sampai 1.0)
  double _trainProgress = 0.58; // Posisi sekarang ~58% perjalanan
  int _currentSpeed = 108; // km/jam
  String _mapStyle = 'Navigasi'; // Navigasi, Terang, Satelit
  bool _isAutoCenter = true;

  Timer? _simulationTimer;
  final math.Random _random = math.Random();

  // Data Dinamis Tiket & Kereta
  List<BookingModel> _activeBookings = [];
  BookingModel? _selectedBooking;
  late String _trainName;
  late String _trainNumber;
  late String _origin;
  late String _destination;
  late String _departureTime;
  late String _arrivalTime;

  List<Map<String, dynamic>> _stations = [];

  @override
  void initState() {
    super.initState();
    _trainAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _initTrackingData();

    // Simulasi live telemetri kecepatan & pergerakan kereta
    _simulationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      setState(() {
        _currentSpeed = 102 + _random.nextInt(12); // Fluktuasi 102-114 km/jam
        _trainProgress = (_trainProgress + 0.003).clamp(0.0, 1.0);
        _updateStationStatuses();
      });
    });
  }

  Future<void> _initTrackingData() async {
    // 1. Tentukan target booking awal
    if (widget.booking != null) {
      _selectedBooking = widget.booking;
    }

    // 2. Load tiket aktif pengguna dari database
    try {
      final bookings = await UserDatabaseService.getBookings(
        statusFilter: 'Sudah Dibayar',
      );
      if (mounted) {
        setState(() {
          _activeBookings = bookings;
          if (_selectedBooking == null && _activeBookings.isNotEmpty) {
            _selectedBooking = _activeBookings.first;
          }
        });
      }
    } catch (_) {}

    _applyBookingDetails();
  }

  void _applyBookingDetails() {
    if (_selectedBooking != null) {
      final b = _selectedBooking!;
      _trainName = b.trainName;
      final match = RegExp(r'\((.*?)\)').firstMatch(b.trainName);
      _trainNumber = match != null ? match.group(1)! : 'KA 01';
      _origin = '${b.originName} (${b.originCode})';
      _destination = '${b.destCity} (${b.destCode})';
      _departureTime = b.departureTime.replaceAll(' WIB', '').trim();
      _arrivalTime = b.arrivalTime.replaceAll(' WIB', '').trim();
    } else {
      _trainName = widget.trainName ?? 'KA Argo Bromo Anggrek';
      _trainNumber = widget.trainNumber ?? 'KA 02';
      _origin = widget.origin ?? 'Gambir (GMR)';
      _destination = widget.destination ?? 'Surabaya Pasarturi (SBI)';
      _departureTime = widget.departureTime ?? '08:20';
      _arrivalTime = widget.arrivalTime ?? '16:25';
    }

    _stations = _buildStationsForRoute(
      _origin,
      _destination,
      _departureTime,
      _arrivalTime,
    );
    _updateStationStatuses();
    if (mounted) setState(() {});
  }

  String _extractCode(String text) {
    final reg = RegExp(r'\(([A-Z0-9]+)\)');
    final match = reg.firstMatch(text);
    if (match != null) return match.group(1)!;
    return text.trim().toUpperCase();
  }

  List<Map<String, dynamic>> _buildStationsForRoute(
    String origin,
    String destination,
    String depTime,
    String arrTime,
  ) {
    final oCode = _extractCode(origin);
    final dCode = _extractCode(destination);

    // 1. Rute Malang <-> Surabaya (MLK / ML -> SGU / SBI)
    if ((oCode == 'MLK' || oCode == 'ML' || oCode == 'LW' || oCode == 'KPN') &&
        (dCode == 'SGU' || dCode == 'SBI' || dCode == 'WO' || dCode == 'SDA')) {
      return [
        {
          'name': 'Malang Kota Lama (MLK)',
          'city': 'Malang',
          'time': '$depTime WIB',
          'pos': 0.0,
          'platform': 'Jalur 1',
        },
        {
          'name': 'Malang (ML)',
          'city': 'Malang',
          'time': '08:14 WIB',
          'pos': 0.14,
          'platform': 'Jalur 2',
        },
        {
          'name': 'Lawang (LW)',
          'city': 'Malang',
          'time': '08:42 WIB',
          'pos': 0.32,
          'platform': 'Jalur 1',
        },
        {
          'name': 'Bangil (BG)',
          'city': 'Pasuruan',
          'time': '09:18 WIB',
          'pos': 0.55,
          'platform': 'Jalur 3',
        },
        {
          'name': 'Sidoarjo (SDA)',
          'city': 'Sidoarjo',
          'time': '09:52 WIB',
          'pos': 0.76,
          'platform': 'Jalur 2',
        },
        {
          'name': 'Wonokromo (WO)',
          'city': 'Surabaya',
          'time': '10:15 WIB',
          'pos': 0.89,
          'platform': 'Jalur 4',
        },
        {
          'name': 'Surabaya Gubeng (SGU)',
          'city': 'Surabaya',
          'time': '$arrTime WIB',
          'pos': 1.0,
          'platform': 'Jalur 3',
        },
      ];
    }

    // 2. Rute Surabaya <-> Pasuruan / Bangil (SGU / SBI -> PS / BG)
    if ((oCode == 'SGU' || oCode == 'SBI' || oCode == 'WO' || oCode == 'SDA') &&
        (dCode == 'PS' || dCode == 'BG' || dCode == 'PR' || dCode == 'KK')) {
      return [
        {
          'name': 'Surabaya Gubeng (SGU)',
          'city': 'Surabaya',
          'time': '$depTime WIB',
          'pos': 0.0,
          'platform': 'Jalur 3',
        },
        {
          'name': 'Wonokromo (WO)',
          'city': 'Surabaya',
          'time': '09:35 WIB',
          'pos': 0.18,
          'platform': 'Jalur 2',
        },
        {
          'name': 'Sidoarjo (SDA)',
          'city': 'Sidoarjo',
          'time': '09:58 WIB',
          'pos': 0.42,
          'platform': 'Jalur 2',
        },
        {
          'name': 'Bangil (BG)',
          'city': 'Pasuruan',
          'time': '10:22 WIB',
          'pos': 0.70,
          'platform': 'Jalur 1',
        },
        {
          'name': 'Pasuruan (PS)',
          'city': 'Pasuruan',
          'time': '$arrTime WIB',
          'pos': 1.0,
          'platform': 'Jalur 2',
        },
      ];
    }

    // 3. Rute Jakarta <-> Surabaya (GMR / PSE -> SBI / SGU)
    if ((oCode == 'GMR' || oCode == 'PSE') &&
        (dCode == 'SBI' || dCode == 'SGU')) {
      return [
        {
          'name': 'Gambir (GMR)',
          'city': 'Jakarta Pusat',
          'time': '$depTime WIB',
          'pos': 0.0,
          'platform': 'Jalur 3',
        },
        {
          'name': 'Cirebon (CN)',
          'city': 'Cirebon',
          'time': '10:55 WIB',
          'pos': 0.32,
          'platform': 'Jalur 2',
        },
        {
          'name': 'Pekalongan (PK)',
          'city': 'Pekalongan',
          'time': '12:20 WIB',
          'pos': 0.48,
          'platform': 'Jalur 1',
        },
        {
          'name': 'Semarang Tawang (SMT)',
          'city': 'Semarang',
          'time': '13:15 WIB',
          'pos': 0.65,
          'platform': 'Jalur 4',
        },
        {
          'name': 'Bojonegoro (BJN)',
          'city': 'Bojonegoro',
          'time': '15:10 WIB',
          'pos': 0.84,
          'platform': 'Jalur 2',
        },
        {
          'name': 'Surabaya Pasarturi (SBI)',
          'city': 'Surabaya',
          'time': '$arrTime WIB',
          'pos': 1.0,
          'platform': 'Jalur 1',
        },
      ];
    }

    // 4. Fallback Dinamis untuk Rute Kereta Lainnya di Indonesia
    return [
      {
        'name': origin,
        'city': origin.split('(').first.trim(),
        'time': '$depTime WIB',
        'pos': 0.0,
        'platform': 'Jalur 1',
      },
      {
        'name': 'Stasiun Antara 1',
        'city': 'Transit Kota',
        'time': '10:30 WIB',
        'pos': 0.35,
        'platform': 'Jalur 2',
      },
      {
        'name': 'Stasiun Antara 2',
        'city': 'Transit Wilayah',
        'time': '12:45 WIB',
        'pos': 0.68,
        'platform': 'Jalur 3',
      },
      {
        'name': destination,
        'city': destination.split('(').first.trim(),
        'time': '$arrTime WIB',
        'pos': 1.0,
        'platform': 'Jalur 1',
      },
    ];
  }

  void _updateStationStatuses() {
    for (int i = 0; i < _stations.length; i++) {
      final pos = _stations[i]['pos'] as double;
      if (pos < _trainProgress - 0.05) {
        _stations[i]['status'] = 'passed';
      } else if (pos >= _trainProgress - 0.05 && pos <= _trainProgress + 0.15) {
        _stations[i]['status'] = 'next';
      } else {
        _stations[i]['status'] = 'upcoming';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF062056),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062056),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'LIVE GPS TRACKING',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF38BDF8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '$_trainName ($_trainNumber)',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            tooltip: 'Bagikan Posisi',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tautan live tracking disalin ke clipboard!'),
                  backgroundColor: Color(0xFF0256B8),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Interactive Canvas Map View
          Positioned.fill(child: _buildInteractiveMapView()),

          // 2. Chip Pemilih Tiket Perjalanan jika ada > 1 tiket
          if (_activeBookings.length > 1)
            Positioned(
              top: 10,
              left: 16,
              right: 16,
              child: _buildActiveTicketSwitcher(),
            ),

          // 3. Telemetry Floating Header Bar (Kecepatan, Status, Sisa Waktu)
          Positioned(
            top: _activeBookings.length > 1 ? 76 : 14,
            left: 16,
            right: 16,
            child: _buildTelemetryBar(),
          ),

          // 4. Floating Map Controls (Zoom, Center, Style)
          Positioned(
            right: 16,
            top: _activeBookings.length > 1 ? 162 : 100,
            child: _buildMapControls(),
          ),

          // 5. Draggable Bottom Sheet Timeline & Info Stasiun
          _buildDraggableStationSheet(),
        ],
      ),
    );
  }

  Widget _buildActiveTicketSwitcher() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF062056).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PILIH TIKET PERJALANAN AKTIF:',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Color(0xFF93C5FD),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _activeBookings.map((b) {
                final isSel = _selectedBooking?.bookingId == b.bookingId;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedBooking = b;
                      _applyBookingDetails();
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSel
                          ? const Color(0xFF0256B8)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSel ? const Color(0xFF38BDF8) : Colors.white24,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.train_rounded,
                          size: 14,
                          color: isSel ? Colors.white : Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${b.trainName} (${b.originCode} ➔ ${b.destCode})',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSel
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // INTERACTIVE CANVAS MAP
  // ===========================================================================
  Widget _buildInteractiveMapView() {
    Color bgCanvasColor;
    if (_mapStyle == 'Satelit') {
      bgCanvasColor = const Color(0xFF0F172A);
    } else if (_mapStyle == 'Terang') {
      bgCanvasColor = const Color(0xFFF1F5F9);
    } else {
      bgCanvasColor = const Color(0xFF1E293B); // Dark Navigation style
    }

    return Container(
      color: bgCanvasColor,
      child: AnimatedBuilder(
        animation: _trainAnimController,
        builder: (context, _) {
          return CustomPaint(
            painter: _RailwayTrackPainter(
              trainProgress: _trainProgress,
              pulseAnimation: _trainAnimController.value,
              mapStyle: _mapStyle,
              stations: _stations,
              trainLabel: _trainNumber,
              currentSpeed: _currentSpeed,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // TELEMETRY BAR
  // ===========================================================================
  Widget _buildTelemetryBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF062056).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Kecepatan
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF0256B8).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.speed_rounded,
                  size: 20,
                  color: Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kecepatan',
                    style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                  ),
                  Text(
                    '$_currentSpeed km/h',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Garis Pemisah
          Container(width: 1, height: 26, color: Colors.white24),

          // Status Ketepatan Waktu
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF10B981),
                    width: 0.8,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 10,
                      color: Color(0xFF10B981),
                    ),
                    SizedBox(width: 3),
                    Text(
                      'Tepat Waktu',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Sisa: ${((1.0 - _trainProgress) * 220 + 25).round()} km',
                style: const TextStyle(fontSize: 10.5, color: Colors.white70),
              ),
            ],
          ),

          // Garis Pemisah
          Container(width: 1, height: 26, color: Colors.white24),

          // Estimasi Tiba
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Estimasi Tiba',
                style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
              Text(
                '$_arrivalTime WIB',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFF26716),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // FLOATING MAP CONTROLS
  // ===========================================================================
  Widget _buildMapControls() {
    return Column(
      children: [
        // Ganti Style Peta
        _buildCircleButton(
          icon: Icons.layers_outlined,
          tooltip: 'Gaya Peta',
          onTap: () {
            setState(() {
              if (_mapStyle == 'Navigasi') {
                _mapStyle = 'Satelit';
              } else if (_mapStyle == 'Satelit') {
                _mapStyle = 'Terang';
              } else {
                _mapStyle = 'Navigasi';
              }
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Tema peta: $_mapStyle'),
                backgroundColor: const Color(0xFF062056),
                duration: const Duration(milliseconds: 900),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        const SizedBox(height: 8),

        // Pusatkan ke Kereta
        _buildCircleButton(
          icon: Icons.my_location_rounded,
          color: _isAutoCenter ? const Color(0xFF0256B8) : Colors.white,
          iconColor: _isAutoCenter ? Colors.white : const Color(0xFF0F172A),
          tooltip: 'Pusatkan Posisi Kereta',
          onTap: () {
            setState(() => _isAutoCenter = !_isAutoCenter);
          },
        ),
      ],
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    Color color = Colors.white,
    Color iconColor = const Color(0xFF0F172A),
  }) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black45,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: iconColor),
        ),
      ),
    );
  }

  // ===========================================================================
  // DRAGGABLE BOTTOM SHEET TIMELINE
  // ===========================================================================
  Widget _buildDraggableStationSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.38,
      minChildSize: 0.18,
      maxChildSize: 0.82,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 18,
                offset: Offset(0, -6),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            children: [
              // Pill Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Info Stasiun Berikutnya (Highlight Card Dinamis)
              Builder(
                builder: (context) {
                  final nextStation = _stations.firstWhere(
                    (s) => s['status'] == 'next',
                    orElse: () => _stations.isNotEmpty
                        ? _stations.last
                        : {
                            'name': _destination,
                            'city': _destination,
                            'time': '$_arrivalTime WIB',
                            'platform': 'Jalur 1',
                          },
                  );
                  final stName = nextStation['name'] as String? ?? _destination;
                  final stTime =
                      nextStation['time'] as String? ?? '$_arrivalTime WIB';
                  final stPlatform =
                      nextStation['platform'] as String? ?? 'Jalur 1';

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF062056), Color(0xFF0A3A8A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF062056)
                              .withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Color(0xFF38BDF8),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'STASIUN BERIKUTNYA',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF93C5FD),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                stName,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Estimasi Tiba: $stTime • $stPlatform',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade300,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 18),

              // Rute Timeline Perjalanan
              const Text(
                'Rute & Titik Henti Kereta',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),

              // List Stasiun
              ...List.generate(_stations.length, (idx) {
                final st = _stations[idx];
                final isLast = idx == _stations.length - 1;
                final isNext = st['status'] == 'next';
                final isPassed = st['status'] == 'passed';

                Color nodeColor;
                IconData nodeIcon;
                if (isPassed) {
                  nodeColor = const Color(0xFF10B981);
                  nodeIcon = Icons.check_rounded;
                } else if (isNext) {
                  nodeColor = const Color(0xFFF26716);
                  nodeIcon = Icons.train_rounded;
                } else {
                  nodeColor = Colors.grey.shade400;
                  nodeIcon = Icons.circle_outlined;
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kolom Waktu
                    SizedBox(
                      width: 65,
                      child: Text(
                        st['time'],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isNext
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isNext
                              ? const Color(0xFFF26716)
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),

                    // Garis & Lingkaran Node
                    Column(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: nodeColor.withValues(
                              alpha: isNext ? 0.2 : 1.0,
                            ),
                            shape: BoxShape.circle,
                            border: isNext
                                ? Border.all(color: nodeColor, width: 2)
                                : null,
                          ),
                          child: Icon(
                            nodeIcon,
                            size: 14,
                            color: isNext ? nodeColor : Colors.white,
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 2.5,
                            height: 38,
                            color: isPassed
                                ? const Color(0xFF10B981)
                                : Colors.grey.shade300,
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),

                    // Nama Stasiun & Status
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  st['name'],
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isNext
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: isNext
                                        ? const Color(0xFF0F172A)
                                        : Colors.grey.shade800,
                                  ),
                                ),
                                if (isNext) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7ED),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(0xFFFDBA74),
                                      ),
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
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }),

              const Divider(height: 24),

              // Fasilitas & Layanan Onboard
              const Text(
                'Status Layanan On-Board',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildServicePill(
                    Icons.ac_unit_rounded,
                    'Suhu AC',
                    '22°C (Sejuk)',
                  ),
                  const SizedBox(width: 8),
                  _buildServicePill(
                    Icons.wifi_rounded,
                    'Wi-Fi 5G',
                    'Aktif Terhubung',
                  ),
                  const SizedBox(width: 8),
                  _buildServicePill(
                    Icons.wb_sunny_rounded,
                    'Cuaca Rute',
                    'Cerah 29°C',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildServicePill(IconData icon, String label, String val) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF0256B8)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600),
            ),
            Text(
              val,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// RAILWAY TRACK & ANIMATED TRAIN CANVAS PAINTER
// =============================================================================
class _RailwayTrackPainter extends CustomPainter {
  final double trainProgress;
  final double pulseAnimation;
  final String mapStyle;
  final List<Map<String, dynamic>> stations;
  final String trainLabel;
  final int currentSpeed;

  _RailwayTrackPainter({
    required this.trainProgress,
    required this.pulseAnimation,
    required this.mapStyle,
    required this.stations,
    required this.trainLabel,
    required this.currentSpeed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background Grid / Map Road Net
    final gridPaint = Paint()
      ..color = mapStyle == 'Terang'
          ? Colors.grey.shade300
          : const Color(0xFF334155).withValues(alpha: 0.3)
      ..strokeWidth = 0.8;

    for (double x = 0; x < w; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }
    for (double y = 0; y < h; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // Path Rel Kereta (Polyline Melengkung Cantik)
    final trackPath = Path();
    final p0 = Offset(w * 0.15, h * 0.12);
    final p1 = Offset(w * 0.38, h * 0.26);
    final p2 = Offset(w * 0.72, h * 0.40);
    final p3 = Offset(w * 0.45, h * 0.58);
    final p4 = Offset(w * 0.80, h * 0.75);

    trackPath.moveTo(p0.dx, p0.dy);
    trackPath.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);
    trackPath.quadraticBezierTo(w * 0.30, h * 0.68, p4.dx, p4.dy);

    // 1. Gambar Rel Belakang (Garis Abu/Track Bed)
    final bedPaint = Paint()
      ..color = mapStyle == 'Terang'
          ? Colors.grey.shade400
          : const Color(0xFF475569)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(trackPath, bedPaint);

    // 2. Garis Track Rel Tengah (Dotted Railway Ties)
    final tiePaint = Paint()
      ..color = mapStyle == 'Terang' ? Colors.white : const Color(0xFF64748B)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    canvas.drawPath(trackPath, tiePaint);

    // 3. Garis Jalur yang Sudah Dilewati (Hijau Neon Glowing)
    final passedPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final pathMetrics = trackPath.computeMetrics().toList();
    if (pathMetrics.isNotEmpty) {
      final metric = pathMetrics.first;
      final passedLength = metric.length * trainProgress;
      final extractedPath = metric.extractPath(0, passedLength);
      canvas.drawPath(extractedPath, passedPaint);

      // Hitung Posisi Kereta Saat Ini
      final tangent = metric.getTangentForOffset(passedLength);
      if (tangent != null) {
        final trainPos = tangent.position;
        final angle = tangent.angle;

        // Pulsing Wave Halo Radar di Sekeliling Kereta
        final pulseRadius = 16.0 + (pulseAnimation * 26.0);
        final pulsePaint = Paint()
          ..color = const Color(0xFF38BDF8)
              .withValues(alpha: (1.0 - pulseAnimation) * 0.6)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(trainPos, pulseRadius, pulsePaint);

        final innerPulse = Paint()
          ..color = const Color(0xFF0256B8).withValues(alpha: 0.3)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(trainPos, 18, innerPulse);

        // Badan Marker Kereta Api (Badge Biru Gelap + Arah Laju)
        canvas.save();
        canvas.translate(trainPos.dx, trainPos.dy);
        canvas.rotate(angle);

        final trainBodyPaint = Paint()..color = const Color(0xFF062056);
        final trainBorderPaint = Paint()
          ..color = Colors.white
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;

        final bodyRect = RRect.fromLTRBAndCorners(
          -14,
          -8,
          14,
          8,
          topLeft: const Radius.circular(5),
          bottomLeft: const Radius.circular(5),
          topRight: const Radius.circular(8),
          bottomRight: const Radius.circular(8),
        );
        canvas.drawRRect(bodyRect, trainBodyPaint);
        canvas.drawRRect(bodyRect, trainBorderPaint);

        // Lampu Depan Kereta (Kuning Terang)
        final lightPaint = Paint()..color = const Color(0xFFFBBF24);
        canvas.drawCircle(const Offset(11, -3), 2, lightPaint);
        canvas.drawCircle(const Offset(11, 3), 2, lightPaint);

        canvas.restore();

        // Label Tag di Atas Kereta
        final textSpan = TextSpan(
          text: '$trainLabel ($currentSpeed km/h)',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            backgroundColor: Color(0xFF0256B8),
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset(trainPos.dx - (textPainter.width / 2), trainPos.dy - 34),
        );
      }
    }

    // 4. Stasiun-stasiun Pin di Sepanjang Rute
    if (pathMetrics.isNotEmpty) {
      final metric = pathMetrics.first;
      for (final st in stations) {
        final posLen = metric.length * (st['pos'] as double);
        final stTangent = metric.getTangentForOffset(posLen);
        if (stTangent != null) {
          final p = stTangent.position;
          final isPassed = st['status'] == 'passed';
          final isNext = st['status'] == 'next';

          final pinColor = isPassed
              ? const Color(0xFF10B981)
              : isNext
              ? const Color(0xFFF26716)
              : Colors.white;

          // Lingkaran Stasiun
          canvas.drawCircle(p, 6, Paint()..color = pinColor);
          canvas.drawCircle(
            p,
            6,
            Paint()
              ..color = const Color(0xFF062056)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.8,
          );

          // Label Singkatan Stasiun
          final stCode = (st['name'] as String)
              .split('(')
              .last
              .replaceAll(')', '');
          final stTextSpan = TextSpan(
            text: stCode,
            style: TextStyle(
              color: mapStyle == 'Terang'
                  ? const Color(0xFF0F172A)
                  : Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
            ),
          );
          final stPainter = TextPainter(
            text: stTextSpan,
            textDirection: TextDirection.ltr,
          )..layout();
          stPainter.paint(canvas, Offset(p.dx + 9, p.dy - 6));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RailwayTrackPainter oldDelegate) {
    return oldDelegate.trainProgress != trainProgress ||
        oldDelegate.pulseAnimation != pulseAnimation ||
        oldDelegate.mapStyle != mapStyle;
  }
}
