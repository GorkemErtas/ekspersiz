import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/auth/models/business_account.dart';
import 'package:mobile/features/business/screens/business_management_screen.dart';
import 'package:mobile/features/inspection/screens/create_inspection_screen.dart';
import 'package:mobile/features/inspection/screens/inspection_history_screen.dart';
import 'package:mobile/features/inspection/services/damage_analysis_availability.dart';
import 'package:mobile/features/notification/screens/notification_center_screen.dart';

import '../support/ui_mock_api.dart';
import '../support/ui_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(installOfflineTestFonts);
  setUp(initializeUiSession);

  testWidgets(
    'new analysis explains unavailability without loading quota or vehicles',
    (tester) async {
      var requests = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            uiTestApp(
              home: const CreateInspectionScreen(),
              brightness: Brightness.light,
              textScale: 1,
              reduceMotion: true,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(DamageAnalysisAvailability.message), findsOneWidget);
          expect(requests, 0);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          requests++;
          return uiJsonResponse({});
        }),
      );
    },
  );

  for (final brightness in Brightness.values) {
    for (final scenario in [
      (size: const Size(320, 640), scale: 2.0),
      (size: const Size(390, 844), scale: 1.0),
      (size: const Size(430, 932), scale: 1.5),
    ]) {
      testWidgets('compact lists and creation forms: $brightness $scenario', (
        tester,
      ) async {
        await setUiSize(tester, scenario.size);
        await http.runWithClient(
          () async {
            for (final screen in <Widget>[
              const CreateInspectionScreen(),
              const InspectionHistoryScreen(),
              const NotificationCenterScreen(),
              const BusinessManagementScreen(
                subscriptionPlan: 'BUSINESS',
                businessAccount: BusinessAccount(
                  id: 1,
                  role: 'OWNER',
                  companyName:
                      'Uzun İsimli Otomotiv Bakım ve Ekspertiz Şirketi',
                ),
              ),
            ]) {
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
                await tester.drag(scrollable, const Offset(0, -300));
                await tester.pumpAndSettle();
                expect(
                  tester.takeException(),
                  isNull,
                  reason: '${screen.runtimeType} scroll $step',
                );
              }
            }
            await tester.pumpWidget(const SizedBox());
          },
          () => MockClient((request) async {
            final path = request.url.path;
            if (path.endsWith('/analysis-quota')) {
              return uiJsonResponse({
                'plan': 'FREE',
                'remaining': 5,
                'purchasedCredits': 5,
              });
            }
            if (path.endsWith('/credits')) {
              return uiJsonResponse({
                'personal': {
                  'canPurchase': true,
                  'usedSlots': 1,
                  'totalSlots': 2,
                  'balances': {
                    'ANALYSIS': {'available': 5},
                    'ASSISTANT': {'available': 10},
                  },
                },
                'products': [],
              });
            }
            if (path.endsWith('/vehicles')) {
              return uiJsonResponse([uiVehicleJson]);
            }
            if (path.endsWith('/business-members')) {
              return uiJsonResponse([
                {
                  'id': 20,
                  'userId': 2,
                  'fullName': 'Uzun İsimli Şirket Çalışanı',
                  'email': 'uzun.calisan.adresi@example.com',
                  'role': 'MEMBER',
                },
              ]);
            }
            if (path.endsWith('/notifications')) {
              return uiJsonResponse([
                for (var i = 1; i <= 3; i++)
                  {
                    'id': i,
                    'notificationType': 'MAINTENANCE',
                    'severity': 'WARNING',
                    'title': 'Araç bakım ve muayene tarihinizi kontrol edin',
                    'body':
                        'Bakım randevunuzu ve yaklaşan zorunlu işlemlerinizi aracınızın geçmişinden takip edebilirsiniz.',
                    'read': true,
                    'createdAt': '2026-10-17T12:00:00',
                  },
              ]);
            }
            if (path.endsWith('/inspections')) {
              return uiJsonResponse([
                {
                  ...uiVehicleJson,
                  'id': 4,
                  'vehicleId': 1,
                  'vehiclePlate': '34 ABC 123',
                  'vehicleBrand': 'Honda',
                  'vehicleModel': 'Civic',
                  'status': 'COMPLETED',
                  'reportStatus': 'COMPLETED',
                  'damageSeverity': 'MINOR',
                  'damageTypes': ['SCRATCH'],
                  'affectedParts': ['FRONT_BUMPER'],
                  'locationCity': 'İstanbul',
                  'createdAt': '2026-10-17T12:00:00',
                },
              ]);
            }
            throw StateError('Unexpected layout test request: ${request.url}');
          }),
        );
      });
    }
  }
}
