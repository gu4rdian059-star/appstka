import 'dart:convert';

/// Lapisan Keamanan Terpusat (Security Guard) untuk TKA Rail:
/// - Sanitasi input terhadap XSS (Cross-Site Scripting) & HTML Injection
/// - Proteksi terhadap SQL Injection & PostgREST Filter Injection
/// - Whitelist kolom skema database (mencegah Mass-Assignment & Error 400 PGRST204)
class SecurityGuard {
  SecurityGuard._();

  // ==================== SKEMA WHITELIST TABEL SUPABASE ====================
  static const Set<String> usersCoreColumns = {
    'id',
    'email',
    'full_name',
    'phone',
    'role',
    'created_at',
    'updated_at',
  };

  static const Set<String> usersExtendedColumns = {
    ...usersCoreColumns,
    'balance',
    'avatar_url',
    'nik',
    'gender',
    'document_type',
    'birth_date',
  };

  static const Set<String> profilesColumns = {
    'id',
    'email',
    'full_name',
    'phone',
    'role',
    'created_at',
    'balance',
  };

  static const Set<String> bookingsColumns = {
    'booking_id',
    'user_id',
    'passenger_name',
    'passenger_email',
    'passenger_phone',
    'passenger_nik',
    'train_number',
    'train_name',
    'train_class',
    'wagon_class',
    'route',
    'origin_code',
    'origin_name',
    'origin_city',
    'dest_code',
    'dest_name',
    'dest_city',
    'travel_date',
    'departure_time',
    'arrival_time',
    'seat_number',
    'amount',
    'total_amount',
    'status',
    'payment_method',
    'va_number',
    'cancel_reason',
    'refund_amount',
    'created_at',
  };

  static const Set<String> cancellationsColumns = {
    'id',
    'booking_id',
    'user_id',
    'reason',
    'refund_amount',
  };

  static const Set<String> paymentsColumns = {
    'payment_id',
    'booking_id',
    'user_id',
    'payment_method',
    'payment_channel',
    'reference_number',
    'amount',
    'status',
    'paid_at',
    'created_at',
  };

  static const Set<String> stationsColumns = {
    'code',
    'name',
    'city',
    'region',
    'created_at',
  };

  static const Set<String> trainSchedulesColumns = {
    'id',
    'train_number',
    'name',
    'train_name',
    'category',
    'origin',
    'destination',
    'origin_code',
    'origin_name',
    'origin_city',
    'dest_code',
    'dest_name',
    'dest_city',
    'departure_time',
    'arrival_time',
    'duration',
    'base_fare',
    'fare',
    'status',
    'capacity',
    'booked_seats',
    'available_classes',
    'available_seats',
    'created_at',
  };

  static const Set<String> recentSearchesColumns = {
    'id',
    'user_id',
    'origin_code',
    'origin_name',
    'dest_code',
    'dest_name',
    'travel_date',
    'passengers',
    'created_at',
  };

  // ==================== POLA DETEKSI SERANGAN ====================
  static final RegExp _sqlInjectionPattern = RegExp(
    r"(\b(UNION\s+ALL\s+SELECT|UNION\s+SELECT|DROP\s+TABLE|DROP\s+DATABASE|TRUNCATE\s+TABLE|ALTER\s+TABLE|INSERT\s+INTO|DELETE\s+FROM|PG_SLEEP|INFORMATION_SCHEMA|XP_CMDSHELL)\b)|(--\s*$)|(/\*[\s\S]*?\*/)|('\s*OR\s+'?1'?\s*=\s*'?1)|('\s*;\s*)",
    caseSensitive: false,
  );

  static final RegExp _xssPattern = RegExp(
    r'(<\s*/?\s*(script|iframe|object|embed|svg|math|link|meta|style|form|base)\b)|(on[a-z]+\s*=)|(javascript\s*:)|(vbscript\s*:)|(data\s*:\s*text/html)',
    caseSensitive: false,
  );

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  /// Deteksi pola SQL Injection atau PostgREST Filter Injection
  static bool containsSqlInjection(String input) {
    if (input.isEmpty) return false;
    return _sqlInjectionPattern.hasMatch(input);
  }

  /// Deteksi pola Cross-Site Scripting (XSS)
  static bool containsXss(String input) {
    if (input.isEmpty) return false;
    return _xssPattern.hasMatch(input);
  }

  /// Escape karakter HTML berbahaya (wajib untuk template email & rich HTML)
  static String escapeHtml(String input) {
    const HtmlEscape escape = HtmlEscape(HtmlEscapeMode.element);
    return escape
        .convert(input)
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  /// Sanitasi teks input umum dari tag HTML/script, karakter kontrol, dan SQLi
  static String sanitizeText(String input, {int maxLength = 250}) {
    if (input.isEmpty) return '';
    var cleaned = input
        // Hapus karakter kontrol berbahaya
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        // Hapus blok <script>...</script>
        .replaceAll(
          RegExp(r'<\s*script[^>]*>[\s\S]*?<\s*/\s*script\s*>', caseSensitive: false),
          '',
        )
        // Hapus semua tag HTML mentah
        .replaceAll(RegExp(r'<[^>]*>'), '')
        // Hapus skema URI berbahaya
        .replaceAll(RegExp(r'(javascript|vbscript|data)\s*:', caseSensitive: false), '')
        .trim();

    if (containsSqlInjection(cleaned)) {
      cleaned = cleaned
          .replaceAll("'", '')
          .replaceAll('"', '')
          .replaceAll(';', '')
          .replaceAll('--', '');
    }

    if (cleaned.length > maxLength) {
      cleaned = cleaned.substring(0, maxLength);
    }
    return cleaned;
  }

  /// Sanitasi kode identifier (booking_id, payment_id, search_id)
  static String sanitizeIdentifier(String input, {int maxLength = 64}) {
    final cleaned = input.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '');
    if (cleaned.length > maxLength) {
      return cleaned.substring(0, maxLength);
    }
    return cleaned;
  }

  /// Sanitasi kode stasiun (2-6 huruf/angka kapital, misal GMR, BD, JAKK)
  static String sanitizeStationCode(String input) {
    final cleaned = input
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (cleaned.length > 6) return cleaned.substring(0, 6);
    return cleaned;
  }

  /// Validasi & normalisasi alamat email secara ketat
  static String sanitizeEmail(String input) {
    final cleaned = input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'''[\s'"<>(),;:\\]'''), '');
    if (!_emailRegex.hasMatch(cleaned)) {
      return '';
    }
    return cleaned;
  }

  /// Sanitasi nomor telepon
  static String sanitizePhone(String input) {
    final cleaned = input.trim().replaceAll(RegExp(r'[^0-9+\-\s]'), '');
    if (cleaned.length > 22) return cleaned.substring(0, 22);
    return cleaned;
  }

  /// Sanitasi NIK / Nomor Paspor
  static String sanitizeNik(String input) {
    final cleaned = input
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (cleaned.length > 24) return cleaned.substring(0, 24);
    return cleaned;
  }

  /// Validasi UUID standar PostgreSQL
  static bool isValidUuid(String? value) {
    if (value == null || value.isEmpty) return false;
    return _uuidRegex.hasMatch(value.trim());
  }

  /// Batasi nilai nominal uang agar selalu positif dan aman dari integer overflow
  static int sanitizeAmount(num value, {int min = 0, int max = 500000000}) {
    final rounded = value.round();
    if (rounded < min) return min;
    if (rounded > max) return max;
    return rounded;
  }

  /// Filter & sanitasi Map payload sesuai daftar kolom resmi tabel PostgreSQL.
  /// Menjamin 100% bebas error PostgREST 400 (PGRST204) dan Mass-Assignment.
  static Map<String, dynamic> sanitizePayload(
    Map<String, dynamic> raw,
    Set<String> allowedColumns,
  ) {
    final result = <String, dynamic>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      final val = entry.value;
      if (!allowedColumns.contains(key) || val == null) continue;

      if (val is String) {
        if (key.contains('email')) {
          final email = sanitizeEmail(val);
          if (email.isNotEmpty) result[key] = email;
        } else if (key.contains('phone')) {
          result[key] = sanitizePhone(val);
        } else if (key.contains('nik')) {
          result[key] = sanitizeNik(val);
        } else if (key.endsWith('_code') || key == 'code') {
          result[key] = sanitizeStationCode(val);
        } else if (key == 'user_id') {
          if (isValidUuid(val)) result[key] = val.trim();
        } else {
          result[key] = sanitizeText(val, maxLength: 500);
        }
      } else if (val is int || val is double || val is bool) {
        result[key] = val;
      } else if (val is List) {
        result[key] = val
            .map((e) => e is String ? sanitizeText(e, maxLength: 100) : e)
            .toList();
      } else {
        result[key] = val;
      }
    }
    return result;
  }
}

