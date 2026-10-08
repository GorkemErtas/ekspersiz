import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../core/network/api_client.dart';
import '../models/billing_overview.dart';
import '../models/billing_plan.dart';
import 'revenue_cat_gateway.dart';

class BillingPageData {
  const BillingPageData({
    required this.overview,
    required this.storeConfigured,
    required this.localizedPrices,
  });

  final BillingOverview overview;
  final bool storeConfigured;
  final Map<String, String> localizedPrices;
}

class BillingService {
  const BillingService({
    this.apiClient = const ApiClient(),
    this.revenueCatGateway = const RevenueCatGateway(),
  });

  final ApiClient apiClient;
  final RevenueCatGateway revenueCatGateway;

  Future<BillingPageData> load() async {
    final overview = await getOverview();
    final configured = await revenueCatGateway.configure(
      overview.status.billingCustomerId,
    );

    if (!configured) {
      return BillingPageData(
        overview: overview,
        storeConfigured: false,
        localizedPrices: const {},
      );
    }

    final packages = await revenueCatGateway.getPackages();

    return BillingPageData(
      overview: overview,
      storeConfigured: true,
      localizedPrices: {
        for (final entry in packages.entries)
          entry.key: entry.value.storeProduct.priceString,
      },
    );
  }

  Future<BillingOverview> purchase(
    BillingPlan plan, {
    String currentPlan = 'FREE',
    String? currentProductId,
  }) async {
    final packageIdentifier = plan.packageIdentifier;

    if (packageIdentifier == null) {
      throw StateError('Bu plan mağaza üzerinden satın alınamaz.');
    }

    final packages = await revenueCatGateway.getPackages();
    final package = packages[packageIdentifier];

    if (package == null) {
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
    return sync();
  }

  Future<BillingOverview> restore() async {
    await revenueCatGateway.restorePurchases();
    return sync();
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
