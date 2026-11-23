import 'package:flutter/material.dart';

import '../services/user_db_service.dart';
import '../booking/train_search_results_screen.dart';

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
  StationModel? _originStation;
  StationModel? _destStation;

  late DateTime _departureDate;
  DateTime? _returnDate;
  bool _isRoundTrip = false;
  int _adultCount = 1;
  int _infantCount = 0;

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

    // Inisialisasi asal dari props jika ada
    if (widget.initialOrigin != null) {
      final found = allStations.where(
        (s) =>
            widget.initialOrigin!.contains(s.code) ||
            widget.initialOrigin!.toLowerCase().contains(s.name.toLowerCase()),
      ).firstOrNull;
      if (found != null) {
        _originStation = found;
      }
    }

    // Hanya isi tujuan jika diberikan secara eksplisit melalui props
    if (widget.initialDestination != null) {
      final found = allStations.where(
        (s) =>
            widget.initialDestination!.contains(s.code) ||
            widget.initialDestination!.toLowerCase().contains(
              s.name.toLowerCase(),
            ),
      ).firstOrNull;
      if (found != null) {
        _destStation = found;
      }
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
    if (_originStation == null || _destStation == null) {
      _showWarning('Silakan pilih stasiun keberangkatan dan tujuan terlebih dahulu sebelum menukar stasiun!');
      return;
    }
    setState(() {
      final temp = _originStation;
      _originStation = _destStation;
      _destStation = temp;
    });
  }

  String _formatDate(DateTime d) {
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
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
        title: isOrigin
            ? 'Pilih Stasiun Keberangkatan'
            : 'Pilih Stasiun Tujuan',
        forbiddenStationCode: isOrigin
            ? (_destStation?.code ?? '')
            : (_originStation?.code ?? ''),
      ),
    );

    if (pickedStation != null && mounted) {
      // Validasi: Stasiun asal dan tujuan tidak boleh sama
      if (isOrigin && _destStation != null && pickedStation.code == _destStation!.code) {
        _showWarning('Stasiun asal dan tujuan tidak boleh sama!');
        return;
      }
      if (!isOrigin && _originStation != null && pickedStation.code == _originStation!.code) {
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
                  border: Border.all(color: const Color(0xFFFECACA), width: 2),
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
    if (_originStation == null) {
      _showWarning('Silakan pilih stasiun keberangkatan terlebih dahulu!');
      return;
    }

    if (_destStation == null) {
      _showWarning('Silakan pilih stasiun tujuan terlebih dahulu!');
      return;
    }

    if (_originStation!.code == _destStation!.code) {
      _showWarning('Stasiun asal dan tujuan tidak boleh sama!');
      return;
    }

    if (_isRoundTrip &&
        _returnDate != null &&
        _returnDate!.isBefore(_departureDate)) {
      _showWarning('Tanggal pulang harus setelah tanggal berangkat!');
      return;
    }

    // 1. Simpan ke riwayat pencarian
    final searchRecord = RecentSearchModel(
      id: 'srch-${DateTime.now().millisecondsSinceEpoch}',
      originCode: _originStation!.code,
      originName: _originStation!.displayName,
      destCode: _destStation!.code,
      destName: _destStation!.displayName,
      travelDate: '${_departureDate.day} Nov 2026',
      passengers:
          '$_adultCount Dewasa${_infantCount > 0 ? ', $_infantCount Bayi' : ', 0 Bayi'}',
      createdAt: DateTime.now(),
    );

    await UserDatabaseService.addRecentSearch(searchRecord);
    final updated = await UserDatabaseService.getRecentSearches();
    if (mounted) {
      setState(() => _recentSearches = List.from(updated));
    }

    if (!mounted) return;

    // 2. Masuk ke Halaman Hasil Pencarian Kereta (Gambar 1)
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            TrainSearchResultsScreen(
              origin: _originStation!,
              dest: _destStation!,
              travelDate: _departureDate,
              adultCount: _adultCount,
              infantCount: _infantCount,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOutCubic,
                  ),
                ),
            child: child,
          );
        },
      ),
    );
  }

  void _showWarning(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 20,
            ),
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
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
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
      helpText: isReturn
          ? 'PILIH TANGGAL PULANG'
          : 'PILIH TANGGAL KEBERANGKATAN',
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
                              color: const Color(0xFF062056)
                                  .withValues(alpha: 0.06),
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
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons
                                                      .directions_train_rounded,
                                                  size: 20,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'Keberangkatan',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      _originStation
                                                              ?.displayName ??
                                                          'Pilih Stasiun Keberangkatan',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: _originStation !=
                                                                null
                                                            ? const Color(
                                                                0xFF062056,
                                                              )
                                                            : Colors
                                                                .grey.shade400,
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
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Divider(height: 1),
                                      ),

                                      // Tujuan (Klik untuk Pilih Stasiun se-Indonesia)
                                      InkWell(
                                        onTap: () => _openStationPicker(false),
                                        borderRadius: BorderRadius.circular(10),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons
                                                      .directions_train_rounded,
                                                  size: 20,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'Tujuan',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      _destStation?.displayName ??
                                                          'Pilih Stasiun Tujuan',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: _destStation != null
                                                            ? const Color(0xFF062056)
                                                            : Colors.grey.shade400,
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
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
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
                                                  color: Colors.black
                                                      .withValues(alpha: 0.05),
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
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: Colors.grey.shade200,
                                                  ),
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
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'Tanggal Keberangkatan',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      _formatDate(
                                                        _departureDate,
                                                      ),
                                                      style: const TextStyle(
                                                        fontSize: 13.5,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Color(
                                                          0xFF062056,
                                                        ),
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
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
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
                                                    activeThumbColor:
                                                        const Color(0xFF062056),
                                                    onChanged: (val) {
                                                      setState(() {
                                                        _isRoundTrip = val;
                                                        if (val &&
                                                            _returnDate ==
                                                                null) {
                                                          _returnDate =
                                                              _departureDate.add(
                                                                const Duration(
                                                                  days: 2,
                                                                ),
                                                              );
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
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: const Color(0xFFFED7AA),
                                              ),
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
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
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
                                                      ? _formatDate(
                                                          _returnDate!,
                                                        )
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_recentSearches.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 24,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Text(
                              'Belum ada riwayat pencarian tiket kereta.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          height: 154,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _recentSearches.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 12),
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
                                      color: Colors.black.withValues(
                                        alpha: 0.04,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.originName,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Color(0xFF1B1E28),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    item.destName,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
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
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
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
                                                final all =
                                                    await UserDatabaseService.getStations();
                                                final o = all.where(
                                                  (s) =>
                                                      s.code == item.originCode,
                                                ).firstOrNull;
                                                final d = all.where(
                                                  (s) => s.code == item.destCode,
                                                ).firstOrNull;
                                                setState(() {
                                                  if (o != null) _originStation = o;
                                                  if (d != null) _destStation = d;
                                                });
                                                _handleSearch();
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 5,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF062056,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
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
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                        onPressed: () =>
                                            _deleteSingleSearch(item.id),
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
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: Colors.grey,
                  ),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.grey,
                          ),
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
              separatorBuilder: (_, _) => const SizedBox(width: 8),
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
                        Icon(
                          Icons.search_off_rounded,
                          size: 40,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Stasiun "${_searchCtrl.text}" tidak ditemukan.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                    itemCount: stations.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 48),
                    itemBuilder: (context, i) {
                      final station = stations[i];
                      final isForbidden =
                          station.code == widget.forbiddenStationCode;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        enabled: !isForbidden,
                        onTap: () => Navigator.of(context).pop(station),
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isForbidden
                                ? Colors.grey.shade200
                                : const Color(0xFFE8F1FC),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.directions_train_rounded,
                            color: isForbidden
                                ? Colors.grey
                                : const Color(0xFF062056),
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
                                color: isForbidden
                                    ? Colors.grey
                                    : const Color(0xFF1B1E28),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isForbidden
                                    ? Colors.grey.shade300
                                    : const Color(0xFF062056),
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
                            color: isForbidden
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                        trailing: isForbidden
                            ? const Text(
                                'Stasiun Terpilih',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFFF26716),
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : const Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: Colors.grey,
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
