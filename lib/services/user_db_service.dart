import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';
import 'session_service.dart';
import 'auth_service.dart';
import 'security_guard.dart';
import 'supabase_storage_service.dart';
import 'brevo_notification_service.dart';

/// ============================================================================
/// DOMAIN MODELS (Strict Typing)
/// ============================================================================

class StationModel {
  final String code;
  final String name;
  final String city;
  final String region;

  const StationModel({
    required this.code,
    required this.name,
    required this.city,
    required this.region,
  });

  String get displayName => '$name ($code)';

  Map<String, dynamic> toMap() {
    return {'code': code, 'name': name, 'city': city, 'region': region};
  }

  factory StationModel.fromMap(Map<String, dynamic> map) {
    return StationModel(
      code: (map['code'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      city: (map['city'] ?? '').toString(),
      region: (map['region'] ?? 'Jawa').toString(),
    );
  }
}

class TrainScheduleModel {
  final String id;
  final String trainNumber;
  final String name;
  final String originCode;
  final String originName;
  final String originCity;
  final String destCode;
  final String destName;
  final String destCity;
  final String departureTime;
  final String arrivalTime;
  final String duration;
  final int baseFare;
  final List<String> availableClasses;
  final int availableSeats;

  const TrainScheduleModel({
    required this.id,
    required this.trainNumber,
    required this.name,
    required this.originCode,
    required this.originName,
    required this.originCity,
    required this.destCode,
    required this.destName,
    required this.destCity,
    required this.departureTime,
    required this.arrivalTime,
    required this.duration,
    required this.baseFare,
    required this.availableClasses,
    required this.availableSeats,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'train_number': trainNumber,
      'name': name,
      'origin_code': originCode,
      'origin_name': originName,
      'origin_city': originCity,
      'dest_code': destCode,
      'dest_name': destName,
      'dest_city': destCity,
      'departure_time': departureTime,
      'arrival_time': arrivalTime,
      'duration': duration,
      'base_fare': baseFare,
      'available_classes': availableClasses,
      'available_seats': availableSeats,
    };
  }

  factory TrainScheduleModel.fromMap(Map<String, dynamic> map) {
    return TrainScheduleModel(
      id: (map['id'] ?? '').toString(),
      trainNumber: (map['train_number'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      originCode: (map['origin_code'] ?? '').toString(),
      originName: (map['origin_name'] ?? '').toString(),
      originCity: (map['origin_city'] ?? '').toString(),
      destCode: (map['dest_code'] ?? '').toString(),
      destName: (map['dest_name'] ?? '').toString(),
      destCity: (map['dest_city'] ?? '').toString(),
      departureTime: (map['departure_time'] ?? '').toString(),
      arrivalTime: (map['arrival_time'] ?? '').toString(),
      duration: (map['duration'] ?? '8j 00m').toString(),
      baseFare:
          int.tryParse(map['base_fare']?.toString() ?? '250000') ?? 250000,
      availableClasses:
          (map['available_classes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['Eksekutif', 'Ekonomi'],
      availableSeats:
          int.tryParse(map['available_seats']?.toString() ?? '50') ?? 50,
    );
  }
}

class RecentSearchModel {
  final String id;
  final String originCode;
  final String originName;
  final String destCode;
  final String destName;
  final String travelDate;
  final String passengers;
  final DateTime createdAt;

  const RecentSearchModel({
    required this.id,
    required this.originCode,
    required this.originName,
    required this.destCode,
    required this.destName,
    required this.travelDate,
    required this.passengers,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'origin_code': originCode,
      'origin_name': originName,
      'dest_code': destCode,
      'dest_name': destName,
      'travel_date': travelDate,
      'passengers': passengers,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory RecentSearchModel.fromMap(Map<String, dynamic> map) {
    return RecentSearchModel(
      id: (map['id'] ?? '').toString(),
      originCode: (map['origin_code'] ?? '').toString(),
      originName: (map['origin_name'] ?? '').toString(),
      destCode: (map['dest_code'] ?? '').toString(),
      destName: (map['dest_name'] ?? '').toString(),
      travelDate: (map['travel_date'] ?? '').toString(),
      passengers: (map['passengers'] ?? '1 Dewasa, 0 Bayi').toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class BookingModel {
  final String bookingId;
  final String passengerName;
  final String passengerEmail;
  final String passengerPhone;
  final String passengerNik;
  final String trainName;
  final String trainClass;
  final String originCode;
  final String originName;
  final String originCity;
  final String destCode;
  final String destName;
  final String destCity;
  final String travelDate;
  final String departureTime;
  final String arrivalTime;
  final String seatNumber;
  final int totalAmount;
  final String status; // 'Menunggu Pembayaran', 'Sudah Dibayar', 'Perjalanan Selesai', 'Dibatalkan', 'Kedaluwarsa'
  final String paymentMethod;
  final String vaNumber;
  final DateTime createdAt;
  final String? cancelReason;
  final int? refundAmount;
  final List<Map<String, String>>? passengers;
  final String? qrCodeUrl;

  int get passengerCount =>
      (passengers != null && passengers!.isNotEmpty) ? passengers!.length : 1;

  List<Map<String, String>> get passengerList =>
      (passengers != null && passengers!.isNotEmpty)
      ? passengers!
      : [
          {
            'name': passengerName,
            'id': passengerNik,
            'seat': seatNumber,
            'type': 'Dewasa (Adult)',
          },
        ];

  const BookingModel({
    required this.bookingId,
    required this.passengerName,
    required this.passengerEmail,
    required this.passengerPhone,
    required this.passengerNik,
    required this.trainName,
    required this.trainClass,
    required this.originCode,
    required this.originName,
    required this.originCity,
    required this.destCode,
    required this.destName,
    required this.destCity,
    required this.travelDate,
    required this.departureTime,
    required this.arrivalTime,
    required this.seatNumber,
    required this.totalAmount,
    required this.status,
    required this.paymentMethod,
    required this.vaNumber,
    required this.createdAt,
    this.cancelReason,
    this.refundAmount,
    this.passengers,
    this.qrCodeUrl,
  });

  BookingModel copyWith({
    String? passengerName,
    String? passengerEmail,
    String? passengerPhone,
    String? status,
    String? cancelReason,
    int? refundAmount,
    List<Map<String, String>>? passengers,
    String? qrCodeUrl,
  }) {
    return BookingModel(
      bookingId: bookingId,
      passengerName: passengerName ?? this.passengerName,
      passengerEmail: passengerEmail ?? this.passengerEmail,
      passengerPhone: passengerPhone ?? this.passengerPhone,
      passengerNik: passengerNik,
      trainName: trainName,
      trainClass: trainClass,
      originCode: originCode,
      originName: originName,
      originCity: originCity,
      destCode: destCode,
      destName: destName,
      destCity: destCity,
      travelDate: travelDate,
      departureTime: departureTime,
      arrivalTime: arrivalTime,
      seatNumber: seatNumber,
      totalAmount: totalAmount,
      status: status ?? this.status,
      paymentMethod: paymentMethod,
      vaNumber: vaNumber,
      createdAt: createdAt,
      cancelReason: cancelReason ?? this.cancelReason,
      refundAmount: refundAmount ?? this.refundAmount,
      passengers: passengers ?? this.passengers,
      qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'booking_id': bookingId,
      'passenger_name': passengerName,
      'passenger_email': passengerEmail,
      'passenger_phone': passengerPhone,
      'passenger_nik': passengerNik,
      'train_name': trainName,
      'train_class': trainClass,
      'origin_code': originCode,
      'origin_name': originName,
      'origin_city': originCity,
      'dest_code': destCode,
      'dest_name': destName,
      'dest_city': destCity,
      'travel_date': travelDate,
      'departure_time': departureTime,
      'arrival_time': arrivalTime,
      'seat_number': seatNumber,
      'total_amount': totalAmount,
      'status': status,
      'payment_method': paymentMethod,
      'va_number': vaNumber,
      'created_at': createdAt.toIso8601String(),
      'cancel_reason': cancelReason,
      'refund_amount': refundAmount,
      if (passengers != null) 'passengers': passengers,
      if (qrCodeUrl != null) 'qr_code_url': qrCodeUrl,
    };
  }

  /// Payload khusus PostgREST tabel `public.bookings` yang 100% sesuai skema kolom resmi
  /// sehingga tidak pernah memicu HTTP 400 Bad Request (PGRST204).
  Map<String, dynamic> toSupabaseMap({
    String? userId,
    String? trainNumber,
    String? wagonClass,
  }) {
    final raw = <String, dynamic>{
      'booking_id': SecurityGuard.sanitizeIdentifier(bookingId),
      if (SecurityGuard.isValidUuid(userId)) 'user_id': userId!.trim(),
      'passenger_name': passengerName,
      'passenger_email': passengerEmail,
      'passenger_phone': passengerPhone,
      'passenger_nik': passengerNik,
      'train_number': trainNumber ?? trainName.split(' ').take(2).join(' '),
      'train_name': trainName,
      'train_class': trainClass,
      'wagon_class': wagonClass ?? trainClass.split('•').first.trim(),
      'route': '$originCode -> $destCode',
      'origin_code': originCode,
      'origin_name': originName,
      'origin_city': originCity,
      'dest_code': destCode,
      'dest_name': destName,
      'dest_city': destCity,
      'travel_date': travelDate,
      'departure_time': departureTime,
      'arrival_time': arrivalTime,
      'seat_number': seatNumber,
      'amount': SecurityGuard.sanitizeAmount(totalAmount),
      'total_amount': SecurityGuard.sanitizeAmount(totalAmount),
      'status': status,
      'payment_method': paymentMethod,
      'va_number': vaNumber,
      if (cancelReason != null) 'cancel_reason': cancelReason,
      if (refundAmount != null)
        'refund_amount': SecurityGuard.sanitizeAmount(refundAmount!),
      'created_at': createdAt.toIso8601String(),
    };
    return SecurityGuard.sanitizePayload(raw, SecurityGuard.bookingsColumns);
  }

  factory BookingModel.fromMap(Map<String, dynamic> map) {
    List<Map<String, String>>? parsedPassengers;
    if (map['passengers'] != null) {
      try {
        final dynamic raw = map['passengers'];
        if (raw is List) {
          parsedPassengers = raw
              .map(
                (e) => Map<String, String>.from(
                  (e as Map).map(
                    (k, v) => MapEntry(k.toString(), v.toString()),
                  ),
                ),
              )
              .toList();
        } else if (raw is String && raw.startsWith('[')) {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            parsedPassengers = decoded
                .map(
                  (e) => Map<String, String>.from(
                    (e as Map).map(
                      (k, v) => MapEntry(k.toString(), v.toString()),
                    ),
                  ),
                )
                .toList();
          }
        }
      } catch (_) {}
    }

    return BookingModel(
      bookingId: (map['booking_id'] ?? '').toString(),
      passengerName: (map['passenger_name'] ?? 'Mukhammad Safid Maulana')
          .toString(),
      passengerEmail: (map['passenger_email'] ?? 'safidsafid182@gmail.com')
          .toString(),
      passengerPhone: (map['passenger_phone'] ?? '+62 857-4849-4469')
          .toString(),
      passengerNik: (map['passenger_nik'] ?? '3514062607090001').toString(),
      trainName: (map['train_name'] ?? 'KA Argo Bromo Anggrek').toString(),
      trainClass: (map['train_class'] ?? 'Eksekutif').toString(),
      originCode: (map['origin_code'] ?? 'GMR').toString(),
      originName: (map['origin_name'] ?? 'Gambir').toString(),
      originCity: (map['origin_city'] ?? 'Jakarta Pusat').toString(),
      destCode: (map['dest_code'] ?? 'SBI').toString(),
      destName: (map['dest_name'] ?? 'Surabaya Pasarturi').toString(),
      destCity: (map['dest_city'] ?? 'Surabaya').toString(),
      travelDate: (map['travel_date'] ?? '25 Okt 2024').toString(),
      departureTime: (map['departure_time'] ?? '08:20 WIB').toString(),
      arrivalTime: (map['arrival_time'] ?? '16:25 WIB').toString(),
      seatNumber: (map['seat_number'] ?? 'EKS-2 / 5C').toString(),
      totalAmount:
          int.tryParse(map['total_amount']?.toString() ?? '640000') ?? 640000,
      status: (map['status'] ?? 'Sudah Dibayar').toString(),
      paymentMethod: (map['payment_method'] ?? 'BCA Virtual Account')
          .toString(),
      vaNumber: (map['va_number'] ?? 'VA-9001842910').toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      cancelReason: map['cancel_reason']?.toString(),
      refundAmount: int.tryParse(map['refund_amount']?.toString() ?? ''),
      passengers: parsedPassengers,
      qrCodeUrl: (map['qr_code_url'] ?? map['qrCodeUrl'])?.toString(),
    );
  }
}

/// ============================================================================
/// SERVICE LAYER (Database & Local Fallback)
/// ============================================================================

class UserDatabaseService {
  static const String _keyRecentSearches = 'tka_recent_searches_cache';
  static const String _keyBookings = 'tka_bookings_cache';

  static final List<StationModel> _stations = [];
  static final List<TrainScheduleModel> _trainSchedules = [];
  static final List<RecentSearchModel> _recentSearches = [];
  static final List<BookingModel> _bookings = [];
  static bool _isInitialized = false;
  static String _lastLoadedUser = '';

  // Smart In-Memory TTL Cache (mencegah network round-trip berulang saat berpindah tab/fitur)
  static DateTime? _stationsFetchedAt;
  static DateTime? _schedulesFetchedAt;
  static DateTime? _recentSearchesFetchedAt;
  static DateTime? _bookingsFetchedAt;
  static Future<void>? _inFlightBookingsSync;

  static const Duration _stationsTtl = Duration(minutes: 10);
  static const Duration _schedulesTtl = Duration(minutes: 5);
  static const Duration _recentSearchesTtl = Duration(seconds: 60);
  static const Duration _bookingsTtl = Duration(seconds: 25);

  static bool _isCacheFresh(DateTime? fetchedAt, Duration ttl) {
    if (fetchedAt == null) return false;
    return DateTime.now().difference(fetchedAt) < ttl;
  }

  /// Paksa sinkronisasi ulang bookings pada pemanggilan berikutnya (otomatis dipanggil saat transaksi baru/bayar/batal)
  static void invalidateBookingsCache() {
    _bookingsFetchedAt = null;
  }

  static Future<String> _getBookingsKey() async {
    final email =
        (await SessionService.getUserEmail())?.toLowerCase().trim() ?? '';
    final name = (await SessionService.getUserName()).toLowerCase().trim();
    final userKey = email.isNotEmpty
        ? email
        : (name.isNotEmpty ? name : 'guest');
    return '${_keyBookings}_$userKey';
  }

  static Future<String> _getSearchesKey() async {
    final email =
        (await SessionService.getUserEmail())?.toLowerCase().trim() ?? '';
    final name = (await SessionService.getUserName()).toLowerCase().trim();
    final userKey = email.isNotEmpty
        ? email
        : (name.isNotEmpty ? name : 'guest');
    return '${_keyRecentSearches}_$userKey';
  }

  static bool _isValidUuid(String? val) {
    if (val == null || val.isEmpty) return false;
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidRegex.hasMatch(val);
  }

  /// Membuat string UUID v4 deterministik dari kode booking (misal TKA-661350)
  /// agar kompatibel jika kolom booking_id di Supabase masih bertipe UUID.
  static String _codeToUuid(String code) {
    final clean = code.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    final hex = clean.codeUnits
        .map((c) => c.toRadixString(16))
        .join()
        .padRight(32, '0')
        .substring(0, 32);
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-4${hex.substring(13, 16)}-a${hex.substring(17, 20)}-${hex.substring(20, 32)}';
  }

  /// Inisialisasi Master Data Stasiun, Jadwal Kereta & Sinkronisasi DB per User
  static Future<void> initialize({bool forceReload = false}) async {
    final currentEmail =
        (await SessionService.getUserEmail())?.toLowerCase().trim() ?? '';
    if (_isInitialized && !forceReload && _lastLoadedUser == currentEmail) {
      return;
    }

    _lastLoadedUser = currentEmail;
    _bookingsFetchedAt = null;
    _recentSearchesFetchedAt = null;
    _populateMasterStations();
    _populateMasterTrainSchedules();
    await _loadLocalCache();

    // Coba sinkronisasi langsung dengan Supabase jika tabel sudah ada di cloud
    _syncWithSupabaseBackground();

    _isInitialized = true;
  }

  // ===========================================================================
  // 1. MASTER STASIUN SE-INDONESIA (Jabodetabek, Jabar, Jateng, Jatim, Sumatera)
  // ===========================================================================
  static void _populateMasterStations() {
    _stations.clear();
    _stations.addAll([
      // Jabodetabek
      const StationModel(
        code: 'GMR',
        name: 'Gambir',
        city: 'Jakarta Pusat',
        region: 'Jabodetabek',
      ),
      const StationModel(
        code: 'PSE',
        name: 'Pasar Senen',
        city: 'Jakarta Pusat',
        region: 'Jabodetabek',
      ),
      const StationModel(
        code: 'JNG',
        name: 'Jatinegara',
        city: 'Jakarta Timur',
        region: 'Jabodetabek',
      ),
      const StationModel(
        code: 'MRI',
        name: 'Manggarai',
        city: 'Jakarta Selatan',
        region: 'Jabodetabek',
      ),
      const StationModel(
        code: 'JAKK',
        name: 'Jakarta Kota',
        city: 'Jakarta Barat',
        region: 'Jabodetabek',
      ),
      const StationModel(
        code: 'BKS',
        name: 'Bekasi',
        city: 'Bekasi',
        region: 'Jabodetabek',
      ),
      const StationModel(
        code: 'BOO',
        name: 'Bogor',
        city: 'Bogor',
        region: 'Jabodetabek',
      ),

      // Jawa Barat
      const StationModel(
        code: 'BD',
        name: 'Bandung',
        city: 'Bandung',
        region: 'Jawa Barat',
      ),
      const StationModel(
        code: 'KAC',
        name: 'Kiaracondong',
        city: 'Bandung',
        region: 'Jawa Barat',
      ),
      const StationModel(
        code: 'CMI',
        name: 'Cimahi',
        city: 'Cimahi',
        region: 'Jawa Barat',
      ),
      const StationModel(
        code: 'PDL',
        name: 'Padalarang',
        city: 'Bandung Barat',
        region: 'Jawa Barat',
      ),
      const StationModel(
        code: 'CN',
        name: 'Cirebon',
        city: 'Cirebon',
        region: 'Jawa Barat',
      ),
      const StationModel(
        code: 'CNP',
        name: 'Cirebon Prujakan',
        city: 'Cirebon',
        region: 'Jawa Barat',
      ),
      const StationModel(
        code: 'JTB',
        name: 'Jatibarang',
        city: 'Indramayu',
        region: 'Jawa Barat',
      ),
      const StationModel(
        code: 'HGL',
        name: 'Haurgeulis',
        city: 'Indramayu',
        region: 'Jawa Barat',
      ),
      const StationModel(
        code: 'CKR',
        name: 'Cikarang',
        city: 'Bekasi',
        region: 'Jawa Barat',
      ),
      const StationModel(
        code: 'KW',
        name: 'Karawang',
        city: 'Karawang',
        region: 'Jawa Barat',
      ),
      const StationModel(
        code: 'PWK',
        name: 'Purwakarta',
        city: 'Purwakarta',
        region: 'Jawa Barat',
      ),
      const StationModel(
        code: 'TSM',
        name: 'Tasikmalaya',
        city: 'Tasikmalaya',
        region: 'Jawa Barat',
      ),
      const StationModel(
        code: 'CI',
        name: 'Ciamis',
        city: 'Ciamis',
        region: 'Jawa Barat',
      ),
      const StationModel(
        code: 'BJR',
        name: 'Banjar',
        city: 'Banjar',
        region: 'Jawa Barat',
      ),

      // Banten
      const StationModel(
        code: 'RK',
        name: 'Rangkasbitung',
        city: 'Lebak',
        region: 'Banten',
      ),
      const StationModel(
        code: 'SG',
        name: 'Serang',
        city: 'Serang',
        region: 'Banten',
      ),
      const StationModel(
        code: 'MER',
        name: 'Merak',
        city: 'Cilegon',
        region: 'Banten',
      ),

      // Jawa Tengah & DIY
      const StationModel(
        code: 'YK',
        name: 'Yogyakarta',
        city: 'Yogyakarta',
        region: 'Jawa Tengah & DIY',
      ),
      const StationModel(
        code: 'LPN',
        name: 'Lempuyangan',
        city: 'Yogyakarta',
        region: 'Jawa Tengah & DIY',
      ),
      const StationModel(
        code: 'WT',
        name: 'Wates',
        city: 'Kulon Progo',
        region: 'Jawa Tengah & DIY',
      ),
      const StationModel(
        code: 'SLO',
        name: 'Solo Balapan',
        city: 'Surakarta',
        region: 'Jawa Tengah & DIY',
      ),
      const StationModel(
        code: 'PWS',
        name: 'Purwosari',
        city: 'Surakarta',
        region: 'Jawa Tengah & DIY',
      ),
      const StationModel(
        code: 'SK',
        name: 'Solo Jebres',
        city: 'Surakarta',
        region: 'Jawa Tengah & DIY',
      ),
      const StationModel(
        code: 'KT',
        name: 'Klaten',
        city: 'Klaten',
        region: 'Jawa Tengah & DIY',
      ),
      const StationModel(
        code: 'SMT',
        name: 'Semarang Tawang',
        city: 'Semarang',
        region: 'Jawa Tengah & DIY',
      ),
      const StationModel(
        code: 'SMC',
        name: 'Semarang Poncol',
        city: 'Semarang',
        region: 'Jawa Tengah & DIY',
      ),
      const StationModel(
        code: 'WLR',
        name: 'Weleri',
        city: 'Kendal',
        region: 'Jawa Tengah & DIY',
      ),
      const StationModel(
        code: 'PK',
        name: 'Pekalongan',
        city: 'Pekalongan',
        region: 'Jawa Tengah & DIY',
      ),
      const StationModel(
        code: 'PML',
        name: 'Pemalang',
        city: 'Pemalang',
        region: 'Jawa Tengah & DIY',
      ),
      const StationModel(
        code: 'TG',
        name: 'Tegal',
        city: 'Tegal',
        region: 'Jawa Tengah & DIY',
      ),
      const StationModel(
        code: 'BB',
        name: 'Brebes',
        city: 'Brebes',
        region: 'Jawa Tengah & DIY',
      ),
      const StationModel(
        code: 'PWT',
        name: 'Purwokerto',
        city: 'Banyumas',
        region: 'Jawa Tengah & DIY',
      ),
      const StationModel(
        code: 'KYA',
        name: 'Kroya',
        city: 'Cilacap',
        region: 'Jawa Tengah & DIY',
      ),
      const StationModel(
        code: 'CP',
        name: 'Cilacap',
        city: 'Cilacap',
        region: 'Jawa Tengah & DIY',
      ),
      const StationModel(
        code: 'GB',
        name: 'Gombong',
        city: 'Kebumen',
        region: 'Jawa Tengah & DIY',
      ),
      const StationModel(
        code: 'KM',
        name: 'Kebumen',
        city: 'Kebumen',
        region: 'Jawa Tengah & DIY',
      ),
      const StationModel(
        code: 'KTA',
        name: 'Kutoarjo',
        city: 'Purworejo',
        region: 'Jawa Tengah & DIY',
      ),
      const StationModel(
        code: 'CU',
        name: 'Cepu',
        city: 'Blora',
        region: 'Jawa Tengah & DIY',
      ),

      // Jawa Timur
      const StationModel(
        code: 'SBI',
        name: 'Surabaya Pasarturi',
        city: 'Surabaya',
        region: 'Jawa Timur',
      ),
      const StationModel(
        code: 'SGU',
        name: 'Surabaya Gubeng',
        city: 'Surabaya',
        region: 'Jawa Timur',
      ),
      const StationModel(
        code: 'WO',
        name: 'Wonokromo',
        city: 'Surabaya',
        region: 'Jawa Timur',
      ),
      const StationModel(
        code: 'SDA',
        name: 'Sidoarjo',
        city: 'Sidoarjo',
        region: 'Jawa Timur',
      ),
      const StationModel(
        code: 'BG',
        name: 'Bangil',
        city: 'Pasuruan',
        region: 'Jawa Timur',
      ),
      const StationModel(
        code: 'PS',
        name: 'Pasuruan',
        city: 'Pasuruan',
        region: 'Jawa Timur',
      ),
      const StationModel(
        code: 'PB',
        name: 'Probolinggo',
        city: 'Probolinggo',
        region: 'Jawa Timur',
      ),
      const StationModel(
        code: 'KK',
        name: 'Klakah',
        city: 'Lumajang',
        region: 'Jawa Timur',
      ),
      const StationModel(
        code: 'TGL',
        name: 'Tanggul',
        city: 'Jember',
        region: 'Jawa Timur',
      ),
      const StationModel(
        code: 'JR',
        name: 'Jember',
        city: 'Jember',
        region: 'Jawa Timur',
      ),
      const StationModel(
        code: 'KBR',
        name: 'Kalibaru',
        city: 'Banyuwangi',
        region: 'Jawa Timur',
      ),
      const StationModel(
        code: 'RGP',
        name: 'Rogojampi',
        city: 'Banyuwangi',
        region: 'Jawa Timur',
      ),
      const StationModel(
        code: 'BWI',
        name: 'Banyuwangi Kota',
        city: 'Banyuwangi',
        region: 'Jawa Timur',
      ),
      const StationModel(
        code: 'KTG',
        name: 'Ketapang',
        city: 'Banyuwangi',
        region: 'Jawa Timur',
      ),
      const StationModel(
        code: 'ML',
        name: 'Malang',
        city: 'Malang',
        region: 'Jawa Timur',
      ),
      const StationModel(
        code: 'MLK',
        name: 'Malang Kota Lama',
        city: 'Malang',
        region: 'Jawa Timur',
      ),
      const StationModel(
        code: 'LW',
        name: 'Lawang',
        city: 'Malang',
        region: 'Jawa Timur',
      ),
      const StationModel(
        code: 'KPN',
        name: 'Kepanjen',
        city: 'Malang',
        region: 'Jawa Timur',
      ),
      const StationModel(
        code: 'MR',
        name: 'Mojokerto',
        city: 'Mojokerto',
        region: 'Jawa Timur',
      ),
      const StationModel(
        code: 'JG',
        name: 'Jombang',
        city: 'Jombang',
        region: 'Jawa Timur',
      ),
      const StationModel(
        code: 'KTS',
        name: 'Kertosono',
        city: 'Nganjuk',
        region: 'Jawa Timur',
      ),
      const StationModel(
        code: 'NJ',
        name: 'Nganjuk',
        city: 'Nganjuk',
        region: 'Jawa Timur',
      ),
      const StationModel(
        code: 'MN',
        name: 'Madiun',
        city: 'Madiun',
        region: 'Jawa Timur',
      ),
      const StationModel(
        code: 'CRB',
        name: 'Caruban',
        city: 'Madiun',
        region: 'Jawa Timur',
      ),
      const StationModel(
        code: 'KD',
        name: 'Kediri',
        city: 'Kediri',
        region: 'Jawa Timur',
      ),
      const StationModel(
        code: 'TA',
        name: 'Tulungagung',
        city: 'Tulungagung',
        region: 'Jawa Timur',
      ),
      const StationModel(
        code: 'BL',
        name: 'Blitar',
        city: 'Blitar',
        region: 'Jawa Timur',
      ),
      const StationModel(
        code: 'LMG',
        name: 'Lamongan',
        city: 'Lamongan',
        region: 'Jawa Timur',
      ),
      const StationModel(
        code: 'BBT',
        name: 'Babat',
        city: 'Lamongan',
        region: 'Jawa Timur',
      ),
      const StationModel(
        code: 'BJN',
        name: 'Bojonegoro',
        city: 'Bojonegoro',
        region: 'Jawa Timur',
      ),

      // Sumatera
      const StationModel(
        code: 'MDN',
        name: 'Medan',
        city: 'Medan',
        region: 'Sumatera',
      ),
      const StationModel(
        code: 'KNM',
        name: 'Kualanamu',
        city: 'Deli Serdang',
        region: 'Sumatera',
      ),
      const StationModel(
        code: 'TNK',
        name: 'Tanjung Karang',
        city: 'Bandar Lampung',
        region: 'Sumatera',
      ),
      const StationModel(
        code: 'KPT',
        name: 'Kertapati',
        city: 'Palembang',
        region: 'Sumatera',
      ),
      const StationModel(
        code: 'PD',
        name: 'Padang',
        city: 'Padang',
        region: 'Sumatera',
      ),
    ]);
  }

  // ===========================================================================
  // 2. MASTER JADWAL KERETA API LINTAS PULAU JAWA
  // ===========================================================================
  static void _populateMasterTrainSchedules() {
    _trainSchedules.clear();
    _trainSchedules.addAll([
      const TrainScheduleModel(
        id: 'SCH-001',
        trainNumber: 'KA 2',
        name: 'KA Argo Bromo Anggrek',
        originCode: 'GMR',
        originName: 'Gambir',
        originCity: 'Jakarta Pusat',
        destCode: 'SBI',
        destName: 'Surabaya Pasarturi',
        destCity: 'Surabaya',
        departureTime: '08:20 WIB',
        arrivalTime: '16:25 WIB',
        duration: '8j 05m',
        baseFare: 640000,
        availableClasses: ['Eksekutif', 'Luxury'],
        availableSeats: 32,
      ),
      const TrainScheduleModel(
        id: 'SCH-002',
        trainNumber: 'KA 68',
        name: 'KA Taksaka',
        originCode: 'GMR',
        originName: 'Gambir',
        originCity: 'Jakarta Pusat',
        destCode: 'YK',
        destName: 'Yogyakarta',
        destCity: 'Yogyakarta',
        departureTime: '09:10 WIB',
        arrivalTime: '15:20 WIB',
        duration: '6j 10m',
        baseFare: 550000,
        availableClasses: ['Eksekutif', 'Luxury'],
        availableSeats: 45,
      ),
      const TrainScheduleModel(
        id: 'SCH-003',
        trainNumber: 'KA 44',
        name: 'KA Argo Parahyangan',
        originCode: 'GMR',
        originName: 'Gambir',
        originCity: 'Jakarta Pusat',
        destCode: 'BD',
        destName: 'Bandung',
        destCity: 'Bandung',
        departureTime: '06:30 WIB',
        arrivalTime: '09:15 WIB',
        duration: '2j 45m',
        baseFare: 150000,
        availableClasses: ['Ekonomi', 'Eksekutif'],
        availableSeats: 120,
      ),
      const TrainScheduleModel(
        id: 'SCH-004',
        trainNumber: 'KA 66',
        name: 'KA Turangga',
        originCode: 'BD',
        originName: 'Bandung',
        originCity: 'Bandung',
        destCode: 'SGU',
        destName: 'Surabaya Gubeng',
        destCity: 'Surabaya',
        departureTime: '18:10 WIB',
        arrivalTime: '04:50 WIB',
        duration: '10j 40m',
        baseFare: 490000,
        availableClasses: ['Eksekutif'],
        availableSeats: 28,
      ),
      const TrainScheduleModel(
        id: 'SCH-005',
        trainNumber: 'KA 92',
        name: 'KA Lodaya',
        originCode: 'BD',
        originName: 'Bandung',
        originCity: 'Bandung',
        destCode: 'SLO',
        destName: 'Solo Balapan',
        destCity: 'Surakarta',
        departureTime: '07:05 WIB',
        arrivalTime: '15:40 WIB',
        duration: '8j 35m',
        baseFare: 295000,
        availableClasses: ['Ekonomi', 'Eksekutif'],
        availableSeats: 64,
      ),
      const TrainScheduleModel(
        id: 'SCH-006',
        trainNumber: 'KA 134',
        name: 'KA Fajar Utama Solo',
        originCode: 'PSE',
        originName: 'Pasar Senen',
        originCity: 'Jakarta Pusat',
        destCode: 'SLO',
        destName: 'Solo Balapan',
        destCity: 'Surakarta',
        departureTime: '05:55 WIB',
        arrivalTime: '13:45 WIB',
        duration: '7j 50m',
        baseFare: 240000,
        availableClasses: ['Ekonomi', 'Eksekutif'],
        availableSeats: 88,
      ),
      const TrainScheduleModel(
        id: 'SCH-007',
        trainNumber: 'KA 56',
        name: 'KA Gajayana',
        originCode: 'GMR',
        originName: 'Gambir',
        originCity: 'Jakarta Pusat',
        destCode: 'ML',
        destName: 'Malang',
        destCity: 'Malang',
        departureTime: '18:40 WIB',
        arrivalTime: '07:15 WIB',
        duration: '12j 35m',
        baseFare: 680000,
        availableClasses: ['Eksekutif', 'Luxury'],
        availableSeats: 18,
      ),

      // Rute Surabaya - Pasuruan (SGU -> PS)
      const TrainScheduleModel(
        id: 'SCH-008',
        trainNumber: '209A',
        name: 'MUTIARA TIMUR (209A)',
        originCode: 'SGU',
        originName: 'Surabaya Gubeng',
        originCity: 'Surabaya',
        destCode: 'PS',
        destName: 'Pasuruan',
        destCity: 'Pasuruan',
        departureTime: '09.24 WIB',
        arrivalTime: '10.43 WIB',
        duration: '01j 19m',
        baseFare: 150000,
        availableClasses: ['Ekonomi', 'Eksekutif'],
        availableSeats: 37,
      ),
      const TrainScheduleModel(
        id: 'SCH-009',
        trainNumber: '278',
        name: 'SRI TANJUNG (278)',
        originCode: 'SGU',
        originName: 'Surabaya Gubeng',
        originCity: 'Surabaya',
        destCode: 'PS',
        destName: 'Pasuruan',
        destCity: 'Pasuruan',
        departureTime: '13.34 WIB',
        arrivalTime: '14.52 WIB',
        duration: '01j 18m',
        baseFare: 88000,
        availableClasses: ['Ekonomi'],
        availableSeats: 9,
      ),
      const TrainScheduleModel(
        id: 'SCH-010',
        trainNumber: '248C',
        name: 'LOGAWA (248C)',
        originCode: 'SGU',
        originName: 'Surabaya Gubeng',
        originCity: 'Surabaya',
        destCode: 'PS',
        destName: 'Pasuruan',
        destCity: 'Pasuruan',
        departureTime: '14.45 WIB',
        arrivalTime: '16.18 WIB',
        duration: '01j 33m',
        baseFare: 100000,
        availableClasses: ['Ekonomi'],
        availableSeats: 25,
      ),

      // Rute Malang Kota Lama - Surabaya Gubeng (MLK -> SGU)
      const TrainScheduleModel(
        id: 'SCH-011',
        trainNumber: 'KA Express 1',
        name: 'KA Malang Express (KA Express 1)',
        originCode: 'MLK',
        originName: 'Malang Kota Lama',
        originCity: 'Malang',
        destCode: 'SGU',
        destName: 'Surabaya Gubeng',
        destCity: 'Surabaya',
        departureTime: '08:00 WIB',
        arrivalTime: '14:30 WIB',
        duration: '6j 30m',
        baseFare: 224000,
        availableClasses: ['Ekonomi', 'Eksekutif'],
        availableSeats: 30,
      ),
      const TrainScheduleModel(
        id: 'SCH-012',
        trainNumber: '371',
        name: 'KA Penataran (371)',
        originCode: 'MLK',
        originName: 'Malang Kota Lama',
        originCity: 'Malang',
        destCode: 'SGU',
        destName: 'Surabaya Gubeng',
        destCity: 'Surabaya',
        departureTime: '11:15 WIB',
        arrivalTime: '13:45 WIB',
        duration: '2j 30m',
        baseFare: 18000,
        availableClasses: ['Ekonomi'],
        availableSeats: 40,
      ),

      // Rute Surabaya Gubeng - Bangil (SGU -> BG)
      const TrainScheduleModel(
        id: 'SCH-013',
        trainNumber: '266',
        name: 'KA Probowangi (266)',
        originCode: 'SGU',
        originName: 'Surabaya Gubeng',
        originCity: 'Surabaya',
        destCode: 'BG',
        destName: 'Bangil',
        destCity: 'Pasuruan',
        departureTime: '05:30 WIB',
        arrivalTime: '06:40 WIB',
        duration: '1j 10m',
        baseFare: 29000,
        availableClasses: ['Ekonomi'],
        availableSeats: 20,
      ),
    ]);
  }

  // ===========================================================================
  // 3. PERSISTENCE & CACHE LOKAL
  // ===========================================================================
  static Future<void> _loadLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final currentUserName = await SessionService.getUserName();
      final currentUserEmail =
          (await SessionService.getUserEmail())?.toLowerCase().trim() ?? '';
      final isDemoSamuel =
          currentUserEmail == 'kocak@co.id' ||
          currentUserName.toLowerCase() == 'samuel';

      // 1. Recent searches (ISOLASI PER USER)
      final searchKey = await _getSearchesKey();
      final rawSearches = prefs.getString(searchKey);
      _recentSearches.clear();
      if (rawSearches != null) {
        final List<dynamic> list = jsonDecode(rawSearches);
        _recentSearches.addAll(list.map((m) => RecentSearchModel.fromMap(m)));
      } else {
        // HANYA seed data demo jika user adalah Samuel (kocak@co.id). User baru start KOSONG (0 riwayat)!
        if (isDemoSamuel) {
          _recentSearches.addAll([
            RecentSearchModel(
              id: 'srch-1',
              originCode: 'PSE',
              originName: 'Pasarsenen (PSE)',
              destCode: 'BD',
              destName: 'Bandung (BD)',
              travelDate: '11 Nov 2026',
              passengers: '1 Dewasa, 0 Bayi',
              createdAt: DateTime.now().subtract(const Duration(days: 2)),
            ),
            RecentSearchModel(
              id: 'srch-2',
              originCode: 'GMR',
              originName: 'Gambir (GMR)',
              destCode: 'SBI',
              destName: 'Surabaya Pasarturi (SBI)',
              travelDate: '24 Okt 2026',
              passengers: '1 Dewasa, 0 Bayi',
              createdAt: DateTime.now().subtract(const Duration(days: 5)),
            ),
          ]);
          await _saveRecentSearchesToPrefs();
        }
      }

      // 2. Bookings (ISOLASI PER USER)
      final bookingsKey = await _getBookingsKey();
      final rawBookings = prefs.getString(bookingsKey);
      _bookings.clear();
      if (rawBookings != null) {
        final List<dynamic> list = jsonDecode(rawBookings);
        for (final m in list) {
          _bookings.add(BookingModel.fromMap(m));
        }
      } else {
        // HANYA seed data demo jika user adalah Samuel (kocak@co.id). User baru start KOSONG (0 tiket)!
        if (isDemoSamuel) {
          _bookings.addAll([
            BookingModel(
              bookingId: 'TKA-9921XB',
              passengerName: 'Samuel',
              passengerEmail: 'kocak@co.id',
              passengerPhone: '+62 887-1287-18',
              passengerNik: '3514062607090001',
              trainName: 'KA Argo Bromo Anggrek',
              trainClass: 'Luxury • Kursi 5C • EKS-1',
              originCode: 'GMR',
              originName: 'Gambir',
              originCity: 'Jakarta Pusat',
              destCode: 'SBI',
              destName: 'Surabaya Pasarturi',
              destCity: 'Surabaya',
              travelDate: '25 Okt 2026',
              departureTime: '08:20 WIB',
              arrivalTime: '16:25 WIB',
              seatNumber: 'Gerbong EKS-2 / Kursi 5C',
              totalAmount: 640000,
              status: 'Sudah Dibayar',
              paymentMethod: 'BCA Virtual Account',
              vaNumber: 'VA-9001842910',
              createdAt: DateTime.now().subtract(const Duration(days: 1)),
            ),
            BookingModel(
              bookingId: 'TKA-8832KL',
              passengerName: 'Samuel',
              passengerEmail: 'kocak@co.id',
              passengerPhone: '+62 887-1287-18',
              passengerNik: '3514062607090001',
              trainName: 'KA Taksaka',
              trainClass: 'Eksekutif (H)',
              originCode: 'YK',
              originName: 'Yogyakarta',
              originCity: 'Yogyakarta',
              destCode: 'GMR',
              destName: 'Gambir',
              destCity: 'Jakarta Pusat',
              travelDate: '24 Okt 2026',
              departureTime: '08:45 WIB',
              arrivalTime: '15:15 WIB',
              seatNumber: 'Gerbong EKS-1 / Kursi 3A',
              totalAmount: 550000,
              status: 'Menunggu Pembayaran',
              paymentMethod: 'Mandiri Virtual Account',
              vaNumber: 'VA-8820194821',
              createdAt: DateTime.now().subtract(const Duration(minutes: 42)),
            ),
            BookingModel(
              bookingId: 'TKA-7104MN',
              passengerName: 'Samuel',
              passengerEmail: 'kocak@co.id',
              passengerPhone: '+62 887-1287-18',
              passengerNik: '3514062607090001',
              trainName: 'KA Turangga',
              trainClass: 'Eksekutif 2',
              originCode: 'BD',
              originName: 'Bandung',
              originCity: 'Bandung',
              destCode: 'SGU',
              destName: 'Surabaya Gubeng',
              destCity: 'Surabaya',
              travelDate: '10 Okt 2026',
              departureTime: '18:10 WIB',
              arrivalTime: '04:50 WIB',
              seatNumber: 'Gerbong EKS-2 / Kursi 8B',
              totalAmount: 490000,
              status: 'Perjalanan Selesai',
              paymentMethod: 'BCA Virtual Account',
              vaNumber: 'VA-7104928101',
              createdAt: DateTime.now().subtract(const Duration(days: 15)),
            ),
            BookingModel(
              bookingId: 'TKA-5021PQ',
              passengerName: 'Samuel',
              passengerEmail: 'kocak@co.id',
              passengerPhone: '+62 887-1287-18',
              passengerNik: '3514062607090001',
              trainName: 'KA Lodaya',
              trainClass: 'Ekonomi Premium',
              originCode: 'SLO',
              originName: 'Solo Balapan',
              originCity: 'Surakarta',
              destCode: 'BD',
              destName: 'Bandung',
              destCity: 'Bandung',
              travelDate: '05 Okt 2026',
              departureTime: '07:05 WIB',
              arrivalTime: '15:40 WIB',
              seatNumber: 'PRE-1 / 14D',
              totalAmount: 295000,
              status: 'Dibatalkan',
              paymentMethod: 'BCA Virtual Account',
              vaNumber: 'VA-5021948201',
              createdAt: DateTime.now().subtract(const Duration(days: 20)),
              cancelReason: 'Perubahan rencana perjalanan',
              refundAmount: 221250,
            ),
            BookingModel(
              bookingId: 'TKA-3319TR',
              passengerName: 'Samuel',
              passengerEmail: 'kocak@co.id',
              passengerPhone: '+62 887-1287-18',
              passengerNik: '3514062607090001',
              trainName: 'KA Fajar Utama Solo',
              trainClass: 'Ekonomi Premium',
              originCode: 'PSE',
              originName: 'Pasar Senen',
              originCity: 'Jakarta Pusat',
              destCode: 'SLO',
              destName: 'Solo Balapan',
              destCity: 'Surakarta',
              travelDate: '12 Okt 2026',
              departureTime: '05:55 WIB',
              arrivalTime: '13:45 WIB',
              seatNumber: 'PRE-2 / 10A',
              totalAmount: 240000,
              status: 'Kedaluwarsa',
              paymentMethod: 'BRI Virtual Account',
              vaNumber: 'VA-3319201940',
              createdAt: DateTime.now().subtract(const Duration(days: 25)),
            ),
          ]);
          await _saveBookingsToPrefs();
        }
      }
    } catch (e) {
      debugPrint('Error loading local user DB cache: $e');
    }
  }

  static Future<void> _saveRecentSearchesToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _getSearchesKey();
      final jsonStr = jsonEncode(
        _recentSearches.map((e) => e.toMap()).toList(),
      );
      await prefs.setString(key, jsonStr);
    } catch (e) {
      debugPrint('Error saving recent searches cache: $e');
    }
  }

  static Future<void> _saveBookingsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _getBookingsKey();
      final jsonStr = jsonEncode(_bookings.map((e) => e.toMap()).toList());
      await prefs.setString(key, jsonStr);
    } catch (e) {
      debugPrint('Error saving bookings cache: $e');
    }
  }

  // ===========================================================================
  // 4. API UNTUK UI (STATIONS, SEARCH, RECENT, BOOKING & REFUND)
  // ===========================================================================

  /// Cari Stasiun se-Indonesia dengan filter query dan region (TTL Cache 10 menit -> 0ms instan dari RAM)
  static Future<List<StationModel>> getStations({
    String? query,
    String? region,
    bool refreshRemote = true,
    bool forceRefresh = false,
  }) async {
    await initialize();

    final shouldFetch = refreshRemote &&
        SupabaseService.isInitialized &&
        (forceRefresh || !_isCacheFresh(_stationsFetchedAt, _stationsTtl));

    if (shouldFetch) {
      try {
        final rows = await SupabaseService.client
            .from('stations')
            .select('code, name, city, region')
            .order('name', ascending: true);
        for (final m in rows) {
          final model = StationModel.fromMap(Map<String, dynamic>.from(m));
          if (model.code.isEmpty) continue;
          final idx = _stations.indexWhere((s) => s.code == model.code);
          if (idx != -1) {
            _stations[idx] = model;
          } else {
            _stations.add(model);
          }
        }
        _stationsFetchedAt = DateTime.now();
      } catch (e) {
        debugPrint('Catatan GET stations PostgREST: $e');
      }
    }

    var list = _stations;
    if (region != null && region != 'Semua') {
      final safeRegion = SecurityGuard.sanitizeText(region, maxLength: 60).toLowerCase();
      list = list
          .where((s) => s.region.toLowerCase() == safeRegion)
          .toList();
    }

    if (query != null && query.trim().isNotEmpty) {
      final clean = SecurityGuard.sanitizeText(query, maxLength: 80).toLowerCase();
      list = list.where((s) {
        return s.code.toLowerCase().contains(clean) ||
            s.name.toLowerCase().contains(clean) ||
            s.city.toLowerCase().contains(clean);
      }).toList();
    }

    return list;
  }

  /// Ambil Riwayat Pencarian Terakhir dengan TTL Cache 60 detik + cache lokal
  static Future<List<RecentSearchModel>> getRecentSearches({
    bool refreshRemote = true,
    bool forceRefresh = false,
  }) async {
    await initialize();

    final shouldFetch = refreshRemote &&
        SupabaseService.isInitialized &&
        (forceRefresh ||
            !_isCacheFresh(_recentSearchesFetchedAt, _recentSearchesTtl));

    if (shouldFetch) {
      try {
        final client = SupabaseService.client;
        final uid = client.auth.currentUser?.id ?? await SessionService.getUserId();
        List<dynamic> rows;
        if (SecurityGuard.isValidUuid(uid)) {
          rows = await client
              .from('recent_searches')
              .select('*')
              .eq('user_id', uid!.trim())
              .order('created_at', ascending: false)
              .limit(10);
        } else {
          rows = await client
              .from('recent_searches')
              .select('*')
              .order('created_at', ascending: false)
              .limit(10);
        }
        if (rows.isNotEmpty) {
          for (final r in rows.reversed) {
            final model = RecentSearchModel.fromMap(Map<String, dynamic>.from(r));
            _recentSearches.removeWhere(
              (s) =>
                  s.id == model.id ||
                  (s.originCode == model.originCode &&
                      s.destCode == model.destCode),
            );
            _recentSearches.insert(0, model);
          }
          if (_recentSearches.length > 10) {
            _recentSearches.removeRange(10, _recentSearches.length);
          }
          await _saveRecentSearchesToPrefs();
        }
        _recentSearchesFetchedAt = DateTime.now();
      } catch (e) {
        debugPrint('Catatan GET recent_searches PostgREST: $e');
      }
    }

    return List.unmodifiable(_recentSearches);
  }

  /// Tambahkan Pencarian ke Riwayat & kirim POST ke PostgREST `recent_searches`
  static Future<void> addRecentSearch(RecentSearchModel search) async {
    await initialize();
    _recentSearchesFetchedAt = null;

    _recentSearches.removeWhere(
      (s) => s.originCode == search.originCode && s.destCode == search.destCode,
    );

    _recentSearches.insert(0, search);

    if (_recentSearches.length > 10) {
      _recentSearches.removeLast();
    }

    await _saveRecentSearchesToPrefs();

    if (SupabaseService.isInitialized) {
      try {
        final client = SupabaseService.client;
        final uid = client.auth.currentUser?.id ?? await SessionService.getUserId();
        final rawPayload = <String, dynamic>{
          ...search.toMap(),
          if (SecurityGuard.isValidUuid(uid)) 'user_id': uid!.trim(),
        };
        final safePayload = SecurityGuard.sanitizePayload(
          rawPayload,
          SecurityGuard.recentSearchesColumns,
        );
        await client.from('recent_searches').upsert(safePayload);
      } catch (e) {
        debugPrint('Catatan insert recent_searches Supabase: $e');
      }
    }
  }

  /// Hapus Satu Riwayat Pencarian (Lokal + DELETE PostgREST)
  static Future<void> deleteRecentSearch(String id) async {
    await initialize();
    _recentSearchesFetchedAt = null;
    final safeId = SecurityGuard.sanitizeIdentifier(id);
    _recentSearches.removeWhere((s) => s.id == safeId || s.id == id);
    await _saveRecentSearchesToPrefs();

    if (SupabaseService.isInitialized && safeId.isNotEmpty) {
      try {
        await SupabaseService.client
            .from('recent_searches')
            .delete()
            .eq('id', safeId);
      } catch (e) {
        debugPrint('Catatan delete item recent_searches Supabase: $e');
      }
    }
  }

  /// Hapus Seluruh Riwayat Pencarian
  static Future<void> clearRecentSearches() async {
    await initialize();
    _recentSearchesFetchedAt = null;
    _recentSearches.clear();
    await _saveRecentSearchesToPrefs();

    try {
      final client = SupabaseService.client;
      final user = client.auth.currentUser;
      if (user != null && SecurityGuard.isValidUuid(user.id)) {
        await client.from('recent_searches').delete().eq('user_id', user.id);
      }
    } catch (e) {
      debugPrint('Catatan clear recent_searches Supabase: $e');
    }
  }

  /// Cari Jadwal Kereta Berdasarkan Stasiun Asal & Tujuan (TTL Cache 5 menit -> bebas double-query)
  static Future<List<TrainScheduleModel>> searchTrains({
    required String originCode,
    required String destCode,
    String? trainClass,
    bool forceRefresh = false,
  }) async {
    await initialize();

    final safeOrigin = SecurityGuard.sanitizeStationCode(originCode);
    final safeDest = SecurityGuard.sanitizeStationCode(destCode);

    final shouldFetch = SupabaseService.isInitialized &&
        safeOrigin.isNotEmpty &&
        safeDest.isNotEmpty &&
        (forceRefresh || !_isCacheFresh(_schedulesFetchedAt, _schedulesTtl));

    if (shouldFetch) {
      try {
        final client = SupabaseService.client;
        // Ambil 1x seluruh jadwal aktif lalu cache di RAM 5 menit (hilangkan double query!)
        final sourceRows = await client
            .from('train_schedules')
            .select('*')
            .limit(100);

        for (final m in sourceRows) {
          final model = TrainScheduleModel.fromMap(Map<String, dynamic>.from(m));
          if (model.id.isEmpty) continue;
          final idx = _trainSchedules.indexWhere((s) => s.id == model.id);
          if (idx != -1) {
            _trainSchedules[idx] = model;
          } else {
            _trainSchedules.insert(0, model);
          }
        }
        _schedulesFetchedAt = DateTime.now();
      } catch (e) {
        debugPrint('Catatan GET train_schedules PostgREST: $e');
      }
    }

    // Cari jadwal langsung
    var matches = _trainSchedules.where((t) {
      return t.originCode.toUpperCase() == safeOrigin &&
          t.destCode.toUpperCase() == safeDest;
    }).toList();

    // Jika tidak ada jadwal statis persis rute tersebut, generate jadwal dinamis realistis
    if (matches.isEmpty) {
      final originStation = _stations.firstWhere(
        (s) => s.code.toUpperCase() == originCode.toUpperCase(),
        orElse: () => StationModel(
          code: originCode,
          name: originCode,
          city: originCode,
          region: 'Jawa',
        ),
      );
      final destStation = _stations.firstWhere(
        (s) => s.code.toUpperCase() == destCode.toUpperCase(),
        orElse: () => StationModel(
          code: destCode,
          name: destCode,
          city: destCode,
          region: 'Jawa',
        ),
      );

      matches = [
        TrainScheduleModel(
          id: 'SCH-DYN-1',
          trainNumber: 'KA Express 1',
          name: 'KA ${originStation.city} Express',
          originCode: originStation.code,
          originName: originStation.name,
          originCity: originStation.city,
          destCode: destStation.code,
          destName: destStation.name,
          destCity: destStation.city,
          departureTime: '08:00 WIB',
          arrivalTime: '14:30 WIB',
          duration: '6j 30m',
          baseFare: 320000,
          availableClasses: ['Eksekutif', 'Ekonomi'],
          availableSeats: 48,
        ),
        TrainScheduleModel(
          id: 'SCH-DYN-2',
          trainNumber: 'KA Express 2',
          name: 'KA Nusantara Prioritas',
          originCode: originStation.code,
          originName: originStation.name,
          originCity: originStation.city,
          destCode: destStation.code,
          destName: destStation.name,
          destCity: destStation.city,
          departureTime: '15:15 WIB',
          arrivalTime: '21:45 WIB',
          duration: '6j 30m',
          baseFare: 480000,
          availableClasses: ['Eksekutif', 'Luxury'],
          availableSeats: 26,
        ),
      ];
    }

    if (trainClass != null && trainClass != 'Semua') {
      matches = matches
          .where((t) => t.availableClasses.contains(trainClass))
          .toList();
    }

    return matches;
  }

  /// Cek apakah suatu tiket sudah lewat jadwal kedatangan (otomatis selesai)
  static bool isTicketCompletedBySchedule(BookingModel b) {
    try {
      final now = DateTime.now();
      DateTime? tripDate;

      if (b.travelDate.contains('-')) {
        tripDate = DateTime.tryParse(b.travelDate);
      }
      if (tripDate == null) {
        final yearMatch = RegExp(r'\b(202\d)\b').firstMatch(b.travelDate);
        final dayMatch = RegExp(r'\b(\d{1,2})\b').firstMatch(b.travelDate);
        if (yearMatch != null && dayMatch != null) {
          final year = int.parse(yearMatch.group(1)!);
          final day = int.parse(dayMatch.group(1)!);
          int month = 1;
          final lower = b.travelDate.toLowerCase();
          if (lower.contains('jan')) {
            month = 1;
          } else if (lower.contains('feb')) {
            month = 2;
          } else if (lower.contains('mar')) {
            month = 3;
          } else if (lower.contains('apr')) {
            month = 4;
          } else if (lower.contains('mei') || lower.contains('may')) {
            month = 5;
          } else if (lower.contains('jun')) {
            month = 6;
          } else if (lower.contains('jul')) {
            month = 7;
          } else if (lower.contains('agu') || lower.contains('aug')) {
            month = 8;
          } else if (lower.contains('sep')) {
            month = 9;
          } else if (lower.contains('okt') || lower.contains('oct')) {
            month = 10;
          } else if (lower.contains('nov')) {
            month = 11;
          } else if (lower.contains('des') || lower.contains('dec')) {
            month = 12;
          }

          tripDate = DateTime(year, month, day);
        }
      }

      if (tripDate != null) {
        int hour = 23;
        int min = 59;
        final cleanArr = b.arrivalTime.replaceAll('.', ':');
        final parts = cleanArr.split(':');
        if (parts.length >= 2) {
          hour = int.tryParse(parts[0].trim()) ?? 23;
          min = int.tryParse(parts[1].trim()) ?? 59;
        }

        final arrivalDateTime =
            DateTime(tripDate.year, tripDate.month, tripDate.day, hour, min);
        return now.isAfter(arrivalDateTime.add(const Duration(minutes: 15)));
      }
    } catch (_) {}
    return false;
  }

  /// Ambil Daftar Pesanan (Bookings) dengan Smart TTL Cache (25s) + In-Flight Deduplication
  static Future<List<BookingModel>> getBookings({
    String? statusFilter,
    bool refreshRemote = true,
    bool forceRefresh = false,
  }) async {
    await initialize();

    final sessionData = await Future.wait([
      SessionService.getUserEmail(),
      SessionService.getUserName(),
    ]);
    final rawEmail = (sessionData[0] ?? '').toLowerCase().trim();
    final currentEmail = SecurityGuard.sanitizeEmail(rawEmail);
    final currentName = SecurityGuard.sanitizeText(
      sessionData[1] ?? '',
      maxLength: 100,
    ).toLowerCase();
    final isDemoSamuel =
        currentEmail == 'kocak@co.id' || currentName == 'samuel';

    final shouldSyncRemote = refreshRemote &&
        SupabaseService.isInitialized &&
        currentEmail.isNotEmpty &&
        (forceRefresh || !_isCacheFresh(_bookingsFetchedAt, _bookingsTtl));

    // Request Coalescing: jika beberapa tab memanggil bersamaan, cukup 1 request ke Supabase
    if (shouldSyncRemote) {
      _inFlightBookingsSync ??= () async {
        try {
          final remoteRows = await SupabaseService.client
              .from('bookings')
              .select('*')
              .eq('passenger_email', currentEmail)
              .order('created_at', ascending: false);

          if (remoteRows.isNotEmpty) {
            final Map<String, BookingModel> localByCode = {
              for (final b in _bookings) b.bookingId: b,
            };
            for (final m in remoteRows) {
              final remoteModel =
                  BookingModel.fromMap(Map<String, dynamic>.from(m));
              final prev = localByCode[remoteModel.bookingId];
              final merged = remoteModel.copyWith(
                passengers: remoteModel.passengers ?? prev?.passengers,
                qrCodeUrl: remoteModel.qrCodeUrl ?? prev?.qrCodeUrl,
              );
              final idx = _bookings.indexWhere(
                (x) => x.bookingId == merged.bookingId,
              );
              if (idx != -1) {
                _bookings[idx] = merged;
              } else {
                _bookings.add(merged);
              }
            }
            _bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            await _saveBookingsToPrefs();
          }
          _bookingsFetchedAt = DateTime.now();
        } catch (e) {
          debugPrint('Catatan GET bookings PostgREST: $e');
        } finally {
          _inFlightBookingsSync = null;
        }
      }();
      await _inFlightBookingsSync;
    }

    // Auto-complete: update tiket yang jadwal kedatangannya telah terlewati
    bool hasAutoUpdated = false;
    for (int i = 0; i < _bookings.length; i++) {
      if (_bookings[i].status == 'Sudah Dibayar' &&
          isTicketCompletedBySchedule(_bookings[i])) {
        _bookings[i] = _bookings[i].copyWith(status: 'Perjalanan Selesai');
        hasAutoUpdated = true;
      }
    }
    if (hasAutoUpdated) {
      _saveBookingsToPrefs();
    }

    // Filter ketat: HANYA tiket milik user yang sedang aktif login!
    var userBookings = _bookings.where((b) {
      final pEmail = b.passengerEmail.toLowerCase().trim();
      final pName = b.passengerName.toLowerCase().trim();
      if (isDemoSamuel) {
        return pEmail == 'kocak@co.id' || pName == 'samuel';
      }
      return (currentEmail.isNotEmpty && pEmail == currentEmail) ||
          (currentName.isNotEmpty && pName == currentName);
    }).toList();

    if (statusFilter != null && statusFilter != 'Semua') {
      return userBookings.where((b) {
        if (statusFilter == 'Menunggu Bayar') {
          return b.status == 'Menunggu Pembayaran';
        }
        if (statusFilter == 'Sudah Dibayar') return b.status == 'Sudah Dibayar';
        if (statusFilter == 'Dibatalkan') return b.status == 'Dibatalkan';
        if (statusFilter == 'Selesai') return b.status == 'Perjalanan Selesai';
        return b.status.toLowerCase() == statusFilter.toLowerCase();
      }).toList();
    }

    return List.unmodifiable(userBookings);
  }

  /// Ambil Seluruh Jadwal Kereta dari PostgREST `train_schedules` (dengan TTL Cache 5 menit)
  static Future<List<TrainScheduleModel>> getAllTrainSchedules({
    bool refreshRemote = true,
    bool forceRefresh = false,
  }) async {
    await initialize();
    final shouldFetch = refreshRemote &&
        SupabaseService.isInitialized &&
        (forceRefresh || !_isCacheFresh(_schedulesFetchedAt, _schedulesTtl));

    if (shouldFetch) {
      try {
        final rows = await SupabaseService.client
            .from('train_schedules')
            .select('*')
            .order('created_at', ascending: false)
            .limit(100);
        for (final m in rows) {
          final model = TrainScheduleModel.fromMap(Map<String, dynamic>.from(m));
          if (model.id.isEmpty) continue;
          final idx = _trainSchedules.indexWhere((s) => s.id == model.id);
          if (idx != -1) {
            _trainSchedules[idx] = model;
          } else {
            _trainSchedules.insert(0, model);
          }
        }
        _schedulesFetchedAt = DateTime.now();
      } catch (e) {
        debugPrint('Catatan GET all train_schedules PostgREST: $e');
      }
    }
    return List.unmodifiable(_trainSchedules);
  }

  /// Ambil Riwayat Pembayaran & Top Up langsung melalui GET PostgREST `payments` (HTTP 200 OK)
  static Future<List<Map<String, dynamic>>> getPaymentsFromSupabase() async {
    if (!SupabaseService.isInitialized) return const [];
    try {
      final client = SupabaseService.client;
      final uid = client.auth.currentUser?.id ?? await SessionService.getUserId();
      List<dynamic> rows;
      if (SecurityGuard.isValidUuid(uid)) {
        rows = await client
            .from('payments')
            .select('*')
            .eq('user_id', uid!.trim())
            .order('created_at', ascending: false)
            .limit(50);
      } else {
        rows = await client
            .from('payments')
            .select('*')
            .order('created_at', ascending: false)
            .limit(50);
      }
      return rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('Catatan GET payments PostgREST: $e');
      return const [];
    }
  }

  /// Ambil Riwayat Pembatalan Tiket langsung melalui GET PostgREST `cancellations` (HTTP 200 OK)
  static Future<List<Map<String, dynamic>>> getCancellationsFromSupabase() async {
    if (!SupabaseService.isInitialized) return const [];
    try {
      final client = SupabaseService.client;
      final uid = client.auth.currentUser?.id ?? await SessionService.getUserId();
      List<dynamic> rows;
      if (SecurityGuard.isValidUuid(uid)) {
        rows = await client
            .from('cancellations')
            .select('*')
            .eq('user_id', uid!.trim())
            .limit(50);
      } else {
        rows = await client.from('cancellations').select('*').limit(50);
      }
      return rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('Catatan GET cancellations PostgREST: $e');
      return const [];
    }
  }

  /// Ambil cache tiket dalam memori secara sinkron untuk pencarian instan
  static List<BookingModel> getCachedBookings() {
    return List.unmodifiable(_bookings);
  }

  /// Buat Pemesanan Lengkap untuk Banyak Penumpang (Masuk ke Database Supabase & Lokal)
  static Future<BookingModel> createBookingOrder({
    required TrainScheduleModel schedule,
    required String selectedClass,
    required String bookerName,
    required String bookerEmail,
    required String bookerPhone,
    required List<Map<String, String>> manifestPassengers,
    required String travelDate,
    String? status,
    String? paymentMethod,
    String? vaNumber,
    int? totalFare,
  }) async {
    await initialize();

    final baseBookingCode =
        'TKA-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final count = manifestPassengers.isNotEmpty ? manifestPassengers.length : 1;
    final singleFare = totalFare != null
        ? (totalFare ~/ count)
        : (selectedClass == 'Luxury'
              ? (schedule.baseFare * 1.5).round()
              : selectedClass == 'Ekonomi'
              ? (schedule.baseFare * 0.7).round()
              : schedule.baseFare);
    final finalTotalAmount = totalFare ?? (singleFare * count);
    final finalStatus = status ?? 'Sudah Dibayar';
    final finalPaymentMethod = paymentMethod ?? 'QRIS';
    final finalVaNumber =
        vaNumber ??
        'NMID-${DateTime.now().millisecondsSinceEpoch.toString().substring(3)}';

    // Rangkai data kursi dan nama manifest
    final allSeats = manifestPassengers
        .map((p) => p['seat'] ?? '1A')
        .join(', ');
    final primaryName = manifestPassengers.isNotEmpty
        ? (manifestPassengers.first['name'] ?? bookerName)
        : bookerName;
    final primaryNik = manifestPassengers.isNotEmpty
        ? (manifestPassengers.first['id'] ?? '3514062607090001')
        : '3514062607090001';

    // 1. Buat dan unggah QR code boarding pass utama ke Supabase Storage (tickets-qr)
    String? mainQrUrl;
    try {
      final qrBytes = await SupabaseStorageService.generateTicketQrPng(
        bookingId: baseBookingCode,
        pnr: baseBookingCode,
        trainName: schedule.name,
        seatNumber: allSeats,
      );
      mainQrUrl = await SupabaseStorageService.uploadTicketQr(
        bookingId: baseBookingCode,
        pngBytes: qrBytes,
      );
    } catch (qrErr) {
      debugPrint('Catatan QR boarding generation/upload: $qrErr');
    }

    // Master order booking untuk lokal
    final mainBooking = BookingModel(
      bookingId: baseBookingCode,
      passengerName: primaryName,
      passengerEmail: bookerEmail,
      passengerPhone: bookerPhone,
      passengerNik: primaryNik,
      trainName: schedule.name,
      trainClass: '$selectedClass • $allSeats',
      originCode: schedule.originCode,
      originName: schedule.originName,
      originCity: schedule.originCity,
      destCode: schedule.destCode,
      destName: schedule.destName,
      destCity: schedule.destCity,
      travelDate: travelDate,
      departureTime: schedule.departureTime,
      arrivalTime: schedule.arrivalTime,
      seatNumber: allSeats,
      totalAmount: finalTotalAmount,
      status: finalStatus,
      paymentMethod: finalPaymentMethod,
      vaNumber: finalVaNumber,
      createdAt: DateTime.now(),
      passengers: List.from(manifestPassengers),
      qrCodeUrl: mainQrUrl,
    );

    _bookings.insert(0, mainBooking);
    invalidateBookingsCache();
    await _saveBookingsToPrefs();

    // Masukkan SEMUA penumpang ke Supabase bookings table (100% sesuai skema resmi tanpa kolom ilegal)
    try {
      final client = SupabaseService.client;
      var currentUser = client.auth.currentUser;
      currentUser ??= await AuthService.ensureSupabaseAuthSession();
      final savedUserId = currentUser?.id ?? await SessionService.getUserId();

      for (int i = 0; i < manifestPassengers.length; i++) {
        final p = manifestPassengers[i];
        final pName = p['name'] ?? bookerName;
        final pNik = p['id'] ?? primaryNik;
        final pSeat = p['seat'] ?? '1A';
        final subBookingId = i == 0
            ? baseBookingCode
            : '$baseBookingCode-${i + 1}';

        final rawBookingMap = <String, dynamic>{
          'booking_id': subBookingId,
          if (SecurityGuard.isValidUuid(savedUserId)) 'user_id': savedUserId!,
          'passenger_name': pName,
          'passenger_email': bookerEmail,
          'passenger_phone': bookerPhone,
          'passenger_nik': pNik,
          'train_number': schedule.trainNumber,
          'train_name': schedule.name,
          'train_class': selectedClass,
          'wagon_class': selectedClass,
          'route': '${schedule.originCode} -> ${schedule.destCode}',
          'origin_code': schedule.originCode,
          'origin_name': schedule.originName,
          'origin_city': schedule.originCity,
          'dest_code': schedule.destCode,
          'dest_name': schedule.destName,
          'dest_city': schedule.destCity,
          'travel_date': travelDate,
          'departure_time': schedule.departureTime,
          'arrival_time': schedule.arrivalTime,
          'seat_number': pSeat,
          'amount': SecurityGuard.sanitizeAmount(singleFare),
          'total_amount': SecurityGuard.sanitizeAmount(singleFare),
          'status': finalStatus,
          'payment_method': finalPaymentMethod,
          'va_number': finalVaNumber,
          'created_at': DateTime.now().toIso8601String(),
        };

        final safeBookingMap = SecurityGuard.sanitizePayload(
          rawBookingMap,
          SecurityGuard.bookingsColumns,
        );
        await client.from('bookings').upsert(safeBookingMap);

        debugPrint(
          '✅ [Supabase Insert Success] Penumpang ${i + 1} ($pName - $pSeat) berhasil masuk Supabase: $subBookingId',
        );

        if (finalStatus == 'Sudah Dibayar') {
          await recordPaymentInSupabase(
            bookingId: subBookingId,
            paymentMethod: finalPaymentMethod,
            referenceNumber: '$finalVaNumber-${i + 1}',
            amount: singleFare,
            status: 'Sudah Dibayar',
          );
        }
      }
    } catch (e, stack) {
      debugPrint(
        '❌ [Supabase Insert Error] Gagal simpan penumpang ke Supabase: $e',
      );
      debugPrint('Detail error: $stack');
    }

    _dispatchBrevoTicketAsync(mainBooking);
    return mainBooking;
  }

  /// Buat Pemesanan Tiket Baru (Masuk ke Database & Supabase)
  static Future<BookingModel> createBooking({
    required TrainScheduleModel schedule,
    required String selectedClass,
    required String passengerName,
    required String passengerEmail,
    required String passengerPhone,
    required String passengerNik,
    required String travelDate,
    String? status,
    String? paymentMethod,
    String? vaNumber,
    int? customFare,
    String? customSeat,
  }) async {
    await initialize();

    final bookingCode =
        'TKA-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final seat =
        customSeat ??
        '${selectedClass.substring(0, 3).toUpperCase()}-1 / ${(1 + (DateTime.now().second % 15))}A';
    final fare =
        customFare ??
        (selectedClass == 'Luxury'
            ? (schedule.baseFare * 1.5).round()
            : selectedClass == 'Ekonomi'
            ? (schedule.baseFare * 0.7).round()
            : schedule.baseFare);

    final finalStatus = status ?? 'Menunggu Pembayaran';
    final finalPaymentMethod = paymentMethod ?? 'QRIS';
    final finalVaNumber =
        vaNumber ??
        'NMID-${DateTime.now().millisecondsSinceEpoch.toString().substring(3)}';

    // Buat dan unggah QR code ke Supabase Storage (tickets-qr)
    String? qrUrl;
    try {
      final qrBytes = await SupabaseStorageService.generateTicketQrPng(
        bookingId: bookingCode,
        pnr: bookingCode,
        trainName: schedule.name,
        seatNumber: seat,
      );
      qrUrl = await SupabaseStorageService.uploadTicketQr(
        bookingId: bookingCode,
        pngBytes: qrBytes,
      );
    } catch (_) {}

    final newBooking = BookingModel(
      bookingId: bookingCode,
      passengerName: passengerName,
      passengerEmail: passengerEmail,
      passengerPhone: passengerPhone,
      passengerNik: passengerNik,
      trainName: schedule.name,
      trainClass: '$selectedClass • Kursi $seat',
      originCode: schedule.originCode,
      originName: schedule.originName,
      originCity: schedule.originCity,
      destCode: schedule.destCode,
      destName: schedule.destName,
      destCity: schedule.destCity,
      travelDate: travelDate,
      departureTime: schedule.departureTime,
      arrivalTime: schedule.arrivalTime,
      seatNumber: seat,
      totalAmount: fare,
      status: finalStatus,
      paymentMethod: finalPaymentMethod,
      vaNumber: finalVaNumber,
      createdAt: DateTime.now(),
      qrCodeUrl: qrUrl,
    );

    _bookings.insert(0, newBooking);
    await _saveBookingsToPrefs();

    // Simpan ke Supabase dengan kolom tervalidasi SecurityGuard (langsung 201 Created tanpa 400)
    try {
      final client = SupabaseService.client;
      var currentUser = client.auth.currentUser;
      currentUser ??= await AuthService.ensureSupabaseAuthSession();
      final savedUserId = currentUser?.id ?? await SessionService.getUserId();
      final bookingMap = newBooking.toSupabaseMap(
        userId: savedUserId,
        trainNumber: schedule.trainNumber,
        wagonClass: selectedClass,
      );

      final res = await client.from('bookings').insert(bookingMap).select();
      debugPrint(
        '✅ [Supabase Insert Success] Tiket $bookingCode berhasil masuk ke tabel bookings Supabase: $res',
      );

      if (finalStatus == 'Sudah Dibayar') {
        await recordPaymentInSupabase(
          bookingId: bookingCode,
          paymentMethod: finalPaymentMethod,
          referenceNumber: finalVaNumber,
          amount: fare,
          status: 'Sudah Dibayar',
        );
      }
    } catch (e, stack) {
      debugPrint(
        '❌ [Supabase Insert Error] Gagal menyimpan booking $bookingCode ke Supabase: $e',
      );
      debugPrint('Detail error: $stack');
    }

    _dispatchBrevoTicketAsync(newBooking);
    return newBooking;
  }

  /// Proses Pembayaran Tiket (Dari Menunggu Pembayaran -> Sudah Dibayar)
  static Future<BookingModel?> payBooking({
    required String bookingId,
    required String paymentMethod,
    required String vaNumber,
  }) async {
    await initialize();
    final index = _bookings.indexWhere((b) => b.bookingId == bookingId);
    if (index == -1) return null;

    final old = _bookings[index];
    final updated = BookingModel(
      bookingId: old.bookingId,
      passengerName: old.passengerName,
      passengerEmail: old.passengerEmail,
      passengerPhone: old.passengerPhone,
      passengerNik: old.passengerNik,
      trainName: old.trainName,
      trainClass: old.trainClass,
      originCode: old.originCode,
      originName: old.originName,
      originCity: old.originCity,
      destCode: old.destCode,
      destName: old.destName,
      destCity: old.destCity,
      travelDate: old.travelDate,
      departureTime: old.departureTime,
      arrivalTime: old.arrivalTime,
      seatNumber: old.seatNumber,
      totalAmount: old.totalAmount,
      status: 'Sudah Dibayar',
      paymentMethod: paymentMethod,
      vaNumber: vaNumber,
      createdAt: old.createdAt,
      cancelReason: old.cancelReason,
      refundAmount: old.refundAmount,
    );

    _bookings[index] = updated;
    await _saveBookingsToPrefs();

    // Sync ke Supabase
    try {
      final client = SupabaseService.client;
      var currentUser = client.auth.currentUser;
      currentUser ??= await AuthService.ensureSupabaseAuthSession();
      final savedUserId = currentUser?.id ?? await SessionService.getUserId();

      final updateData = <String, dynamic>{
        'status': 'Sudah Dibayar',
        'payment_method': paymentMethod,
        'va_number': vaNumber,
      };
      if (_isValidUuid(savedUserId)) {
        updateData['user_id'] = savedUserId!;
      }

      await client
          .from('bookings')
          .update(updateData)
          .eq('booking_id', bookingId);
      debugPrint(
        '✅ [Supabase Update Success] Status tiket $bookingId diperbarui jadi Sudah Dibayar',
      );

      await recordPaymentInSupabase(
        bookingId: bookingId,
        paymentMethod: paymentMethod,
        referenceNumber: vaNumber,
        amount: updated.totalAmount,
        status: 'Sudah Dibayar',
      );
    } catch (e) {
      debugPrint(
        '❌ [Supabase Update Error] Gagal update booking $bookingId: $e',
      );
    }

    return updated;
  }

  /// Catat data transaksi pembayaran ke tabel payments Supabase
  static Future<void> recordPaymentInSupabase({
    required String bookingId,
    required String paymentMethod,
    required String referenceNumber,
    required int amount,
    required String status,
  }) async {
    try {
      final client = SupabaseService.client;
      var currentUser = client.auth.currentUser;
      currentUser ??= await AuthService.ensureSupabaseAuthSession();
      final savedUserId = currentUser?.id ?? await SessionService.getUserId();

      String channel = 'Virtual Account';
      if (paymentMethod.toLowerCase().contains('qris')) {
        channel = 'QRIS';
      } else if (paymentMethod.toLowerCase().contains('tka') ||
          paymentMethod.toLowerCase().contains('saldo')) {
        channel = 'Saldo Akun';
      } else if (paymentMethod.toLowerCase().contains('gopay') ||
          paymentMethod.toLowerCase().contains('ovo') ||
          paymentMethod.toLowerCase().contains('dana') ||
          paymentMethod.toLowerCase().contains('shopee')) {
        channel = 'E-Wallet';
      }

      final rawPayMap = <String, dynamic>{
        'payment_id':
            'PAY-${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}',
        'booking_id': SecurityGuard.sanitizeIdentifier(bookingId),
        'payment_method': paymentMethod,
        'payment_channel': channel,
        'reference_number': SecurityGuard.sanitizeIdentifier(referenceNumber),
        'amount': SecurityGuard.sanitizeAmount(amount),
        'status': status,
        'paid_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        if (SecurityGuard.isValidUuid(savedUserId)) 'user_id': savedUserId!,
      };
      final payMap = SecurityGuard.sanitizePayload(
        rawPayMap,
        SecurityGuard.paymentsColumns,
      );

      await client.from('payments').insert(payMap);
      debugPrint(
        '✅ [Supabase Payment Success] Transaksi pembayaran $paymentMethod ($referenceNumber) masuk ke tabel payments Supabase',
      );
    } catch (e) {
      debugPrint(
        'ℹ️ [Supabase Payment Info] Info simpan payment ke Supabase: $e',
      );
    }
  }

  /// Proses Pembatalan Tiket & Pengembalian Dana (Refund)
  static Future<bool> cancelBookingWithRefund({
    required String bookingCode,
    required String reason,
  }) async {
    await initialize();

    final index = _bookings.indexWhere((b) => b.bookingId == bookingCode);
    if (index != -1) {
      final b = _bookings[index];
      final fee = (b.totalAmount * 0.25).round();
      final refundAmount = b.totalAmount - fee;

      _bookings[index] = b.copyWith(
        status: 'Dibatalkan',
        cancelReason: reason,
        refundAmount: refundAmount,
      );

      invalidateBookingsCache();
      await _saveBookingsToPrefs();

      // Sinkronkan ke Supabase (Update jika sudah ada, atau Upsert jika tiket belum tercatat di Supabase)
      try {
        final client = SupabaseService.client;
        var currentUser = client.auth.currentUser;
        currentUser ??= await AuthService.ensureSupabaseAuthSession();
        final savedUserId = currentUser?.id ?? await SessionService.getUserId();

        final updateData = <String, dynamic>{
          'status': 'Dibatalkan',
          'cancel_reason': reason,
          'refund_amount': refundAmount,
        };
        if (_isValidUuid(savedUserId)) {
          updateData['user_id'] = savedUserId!;
        }

        final res = await client
            .from('bookings')
            .update(updateData)
            .eq('booking_id', bookingCode)
            .select();

        if (res.isNotEmpty) {
          debugPrint(
            '✅ [Supabase Update Success] Status pembatalan tiket $bookingCode berhasil di-update di Supabase: $res',
          );
        } else {
          // Jika tiket sebelumnya baru di memori lokal, masukkan record bersih sesuai skema bookings
          final upsertMap = _bookings[index].toSupabaseMap(userId: savedUserId);
          final upsertRes = await client
              .from('bookings')
              .upsert(upsertMap)
              .select();
          debugPrint(
            '✅ [Supabase Upsert Success] Tiket $bookingCode berhasil disimpan ke Supabase dengan status Dibatalkan: $upsertRes',
          );
        }

        // 2. Masukkan riwayat pembatalan ke tabel cancellations Supabase dengan fallback multi-tier
        await _recordCancellationInSupabase(
          bookingCode: bookingCode,
          reason: reason,
          refundAmount: refundAmount,
        );
      } catch (e, stack) {
        debugPrint(
          '❌ [Supabase Update Error] Gagal membatalkan tiket $bookingCode di Supabase: $e',
        );
        debugPrint('Detail error: $stack');
      }

      _dispatchBrevoRefundAsync(b, reason, refundAmount);
      return true;
    }

    return false;
  }

/// Menandai tiket telah menyelesaikan perjalanan (Perjalanan Selesai)
  static Future<bool> completeBooking({required String bookingCode}) async {
    await initialize();

    final index = _bookings.indexWhere((b) => b.bookingId == bookingCode);
    if (index != -1) {
      final b = _bookings[index];
      _bookings[index] = b.copyWith(status: 'Perjalanan Selesai');
      invalidateBookingsCache();
      await _saveBookingsToPrefs();

      // Sinkronkan ke Supabase
      try {
        final client = SupabaseService.client;
        final res = await client
            .from('bookings')
            .update({'status': 'Perjalanan Selesai'})
            .eq('booking_id', bookingCode)
            .select();
        debugPrint(
          '✅ [Supabase] Status tiket $bookingCode diubah menjadi Perjalanan Selesai: $res',
        );
      } catch (e) {
        debugPrint('Catatan update status selesai ke Supabase: $e');
      }
      return true;
    }
    return false;
  }

  // ================= BREVO ASYNC DISPATCH HELPERS =================
  static void _dispatchBrevoTicketAsync(BookingModel booking) {
    if (booking.passengerEmail.isEmpty ||
        !booking.passengerEmail.contains('@')) {
      return;
    }
    Future.microtask(() async {
      try {
        await BrevoNotificationService.sendTicketConfirmationEmail(
          recipientEmail: booking.passengerEmail,
          bookingCode: booking.bookingId,
          trainName: booking.trainName,
          trainClass: booking.trainClass,
          originStation: '${booking.originName} (${booking.originCode})',
          destStation: '${booking.destName} (${booking.destCode})',
          travelDate: booking.travelDate,
          departureTime: booking.departureTime,
          arrivalTime: booking.arrivalTime,
          passengerName: booking.passengerName,
          seatNumber: booking.seatNumber,
          totalAmount: booking.totalAmount,
          paymentMethod: booking.paymentMethod,
        );
      } catch (e) {
        debugPrint('Catatan dispatch Brevo ticket async: $e');
      }
    });
  }

  static void _dispatchBrevoRefundAsync(
    BookingModel booking,
    String reason,
    int refundAmount,
  ) {
    if (booking.passengerEmail.isEmpty ||
        !booking.passengerEmail.contains('@')) {
      return;
    }
    Future.microtask(() async {
      try {
        await BrevoNotificationService.sendRefundConfirmationEmail(
          recipientEmail: booking.passengerEmail,
          bookingCode: booking.bookingId,
          trainName: booking.trainName,
          refundAmount: refundAmount,
          reason: reason,
          passengerName: booking.passengerName,
        );
      } catch (e) {
        debugPrint('Catatan dispatch Brevo refund async: $e');
      }
    });
  }

  /// Mencatat riwayat pembatalan ke tabel `public.cancellations` secara presisi dalam 1x request
  /// (Bebas error 400 PGRST204, bebas 22P02 UUID syntax, dan bebas duplikasi).
  static Future<void> _recordCancellationInSupabase({
    required String bookingCode,
    required String reason,
    required int refundAmount,
  }) async {
    try {
      final client = SupabaseService.client;
      var currentUser = client.auth.currentUser;
      currentUser ??= await AuthService.ensureSupabaseAuthSession();
      final savedUserId = currentUser?.id ?? await SessionService.getUserId();
      if (!SecurityGuard.isValidUuid(savedUserId)) {
        debugPrint(
          'ℹ️ Lewati insert cancellations remote karena sesi user belum memiliki UUID Auth.',
        );
        return;
      }

      final safeBookingCode = SecurityGuard.sanitizeIdentifier(bookingCode);
      final uuidCode = _codeToUuid(safeBookingCode);
      final safeReason = SecurityGuard.sanitizeText(
        '$reason [Kode: $safeBookingCode]',
        maxLength: 240,
      );

      // Cek terlebih dahulu via GET PostgREST agar tidak terjadi duplikasi
      final existing = await client
          .from('cancellations')
          .select('id')
          .eq('booking_id', uuidCode)
          .eq('user_id', savedUserId!.trim())
          .limit(1);
      if (existing.isNotEmpty) {
        return;
      }

      final payload = SecurityGuard.sanitizePayload(
        <String, dynamic>{
          'booking_id': uuidCode,
          'user_id': savedUserId.trim(),
          'reason': safeReason,
          'refund_amount': SecurityGuard.sanitizeAmount(refundAmount),
        },
        SecurityGuard.cancellationsColumns,
      );

      await client.from('cancellations').insert(payload);
      debugPrint(
        '✅ [Supabase Cancellations 201] Pembatalan $safeBookingCode berhasil tercatat.',
      );
    } catch (outerErr) {
      debugPrint('ℹ️ [Supabase Cancellations Notice]: $outerErr');
    }
  }

  // ===========================================================================
  // 5. SINKRONISASI SUPABASE BACKGROUND (RINGAN & BEBAS ERROR 400)
  // ===========================================================================
  static void _syncWithSupabaseBackground() async {
    if (!SupabaseService.isInitialized) return;
    try {
      final client = SupabaseService.client;

      // 1. Ambil stations dari Supabase via GET PostgREST (HTTP 200 OK)
      final remoteStations = await client
          .from('stations')
          .select('code, name, city, region');
      if (remoteStations.isNotEmpty) {
        for (final m in remoteStations) {
          final model = StationModel.fromMap(Map<String, dynamic>.from(m));
          final idx = _stations.indexWhere((s) => s.code == model.code);
          if (idx != -1) {
            _stations[idx] = model;
          } else {
            _stations.add(model);
          }
        }
      }

      // 2. Ambil train_schedules dari Supabase via GET PostgREST (HTTP 200 OK)
      final remoteSchedules = await client.from('train_schedules').select('*');
      if (remoteSchedules.isNotEmpty) {
        for (final m in remoteSchedules) {
          final model = TrainScheduleModel.fromMap(Map<String, dynamic>.from(m));
          final idx = _trainSchedules.indexWhere((s) => s.id == model.id);
          if (idx != -1) {
            _trainSchedules[idx] = model;
          } else {
            _trainSchedules.add(model);
          }
        }
      }

      // 3. Ambil bookings dari Supabase khusus untuk user aktif via GET PostgREST (HTTP 200 OK)
      final rawEmail =
          (await SessionService.getUserEmail())?.toLowerCase().trim() ?? '';
      final currentUserEmail = SecurityGuard.sanitizeEmail(rawEmail);

      if (currentUserEmail.isNotEmpty) {
        final remoteBookings = await client
            .from('bookings')
            .select('*')
            .eq('passenger_email', currentUserEmail)
            .order('created_at', ascending: false);

        if (remoteBookings.isNotEmpty) {
          final Map<String, BookingModel> prevLocal = {
            for (final b in _bookings) b.bookingId: b,
          };
          _bookings.removeWhere(
            (b) => b.passengerEmail.toLowerCase().trim() == currentUserEmail,
          );
          for (final m in remoteBookings) {
            final parsed = BookingModel.fromMap(Map<String, dynamic>.from(m));
            final old = prevLocal[parsed.bookingId];
            _bookings.add(
              parsed.copyWith(
                passengers: parsed.passengers ?? old?.passengers,
                qrCodeUrl: parsed.qrCodeUrl ?? old?.qrCodeUrl,
              ),
            );
          }
          await _saveBookingsToPrefs();
          debugPrint(
            '✅ [Supabase Sync 200] Berhasil memuat ${remoteBookings.length} tiket untuk $currentUserEmail.',
          );
        }
      }
    } catch (e) {
      debugPrint(
        'Supabase background sync notice: $e (Sistem otomatis memakai cache lokal terverifikasi)',
      );
    }
  }
}
