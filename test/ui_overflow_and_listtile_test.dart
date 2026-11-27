import 'dart:convert';

import 'package:appstka/dashboard/dashboard_screen.dart';
import 'package:appstka/intercity/antar_kota_screen.dart';
import 'package:appstka/orders/orders_screen.dart';
import 'package:appstka/payment/payment_method_screen.dart';
import 'package:appstka/payment/transaction_status_screen.dart';
import 'package:appstka/profile/profile_screen.dart';
import 'package:appstka/services/user_db_service.dart';
import 'package:appstka/tickets/eticket_boarding_pass_screen.dart';
import 'package:appstka/tickets/my_tickets_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'tka_user_name': 'Azhar Samawwal',
      'tka_user_email': 'samawwalazhar@gmail.com',
      'tka_user_phone': '085738686279',
    });
  });

  final sampleOrigin = const StationModel(
    code: 'GMR',
    name: 'Gambir',
    city: 'Jakarta Pusat',
    region: 'Jabodetabek',
  );

  final sampleDest = const StationModel(
    code: 'SBI',
    name: 'Surabaya Pasarturi',
    city: 'Surabaya',
    region: 'Jawa Timur',
  );

  final sampleTrain = const TrainScheduleModel(
    id: 'SCH-001',
    trainNumber: 'KA 02',
    name: 'KA Nusantara Prioritas',
    originCode: 'GMR',
    originName: 'Gambir',
    originCity: 'Jakarta Pusat',
    destCode: 'SBI',
    destName: 'Surabaya Pasarturi',
    destCity: 'Surabaya',
    departureTime: '15:15 WIB',
    arrivalTime: '21:45 WIB',
    duration: '6j 30m',
    baseFare: 480000,
    availableClasses: ['Eksekutif', 'Luxury'],
    availableSeats: 26,
  );

  final sampleBooking = BookingModel(
    bookingId: 'TKA-027185',
    passengerName: 'Azhar Samawwal',
    passengerEmail: 'samawwalazhar@gmail.com',
    passengerPhone: '085738686279',
    passengerNik: '3514062607090001',
    trainName: 'KA Nusantara Prioritas',
    trainClass: 'Eksekutif • EKS-2 / 1D',
    originCode: 'GMR',
    originName: 'Gambir',
    originCity: 'Jakarta Pusat',
    destCode: 'SBI',
    destName: 'Surabaya Pasarturi',
    destCity: 'Surabaya',
    travelDate: 'Sab, 28 Nov 2026',
    departureTime: '15:15 WIB',
    arrivalTime: '21:45 WIB',
    seatNumber: 'EKS-2 / 1D',
    totalAmount: 480000,
    status: 'Sudah Dibayar',
    paymentMethod: 'QRIS Instant',
    vaNumber: 'NMID-1795796096',
    createdAt: DateTime(2026, 11, 27, 23, 47),
  );

  Future<void> pumpAtIphoneSeAndCheckZeroErrors(
    WidgetTester tester,
    Widget screen,
  ) async {
    final errors = <FlutterErrorDetails>[];
    final prevHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details);
    };

    try {
      await tester.binding.setSurfaceSize(const Size(375, 667));
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        errors,
        isEmpty,
        reason: errors
            .map((e) => e.exceptionAsString())
            .join('\n---\n'),
      );
    } finally {
      FlutterError.onError = prevHandler;
      await tester.binding.setSurfaceSize(null);
    }
  }

  testWidgets('PaymentMethodScreen renders with zero ListTile/overflow errors at 375x667', (
    tester,
  ) async {
    await pumpAtIphoneSeAndCheckZeroErrors(
      tester,
      PaymentMethodScreen(
        bookingCode: 'TKA-027185',
        train: sampleTrain,
        origin: sampleOrigin,
        dest: sampleDest,
        travelDate: DateTime(2026, 11, 28),
        bookerName: 'Azhar Samawwal',
        bookerEmail: 'samawwalazhar@gmail.com',
        bookerPhone: '085738686279',
        passengerName: 'Azhar Samawwal',
        passengerNik: '3514062607090001',
        selectedSeat: 'EKS-2 / 1D',
        seatSide: 'Jendela',
        totalAmount: 480000,
      ),
    );
  });

  testWidgets('TransactionStatusScreen renders with zero RenderFlex overflow at 375x667', (
    tester,
  ) async {
    await pumpAtIphoneSeAndCheckZeroErrors(
      tester,
      TransactionStatusScreen(
        booking: sampleBooking,
        transactionNumber: 'TRX-1795796096123',
        paymentMethod: 'QRIS Instant',
        paidAmount: 480000,
        seatNumber: 'EKS-2 / 1D',
        passengerName: 'Azhar Samawwal',
        passengerNik: '3514062607090001',
      ),
    );
  });

  testWidgets('ETicketBoardingPassScreen renders with zero RenderFlex overflow at 375x667', (
    tester,
  ) async {
    await pumpAtIphoneSeAndCheckZeroErrors(
      tester,
      ETicketBoardingPassScreen(
        booking: sampleBooking,
        passengerName: 'Azhar Samawwal',
        passengerNik: '3514062607090001',
        seatNumber: 'EKS-2 / 1D',
      ),
    );
  });

  testWidgets('ProfileScreen renders with zero ListTile/overflow errors at 375x667', (
    tester,
  ) async {
    await pumpAtIphoneSeAndCheckZeroErrors(
      tester,
      const ProfileScreen(),
    );
  });

  testWidgets('DashboardScreen renders with active ticket and zero overflow at 375x667', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'tka_user_name': 'Azhar Samawwal',
      'tka_user_email': 'samawwalazhar@gmail.com',
      'tka_user_phone': '085738686279',
      'tka_bookings_cache_samawwalazhar@gmail.com': jsonEncode([
        sampleBooking.toMap(),
      ]),
    });

    await pumpAtIphoneSeAndCheckZeroErrors(
      tester,
      const DashboardScreen(userName: 'Azhar Samawwal'),
    );
  });

  testWidgets('OrdersScreen renders with zero ListTile/overflow errors at 375x667', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'tka_user_name': 'Azhar Samawwal',
      'tka_user_email': 'samawwalazhar@gmail.com',
      'tka_bookings_cache_samawwalazhar@gmail.com': jsonEncode([
        sampleBooking.toMap(),
      ]),
    });

    await pumpAtIphoneSeAndCheckZeroErrors(
      tester,
      const OrdersScreen(),
    );
  });

  testWidgets('MyTicketsScreen renders with zero ListTile/overflow errors at 375x667', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'tka_user_name': 'Azhar Samawwal',
      'tka_user_email': 'samawwalazhar@gmail.com',
      'tka_bookings_cache_samawwalazhar@gmail.com': jsonEncode([
        sampleBooking.toMap(),
      ]),
    });

    await pumpAtIphoneSeAndCheckZeroErrors(
      tester,
      const MyTicketsScreen(),
    );
  });

  testWidgets('AntarKotaScreen renders with zero ListTile/overflow errors at 375x667', (
    tester,
  ) async {
    await pumpAtIphoneSeAndCheckZeroErrors(
      tester,
      const AntarKotaScreen(),
    );
  });
}

