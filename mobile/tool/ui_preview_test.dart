import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/features/home/screens/main_shell.dart';
import 'package:mobile/features/auth/screens/login_screen.dart';
import 'package:mobile/features/billing/screens/subscription_screen.dart';
import 'package:mobile/features/inspection/screens/upload_damage_image_screen.dart';
import 'package:mobile/features/profile/screens/profile_screen.dart';
import 'package:mobile/features/vehicle/screens/reminder_form_screen.dart';
import 'package:mobile/features/vehicle/models/vehicle.dart';

import '../test/features/billing/screens/subscription_screen_test.dart'
    as billing;
import '../test/features/inspection/screens/inspection_result_screen_test.dart'
    as inspection;
import '../test/support/ui_test_app.dart';
import '../test/support/ui_mock_api.dart';

// Opt-in review artifacts; no screenshots are written by the regular test suite.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('CAPTURE_UI')) return;
  setUpAll(installOfflineTestFonts);
  setUp(initializeUiSession);

  for (final brightness in Brightness.values) {
    for (final name in [
      'login',
      'profile',
      'photo',
      'plans',
      'reminder',
      'dashboard',
      'dashboard-tablet',
    ]) {
      testWidgets('capture $name ${brightness.name}', (tester) async {
        await http.runWithClient(() async {
          await setUiSize(
            tester,
            name == 'dashboard-tablet'
                ? const Size(1024, 768)
                : const Size(390, 844),
          );
          final Widget screen = switch (name) {
            'dashboard' || 'dashboard-tablet' => const MainShell(
              fullName: 'Deniz Yılmaz',
              email: 'deniz@example.com',
              subscriptionPlan: 'PLUS',
            ),
            'login' => const LoginScreen(),
            'profile' => const ProfileScreen(
              fullName: 'Deniz Yılmaz',
              email: 'deniz@example.com',
              subscriptionPlan: 'PLUS',
            ),
            'photo' => UploadDamageImageScreen(
              inspection: inspection.minorResult(),
            ),
            'plans' => SubscriptionScreen(
              billingService: billing.FakeBillingService(
                storeConfigured: false,
              ),
              quotaService: billing.FakeQuotaService(),
            ),
            _ => const ReminderFormScreen(
              vehicle: Vehicle(
                id: 1,
                plate: '34 ABC 123',
                brand: 'Honda',
                model: 'Civic',
                modelYear: 2024,
                mileage: 50000,
                primaryVehicle: true,
              ),
            ),
          };
          final boundaryKey = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundaryKey,
              child: uiTestApp(
                home: screen,
                brightness: brightness,
                reduceMotion: true,
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (name == 'login') {
            await tester.runAsync(
              () => precacheImage(
                const AssetImage('assets/images/ekspersiz_logo.png'),
                boundaryKey.currentContext!,
              ),
            );
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final directory = Directory('build/ui-previews')
                ..createSync(recursive: true);
              File(
                '${directory.path}/$name-${brightness.name}.png',
              ).writeAsBytesSync(bytes!.buffer.asUint8List());
            } finally {
              image.dispose();
            }
          });
        }, uiMockClient);
      });
    }
  }
}
