import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/billing/models/credit_catalog.dart';
import 'package:mobile/features/billing/services/billing_service.dart';
import 'package:mobile/features/billing/services/revenue_cat_gateway.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

const _productId = 'eksper_analysis_5';
const _customerId = 'server-issued-customer-id';
const _transactionId = 'GPA.order/1';
const _package = Package(
  _productId,
  PackageType.custom,
  StoreProduct(_productId, '', '5 analyses', 189.95, '189,95 TL', 'TRY'),
  PresentedOfferingContext('credits_v1', null, null),
);

void main() {
  late List<String> calls;
  late RecordingApi api;
  late RecordingGateway gateway;
  late BillingService service;
  final product = CreditProduct.fromJson({
    'productId': _productId,
    'resource': 'ANALYSIS',
    'quantity': 5,
    'business': false,
    'referencePrice': 189.95,
  });

  setUp(() {
    calls = [];
    api = RecordingApi(calls);
    gateway = RecordingGateway(calls);
    service = BillingService(apiClient: api, revenueCatGateway: gateway);
  });

  test(
    'store success requires backend confirmation after intent and sync',
    () async {
      api.confirmed = true;
      expect(await service.purchaseCredit(product), isTrue);
      expect(calls, [
        'GET /billing',
        'configure $_customerId',
        'packages',
        'POST /credits/purchase-intents/$_productId',
        'purchase',
        'POST /billing/sync',
        'GET /credits/purchases/GPA.order%2F1',
      ]);
      // Neither environment nor a test-account assertion is submitted by Flutter.
      expect(api.bodies, everyElement(isNull));
    },
  );

  test(
    'HTTP 200 with unconfirmed transaction does not grant local credits',
    () async {
      expect(await service.purchaseCredit(product), isFalse);
    },
  );

  test('sync outage after accepted purchase remains pending', () async {
    api.failSync = true;
    await expectLater(
      service.purchaseCredit(product),
      throwsA(isA<BillingPurchasePending>()),
    );
    expect(calls.where((call) => call == 'purchase'), hasLength(1));
    expect(
      calls.any((call) => call.startsWith('GET /credits/purchases')),
      isFalse,
    );
  });

  test(
    'opening billing reconciles missed webhook without another purchase',
    () async {
      await service.load();
      expect(calls, [
        'GET /billing',
        'configure $_customerId',
        'POST /billing/sync',
        'packages',
      ]);
    },
  );

  test(
    'restore reconciles through backend without creating purchase intent',
    () async {
      await service.restore();
      expect(calls, ['restore', 'POST /billing/sync']);
      expect(api.bodies, everyElement(isNull));
    },
  );

  test('failed purchase intent never starts store payment', () async {
    api.failIntent = true;
    await expectLater(service.purchaseCredit(product), throwsStateError);
    expect(calls, isNot(contains('purchase')));
  });
}

class RecordingApi extends ApiClient {
  RecordingApi(this.calls);
  final List<String> calls;
  final List<Map<String, dynamic>?> bodies = [];
  bool confirmed = false;
  bool failSync = false;
  bool failIntent = false;
  Map<String, dynamic> get overview => {
    'status': {'billingCustomerId': _customerId, 'currentPlan': 'FREE'},
    'plans': <dynamic>[],
  };

  @override
  Future<dynamic> get(String path) async {
    calls.add('GET $path');
    if (path == '/billing') return overview;
    if (path.startsWith('/credits/purchases/')) return {'confirmed': confirmed};
    throw StateError('Unexpected path $path');
  }

  @override
  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    Duration? timeout,
    bool includeAuth = true,
    bool clearTokenOnUnauthorized = true,
  }) async {
    calls.add('POST $path');
    bodies.add(body);
    if (path == '/billing/sync') {
      if (failSync) throw StateError('Unavailable');
      return overview;
    }
    if (path.startsWith('/credits/purchase-intents/')) {
      if (failIntent) throw StateError('Denied');
      return {'id': 'server-intent'};
    }
    throw StateError('Unexpected path $path');
  }
}

class RecordingGateway extends RevenueCatGateway {
  RecordingGateway(this.calls);
  final List<String> calls;
  @override
  Future<bool> configure(String appUserId) async {
    calls.add('configure $appUserId');
    return true;
  }

  @override
  Future<Map<String, Package>> getPackages() async {
    calls.add('packages');
    return {_productId: _package};
  }

  @override
  Future<String> purchaseConsumable(Package package) async {
    calls.add('purchase');
    return _transactionId;
  }

  @override
  Future<void> restorePurchases() async {
    calls.add('restore');
  }
}
