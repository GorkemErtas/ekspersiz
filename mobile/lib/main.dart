import 'package:flutter/material.dart';

import 'core/ads/ad_service.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_theme_controller.dart';
import 'features/auth/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdService.initialize();
  await PushNotificationService.instance.initializeFirebase();
  await AppThemeController.instance.initialize();
  runApp(const VehicleInspectorApp());
}

class VehicleInspectorApp extends StatelessWidget {
  const VehicleInspectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) => MaterialApp(
        title: 'EksperSiz',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: AppThemeController.instance.themeMode,
        themeAnimationDuration: const Duration(milliseconds: 420),
        themeAnimationCurve: Curves.easeInOutCubic,
        home: const SplashScreen(),
      ),
    );
  }
}
