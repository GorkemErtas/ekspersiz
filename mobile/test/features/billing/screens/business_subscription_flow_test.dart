import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/workspace/workspace_session.dart';
import 'package:mobile/features/billing/screens/subscription_screen.dart';
import 'package:mobile/features/billing/services/billing_service.dart';
import 'package:mobile/features/billing/services/revenue_cat_gateway.dart';
import 'package:mobile/features/business/screens/business_management_screen.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

const businessPackage = Package(
  'business_monthly',
  PackageType.custom,
  StoreProduct(
    'eksper_business_monthly:monthly',
    '',
    'Business',
    4999.99,
    '4.999,99 TL',
    'TRY',
  ),
  PresentedOfferingContext('credits_v1', null, null),
);

class Store extends RevenueCatGateway {
  Store(this.server);
  final Server server;
  Object? failure;
  int purchases = 0;
  @override
  Future<bool> hasActiveSubscription(String productId) async => server.paid;
  @override
  Future<bool> configure(String appUserId) async {
    expect(appUserId, 'canonical-backend-customer');
    return true;
  }

  @override
  Future<Map<String, Package>> getPackages() async => {
    'business_monthly': businessPackage,
  };
  @override
  Future<void> purchase(
    Package package, {
    String? oldProductId,
    StoreReplacementMode? replacementMode,
  }) async {
    purchases++;
    if (failure != null) throw failure!;
    server.paid = true;
  }

  @override
  Future<void> restorePurchases() async {}
}

class Server {
  bool paid = false;
  bool sandbox = false;
  bool authorizedSandbox = false;
  bool delayed = false;
  bool failCreate = false;
  bool denyWorkspace = false;
  bool failMembershipRefresh = false;
  Map<String, Object>? membership;
  int creates = 0;
  final calls = <String>[];
  final gate = Completer<void>();
  final authStarted = Completer<void>();
  bool delayAuth = false;
  bool delaySync = false;
  final syncStarted = Completer<void>();
  final syncGate = Completer<void>();
  String get plan =>
      paid && (!sandbox || authorizedSandbox) && !delayed ? 'BUSINESS' : 'FREE';
  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path.replaceFirst('/api/v1', '');
    final area = request.headers['X-Workspace'];
    calls.add('${request.method} $path $area');
    Object body;
    int status = 200;
    if (path == '/billing' || path == '/billing/sync') {
      if (delaySync && path == '/billing/sync') {
        if (!syncStarted.isCompleted) syncStarted.complete();
        await syncGate.future;
      }
      body = {
        'status': {
          'billingCustomerId': 'canonical-backend-customer',
          'currentPlan': plan,
          'productId': plan == 'BUSINESS'
              ? 'eksper_business_monthly:monthly'
              : null,
          'sandbox': sandbox && plan == 'BUSINESS',
          'verificationStatus': sandbox && paid && !authorizedSandbox
              ? 'SANDBOX_REJECTED'
              : plan == 'BUSINESS'
              ? 'VERIFIED'
              : 'NO_ACTIVE_SUBSCRIPTION',
        },
        'plans': [
          {
            'plan': 'BUSINESS',
            'title': 'Business',
            'productId': 'eksper_business_monthly',
            'packageIdentifier': 'business_monthly',
          },
        ],
      };
    } else if (path == '/credits') {
      body = {
        if (area != 'BUSINESS')
          'personal': {
            'canPurchase': true,
            'usedSlots': 1,
            'totalSlots': 2,
            'balances': {
              'ANALYSIS': {'available': 3},
            },
          },
        if (membership != null)
          'company': {
            'owner': membership!['role'] == 'OWNER',
            'usedSlots': 0,
            'totalSlots': 10,
            'balances': {
              'ANALYSIS': {'available': 100},
            },
          },
        'products': [],
      };
    } else if (path == '/auth/me') {
      if (delayAuth) {
        if (!authStarted.isCompleted) authStarted.complete();
        await gate.future;
      }
      if (failMembershipRefresh && membership != null) {
        status = 503;
        body = {'message': 'Üyelik yenilenemedi. Yeniden deneyin.'};
      } else {
        body = {
          'id': 1,
          'fullName': 'Test',
          'email': 'test@example.com',
          'subscriptionPlan': plan,
          'businessAccount': membership,
        };
      }
    } else if (path == '/business-accounts') {
      expect(plan, 'BUSINESS');
      expect(membership, isNull, reason: 'Never create a second company');
      creates++;
      if (failCreate) {
        status = 503;
        body = {'message': 'Şirket oluşturulamadı. Yeniden deneyin.'};
      } else {
        membership = {
          'id': 7,
          'companyName':
              (jsonDecode(request.body) as Map)['companyName'] as String,
          'role': 'OWNER',
        };
        body = membership!;
      }
    } else if (path == '/workspace') {
      expect(area, 'BUSINESS');
      expect(
        WorkspaceSession.state.value!.isBusiness,
        isFalse,
        reason: 'Publish selection after authorization',
      );
      if (denyWorkspace) {
        status = 403;
        body = {
          'message': 'Üyelik iptal edildi.',
          'validationErrors': {'code': 'WORKSPACE_UNAVAILABLE'},
        };
      } else {
        body = {
          'type': 'BUSINESS',
          'userId': 1,
          'businessId': membership!['id'],
        };
      }
    } else {
      throw StateError('Unexpected ${request.method} $path');
    }
    return http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json', 'x-workspace': ?area},
    );
  }
}

void main() {
  setUp(() async {
    WorkspaceSession.clear();
    FlutterSecureStorage.setMockInitialValues({'access_token': 'test-token'});
    await WorkspaceSession.initialize(userId: 1);
  });
  tearDown(WorkspaceSession.clear);

  Future<void> open(WidgetTester tester, Store store) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionScreen(
          billingService: BillingService(revenueCatGateway: store),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(
      find.text(text),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text(text).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).first);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'production purchase, sync, explicit company consent, me and authorized workspace',
    (tester) async {
      final server = Server();
      final store = Store(server);
      await http.runWithClient(() async {
        await open(tester, store);
        await tap(tester, 'Business’a geç');
        expect(find.byType(BusinessManagementScreen), findsOneWidget);
        expect(server.creates, 0);
        expect(WorkspaceSession.state.value!.isBusiness, isFalse);
        await tester.enterText(
          find.byType(TextFormField).first,
          '  Kullanıcının Şirketi  ',
        );
        await tap(tester, 'Şirketi Oluştur');
        expect(server.membership!['companyName'], 'Kullanıcının Şirketi');
        expect(WorkspaceSession.state.value!.isBusiness, isTrue);
        expect(WorkspaceSession.state.value!.role, 'OWNER');
        expect(find.text('100 analiz kredisi'), findsOneWidget);
        expect(find.text('3 analiz kredisi'), findsNothing);
        expect(store.purchases, 1);
        final create = server.calls.indexOf('POST /business-accounts PERSONAL');
        expect(
          server.calls.skip(create + 1),
          containsAllInOrder([
            'GET /auth/me PERSONAL',
            'GET /workspace BUSINESS',
          ]),
        );
        WorkspaceSession.clear();
        await WorkspaceSession.initialize(
          userId: 1,
          businessId: 7,
          role: 'OWNER',
        );
        expect(
          WorkspaceSession.state.value!.isBusiness,
          isTrue,
          reason: 'Selection survives restart',
        );
      }, () => MockClient(server.handle));
    },
  );

  testWidgets(
    'paid onboarding can be abandoned and resumed on reopen without payment',
    (tester) async {
      final server = Server();
      final store = Store(server);
      await http.runWithClient(() async {
        await open(tester, store);
        await tap(tester, 'Business’a geç');
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        await open(tester, store);
        await tap(tester, 'Şirketini oluştur');
        expect(find.byType(BusinessManagementScreen), findsOneWidget);
        expect(store.purchases, 1);
        expect(server.creates, 0);
      }, () => MockClient(server.handle));
    },
  );

  for (final role in ['OWNER', 'MEMBER']) {
    testWidgets(
      'existing $role membership is reused even if another device changed it',
      (tester) async {
        final server = Server()..paid = true;
        final store = Store(server);
        await http.runWithClient(() async {
          await open(tester, store);
          server.membership = {
            'id': 7,
            'companyName': 'Existing',
            'role': role,
          };
          await tap(tester, 'Şirketini oluştur');
          expect(WorkspaceSession.state.value!.role, role);
          expect(WorkspaceSession.state.value!.isBusiness, isTrue);
          expect(server.creates, 0);
          expect(store.purchases, 0);
        }, () => MockClient(server.handle));
      },
    );
  }

  testWidgets('sandbox store success remains personal and explains rejection', (
    tester,
  ) async {
    final server = Server()..sandbox = true;
    final store = Store(server);
    await http.runWithClient(() async {
      await open(tester, store);
      await tap(tester, 'Business’a geç');
      expect(find.textContaining('Bu test satın alımı sandbox'), findsWidgets);
      expect(find.text('Business · Abonelik aktif'), findsNothing);
      expect(find.byType(BusinessManagementScreen), findsNothing);
      expect(server.creates, 0);
      expect(WorkspaceSession.state.value!.isBusiness, isFalse);
    }, () => MockClient(server.handle));
  });

  testWidgets(
    'authorized sandbox subscription uses explicit company consent and verified workspace',
    (tester) async {
      final server = Server()
        ..sandbox = true
        ..authorizedSandbox = true;
      final store = Store(server);
      await http.runWithClient(() async {
        await open(tester, store);
        await tap(tester, 'Business’a geç');
        expect(find.byType(BusinessManagementScreen), findsOneWidget);
        expect(server.creates, 0);
        await tester.enterText(
          find.byType(TextFormField).first,
          'Isolated test company',
        );
        await tap(tester, 'Şirketi Oluştur');
        expect(server.creates, 1);
        expect(WorkspaceSession.state.value!.isBusiness, isTrue);
        expect(store.purchases, 1);
        expect(find.text('Business · Test aboneliği aktif'), findsOneWidget);
        expect(
          find.textContaining('toplam 3 analiz + 10 asistan'),
          findsOneWidget,
        );
      }, () => MockClient(server.handle));
    },
  );

  for (final failure in [
    const BillingPurchasePending(),
    const BillingPurchaseCancelled(),
  ]) {
    testWidgets('$failure never activates Business or creates a company', (
      tester,
    ) async {
      final server = Server();
      final store = Store(server)..failure = failure;
      await http.runWithClient(() async {
        await open(tester, store);
        await tap(tester, 'Business’a geç');
        expect(WorkspaceSession.state.value!.isBusiness, isFalse);
        expect(server.creates, 0);
        expect(find.byType(BusinessManagementScreen), findsNothing);
        expect(find.text('Business · Abonelik aktif'), findsNothing);
        if (failure is BillingPurchasePending) {
          expect(
            find.textContaining('Satın alma henüz doğrulanmadı'),
            findsWidgets,
          );
        }
      }, () => MockClient(server.handle));
    });
  }

  testWidgets(
    'delayed provider visibility can be checked again without paying',
    (tester) async {
      final server = Server()..delayed = true;
      final store = Store(server);
      await http.runWithClient(() async {
        await open(tester, store);
        await tap(tester, 'Business’a geç');
        expect(
          find.textContaining('henüz sunucu tarafından doğrulanmadı'),
          findsWidgets,
        );
        server.delayed = false;
        await tester.tap(find.byTooltip('Bakiyeyi yenile'));
        await tester.pumpAndSettle();
        await tap(tester, 'Şirketini oluştur');
        expect(find.byType(BusinessManagementScreen), findsOneWidget);
        expect(store.purchases, 1);
      }, () => MockClient(server.handle));
    },
  );

  testWidgets(
    'creation succeeds but me fails: retry reuses company without another purchase',
    (tester) async {
      final server = Server()
        ..paid = true
        ..failMembershipRefresh = true;
      final store = Store(server);
      await http.runWithClient(() async {
        await open(tester, store);
        await tap(tester, 'Şirketini oluştur');
        await tester.enterText(find.byType(TextFormField).first, 'My Company');
        await tap(tester, 'Şirketi Oluştur');
        expect(WorkspaceSession.state.value!.isBusiness, isFalse);
        expect(server.creates, 1);
        server.failMembershipRefresh = false;
        await tap(tester, 'Şirketi Oluştur');
        expect(WorkspaceSession.state.value!.isBusiness, isTrue);
        expect(server.creates, 1);
        expect(store.purchases, 0);
      }, () => MockClient(server.handle));
    },
  );

  testWidgets(
    'membership revoked before workspace authorization never selects Business',
    (tester) async {
      final server = Server()
        ..paid = true
        ..denyWorkspace = true;
      final store = Store(server);
      await http.runWithClient(() async {
        await open(tester, store);
        server.membership = {
          'id': 7,
          'companyName': 'Removed',
          'role': 'MEMBER',
        };
        await tap(tester, 'Şirketini oluştur');
        expect(WorkspaceSession.state.value!.isBusiness, isFalse);
        expect(WorkspaceSession.state.value!.businessId, isNull);
        expect(server.creates, 0);
      }, () => MockClient(server.handle));
    },
  );

  testWidgets(
    'late me response after login change cannot update the next session',
    (tester) async {
      final server = Server()
        ..paid = true
        ..delayAuth = true;
      final store = Store(server);
      await http.runWithClient(() async {
        await open(tester, store);
        await tap(tester, 'Şirketini oluştur');
        expect(server.authStarted.isCompleted, isTrue);
        WorkspaceSession.clear();
        await WorkspaceSession.initialize(userId: 2);
        server.gate.complete();
        await tester.pumpAndSettle();
        expect(WorkspaceSession.state.value!.userId, 2);
        expect(WorkspaceSession.state.value!.isBusiness, isFalse);
        expect(server.creates, 0);
      }, () => MockClient(server.handle));
    },
  );

  testWidgets(
    'an action waiting for refresh cannot start payment in the next login',
    (tester) async {
      final server = Server();
      final store = Store(server);
      await http.runWithClient(() async {
        await open(tester, store);
        server.delaySync = true;
        await tester.tap(find.byTooltip('Bakiyeyi yenile'));
        await tester.pumpAndSettle();
        expect(server.syncStarted.isCompleted, isTrue);
        await tap(tester, 'Business’a geç');
        WorkspaceSession.clear();
        await WorkspaceSession.initialize(userId: 2);
        server.syncGate.complete();
        await tester.pumpAndSettle();
        expect(store.purchases, 0);
        expect(WorkspaceSession.state.value!.userId, 2);
      }, () => MockClient(server.handle));
    },
  );
}
