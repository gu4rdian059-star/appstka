import 'package:flutter/material.dart';
import 'config/app_env.dart';
import 'dashboard/dashboard_screen.dart';
import 'services/indonesia_time_service.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppEnv.load();
  await IndonesiaTimeService.initialize();
  await SupabaseService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TKA - Live Tracking & Tiket Kereta Api',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF062056),
          primary: const Color(0xFF062056),
          secondary: const Color(0xFFF26716),
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      // A. Live Map sebagai halaman utama aplikasi (Tab 0 di DashboardScreen)
      home: const DashboardScreen(initialTabIndex: 0),
    );
  }
}
