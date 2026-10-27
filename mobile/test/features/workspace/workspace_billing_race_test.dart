import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/workspace/workspace_session.dart';
import 'package:mobile/features/billing/models/credit_catalog.dart';
import 'package:mobile/features/billing/services/billing_service.dart';
import 'package:mobile/features/billing/services/revenue_cat_gateway.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../billing/services/billing_service_test.dart'
    show RecordingApi, RecordingGateway;

class _DelayedGateway extends RecordingGateway {
  _DelayedGateway(super.calls);
  final gate = Completer<void>();
  final started = Completer<void>();
  bool duringPurchase = false;
  @override
  Future<Map<String, Package>> getPackages() async {
    if (!duringPurchase) {
      started.complete();
      await gate.future;
    }
    return super.getPackages();
  }

  @override
  Future<String> purchaseConsumable(Package package) async {
    started.complete();
    await gate.future;
    return super.purchaseConsumable(package);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    WorkspaceSession.clear();
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(WorkspaceSession.clear);
  final product = CreditProduct.fromJson({
    'productId': 'eksper_analysis_5',
    'resource': 'ANALYSIS',
    'quantity': 5,
    'referencePrice': 189.95,
  });

  test(
    'switching before intent creation cannot start a store purchase in the next workspace',
    () async {
      await WorkspaceSession.initialize(
        userId: 1,
        businessId: 7,
        role: 'MEMBER',
        businessAvailable: true,
        businessAccessStatus: 'ACTIVE',
      );
      await WorkspaceSession.select(WorkspaceType.personal);
      final calls = <String>[];
      final gateway = _DelayedGateway(calls);
      final service = BillingService(
        apiClient: RecordingApi(calls),
        revenueCatGateway: gateway,
      );
      final purchase = service.purchaseCredit(product);
      await gateway.started.future;
      await WorkspaceSession.select(WorkspaceType.business);
      final rejected = expectLater(purchase, throwsA(isA<ApiException>()));
      gateway.gate.complete();
      await rejected;
      expect(calls.any((c) => c.startsWith('POST ')), isFalse);
      expect(calls, isNot(contains('purchase')));
    },
  );

  test(
    'store completion after account change never syncs or confirms as the next user',
    () async {
      await WorkspaceSession.initialize(userId: 1);
      final calls = <String>[];
      final gateway = _DelayedGateway(calls)..duringPurchase = true;
      final service = BillingService(
        apiClient: RecordingApi(calls),
        revenueCatGateway: gateway,
      );
      final purchase = service.purchaseCredit(product);
      await gateway.started.future;
      WorkspaceSession.clear();
      await WorkspaceSession.initialize(userId: 2);
      final pending = expectLater(
        purchase,
        throwsA(isA<BillingPurchasePending>()),
      );
      gateway.gate.complete();
      await pending;
      expect(
        calls,
        contains('POST /credits/purchase-intents/eksper_analysis_5'),
      );
      expect(calls, isNot(contains('POST /billing/sync')));
      expect(
        calls.any((c) => c.startsWith('GET /credits/purchases/')),
        isFalse,
      );
    },
  );
}
