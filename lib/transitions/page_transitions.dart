import 'package:flutter/material.dart';

/// Jenis animasi transisi halaman yang elegan dan modern
enum AppPageTransitionType {
  /// Geser halus dari bawah ke atas dengan efek fade & scale halus (cocok untuk menu modal, filter, layanan)
  slideUp,

  /// Geser halus dari kanan ke kiri dengan efek fade & parallax (cocok untuk alur pemesanan bertahap)
  slideRight,

  /// Efek fade mendalam yang mulus
  fade,

  /// Efek zoom halus (scale up dari 90% ke 100% dengan fade)
  zoom,
}

/// Helper transisi halaman kustom dengan kurva easing yang sangat halus (mirip iOS & Material 3)
class AppPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final AppPageTransitionType transitionType;
  final Duration customDuration;

  AppPageRoute({
    required this.page,
    this.transitionType = AppPageTransitionType.slideRight,
    this.customDuration = const Duration(milliseconds: 320),
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: customDuration,
          reverseTransitionDuration: const Duration(milliseconds: 260),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Kurva akselerasi modern (Cubic)
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.fastEaseInToSlowEaseOut,
              reverseCurve: Curves.easeInCubic,
            );

            switch (transitionType) {
              case AppPageTransitionType.slideRight:
                // Geser dari kanan dengan sedikit scaling dan fade
                final slideAnim = Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(curvedAnimation);

                final fadeAnim = Tween<double>(
                  begin: 0.15,
                  end: 1.0,
                ).animate(curvedAnimation);

                return SlideTransition(
                  position: slideAnim,
                  child: FadeTransition(
                    opacity: fadeAnim,
                    child: child,
                  ),
                );

              case AppPageTransitionType.slideUp:
                // Geser elegan dari bawah dengan subtle scale dan fade
                final slideAnim = Tween<Offset>(
                  begin: const Offset(0.0, 0.12),
                  end: Offset.zero,
                ).animate(curvedAnimation);

                final scaleAnim = Tween<double>(
                  begin: 0.96,
                  end: 1.0,
                ).animate(curvedAnimation);

                final fadeAnim = Tween<double>(
                  begin: 0.0,
                  end: 1.0,
                ).animate(curvedAnimation);

                return SlideTransition(
                  position: slideAnim,
                  child: ScaleTransition(
                    scale: scaleAnim,
                    child: FadeTransition(
                      opacity: fadeAnim,
                      child: child,
                    ),
                  ),
                );

              case AppPageTransitionType.zoom:
                final scaleAnim = Tween<double>(
                  begin: 0.90,
                  end: 1.0,
                ).animate(curvedAnimation);

                final fadeAnim = Tween<double>(
                  begin: 0.0,
                  end: 1.0,
                ).animate(curvedAnimation);

                return ScaleTransition(
                  scale: scaleAnim,
                  child: FadeTransition(
                    opacity: fadeAnim,
                    child: child,
                  ),
                );

              case AppPageTransitionType.fade:
                return FadeTransition(
                  opacity: curvedAnimation,
                  child: child,
                );
            }
          },
        );

  /// Navigasi cepat dengan transisi geser kanan (booking flow)
  static Future<T?> push<T>(
    BuildContext context,
    Widget page, {
    AppPageTransitionType type = AppPageTransitionType.slideRight,
  }) {
    return Navigator.of(context).push<T>(
      AppPageRoute<T>(page: page, transitionType: type),
    );
  }

  /// Navigasi cepat menggantikan halaman saat ini
  static Future<T?> pushReplacement<T, TO>(
    BuildContext context,
    Widget page, {
    AppPageTransitionType type = AppPageTransitionType.slideRight,
  }) {
    return Navigator.of(context).pushReplacement<T, TO>(
      AppPageRoute<T>(page: page, transitionType: type),
    );
  }

  /// Navigasi untuk menu layanan (Antar Kota, Lokal, dll.) dengan slide up halus
  static Future<T?> pushMenu<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push<T>(
      AppPageRoute<T>(
        page: page,
        transitionType: AppPageTransitionType.slideUp,
        customDuration: const Duration(milliseconds: 350),
      ),
    );
  }
}

