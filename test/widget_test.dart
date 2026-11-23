import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appstka/splash_screen.dart';

void main() {
  testWidgets('Splash screen renders animated title and subtitle', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(onAnimationComplete: () {}),
      ),
    );
    await tester.pump(const Duration(seconds: 6));

    expect(find.text('Tiket Kereta Api'), findsOneWidget);
    expect(find.textContaining('Pemesanan tiket kereta'), findsOneWidget);
  });
}
