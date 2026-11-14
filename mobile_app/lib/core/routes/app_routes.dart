import 'package:flutter/material.dart';
import '../../features/auth/otp_login_screen.dart';
import '../../features/auth/technician_registration_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/service_catalog_screen.dart';
import '../../features/orders/create_order_screen.dart';
import '../../features/orders/track_order_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../services/app_state_service.dart';
import '../services/auth_session.dart';

class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String registerTech = '/register-tech';
  static const String home = '/home';
  static const String createOrder = '/create-order';
  static const String trackOrder = '/track-order';

  static Route<dynamic> onGenerateRoute(
      RouteSettings settings, AuthSession session) {
    if (!AppStateService.demoMode &&
        (settings.name == registerTech ||
            settings.name == createOrder ||
            settings.name == trackOrder)) {
      return MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('خدمات')),
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child:
                  Text('هذه الخدمة قيد التجهيز. يمكنك تصفح الخدمات المتاحة.'),
            ),
          ),
        ),
        settings: settings,
      );
    }
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(
            builder: (_) => const SplashScreen(), settings: settings);
      case login:
        return MaterialPageRoute(
            builder: (_) => OtpLoginScreen(session: session),
            settings: settings);
      case registerTech:
        return MaterialPageRoute(
            builder: (_) => const TechnicianRegistrationScreen(),
            settings: settings);
      case home:
        return MaterialPageRoute(builder: (_) => _home, settings: settings);
      case createOrder:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => CreateOrderScreen(
              initialServiceName: args?['service'] as String?),
          settings: settings,
        );
      case trackOrder:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) =>
              TrackOrderScreen(orderId: args?['orderId'] as String?),
          settings: settings,
        );
      default:
        return MaterialPageRoute(builder: (_) => _home, settings: settings);
    }
  }

  static Widget get _home => AppStateService.demoMode
      ? const HomeScreen()
      : const ServiceCatalogScreen();
}
