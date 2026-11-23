import 'dart:async';
import 'package:flutter/material.dart';
import '../models/tracking_models.dart';
import '../services/indonesia_time_service.dart';
import '../services/train_tracking_service.dart';
import 'station_detail_screen.dart';
import 'train_detail_screen.dart';
import 'widgets/tracking_status_badge.dart';

/// C. Train Schedule & Station Directory Screen
/// Fitur Jadwal:
/// - Search schedule (debounced)
/// - Filter origin station & destination station (+ swap)
/// - Date picker (zona waktu Indonesia)
/// - Time filter (Pagi, Siang, Sore, Malam, Semua)
/// - Departure time, Arrival time, Train information, Trip status
/// + Sub-tab Daftar Stasiun Indonesia untuk akses cepat ke D. Station Information.
class TrainScheduleScreen extends StatefulWidget {
  final void Function(String tripId)? onTrackTrainOnMap;
  final void Function(String stationCode)? onFocusStationOnMap;

  const TrainScheduleScreen({
    super.key,
    this.onTrackTrainOnMap,
    this.onFocusStationOnMap,
  });

  @override
  State<TrainScheduleScreen> createState() => _TrainScheduleScreenState();
}

class _TrainScheduleScreenState extends State<TrainScheduleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _stationSearchCtrl = TextEditingController();
  Timer? _debounce;

  String _searchQuery = '';
  String _stationQuery = '';
  String? _originFilter;
  String? _destFilter;
  DateTime _selectedDate = IndonesiaTimeService.now();
  String _timeFilter = 'Semua'; // Semua, Pagi, Siang, Sore, Malam
  String _stationRegionFilter = 'Semua Wilayah';

  static const List<({String id, String label, int startH, int endH})>
      _timeSlots = [
    (id: 'Semua', label: 'Semua Jam', startH: 0, endH: 24),
    (id: 'Pagi', label: 'Pagi (00-11)', startH: 0, endH: 11),
    (id: 'Siang', label: 'Siang (11-15)', startH: 11, endH: 15),
    (id: 'Sore', label: 'Sore (15-18)', startH: 15, endH: 18),
    (id: 'Malam', label: 'Malam (18-24)', startH: 18, endH: 24),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.dispose();
    _searchCtrl.dispose();
    _stationSearchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (mounted) setState(() => _searchQuery = val.trim().toLowerCase());
    });
  }

  Future<void> _pickDate() async {
    final now = IndonesiaTimeService.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(today) ? today : _selectedDate,
      firstDate: today.subtract(const Duration(days: 7)),
      lastDate: today.add(const Duration(days: 90)),
      helpText: 'PILIH TANGGAL JADWAL',
      cancelText: 'BATAL',
      confirmText: 'PILIH',
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  void _swapOriginDest() {
    setState(() {
      final tmp = _originFilter;
      _originFilter = _destFilter;
      _destFilter = tmp;
    });
  }

  void _resetFilters() {
    _searchCtrl.clear();
    setState(() {
      _searchQuery = '';
      _originFilter = null;
      _destFilter = null;
      _timeFilter = 'Semua';
      _selectedDate = IndonesiaTimeService.now();
    });
  }

  List<TrainTripModel> _applyScheduleFilters(List<TrainTripModel> trips) {
    final slot = _timeSlots.firstWhere(
      (s) => s.id == _timeFilter,
      orElse: () => _timeSlots.first,
    );

    return trips.where((trip) {
      if (_originFilter != null && trip.originCode != _originFilter) {
        final stopsHasOrigin =
            trip.stops.any((s) => s.stationCode == _originFilter);
        if (!stopsHasOrigin) return false;
      }
      if (_destFilter != null && trip.destinationCode != _destFilter) {
        final stopsHasDest =
            trip.stops.any((s) => s.stationCode == _destFilter);
        if (!stopsHasDest) return false;
      }

      if (_timeFilter != 'Semua') {
        final depLocal = IndonesiaTimeService.toZone(trip.scheduledDeparture);
        if (depLocal.hour < slot.startH || depLocal.hour >= slot.endH) {
          return false;
        }
      }

      if (_searchQuery.isNotEmpty) {
        final hay =
            '${trip.trainNumber} ${trip.trainName} ${trip.serviceType ?? ''} ${trip.originCode} ${trip.originName} ${trip.destinationCode} ${trip.destinationName} ${trip.region}'
                .toLowerCase();
        if (!hay.contains(_searchQuery)) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062056),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Jadwal & Stasiun Kereta',
          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: IndonesiaClockPill(darkStyle: true)),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFF26716),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.schedule_rounded, size: 18), text: 'Jadwal Kereta'),
            Tab(icon: Icon(Icons.location_city_rounded, size: 18), text: 'Info Stasiun'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScheduleTab(),
          _buildStationsTab(),
        ],
      ),
    );
  }

  Widget _buildScheduleTab() {
    return ValueListenableBuilder<List<TrackStationModel>>(
      valueListenable: TrainTrackingService.stationsNotifier,
      builder: (context, stations, _) {
        return ValueListenableBuilder<List<TrainTripModel>>(
          valueListenable: TrainTrackingService.tripsNotifier,
          builder: (context, trips, _) {
            final filtered = _applyScheduleFilters(trips);
            final hasActiveFilters = _searchQuery.isNotEmpty ||
                _originFilter != null ||
                _destFilter != null ||
                _timeFilter != 'Semua';

            return Column(
              children: [
                // Panel Filter Jadwal
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    children: [
                      // Search Schedule
                      TextField(
                        controller: _searchCtrl,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Cari nama kereta, nomor KA, atau tujuan...',
                          hintStyle: TextStyle(
                              fontSize: 12.5, color: Colors.grey.shade500),
                          prefixIcon: const Icon(Icons.search_rounded,
                              size: 20, color: Color(0xFF062056)),
                          suffixIcon: hasActiveFilters
                              ? TextButton(
                                  onPressed: _resetFilters,
                                  child: const Text('Reset',
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFFF26716),
                                          fontWeight: FontWeight.bold)),
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Filter Origin & Destination + Swap
                      Row(
                        children: [
                          Expanded(
                            child: _stationDropdown(
                              label: 'Asal',
                              value: _originFilter,
                              stations: stations,
                              onChanged: (v) =>
                                  setState(() => _originFilter = v),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Tukar Asal & Tujuan',
                            onPressed: _swapOriginDest,
                            icon: const Icon(Icons.swap_horiz_rounded,
                                color: Color(0xFFF26716)),
                          ),
                          Expanded(
                            child: _stationDropdown(
                              label: 'Tujuan',
                              value: _destFilter,
                              stations: stations,
                              onChanged: (v) => setState(() => _destFilter = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Date Picker + Time Filter
                      Row(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: _pickDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFFC7D2FE)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_today_rounded,
                                      size: 14, color: Color(0xFF062056)),
                                  const SizedBox(width: 6),
                                  Text(
                                    IndonesiaTimeService.formatDate(
                                      DateTime.utc(
                                        _selectedDate.year,
                                        _selectedDate.month,
                                        _selectedDate.day,
                                      ),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF062056),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 34,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _timeSlots.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 6),
                                itemBuilder: (context, i) {
                                  final slot = _timeSlots[i];
                                  final sel = _timeFilter == slot.id;
                                  return ChoiceChip(
                                    label: Text(
                                      slot.label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: sel
                                            ? Colors.white
                                            : const Color(0xFF334155),
                                      ),
                                    ),
                                    selected: sel,
                                    selectedColor: const Color(0xFF062056),
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    side: BorderSide.none,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6),
                                    onSelected: (_) =>
                                        setState(() => _timeFilter = slot.id),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Daftar Jadwal
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.event_busy_rounded,
                                    size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 10),
                                const Text(
                                  'Tidak ada jadwal yang sesuai filter.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF062056),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF062056),
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: _resetFilters,
                                  icon: const Icon(Icons.refresh_rounded,
                                      size: 16),
                                  label: const Text('Reset Filter'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () =>
                              TrainTrackingService.loadTrackingData(),
                          color: const Color(0xFFF26716),
                          child: ListView.separated(
                            padding: const EdgeInsets.all(14),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) =>
                                _buildScheduleCard(filtered[i]),
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _stationDropdown({
    required String label,
    required String? value,
    required List<TrackStationModel> stations,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isExpanded: true,
          hint: Text(
            'Semua $label',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF062056),
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('Semua $label'),
            ),
            ...stations.map(
              (s) => DropdownMenuItem<String?>(
                value: s.code,
                child: Text(
                  '${s.code} - ${s.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildScheduleCard(TrainTripModel trip) {
    final eta = trip.computedEta;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TrainDetailScreen(
                trip: trip,
                onTrackOnMap: widget.onTrackTrainOnMap,
                onFocusStationOnMap: widget.onFocusStationOnMap,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Nama KA + Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${trip.trainNumber} • ${trip.trainName}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF062056),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${trip.serviceType ?? 'Kereta Penumpang'} • ${trip.region}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TrainStatusBadge(
                    status: trip.dataStatus,
                    delayMinutes: trip.delayMinutes,
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Jam Berangkat -> Jam Tiba
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          IndonesiaTimeService.formatTime(
                            trip.scheduledDeparture,
                            showZone: false,
                          ),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF062056),
                          ),
                        ),
                        Text(
                          '${trip.originCode} • ${trip.originName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      children: [
                        const Icon(Icons.east_rounded,
                            size: 18, color: Color(0xFFF26716)),
                        Text(
                          IndonesiaTimeService.currentTimezone.value.code,
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          IndonesiaTimeService.formatTime(
                            trip.scheduledArrival,
                            showZone: false,
                          ),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF062056),
                          ),
                        ),
                        Text(
                          '${trip.destinationCode} • ${trip.destinationName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Divider(height: 18),

              // Footer: Status Perjalanan + ETA + Lacak di Peta
              Row(
                children: [
                  Expanded(
                    child: Text(
                      eta != null
                          ? 'ETA: ${IndonesiaTimeService.formatTime(eta)} • ${trip.tripStatus}'
                          : trip.tripStatus,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: trip.dataStatus == TrainDataStatus.delayed
                            ? const Color(0xFFDC2626)
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                  if (widget.onTrackTrainOnMap != null)
                    TextButton.icon(
                      onPressed: () => widget.onTrackTrainOnMap!(trip.id),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                      ),
                      icon: const Icon(Icons.gps_fixed_rounded,
                          size: 14, color: Color(0xFFF26716)),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStationsTab() {
    return ValueListenableBuilder<List<TrackStationModel>>(
      valueListenable: TrainTrackingService.stationsNotifier,
      builder: (context, stations, _) {
        final filtered = stations.where((s) {
          if (_stationRegionFilter != 'Semua Wilayah' &&
              s.region != _stationRegionFilter) {
            return false;
          }
          if (_stationQuery.isNotEmpty) {
            final hay = '${s.code} ${s.name} ${s.city} ${s.region}'.toLowerCase();
            if (!hay.contains(_stationQuery)) return false;
          }
          return true;
        }).toList();

        return Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  TextField(
                    controller: _stationSearchCtrl,
                    onChanged: (v) =>
                        setState(() => _stationQuery = v.trim().toLowerCase()),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Cari nama stasiun, kode (GMR, BD), atau kota...',
                      hintStyle:
                          TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 20, color: Color(0xFF062056)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: TrainTrackingService.availableRegions.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, i) {
                        final reg = TrainTrackingService.availableRegions[i];
                        final sel = _stationRegionFilter == reg;
                        return ChoiceChip(
                          label: Text(
                            reg,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: sel ? Colors.white : const Color(0xFF334155),
                            ),
                          ),
                          selected: sel,
                          selectedColor: const Color(0xFF062056),
                          backgroundColor: const Color(0xFFF1F5F9),
                          side: BorderSide.none,
                          onSelected: (_) =>
                              setState(() => _stationRegionFilter = reg),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final st = filtered[i];
                  return Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      leading: Container(
                        width: 50,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF062056),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          st.code,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      title: Text(
                        st.name,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF062056),
                        ),
                      ),
                      subtitle: Text(
                        '${st.city} • ${st.region} • ${st.facilities.length} Fasilitas',
                        style: TextStyle(
                            fontSize: 11.5, color: Colors.grey.shade600),
                      ),
                      trailing:
                          const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => StationDetailScreen(
                              station: st,
                              onFocusOnLiveMap: widget.onFocusStationOnMap,
                              onTrackTrainOnMap: widget.onTrackTrainOnMap,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

