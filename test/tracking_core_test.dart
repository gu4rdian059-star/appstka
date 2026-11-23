import 'package:flutter_test/flutter_test.dart';
import 'package:appstka/models/tracking_models.dart';
import 'package:appstka/services/brevo_notification_service.dart';
import 'package:appstka/services/indonesia_time_service.dart';

void main() {
  group('Honest Train Data Status Guard', () {
    test('Simulated data NEVER returns LIVE status', () {
      final status = TrainDataStatus.fromString('LIVE', isSimulated: true);
      expect(status, TrainDataStatus.demo);
    });

    test('Genuine non-simulated LIVE returns LIVE status', () {
      final status = TrainDataStatus.fromString('LIVE', isSimulated: false);
      expect(status, TrainDataStatus.live);
    });

    test('All 5 statuses parse cleanly', () {
      expect(TrainDataStatus.fromString('LIVE'), TrainDataStatus.live);
      expect(TrainDataStatus.fromString('DELAYED'), TrainDataStatus.delayed);
      expect(TrainDataStatus.fromString('SCHEDULED'), TrainDataStatus.scheduled);
      expect(TrainDataStatus.fromString('DEMO'), TrainDataStatus.demo);
      expect(
        TrainDataStatus.fromString('UNAVAILABLE'),
        TrainDataStatus.unavailable,
      );
    });
  });

  group('Indonesia Real-Time Timezone Service', () {
    test('Converts UTC accurately to WIB (+7), WITA (+8), WIT (+9)', () {
      final utc = DateTime.utc(2026, 11, 20, 10, 30, 0);
      expect(
        IndonesiaTimeService.formatTime(utc, zone: IndonesiaTimezone.wib),
        '17:30 WIB',
      );
      expect(
        IndonesiaTimeService.formatTime(utc, zone: IndonesiaTimezone.wita),
        '18:30 WITA',
      );
      expect(
        IndonesiaTimeService.formatTime(utc, zone: IndonesiaTimezone.wit),
        '19:30 WIT',
      );
    });
  });

  group('Brevo Notification Deduplication Key', () {
    test('Produces identical deterministic dedup key for same event', () {
      final key1 = BrevoNotificationService.buildDedupKey(
        eventType: TrainNotificationEventType.trainDelay,
        tripId: 'trip-ka40-ap',
        incidentCode: 'delay 18m',
      );
      final key2 = BrevoNotificationService.buildDedupKey(
        eventType: TrainNotificationEventType.trainDelay,
        tripId: 'TRIP-KA40-AP',
        incidentCode: 'DELAY_18M',
      );
      expect(key1, key2);
      expect(key1, 'TRAIN_DELAY:TRIP-KA40-AP:DELAY_18M');
    });
  });

  group('TrainTripModel ETA & Real-Time Truthfulness', () {
    test('UNAVAILABLE trip returns null ETA and isTrulyRealTime false', () {
      final now = DateTime.now().toUtc();
      final trip = TrainTripModel(
        id: 'TRIP-TEST-1',
        trainNumber: 'KA U12',
        trainName: 'KA Bandara',
        region: 'Sumatera',
        originCode: 'MDN',
        originName: 'Medan',
        destinationCode: 'KNM',
        destinationName: 'Kualanamu',
        serviceDate: now,
        scheduledDeparture: now,
        scheduledArrival: now.add(const Duration(minutes: 35)),
        dataStatus: TrainDataStatus.unavailable,
        tripStatus: 'Tidak Tersedia',
        isSimulated: false,
        dataSourceLabel: 'Offline',
      );
      expect(trip.computedEta, isNull);
      expect(trip.isTrulyRealTime, isFalse);
    });
  });
}

