import 'dart:async';
import 'package:flutter/material.dart';
import '../models/tracking_models.dart';
import '../services/indonesia_time_service.dart';
import '../services/train_tracking_service.dart';
import 'station_detail_screen.dart';
import 'train_detail_screen.dart';
import 'widgets/tracking_status_badge.dart';

/// F. Global Search Screen
/// Mencari secara efisien dengan debounce (350ms) untuk:
/// - Train name
/// - Train number
/// - Station name
/// - Station code
/// - Route
class GlobalSearchScreen extends StatefulWidget {
  final void Function(String tripId)? onTrackTrainOnMap;
  final void Function(String stationCode)? onFocusStationOnMap;

  const GlobalSearchScreen({
    super.key,
    this.onTrackTrainOnMap,
    this.onFocusStationOnMap,
  });

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  bool _isSearching = false;
  GlobalSearchResult _result = const GlobalSearchResult(query: '');

  static const List<String> _quickSuggestions = [
    'Argo Bromo',
    'KA 40',
    'GMR',
    'Bandung',
    'Yogyakarta',
    'Surabaya',
    'KRL',
    'Medan',
  ];

  @override
  void initState() {
    super.initState();
    _executeSearch('');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _executeSearch(value);
    });
  }

  Future<void> _executeSearch(String query) async {
    if (!mounted) return;
    setState(() => _isSearching = true);
    try {
      final res = await TrainTrackingService.searchGlobal(query);
      if (mounted) {
        setState(() {
          _result = res;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF062056),
        elevation: 0.6,
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onQueryChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: _executeSearch,
          style: const TextStyle(fontSize: 14, color: Color(0xFF062056)),
          decoration: InputDecoration(
            hintText: 'Cari nama KA, nomor KA, stasiun, kode, rute...',
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            border: InputBorder.none,
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _controller.clear();
                      _executeSearch('');
                    },
                  )
                : null,
          ),
        ),
      ),
      body: Column(
        children: [
          // Saran cepat
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _quickSuggestions.map((tag) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF062056),
                        ),
                      ),
                      backgroundColor: const Color(0xFFF1F5F9),
                      side: BorderSide.none,
                      onPressed: () {
                        _controller.text = tag;
                        _executeSearch(tag);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          if (_isSearching)
            const LinearProgressIndicator(
              minHeight: 2.5,
              color: Color(0xFFF26716),
              backgroundColor: Color(0xFFE2E8F0),
            ),
          Expanded(
            child: _result.isEmpty && !_isSearching
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 52, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'Tidak ditemukan hasil untuk "${_result.query}"',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF062056),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Coba cari nama kereta (Argo Bromo), nomor (KA 2), kode stasiun (GMR, BD, SBI), atau rute (Jakarta Surabaya).',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_result.trains.isNotEmpty) ...[
                        _sectionHeader(
                          'Kereta & Perjalanan (${_result.trains.length})',
                          Icons.train_rounded,
                        ),
                        const SizedBox(height: 8),
                        ..._result.trains.map(_buildTrainItem),
                        const SizedBox(height: 18),
                      ],
                      if (_result.stations.isNotEmpty) ...[
                        _sectionHeader(
                          'Stasiun Indonesia (${_result.stations.length})',
                          Icons.location_city_rounded,
                        ),
                        const SizedBox(height: 8),
                        ..._result.stations.map(_buildStationItem),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFFF26716)),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF062056),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildTrainItem(TrainTripModel trip) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TrainDetailScreen(
                trip: trip,
                onTrackOnMap: (id) {
                  Navigator.of(context).pop();
                  widget.onTrackTrainOnMap?.call(id);
                },
                onFocusStationOnMap: (code) {
                  Navigator.of(context).pop();
                  widget.onFocusStationOnMap?.call(code);
                },
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: trip.dataStatus.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.train_rounded,
                    color: trip.dataStatus.color, size: 22),
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
                      '${trip.originName} (${trip.originCode}) → ${trip.destinationName} (${trip.destinationCode})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TrainStatusBadge(
                          status: trip.dataStatus,
                          delayMinutes: trip.delayMinutes,
                          compact: true,
                        ),
                        Text(
                          '${IndonesiaTimeService.formatTime(trip.scheduledDeparture, showZone: false)} - ${IndonesiaTimeService.formatTime(trip.scheduledArrival)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.onTrackTrainOnMap != null)
                IconButton(
                  tooltip: 'Lacak di Peta',
                  icon: const Icon(Icons.gps_fixed_rounded,
                      color: Color(0xFF062056), size: 20),
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onTrackTrainOnMap!(trip.id);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStationItem(TrackStationModel station) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 48,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF062056),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            station.code,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
            ),
          ),
        ),
        title: Text(
          station.name,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF062056),
          ),
        ),
        subtitle: Text(
          '${station.city} • ${station.region}',
          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StationDetailScreen(
                station: station,
                onFocusOnLiveMap: (code) {
                  Navigator.of(context).pop();
                  widget.onFocusStationOnMap?.call(code);
                },
                onTrackTrainOnMap: (id) {
                  Navigator.of(context).pop();
                  widget.onTrackTrainOnMap?.call(id);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

