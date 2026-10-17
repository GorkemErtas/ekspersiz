import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/widgets/primary_button.dart';
import 'package:mobile/features/auth/screens/login_screen.dart';
import 'package:mobile/features/auth/screens/register_screen.dart';
import 'package:mobile/features/billing/screens/subscription_screen.dart';
import 'package:mobile/features/inspection/screens/inspection_result_screen.dart';
import 'package:mobile/features/inspection/screens/upload_damage_image_screen.dart';
import 'package:mobile/features/inspection/services/inspection_service.dart';
import 'package:mobile/features/inspection/models/damage_inspection.dart';
import 'package:mobile/features/profile/screens/profile_screen.dart';
import 'package:mobile/features/vehicle/models/vehicle.dart';
import 'package:mobile/features/vehicle/screens/maintenance_form_screen.dart';
import 'package:mobile/features/vehicle/screens/reminder_form_screen.dart';

import '../support/ui_test_app.dart';
import 'billing/screens/subscription_screen_test.dart' as billing;
import 'inspection/screens/inspection_result_screen_test.dart' as inspection;

const _vehicle = Vehicle(
  id: 1,
  plate: '34 ABC 123',
  brand: 'Honda',
  model: 'Civic',
  modelYear: 2024,
  mileage: 50000,
  primaryVehicle: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(installOfflineTestFonts);

  for (final brightness in Brightness.values) {
    for (final scenario in [
      (size: const Size(320, 640), scale: 2.0),
      (size: const Size(844, 390), scale: 1.5),
      (size: const Size(1024, 768), scale: 1.0),
    ]) {
      testWidgets('forms and account screens: $brightness, $scenario', (
        tester,
      ) async {
        await setUiSize(tester, scenario.size);
        final screens = <Widget>[
          const LoginScreen(),
          const RegisterScreen(),
          const MaintenanceFormScreen(vehicleId: 1, currentMileage: 50000),
          const ReminderFormScreen(vehicle: _vehicle),
          const ProfileScreen(
            fullName: 'Uzun İsimli Kullanıcı Hesabı',
            email: 'uzun.kullanici.adresi@example.com',
            subscriptionPlan: 'PLUS',
          ),
          SubscriptionScreen(
            billingService: billing.FakeBillingService(storeConfigured: false),
            quotaService: billing.FakeQuotaService(),
          ),
        ];
        for (final screen in screens) {
          // A fresh route tree ensures scroll state cannot leak across screens.
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(
            uiTestApp(
              home: screen,
              brightness: brightness,
              textScale: scenario.scale,
              reduceMotion: true,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${screen.runtimeType} initial layout',
          );
          final scrollable = find.byType(Scrollable).first;
          for (var step = 0; step < 12; step++) {
            await tester.drag(scrollable, const Offset(0, -350));
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '${screen.runtimeType}, scroll $step',
            );
          }
        }
      });

      testWidgets(
        'photo selection and analysis result: $brightness, $scenario',
        (tester) async {
          await setUiSize(tester, scenario.size);
          await tester.pumpWidget(
            uiTestApp(
              home: UploadDamageImageScreen(
                inspection: inspection.minorResult(),
              ),
              brightness: brightness,
              textScale: scenario.scale,
              reduceMotion: true,
            ),
          );
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.byType(PrimaryButton),
            200,
            maxScrolls: 30,
          );
          await tester.ensureVisible(find.byType(PrimaryButton));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(PrimaryButton));
          await tester.pumpAndSettle();
          expect(find.text('Fotoğraf kaynağı'), findsOneWidget);
          // Both sources remain reachable without invoking a platform picker.
          await tester.ensureVisible(find.text('Galeriden seç'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());

          final data = await rootBundle.load(
            'assets/images/ekspersiz_logo.png',
          );
          for (final result in [
            inspection.minorResult(),
            inspection.noDamageResult(),
            _detailedResult(),
          ]) {
            await tester.pumpWidget(
              uiTestApp(
                home: InspectionResultScreen(
                  inspection: result,
                  inspectionService: InspectionService(
                    apiClient: _ImageApiClient(data.buffer.asUint8List()),
                  ),
                ),
                brightness: brightness,
                textScale: scenario.scale,
                reduceMotion: true,
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: 'result header');
            await tester.scrollUntilVisible(
              find.text('Tutanak Oluştur / Görüntüle'),
              200,
              maxScrolls: 60,
            );
            await tester.ensureVisible(
              find.text('Tutanak Oluştur / Görüntüle'),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: 'result details');
            await tester.pumpWidget(const SizedBox());
          }
        },
      );
    }
  }

  testWidgets('login validation remains reachable with the keyboard open', (
    tester,
  ) async {
    await setUiSize(tester, const Size(320, 640));
    await tester.pumpWidget(
      uiTestApp(
        home: const LoginScreen(),
        textScale: 1.5,
        keyboardInset: 260,
        reduceMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(PrimaryButton),
      150,
      maxScrolls: 30,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byType(PrimaryButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(2));
    final form = tester.state<FormState>(find.byType(Form));
    expect(form.validate(), isFalse);
    expect(tester.takeException(), isNull);
  });
}

DamageInspection _detailedResult() => DamageInspection.fromJson({
  'id': 42,
  'vehicleId': 1,
  'vehiclePlate': '34 ABC 123',
  'status': 'COMPLETED',
  'reportStatus': 'COMPLETED',
  'damageSeverity': 'SEVERE',
  'damageTypes': ['CRACK'],
  'affectedParts': ['FRONT_BUMPER'],
  'repairRecommendations': [
    {
      'damageType': 'CRACK',
      'recommendedAction': 'REPLACEMENT',
      'partReplacementRequired': true,
      'affectedParts': ['FRONT_BUMPER'],
    },
  ],
  'confidenceScore': .987,
  'locationCity': 'İstanbul',
  'locationLatitude': 41.0,
  'locationLongitude': 29.0,
  'report': {
    'title': 'Ön tampon değerlendirmesi',
    'summary': 'Ön tamponda onarım gerektiren görünür hasar tespit edildi.',
    'damageDescription': 'Görünür çatlak ve yüzey deformasyonu.',
    'repairRecommendation': 'Yetkili bir serviste inceleme önerilir.',
    'estimatedMinimumPrice': 15000.0,
    'estimatedMaximumPrice': 125000.0,
    'currency': 'TRY',
    'priceInformation': 'Bölgesel tahmini fiyat aralığı.',
    'priceSourceDescription': 'Servis ve parça fiyatları değişebilir.',
    'disclaimer': 'Kesin fiyat için servis değerlendirmesi gereklidir.',
  },
});

class _ImageApiClient extends ApiClient {
  _ImageApiClient(this.bytes);
  final Uint8List bytes;
  @override
  Future<Uint8List> getBytes(String path) async => bytes;
}
