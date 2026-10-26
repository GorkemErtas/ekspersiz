import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/workspace/workspace_session.dart';
import 'package:mobile/core/workspace/workspace_switcher.dart';
import 'package:mobile/features/auth/models/business_account.dart';
import 'package:mobile/features/home/screens/main_shell.dart';
import 'package:mobile/features/home/screens/home_screen.dart';
import 'package:mobile/features/billing/screens/subscription_screen.dart';

import '../billing/screens/subscription_screen_test.dart'
    show FakeBillingService;

import '../../support/ui_mock_api.dart';
import '../../support/ui_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(installOfflineTestFonts);
  setUp(initializeUiSession);
  tearDown(WorkspaceSession.clear);

  for (final brightness in Brightness.values) {
    testWidgets(
      'personal/company/personal replaces cached screens: $brightness',
      (tester) async {
        await setUiSize(tester, const Size(320, 700));
        tester.view.padding = const FakeViewPadding(top: 24);
        addTearDown(tester.view.resetPadding);
        await WorkspaceSession.initialize(
          userId: 1,
          businessId: 7,
          companyName: 'Test Şirketi',
          role: 'MEMBER',
        );
        await WorkspaceSession.select(WorkspaceType.personal);
        final calls = <String>[];
        await http.runWithClient(
          () async {
            await tester.pumpWidget(
              uiTestApp(
                brightness: brightness,
                textScale: 2,
                reduceMotion: true,
                home: const MainShell(
                  userId: 1,
                  fullName: 'Test User',
                  email: 'user@example.com',
                  subscriptionPlan: 'FREE',
                  businessAccount: BusinessAccount(
                    id: 7,
                    companyName: 'Test Şirketi',
                    role: 'MEMBER',
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: 'initial shell');
            expect(
              MediaQuery.paddingOf(tester.element(find.byType(HomeScreen))).top,
              0,
              reason: 'The workspace header already consumes the top safe area',
            );
            expect(find.byKey(const Key('workspace-switcher')), findsOneWidget);
            expect(
              calls.where((c) => c.startsWith('BUSINESS')),
              isEmpty,
              reason: 'Do not prefetch an unused workspace',
            );
            final personalScreen = tester.state(find.byType(HomeScreen));
            await tester.tap(find.byKey(const Key('workspace-switcher')));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: 'workspace sheet');
            await tester.tap(find.text('Test Şirketi').last);
            await tester.pumpAndSettle();
            expect(WorkspaceSession.state.value!.isBusiness, isTrue);
            expect(
              tester.state(find.byType(HomeScreen)),
              isNot(same(personalScreen)),
            );
            expect(calls, contains('BUSINESS /api/v1/vehicles'));

            final companyScreen = tester.state(find.byType(HomeScreen));
            await tester.tap(find.byKey(const Key('workspace-switcher')));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Kişisel Hesap').last);
            await tester.pumpAndSettle();
            expect(WorkspaceSession.state.value!.isBusiness, isFalse);
            expect(
              tester.state(find.byType(HomeScreen)),
              isNot(same(companyScreen)),
            );
            expect(
              calls.where((c) => c == 'PERSONAL /api/v1/vehicles').length,
              2,
            );
            expect(
              calls.any((c) => c.contains('analyze') || c.contains('/chat')),
              isFalse,
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          },
          () => MockClient((request) async {
            final workspace = request.headers['X-Workspace'];
            calls.add('$workspace ${request.url.path}');
            final Object body;
            if (request.url.path.endsWith('/workspace')) {
              body = {
                'type': workspace,
                'userId': 1,
                'businessId': workspace == 'BUSINESS' ? 7 : null,
              };
            } else if (request.url.path.endsWith('/vehicles') ||
                request.url.path.endsWith('/inspections')) {
              body = [];
            } else if (request.url.path.endsWith('/unread-count')) {
              body = {'unreadCount': 0};
            } else {
              body = {};
            }
            return http.Response(
              jsonEncode(body),
              200,
              headers: {
                'content-type': 'application/json',
                'x-workspace': ?workspace,
              },
            );
          }),
        );
      },
    );
  }

  testWidgets('nonmembers see no workspace selection', (tester) async {
    await WorkspaceSession.initialize(userId: 1);
    await tester.pumpWidget(
      uiTestApp(home: const Scaffold(body: WorkspaceSwitcher())),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('workspace-switcher')), findsNothing);
  });

  testWidgets(
    'new company metadata preserves setup route; selection and role revocation close it',
    (tester) async {
      await WorkspaceSession.initialize(userId: 1);
      await http.runWithClient(() async {
        await tester.pumpWidget(
          uiTestApp(
            home: const MainShell(
              userId: 1,
              fullName: 'Test',
              email: 'test@example.com',
              subscriptionPlan: 'FREE',
            ),
          ),
        );
        await tester.pumpAndSettle();
        void openSetup() =>
            Navigator.of(tester.element(find.byType(HomeScreen)))
                .push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('setup route')),
                  ),
                )
                .ignore();
        openSetup();
        await tester.pumpAndSettle();
        await WorkspaceSession.initialize(
          userId: 1,
          businessId: 7,
          companyName: 'New Company',
          role: 'OWNER',
          subscriptionPlan: 'BUSINESS',
        );
        await tester.pumpAndSettle();
        expect(find.text('setup route'), findsOneWidget);
        await WorkspaceSession.select(WorkspaceType.business);
        await tester.pumpAndSettle();
        expect(find.text('setup route'), findsNothing);
        expect(
          tester.widget<HomeScreen>(find.byType(HomeScreen)).subscriptionPlan,
          'BUSINESS',
        );
        openSetup();
        await tester.pumpAndSettle();
        await WorkspaceSession.initialize(
          userId: 1,
          businessId: 7,
          companyName: 'New Company',
          role: 'MEMBER',
          subscriptionPlan: 'FREE',
        );
        await tester.pumpAndSettle();
        expect(find.text('setup route'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }, uiMockClient);
    },
  );

  testWidgets(
    'credit screen follows personal selection even when opened from company management',
    (tester) async {
      await WorkspaceSession.initialize(
        userId: 1,
        businessId: 7,
        companyName: 'Company',
        role: 'MEMBER',
      );
      await WorkspaceSession.select(WorkspaceType.personal);
      await tester.pumpWidget(
        uiTestApp(
          home: SubscriptionScreen(
            billingService: FakeBillingService(company: true),
            preferCompany: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kişisel bakiyeniz'), findsOneWidget);
      expect(find.text('3 analiz kredisi'), findsOneWidget);
      expect(find.text('Şirket'), findsNothing);
      expect(find.text('Satın al'), findsWidgets);
    },
  );

  testWidgets(
    'company member sees shared credits without a separate account selector',
    (tester) async {
      await WorkspaceSession.initialize(
        userId: 1,
        businessId: 7,
        companyName: 'Company',
        role: 'MEMBER',
      );
      await tester.pumpWidget(
        uiTestApp(
          home: SubscriptionScreen(
            billingService: FakeBillingService(company: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Şirketin ortak bakiyesi'), findsOneWidget);
      expect(find.text('99 analiz kredisi'), findsOneWidget);
      expect(find.text('Kişisel'), findsNothing);
      expect(find.text('Satın al'), findsNothing);
    },
  );

  testWidgets('missing company balance never falls back to personal credits', (
    tester,
  ) async {
    await WorkspaceSession.initialize(
      userId: 1,
      businessId: 7,
      companyName: 'Company',
      role: 'MEMBER',
    );
    await tester.pumpWidget(
      uiTestApp(home: SubscriptionScreen(billingService: FakeBillingService())),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Seçili çalışma alanının bakiyesi alınamadı.'),
      findsOneWidget,
    );
    expect(find.text('3 analiz kredisi'), findsNothing);
  });
}
