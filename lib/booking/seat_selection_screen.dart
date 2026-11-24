import 'dart:async';

import 'package:flutter/material.dart';

import '../services/user_db_service.dart';
import '../transitions/page_transitions.dart';
import 'order_confirmation_screen.dart';

// halo/

class SeatSelectionScreen extends StatefulWidget {
  final TrainScheduleModel train;
  final StationModel origin;
  final StationModel dest;
  final DateTime travelDate;
  final String bookerName;
  final String bookerEmail;
  final String bookerPhone;
  final String passengerName;
  final String passengerNik;
  final List<Map<String, String>>? passengers;
  final int totalAmount;
  final TrainScheduleModel? returnTrain;
  final DateTime? returnDate;

  const SeatSelectionScreen({
    super.key,
    required this.train,
    required this.origin,
    required this.dest,
    required this.travelDate,
    required this.bookerName,
    required this.bookerEmail,
    required this.bookerPhone,
    required this.passengerName,
    required this.passengerNik,
    this.passengers,
    required this.totalAmount,
    this.returnTrain,
    this.returnDate,
  });

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  // Gerbong yang dipilih
  int _selectedWagonIndex = 1; // 0: EKS-1, 1: EKS-2, 2: EKS-3

  final List<Map<String, dynamic>> _wagons = [
    {'code': 'EKS-1', 'name': 'Eksekutif 1', 'available': 4},
    {'code': 'EKS-2', 'name': 'Eksekutif 2', 'available': 18},
    {'code': 'EKS-3', 'name': 'Eksekutif 3', 'available': 12},
  ];

  // Kursi yang dipilih untuk multi penumpang
  int _activePassengerIdx = 0;
  final Map<int, String> _passengerSeats = {};

  // Kursi yang dipilih: Default 5C
  String _selectedSeat = '5C';

  int get _passengerCount {
    if (widget.passengers != null && widget.passengers!.isNotEmpty) {
      return widget.passengers!.length;
    }
    return 1;
  }

  // Peta kursi terisi dinamis & berbeda per gerbong dan jadwal kereta
  late final Map<int, Set<String>> _wagonOccupiedMap;

  // Live Timer Countdown (09:47)
  late int _remainingSeconds;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = 587; // 09:47
    _startTimer();
    _initOccupiedSeats();
  }

  void _initOccupiedSeats() {
    // Gerbong 0 (EKS-1): 4 kursi tersedia (28 terisi)
    final eks1Occupied = <String>{};
    for (int r = 1; r <= 8; r++) {
      for (final col in ['A', 'B', 'C', 'D']) {
        final code = '$r$col';
        if (code != '2A' && code != '4B' && code != '6C' && code != '7D') {
          eks1Occupied.add(code);
        }
      }
    }

    // Gerbong 1 (EKS-2): 18 kursi tersedia (14 terisi) - Persis Gambar 3 & Gambar 4
    final eks2Occupied = <String>{
      '1A',
      '1B',
      '2B',
      '2C',
      '3D',
      '4A',
      '4C',
      '6D',
      '7A',
      '7B',
      '8C',
      '8D',
    };

    // Gerbong 2 (EKS-3): 12 kursi tersedia (20 terisi)
    final eks3Occupied = <String>{
      '1C',
      '1D',
      '2A',
      '2D',
      '3A',
      '3B',
      '4B',
      '4D',
      '5A',
      '5B',
      '6A',
      '6B',
      '7C',
      '7D',
      '8A',
      '8B',
      '3C',
      '5D',
      '6C',
      '7A',
    };

    _wagonOccupiedMap = {0: eks1Occupied, 1: eks2Occupied, 2: eks3Occupied};

    _assignDefaultSeats();
  }

  void _assignDefaultSeats() {
    final currentOccupied = _wagonOccupiedMap[_selectedWagonIndex] ?? {};
    final usedSeats = <String>{};

    for (int i = 0; i < _passengerCount; i++) {
      String? found;
      // Berikan kursi default 5C, 5D dst jika tersedia
      final preferred = ['5C', '5D', '6A', '6B', '3A', '3B', '4D', '2A'];
      for (final pref in preferred) {
        if (!currentOccupied.contains(pref) && !usedSeats.contains(pref)) {
          found = pref;
          break;
        }
      }
      if (found == null) {
        for (int r = 1; r <= 8; r++) {
          for (final col in ['A', 'B', 'C', 'D']) {
            final code = '$r$col';
            if (!currentOccupied.contains(code) && !usedSeats.contains(code)) {
              found = code;
              break;
            }
          }
          if (found != null) break;
        }
      }
      if (found != null) {
        _passengerSeats[i] = found;
        usedSeats.add(found);
      }
    }

    _selectedSeat = _passengerSeats[_activePassengerIdx] ?? '5C';
  }

  Set<String> get _currentOccupiedSeats =>
      _wagonOccupiedMap[_selectedWagonIndex] ?? {};

  String _findFirstAvailableSeat(int wagonIdx) {
    final occupied = _wagonOccupiedMap[wagonIdx] ?? {};
    for (int r = 1; r <= 8; r++) {
      for (final col in ['A', 'B', 'C', 'D']) {
        final code = '$r$col';
        if (!occupied.contains(code)) return code;
      }
    }
    return '1A';
  }

  void _onWagonChanged(int idx) {
    if (_selectedWagonIndex == idx) return;
    setState(() {
      _selectedWagonIndex = idx;
      _assignDefaultSeats();
    });
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _timerFormatted {
    final m = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _getSeatSide(String seatCode) {
    if (seatCode.endsWith('A') || seatCode.endsWith('D')) {
      return 'Sisi Jendela (Window)';
    }
    return 'Sisi Lorong (Aisle)';
  }

  String get _seatSideDescription {
    return _getSeatSide(_selectedSeat);
  }

  void _selectSeat(String seatCode) {
    if (_currentOccupiedSeats.contains(seatCode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kursi $seatCode sudah terisi oleh penumpang lain. Silakan pilih kursi lain.',
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1500),
        ),
      );
      return;
    }

    // Cek apakah kursi ini sudah dipilih oleh penumpang lain dalam pesanan ini
    int? otherPassengerIdx;
    _passengerSeats.forEach((idx, s) {
      if (s == seatCode && idx != _activePassengerIdx) {
        otherPassengerIdx = idx;
      }
    });

    if (otherPassengerIdx != null) {
      final pName =
          widget.passengers != null &&
                  otherPassengerIdx! < widget.passengers!.length
              ? widget.passengers![otherPassengerIdx!]['name'] ??
                  'Penumpang ${otherPassengerIdx! + 1}'
              : 'Penumpang ${otherPassengerIdx! + 1}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kursi $seatCode saat ini dialokasikan untuk $pName.'),
          backgroundColor: const Color(0xFF0256B8),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1400),
        ),
      );
      setState(() {
        _activePassengerIdx = otherPassengerIdx!;
        _selectedSeat = seatCode;
      });
      return;
    }

    setState(() {
      _passengerSeats[_activePassengerIdx] = seatCode;
      _selectedSeat = seatCode;

      // Otomatis pindah ke penumpang berikutnya yang belum memilih kursi jika ada
      if (_passengerCount > 1) {
        for (int i = 0; i < _passengerCount; i++) {
          if (!_passengerSeats.containsKey(i)) {
            _activePassengerIdx = i;
            break;
          }
        }
      }
    });
  }

  void _confirmSeat() {
    if (_passengerSeats.length < _passengerCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Silakan pilih kursi untuk seluruh penumpang terlebih dahulu!',
          ),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final currentWagon = _wagons[_selectedWagonIndex]['code'];
    final confirmedPassengers = <Map<String, String>>[];

    for (int i = 0; i < _passengerCount; i++) {
      final p =
          widget.passengers != null && i < widget.passengers!.length
              ? Map<String, String>.from(widget.passengers![i])
              : <String, String>{
                'name': widget.passengerName,
                'id': widget.passengerNik,
                'category': 'Dewasa (> 3 tahun)',
                'idType': 'NIK / KTP',
              };
      final s = _passengerSeats[i] ?? _selectedSeat;
      p['seat'] = '$currentWagon / $s';
      p['seatSide'] = _getSeatSide(s);
      confirmedPassengers.add(p);
    }

    final allSeatsStr = confirmedPassengers.map((p) => p['seat']).join(', ');

    // Lanjut ke Konfirmasi Pemesanan dengan animasi mulus
    AppPageRoute.push(
      context,
      OrderConfirmationScreen(
        train: widget.train,
        origin: widget.origin,
        dest: widget.dest,
        travelDate: widget.travelDate,
        bookerName: widget.bookerName,
        bookerEmail: widget.bookerEmail,
        bookerPhone: widget.bookerPhone,
        passengerName: confirmedPassengers[0]['name'] ?? widget.passengerName,
        passengerNik: confirmedPassengers[0]['id'] ?? widget.passengerNik,
        passengers: confirmedPassengers,
        selectedSeat: allSeatsStr,
        seatSide: confirmedPassengers[0]['seatSide'] ?? _seatSideDescription,
        totalAmount: widget.totalAmount,
        returnTrain: widget.returnTrain,
        returnDate: widget.returnDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentWagon = _wagons[_selectedWagonIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF062056)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pilih Kursi',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF062056),
              ),
            ),
            Text(
              'Langkah 2 dari 3: Pilih Gerbong & Kursi',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: Color(0xFF1D4ED8),
                ),
                const SizedBox(width: 4),
                Text(
                  _timerFormatted,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(height: 3, color: const Color(0xFF062056)),
              ),
              Expanded(
                flex: 1,
                child: Container(height: 3, color: Colors.grey.shade200),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Info Badge Kereta & Formasi Kursi
                  _buildTrainInfoBadge(),

                  const SizedBox(height: 18),

                  // 2. Pilih Gerbong Selector
                  _buildWagonSelector(),

                  const SizedBox(height: 14),

                  // 2.1 Tab Penumpang untuk Multi Penumpang
                  _buildPassengerSelector(),

                  // 3. Legend Kursi (Tersedia, Pilihan Anda, Terisi)
                  _buildLegendRow(),

                  const SizedBox(height: 16),

                  // 4. Denah Gerbong Kursi (Wagon Layout dengan Animasi Halus)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.04, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey<int>(_selectedWagonIndex),
                      child: _buildWagonSeatGrid(
                        currentWagon['code'] as String,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Sticky Bottom Bar
          _buildStickyBottomBar(currentWagon['code'] as String),
        ],
      ),
    );
  }

  // ===========================================================================
  // SUB WIDGETS (PERSIS GAMBAR 3)
  // ===========================================================================

  Widget _buildTrainInfoBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.train.availableClasses.first.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.train.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Formasi Kursi',
                    style: TextStyle(fontSize: 9.5, color: Colors.grey),
                  ),
                  Text(
                    '2-2',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.origin.name} (${widget.origin.code}) ➔ ${widget.dest.name} (${widget.dest.code})',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildWagonSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'PILIH GERBONG',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: 0.5,
              ),
            ),
            Text(
              '${_wagons[_selectedWagonIndex]['available']} kursi tersisa',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children:
              _wagons.asMap().entries.map((entry) {
                final idx = entry.key;
                final w = entry.value;
                final isSelected = _selectedWagonIndex == idx;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onWagonChanged(idx),
                    child: Container(
                      margin: EdgeInsets.only(
                        right: idx == _wagons.length - 1 ? 0 : 8,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? const Color(0xFF062056) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isSelected
                                  ? const Color(0xFF062056)
                                  : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            w['code'] as String,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color:
                                  isSelected
                                      ? Colors.white70
                                      : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            w['name'] as String,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color:
                                  isSelected
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${w['available']} Kursi',
                            style: TextStyle(
                              fontSize: 9.5,
                              color:
                                  isSelected
                                      ? Colors.white60
                                      : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildLegendRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLegendItem(
            boxColor: const Color(0xFFF8FAFC),
            borderColor: const Color(0xFFCBD5E1),
            label: 'Tersedia',
          ),
          _buildLegendItem(
            boxColor: const Color(0xFF062056),
            borderColor: const Color(0xFF062056),
            label: 'Pilihan Anda',
            icon: Icons.check,
            iconColor: Colors.white,
          ),
          _buildLegendItem(
            boxColor: const Color(0xFFE2E8F0),
            borderColor: const Color(0xFFCBD5E1),
            label: 'Terisi',
            icon: Icons.close_rounded,
            iconColor: Colors.grey.shade500,
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color boxColor,
    required Color borderColor,
    required String label,
    IconData? icon,
    Color? iconColor,
  }) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: boxColor,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: borderColor),
          ),
          child: icon != null ? Icon(icon, size: 13, color: iconColor) : null,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  Widget _buildWagonSeatGrid(String wagonCode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Banner Arah Perjalanan Kereta (Persis Gambar 3)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.arrow_upward_rounded,
                  size: 14,
                  color: Color(0xFF1D4ED8),
                ),
                SizedBox(width: 6),
                Text(
                  'Arah Perjalanan Kereta',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Header Kolom: A  B   LORONG   C  D
          const Row(
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    'A',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'B',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'LORONG',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'C',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'D',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Baris Kursi 1 sampai 8
          ...List.generate(8, (index) {
            final rowNumber = index + 1;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(child: _buildSeatItem('${rowNumber}A')),
                  Expanded(child: _buildSeatItem('${rowNumber}B')),
                  Expanded(
                    child: Center(
                      child: Text(
                        '$rowNumber',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: _buildSeatItem('${rowNumber}C')),
                  Expanded(child: _buildSeatItem('${rowNumber}D')),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPassengerSelector() {
    if (_passengerCount <= 1) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
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
              Text(
                'PENUMPANG & KURSI (${_passengerSeats.length}/$_passengerCount)',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.3,
                ),
              ),
              const Text(
                'Ketuk untuk ubah kursi',
                style: TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF0256B8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_passengerCount, (idx) {
                final isActive = _activePassengerIdx == idx;
                final pData =
                    widget.passengers != null && idx < widget.passengers!.length
                        ? widget.passengers![idx]
                        : {'name': 'Penumpang ${idx + 1}'};
                final name = pData['name'] ?? 'Penumpang ${idx + 1}';
                final seat = _passengerSeats[idx];

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _activePassengerIdx = idx;
                      if (seat != null) _selectedSeat = seat;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isActive
                              ? const Color(0xFF062056)
                              : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            isActive
                                ? const Color(0xFF062056)
                                : const Color(0xFFCBD5E1),
                        width: isActive ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isActive
                                    ? const Color(0xFFF26716)
                                    : const Color(0xFF94A3B8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'P${idx + 1}',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          name.length > 12
                              ? '${name.substring(0, 11)}...'
                              : name,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color:
                                isActive
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isActive
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            seat ?? 'Pilih',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color:
                                  isActive
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatItem(String seatCode) {
    final isOccupied = _currentOccupiedSeats.contains(seatCode);

    // Cek apakah kursi ini dipilih oleh salah satu penumpang
    int? assignedPIdx;
    _passengerSeats.forEach((idx, s) {
      if (s == seatCode) assignedPIdx = idx;
    });

    final isSelectedByActive = assignedPIdx == _activePassengerIdx;
    final isSelectedByOther =
        assignedPIdx != null && assignedPIdx != _activePassengerIdx;

    Color bg;
    Color border;
    Color textColor;

    if (isSelectedByActive) {
      bg = const Color(0xFF062056);
      border = const Color(0xFF062056);
      textColor = Colors.white;
    } else if (isSelectedByOther) {
      bg = const Color(0xFF0256B8);
      border = const Color(0xFF0256B8);
      textColor = Colors.white;
    } else if (isOccupied) {
      bg = const Color(0xFFE2E8F0);
      border = const Color(0xFFCBD5E1);
      textColor = Colors.grey.shade400;
    } else {
      bg = const Color(0xFFF8FAFC);
      border = const Color(0xFFCBD5E1);
      textColor = const Color(0xFF0F172A);
    }

    return GestureDetector(
      onTap: () => _selectSeat(seatCode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: border,
            width: (isSelectedByActive || isSelectedByOther) ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              seatCode,
              style: TextStyle(
                fontSize:
                    assignedPIdx != null && _passengerCount > 1 ? 10.5 : 11.5,
                fontWeight:
                    (isSelectedByActive || isSelectedByOther)
                        ? FontWeight.w900
                        : FontWeight.bold,
                color: textColor,
              ),
            ),
            if (assignedPIdx != null && _passengerCount > 1)
              Container(
                margin: const EdgeInsets.only(top: 1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 0.5,
                ),
                decoration: BoxDecoration(
                  color:
                      isSelectedByActive
                          ? const Color(0xFFF26716)
                          : Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'P${assignedPIdx! + 1}',
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyBottomBar(String wagonCode) {
    final wagonName = _wagons[_selectedWagonIndex]['code'];
    final seatsDisplay =
        _passengerCount > 1 ? _passengerSeats.values.join(', ') : _selectedSeat;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _passengerCount > 1
                        ? 'KURSI DIPILIH ($_passengerCount PENUMPANG)'
                        : 'KURSI DIPILIH',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$wagonName / $seatsDisplay',
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _passengerCount > 1
                        ? '${_passengerSeats.length} dari $_passengerCount kursi telah ditentukan'
                        : _seatSideDescription,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF062056),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _confirmSeat,
              child: const Row(
                children: [
                  Text(
                    'Konfirmasi Kursi',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
