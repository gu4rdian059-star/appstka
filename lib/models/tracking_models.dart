import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Status data resmi posisi kereta.
/// ATURAN KETAT:
/// - `live` HANYA untuk data telemetri GPS nyata (`isSimulated == false`).
/// - Data simulasi WAJIB berstatus `demo` atau `delayed` dengan `isSimulated == true`,
///   dan TIDAK PERNAH disebut sebagai data real-time.
enum TrainDataStatus {
  live('LIVE', 'LIVE', 'Real-Time GPS', Color(0xFF10B981), '#10B981', Icons.sensors_rounded),
  delayed('DELAYED', 'TERLAMBAT', 'Terlambat', Color(0xFFEF4444), '#EF4444', Icons.warning_amber_rounded),
  scheduled('SCHEDULED', 'TERJADWAL', 'Berdasarkan Jadwal', Color(0xFF2563EB), '#2563EB', Icons.schedule_rounded),
  demo('DEMO', 'DEMO / SIMULASI', 'Simulasi (Non-Real-Time)', Color(0xFF7C3AED), '#7C3AED', Icons.science_rounded),
  unavailable('UNAVAILABLE', 'TIDAK TERSEDIA', 'Posisi Tidak Tersedia', Color(0xFF64748B), '#64748B', Icons.signal_wifi_off_rounded);

  final String code;
  final String label;
  final String description;
  final Color color;
  final String hexColor;
  final IconData icon;

  const TrainDataStatus(
    this.code,
    this.label,
    this.description,
    this.color,
    this.hexColor,
    this.icon,
  );

  static TrainDataStatus fromString(String? raw, {bool isSimulated = false}) {
    final normalized = (raw ?? '').trim().toUpperCase();
    // Guard anti-kebohongan: jika isSimulated true, jangan pernah return LIVE!
    if (isSimulated && normalized == 'LIVE') {
      return TrainDataStatus.demo;
    }
    switch (normalized) {
      case 'LIVE':
        return TrainDataStatus.live;
      case 'DELAYED':
        return TrainDataStatus.delayed;
      case 'SCHEDULED':
        return TrainDataStatus.scheduled;
      case 'DEMO':
        return TrainDataStatus.demo;
      case 'UNAVAILABLE':
        return TrainDataStatus.unavailable;
      default:
        return isSimulated ? TrainDataStatus.demo : TrainDataStatus.scheduled;
    }
  }
}

/// Model koordinat sederhana (lintas platform tanpa mengikat model ke MapLibre langsung).
class GeoPoint {
  final double lat;
  final double lng;

  const GeoPoint(this.lat, this.lng);

  List<double> toLngLatJson() => [lng, lat];
}

/// Model Stasiun lengkap untuk D. Station Information & Live Map markers.
class TrackStationModel {
  final String code;
  final String name;
  final String city;
  final String region;
  final String address;
  final double latitude;
  final double longitude;
  final String timezone;
  final List<String> facilities;

  const TrackStationModel({
    required this.code,
    required this.name,
    required this.city,
    required this.region,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.timezone = 'WIB',
    this.facilities = const [],
  });

  factory TrackStationModel.fromMap(Map<String, dynamic> map) {
    final rawFacilities = map['facilities'];
    List<String> parsedFacilities = [];
    if (rawFacilities is List) {
      parsedFacilities = rawFacilities.map((e) => e.toString()).toList();
    }
    return TrackStationModel(
      code: (map['code'] ?? '').toString().trim().toUpperCase(),
      name: (map['name'] ?? '').toString().trim(),
      city: (map['city'] ?? '').toString().trim(),
      region: (map['region'] ?? 'Jawa').toString().trim(),
      address: (map['address'] ?? '').toString().trim(),
      latitude: (map['latitude'] is num)
          ? (map['latitude'] as num).toDouble()
          : -6.176655,
      longitude: (map['longitude'] is num)
          ? (map['longitude'] as num).toDouble()
          : 106.830583,
      timezone: (map['timezone'] ?? 'WIB').toString().trim(),
      facilities: parsedFacilities,
    );
  }

  Map<String, dynamic> toMap() => {
        'code': code,
        'name': name,
        'city': city,
        'region': region,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'timezone': timezone,
        'facilities': facilities,
      };
}

/// Model Stasiun Pemberhentian dalam satu perjalanan kereta.
class TrainStopModel {
  final String id;
  final String tripId;
  final String stationCode;
  final String stationName;
  final String city;
  final int stopSequence;
  final DateTime? scheduledArrival;
  final DateTime? scheduledDeparture;
  final DateTime? estimatedArrival;
  final DateTime? estimatedDeparture;
  final DateTime? actualArrival;
  final DateTime? actualDeparture;
  final String? platform;
  final String stopStatus; // PASSED, AT_STATION, UPCOMING, SKIPPED
  final double? latitude;
  final double? longitude;

  const TrainStopModel({
    required this.id,
    required this.tripId,
    required this.stationCode,
    required this.stationName,
    required this.city,
    required this.stopSequence,
    this.scheduledArrival,
    this.scheduledDeparture,
    this.estimatedArrival,
    this.estimatedDeparture,
    this.actualArrival,
    this.actualDeparture,
    this.platform,
    this.stopStatus = 'UPCOMING',
    this.latitude,
    this.longitude,
  });

  TrainStopModel copyWith({
    String? stopStatus,
    DateTime? estimatedArrival,
    DateTime? estimatedDeparture,
    DateTime? actualArrival,
    DateTime? actualDeparture,
  }) {
    return TrainStopModel(
      id: id,
      tripId: tripId,
      stationCode: stationCode,
      stationName: stationName,
      city: city,
      stopSequence: stopSequence,
      scheduledArrival: scheduledArrival,
      scheduledDeparture: scheduledDeparture,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
      estimatedDeparture: estimatedDeparture ?? this.estimatedDeparture,
      actualArrival: actualArrival ?? this.actualArrival,
      actualDeparture: actualDeparture ?? this.actualDeparture,
      platform: platform,
      stopStatus: stopStatus ?? this.stopStatus,
      latitude: latitude,
      longitude: longitude,
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  factory TrainStopModel.fromMap(
    Map<String, dynamic> map, {
    TrackStationModel? station,
  }) {
    final code = (map['station_code'] ?? '').toString().toUpperCase();
    return TrainStopModel(
      id: (map['id'] ?? '$code-${map['stop_sequence'] ?? 0}').toString(),
      tripId: (map['trip_id'] ?? '').toString(),
      stationCode: code,
      stationName: station?.name ?? (map['station_name'] ?? code).toString(),
      city: station?.city ?? (map['city'] ?? '').toString(),
      stopSequence: (map['stop_sequence'] is num)
          ? (map['stop_sequence'] as num).toInt()
          : 0,
      scheduledArrival: _parseDate(map['scheduled_arrival']),
      scheduledDeparture: _parseDate(map['scheduled_departure']),
      estimatedArrival: _parseDate(map['estimated_arrival']),
      estimatedDeparture: _parseDate(map['estimated_departure']),
      actualArrival: _parseDate(map['actual_arrival']),
      actualDeparture: _parseDate(map['actual_departure']),
      platform: map['platform']?.toString(),
      stopStatus: (map['stop_status'] ?? 'UPCOMING').toString().toUpperCase(),
      latitude: station?.latitude,
      longitude: station?.longitude,
    );
  }
}

/// Model utama Perjalanan Kereta (Live Map, Train Detail, Train Schedule).
class TrainTripModel {
  final String id;
  final String? scheduleId;
  final String trainNumber;
  final String trainName;
  final String? serviceType;
  final String region;
  final String originCode;
  final String originName;
  final String destinationCode;
  final String destinationName;
  final DateTime serviceDate;
  final DateTime scheduledDeparture;
  final DateTime scheduledArrival;
  final DateTime? estimatedArrival;
  final TrainDataStatus dataStatus;
  final String tripStatus;
  final bool isSimulated;
  final String dataSourceLabel;
  final int delayMinutes;
  final String? delayReason;
  final double? currentLat;
  final double? currentLng;
  final double? heading;
  final double? speedKmh;
  final String? currentStationCode;
  final String? nextStationCode;
  final List<GeoPoint> routeGeometry;
  final DateTime? lastUpdatedAt;
  final List<TrainStopModel> stops;

  const TrainTripModel({
    required this.id,
    this.scheduleId,
    required this.trainNumber,
    required this.trainName,
    this.serviceType,
    required this.region,
    required this.originCode,
    required this.originName,
    required this.destinationCode,
    required this.destinationName,
    required this.serviceDate,
    required this.scheduledDeparture,
    required this.scheduledArrival,
    this.estimatedArrival,
    required this.dataStatus,
    required this.tripStatus,
    required this.isSimulated,
    required this.dataSourceLabel,
    this.delayMinutes = 0,
    this.delayReason,
    this.currentLat,
    this.currentLng,
    this.heading,
    this.speedKmh,
    this.currentStationCode,
    this.nextStationCode,
    this.routeGeometry = const [],
    this.lastUpdatedAt,
    this.stops = const [],
  });

  bool get hasValidPosition => currentLat != null && currentLng != null;

  /// Guard eksplisit: hanya dianggap real-time jika status == LIVE dan BUKAN simulasi.
  bool get isTrulyRealTime => dataStatus == TrainDataStatus.live && !isSimulated;

  /// Hitung ETA dinamis jika memungkinkan (dari estimatedArrival DB, atau dari
  /// jarak tersisa ke stasiun tujuan dibagi kecepatan saat ini, atau jadwal + delay).
  DateTime? get computedEta {
    if (dataStatus == TrainDataStatus.unavailable) return null;
    if (estimatedArrival != null) return estimatedArrival;
    if (hasValidPosition &&
        speedKmh != null &&
        speedKmh! > 10 &&
        routeGeometry.isNotEmpty) {
      final dest = routeGeometry.last;
      final remainingKm = haversineKm(currentLat!, currentLng!, dest.lat, dest.lng);
      final remainingMinutes = ((remainingKm / speedKmh!) * 60).round();
      return DateTime.now().toUtc().add(Duration(minutes: remainingMinutes));
    }
    return scheduledArrival.add(Duration(minutes: delayMinutes));
  }

  /// Jarak lurus Haversine (km) antar 2 koordinat GPS.
  static double haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  TrainTripModel copyWith({
    TrainDataStatus? dataStatus,
    String? tripStatus,
    bool? isSimulated,
    String? dataSourceLabel,
    int? delayMinutes,
    String? delayReason,
    double? currentLat,
    double? currentLng,
    double? heading,
    double? speedKmh,
    String? currentStationCode,
    String? nextStationCode,
    DateTime? estimatedArrival,
    DateTime? lastUpdatedAt,
    List<TrainStopModel>? stops,
  }) {
    return TrainTripModel(
      id: id,
      scheduleId: scheduleId,
      trainNumber: trainNumber,
      trainName: trainName,
      serviceType: serviceType,
      region: region,
      originCode: originCode,
      originName: originName,
      destinationCode: destinationCode,
      destinationName: destinationName,
      serviceDate: serviceDate,
      scheduledDeparture: scheduledDeparture,
      scheduledArrival: scheduledArrival,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
      dataStatus: dataStatus ?? this.dataStatus,
      tripStatus: tripStatus ?? this.tripStatus,
      isSimulated: isSimulated ?? this.isSimulated,
      dataSourceLabel: dataSourceLabel ?? this.dataSourceLabel,
      delayMinutes: delayMinutes ?? this.delayMinutes,
      delayReason: delayReason ?? this.delayReason,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      heading: heading ?? this.heading,
      speedKmh: speedKmh ?? this.speedKmh,
      currentStationCode: currentStationCode ?? this.currentStationCode,
      nextStationCode: nextStationCode ?? this.nextStationCode,
      routeGeometry: routeGeometry,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      stops: stops ?? this.stops,
    );
  }

  static DateTime _parseRequiredDate(dynamic v, DateTime fallback) {
    if (v == null) return fallback;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString()) ?? fallback;
  }

  static DateTime? _parseNullableDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  factory TrainTripModel.fromMap(
    Map<String, dynamic> map, {
    required Map<String, TrackStationModel> stationByCode,
    List<TrainStopModel> stops = const [],
  }) {
    final originCode = (map['origin_station_code'] ?? '').toString().toUpperCase();
    final destCode = (map['destination_station_code'] ?? '').toString().toUpperCase();
    final isSim = map['is_simulated'] == true;
    final parsedStatus = TrainDataStatus.fromString(
      map['data_status']?.toString(),
      isSimulated: isSim,
    );

    final List<GeoPoint> geom = [];
    final rawGeom = map['route_geometry'];
    if (rawGeom is List) {
      for (final pt in rawGeom) {
        if (pt is List && pt.length >= 2 && pt[0] is num && pt[1] is num) {
          geom.add(GeoPoint((pt[1] as num).toDouble(), (pt[0] as num).toDouble()));
        }
      }
    }

    final nowUtc = DateTime.now().toUtc();
    return TrainTripModel(
      id: (map['id'] ?? '').toString(),
      scheduleId: map['schedule_id']?.toString(),
      trainNumber: (map['train_number'] ?? '').toString(),
      trainName: (map['train_name'] ?? '').toString(),
      serviceType: map['service_type']?.toString(),
      region: (map['region'] ?? 'Jawa').toString(),
      originCode: originCode,
      originName: stationByCode[originCode]?.name ?? originCode,
      destinationCode: destCode,
      destinationName: stationByCode[destCode]?.name ?? destCode,
      serviceDate: _parseRequiredDate(map['service_date'], nowUtc),
      scheduledDeparture: _parseRequiredDate(map['scheduled_departure'], nowUtc),
      scheduledArrival: _parseRequiredDate(
        map['scheduled_arrival'],
        nowUtc.add(const Duration(hours: 4)),
      ),
      estimatedArrival: _parseNullableDate(map['estimated_arrival']),
      dataStatus: parsedStatus,
      tripStatus: (map['trip_status'] ?? parsedStatus.description).toString(),
      isSimulated: isSim || parsedStatus == TrainDataStatus.demo,
      dataSourceLabel: (map['data_source_label'] ??
              (isSim ? 'Simulasi Demo (Bukan Real-Time)' : 'Jadwal Operasional'))
          .toString(),
      delayMinutes: (map['delay_minutes'] is num)
          ? (map['delay_minutes'] as num).toInt()
          : 0,
      delayReason: map['delay_reason']?.toString(),
      currentLat: (map['current_lat'] is num)
          ? (map['current_lat'] as num).toDouble()
          : null,
      currentLng: (map['current_lng'] is num)
          ? (map['current_lng'] as num).toDouble()
          : null,
      heading: (map['heading'] is num) ? (map['heading'] as num).toDouble() : null,
      speedKmh:
          (map['speed_kmh'] is num) ? (map['speed_kmh'] as num).toDouble() : null,
      currentStationCode: map['current_station_code']?.toString().toUpperCase(),
      nextStationCode: map['next_station_code']?.toString().toUpperCase(),
      routeGeometry: geom,
      lastUpdatedAt: _parseNullableDate(map['last_updated_at']),
      stops: stops,
    );
  }
}

/// Model Kereta / Perjalanan Favorit (G. Favorites).
class FavoriteTrainModel {
  final String id;
  final String userId;
  final String? userEmail;
  final String? tripId;
  final String trainNumber;
  final String trainName;
  final String originCode;
  final String destinationCode;
  final bool notifyDelay;
  final bool notifyScheduleChange;
  final bool notifyServiceDisruption;
  final bool notifyArrivalInfo;
  final bool notifyStatusChange;
  final DateTime createdAt;

  const FavoriteTrainModel({
    required this.id,
    required this.userId,
    this.userEmail,
    this.tripId,
    required this.trainNumber,
    required this.trainName,
    required this.originCode,
    required this.destinationCode,
    this.notifyDelay = true,
    this.notifyScheduleChange = true,
    this.notifyServiceDisruption = true,
    this.notifyArrivalInfo = true,
    this.notifyStatusChange = true,
    required this.createdAt,
  });

  String get uniqueKey =>
      '${trainNumber.toUpperCase()}_${originCode.toUpperCase()}_${destinationCode.toUpperCase()}';

  FavoriteTrainModel copyWith({
    bool? notifyDelay,
    bool? notifyScheduleChange,
    bool? notifyServiceDisruption,
    bool? notifyArrivalInfo,
    bool? notifyStatusChange,
  }) {
    return FavoriteTrainModel(
      id: id,
      userId: userId,
      userEmail: userEmail,
      tripId: tripId,
      trainNumber: trainNumber,
      trainName: trainName,
      originCode: originCode,
      destinationCode: destinationCode,
      notifyDelay: notifyDelay ?? this.notifyDelay,
      notifyScheduleChange: notifyScheduleChange ?? this.notifyScheduleChange,
      notifyServiceDisruption:
          notifyServiceDisruption ?? this.notifyServiceDisruption,
      notifyArrivalInfo: notifyArrivalInfo ?? this.notifyArrivalInfo,
      notifyStatusChange: notifyStatusChange ?? this.notifyStatusChange,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'user_email': userEmail,
        'trip_id': tripId,
        'train_number': trainNumber,
        'train_name': trainName,
        'origin_station_code': originCode,
        'destination_station_code': destinationCode,
        'notify_delay': notifyDelay,
        'notify_schedule_change': notifyScheduleChange,
        'notify_service_disruption': notifyServiceDisruption,
        'notify_arrival_info': notifyArrivalInfo,
        'notify_status_change': notifyStatusChange,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  factory FavoriteTrainModel.fromMap(Map<String, dynamic> map) {
    return FavoriteTrainModel(
      id: (map['id'] ?? '').toString(),
      userId: (map['user_id'] ?? '').toString(),
      userEmail: map['user_email']?.toString(),
      tripId: map['trip_id']?.toString(),
      trainNumber: (map['train_number'] ?? '').toString(),
      trainName: (map['train_name'] ?? '').toString(),
      originCode: (map['origin_station_code'] ?? '').toString().toUpperCase(),
      destinationCode:
          (map['destination_station_code'] ?? '').toString().toUpperCase(),
      notifyDelay: map['notify_delay'] ?? true,
      notifyScheduleChange: map['notify_schedule_change'] ?? true,
      notifyServiceDisruption: map['notify_service_disruption'] ?? true,
      notifyArrivalInfo: map['notify_arrival_info'] ?? true,
      notifyStatusChange: map['notify_status_change'] ?? true,
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ??
          DateTime.now().toUtc(),
    );
  }
}

/// Jenis Event Notifikasi Resmi (E. Notifications).
enum TrainNotificationEventType {
  trainDelay('TRAIN_DELAY', 'Keterlambatan Kereta', 'DELAY', Color(0xFFEF4444), Icons.warning_amber_rounded),
  scheduleChange('SCHEDULE_CHANGE', 'Perubahan Jadwal', 'JADWAL', Color(0xFFF59E0B), Icons.edit_calendar_rounded),
  serviceDisruption('SERVICE_DISRUPTION', 'Gangguan Layanan', 'GANGGUAN', Color(0xFFDC2626), Icons.report_problem_rounded),
  arrivalInfo('ARRIVAL_INFO', 'Info Kedatangan', 'KEDATANGAN', Color(0xFF10B981), Icons.location_on_rounded),
  tripStatusChange('TRIP_STATUS_CHANGE', 'Perubahan Status', 'STATUS', Color(0xFF2563EB), Icons.sync_alt_rounded);

  final String code;
  final String label;
  final String shortTag;
  final Color color;
  final IconData icon;

  const TrainNotificationEventType(
    this.code,
    this.label,
    this.shortTag,
    this.color,
    this.icon,
  );

  static TrainNotificationEventType fromCode(String? code) {
    switch ((code ?? '').toUpperCase().trim()) {
      case 'TRAIN_DELAY':
        return TrainNotificationEventType.trainDelay;
      case 'SCHEDULE_CHANGE':
        return TrainNotificationEventType.scheduleChange;
      case 'SERVICE_DISRUPTION':
        return TrainNotificationEventType.serviceDisruption;
      case 'ARRIVAL_INFO':
        return TrainNotificationEventType.arrivalInfo;
      default:
        return TrainNotificationEventType.tripStatusChange;
    }
  }
}

/// Model Notifikasi Perjalanan dengan kunci anti-duplikasi & status pengiriman Brevo.
class TrainNotificationModel {
  final String id;
  final String userId;
  final String? recipientEmail;
  final String? tripId;
  final String? trainNumber;
  final String? trainName;
  final TrainNotificationEventType eventType;
  final String eventDedupKey;
  final String title;
  final String message;
  final bool isRead;
  final String brevoStatus; // PENDING, SENT, SKIPPED, FAILED
  final String? brevoMessageId;
  final String? brevoError;
  final DateTime createdAt;

  const TrainNotificationModel({
    required this.id,
    required this.userId,
    this.recipientEmail,
    this.tripId,
    this.trainNumber,
    this.trainName,
    required this.eventType,
    required this.eventDedupKey,
    required this.title,
    required this.message,
    this.isRead = false,
    this.brevoStatus = 'PENDING',
    this.brevoMessageId,
    this.brevoError,
    required this.createdAt,
  });

  TrainNotificationModel copyWith({
    bool? isRead,
    String? brevoStatus,
    String? brevoMessageId,
    String? brevoError,
  }) {
    return TrainNotificationModel(
      id: id,
      userId: userId,
      recipientEmail: recipientEmail,
      tripId: tripId,
      trainNumber: trainNumber,
      trainName: trainName,
      eventType: eventType,
      eventDedupKey: eventDedupKey,
      title: title,
      message: message,
      isRead: isRead ?? this.isRead,
      brevoStatus: brevoStatus ?? this.brevoStatus,
      brevoMessageId: brevoMessageId ?? this.brevoMessageId,
      brevoError: brevoError ?? this.brevoError,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'recipient_email': recipientEmail,
        'trip_id': tripId,
        'train_number': trainNumber,
        'train_name': trainName,
        'event_type': eventType.code,
        'event_dedup_key': eventDedupKey,
        'title': title,
        'message': message,
        'is_read': isRead,
        'brevo_status': brevoStatus,
        'brevo_message_id': brevoMessageId,
        'brevo_error': brevoError,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  factory TrainNotificationModel.fromMap(Map<String, dynamic> map) {
    return TrainNotificationModel(
      id: (map['id'] ?? '').toString(),
      userId: (map['user_id'] ?? '').toString(),
      recipientEmail: map['recipient_email']?.toString(),
      tripId: map['trip_id']?.toString(),
      trainNumber: map['train_number']?.toString(),
      trainName: map['train_name']?.toString(),
      eventType: TrainNotificationEventType.fromCode(map['event_type']?.toString()),
      eventDedupKey: (map['event_dedup_key'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      message: (map['message'] ?? '').toString(),
      isRead: map['is_read'] == true,
      brevoStatus: (map['brevo_status'] ?? 'SKIPPED').toString().toUpperCase(),
      brevoMessageId: map['brevo_message_id']?.toString(),
      brevoError: map['brevo_error']?.toString(),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ??
          DateTime.now().toUtc(),
    );
  }
}

/// Preferensi Notifikasi & Pengaturan Aplikasi Pengguna (H. User Profile).
class UserNotificationPreferences {
  final String userId;
  final String? userEmail;
  final bool emailNotificationsEnabled;
  final bool inAppNotificationsEnabled;
  final bool notifyDelay;
  final bool notifyScheduleChange;
  final bool notifyServiceDisruption;
  final bool notifyArrivalInfo;
  final bool notifyStatusChange;
  final String preferredTimezone; // WIB, WITA, WIT
  final bool autoFollowTrain;

  const UserNotificationPreferences({
    required this.userId,
    this.userEmail,
    this.emailNotificationsEnabled = true,
    this.inAppNotificationsEnabled = true,
    this.notifyDelay = true,
    this.notifyScheduleChange = true,
    this.notifyServiceDisruption = true,
    this.notifyArrivalInfo = true,
    this.notifyStatusChange = true,
    this.preferredTimezone = 'WIB',
    this.autoFollowTrain = true,
  });

  bool isEventAllowed(TrainNotificationEventType type) {
    switch (type) {
      case TrainNotificationEventType.trainDelay:
        return notifyDelay;
      case TrainNotificationEventType.scheduleChange:
        return notifyScheduleChange;
      case TrainNotificationEventType.serviceDisruption:
        return notifyServiceDisruption;
      case TrainNotificationEventType.arrivalInfo:
        return notifyArrivalInfo;
      case TrainNotificationEventType.tripStatusChange:
        return notifyStatusChange;
    }
  }

  UserNotificationPreferences copyWith({
    String? userEmail,
    bool? emailNotificationsEnabled,
    bool? inAppNotificationsEnabled,
    bool? notifyDelay,
    bool? notifyScheduleChange,
    bool? notifyServiceDisruption,
    bool? notifyArrivalInfo,
    bool? notifyStatusChange,
    String? preferredTimezone,
    bool? autoFollowTrain,
  }) {
    return UserNotificationPreferences(
      userId: userId,
      userEmail: userEmail ?? this.userEmail,
      emailNotificationsEnabled:
          emailNotificationsEnabled ?? this.emailNotificationsEnabled,
      inAppNotificationsEnabled:
          inAppNotificationsEnabled ?? this.inAppNotificationsEnabled,
      notifyDelay: notifyDelay ?? this.notifyDelay,
      notifyScheduleChange: notifyScheduleChange ?? this.notifyScheduleChange,
      notifyServiceDisruption:
          notifyServiceDisruption ?? this.notifyServiceDisruption,
      notifyArrivalInfo: notifyArrivalInfo ?? this.notifyArrivalInfo,
      notifyStatusChange: notifyStatusChange ?? this.notifyStatusChange,
      preferredTimezone: preferredTimezone ?? this.preferredTimezone,
      autoFollowTrain: autoFollowTrain ?? this.autoFollowTrain,
    );
  }

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'user_email': userEmail,
        'email_notifications_enabled': emailNotificationsEnabled,
        'in_app_notifications_enabled': inAppNotificationsEnabled,
        'notify_delay': notifyDelay,
        'notify_schedule_change': notifyScheduleChange,
        'notify_service_disruption': notifyServiceDisruption,
        'notify_arrival_info': notifyArrivalInfo,
        'notify_status_change': notifyStatusChange,
        'preferred_timezone': preferredTimezone,
        'auto_follow_train': autoFollowTrain,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

  factory UserNotificationPreferences.fromMap(Map<String, dynamic> map) {
    return UserNotificationPreferences(
      userId: (map['user_id'] ?? 'guest').toString(),
      userEmail: map['user_email']?.toString(),
      emailNotificationsEnabled: map['email_notifications_enabled'] ?? true,
      inAppNotificationsEnabled: map['in_app_notifications_enabled'] ?? true,
      notifyDelay: map['notify_delay'] ?? true,
      notifyScheduleChange: map['notify_schedule_change'] ?? true,
      notifyServiceDisruption: map['notify_service_disruption'] ?? true,
      notifyArrivalInfo: map['notify_arrival_info'] ?? true,
      notifyStatusChange: map['notify_status_change'] ?? true,
      preferredTimezone: (map['preferred_timezone'] ?? 'WIB').toString(),
      autoFollowTrain: map['auto_follow_train'] ?? true,
    );
  }
}

/// Hasil Pencarian Global (F. Search).
class GlobalSearchResult {
  final String query;
  final List<TrainTripModel> trains;
  final List<TrackStationModel> stations;
  final List<String> matchedRoutes;

  const GlobalSearchResult({
    required this.query,
    this.trains = const [],
    this.stations = const [],
    this.matchedRoutes = const [],
  });

  bool get isEmpty => trains.isEmpty && stations.isEmpty;
  int get totalCount => trains.length + stations.length;
}
