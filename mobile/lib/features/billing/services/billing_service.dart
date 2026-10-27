import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../core/workspace/workspace_session.dart';
import '../models/billing_overview.dart';
import '../models/billing_plan.dart';
import '../models/credit_catalog.dart';
import 'revenue_cat_gateway.dart';

class BillingPageData {
  const BillingPageData({
    required this.overview,
    required this.storeConfigured,
    required this.localizedPrices,
    this.storePrices = const {},
  });

  final BillingOverview overview;
  final bool storeConfigured;
  final Map<String, String> localizedPrices;
  final Map<String, StorePrice> storePrices;
}

class BillingService {
  const BillingService({
    this.apiClient = const ApiClient(),
    this.revenueCatGateway = const RevenueCatGateway(),
  });

  final ApiClient apiClient;
  final RevenueCatGateway revenueCatGateway;

  Future<BillingPageData> load() async {
    final scope = WorkspaceSession.capture();
    final overview = await getOverview();
    WorkspaceSession.check(scope);
    final configured = await revenueCatGateway.configure(
      overview.status.billingCustomerId,
    );

    WorkspaceSession.check(scope);
    if (!configured) {
      return BillingPageData(
        overview: overview,
        storeConfigured: false,
        localizedPrices: const {},
      );
    }

    // Reconcile the backend subscription with RevenueCat when opening plans.
    // A purchase can be active in the store while a webhook is delayed or missed.
    final syncedOverview = await sync();
    Map<String, Package> packages;
    try {
      packages = await revenueCatGateway.getPackages();
    } catch (_) {
      // A store catalogue outage must not hide a server-verified subscription
      // or prevent resuming a company setup that has already been paid for.
      packages = const {};
    }
    WorkspaceSession.check(scope);

    return BillingPageData(
      overview: syncedOverview,
      storeConfigured: true,
      localizedPrices: {
        for (final entry in packages.entries)
          entry.key: entry.value.storeProduct.priceString,
      },
      storePrices: {
        for (final entry in packages.entries)
          entry.key: StorePrice(
            entry.value.storeProduct.price,
            entry.value.storeProduct.currencyCode,
            entry.value.storeProduct.priceString,
          ),
      },
    );
  }

  Future<BillingOverview> purchase(
    BillingPlan plan, {
    String currentPlan = 'FREE',
    String? currentProductId,
  }) async {
    final scope = WorkspaceSession.capture();
    final overview = await getOverview();
    WorkspaceSession.check(scope);
    if (!await revenueCatGateway.configure(overview.status.billingCustomerId)) {
      throw StateError('Satın alma mağazası şu anda kullanılamıyor.');
    }
    WorkspaceSession.check(scope);
    // One explicit reconciliation before opening a payment. No polling loop.
    final verified = await sync();
    WorkspaceSession.check(scope);
    if (verified.status.currentPlan == plan.plan ||
        verified.status.verificationStatus == 'SANDBOX_REJECTED') {
      return verified;
    }
    if (plan.productId != null &&
        await revenueCatGateway.hasActiveSubscription(plan.productId!)) {
      WorkspaceSession.check(scope);
      return verified;
    }
    WorkspaceSession.check(scope);
    currentPlan = verified.status.currentPlan;
    currentProductId = verified.status.productId;
    final packageIdentifier = plan.packageIdentifier;

    if (packageIdentifier == null) {
      throw StateError('Bu plan mağaza üzerinden satın alınamaz.');
    }

    final packages = await revenueCatGateway.getPackages();
    WorkspaceSession.check(scope);
    final package = packages[packageIdentifier];

    final sku = package?.storeProduct.identifier;
    if (package == null ||
        plan.productId == null ||
        (sku != plan.productId && !sku!.startsWith('${plan.productId}:'))) {
      throw StateError('Bu plan mağazada henüz yayınlanmadı.');
    }

    final isChangingPlan = currentPlan != 'FREE' && currentPlan != plan.plan;
    await revenueCatGateway.purchase(
      package,
      oldProductId: isChangingPlan ? currentProductId : null,
      replacementMode: isChangingPlan
          ? (_rank(plan.plan) > _rank(currentPlan)
                ? StoreReplacementMode.withTimeProration
                : StoreReplacementMode.deferred)
          : null,
    );
    try {
      WorkspaceSession.check(scope);
      return await sync();
    } catch (_) {
      throw const BillingPurchasePending();
    }
  }

  Future<BillingOverview> restore() async {
    final scope = WorkspaceSession.capture();
    final overview = await getOverview();
    WorkspaceSession.check(scope);
    if (!await revenueCatGateway.configure(overview.status.billingCustomerId)) {
      throw StateError('Satın alma mağazası şu anda kullanılamıyor.');
    }
    WorkspaceSession.check(scope);
    await revenueCatGateway.restorePurchases();
    WorkspaceSession.check(scope);
    return sync();
  }

  Future<CreditOverview> credits() async {
    final data = await apiClient.get('/credits');
    return CreditOverview.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<bool> purchaseCredit(CreditProduct product) async {
    final scope = WorkspaceSession.capture();
    final overview = await getOverview();
    WorkspaceSession.check(scope);
    if (!await revenueCatGateway.configure(overview.status.billingCustomerId)) {
      throw StateError('Satın alma mağazası şu anda kullanılamıyor.');
    }
    final packages = await revenueCatGateway.getPackages();
    WorkspaceSession.check(scope);
    final package = packages[product.id];
    if (package == null || package.storeProduct.identifier != product.id) {
      throw StateError('Bu paket mağazada henüz yayınlanmadı.');
    }
    WorkspaceSession.check(scope);
    await apiClient.post('/credits/purchase-intents/${product.id}');
    WorkspaceSession.check(scope);
    final transaction = await revenueCatGateway.purchaseConsumable(package);
    try {
      WorkspaceSession.check(scope);
      await sync();
      final result = await apiClient.get(
        '/credits/purchases/${Uri.encodeComponent(transaction)}',
      );
      return result is Map && result['confirmed'] == true;
    } catch (_) {
      // The store has already accepted the purchase; backend reconciliation may lag.
      throw const BillingPurchasePending();
    }
  }

  Future<BillingOverview> getOverview() async {
    final response = await apiClient.get('/billing');
    return _parseOverview(response);
  }

  Future<BillingOverview> sync() async {
    final response = await apiClient.post('/billing/sync');
    return _parseOverview(response);
  }

  BillingOverview _parseOverview(dynamic response) {
    if (response is! Map) {
      throw const FormatException('Abonelik bilgisi alınamadı.');
    }

    return BillingOverview.fromJson(Map<String, dynamic>.from(response));
  }

  int _rank(String plan) {
    return switch (plan) {
      'BUSINESS' => 3,
      'PRO' => 2,
      'PLUS' => 1,
      _ => 0,
    };
  }
}
