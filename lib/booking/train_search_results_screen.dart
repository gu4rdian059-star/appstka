import 'package:flutter/material.dart';

import '../services/user_db_service.dart';
import 'passenger_form_screen.dart';

class TrainSearchResultsScreen extends StatefulWidget {
  final StationModel origin;
  final StationModel dest;
  final DateTime travelDate;
  final int adultCount;
  final int infantCount;

  const TrainSearchResultsScreen({
    super.key,
    required this.origin,
    required this.dest,
    required this.travelDate,
    this.adultCount = 1,
    this.infantCount = 0,
  });

  @override
  State<TrainSearchResultsScreen> createState() =>
      _TrainSearchResultsScreenState();
}

class _TrainSearchResultsScreenState extends State<TrainSearchResultsScreen> {
  late DateTime _selectedDate;
  String _selectedClassFilter = 'Semua'; // 'Semua', 'Eksekutif', 'Bisnis', 'Ekonomi'
  bool _hideRunOutTrains = false;
  String _activeSort = 'earliest'; // 'earliest', 'lowest_price', 'fastest'

  List<TrainScheduleModel> _allTrains = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.travelDate;
    _fetchTrains();
  }

  Future<void> _fetchTrains() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 200));
    final results = await UserDatabaseService.searchTrains(
      originCode: widget.origin.code,
      destCode: widget.dest.code,
    );

    // Jadwal bervariasi secara dinamis mengikuti tanggal yang dipilih
    final enriched = _enrichWithRealisticClasses(results, _selectedDate);

    if (mounted) {
      setState(() {
        _allTrains = enriched;
        _isLoading = false;
      });
    }
  }

  List<TrainScheduleModel> _enrichWithRealisticClasses(
    List<TrainScheduleModel> base,
    DateTime date,
  ) {
    final day = date.day;
    final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    final seed = (day * 7 + date.month * 11) % 4;

    final isSguToPs =
        (widget.origin.code == 'SGU' || widget.origin.code == 'SBI') &&
        (widget.dest.code == 'PS' || widget.dest.code == 'ML');

    if (isSguToPs || base.length <= 1) {
      if (seed == 0) {
        return [
          TrainScheduleModel(
            id: 'MUTIARA-209A-EKO',
            trainNumber: '209A',
            name: 'MUTIARA TIMUR (209A)',
            originCode: widget.origin.code,
            originName: widget.origin.name,
            originCity: widget.origin.city,
            destCode: widget.dest.code,
            destName: widget.dest.name,
            destCity: widget.dest.city,
            departureTime: '09.24',
            arrivalTime: '10.43',
            duration: '01j 19m',
            baseFare: 150000,
            availableClasses: ['Ekonomi (CC)'],
            availableSeats: isWeekend ? 8 : 48,
          ),
          TrainScheduleModel(
            id: 'MUTIARA-209A-EKS',
            trainNumber: '209A',
            name: 'MUTIARA TIMUR (209A)',
            originCode: widget.origin.code,
            originName: widget.origin.name,
            originCity: widget.origin.city,
            destCode: widget.dest.code,
            destName: widget.dest.name,
            destCity: widget.dest.city,
            departureTime: '09.24',
            arrivalTime: '10.43',
            duration: '01j 19m',
            baseFare: 195000,
            availableClasses: ['Eksekutif (AC)'],
            availableSeats: isWeekend ? 0 : 37,
          ),
          TrainScheduleModel(
            id: 'SRI-TANJUNG-278',
            trainNumber: '278',
            name: 'SRI TANJUNG (278)',
            originCode: widget.origin.code,
            originName: widget.origin.name,
            originCity: widget.origin.city,
            destCode: widget.dest.code,
            destName: widget.dest.name,
            destCity: widget.dest.city,
            departureTime: '13.34',
            arrivalTime: '14.52',
            duration: '01j 18m',
            baseFare: 88000,
            availableClasses: ['Ekonomi (C)'],
            availableSeats: 9,
          ),
          TrainScheduleModel(
            id: 'LOGAWA-248C',
            trainNumber: '248C',
            name: 'LOGAWA (248C)',
            originCode: widget.origin.code,
            originName: widget.origin.name,
            originCity: widget.origin.city,
            destCode: widget.dest.code,
            destName: widget.dest.name,
            destCity: widget.dest.city,
            departureTime: '14.45',
            arrivalTime: '16.18',
            duration: '01j 33m',
            baseFare: 100000,
            availableClasses: ['Ekonomi (CC)'],
            availableSeats: 52,
          ),
          TrainScheduleModel(
            id: 'ARGO-WILIS-SOLD',
            trainNumber: '02',
            name: 'KA ARGO WILIS (02)',
            originCode: widget.origin.code,
            originName: widget.origin.name,
            originCity: widget.origin.city,
            destCode: widget.dest.code,
            destName: widget.dest.name,
            destCity: widget.dest.city,
            departureTime: '17.30',
            arrivalTime: '18.45',
            duration: '01j 15m',
            baseFare: 220000,
            availableClasses: ['Eksekutif (AC)'],
            availableSeats: 0, // Habis untuk validasi
          ),
        ];
      } else if (seed == 1) {
        return [
          TrainScheduleModel(
            id: 'MUTIARA-209A-EKO',
            trainNumber: '209A',
            name: 'MUTIARA TIMUR (209A)',
            originCode: widget.origin.code,
            originName: widget.origin.name,
            originCity: widget.origin.city,
            destCode: widget.dest.code,
            destName: widget.dest.name,
            destCity: widget.dest.city,
            departureTime: '08.15',
            arrivalTime: '09.34',
            duration: '01j 19m',
            baseFare: 155000,
            availableClasses: ['Ekonomi (CC)'],
            availableSeats: 22,
          ),
          TrainScheduleModel(
            id: 'RANGGAJATI-104',
            trainNumber: '104',
            name: 'RANGGAJATI (104)',
            originCode: widget.origin.code,
            originName: widget.origin.name,
            originCity: widget.origin.city,
            destCode: widget.dest.code,
            destName: widget.dest.name,
            destCity: widget.dest.city,
            departureTime: '11.10',
            arrivalTime: '12.28',
            duration: '01j 18m',
            baseFare: 140000,
            availableClasses: ['Bisnis (B)'],
            availableSeats: 16,
          ),
          TrainScheduleModel(
            id: 'SRI-TANJUNG-278',
            trainNumber: '278',
            name: 'SRI TANJUNG (278)',
            originCode: widget.origin.code,
            originName: widget.origin.name,
            originCity: widget.origin.city,
            destCode: widget.dest.code,
            destName: widget.dest.name,
            destCity: widget.dest.city,
            departureTime: '13.34',
            arrivalTime: '14.52',
            duration: '01j 18m',
            baseFare: 90000,
            availableClasses: ['Ekonomi (C)'],
            availableSeats: 0, // Habis
          ),
          TrainScheduleModel(
            id: 'WIJAYAKUSUMA-116',
            trainNumber: '116',
            name: 'WIJAYAKUSUMA (116)',
            originCode: widget.origin.code,
            originName: widget.origin.name,
            originCity: widget.origin.city,
            destCode: widget.dest.code,
            destName: widget.dest.name,
            destCity: widget.dest.city,
            departureTime: '18.15',
            arrivalTime: '19.35',
            duration: '01j 20m',
            baseFare: 230000,
            availableClasses: ['Eksekutif (AC)'],
            availableSeats: 35,
          ),
        ];
      } else if (seed == 2) {
        return [
          TrainScheduleModel(
            id: 'MUTIARA-209A-EKS',
            trainNumber: '209A',
            name: 'MUTIARA TIMUR (209A)',
            originCode: widget.origin.code,
            originName: widget.origin.name,
            originCity: widget.origin.city,
            destCode: widget.dest.code,
            destName: widget.dest.name,
            destCity: widget.dest.city,
            departureTime: '09.24',
            arrivalTime: '10.43',
            duration: '01j 19m',
            baseFare: 190000,
            availableClasses: ['Eksekutif (AC)'],
            availableSeats: 18,
          ),
          TrainScheduleModel(
            id: 'SANCAKA-176',
            trainNumber: '176',
            name: 'SANCAKA (176)',
            originCode: widget.origin.code,
            originName: widget.origin.name,
            originCity: widget.origin.city,
            destCode: widget.dest.code,
            destName: widget.dest.name,
            destCity: widget.dest.city,
            departureTime: '15.20',
            arrivalTime: '16.42',
            duration: '01j 22m',
            baseFare: 215000,
            availableClasses: ['Eksekutif (AC)'],
            availableSeats: 41,
          ),
          TrainScheduleModel(
            id: 'LOGAWA-248C',
            trainNumber: '248C',
            name: 'LOGAWA (248C)',
            originCode: widget.origin.code,
            originName: widget.origin.name,
            originCity: widget.origin.city,
            destCode: widget.dest.code,
            destName: widget.dest.name,
            destCity: widget.dest.city,
            departureTime: '14.45',
            arrivalTime: '16.18',
            duration: '01j 33m',
            baseFare: 98000,
            availableClasses: ['Ekonomi (CC)'],
            availableSeats: 4,
          ),
          TrainScheduleModel(
            id: 'PROBOWANGI-266',
            trainNumber: '266',
            name: 'PROBOWANGI (266)',
            originCode: widget.origin.code,
            originName: widget.origin.name,
            originCity: widget.origin.city,
            destCode: widget.dest.code,
            destName: widget.dest.name,
            destCity: widget.dest.city,
            departureTime: '19.40',
            arrivalTime: '21.05',
            duration: '01j 25m',
            baseFare: 65000,
            availableClasses: ['Ekonomi (C)'],
            availableSeats: 0, // Habis
          ),
        ];
      } else {
        return [
          TrainScheduleModel(
            id: 'MUTIARA-209A-EKO',
            trainNumber: '209A',
            name: 'MUTIARA TIMUR (209A)',
            originCode: widget.origin.code,
            originName: widget.origin.name,
            originCity: widget.origin.city,
            destCode: widget.dest.code,
            destName: widget.dest.name,
            destCity: widget.dest.city,
            departureTime: '09.24',
            arrivalTime: '10.43',
            duration: '01j 19m',
            baseFare: 148000,
            availableClasses: ['Ekonomi (CC)'],
            availableSeats: 29,
          ),
          TrainScheduleModel(
            id: 'SRI-TANJUNG-278',
            trainNumber: '278',
            name: 'SRI TANJUNG (278)',
            originCode: widget.origin.code,
            originName: widget.origin.name,
            originCity: widget.origin.city,
            destCode: widget.dest.code,
            destName: widget.dest.name,
            destCity: widget.dest.city,
            departureTime: '13.34',
            arrivalTime: '14.52',
            duration: '01j 18m',
            baseFare: 88000,
            availableClasses: ['Ekonomi (C)'],
            availableSeats: 15,
          ),
          TrainScheduleModel(
            id: 'MUTIARA-209A-EKS',
            trainNumber: '209A',
            name: 'MUTIARA TIMUR (209A)',
            originCode: widget.origin.code,
            originName: widget.origin.name,
            originCity: widget.origin.city,
            destCode: widget.dest.code,
            destName: widget.dest.name,
            destCity: widget.dest.city,
            departureTime: '09.24',
            arrivalTime: '10.43',
            duration: '01j 19m',
            baseFare: 195000,
            availableClasses: ['Eksekutif (AC)'],
            availableSeats: 0, // Habis
          ),
          TrainScheduleModel(
            id: 'LOGAWA-248C',
            trainNumber: '248C',
            name: 'LOGAWA (248C)',
            originCode: widget.origin.code,
            originName: widget.origin.name,
            originCity: widget.origin.city,
            destCode: widget.dest.code,
            destName: widget.dest.name,
            destCity: widget.dest.city,
            departureTime: '14.45',
            arrivalTime: '16.18',
            duration: '01j 33m',
            baseFare: 102000,
            availableClasses: ['Ekonomi (CC)'],
            availableSeats: 38,
          ),
        ];
      }
    }

    // Untuk rute umum lainnya, variasikan kursi & harga per tanggal
    final List<TrainScheduleModel> list = [];
    for (int i = 0; i < base.length; i++) {
      final t = base[i];
      for (final cls in t.availableClasses) {
        final fare = cls == 'Luxury'
            ? (t.baseFare * 1.5).round()
            : cls == 'Eksekutif'
            ? t.baseFare
            : (t.baseFare * 0.7).round();
        final tag = cls == 'Ekonomi'
            ? 'Ekonomi (CC)'
            : cls == 'Eksekutif'
            ? 'Eksekutif (AC)'
            : 'Luxury Sleeper';
        
        final dynamicSeats = ((day * 5 + i * 11) % 65) - (isWeekend ? 15 : 0);
        final seats = dynamicSeats < 5 ? 0 : dynamicSeats;

        list.add(
          TrainScheduleModel(
            id: '${t.id}-$cls',
            trainNumber: t.trainNumber,
            name: t.name,
            originCode: t.originCode,
            originName: t.originName,
            originCity: t.originCity,
            destCode: t.destCode,
            destName: t.destName,
            destCity: t.destCity,
            departureTime: t.departureTime.replaceAll(' WIB', ''),
            arrivalTime: t.arrivalTime.replaceAll(' WIB', ''),
            duration: t.duration,
            baseFare: fare,
            availableClasses: [tag],
            availableSeats: seats,
          ),
        );
      }
    }
    return list;
  }

  List<TrainScheduleModel> get _filteredTrains {
    var list = List<TrainScheduleModel>.from(_allTrains);

    // Filter Sembunyikan Kereta Habis
    if (_hideRunOutTrains) {
      list = list.where((t) => t.availableSeats > 0).toList();
    }

    // Filter Kelas
    if (_selectedClassFilter != 'Semua') {
      list = list.where((t) {
        final cls = t.availableClasses.first.toLowerCase();
        if (_selectedClassFilter == 'Eksekutif') return cls.contains('eksekutif');
        if (_selectedClassFilter == 'Bisnis') return cls.contains('bisnis');
        if (_selectedClassFilter == 'Ekonomi') return cls.contains('ekonomi');
        return true;
      }).toList();
    }

    // Sort
    if (_activeSort == 'lowest_price') {
      list.sort((a, b) => a.baseFare.compareTo(b.baseFare));
    } else if (_activeSort == 'fastest') {
      list.sort((a, b) => a.duration.compareTo(b.duration));
    }

    return list;
  }

  void _onTrainSelected(TrainScheduleModel train) {
    // =========================================================================
    // VALIDASI TIKET HABIS (Sesuai Permintaan User)
    // =========================================================================
    if (train.availableSeats <= 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.block_rounded,
                  color: Color(0xFFDC2626),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Tiket Sudah Habis',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF062056),
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Maaf, tiket untuk kereta ${train.name} (${train.availableClasses.first}) pada tanggal ${_formatDateDisplay(_selectedDate)} sudah habis terjual.\n\nSilakan pilih jadwal keberangkatan lain atau aktifkan opsi "Hide a run out train?" untuk menampilkan kereta yang masih tersedia.',
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Color(0xFF475569),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Pilih Kereta Lain',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0256B8),
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

    // Jika tiket tersedia, lanjut ke Gambar 2: Data Penumpang
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            PassengerFormScreen(
              train: train,
              origin: widget.origin,
              dest: widget.dest,
              travelDate: _selectedDate,
              adultCount: widget.adultCount,
              infantCount: widget.infantCount,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          );
        },
      ),
    );
  }

  void _showTrainDetails(TrainScheduleModel train) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  train.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF062056),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E7FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    train.availableClasses.first,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3730A3),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.schedule_rounded,
              'Waktu Tempuh',
              '${train.duration} (Langsung)',
            ),
            _buildDetailRow(
              Icons.airline_seat_recline_extra_rounded,
              'Sisa Kursi',
              '${train.availableSeats} Kursi Tersedia',
            ),
            _buildDetailRow(
              Icons.ac_unit_rounded,
              'Fasilitas',
              'Full AC, Colokan Listrik, Bagasi 20 Kg, Toilet',
            ),
            _buildDetailRow(
              Icons.payments_outlined,
              'Tarif',
              _formatCurrency(train.baseFare),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0256B8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _onTrainSelected(train);
                },
                child: const Text(
                  'Pilih Kereta Ini',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF0256B8)),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF062056),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateDisplay(DateTime d) {
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
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _formatCurrency(int amount) {
    return 'Rp${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    final routeTitle =
        '${widget.origin.name} (${widget.origin.code}) ➔ ${widget.dest.name} (${widget.dest.code})';
    final passengersSubtitle =
        '${widget.adultCount} Dewasa${widget.infantCount > 0 ? ', ${widget.infantCount} Bayi' : ', 0 Bayi'}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF062056)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    routeTitle,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF062056),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: Color(0xFF0256B8),
                ),
              ],
            ),
            const SizedBox(height: 1),
            Text(
              passengersSubtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // 1. Horizontal Date Bar (Sat, 14 Nov, Sun, 15 Nov, dll)
          _buildDateSelector(),

          // 2. Class Filter Chips (All, Executive, Business, Economy)
          _buildClassFilterChips(),

          const Divider(height: 1),

          // 3. Section Title & List Train Cards
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0256B8)),
                  )
                : _filteredTrains.isEmpty
                ? _buildEmptyState()
                : Scrollbar(
                    thumbVisibility: false,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
                      itemCount: _filteredTrains.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Kereta Keberangkatan',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF062056),
                              ),
                            ),
                          );
                        }
                        final train = _filteredTrains[index - 1];
                        return _buildTrainCard(train);
                      },
                    ),
                  ),
          ),

          // 4. Bottom Action Bar: Filter, Sort & Hide Run Out Train
          _buildBottomFilterBar(),
        ],
      ),
    );
  }

  // ===========================================================================
  // WIDGETS
  // ===========================================================================

  Widget _buildDateSelector() {
    return Container(
      color: Colors.white,
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        itemBuilder: (context, i) {
          final date = widget.travelDate.add(Duration(days: i));
          final isSelected =
              date.day == _selectedDate.day &&
              date.month == _selectedDate.month &&
              date.year == _selectedDate.year;

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
          final dateText =
              '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';

          return InkWell(
            onTap: () {
              setState(() => _selectedDate = date);
              _fetchTrains();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected
                        ? const Color(0xFF0256B8)
                        : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
              child: Text(
                dateText,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF0256B8)
                      : const Color(0xFF475569),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildClassFilterChips() {
    final filters = ['Semua', 'Eksekutif', 'Bisnis', 'Ekonomi'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: filters.map((f) {
            final isSelected = _selectedClassFilter == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f),
                selected: isSelected,
                onSelected: (val) {
                  if (val) setState(() => _selectedClassFilter = f);
                },
                selectedColor: const Color(0xFF0256B8),
                backgroundColor: const Color(0xFFEFF6FF),
                labelStyle: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF1E40AF),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTrainCard(TrainScheduleModel train) {
    final isSoldOut = train.availableSeats <= 0;
    final category = train.availableClasses.first;
    final isEksekutif = category.toLowerCase().contains('eksekutif');
    final tagColor = isEksekutif
        ? const Color(0xFF7E22CE)
        : const Color(0xFFE11D48);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSoldOut ? Colors.grey.shade300 : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isSoldOut ? 0.02 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag Kelas di Pojok Kiri Atas & Tombol "See Details"
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tagColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _showTrainDetails(train),
                  child: const Text(
                    'Lihat Detail',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0256B8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Nama Kereta
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Text(
              train.name.toUpperCase(),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: isSoldOut
                    ? Colors.grey.shade500
                    : const Color(0xFF0F172A),
                letterSpacing: 0.3,
              ),
            ),
          ),

          // Jam Keberangkatan & Kedatangan + Rute + Durasi
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Berangkat
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      train.departureTime,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: isSoldOut
                            ? Colors.grey.shade500
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${train.originCity}\n(${train.originCode})',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey.shade600,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),

                // Garis Durasi Tengah
                Column(
                  children: [
                    Text(
                      train.duration,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 90,
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: Colors.grey.shade300,
                              thickness: 1,
                            ),
                          ),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Tiba
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      train.arrivalTime,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: isSoldOut
                            ? Colors.grey.shade500
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${train.destCity}\n(${train.destCode})',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey.shade600,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Baris Bawah: Status Sisa Kursi, Harga & Tombol "Select"
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Info Kursi & Harga
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Kursi Sisa
                    if (isSoldOut)
                      const Text(
                        'Habis / Sold Out',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                      )
                    else if (train.availableSeats > 40)
                      const Text(
                        'Tersedia',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF16A34A),
                        ),
                      )
                    else
                      Text(
                        '${train.availableSeats} Kursi Tersisa',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      _formatCurrency(train.baseFare),
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        color: isSoldOut
                            ? Colors.grey.shade500
                            : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),

                // Tombol Pilih / Habis
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSoldOut
                        ? Colors.grey.shade300
                        : const Color(0xFF0256B8),
                    elevation: isSoldOut ? 0 : 2,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _onTrainSelected(train),
                  child: Text(
                    isSoldOut ? 'Habis' : 'Pilih',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isSoldOut ? Colors.grey.shade600 : Colors.white,
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

  Widget _buildBottomFilterBar() {
    return Container(
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Baris Tombol Filter & Sort
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _showFilterDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.filter_list_rounded,
                          size: 18,
                          color: Color(0xFF0256B8),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Filter',
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
              Container(width: 1, height: 26, color: Colors.grey.shade300),
              Expanded(
                child: InkWell(
                  onTap: _showSortDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.swap_vert_rounded,
                          size: 18,
                          color: Color(0xFF0256B8),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Urutkan',
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
            ],
          ),

          // Baris Toggle "Sembunyikan kereta yang habis?" (Persis Gambar 1)
          Container(
            color: const Color(0xFFEAF2FD),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sembunyikan kereta yang habis?',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                Switch(
                  value: _hideRunOutTrains,
                  activeThumbColor: const Color(0xFF0256B8),
                  activeTrackColor: const Color(0xFF93C5FD),
                  onChanged: (val) {
                    setState(() => _hideRunOutTrains = val);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Kelas Kereta',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF062056),
              ),
            ),
            const SizedBox(height: 14),
            ...['Semua', 'Eksekutif', 'Bisnis', 'Ekonomi'].map(
              (c) => ListTile(
                title: Text(
                  c,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: _selectedClassFilter == c
                    ? const Icon(Icons.check, color: Color(0xFF0256B8))
                    : null,
                onTap: () {
                  setState(() => _selectedClassFilter = c);
                  Navigator.of(ctx).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Urutkan Jadwal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF062056),
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              title: const Text('Keberangkatan Paling Awal'),
              trailing: _activeSort == 'earliest'
                  ? const Icon(Icons.check, color: Color(0xFF0256B8))
                  : null,
              onTap: () {
                setState(() => _activeSort = 'earliest');
                Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              title: const Text('Harga Termurah'),
              trailing: _activeSort == 'lowest_price'
                  ? const Icon(Icons.check, color: Color(0xFF0256B8))
                  : null,
              onTap: () {
                setState(() => _activeSort = 'lowest_price');
                Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              title: const Text('Durasi Tercepat'),
              trailing: _activeSort == 'fastest'
                  ? const Icon(Icons.check, color: Color(0xFF0256B8))
                  : null,
              onTap: () {
                setState(() => _activeSort = 'fastest');
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.train_outlined, size: 54, color: Colors.grey),
          const SizedBox(height: 12),
          const Text(
            'Tidak ada jadwal kereta tersedia',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF062056),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Silakan pilih tanggal lain atau nonaktifkan filter.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
