import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'config/app_env.dart';
import 'dashboard/dashboard_screen.dart';
import 'services/indonesia_time_service.dart';
import 'services/supabase_service.dart';
import 'splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppEnv.load();
  // Pada Web, muat MapLibre GL JS self-hosted dari Secure API Gateway (0ms lokal, bebas blokir CSP/CDN unpkg).
  // maplibre-gl.css sudah dimuat langsung lewat <link rel="stylesheet"> di web/index.html sehingga bebas warning Chrome unused-preload.
  if (kIsWeb) {
    MapLibreMap.webLibrarySource = MapLibreJsSource.urls(
      scriptUrl: '${AppEnv.apiGatewayUrl}/api/map/lib/maplibre-gl.mjs',
      timeout: const Duration(seconds: 15),
    );
  }
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
    final oauthUser = SupabaseService.initialOAuthUserName;

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
      // Jika kembali dari callback Google OAuth (?code=...), langsung masuk ke Beranda (DashboardScreen)
      home: oauthUser != null
          ? DashboardScreen(userName: oauthUser)
          : const SplashScreen(),
    );
  }
}
