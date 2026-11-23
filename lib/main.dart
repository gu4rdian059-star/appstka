import 'dart:ui';
import 'package:flutter/material.dart';

import 'config/app_env.dart';
import 'services/indonesia_time_service.dart';
import 'services/supabase_service.dart';
import 'splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppEnv.load();
  await IndonesiaTimeService.initialize();
  await SupabaseService.initialize();
  runApp(const MyApp());
}

/// Scroll behavior yang mengaktifkan drag dengan mouse, touch, trackpad, dan stylus di seluruh platform (Windows, Web, Mobile)
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TKA - Tiket Kereta Api',
      debugShowCheckedModeBanner: false,
      scrollBehavior: AppScrollBehavior(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF062056),
          primary: const Color(0xFF062056),
          secondary: const Color(0xFFF26716),
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
