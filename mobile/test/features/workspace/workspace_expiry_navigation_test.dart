import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/workspace/workspace_session.dart';
import 'package:mobile/core/workspace/workspace_switcher.dart';
import 'package:mobile/features/auth/services/auth_service.dart';
import 'package:mobile/features/auth/models/business_account.dart';
import 'package:mobile/features/billing/screens/subscription_screen.dart';
import 'package:mobile/features/home/screens/main_shell.dart';
import 'package:mobile/features/profile/screens/profile_screen.dart';

import '../../core/workspace/workspace_access_test.dart' show profile, reply;
import '../../support/ui_mock_api.dart';
import '../../support/ui_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(installOfflineTestFonts);
  setUp(initializeUiSession);
  tearDown(WorkspaceSession.clear);

  testWidgets(
    'rebuilding shell from a cached active membership cannot restore Business permission',
    (tester) async {
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            uiTestApp(
              home: const MainShell(
                userId: 1,
                fullName: 'Tester',
                email: 'test@example.com',
                subscriptionPlan: 'FREE',
                businessAccount: BusinessAccount(
                  id: 7,
                  companyName: 'Company',
                  role: 'MEMBER',
                  workspaceAvailable: true,
                  workspaceAccessStatus: 'ACTIVE',
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(WorkspaceSession.state.value!.businessId, 7);
          expect(WorkspaceSession.state.value!.businessAvailable, isFalse);
          expect(WorkspaceSession.state.value!.isBusiness, isFalse);
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient((request) async {
          expect(request.headers['X-Workspace'], 'PERSONAL');
          if (request.url.path.endsWith('/unread-count')) {
            return reply(request, {'unreadCount': 0});
          }
          return reply(request, []);
        }),
      );
    },
  );

  for (final role in ['OWNER', 'MEMBER']) {
    testWidgets(
      'expired $role: Personal → Profile → credits → back repeated without restoring Business access',
      (tester) async {
        final requests = <String>[];
        await http.runWithClient(
          () async {
            final user = await const AuthService().getCurrentUser();
            await tester.pumpWidget(
              uiTestApp(
                home: MainShell(
                  userId: user.id,
                  fullName: user.fullName,
                  email: user.email,
                  subscriptionPlan: user.subscriptionPlan,
                  businessAccount: user.businessAccount,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.byType(WorkspaceSwitcher), findsOneWidget);
            await tester.tap(find.text('Profil').last);
            await tester.pumpAndSettle();
            expect(find.byType(ProfileScreen), findsOneWidget);
            for (int trip = 0; trip < 3; trip++) {
              await tester.scrollUntilVisible(
                find.text('Krediler ve Paketler'),
                180,
                scrollable: find
                    .descendant(
                      of: find.byType(ProfileScreen),
                      matching: find.byType(Scrollable),
                    )
                    .first,
              );
              await tester.ensureVisible(find.text('Krediler ve Paketler'));
              await tester.tap(find.text('Krediler ve Paketler'));
              await tester.pumpAndSettle();
              expect(find.byType(SubscriptionScreen), findsOneWidget);
              expect(find.text('Kişisel bakiyeniz'), findsOneWidget);
              await tester.pageBack();
              await tester.pumpAndSettle();
              expect(WorkspaceSession.state.value!.businessId, 7);
              expect(WorkspaceSession.state.value!.role, role);
              expect(WorkspaceSession.state.value!.businessAvailable, isFalse);
              expect(WorkspaceSession.state.value!.isBusiness, isFalse);
              await tester.tap(find.byKey(const Key('workspace-switcher')));
              await tester.pumpAndSettle();
              final company = find.widgetWithText(ListTile, 'Company');
              expect(tester.widget<ListTile>(company).enabled, isFalse);
              expect(tester.widget<ListTile>(company).onTap, isNull);
              expect(find.textContaining('aboneliği sona erdi'), findsWidgets);
              Navigator.of(tester.element(company)).pop();
              await tester.pumpAndSettle();
            }
            expect(
              requests.where((path) => path.endsWith('/auth/me')),
              hasLength(4),
            );
            expect(
              requests.any(
                (path) =>
                    path.endsWith('/workspace') ||
                    path.contains('/billing/sync'),
              ),
              isFalse,
            );
            expect(requests.any((path) => path.contains('BUSINESS')), isFalse);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          },
          () => MockClient((request) async {
            final path = request.url.path;
            requests.add(path);
            expect(request.headers['X-Workspace'], isNot('BUSINESS'));
            if (path.endsWith('/auth/me')) {
              return reply(
                request,
                profile(access: 'SUBSCRIPTION_EXPIRED', role: role),
              );
            }
            if (path.endsWith('/billing')) {
              return reply(request, {
                'status': {
                  'billingCustomerId': 'canonical',
                  'currentPlan': 'FREE',
                  'status': 'EXPIRED',
                },
                'plans': [],
              });
            }
            if (path.endsWith('/credits')) {
              return reply(request, {
                'personal': {
                  'id': 'user:1',
                  'owner': true,
                  'canPurchase': true,
                  'usedSlots': 1,
                  'totalSlots': 1,
                  'balances': {
                    'ANALYSIS': {'available': 5},
                    'ASSISTANT': {'available': 2},
                    'SLOT': {'available': 0},
                  },
                },
                'products': [],
              });
            }
            if (path.endsWith('/vehicles') || path.endsWith('/inspections')) {
              return reply(request, []);
            }
            if (path.endsWith('/unread-count')) {
              return reply(request, {'unreadCount': 0});
            }
            throw StateError(
              'Unexpected ${request.method} $path ${jsonEncode(request.headers)}',
            );
          }),
        );
      },
    );
  }
}
