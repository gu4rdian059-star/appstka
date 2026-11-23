import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_env.dart';

/// Zona waktu resmi Republik Indonesia.
enum IndonesiaTimezone {
  wib('WIB', 'Waktu Indonesia Barat', 7),
  wita('WITA', 'Waktu Indonesia Tengah', 8),
  wit('WIT', 'Waktu Indonesia Timur', 9);

  final String code;
  final String fullName;
  final int utcOffsetHours;

  const IndonesiaTimezone(this.code, this.fullName, this.utcOffsetHours);

  Duration get offset => Duration(hours: utcOffsetHours);

  static IndonesiaTimezone fromCode(String? code) {
    switch ((code ?? '').toUpperCase().trim()) {
      case 'WITA':
        return IndonesiaTimezone.wita;
      case 'WIT':
        return IndonesiaTimezone.wit;
      default:
        return IndonesiaTimezone.wib;
    }
  }
}

/// Service real-time zona waktu Indonesia (WIB / WITA / WIT) berbasis UTC
/// agar tampilan jam selalu akurat tanpa terpengaruh timezone perangkat.
class IndonesiaTimeService {
  static const String _prefKeyTimezone = 'tka_preferred_timezone';

  static final ValueNotifier<IndonesiaTimezone> currentTimezone =
      ValueNotifier<IndonesiaTimezone>(IndonesiaTimezone.wib);

  static const List<String> _days = [
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ];

  static const List<String> _months = [
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

  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKeyTimezone);
      final initial = IndonesiaTimezone.fromCode(
        saved ?? AppEnv.defaultTimezone,
      );
      currentTimezone.value = initial;
    } catch (_) {
      currentTimezone.value = IndonesiaTimezone.fromCode(AppEnv.defaultTimezone);
    }
  }

  static Future<void> setTimezone(IndonesiaTimezone zone) async {
    currentTimezone.value = zone;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyTimezone, zone.code);
    } catch (_) {}
  }

  /// Waktu saat ini dalam zona waktu Indonesia (dikonversi dari UTC).
  static DateTime now([IndonesiaTimezone? zone]) {
    final tz = zone ?? currentTimezone.value;
    return DateTime.now().toUtc().add(tz.offset);
  }

  /// Konversi DateTime apapun (UTC atau lokal) ke wall-clock zona Indonesia.
  static DateTime toZone(DateTime dateTime, [IndonesiaTimezone? zone]) {
    final tz = zone ?? currentTimezone.value;
    return dateTime.toUtc().add(tz.offset);
  }

  /// Stream jam real-time per detik dalam zona waktu Indonesia terpilih.
  static Stream<DateTime> clockStream([IndonesiaTimezone? zone]) {
    return Stream<DateTime>.periodic(
      const Duration(seconds: 1),
      (_) => now(zone),
    );
  }

  static String _pad2(int n) => n.toString().padLeft(2, '0');

  /// Format jam: `22:15 WIB` atau `22:15:09 WIB`
  static String formatTime(
    DateTime? dt, {
    bool withSeconds = false,
    bool showZone = true,
    IndonesiaTimezone? zone,
  }) {
    if (dt == null) return '-';
    final tz = zone ?? currentTimezone.value;
    final shifted = toZone(dt, tz);
    final base = withSeconds
        ? '${_pad2(shifted.hour)}:${_pad2(shifted.minute)}:${_pad2(shifted.second)}'
        : '${_pad2(shifted.hour)}:${_pad2(shifted.minute)}';
    return showZone ? '$base ${tz.code}' : base;
  }

  /// Format jam untuk DateTime yang sudah berupa wall-clock Indonesia (hasil `now()`).
  static String formatWallClock(
    DateTime wallClock, {
    bool withSeconds = true,
    IndonesiaTimezone? zone,
  }) {
    final tz = zone ?? currentTimezone.value;
    final base = withSeconds
        ? '${_pad2(wallClock.hour)}:${_pad2(wallClock.minute)}:${_pad2(wallClock.second)}'
        : '${_pad2(wallClock.hour)}:${_pad2(wallClock.minute)}';
    return '$base ${tz.code}';
  }

  /// Format tanggal: `Jum, 20 Nov 2026`
  static String formatDate(DateTime? dt, {IndonesiaTimezone? zone}) {
    if (dt == null) return '-';
    final shifted = toZone(dt, zone);
    final dayName = _days[shifted.weekday - 1];
    final monthName = _months[shifted.month - 1];
    return '$dayName, ${shifted.day} $monthName ${shifted.year}';
  }

  /// Format tanggal & jam lengkap: `Jum, 20 Nov 2026 • 22:15 WIB`
  static String formatDateTime(
    DateTime? dt, {
    bool withSeconds = false,
    IndonesiaTimezone? zone,
  }) {
    if (dt == null) return '-';
    return '${formatDate(dt, zone: zone)} • ${formatTime(dt, withSeconds: withSeconds, zone: zone)}';
  }

  /// Format selisih waktu relatif dari sekarang (berbasis UTC).
  static String formatRelative(DateTime? dt) {
    if (dt == null) return 'Belum pernah diperbarui';
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inSeconds < 5) return 'Baru saja';
    if (diff.inSeconds < 60) return '${diff.inSeconds} detik lalu';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  /// Format sisa waktu menuju ETA (misal `1j 25m lagi` atau `Tiba sebentar lagi`).
  static String formatRemainingToEta(DateTime? eta) {
    if (eta == null) return 'Tidak dapat dihitung';
    final diff = eta.toUtc().difference(DateTime.now().toUtc());
    if (diff.isNegative) {
      final pastMin = diff.inMinutes.abs();
      if (pastMin < 2) return 'Sedang tiba';
      return 'Lewat $pastMin mnt dari jadwal';
    }
    if (diff.inMinutes < 1) return 'Kurang dari 1 menit';
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    if (hours == 0) return '$mins menit lagi';
    return '${hours}j ${mins}m lagi';
  }

  /// Buat DateTime UTC dari jam & menit hari ini (WIB UTC+7) untuk jadwal kereta.
  static DateTime todayWibUtc(int hour, int minute, {int addDays = 0}) {
    final wibNow = now(IndonesiaTimezone.wib);
    final targetWib = DateTime.utc(
      wibNow.year,
      wibNow.month,
      wibNow.day + addDays,
      hour,
      minute,
    );
    return targetWib.subtract(const Duration(hours: 7));
  }
}

