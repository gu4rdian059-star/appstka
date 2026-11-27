import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tracking_models.dart';
import 'indonesia_time_service.dart';
import 'session_service.dart';
import 'supabase_service.dart';

enum TrackingDataOrigin {
  supabaseRealtime,
  localDemoFallback,
}

class TrackingSnapshot {
  final List<TrackStationModel> stations;
  final List<TrainTripModel> trips;
  final TrackingDataOrigin origin;
  final String? notice;
  final bool realtimeConnected;

  const TrackingSnapshot({
    required this.stations,
    required this.trips,
    required this.origin,
    this.notice,
    this.realtimeConnected = false,
  });
}

/// Service utama Live Tracking Kereta Indonesia:
/// - Integrasi Supabase PostgreSQL (`stations`, `train_trips`, `train_trip_stops`, `user_favorites`, `user_notification_preferences`)
/// - Integrasi Supabase Realtime (`onPostgresChanges`)
/// - Simulasi gerak khusus mode DEMO (tidak pernah diberi label LIVE / real-time)
/// - Pencarian global efisien & manajemen favorit/preferensi
class TrainTrackingService {
  static const String _prefFavoritesPrefix = 'tka_favorites_v2_';
  static const String _prefUserPrefsPrefix = 'tka_user_prefs_v2_';

  static final ValueNotifier<List<TrackStationModel>> stationsNotifier =
      ValueNotifier<List<TrackStationModel>>([]);
  static final ValueNotifier<List<TrainTripModel>> tripsNotifier =
      ValueNotifier<List<TrainTripModel>>([]);
  static final ValueNotifier<List<FavoriteTrainModel>> favoritesNotifier =
      ValueNotifier<List<FavoriteTrainModel>>([]);
  static final ValueNotifier<UserNotificationPreferences> preferencesNotifier =
      ValueNotifier<UserNotificationPreferences>(
    const UserNotificationPreferences(userId: 'guest'),
  );
  static final ValueNotifier<bool> demoMovementRunning =
      ValueNotifier<bool>(false);
  static final ValueNotifier<bool> realtimeConnected =
      ValueNotifier<bool>(false);
  static final ValueNotifier<TrackingDataOrigin> dataOrigin =
      ValueNotifier<TrackingDataOrigin>(TrackingDataOrigin.localDemoFallback);
  static final ValueNotifier<String?> lastSyncNotice =
      ValueNotifier<String?>(null);

  static RealtimeChannel? _tripsChannel;
  static Timer? _demoTimer;
  static final Map<String, double> _demoProgressByTripId = {};
  static bool _optionalTrackingTablesChecked = false;
  static bool _optionalTrackingTablesAvailable = false;
  static DateTime? _lastTrackingLoadedAt;
  static const Duration _trackingCacheTtl = Duration(seconds: 30);

  static const List<String> availableRegions = [
    'Semua Wilayah',
    'Jabodetabek',
    'Jawa Barat',
    'Jawa Tengah & DIY',
    'Jawa Timur',
    'Sumatera',
  ];

  static Future<String> _resolveUserId() async {
    try {
      if (SupabaseService.isInitialized) {
        final authUser = SupabaseService.client.auth.currentUser;
        if (authUser != null && authUser.id.isNotEmpty) {
          return authUser.id;
        }
      }
    } catch (_) {}
    final savedId = await SessionService.getUserId();
    if (savedId != null && savedId.isNotEmpty) return savedId;
    final email = await SessionService.getUserEmail();
    if (email != null && email.isNotEmpty) return 'local_${email.toLowerCase()}';
    return 'guest_device';
  }

  static Future<String?> _resolveUserEmail() async {
    try {
      if (SupabaseService.isInitialized) {
        final email = SupabaseService.client.auth.currentUser?.email;
        if (email != null && email.contains('@')) return email;
      }
    } catch (_) {}
    final saved = await SessionService.getUserEmail();
    if (saved != null && saved.contains('@')) return saved;
    return null;
  }

  /// Muat data stasiun, perjalanan kereta, favorit, dan preferensi.
  /// Mengambil langsung dari Supabase Postgres terlebih dahulu.
  /// Jika tabel `train_trips` belum dibuat di Supabase, kembalikan status jujur
  /// dengan opsi fallback data DEMO (selalu berstatus DEMO / non-real-time).
  static Future<TrackingSnapshot> loadTrackingData({
    bool allowDemoFallback = true,
    bool forceRefresh = false,
  }) async {
    // Kembalikan instan dari RAM jika data tracking sudah dimuat dalam 30 detik terakhir
    if (!forceRefresh &&
        _lastTrackingLoadedAt != null &&
        DateTime.now().difference(_lastTrackingLoadedAt!) < _trackingCacheTtl &&
        tripsNotifier.value.isNotEmpty &&
        stationsNotifier.value.isNotEmpty) {
      return TrackingSnapshot(
        stations: stationsNotifier.value,
        trips: tripsNotifier.value,
        origin: dataOrigin.value,
        notice: lastSyncNotice.value,
        realtimeConnected: realtimeConnected.value,
      );
    }

    final defaultMap = {for (final s in _masterIndonesianStations) s.code: s};
    Map<String, TrackStationModel> stationByCode = Map.of(defaultMap);
    List<TrainTripModel> loadedTrips = [];
    TrackingDataOrigin origin = TrackingDataOrigin.localDemoFallback;
    String? notice;

    if (SupabaseService.isInitialized) {
      final client = SupabaseService.client;

      // 1. Muat stasiun dari Supabase (kolom yang dibutuhkan saja)
      try {
        final stationRows = await client.from('stations').select('*');
        for (final row in stationRows) {
          final map = Map<String, dynamic>.from(row);
          final code = (map['code'] ?? '').toString().trim().toUpperCase();
          if (code.isEmpty) continue;
          final fallback = defaultMap[code];
          final hasLatLng = map['latitude'] is num && map['longitude'] is num;
          final parsedFacilities = map['facilities'] is List
              ? (map['facilities'] as List).map((e) => e.toString()).toList()
              : (fallback?.facilities ?? <String>[]);

          stationByCode[code] = TrackStationModel(
            code: code,
            name: (map['name'] ?? fallback?.name ?? code).toString(),
            city: (map['city'] ?? fallback?.city ?? '').toString(),
            region: (map['region'] ?? fallback?.region ?? 'Jawa').toString(),
            address: (map['address'] ?? fallback?.address ?? 'Alamat stasiun belum dilengkapi')
                .toString(),
            latitude: hasLatLng
                ? (map['latitude'] as num).toDouble()
                : (fallback?.latitude ?? -6.176655),
            longitude: hasLatLng
                ? (map['longitude'] as num).toDouble()
                : (fallback?.longitude ?? 106.830583),
            timezone: (map['timezone'] ?? fallback?.timezone ?? 'WIB').toString(),
            facilities: parsedFacilities,
          );
        }
      } catch (e) {
        debugPrint('Catatan query stations Supabase: $e');
      }

      // 2. Muat train_trips & train_trip_stops dari Supabase Postgres bila tabel sudah dimigrasi
      if (!_optionalTrackingTablesChecked || _optionalTrackingTablesAvailable) {
        try {
          final tripRows = await client
              .from('train_trips')
              .select('*')
              .order('scheduled_departure', ascending: true);

          if (tripRows.isNotEmpty) {
            _optionalTrackingTablesChecked = true;
            _optionalTrackingTablesAvailable = true;
            Map<String, List<TrainStopModel>> stopsByTrip = {};
            try {
              final stopRows = await client
                  .from('train_trip_stops')
                  .select('*')
                  .order('stop_sequence', ascending: true);
              for (final row in stopRows) {
                final map = Map<String, dynamic>.from(row);
                final code = (map['station_code'] ?? '').toString().toUpperCase();
                final stop = TrainStopModel.fromMap(map, station: stationByCode[code]);
                stopsByTrip.putIfAbsent(stop.tripId, () => []).add(stop);
              }
            } catch (stopErr) {
              debugPrint('Catatan query train_trip_stops: $stopErr');
            }

            loadedTrips = tripRows
                .map((row) {
                  final map = Map<String, dynamic>.from(row);
                  final id = (map['id'] ?? '').toString();
                  return TrainTripModel.fromMap(
                    map,
                    stationByCode: stationByCode,
                    stops: stopsByTrip[id] ?? const [],
                  );
                })
                .toList();
            origin = TrackingDataOrigin.supabaseRealtime;
            _subscribeRealtime(stationByCode);
          } else {
            _optionalTrackingTablesChecked = true;
            _optionalTrackingTablesAvailable = false;
            loadedTrips = _buildHonestDemoTrips(stationByCode);
            origin = TrackingDataOrigin.localDemoFallback;
          }
        } catch (tripErr) {
          _optionalTrackingTablesChecked = true;
          _optionalTrackingTablesAvailable = false;
          if (!allowDemoFallback) {
            rethrow;
          }
          loadedTrips = _buildHonestDemoTrips(stationByCode);
          origin = TrackingDataOrigin.localDemoFallback;
          notice =
              'Menampilkan rute dari PostgREST stations & train_schedules (jalankan supabase_master_fix_200.sql untuk tabel train_trips).';
        }
      } else {
        loadedTrips = _buildHonestDemoTrips(stationByCode);
        origin = TrackingDataOrigin.localDemoFallback;
      }
    } else {
      if (!allowDemoFallback) {
        throw Exception('Koneksi Supabase belum terinisialisasi.');
      }
      loadedTrips = _buildHonestDemoTrips(stationByCode);
      origin = TrackingDataOrigin.localDemoFallback;
      notice =
          'Supabase belum aktif — menampilkan data Mode Demo/Simulasi (BUKAN data real-time).';
    }

    final stationsList = stationByCode.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    stationsNotifier.value = stationsList;
    tripsNotifier.value = loadedTrips;
    dataOrigin.value = origin;
    lastSyncNotice.value = notice;

    // Seed progress awal untuk trip simulasi
    for (final t in loadedTrips) {
      if (t.isSimulated && t.routeGeometry.length >= 2) {
        _demoProgressByTripId.putIfAbsent(
          t.id,
          () => _estimateProgressOnRoute(t),
        );
      }
    }

    // Muat favorit & preferensi secara paralel
    await Future.wait([
      loadFavorites(),
      loadPreferences(),
    ]);

    _lastTrackingLoadedAt = DateTime.now();

    return TrackingSnapshot(
      stations: stationsList,
      trips: loadedTrips,
      origin: origin,
      notice: notice,
      realtimeConnected: realtimeConnected.value,
    );
  }

  /// Berlangganan Supabase Realtime pada `public.train_trips` agar perubahan
  /// koordinat, status, atau keterlambatan dari server langsung memperbarui peta.
  static void _subscribeRealtime(Map<String, TrackStationModel> stationByCode) {
    if (!SupabaseService.isInitialized) return;
    try {
      _tripsChannel?.unsubscribe();
      final client = SupabaseService.client;
      _tripsChannel = client
          .channel('public:train_trips_live')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'train_trips',
            callback: (payload) {
              _handleRealtimeTripPayload(payload, stationByCode);
            },
          )
          .subscribe((status, [error]) {
            realtimeConnected.value =
                status == RealtimeSubscribeStatus.subscribed;
            debugPrint('📡 Supabase Realtime train_trips status: $status');
          });
    } catch (e) {
      realtimeConnected.value = false;
      debugPrint('⚠️ Gagal subscribe Supabase Realtime: $e');
    }
  }

  static void _handleRealtimeTripPayload(
    PostgresChangePayload payload,
    Map<String, TrackStationModel> stationByCode,
  ) {
    final current = List<TrainTripModel>.from(tripsNotifier.value);
    if (payload.eventType == PostgresChangeEvent.delete) {
      final oldId = payload.oldRecord['id']?.toString();
      if (oldId != null) {
        current.removeWhere((t) => t.id == oldId);
        tripsNotifier.value = current;
      }
      return;
    }

    final record = payload.newRecord;
    if (record.isEmpty) return;

    final id = record['id']?.toString() ?? '';
    final existingIdx = current.indexWhere((t) => t.id == id);
    final existingStops =
        existingIdx >= 0 ? current[existingIdx].stops : const <TrainStopModel>[];

    final updated = TrainTripModel.fromMap(
      Map<String, dynamic>.from(record),
      stationByCode: stationByCode,
      stops: existingStops,
    );

    if (existingIdx >= 0) {
      current[existingIdx] = updated;
    } else {
      current.add(updated);
    }
    tripsNotifier.value = current;
  }

  /// Aktifkan / hentikan simulasi pergerakan kereta KHUSUS untuk trip bertanda `isSimulated == true`.
  /// ATURAN KETAT: Tidak pernah mengubah status `DEMO` menjadi `LIVE`.
  static void setDemoMovementEnabled(bool enabled) {
    demoMovementRunning.value = enabled;
    _demoTimer?.cancel();
    _demoTimer = null;

    if (!enabled) return;

    // Interval 4 detik (50% lebih hemat CPU/GPU WebGL dibanding 2 detik)
    _demoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _advanceDemoTrainsOneTick();
    });
  }

  static void _advanceDemoTrainsOneTick() {
    final trips = List<TrainTripModel>.from(tripsNotifier.value);
    bool changed = false;

    for (int i = 0; i < trips.length; i++) {
      final trip = trips[i];
      // Hanya gerakkan kereta yang jelas-jelas simulasi dan memiliki jalur
      if (!trip.isSimulated ||
          trip.dataStatus == TrainDataStatus.unavailable ||
          trip.dataStatus == TrainDataStatus.scheduled ||
          trip.routeGeometry.length < 2) {
        continue;
      }

      double progress = _demoProgressByTripId[trip.id] ?? 0.35;
      progress += 0.012; // Maju bertahap di sepanjang jalur rel
      if (progress >= 0.98) {
        progress = 0.04;
      }
      _demoProgressByTripId[trip.id] = progress;

      final interpolated = _interpolateAlongPolyline(trip.routeGeometry, progress);
      final remainingKm = TrainTripModel.haversineKm(
        interpolated.point.lat,
        interpolated.point.lng,
        trip.routeGeometry.last.lat,
        trip.routeGeometry.last.lng,
      );
      final speed = (trip.speedKmh ?? 92.0).clamp(45.0, 120.0);
      final etaMins = ((remainingKm / speed) * 60).round();

      // Update status stop berdasarkan progress
      final updatedStops = <TrainStopModel>[];
      final totalStops = trip.stops.length;
      String? currentCode = trip.currentStationCode;
      String? nextCode = trip.nextStationCode;
      if (totalStops >= 2) {
        final passedCount = (progress * (totalStops - 1)).floor();
        for (int sIdx = 0; sIdx < totalStops; sIdx++) {
          final st = trip.stops[sIdx];
          final stStatus = sIdx < passedCount
              ? 'PASSED'
              : (sIdx == passedCount ? 'PASSED' : 'UPCOMING');
          updatedStops.add(st.copyWith(stopStatus: stStatus));
        }
        currentCode = trip.stops[passedCount.clamp(0, totalStops - 1)].stationCode;
        nextCode = trip.stops[(passedCount + 1).clamp(0, totalStops - 1)].stationCode;
      }

      trips[i] = trip.copyWith(
        currentLat: interpolated.point.lat,
        currentLng: interpolated.point.lng,
        heading: interpolated.bearing,
        currentStationCode: currentCode,
        nextStationCode: nextCode,
        estimatedArrival: DateTime.now().toUtc().add(Duration(minutes: etaMins)),
        lastUpdatedAt: DateTime.now().toUtc(),
        stops: updatedStops.isNotEmpty ? updatedStops : trip.stops,
      );
      changed = true;
    }

    if (changed) {
      tripsNotifier.value = trips;
    }
  }

  /// Muat data contoh Mode Demo (bila user menekan tombol "Muat Data Demo" pada Empty/Error state).
  static void loadDemoDatasetExplicitly() {
    final stationByCode = {
      for (final s in (stationsNotifier.value.isNotEmpty
          ? stationsNotifier.value
          : _masterIndonesianStations))
        s.code: s,
    };
    final demoTrips = _buildHonestDemoTrips(stationByCode);
    stationsNotifier.value = stationByCode.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    tripsNotifier.value = demoTrips;
    dataOrigin.value = TrackingDataOrigin.localDemoFallback;
    lastSyncNotice.value =
        'Mode Demo / Simulasi aktif — data simulasi bukan posisi GPS real-time.';
    for (final t in demoTrips) {
      if (t.isSimulated && t.routeGeometry.length >= 2) {
        _demoProgressByTripId[t.id] = _estimateProgressOnRoute(t);
      }
    }
  }

  /// F. Global Search (train name, train number, station name, station code, route).
  /// Menggunakan query efisien Supabase + merge cache lokal.
  static Future<GlobalSearchResult> searchGlobal(String rawQuery) async {
    final q = rawQuery.trim();
    if (q.isEmpty) {
      return GlobalSearchResult(
        query: '',
        trains: tripsNotifier.value,
        stations: stationsNotifier.value.take(12).toList(),
      );
    }

    final lower = q.toLowerCase();
    final tokens = lower.split(RegExp(r'[\s\-]+')).where((t) => t.isNotEmpty).toList();

    final stationByCode = {for (final s in stationsNotifier.value) s.code: s};
    final Map<String, TrackStationModel> matchedStations = {};
    final Map<String, TrainTripModel> matchedTrips = {};

    // 1. Query efisien ke Supabase Postgres (jika tabel tersedia)
    if (SupabaseService.isInitialized && q.length >= 2) {
      try {
        final pattern = '%$q%';
        final results = await Future.wait([
          SupabaseService.client
              .from('stations')
              .select('*')
              .or('name.ilike.$pattern,code.ilike.$pattern,city.ilike.$pattern,region.ilike.$pattern')
              .limit(15),
          SupabaseService.client
              .from('train_trips')
              .select('*')
              .or('train_name.ilike.$pattern,train_number.ilike.$pattern,origin_station_code.ilike.$pattern,destination_station_code.ilike.$pattern,region.ilike.$pattern')
              .limit(20),
        ]);

        for (final row in results[0]) {
          final map = Map<String, dynamic>.from(row);
          final code = (map['code'] ?? '').toString().toUpperCase();
          final existing = stationByCode[code];
          if (existing != null) {
            matchedStations[code] = existing;
          } else if (code.isNotEmpty) {
            matchedStations[code] = TrackStationModel.fromMap(map);
          }
        }

        for (final row in results[1]) {
          final map = Map<String, dynamic>.from(row);
          final trip = TrainTripModel.fromMap(map, stationByCode: stationByCode);
          matchedTrips[trip.id] = trip;
        }
      } catch (_) {
        // Fallback lancar ke pencocokan lokal bila tabel train_trips belum dimigrasi
      }
    }

    // 2. Pencocokan lokal lengkap (termasuk pencarian rute seperti "Jakarta Surabaya" / "GMR BD")
    for (final s in stationsNotifier.value) {
      final hay = '${s.code} ${s.name} ${s.city} ${s.region}'.toLowerCase();
      if (hay.contains(lower) || tokens.every((t) => hay.contains(t))) {
        matchedStations[s.code] = s;
      }
    }

    final Set<String> routes = {};
    for (final trip in tripsNotifier.value) {
      final originStation = stationByCode[trip.originCode];
      final destStation = stationByCode[trip.destinationCode];
      final routeHay = [
        trip.trainName,
        trip.trainNumber,
        trip.serviceType ?? '',
        trip.originCode,
        trip.originName,
        originStation?.city ?? '',
        trip.destinationCode,
        trip.destinationName,
        destStation?.city ?? '',
        trip.region,
      ].join(' ').toLowerCase();

      if (routeHay.contains(lower) || tokens.every((t) => routeHay.contains(t))) {
        matchedTrips[trip.id] = trip;
        routes.add('${trip.originCode} → ${trip.destinationCode} (${trip.trainName})');
      }
    }

    return GlobalSearchResult(
      query: q,
      trains: matchedTrips.values.toList(),
      stations: matchedStations.values.toList(),
      matchedRoutes: routes.toList(),
    );
  }

  /// D. Jadwal Kedatangan di sebuah stasiun (baik sebagai tujuan akhir maupun pemberhentian transit).
  static List<({TrainTripModel trip, DateTime? time, String? platform})>
      getStationArrivals(String stationCode) {
    final code = stationCode.toUpperCase();
    final List<({TrainTripModel trip, DateTime? time, String? platform})> list = [];

    for (final trip in tripsNotifier.value) {
      final matchingStops =
          trip.stops.where((s) => s.stationCode == code && s.scheduledArrival != null);
      if (matchingStops.isNotEmpty) {
        final stop = matchingStops.first;
        list.add((
          trip: trip,
          time: stop.estimatedArrival ?? stop.scheduledArrival,
          platform: stop.platform,
        ));
      } else if (trip.destinationCode == code) {
        list.add((
          trip: trip,
          time: trip.computedEta ?? trip.scheduledArrival,
          platform: null,
        ));
      }
    }

    list.sort((a, b) {
      if (a.time == null) return 1;
      if (b.time == null) return -1;
      return a.time!.compareTo(b.time!);
    });
    return list;
  }

  /// D. Jadwal Keberangkatan dari sebuah stasiun.
  static List<({TrainTripModel trip, DateTime? time, String? platform})>
      getStationDepartures(String stationCode) {
    final code = stationCode.toUpperCase();
    final List<({TrainTripModel trip, DateTime? time, String? platform})> list = [];

    for (final trip in tripsNotifier.value) {
      final matchingStops = trip.stops
          .where((s) => s.stationCode == code && s.scheduledDeparture != null);
      if (matchingStops.isNotEmpty) {
        final stop = matchingStops.first;
        list.add((
          trip: trip,
          time: stop.estimatedDeparture ?? stop.scheduledDeparture,
          platform: stop.platform,
        ));
      } else if (trip.originCode == code) {
        list.add((
          trip: trip,
          time: trip.scheduledDeparture.add(Duration(minutes: trip.delayMinutes)),
          platform: null,
        ));
      }
    }

    list.sort((a, b) {
      if (a.time == null) return 1;
      if (b.time == null) return -1;
      return a.time!.compareTo(b.time!);
    });
    return list;
  }

  /// D. Daftar kereta yang melayani stasiun tertentu.
  static List<TrainTripModel> getTrainsServingStation(String stationCode) {
    final code = stationCode.toUpperCase();
    return tripsNotifier.value.where((trip) {
      if (trip.originCode == code || trip.destinationCode == code) return true;
      return trip.stops.any((s) => s.stationCode == code);
    }).toList();
  }

  // ===========================================================================
  // G. FAVORITES CRUD (Supabase user_favorites + SharedPreferences)
  // ===========================================================================

  static Future<List<FavoriteTrainModel>> loadFavorites() async {
    final userId = await _resolveUserId();
    final local = await _loadLocalFavorites(userId);

    if (SupabaseService.isInitialized && _optionalTrackingTablesAvailable) {
      try {
        final rows = await SupabaseService.client
            .from('user_favorites')
            .select('*')
            .eq('user_id', userId)
            .order('created_at', ascending: false);

        final remote = rows
            .map((e) => FavoriteTrainModel.fromMap(Map<String, dynamic>.from(e)))
            .toList();

        final Map<String, FavoriteTrainModel> merged = {
          for (final item in local) item.uniqueKey: item,
        };
        for (final item in remote) {
          merged[item.uniqueKey] = item;
        }
        final result = merged.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        await _saveLocalFavorites(userId, result);
        favoritesNotifier.value = result;
        return result;
      } catch (e) {
        debugPrint('Catatan load user_favorites Supabase: $e');
      }
    }

    favoritesNotifier.value = local;
    return local;
  }

  static bool isTripFavorite(TrainTripModel trip) {
    final key =
        '${trip.trainNumber.toUpperCase()}_${trip.originCode.toUpperCase()}_${trip.destinationCode.toUpperCase()}';
    return favoritesNotifier.value.any((f) => f.uniqueKey == key);
  }

  static Future<bool> toggleFavorite(TrainTripModel trip) async {
    final userId = await _resolveUserId();
    final email = await _resolveUserEmail();
    final key =
        '${trip.trainNumber.toUpperCase()}_${trip.originCode.toUpperCase()}_${trip.destinationCode.toUpperCase()}';

    final list = List<FavoriteTrainModel>.from(favoritesNotifier.value);
    final idx = list.indexWhere((f) => f.uniqueKey == key);

    if (idx >= 0) {
      final removed = list.removeAt(idx);
      favoritesNotifier.value = list;
      await _saveLocalFavorites(userId, list);

      if (SupabaseService.isInitialized && _optionalTrackingTablesAvailable) {
        try {
          await SupabaseService.client
              .from('user_favorites')
              .delete()
              .eq('user_id', userId)
              .eq('train_number', removed.trainNumber)
              .eq('origin_station_code', removed.originCode)
              .eq('destination_station_code', removed.destinationCode);
        } catch (_) {}
      }
      return false;
    }

    final newFav = FavoriteTrainModel(
      id: 'fav-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      userEmail: email,
      tripId: trip.id,
      trainNumber: trip.trainNumber,
      trainName: trip.trainName,
      originCode: trip.originCode,
      destinationCode: trip.destinationCode,
      createdAt: DateTime.now().toUtc(),
    );

    list.insert(0, newFav);
    favoritesNotifier.value = list;
    await _saveLocalFavorites(userId, list);

    if (SupabaseService.isInitialized && _optionalTrackingTablesAvailable) {
      try {
        await SupabaseService.client.from('user_favorites').upsert(
          {
            'user_id': userId,
            'user_email': email,
            'trip_id': trip.id,
            'train_number': trip.trainNumber,
            'train_name': trip.trainName,
            'origin_station_code': trip.originCode,
            'destination_station_code': trip.destinationCode,
            'notify_delay': true,
            'notify_schedule_change': true,
            'notify_service_disruption': true,
            'notify_arrival_info': true,
            'notify_status_change': true,
          },
          onConflict: 'user_id,train_number,origin_station_code,destination_station_code',
        );
      } catch (e) {
        debugPrint('Catatan upsert user_favorites Supabase: $e');
      }
    }
    return true;
  }

  static Future<void> updateFavorite(FavoriteTrainModel updated) async {
    final userId = await _resolveUserId();
    final list = List<FavoriteTrainModel>.from(favoritesNotifier.value);
    final idx = list.indexWhere((f) => f.uniqueKey == updated.uniqueKey);
    if (idx >= 0) {
      list[idx] = updated;
      favoritesNotifier.value = list;
      await _saveLocalFavorites(userId, list);
    }

    if (SupabaseService.isInitialized && _optionalTrackingTablesAvailable) {
      try {
        await SupabaseService.client
            .from('user_favorites')
            .update({
              'notify_delay': updated.notifyDelay,
              'notify_schedule_change': updated.notifyScheduleChange,
              'notify_service_disruption': updated.notifyServiceDisruption,
              'notify_arrival_info': updated.notifyArrivalInfo,
              'notify_status_change': updated.notifyStatusChange,
            })
            .eq('user_id', userId)
            .eq('train_number', updated.trainNumber)
            .eq('origin_station_code', updated.originCode)
            .eq('destination_station_code', updated.destinationCode);
      } catch (_) {}
    }
  }

  static Future<void> removeFavorite(FavoriteTrainModel fav) async {
    final userId = await _resolveUserId();
    final list = List<FavoriteTrainModel>.from(favoritesNotifier.value)
      ..removeWhere((f) => f.uniqueKey == fav.uniqueKey);
    favoritesNotifier.value = list;
    await _saveLocalFavorites(userId, list);

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.client
            .from('user_favorites')
            .delete()
            .eq('user_id', userId)
            .eq('train_number', fav.trainNumber)
            .eq('origin_station_code', fav.originCode)
            .eq('destination_station_code', fav.destinationCode);
      } catch (_) {}
    }
  }

  // ===========================================================================
  // H. USER NOTIFICATION PREFERENCES & APP SETTINGS
  // ===========================================================================

  static Future<UserNotificationPreferences> loadPreferences() async {
    final userId = await _resolveUserId();
    final email = await _resolveUserEmail();
    UserNotificationPreferences prefsModel =
        await _loadLocalPreferences(userId, email);

    if (SupabaseService.isInitialized && _optionalTrackingTablesAvailable) {
      try {
        final row = await SupabaseService.client
            .from('user_notification_preferences')
            .select('*')
            .eq('user_id', userId)
            .maybeSingle();

        if (row != null) {
          prefsModel = UserNotificationPreferences.fromMap(
            Map<String, dynamic>.from(row),
          );
          await _saveLocalPreferences(userId, prefsModel);
        }
      } catch (e) {
        debugPrint('Catatan load user_notification_preferences: $e');
      }
    }

    preferencesNotifier.value = prefsModel;
    await IndonesiaTimeService.setTimezone(
      IndonesiaTimezone.fromCode(prefsModel.preferredTimezone),
    );
    return prefsModel;
  }

  static Future<void> savePreferences(
    UserNotificationPreferences updated,
  ) async {
    final userId = await _resolveUserId();
    final email = updated.userEmail ?? await _resolveUserEmail();
    final finalModel = updated.copyWith(userEmail: email);

    preferencesNotifier.value = finalModel;
    await _saveLocalPreferences(userId, finalModel);
    await IndonesiaTimeService.setTimezone(
      IndonesiaTimezone.fromCode(finalModel.preferredTimezone),
    );

    if (SupabaseService.isInitialized && _optionalTrackingTablesAvailable) {
      try {
        await SupabaseService.client
            .from('user_notification_preferences')
            .upsert(finalModel.toMap(), onConflict: 'user_id');
      } catch (e) {
        debugPrint('Catatan upsert user_notification_preferences: $e');
      }
    }
  }

  // ===========================================================================
  // INTERNAL HELPERS: GEOMETRY, LOCAL CACHE & HONEST DEMO DATASET
  // ===========================================================================

  static double _estimateProgressOnRoute(TrainTripModel trip) {
    if (!trip.hasValidPosition || trip.routeGeometry.length < 2) return 0.3;
    double bestDist = double.infinity;
    int bestIdx = 0;
    for (int i = 0; i < trip.routeGeometry.length; i++) {
      final d = TrainTripModel.haversineKm(
        trip.currentLat!,
        trip.currentLng!,
        trip.routeGeometry[i].lat,
        trip.routeGeometry[i].lng,
      );
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    return (bestIdx / (trip.routeGeometry.length - 1)).clamp(0.05, 0.92);
  }

  static ({GeoPoint point, double bearing}) _interpolateAlongPolyline(
    List<GeoPoint> points,
    double progress,
  ) {
    if (points.length == 1) return (point: points.first, bearing: 90.0);

    final segmentLengths = <double>[];
    double totalLength = 0;
    for (int i = 0; i < points.length - 1; i++) {
      final len = TrainTripModel.haversineKm(
        points[i].lat,
        points[i].lng,
        points[i + 1].lat,
        points[i + 1].lng,
      );
      segmentLengths.add(len);
      totalLength += len;
    }

    if (totalLength <= 0) return (point: points.first, bearing: 90.0);
    final targetDist = progress.clamp(0.0, 1.0) * totalLength;
    double acc = 0;

    for (int i = 0; i < segmentLengths.length; i++) {
      final segLen = segmentLengths[i];
      if (acc + segLen >= targetDist || i == segmentLengths.length - 1) {
        final localT =
            segLen > 0 ? ((targetDist - acc) / segLen).clamp(0.0, 1.0) : 0.0;
        final p1 = points[i];
        final p2 = points[i + 1];
        final lat = p1.lat + (p2.lat - p1.lat) * localT;
        final lng = p1.lng + (p2.lng - p1.lng) * localT;
        final bearing = _computeBearing(p1.lat, p1.lng, p2.lat, p2.lng);
        return (point: GeoPoint(lat, lng), bearing: bearing);
      }
      acc += segLen;
    }

    return (point: points.last, bearing: 90.0);
  }

  static double _computeBearing(
      double lat1, double lon1, double lat2, double lon2) {
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dLon);
    final deg = math.atan2(y, x) * 180 / math.pi;
    return (deg + 360) % 360;
  }

  static Future<List<FavoriteTrainModel>> _loadLocalFavorites(
      String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefFavoritesPrefix$userId');
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => FavoriteTrainModel.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveLocalFavorites(
    String userId,
    List<FavoriteTrainModel> list,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_prefFavoritesPrefix$userId',
        jsonEncode(list.map((e) => e.toMap()).toList()),
      );
    } catch (_) {}
  }

  static Future<UserNotificationPreferences> _loadLocalPreferences(
    String userId,
    String? email,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefUserPrefsPrefix$userId');
      if (raw != null && raw.isNotEmpty) {
        return UserNotificationPreferences.fromMap(
          Map<String, dynamic>.from(jsonDecode(raw)),
        );
      }
    } catch (_) {}
    return UserNotificationPreferences(
      userId: userId,
      userEmail: email,
      preferredTimezone: IndonesiaTimeService.currentTimezone.value.code,
    );
  }

  static Future<void> _saveLocalPreferences(
    String userId,
    UserNotificationPreferences model,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_prefUserPrefsPrefix$userId',
        jsonEncode(model.toMap()),
      );
    } catch (_) {}
  }

  /// Master 36 Stasiun Kereta Api Indonesia dengan koordinat GPS & fasilitas akurat.
  static const List<TrackStationModel> _masterIndonesianStations = [
    TrackStationModel(
      code: 'GMR',
      name: 'Stasiun Gambir',
      city: 'Jakarta Pusat',
      region: 'Jabodetabek',
      address: 'Jl. Medan Merdeka Timur No.1, Gambir, Jakarta Pusat',
      latitude: -6.176655,
      longitude: 106.830583,
      facilities: ['Ruang Tunggu Eksekutif', 'Mushola', 'ATM Center', 'WiFi Gratis', 'Akses Disabilitas', 'Klinik Mediska', 'Parkir Luas', 'Charging Station'],
    ),
    TrackStationModel(
      code: 'PSE',
      name: 'Stasiun Pasar Senen',
      city: 'Jakarta Pusat',
      region: 'Jabodetabek',
      address: 'Jl. Stasiun Senen No.14, Senen, Jakarta Pusat',
      latitude: -6.174208,
      longitude: 106.844406,
      facilities: ['Ruang Tunggu AC', 'Mushola', 'ATM Center', 'Akses Disabilitas', 'Klinik Mediska', 'Food Court'],
    ),
    TrackStationModel(
      code: 'JNG',
      name: 'Stasiun Jatinegara',
      city: 'Jakarta Timur',
      region: 'Jabodetabek',
      address: 'Jl. Bekasi Barat Raya, Jatinegara, Jakarta Timur',
      latitude: -6.215192,
      longitude: 106.870251,
      facilities: ['Mushola', 'Toilet', 'ATM', 'Minimarket', 'Integrasi TransJakarta'],
    ),
    TrackStationModel(
      code: 'MRI',
      name: 'Stasiun Manggarai',
      city: 'Jakarta Selatan',
      region: 'Jabodetabek',
      address: 'Jl. Manggarai Utara 1, Tebet, Jakarta Selatan',
      latitude: -6.209911,
      longitude: 106.850262,
      facilities: ['Stasiun Sentral KRL & KA Bandara', 'Eskalator & Lift', 'Mushola', 'ATM Center', 'Akses Disabilitas'],
    ),
    TrackStationModel(
      code: 'JAKK',
      name: 'Stasiun Jakarta Kota',
      city: 'Jakarta Barat',
      region: 'Jabodetabek',
      address: 'Jl. Stasiun Kota No.1, Pinangsia, Taman Sari, Jakarta Barat',
      latitude: -6.137563,
      longitude: 106.814658,
      facilities: ['Cagar Budaya', 'Mushola', 'ATM Center', 'Kantin', 'Integrasi TransJakarta'],
    ),
    TrackStationModel(
      code: 'BKS',
      name: 'Stasiun Bekasi',
      city: 'Bekasi',
      region: 'Jabodetabek',
      address: 'Jl. Ir. H. Juanda, Bekasi Timur, Kota Bekasi',
      latitude: -6.236185,
      longitude: 106.999451,
      facilities: ['Eskalator & Lift', 'Mushola', 'Parkir Luas', 'Minimarket', 'ATM Center'],
    ),
    TrackStationModel(
      code: 'BOO',
      name: 'Stasiun Bogor',
      city: 'Bogor',
      region: 'Jabodetabek',
      address: 'Jl. Nyi Raja Permas No.1, Cibogor, Kota Bogor',
      latitude: -6.595716,
      longitude: 106.790531,
      facilities: ['Mushola', 'Area Kuliner', 'ATM Center', 'Toilet', 'Integrasi Biskita'],
    ),
    TrackStationModel(
      code: 'PWK',
      name: 'Stasiun Purwakarta',
      city: 'Purwakarta',
      region: 'Jawa Barat',
      address: 'Jl. Kolonel Kornel Singawinata No.1, Purwakarta',
      latitude: -6.552906,
      longitude: 107.446669,
      facilities: ['Ruang Tunggu', 'Mushola', 'Toilet', 'Parkir', 'Kantin'],
    ),
    TrackStationModel(
      code: 'CMI',
      name: 'Stasiun Cimahi',
      city: 'Cimahi',
      region: 'Jawa Barat',
      address: 'Jl. Stasiun Cimahi, Baros, Kota Cimahi',
      latitude: -6.885654,
      longitude: 107.535995,
      facilities: ['Ruang Tunggu', 'Mushola', 'Toilet', 'ATM', 'Parkir'],
    ),
    TrackStationModel(
      code: 'BD',
      name: 'Stasiun Bandung',
      city: 'Bandung',
      region: 'Jawa Barat',
      address: 'Jl. Stasiun Barat, Kebon Jeruk, Andir, Kota Bandung',
      latitude: -6.912606,
      longitude: 107.602418,
      facilities: ['Ruang Tunggu Eksekutif', 'Mushola', 'ATM Center', 'WiFi Gratis', 'Klinik Mediska', 'Akses Disabilitas', 'Charging Station'],
    ),
    TrackStationModel(
      code: 'KAC',
      name: 'Stasiun Kiaracondong',
      city: 'Bandung',
      region: 'Jawa Barat',
      address: 'Jl. Stasiun Kiaracondong, Babakan Surabaya, Kota Bandung',
      latitude: -6.925077,
      longitude: 107.646217,
      facilities: ['Ruang Tunggu', 'Mushola', 'ATM', 'Toilet', 'Parkir'],
    ),
    TrackStationModel(
      code: 'CN',
      name: 'Stasiun Cirebon',
      city: 'Cirebon',
      region: 'Jawa Barat',
      address: 'Jl. Siliwangi, Kebonbaru, Kejaksan, Kota Cirebon',
      latitude: -6.705469,
      longitude: 108.555377,
      facilities: ['Ruang Tunggu Eksekutif', 'Mushola', 'ATM Center', 'WiFi Gratis', 'Klinik Mediska', 'Parkir Luas'],
    ),
    TrackStationModel(
      code: 'TG',
      name: 'Stasiun Tegal',
      city: 'Tegal',
      region: 'Jawa Tengah & DIY',
      address: 'Jl. Semeru No.16, Slerok, Tegal Timur, Kota Tegal',
      latitude: -6.867306,
      longitude: 109.142667,
      facilities: ['Ruang Tunggu', 'Mushola', 'ATM', 'Toilet', 'Parkir'],
    ),
    TrackStationModel(
      code: 'PK',
      name: 'Stasiun Pekalongan',
      city: 'Pekalongan',
      region: 'Jawa Tengah & DIY',
      address: 'Jl. Gajah Mada No.10, Bendan, Kota Pekalongan',
      latitude: -6.889779,
      longitude: 109.664183,
      facilities: ['Ruang Tunggu', 'Mushola', 'Toilet', 'ATM', 'Parkir'],
    ),
    TrackStationModel(
      code: 'SMT',
      name: 'Stasiun Semarang Tawang',
      city: 'Semarang',
      region: 'Jawa Tengah & DIY',
      address: 'Jl. Taman Tawang No.1, Tanjung Mas, Kota Semarang',
      latitude: -6.964444,
      longitude: 110.427975,
      facilities: ['Ruang Tunggu Eksekutif', 'Mushola', 'ATM Center', 'WiFi Gratis', 'Akses Disabilitas', 'Charging Station'],
    ),
    TrackStationModel(
      code: 'PWT',
      name: 'Stasiun Purwokerto',
      city: 'Banyumas',
      region: 'Jawa Tengah & DIY',
      address: 'Jl. Stasiun Purwokerto, Kober, Purwokerto Barat',
      latitude: -7.419283,
      longitude: 109.222111,
      facilities: ['Ruang Tunggu Eksekutif', 'Mushola', 'ATM Center', 'WiFi Gratis', 'Skybridge', 'Klinik Mediska'],
    ),
    TrackStationModel(
      code: 'KYA',
      name: 'Stasiun Kroya',
      city: 'Cilacap',
      region: 'Jawa Tengah & DIY',
      address: 'Jl. Stasiun Kroya, Bajing, Kroya, Cilacap',
      latitude: -7.630519,
      longitude: 109.253528,
      facilities: ['Ruang Tunggu', 'Mushola', 'Toilet', 'ATM', 'Kantin'],
    ),
    TrackStationModel(
      code: 'KTA',
      name: 'Stasiun Kutoarjo',
      city: 'Purworejo',
      region: 'Jawa Tengah & DIY',
      address: 'Jl. Merpati No.1, Semawung Daleman, Kutoarjo',
      latitude: -7.725925,
      longitude: 109.907342,
      facilities: ['Ruang Tunggu', 'Mushola', 'Toilet', 'ATM', 'Integrasi KA Prameks'],
    ),
    TrackStationModel(
      code: 'YK',
      name: 'Stasiun Yogyakarta',
      city: 'Yogyakarta',
      region: 'Jawa Tengah & DIY',
      address: 'Jl. Pasar Kembang, Sosromenduran, Gedongtengen, Yogyakarta',
      latitude: -7.789217,
      longitude: 110.363506,
      facilities: ['Ruang Tunggu Eksekutif', 'Mushola', 'ATM Center', 'WiFi Gratis', 'Integrasi KA Bandara YIA', 'Akses Disabilitas'],
    ),
    TrackStationModel(
      code: 'SLO',
      name: 'Stasiun Solo Balapan',
      city: 'Surakarta',
      region: 'Jawa Tengah & DIY',
      address: 'Jl. Wolter Monginsidi No.112, Kestalan, Banjarsari, Surakarta',
      latitude: -7.557042,
      longitude: 110.821361,
      facilities: ['Ruang Tunggu Eksekutif', 'Skybridge Terminal Tirtonadi', 'Integrasi KRL & KA Bandara', 'WiFi Gratis', 'ATM Center'],
    ),
    TrackStationModel(
      code: 'MN',
      name: 'Stasiun Madiun',
      city: 'Madiun',
      region: 'Jawa Timur',
      address: 'Jl. Kompol Sunaryo No.14, Madiun Lor, Kota Madiun',
      latitude: -7.619236,
      longitude: 111.524064,
      facilities: ['Ruang Tunggu Eksekutif', 'Mushola', 'ATM Center', 'WiFi Gratis', 'Parkir'],
    ),
    TrackStationModel(
      code: 'KD',
      name: 'Stasiun Kediri',
      city: 'Kediri',
      region: 'Jawa Timur',
      address: 'Jl. Stasiun No.1, Balowerti, Kota Kediri',
      latitude: -7.817411,
      longitude: 112.015528,
      facilities: ['Ruang Tunggu', 'Mushola', 'Toilet', 'ATM', 'Parkir'],
    ),
    TrackStationModel(
      code: 'SBI',
      name: 'Stasiun Surabaya Pasarturi',
      city: 'Surabaya',
      region: 'Jawa Timur',
      address: 'Jl. Semarang No.1, Tembok Dukuh, Bubutan, Kota Surabaya',
      latitude: -7.248511,
      longitude: 112.731161,
      facilities: ['Ruang Tunggu Eksekutif', 'Mushola', 'ATM Center', 'WiFi Gratis', 'Akses Disabilitas', 'Klinik Mediska', 'Parkir Luas'],
    ),
    TrackStationModel(
      code: 'SGU',
      name: 'Stasiun Surabaya Gubeng',
      city: 'Surabaya',
      region: 'Jawa Timur',
      address: 'Jl. Gubeng Masjid No.1, Pacar Keling, Tambaksari, Kota Surabaya',
      latitude: -7.265464,
      longitude: 112.752056,
      facilities: ['Ruang Tunggu Eksekutif', 'Mushola', 'ATM Center', 'WiFi Gratis', 'Akses Disabilitas', 'Charging Station'],
    ),
    TrackStationModel(
      code: 'ML',
      name: 'Stasiun Malang',
      city: 'Malang',
      region: 'Jawa Timur',
      address: 'Jl. Trunojoyo No.10, Kiduldalem, Klojen, Kota Malang',
      latitude: -7.977286,
      longitude: 112.637011,
      facilities: ['Skybridge Stasiun Baru', 'Ruang Tunggu Eksekutif', 'Mushola', 'ATM Center', 'WiFi Gratis', 'Akses Disabilitas'],
    ),
    TrackStationModel(
      code: 'JR',
      name: 'Stasiun Jember',
      city: 'Jember',
      region: 'Jawa Timur',
      address: 'Jl. Wijaya Kusuma No.5, Jemberlor, Patrang, Jember',
      latitude: -8.164625,
      longitude: 113.704225,
      facilities: ['Ruang Tunggu', 'Mushola', 'ATM', 'Toilet', 'Parkir'],
    ),
    TrackStationModel(
      code: 'KTG',
      name: 'Stasiun Ketapang',
      city: 'Banyuwangi',
      region: 'Jawa Timur',
      address: 'Jl. Gatot Subroto, Ketapang, Kalipuro, Banyuwangi',
      latitude: -8.144947,
      longitude: 114.397636,
      facilities: ['Dekat Pelabuhan Ketapang', 'Ruang Tunggu', 'Mushola', 'Toilet', 'ATM'],
    ),
    TrackStationModel(
      code: 'MDN',
      name: 'Stasiun Medan',
      city: 'Medan',
      region: 'Sumatera',
      address: 'Jl. Stasiun Kereta Api No.1, Kesawan, Medan Barat, Kota Medan',
      latitude: 3.591278,
      longitude: 98.678478,
      facilities: ['Integrasi KA Bandara Kualanamu', 'Ruang Tunggu Eksekutif', 'Mushola', 'WiFi Gratis', 'ATM Center'],
    ),
    TrackStationModel(
      code: 'KNM',
      name: 'Stasiun Kualanamu',
      city: 'Deli Serdang',
      region: 'Sumatera',
      address: 'Kompleks Bandara Internasional Kualanamu, Deli Serdang',
      latitude: 3.638011,
      longitude: 98.876319,
      facilities: ['Akses Langsung Terminal Bandara', 'Ruang Tunggu AC', 'Mushola', 'WiFi Gratis', 'Eskalator & Lift'],
    ),
    TrackStationModel(
      code: 'KPT',
      name: 'Stasiun Kertapati',
      city: 'Palembang',
      region: 'Sumatera',
      address: 'Jl. Ki Merogan, Kemas Rindo, Kertapati, Kota Palembang',
      latitude: -3.025219,
      longitude: 104.741856,
      facilities: ['Ruang Tunggu', 'Mushola', 'Toilet', 'ATM', 'Parkir'],
    ),
    TrackStationModel(
      code: 'TNK',
      name: 'Stasiun Tanjung Karang',
      city: 'Bandar Lampung',
      region: 'Sumatera',
      address: 'Jl. Kotaraja No.1, Gunung Sari, Enggal, Bandar Lampung',
      latitude: -5.408503,
      longitude: 105.259781,
      facilities: ['Ruang Tunggu', 'Mushola', 'ATM Center', 'Toilet', 'Parkir'],
    ),
  ];

  /// Dataset DEMO yang jujur: TIDAK PERNAH menandai data simulasi sebagai `LIVE`.
  static List<TrainTripModel> _buildHonestDemoTrips(
    Map<String, TrackStationModel> st,
  ) {
    GeoPoint pt(String code) {
      final s = st[code];
      return GeoPoint(s?.latitude ?? -6.176655, s?.longitude ?? 106.830583);
    }

    TrainStopModel stop(
      String tripId,
      String code,
      int seq,
      DateTime? schArr,
      DateTime? schDep,
      DateTime? estArr,
      String platform,
      String status,
    ) {
      final s = st[code];
      return TrainStopModel(
        id: '$tripId-$seq',
        tripId: tripId,
        stationCode: code,
        stationName: s?.name ?? code,
        city: s?.city ?? '',
        stopSequence: seq,
        scheduledArrival: schArr,
        scheduledDeparture: schDep,
        estimatedArrival: estArr,
        platform: platform,
        stopStatus: status,
        latitude: s?.latitude,
        longitude: s?.longitude,
      );
    }

    final nowUtc = DateTime.now().toUtc();

    return [
      TrainTripModel(
        id: 'TRIP-KA2-ABA',
        scheduleId: 'SCH-001',
        trainNumber: 'KA 2',
        trainName: 'KA Argo Bromo Anggrek',
        serviceType: 'Eksekutif / Luxury',
        region: 'Jawa Timur',
        originCode: 'GMR',
        originName: st['GMR']?.name ?? 'Gambir',
        destinationCode: 'SBI',
        destinationName: st['SBI']?.name ?? 'Surabaya Pasarturi',
        serviceDate: nowUtc,
        scheduledDeparture: IndonesiaTimeService.todayWibUtc(8, 20),
        scheduledArrival: IndonesiaTimeService.todayWibUtc(16, 25),
        estimatedArrival: IndonesiaTimeService.todayWibUtc(16, 25),
        dataStatus: TrainDataStatus.demo,
        tripStatus: 'Simulasi Perjalanan (Mode Demo)',
        isSimulated: true,
        dataSourceLabel: 'Simulasi Demo TKA (Bukan Real-Time)',
        delayMinutes: 0,
        currentLat: -6.8780,
        currentLng: 109.4200,
        heading: 96,
        speedKmh: 112,
        currentStationCode: 'CN',
        nextStationCode: 'PK',
        routeGeometry: [pt('GMR'), pt('BKS'), pt('CN'), pt('TG'), pt('PK'), pt('SMT'), pt('SBI')],
        lastUpdatedAt: nowUtc,
        stops: [
          stop('TRIP-KA2-ABA', 'GMR', 1, null, IndonesiaTimeService.todayWibUtc(8, 20), null, 'Peron 2', 'PASSED'),
          stop('TRIP-KA2-ABA', 'CN', 2, IndonesiaTimeService.todayWibUtc(10, 55), IndonesiaTimeService.todayWibUtc(11, 1), IndonesiaTimeService.todayWibUtc(10, 55), 'Jalur 1', 'PASSED'),
          stop('TRIP-KA2-ABA', 'PK', 3, IndonesiaTimeService.todayWibUtc(12, 25), IndonesiaTimeService.todayWibUtc(12, 29), IndonesiaTimeService.todayWibUtc(12, 25), 'Jalur 2', 'UPCOMING'),
          stop('TRIP-KA2-ABA', 'SMT', 4, IndonesiaTimeService.todayWibUtc(13, 35), IndonesiaTimeService.todayWibUtc(13, 42), IndonesiaTimeService.todayWibUtc(13, 35), 'Jalur 3', 'UPCOMING'),
          stop('TRIP-KA2-ABA', 'SBI', 5, IndonesiaTimeService.todayWibUtc(16, 25), null, IndonesiaTimeService.todayWibUtc(16, 25), 'Peron 1', 'UPCOMING'),
        ],
      ),
      TrainTripModel(
        id: 'TRIP-KA40-AP',
        scheduleId: 'SCH-002',
        trainNumber: 'KA 40',
        trainName: 'KA Argo Parahyangan',
        serviceType: 'Eksekutif / Ekonomi',
        region: 'Jawa Barat',
        originCode: 'GMR',
        originName: st['GMR']?.name ?? 'Gambir',
        destinationCode: 'BD',
        destinationName: st['BD']?.name ?? 'Bandung',
        serviceDate: nowUtc,
        scheduledDeparture: IndonesiaTimeService.todayWibUtc(9, 30),
        scheduledArrival: IndonesiaTimeService.todayWibUtc(12, 45),
        estimatedArrival: IndonesiaTimeService.todayWibUtc(13, 3),
        dataStatus: TrainDataStatus.delayed,
        tripStatus: 'Terlambat 18 Menit (Simulasi Delay)',
        isSimulated: true,
        dataSourceLabel: 'Simulasi Delay TKA (Bukan Real-Time)',
        delayMinutes: 18,
        delayReason: 'Antrean persilangan jalur tunggal lintas Purwakarta - Cimahi',
        currentLat: -6.6850,
        currentLng: 107.4820,
        heading: 145,
        speedKmh: 64,
        currentStationCode: 'PWK',
        nextStationCode: 'CMI',
        routeGeometry: [pt('GMR'), pt('JNG'), pt('BKS'), pt('PWK'), pt('CMI'), pt('BD')],
        lastUpdatedAt: nowUtc,
        stops: [
          stop('TRIP-KA40-AP', 'GMR', 1, null, IndonesiaTimeService.todayWibUtc(9, 30), null, 'Peron 3', 'PASSED'),
          stop('TRIP-KA40-AP', 'BKS', 2, IndonesiaTimeService.todayWibUtc(9, 58), IndonesiaTimeService.todayWibUtc(10, 0), IndonesiaTimeService.todayWibUtc(10, 5), 'Jalur 4', 'PASSED'),
          stop('TRIP-KA40-AP', 'PWK', 3, IndonesiaTimeService.todayWibUtc(11, 10), IndonesiaTimeService.todayWibUtc(11, 14), IndonesiaTimeService.todayWibUtc(11, 28), 'Jalur 2', 'PASSED'),
          stop('TRIP-KA40-AP', 'CMI', 4, IndonesiaTimeService.todayWibUtc(12, 30), IndonesiaTimeService.todayWibUtc(12, 32), IndonesiaTimeService.todayWibUtc(12, 48), 'Jalur 1', 'UPCOMING'),
          stop('TRIP-KA40-AP', 'BD', 5, IndonesiaTimeService.todayWibUtc(12, 45), null, IndonesiaTimeService.todayWibUtc(13, 3), 'Peron 2', 'UPCOMING'),
        ],
      ),
      TrainTripModel(
        id: 'TRIP-KA68-TKS',
        scheduleId: 'SCH-003',
        trainNumber: 'KA 68',
        trainName: 'KA Taksaka',
        serviceType: 'Eksekutif / Luxury',
        region: 'Jawa Tengah & DIY',
        originCode: 'GMR',
        originName: st['GMR']?.name ?? 'Gambir',
        destinationCode: 'YK',
        destinationName: st['YK']?.name ?? 'Yogyakarta',
        serviceDate: nowUtc,
        scheduledDeparture: IndonesiaTimeService.todayWibUtc(9, 20),
        scheduledArrival: IndonesiaTimeService.todayWibUtc(15, 35),
        estimatedArrival: IndonesiaTimeService.todayWibUtc(15, 35),
        dataStatus: TrainDataStatus.demo,
        tripStatus: 'Simulasi Perjalanan (Mode Demo)',
        isSimulated: true,
        dataSourceLabel: 'Simulasi Demo TKA (Bukan Real-Time)',
        delayMinutes: 0,
        currentLat: -7.4950,
        currentLng: 109.2420,
        heading: 130,
        speedKmh: 98,
        currentStationCode: 'PWT',
        nextStationCode: 'KTA',
        routeGeometry: [pt('GMR'), pt('CN'), pt('PWT'), pt('KYA'), pt('KTA'), pt('YK')],
        lastUpdatedAt: nowUtc,
        stops: [
          stop('TRIP-KA68-TKS', 'GMR', 1, null, IndonesiaTimeService.todayWibUtc(9, 20), null, 'Peron 1', 'PASSED'),
          stop('TRIP-KA68-TKS', 'CN', 2, IndonesiaTimeService.todayWibUtc(12, 0), IndonesiaTimeService.todayWibUtc(12, 5), IndonesiaTimeService.todayWibUtc(12, 0), 'Jalur 2', 'PASSED'),
          stop('TRIP-KA68-TKS', 'PWT', 3, IndonesiaTimeService.todayWibUtc(13, 52), IndonesiaTimeService.todayWibUtc(13, 58), IndonesiaTimeService.todayWibUtc(13, 52), 'Jalur 3', 'PASSED'),
          stop('TRIP-KA68-TKS', 'KTA', 4, IndonesiaTimeService.todayWibUtc(14, 50), IndonesiaTimeService.todayWibUtc(14, 53), IndonesiaTimeService.todayWibUtc(14, 50), 'Jalur 1', 'UPCOMING'),
          stop('TRIP-KA68-TKS', 'YK', 5, IndonesiaTimeService.todayWibUtc(15, 35), null, IndonesiaTimeService.todayWibUtc(15, 35), 'Peron 4', 'UPCOMING'),
        ],
      ),
      TrainTripModel(
        id: 'TRIP-KA56-GJY',
        scheduleId: 'SCH-004',
        trainNumber: 'KA 56',
        trainName: 'KA Gajayana',
        serviceType: 'Eksekutif / Luxury',
        region: 'Jawa Timur',
        originCode: 'GMR',
        originName: st['GMR']?.name ?? 'Gambir',
        destinationCode: 'ML',
        destinationName: st['ML']?.name ?? 'Malang',
        serviceDate: nowUtc,
        scheduledDeparture: IndonesiaTimeService.todayWibUtc(18, 50),
        scheduledArrival: IndonesiaTimeService.todayWibUtc(7, 10, addDays: 1),
        estimatedArrival: IndonesiaTimeService.todayWibUtc(7, 10, addDays: 1),
        dataStatus: TrainDataStatus.scheduled,
        tripStatus: 'Terjadwal Berangkat dari Stasiun Gambir',
        isSimulated: false,
        dataSourceLabel: 'Jadwal Operasional Resmi',
        delayMinutes: 0,
        currentLat: st['GMR']?.latitude,
        currentLng: st['GMR']?.longitude,
        heading: 110,
        speedKmh: null,
        currentStationCode: 'GMR',
        nextStationCode: 'CN',
        routeGeometry: [pt('GMR'), pt('CN'), pt('PWT'), pt('YK'), pt('SLO'), pt('MN'), pt('KD'), pt('ML')],
        lastUpdatedAt: nowUtc,
        stops: [
          stop('TRIP-KA56-GJY', 'GMR', 1, null, IndonesiaTimeService.todayWibUtc(18, 50), null, 'Peron 2', 'UPCOMING'),
          stop('TRIP-KA56-GJY', 'CN', 2, IndonesiaTimeService.todayWibUtc(21, 35), IndonesiaTimeService.todayWibUtc(21, 41), null, 'Jalur 1', 'UPCOMING'),
          stop('TRIP-KA56-GJY', 'YK', 3, IndonesiaTimeService.todayWibUtc(1, 55, addDays: 1), IndonesiaTimeService.todayWibUtc(2, 2, addDays: 1), null, 'Jalur 4', 'UPCOMING'),
          stop('TRIP-KA56-GJY', 'SLO', 4, IndonesiaTimeService.todayWibUtc(2, 50, addDays: 1), IndonesiaTimeService.todayWibUtc(2, 55, addDays: 1), null, 'Jalur 2', 'UPCOMING'),
          stop('TRIP-KA56-GJY', 'MN', 5, IndonesiaTimeService.todayWibUtc(4, 8, addDays: 1), IndonesiaTimeService.todayWibUtc(4, 13, addDays: 1), null, 'Jalur 1', 'UPCOMING'),
          stop('TRIP-KA56-GJY', 'KD', 6, IndonesiaTimeService.todayWibUtc(5, 22, addDays: 1), IndonesiaTimeService.todayWibUtc(5, 26, addDays: 1), null, 'Jalur 1', 'UPCOMING'),
          stop('TRIP-KA56-GJY', 'ML', 7, IndonesiaTimeService.todayWibUtc(7, 10, addDays: 1), null, null, 'Peron 1', 'UPCOMING'),
        ],
      ),
      TrainTripModel(
        id: 'TRIP-KA62-SWK',
        scheduleId: 'SCH-005',
        trainNumber: 'KA 62',
        trainName: 'KA Sancaka',
        serviceType: 'Eksekutif / Ekonomi',
        region: 'Jawa Tengah & DIY',
        originCode: 'YK',
        originName: st['YK']?.name ?? 'Yogyakarta',
        destinationCode: 'SGU',
        destinationName: st['SGU']?.name ?? 'Surabaya Gubeng',
        serviceDate: nowUtc,
        scheduledDeparture: IndonesiaTimeService.todayWibUtc(11, 30),
        scheduledArrival: IndonesiaTimeService.todayWibUtc(15, 30),
        estimatedArrival: IndonesiaTimeService.todayWibUtc(15, 30),
        dataStatus: TrainDataStatus.demo,
        tripStatus: 'Simulasi Perjalanan (Mode Demo)',
        isSimulated: true,
        dataSourceLabel: 'Simulasi Demo TKA (Bukan Real-Time)',
        delayMinutes: 0,
        currentLat: -7.5880,
        currentLng: 111.1700,
        heading: 88,
        speedKmh: 105,
        currentStationCode: 'SLO',
        nextStationCode: 'MN',
        routeGeometry: [pt('YK'), pt('SLO'), pt('MN'), pt('SGU')],
        lastUpdatedAt: nowUtc,
        stops: [
          stop('TRIP-KA62-SWK', 'YK', 1, null, IndonesiaTimeService.todayWibUtc(11, 30), null, 'Peron 3', 'PASSED'),
          stop('TRIP-KA62-SWK', 'SLO', 2, IndonesiaTimeService.todayWibUtc(12, 18), IndonesiaTimeService.todayWibUtc(12, 22), IndonesiaTimeService.todayWibUtc(12, 18), 'Jalur 2', 'PASSED'),
          stop('TRIP-KA62-SWK', 'MN', 3, IndonesiaTimeService.todayWibUtc(13, 35), IndonesiaTimeService.todayWibUtc(13, 40), IndonesiaTimeService.todayWibUtc(13, 35), 'Jalur 1', 'UPCOMING'),
          stop('TRIP-KA62-SWK', 'SGU', 4, IndonesiaTimeService.todayWibUtc(15, 30), null, IndonesiaTimeService.todayWibUtc(15, 30), 'Peron 5', 'UPCOMING'),
        ],
      ),
      TrainTripModel(
        id: 'TRIP-KRL1024',
        scheduleId: 'SCH-006',
        trainNumber: 'KRL 1024',
        trainName: 'Commuter Line Bogor',
        serviceType: 'Komuter',
        region: 'Jabodetabek',
        originCode: 'JAKK',
        originName: st['JAKK']?.name ?? 'Jakarta Kota',
        destinationCode: 'BOO',
        destinationName: st['BOO']?.name ?? 'Bogor',
        serviceDate: nowUtc,
        scheduledDeparture: IndonesiaTimeService.todayWibUtc(10, 0),
        scheduledArrival: IndonesiaTimeService.todayWibUtc(11, 25),
        estimatedArrival: IndonesiaTimeService.todayWibUtc(11, 25),
        dataStatus: TrainDataStatus.demo,
        tripStatus: 'Simulasi Perjalanan (Mode Demo)',
        isSimulated: true,
        dataSourceLabel: 'Simulasi Demo TKA (Bukan Real-Time)',
        delayMinutes: 0,
        currentLat: -6.3420,
        currentLng: 106.8320,
        heading: 185,
        speedKmh: 58,
        currentStationCode: 'MRI',
        nextStationCode: 'BOO',
        routeGeometry: [pt('JAKK'), pt('GMR'), pt('MRI'), pt('BOO')],
        lastUpdatedAt: nowUtc,
        stops: [
          stop('TRIP-KRL1024', 'JAKK', 1, null, IndonesiaTimeService.todayWibUtc(10, 0), null, 'Jalur 5', 'PASSED'),
          stop('TRIP-KRL1024', 'MRI', 2, IndonesiaTimeService.todayWibUtc(10, 22), IndonesiaTimeService.todayWibUtc(10, 24), IndonesiaTimeService.todayWibUtc(10, 22), 'Peron 12', 'PASSED'),
          stop('TRIP-KRL1024', 'BOO', 3, IndonesiaTimeService.todayWibUtc(11, 25), null, IndonesiaTimeService.todayWibUtc(11, 25), 'Jalur 3', 'UPCOMING'),
        ],
      ),
      TrainTripModel(
        id: 'TRIP-KA-ARS12',
        scheduleId: 'SCH-007',
        trainNumber: 'KA U12',
        trainName: 'KA Bandara Kualanamu (Srilelawangsa)',
        serviceType: 'KA Bandara',
        region: 'Sumatera',
        originCode: 'MDN',
        originName: st['MDN']?.name ?? 'Medan',
        destinationCode: 'KNM',
        destinationName: st['KNM']?.name ?? 'Kualanamu',
        serviceDate: nowUtc,
        scheduledDeparture: IndonesiaTimeService.todayWibUtc(10, 15),
        scheduledArrival: IndonesiaTimeService.todayWibUtc(10, 50),
        estimatedArrival: null,
        dataStatus: TrainDataStatus.unavailable,
        tripStatus: 'Data Posisi Telemetri Tidak Tersedia',
        isSimulated: false,
        dataSourceLabel: 'Telemetri Offline',
        delayMinutes: 0,
        delayReason: 'Perangkat pelacak GPS belum mengirimkan data posisi terbaru',
        currentLat: null,
        currentLng: null,
        heading: null,
        speedKmh: null,
        currentStationCode: 'MDN',
        nextStationCode: 'KNM',
        routeGeometry: [pt('MDN'), pt('KNM')],
        lastUpdatedAt: nowUtc.subtract(const Duration(minutes: 25)),
        stops: [
          stop('TRIP-KA-ARS12', 'MDN', 1, null, IndonesiaTimeService.todayWibUtc(10, 15), null, 'Peron Bandara', 'PASSED'),
          stop('TRIP-KA-ARS12', 'KNM', 2, IndonesiaTimeService.todayWibUtc(10, 50), null, null, 'Peron 1', 'UPCOMING'),
        ],
      ),
      TrainTripModel(
        id: 'TRIP-KA-SRJ1',
        scheduleId: 'SCH-008',
        trainNumber: 'KA S1',
        trainName: 'KA Sriwijaya',
        serviceType: 'Eksekutif / Bisnis',
        region: 'Sumatera',
        originCode: 'KPT',
        originName: st['KPT']?.name ?? 'Kertapati',
        destinationCode: 'TNK',
        destinationName: st['TNK']?.name ?? 'Tanjung Karang',
        serviceDate: nowUtc,
        scheduledDeparture: IndonesiaTimeService.todayWibUtc(21, 0),
        scheduledArrival: IndonesiaTimeService.todayWibUtc(5, 30, addDays: 1),
        estimatedArrival: IndonesiaTimeService.todayWibUtc(5, 30, addDays: 1),
        dataStatus: TrainDataStatus.scheduled,
        tripStatus: 'Terjadwal Berangkat dari Stasiun Kertapati',
        isSimulated: false,
        dataSourceLabel: 'Jadwal Operasional Resmi',
        delayMinutes: 0,
        currentLat: st['KPT']?.latitude,
        currentLng: st['KPT']?.longitude,
        heading: 165,
        speedKmh: null,
        currentStationCode: 'KPT',
        nextStationCode: 'TNK',
        routeGeometry: [pt('KPT'), pt('TNK')],
        lastUpdatedAt: nowUtc,
        stops: [
          stop('TRIP-KA-SRJ1', 'KPT', 1, null, IndonesiaTimeService.todayWibUtc(21, 0), null, 'Peron 1', 'UPCOMING'),
          stop('TRIP-KA-SRJ1', 'TNK', 2, IndonesiaTimeService.todayWibUtc(5, 30, addDays: 1), null, IndonesiaTimeService.todayWibUtc(5, 30, addDays: 1), 'Peron 2', 'UPCOMING'),
        ],
      ),
    ];
  }
}

