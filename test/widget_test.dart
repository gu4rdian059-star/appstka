import 'package:flutter_test/flutter_test.dart';
import 'package:appstka/main.dart';

void main() {
  testWidgets('Splash screen renders animated title and subtitle', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(seconds: 6));

    expect(find.text('Tiket Kereta Api'), findsOneWidget);
    expect(find.textContaining('Pemesanan tiket kereta'), findsOneWidget);
  });
}
