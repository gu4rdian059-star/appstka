import 'package:flutter/material.dart';
import '../services/user_db_service.dart';
import '../services/session_service.dart';
import '../tickets/my_tickets_screen.dart';
import '../payment/payment_screen.dart';

class AntarKotaScreen extends StatefulWidget {
  final String? initialOrigin;
  final String? initialDestination;
  final DateTime? initialDate;

  const AntarKotaScreen({
    super.key,
    this.initialOrigin,
    this.initialDestination,
    this.initialDate,
  });

  @override
  State<AntarKotaScreen> createState() => _AntarKotaScreenState();
}

class _AntarKotaScreenState extends State<AntarKotaScreen> {
  StationModel _originStation = const StationModel(
    code: 'GMR',
    name: 'Gambir',
    city: 'Jakarta Pusat',
    region: 'Jabodetabek',
  );

  StationModel _destStation = const StationModel(
    code: 'SBI',
    name: 'Surabaya Pasarturi',
    city: 'Surabaya',
    region: 'Jawa Timur',
  );

  late DateTime _departureDate;
  DateTime? _returnDate;
  bool _isRoundTrip = false;
  int _adultCount = 1;
  int _infantCount = 0;

  String _activePassengerName = 'Samuel';
  String _activePassengerEmail = 'kocak@co.id';
  String _activePassengerPhone = '+62 887-1287-18';
  String _activePassengerNik = '3514062607090001';

  List<RecentSearchModel> _recentSearches = [];
  bool _isLoadingSearches = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _departureDate = widget.initialDate ?? today.add(const Duration(days: 1));
    _loadStationsAndRecent();
  }

  Future<void> _loadStationsAndRecent() async {
    await UserDatabaseService.initialize();
    final allStations = await UserDatabaseService.getStations();

    final userName = await SessionService.getUserName();
    final userEmail = await SessionService.getUserEmail();
    final userPhone = await SessionService.getUserPhone();
    final userNik = await SessionService.getUserNik();

    if (mounted) {
      setState(() {
        _activePassengerName = userName;
        if (userEmail != null && userEmail.isNotEmpty) {
          _activePassengerEmail = userEmail;
        }
        _activePassengerPhone = userPhone;
        _activePassengerNik = userNik;
      });
    }

    // Inisialisasi asal & tujuan dari props jika ada
    if (widget.initialOrigin != null) {
      final found = allStations.firstWhere(
        (s) =>
            widget.initialOrigin!.contains(s.code) ||
            widget.initialOrigin!.toLowerCase().contains(s.name.toLowerCase()),
        orElse: () => _originStation,
      );
      _originStation = found;
    }

    if (widget.initialDestination != null) {
      final found = allStations.firstWhere(
        (s) =>
            widget.initialDestination!.contains(s.code) ||
            widget.initialDestination!.toLowerCase().contains(s.name.toLowerCase()),
        orElse: () => _destStation,
      );
      _destStation = found;
    }

    final recents = await UserDatabaseService.getRecentSearches();
    if (mounted) {
      setState(() {
        _recentSearches = List.from(recents);
        _isLoadingSearches = false;
      });
    }
  }

  void _swapStations() {
    setState(() {
      final temp = _originStation;
      _originStation = _destStation;
      _destStation = temp;
    });
  }

  String _formatDate(DateTime d) {
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final dayName = days[d.weekday - 1];
    final monthName = months[d.month - 1];
    return '$dayName, ${d.day} $monthName ${d.year}';
  }

  // ===========================================================================
  // 1. MODAL PILIH STASIUN SE-INDONESIA DENGAN PENCARIAN & VALIDASI
  // ===========================================================================
  void _openStationPicker(bool isOrigin) async {
    final pickedStation = await showModalBottomSheet<StationModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StationPickerModal(
        title: isOrigin ? 'Pilih Stasiun Keberangkatan' : 'Pilih Stasiun Tujuan',
        forbiddenStationCode: isOrigin ? _destStation.code : _originStation.code,
      ),
    );

    if (pickedStation != null && mounted) {
      // Validasi: Stasiun asal dan tujuan tidak boleh sama
      if (isOrigin && pickedStation.code == _destStation.code) {
        _showWarning('Stasiun asal dan tujuan tidak boleh sama!');
        return;
      }
      if (!isOrigin && pickedStation.code == _originStation.code) {
        _showWarning('Stasiun tujuan dan asal tidak boleh sama!');
        return;
      }

      setState(() {
        if (isOrigin) {
          _originStation = pickedStation;
        } else {
          _destStation = pickedStation;
        }
      });
    }
  }

  // ===========================================================================
  // 2. MODAL KONFIRMASI HAPUS PENCARIAN TERAKHIR (PREMIUM REDESIGNED POPUP)
  // ===========================================================================
  void _confirmClearAllSearches() {
    if (_recentSearches.isEmpty) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 16,
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge Icon Merah Halus
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFECACA),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.delete_sweep_rounded,
                    color: Color(0xFFDC2626),
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Judul Dialog
              const Text(
                'Hapus Riwayat Pencarian?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF062056),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 10),

              // Penjelasan Dialog
              const Text(
                'Seluruh riwayat rute dan stasiun yang pernah Anda cari akan dihapus dari akun ini. Tindakan ini tidak dapat dibatalkan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),

              // Baris Tombol Aksi
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text(
                        'Batal',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await UserDatabaseService.clearRecentSearches();
                        setState(() => _recentSearches.clear());
                        _showSuccess('Riwayat pencarian berhasil dibersihkan.');
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text(
                        'Ya, Hapus',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
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

  void _deleteSingleSearch(String id) async {
    await UserDatabaseService.deleteRecentSearch(id);
    setState(() => _recentSearches.removeWhere((s) => s.id == id));
  }

  // ===========================================================================
  // 3. PENCARIAN TIKET & PEMESANAN AKTIF DARI DATABASE
  // ===========================================================================
  void _handleSearch() async {
    // Validasi Dasar
    if (_originStation.code == _destStation.code) {
      _showWarning('Stasiun asal dan tujuan tidak boleh sama!');
      return;
    }

    if (_isRoundTrip && _returnDate != null && _returnDate!.isBefore(_departureDate)) {
      _showWarning('Tanggal pulang harus setelah tanggal berangkat!');
      return;
    }

    // 1. Simpan ke riwayat pencarian
    final searchRecord = RecentSearchModel(
      id: 'srch-${DateTime.now().millisecondsSinceEpoch}',
      originCode: _originStation.code,
      originName: _originStation.displayName,
      destCode: _destStation.code,
      destName: _destStation.displayName,
      travelDate: '${_departureDate.day} Nov 2026',
      passengers: '$_adultCount Dewasa${_infantCount > 0 ? ', $_infantCount Bayi' : ', 0 Bayi'}',
      createdAt: DateTime.now(),
    );

    await UserDatabaseService.addRecentSearch(searchRecord);
    final updated = await UserDatabaseService.getRecentSearches();
    if (mounted) {
      setState(() => _recentSearches = List.from(updated));
    }

    // 2. Ambil jadwal kereta dari UserDatabaseService
    final trainMatches = await UserDatabaseService.searchTrains(
      originCode: _originStation.code,
      destCode: _destStation.code,
    );

    if (!mounted) return;

    // 3. Buka Sheet Hasil Pencarian & Booking dengan Data Penumpang Sesuai User yang Login
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TrainSearchResultsModal(
        origin: _originStation,
        dest: _destStation,
        dateFormatted: _formatDate(_departureDate),
        trains: trainMatches,
        passengersText: '$_adultCount Dewasa${_infantCount > 0 ? ', $_infantCount Bayi' : ''}',
        passengerName: _activePassengerName,
        passengerEmail: _activePassengerEmail,
        passengerPhone: _activePassengerPhone,
        passengerNik: _activePassengerNik,
        onBookingComplete: () {
          _showSuccess('Pemesanan tiket berhasil! Tiket aktif tersimpan di Tiket Saya.');
        },
      ),
    );
  }

  void _showWarning(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: const Color(0xFFF26716),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showPassengerSheet() {
    int tempAdult = _adultCount;
    int tempInfant = _infantCount;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Pilih Jumlah Penumpang',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF062056),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dewasa',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1B1E28),
                            ),
                          ),
                          Text(
                            'Usia 3 tahun ke atas',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: tempAdult > 1
                                ? () => setModalState(() => tempAdult--)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                            color: const Color(0xFF062056),
                          ),
                          Text(
                            '$tempAdult',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: tempAdult < 4
                                ? () => setModalState(() => tempAdult++)
                                : null,
                            icon: const Icon(Icons.add_circle_outline),
                            color: const Color(0xFF062056),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bayi',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1B1E28),
                            ),
                          ),
                          Text(
                            'Di bawah 3 tahun (tidak dapat kursi)',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: tempInfant > 0
                                ? () => setModalState(() => tempInfant--)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                            color: const Color(0xFF062056),
                          ),
                          Text(
                            '$tempInfant',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: tempInfant < tempAdult
                                ? () => setModalState(() => tempInfant++)
                                : null,
                            icon: const Icon(Icons.add_circle_outline),
                            color: const Color(0xFF062056),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF062056),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _adultCount = tempAdult;
                          _infantCount = tempInfant;
                        });
                        Navigator.of(ctx).pop();
                      },
                      child: const Text(
                        'Terapkan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _pickDate(bool isReturn) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime firstDate = isReturn ? _departureDate : today;
    if (firstDate.isBefore(today)) {
      firstDate = today;
    }

    DateTime initialDate = isReturn
        ? (_returnDate ?? _departureDate.add(const Duration(days: 2)))
        : _departureDate;

    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    }

    final lastDate = today.add(const Duration(days: 180));
    if (initialDate.isAfter(lastDate)) {
      initialDate = lastDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: isReturn ? 'PILIH TANGGAL PULANG' : 'PILIH TANGGAL KEBERANGKATAN',
      cancelText: 'BATAL',
      confirmText: 'PILIH',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF062056),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1B1E28),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        if (isReturn) {
          _returnDate = picked;
        } else {
          _departureDate = picked;
          if (_returnDate != null && _returnDate!.isBefore(_departureDate)) {
            _returnDate = _departureDate.add(const Duration(days: 2));
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF062056),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ================= Header =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Antar Kota',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ================= White Body Sheet =================
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ================= Kartu Detail Perjalanan =================
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF062056).withValues(alpha: 0.06),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Detail Perjalanan',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF062056),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Kotak Asal & Tujuan
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFD),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Column(
                                    children: [
                                      // Keberangkatan (Klik untuk Pilih Stasiun se-Indonesia)
                                      InkWell(
                                        onTap: () => _openStationPicker(true),
                                        borderRadius: BorderRadius.circular(10),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.directions_train_rounded,
                                                  size: 20,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'Keberangkatan',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      _originStation.displayName,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w700,
                                                        color: Color(0xFF062056),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 44),
                                            ],
                                          ),
                                        ),
                                      ),

                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 8),
                                        child: Divider(height: 1),
                                      ),

                                      // Tujuan (Klik untuk Pilih Stasiun se-Indonesia)
                                      InkWell(
                                        onTap: () => _openStationPicker(false),
                                        borderRadius: BorderRadius.circular(10),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.directions_train_rounded,
                                                  size: 20,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'Tujuan',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      _destStation.displayName,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w700,
                                                        color: Color(0xFF062056),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 44),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Tombol Swap Stasiun
                                  Positioned(
                                    right: 4,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: _swapStations,
                                          borderRadius: BorderRadius.circular(20),
                                          child: Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.grey.shade300,
                                                width: 1,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.05),
                                                  blurRadius: 6,
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.swap_vert_rounded,
                                              color: Color(0xFF062056),
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Tanggal Keberangkatan & Switch Pulang Pergi
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFD),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _pickDate(false),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.grey.shade200),
                                                ),
                                                child: const Icon(
                                                  Icons.calendar_month_rounded,
                                                  size: 20,
                                                  color: Color(0xFF062056),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'Tanggal Keberangkatan',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      _formatDate(_departureDate),
                                                      style: const TextStyle(
                                                        fontSize: 13.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: Color(0xFF062056),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Switch Pulang Pergi (Prevent triggering date picker)
                                        GestureDetector(
                                          onTap: () {},
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              const Text(
                                                'Pulang Pergi?',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              SizedBox(
                                                height: 32,
                                                child: Transform.scale(
                                                  scale: 0.8,
                                                  child: Switch(
                                                    value: _isRoundTrip,
                                                    activeColor: const Color(0xFF062056),
                                                    onChanged: (val) {
                                                      setState(() {
                                                        _isRoundTrip = val;
                                                        if (val && _returnDate == null) {
                                                          _returnDate = _departureDate.add(const Duration(days: 2));
                                                        }
                                                      });
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Tanggal Pulang jika Round Trip aktif
                            if (_isRoundTrip) ...[
                              const SizedBox(height: 10),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFFDBA74),
                                    width: 1,
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _pickDate(true),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFFED7AA)),
                                            ),
                                            child: const Icon(
                                              Icons.calendar_month_rounded,
                                              size: 20,
                                              color: Color(0xFFF26716),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Tanggal Pulang',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFFC2410C),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _returnDate != null
                                                      ? _formatDate(_returnDate!)
                                                      : 'Pilih Tanggal Pulang',
                                                  style: const TextStyle(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFFC2410C),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(
                                            Icons.edit_calendar_rounded,
                                            size: 18,
                                            color: Color(0xFFF26716),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),

                            // Penumpang
                            InkWell(
                              onTap: _showPassengerSheet,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFD),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.person_outline_rounded,
                                      size: 21,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Penumpang',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$_adultCount Dewasa${_infantCount > 0 ? ', $_infantCount Bayi' : ', 0 Bayi'}',
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF062056),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Tombol Cari Kereta
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF062056),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: _handleSearch,
                                child: const Text(
                                  'Cari Kereta',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ================= Pencarian Terakhir (Dengan Popup Konfirmasi Hapus) =================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Pencarian Terakhir',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1B1E28),
                            ),
                          ),
                          if (_recentSearches.isNotEmpty)
                            InkWell(
                              onTap: _confirmClearAllSearches,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  'Hapus',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_isLoadingSearches)
                        const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                      else if (_recentSearches.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Text(
                              'Belum ada riwayat pencarian tiket kereta.',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          height: 154,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _recentSearches.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final item = _recentSearches[index];
                              return Container(
                                width: 260,
                                padding: const EdgeInsets.all(14),
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
                                child: Stack(
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Kereta Antar Kota',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF062056),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Column(
                                              children: [
                                                const Icon(
                                                  Icons.circle,
                                                  size: 8,
                                                  color: Color(0xFF062056),
                                                ),
                                                Container(
                                                  width: 1.5,
                                                  height: 14,
                                                  color: Colors.grey.shade300,
                                                ),
                                                const Icon(
                                                  Icons.circle,
                                                  size: 8,
                                                  color: Colors.grey,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.originName,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFF1B1E28),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    item.destName,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFF1B1E28),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Spacer(),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${item.travelDate} • ${item.passengers}',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            InkWell(
                                              onTap: () async {
                                                // Pre-fill stasiun dari kartu riwayat
                                                final all = await UserDatabaseService.getStations();
                                                final o = all.firstWhere((s) => s.code == item.originCode, orElse: () => _originStation);
                                                final d = all.firstWhere((s) => s.code == item.destCode, orElse: () => _destStation);
                                                setState(() {
                                                  _originStation = o;
                                                  _destStation = d;
                                                });
                                                _handleSearch();
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF062056),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Text(
                                                  'Cari Lagi',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),

                                    // Tombol Hapus Satuan (x)
                                    Positioned(
                                      top: -6,
                                      right: -6,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                                        onPressed: () => _deleteSingleSearch(item.id),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),

                      const SizedBox(height: 22),

                      // ================= Informasi Perjalanan =================
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F1FC),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.access_time_rounded,
                                color: Color(0xFF062056),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'INFORMASI PERJALANAN',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF062056),
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Perjalanan Tenang & Tepat Waktu',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1B1E28),
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Pengecekan tiket lebih praktis dan nyaman dengan e-ticket resmi.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.grey,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// MODAL PEMILIH STASIUN SE-INDONESIA (SEARCHABLE + REGION FILTER + VALIDATION)
// =============================================================================
class _StationPickerModal extends StatefulWidget {
  final String title;
  final String forbiddenStationCode;

  const _StationPickerModal({
    required this.title,
    required this.forbiddenStationCode,
  });

  @override
  State<_StationPickerModal> createState() => _StationPickerModalState();
}

class _StationPickerModalState extends State<_StationPickerModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedRegion = 'Semua';
  List<StationModel> _allStations = [];
  bool _isLoading = true;

  final List<String> _regions = [
    'Semua',
    'Jabodetabek',
    'Jawa Barat',
    'Jawa Tengah & DIY',
    'Jawa Timur',
    'Sumatera',
  ];

  @override
  void initState() {
    super.initState();
    _loadStations();
    _searchCtrl.addListener(() => setState(() {}));
  }

  Future<void> _loadStations() async {
    final list = await UserDatabaseService.getStations();
    if (mounted) {
      setState(() {
        _allStations = list;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<StationModel> get _filteredStations {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _allStations.where((s) {
      if (_selectedRegion != 'Semua' && s.region != _selectedRegion) {
        return false;
      }
      if (q.isNotEmpty) {
        final matchCode = s.code.toLowerCase().contains(q);
        final matchName = s.name.toLowerCase().contains(q);
        final matchCity = s.city.toLowerCase().contains(q);
        return matchCode || matchName || matchCity;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final stations = _filteredStations;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF062056),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Cari stasiun, kota, atau kode (GMR, YK, SBI)...',
                  hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.grey),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                          onPressed: () => _searchCtrl.clear(),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Region Chips
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: _regions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final r = _regions[i];
                final isSelected = _selectedRegion == r;
                return ChoiceChip(
                  label: Text(r),
                  selected: isSelected,
                  selectedColor: const Color(0xFF062056),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                  onSelected: (val) => setState(() => _selectedRegion = r),
                );
              },
            ),
          ),

          const Divider(height: 18),

          // Daftar Stasiun
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : stations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            Text(
                              'Stasiun "${_searchCtrl.text}" tidak ditemukan.',
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                        itemCount: stations.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 48),
                        itemBuilder: (context, i) {
                          final station = stations[i];
                          final isForbidden = station.code == widget.forbiddenStationCode;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            enabled: !isForbidden,
                            onTap: () => Navigator.of(context).pop(station),
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isForbidden ? Colors.grey.shade200 : const Color(0xFFE8F1FC),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.directions_train_rounded,
                                color: isForbidden ? Colors.grey : const Color(0xFF062056),
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  station.name,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: isForbidden ? Colors.grey : const Color(0xFF1B1E28),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isForbidden ? Colors.grey.shade300 : const Color(0xFF062056),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    station.code,
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              '${station.city} • ${station.region}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isForbidden ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                            trailing: isForbidden
                                ? const Text(
                                    'Stasiun Terpilih',
                                    style: TextStyle(fontSize: 10, color: Color(0xFFF26716), fontWeight: FontWeight.bold),
                                  )
                                : const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// MODAL HASIL PENCARIAN KERETA & ALUR PEMESANAN LENGKAP INTERAKTIF (UX REALISTIK)
// =============================================================================
class _TrainSearchResultsModal extends StatelessWidget {
  final StationModel origin;
  final StationModel dest;
  final String dateFormatted;
  final List<TrainScheduleModel> trains;
  final String passengersText;
  final String passengerName;
  final String passengerEmail;
  final String passengerPhone;
  final String passengerNik;
  final VoidCallback onBookingComplete;

  const _TrainSearchResultsModal({
    required this.origin,
    required this.dest,
    required this.dateFormatted,
    required this.trains,
    required this.passengersText,
    required this.passengerName,
    required this.passengerEmail,
    required this.passengerPhone,
    required this.passengerNik,
    required this.onBookingComplete,
  });

  String _formatCurrency(int amount) {
    return 'Rp${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  void _openTrainDetailsAndBooking(
    BuildContext context,
    TrainScheduleModel train, [
    String? initialClass,
  ]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TrainClassSelectionModal(
        train: train,
        origin: origin,
        dest: dest,
        dateFormatted: dateFormatted,
        initialClass: initialClass ?? train.availableClasses.first,
        passengersText: passengersText,
        passengerName: passengerName,
        passengerNik: passengerNik,
        onConfirmBooking: (selectedClass, finalFare) async {
          Navigator.of(ctx).pop(); // Tutup sheet seleksi kelas
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PaymentScreen(
                schedule: train,
                origin: origin,
                dest: dest,
                selectedClass: selectedClass,
                fare: finalFare,
                passengerName: passengerName,
                passengerEmail: passengerEmail,
                passengerPhone: passengerPhone,
                passengerNik: passengerNik,
                travelDate: dateFormatted,
                seat: '${selectedClass.substring(0, 3).toUpperCase()}-1 / ${(1 + (DateTime.now().second % 15))}A',
              ),
            ),
          );
        },
      ),
    );
  }

  void _bookTrain(
    BuildContext context,
    TrainScheduleModel train,
    String selectedClass, [
    int? customFare,
  ]) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 650));

    final booking = await UserDatabaseService.createBooking(
      schedule: train,
      selectedClass: selectedClass,
      passengerName: passengerName,
      passengerEmail: passengerEmail,
      passengerPhone: passengerPhone,
      passengerNik: passengerNik,
      travelDate: dateFormatted,
    );

    if (!context.mounted) return;
    Navigator.of(context).pop(); // Tutup loading dialog

    // Dialog Sukses Modern
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        elevation: 16,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pemesanan Berhasil!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF062056),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Kode booking ${booking.bookingId} telah diterbitkan dan tersimpan di database tiket Anda.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFD),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Kereta & Kelas', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(
                          '${booking.trainName} • ${booking.trainClass}',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF062056)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Rute', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(
                          '${origin.displayName} ➔ ${dest.displayName}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Kursi / Gerbong', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(
                          booking.seatNumber,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF26716)),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Biaya (Lunas)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        Text(
                          _formatCurrency(booking.totalAmount),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF062056)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).pop(); // Tutup search sheet
                        onBookingComplete();
                      },
                      child: const Text(
                        'Kembali',
                        style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF062056),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).pop(); // Tutup search sheet
                        onBookingComplete();
                        // Langsung buka layar Tiket Saya
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MyTicketsScreen(embedded: false),
                          ),
                        );
                      },
                      child: const Text(
                        'Lihat Tiket Saya',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFFF7F9FC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header Hasil Pencarian
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${origin.name} (${origin.code}) ➔ ${dest.name} (${dest.code})',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF062056),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$dateFormatted • $passengersText',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // List Kereta
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: trains.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, i) {
                final train = trains[i];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      onTap: () => _openTrainDetailsAndBooking(context, train),
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Baris Nama Kereta & Sisa Kursi
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF062056),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.train_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      train.name,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1B1E28),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${train.availableSeats} Kursi Tersedia',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF2E7D32),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Timeline Keberangkatan & Kedatangan
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      train.departureTime,
                                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
                                    ),
                                    Text(train.originCode, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text(train.duration, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    Row(
                                      children: [
                                        Container(width: 24, height: 1, color: Colors.grey.shade400),
                                        const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.grey),
                                        Container(width: 24, height: 1, color: Colors.grey.shade400),
                                      ],
                                    ),
                                    const Text('Langsung', style: TextStyle(fontSize: 9.5, color: Color(0xFF10B981))),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      train.arrivalTime,
                                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
                                    ),
                                    Text(train.destCode, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 22),

                            // Harga & Pilihan Kelas
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Mulai dari', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                    Text(
                                      _formatCurrency(train.baseFare),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFF26716),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    ...train.availableClasses.map((cls) {
                                      return Padding(
                                        padding: const EdgeInsets.only(left: 6),
                                        child: InkWell(
                                          onTap: () => _openTrainDetailsAndBooking(context, train, cls),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: cls == 'Luxury'
                                                  ? const Color(0xFFF26716)
                                                  : const Color(0xFF062056),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              cls,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 20,
                                      color: Color(0xFF062056),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
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

// =============================================================================
// MODAL SELEKSI KELAS & KONFIRMASI KURSI KERETA (UX DETAIL & TIKET REALISTIS)
// =============================================================================
class _TrainClassSelectionModal extends StatefulWidget {
  final TrainScheduleModel train;
  final StationModel origin;
  final StationModel dest;
  final String dateFormatted;
  final String initialClass;
  final String passengersText;
  final String passengerName;
  final String passengerNik;
  final Function(String selectedClass, int finalFare) onConfirmBooking;

  const _TrainClassSelectionModal({
    required this.train,
    required this.origin,
    required this.dest,
    required this.dateFormatted,
    required this.initialClass,
    required this.passengersText,
    required this.passengerName,
    required this.passengerNik,
    required this.onConfirmBooking,
  });

  @override
  State<_TrainClassSelectionModal> createState() => _TrainClassSelectionModalState();
}

class _TrainClassSelectionModalState extends State<_TrainClassSelectionModal> {
  late String _selectedClass;

  @override
  void initState() {
    super.initState();
    _selectedClass = widget.initialClass;
  }

  int _calculateFare(String className) {
    final base = widget.train.baseFare;
    switch (className) {
      case 'Luxury':
        return (base * 1.6).round();
      case 'Eksekutif':
        return (base * 1.35).round();
      case 'Bisnis':
        return (base * 1.15).round();
      case 'Ekonomi':
      default:
        return base;
    }
  }

  String _getClassPerks(String className) {
    switch (className) {
      case 'Luxury':
        return 'Reclining 170° • Makan & Minum Gratis • Stop Kontak • Sandaran Kaki';
      case 'Eksekutif':
        return 'Reclining 50° • AC Dingin • Colokan Listrik • Formasi 2-2';
      case 'Bisnis':
        return 'AC Dingin • Sandaran Kursi Nyaman • Formasi 2-2 • Bagasi Luas';
      case 'Ekonomi':
      default:
        return 'AC Central • Kursi Tegak Reclining • Bagasi Kabin • Stop Kontak';
    }
  }

  String _formatCurrency(int amount) {
    return 'Rp${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    final currentFare = _calculateFare(_selectedClass);

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Detail Jadwal & Pilihan Kelas',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF062056),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Card Kereta
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFD),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF062056),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.train_rounded, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.train.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF062056),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${widget.train.availableSeats} Kursi Tersedia',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.train.departureTime,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    color: Color(0xFF062056),
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  widget.origin.code,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Column(
                                  children: [
                                    Text(
                                      widget.train.duration,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Container(
                                          width: 5,
                                          height: 5,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF062056),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        Expanded(
                                          child: Container(
                                            height: 1,
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 12,
                                          color: Color(0xFF062056),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5E9),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Langsung',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Color(0xFF2E7D32),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  widget.train.arrivalTime,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    color: Color(0xFF062056),
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  widget.dest.code,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.dateFormatted} • ${widget.passengersText}',
                          style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'PILIH KELAS TIKET',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF062056),
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Opsi Tiap Kelas
                  ...widget.train.availableClasses.map((cls) {
                    final fare = _calculateFare(cls);
                    final isSelected = _selectedClass == cls;
                    final perks = _getClassPerks(cls);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () => setState(() => _selectedClass = cls),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFF0F5FF) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF062056) : Colors.grey.shade200,
                              width: isSelected ? 1.8 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                color: isSelected ? const Color(0xFF062056) : Colors.grey,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          cls,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1B1E28),
                                          ),
                                        ),
                                        Text(
                                          _formatCurrency(fare),
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w900,
                                            color: isSelected ? const Color(0xFFF26716) : const Color(0xFF062056),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      perks,
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.3),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  // Informasi Penumpang & Kursi Otomatis
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_pin_rounded, color: Color(0xFF062056), size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Penumpang: ${widget.passengerName}',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1B1E28)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Kursi Otomatis: Gerbong 2 / Kursi 7A (Jendela) • NIK: ${widget.passengerNik}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Bar & Tombol Pesan
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Total Pembayaran', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      _formatCurrency(currentFare),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFF26716),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF062056),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      widget.onConfirmBooking(_selectedClass, currentFare);
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Lanjut ke Pembayaran',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
