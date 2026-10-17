import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/core/widgets/app_navigation_bar.dart';
import 'package:mobile/features/ai_assistant/screens/ai_assistant_screen.dart';
import 'package:mobile/features/home/screens/main_shell.dart';
import 'package:mobile/features/vehicle/models/vehicle.dart';
import 'package:mobile/features/vehicle/screens/vehicle_detail_screen.dart';

import '../support/ui_mock_api.dart';
import '../support/ui_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(installOfflineTestFonts);
  setUp(
    () =>
        FlutterSecureStorage.setMockInitialValues({'access_token': 'ui-test'}),
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'dashboard, vehicle tab and notification navigation at large text, $brightness',
      (tester) async {
        await setUiSize(tester, const Size(320, 640));
        await http.runWithClient(() async {
          await tester.pumpWidget(
            uiTestApp(
              brightness: brightness,
              textScale: 2,
              reduceMotion: true,
              home: const MainShell(
                fullName: 'Deniz Yılmaz',
                email: 'deniz@example.com',
                subscriptionPlan: 'PLUS',
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('Honda Civic'),
            180,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('Honda Civic'), findsOneWidget);
          expect(tester.takeException(), isNull);
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(Icons.notifications_none_rounded).first);
          await tester.pumpAndSettle();
          expect(find.text('Henüz bildiriminiz yok.'), findsOneWidget);
          await tester.pageBack();
          await tester.pumpAndSettle();
          final vehicleTab = find
              .descendant(
                of: find.byType(AppNavigationBar),
                matching: find.byType(NavigationDestination),
              )
              .at(1);
          await tester.tap(vehicleTab);
          await tester.pumpAndSettle();
          expect(find.text('Garajınız'), findsOneWidget);
          expect(find.text('Honda Civic'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }, uiMockClient);
      },
    );

    testWidgets(
      'vehicle detail actions and data fit narrow screens, $brightness',
      (tester) async {
        await setUiSize(tester, const Size(320, 640));
        await http.runWithClient(() async {
          await tester.pumpWidget(
            uiTestApp(
              brightness: brightness,
              textScale: 2,
              reduceMotion: true,
              home: VehicleDetailScreen(
                vehicle: Vehicle.fromJson(uiVehicleJson),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Araç takip durumu'), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text('Henüz geçmiş kaydı yok.'),
            180,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('Henüz geçmiş kaydı yok.'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }, uiMockClient);
      },
    );

    testWidgets(
      'chat preserves message and prevents repeat sends with keyboard open, $brightness',
      (tester) async {
        await setUiSize(tester, const Size(320, 640));
        final reply = Completer<http.Response>();
        var sends = 0;
        await http.runWithClient(
          () async {
            await tester.pumpWidget(
              uiTestApp(
                brightness: brightness,
                textScale: 2,
                keyboardInset: 260,
                reduceMotion: true,
                home: const AiAssistantScreen(),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.textContaining('kalan soru hakkı'), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.enterText(
              find.byType(TextField),
              'Lastiklerimi ne zaman kontrol etmeliyim?',
            );
            await tester.tap(find.byTooltip('Gönder'));
            await tester.pump(const Duration(milliseconds: 300));
            await tester.tap(find.byTooltip('Gönder'));
            await tester.pump();
            expect(sends, 1);
            reply.complete(
              uiJsonResponse({
                'intent': 'GENERAL',
                'answer':
                    'Lastik basıncını ve diş derinliğini düzenli olarak kontrol edin.',
                'quotaConsumed': true,
                'remainingToday': 9,
                'toolsUsed': [],
                'sources': [
                  {'name': 'Araç kullanım kılavuzu'},
                ],
              }),
            );
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              find.textContaining('Lastik basıncını'),
              120,
              scrollable: find.byType(Scrollable).at(1),
            );
            expect(find.textContaining('Lastik basıncını'), findsOneWidget);
            await tester.scrollUntilVisible(
              find.text('Lastiklerimi ne zaman kontrol etmeliyim?'),
              -120,
              scrollable: find.byType(Scrollable).at(1),
            );
            expect(
              find.text('Lastiklerimi ne zaman kontrol etmeliyim?'),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          },
          () => uiMockClient(
            onChat: (_) {
              sends++;
              return reply.future;
            },
          ),
        );
      },
    );
  }
}
