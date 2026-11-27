import 'package:flutter_test/flutter_test.dart';
import 'package:appstka/services/security_guard.dart';
import 'package:appstka/services/user_db_service.dart';

void main() {
  group('SecurityGuard Anti-SQLi, Anti-XSS & Schema Whitelist Verification', () {
    test('Blocks and strips XSS payloads and escapes HTML safely', () {
      const malicious = '<script>alert("xss")</script>Budi<img src=x onerror=alert(1)>';
      expect(SecurityGuard.containsXss(malicious), isTrue);

      final cleaned = SecurityGuard.sanitizeText(malicious);
      expect(cleaned.contains('<script>'), isFalse);
      expect(cleaned.contains('<img'), isFalse);
      expect(cleaned, equals('Budi'));

      final escaped = SecurityGuard.escapeHtml('<b>O\'Reilly & "Co"</b>');
      expect(escaped, equals('&lt;b&gt;O&#39;Reilly &amp; &quot;Co&quot;&lt;/b&gt;'));
    });

    test('Detects and neutralizes SQL Injection payloads', () {
      const sqli1 = "admin' OR '1'='1' --";
      const sqli2 = 'GMR; DROP TABLE bookings;--';
      expect(SecurityGuard.containsSqlInjection(sqli1), isTrue);
      expect(SecurityGuard.containsSqlInjection(sqli2), isTrue);

      expect(SecurityGuard.sanitizeEmail(sqli1), isEmpty);
      expect(SecurityGuard.sanitizeStationCode(sqli2), equals('GMRDRO'));
    });

    test('BookingModel.toSupabaseMap strips non-existent columns (prevents PGRST204 400)', () {
      final booking = BookingModel(
        bookingId: 'TKA-998877',
        passengerName: 'Siti Aminah',
        passengerEmail: 'siti@example.com',
        passengerPhone: '081234567890',
        passengerNik: '3578012345670001',
        trainName: 'KA Argo Bromo Anggrek',
        trainClass: 'Eksekutif • 2A',
        originCode: 'GMR',
        originName: 'Gambir',
        originCity: 'Jakarta',
        destCode: 'SBI',
        destName: 'Surabaya Pasarturi',
        destCity: 'Surabaya',
        travelDate: '2026-11-30',
        departureTime: '08:20 WIB',
        arrivalTime: '16:25 WIB',
        seatNumber: '2A',
        totalAmount: 640000,
        status: 'Sudah Dibayar',
        paymentMethod: 'QRIS',
        vaNumber: 'NMID-12345',
        createdAt: DateTime.utc(2026, 11, 25),
        passengers: const [
          {'name': 'Siti Aminah', 'seat': '2A'},
        ],
        qrCodeUrl: 'https://example.com/qr.png',
      );

      final supaMap = booking.toSupabaseMap(
        userId: '9154de6e-733f-4450-9543-79270237da12',
        trainNumber: 'KA 2',
        wagonClass: 'Eksekutif',
      );

      expect(supaMap.containsKey('passengers'), isFalse);
      expect(supaMap.containsKey('qr_code_url'), isFalse);
      expect(supaMap['booking_id'], equals('TKA-998877'));
      expect(supaMap['user_id'], equals('9154de6e-733f-4450-9543-79270237da12'));
      expect(supaMap['amount'], equals(640000));
      expect(supaMap['total_amount'], equals(640000));
      expect(supaMap['route'], equals('GMR -> SBI'));
    });

    test('Cancellations whitelist strips invalid status/created_at columns (prevents PGRST204)', () {
      final filtered = SecurityGuard.sanitizePayload(
        {
          'booking_id': '544b4136-3631-4335-a300-000000000000',
          'user_id': '9154de6e-733f-4450-9543-79270237da12',
          'reason': 'Jadwal berubah',
          'refund_amount': 150000,
          'status': 'Dibatalkan',
          'created_at': '2026-11-25T00:00:00Z',
        },
        SecurityGuard.cancellationsColumns,
      );

      expect(filtered.containsKey('status'), isFalse);
      expect(filtered.containsKey('created_at'), isFalse);
      expect(filtered['booking_id'], equals('544b4136-3631-4335-a300-000000000000'));
      expect(filtered['refund_amount'], equals(150000));
    });
  });
}

