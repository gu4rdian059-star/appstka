import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';
import 'session_service.dart';
import 'auth_service.dart';
import 'supabase_storage_service.dart';

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

  /// Cari Stasiun se-Indonesia dengan filter query dan region
  static Future<List<StationModel>> getStations({
    String? query,
    String? region,
  }) async {
    await initialize();

    var list = _stations;
    if (region != null && region != 'Semua') {
      list = list
          .where((s) => s.region.toLowerCase() == region.toLowerCase())
          .toList();
    }

    if (query != null && query.trim().isNotEmpty) {
      final clean = query.trim().toLowerCase();
      list = list.where((s) {
        return s.code.toLowerCase().contains(clean) ||
            s.name.toLowerCase().contains(clean) ||
            s.city.toLowerCase().contains(clean);
      }).toList();
    }

    return list;
  }

  /// Ambil Riwayat Pencarian Terakhir
  static Future<List<RecentSearchModel>> getRecentSearches() async {
    await initialize();
    return List.unmodifiable(_recentSearches);
  }

  /// Tambahkan Pencarian ke Riwayat
  static Future<void> addRecentSearch(RecentSearchModel search) async {
    await initialize();

    // Hindari duplikasi rute yang sama
    _recentSearches.removeWhere(
      (s) => s.originCode == search.originCode && s.destCode == search.destCode,
    );

    _recentSearches.insert(0, search);

    // Maksimal simpan 10 riwayat
    if (_recentSearches.length > 10) {
      _recentSearches.removeLast();
    }

    await _saveRecentSearchesToPrefs();

    // Kirim juga ke Supabase jika tabel 'recent_searches' ada
    try {
      final client = SupabaseService.client;
      await client.from('recent_searches').upsert(search.toMap());
    } catch (e) {
      debugPrint('Catatan insert recent_searches Supabase: $e');
    }
  }

  /// Hapus Satu Riwayat Pencarian
  static Future<void> deleteRecentSearch(String id) async {
    await initialize();
    _recentSearches.removeWhere((s) => s.id == id);
    await _saveRecentSearchesToPrefs();
  }

  /// Hapus Seluruh Riwayat Pencarian
  static Future<void> clearRecentSearches() async {
    await initialize();
    _recentSearches.clear();
    await _saveRecentSearchesToPrefs();

    try {
      final client = SupabaseService.client;
      final user = client.auth.currentUser;
      if (user != null) {
        await client.from('recent_searches').delete().eq('user_id', user.id);
      }
    } catch (e) {
      debugPrint('Catatan clear recent_searches Supabase: $e');
    }
  }

  /// Cari Jadwal Kereta Berdasarkan Stasiun Asal & Tujuan
  static Future<List<TrainScheduleModel>> searchTrains({
    required String originCode,
    required String destCode,
    String? trainClass,
  }) async {
    await initialize();

    // Cari jadwal langsung
    var matches = _trainSchedules.where((t) {
      return t.originCode.toUpperCase() == originCode.toUpperCase() &&
          t.destCode.toUpperCase() == destCode.toUpperCase();
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

  /// Ambil Daftar Pesanan (Bookings) - HANYA milik user yang sedang login!
  static Future<List<BookingModel>> getBookings({String? statusFilter}) async {
    await initialize();

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

    final currentEmail =
        (await SessionService.getUserEmail())?.toLowerCase().trim() ?? '';
    final currentName = (await SessionService.getUserName())
        .toLowerCase()
        .trim();
    final isDemoSamuel =
        currentEmail == 'kocak@co.id' || currentName == 'samuel';

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
    mainQrUrl ??= SupabaseStorageService.getTicketQrUrl(baseBookingCode);

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
    await _saveBookingsToPrefs();

    // Masukkan SEMUA penumpang ke Supabase bookings table
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

        // Buat dan unggah QR tiket untuk sub-booking ini ke Supabase Storage (tickets-qr)
        String? subQrUrl = i == 0 ? mainQrUrl : null;
        if (subQrUrl == null) {
          try {
            final subQrBytes = await SupabaseStorageService.generateTicketQrPng(
              bookingId: subBookingId,
              pnr: subBookingId,
              trainName: schedule.name,
              seatNumber: pSeat,
            );
            subQrUrl = await SupabaseStorageService.uploadTicketQr(
              bookingId: subBookingId,
              pngBytes: subQrBytes,
            );
          } catch (_) {}
          subQrUrl ??= SupabaseStorageService.getTicketQrUrl(subBookingId);
        }

        final pBookingMap = {
          'booking_id': subBookingId,
          'passenger_name': pName,
          'passenger_email': bookerEmail,
          'passenger_phone': bookerPhone,
          'passenger_nik': pNik,
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
          'total_amount': singleFare,
          'status': finalStatus,
          'payment_method': finalPaymentMethod,
          'va_number': finalVaNumber,
          'created_at': DateTime.now().toIso8601String(),
          if (subQrUrl != null) 'qr_code_url': subQrUrl,
        };

        if (_isValidUuid(savedUserId)) {
          pBookingMap['user_id'] = savedUserId!;
        }

        try {
          await client.from('bookings').upsert(pBookingMap);
        } catch (upsertErr) {
          if (upsertErr.toString().contains('qr_code_url')) {
            pBookingMap.remove('qr_code_url');
            await client.from('bookings').upsert(pBookingMap);
          } else {
            rethrow;
          }
        }

        debugPrint(
          '✅ [Supabase Insert Success] Penumpang ${i + 1} ($pName - $pSeat) berhasil masuk Supabase: $subBookingId (QR: $subQrUrl)',
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
    qrUrl ??= SupabaseStorageService.getTicketQrUrl(bookingCode);

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

    // Simpan ke Supabase jika terhubung (dengan validasi user_id dan select check)
    try {
      final client = SupabaseService.client;
      final bookingMap = newBooking.toMap();
      var currentUser = client.auth.currentUser;
      currentUser ??= await AuthService.ensureSupabaseAuthSession();
      final savedUserId = currentUser?.id ?? await SessionService.getUserId();
      if (_isValidUuid(savedUserId)) {
        bookingMap['user_id'] = savedUserId!;
      } else {
        bookingMap.remove('user_id');
      }

      try {
        final res = await client.from('bookings').insert(bookingMap).select();
        debugPrint(
          '✅ [Supabase Insert Success] Tiket $bookingCode berhasil masuk ke tabel bookings Supabase: $res (QR: $qrUrl)',
        );
      } catch (insertErr) {
        if (insertErr.toString().contains('qr_code_url')) {
          bookingMap.remove('qr_code_url');
          final res = await client.from('bookings').insert(bookingMap).select();
          debugPrint(
            '✅ [Supabase Insert Success (fallback)] Tiket $bookingCode berhasil masuk ke tabel bookings Supabase: $res',
          );
        } else {
          rethrow;
        }
      }

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

      final payMap = <String, dynamic>{
        'payment_id':
            'PAY-${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}',
        'booking_id': bookingId,
        'payment_method': paymentMethod,
        'payment_channel': channel,
        'reference_number': referenceNumber,
        'amount': amount,
        'status': status,
        'paid_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      };
      if (_isValidUuid(savedUserId)) {
        payMap['user_id'] = savedUserId!;
      }

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
          // Jika tiket sebelumnya baru di memori lokal, masukkan record lengkap dengan status Dibatalkan
          final upsertMap = _bookings[index].toMap();
          if (_isValidUuid(savedUserId)) {
            upsertMap['user_id'] = savedUserId!;
          } else {
            upsertMap.remove('user_id');
          }
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

  /// Mencatat riwayat pembatalan ke tabel cancellations Supabase dengan fallback berlapis:
  /// 1. Schema lengkap standar (booking_id VARCHAR)
  /// 2. Schema minimal 4-kolom (id, booking_id, user_id, reason)
  /// 3. Schema UUID deterministik (jika booking_id di Supabase masih bertipe UUID)
  /// 4. Fallback tanpa user_id jika ada RLS / foreign key error
  /// 5. Fallback minimal reason
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
      final hasValidUser = _isValidUuid(savedUserId);
      final uuidCode = _codeToUuid(bookingCode);

      // Plan 1: Schema Lengkap (booking_id VARCHAR)
      try {
        final payload = <String, dynamic>{
          'booking_id': bookingCode,
          'reason': reason,
          'refund_amount': refundAmount,
          'status': 'Dibatalkan',
          'created_at': DateTime.now().toIso8601String(),
        };
        if (hasValidUser) payload['user_id'] = savedUserId!;
        await client.from('cancellations').insert(payload);
        debugPrint(
          '✅ [Supabase Cancellations Success] Tercatat dengan booking_id $bookingCode',
        );
        return;
      } catch (err1) {
        debugPrint('⚠️ [Supabase Cancellations Plan 1 Info]: $err1');
      }

      // Plan 2: Schema Minimal 4 Kolom (booking_id VARCHAR)
      try {
        final payload = <String, dynamic>{
          'booking_id': bookingCode,
          'reason': reason,
        };
        if (hasValidUser) payload['user_id'] = savedUserId!;
        await client.from('cancellations').insert(payload);
        debugPrint(
          '✅ [Supabase Cancellations Success] Tercatat dengan schema 4 kolom VARCHAR',
        );
        return;
      } catch (err2) {
        debugPrint('⚠️ [Supabase Cancellations Plan 2 Info]: $err2');
      }

      // Plan 3: Schema UUID (Jika di Supabase kolom booking_id masih bertipe UUID)
      try {
        final payload = <String, dynamic>{
          'booking_id': uuidCode,
          'reason': '$reason (Kode: $bookingCode)',
          'refund_amount': refundAmount,
          'status': 'Dibatalkan',
          'created_at': DateTime.now().toIso8601String(),
        };
        if (hasValidUser) payload['user_id'] = savedUserId!;
        await client.from('cancellations').insert(payload);
        debugPrint(
          '✅ [Supabase Cancellations Success] Tercatat dengan UUID deterministik: $uuidCode',
        );
        return;
      } catch (err3) {
        debugPrint('⚠️ [Supabase Cancellations Plan 3 Info]: $err3');
      }

      // Plan 4: Schema UUID Minimal 4 Kolom (booking_id UUID)
      try {
        final payload = <String, dynamic>{
          'booking_id': uuidCode,
          'reason': '$reason (Kode: $bookingCode)',
        };
        if (hasValidUser) payload['user_id'] = savedUserId!;
        await client.from('cancellations').insert(payload);
        debugPrint(
          '✅ [Supabase Cancellations Success] Tercatat dengan UUID 4 kolom',
        );
        return;
      } catch (err4) {
        debugPrint('⚠️ [Supabase Cancellations Plan 4 Info]: $err4');
      }

      // Plan 5: Omit user_id jika ada RLS atau Foreign Key error pada user_id
      try {
        final payload = <String, dynamic>{
          'booking_id': uuidCode,
          'reason':
              '$reason (Kode: $bookingCode, User: ${savedUserId ?? "Anonim"})',
        };
        await client.from('cancellations').insert(payload);
        debugPrint(
          '✅ [Supabase Cancellations Success] Tercatat tanpa user_id FK',
        );
        return;
      } catch (err5) {
        debugPrint('⚠️ [Supabase Cancellations Plan 5 Info]: $err5');
      }

      // Plan 6: Fallback Darurat Hanya Reason
      try {
        await client.from('cancellations').insert({
          'reason': 'Pembatalan $bookingCode: $reason',
        });
        debugPrint(
          '✅ [Supabase Cancellations Success] Tercatat pada fallback reason',
        );
      } catch (err6) {
        debugPrint(
          '❌ [Supabase Cancellations Final Error] Seluruh metode insert gagal: $err6',
        );
      }
    } catch (outerErr) {
      debugPrint('❌ [Supabase Cancellations Error]: $outerErr');
    }
  }

  // ===========================================================================
  // 5. SINKRONISASI SUPABASE BACKGROUND
  // ===========================================================================
  static void _syncWithSupabaseBackground() async {
    try {
      final client = SupabaseService.client;

      // 1. Ambil stations dari Supabase jika ada (Merge, jangan pernah hapus data lokal)
      final remoteStations = await client
          .from('stations')
          .select('code, name, city, region');
      if (remoteStations.isNotEmpty) {
        for (final m in remoteStations) {
          final model = StationModel.fromMap(m);
          final idx = _stations.indexWhere((s) => s.code == model.code);
          if (idx != -1) {
            _stations[idx] = model;
          } else {
            _stations.add(model);
          }
        }

        // Coba sinkronisasi stasiun lokal yang belum ada di Supabase
        try {
          final remoteCodes = remoteStations
              .map((e) => e['code']?.toString())
              .toSet();
          final missingStations = _stations
              .where((s) => !remoteCodes.contains(s.code))
              .toList();
          if (missingStations.isNotEmpty) {
            final payload = missingStations.map((s) => s.toMap()).toList();
            await client.from('stations').upsert(payload);
            debugPrint(
              '✅ [Supabase Sync] Berhasil sinkronisasi ${payload.length} stasiun ke Supabase.',
            );
          }
        } catch (_) {}
      }

      // 2. Ambil train_schedules dari Supabase jika ada (Merge)
      final remoteSchedules = await client.from('train_schedules').select('*');
      if (remoteSchedules.isNotEmpty) {
        for (final m in remoteSchedules) {
          final model = TrainScheduleModel.fromMap(m);
          final idx = _trainSchedules.indexWhere((s) => s.id == model.id);
          if (idx != -1) {
            _trainSchedules[idx] = model;
          } else {
            _trainSchedules.add(model);
          }
        }
      }

      // 3. Ambil bookings dari Supabase khusus untuk user aktif
      final currentUserEmail =
          (await SessionService.getUserEmail())?.toLowerCase().trim() ?? '';
      final currentUserName = (await SessionService.getUserName())
          .toLowerCase()
          .trim();
      final isDemoSamuel =
          currentUserEmail == 'kocak@co.id' || currentUserName == 'samuel';

      if (currentUserEmail.isNotEmpty) {
        final remoteBookings = await client
            .from('bookings')
            .select('*')
            .eq('passenger_email', currentUserEmail)
            .order('created_at', ascending: false);

        if (remoteBookings.isNotEmpty) {
          _bookings.removeWhere(
            (b) => b.passengerEmail.toLowerCase().trim() == currentUserEmail,
          );
          for (final m in remoteBookings) {
            _bookings.add(BookingModel.fromMap(m));
          }
          await _saveBookingsToPrefs();
          debugPrint(
            '✅ [Supabase Sync] Berhasil memuat ${remoteBookings.length} tiket untuk $currentUserEmail.',
          );
        } else if (isDemoSamuel && _bookings.isNotEmpty) {
          // Hanya sync demo awal jika user adalah akun demo Samuel
          for (final b in _bookings) {
            try {
              final map = b.toMap();
              map.remove('user_id');
              await client.from('bookings').upsert(map);
            } catch (itemErr) {
              debugPrint('Catatan seeding booking ${b.bookingId}: $itemErr');
            }
          }
        }

        // Sinkronkan tiket yang berstatus Dibatalkan ke tabel cancellations Supabase
        for (final b in _bookings.where((x) => x.status == 'Dibatalkan')) {
          _recordCancellationInSupabase(
            bookingCode: b.bookingId,
            reason: b.cancelReason ?? 'Pembatalan oleh pengguna',
            refundAmount: b.refundAmount ?? (b.totalAmount * 0.75).round(),
          );
        }

        // 4. Sinkronisasi aset kereta ke train-assets dan QR tiket ke tickets-qr di background
        SupabaseStorageService.seedTrainAssetsToStorage();
        for (final b in _bookings.take(5)) {
          SupabaseStorageService.ensureTicketQrUploaded(
            bookingId: b.bookingId,
            pnr: b.bookingId,
            trainName: b.trainName,
            seatNumber: b.seatNumber,
          );
        }
      }
    } catch (e) {
      debugPrint(
        'Supabase background sync notice: $e (Sistem otomatis memakai database lokal terverifikasi)',
      );
    }
  }
}
