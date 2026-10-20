import 'dart:io';

import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class BillingPurchaseCancelled implements Exception {
  const BillingPurchaseCancelled();
}

class BillingPurchasePending implements Exception {
  const BillingPurchasePending();
}

class RevenueCatGateway {
  const RevenueCatGateway();

  static const _androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_PUBLIC_KEY',
  );
  static const _iosApiKey = String.fromEnvironment('REVENUECAT_IOS_PUBLIC_KEY');

  bool get supportsCurrentPlatform => Platform.isAndroid || Platform.isIOS;

  Future<bool> configure(String appUserId) async {
    final apiKey = Platform.isAndroid ? _androidApiKey : _iosApiKey;

    if (!supportsCurrentPlatform || apiKey.trim().isEmpty) {
      return false;
    }

    if (!await Purchases.isConfigured) {
      final configuration = PurchasesConfiguration(apiKey)
        ..appUserID = appUserId;
      await Purchases.configure(configuration);
      return true;
    }

    if (await Purchases.appUserID != appUserId) {
      await Purchases.logIn(appUserId);
    }

    return true;
  }

  Future<Map<String, Package>> getPackages() async {
    final offerings = await Purchases.getOfferings();
    // Credit purchases use a dedicated offering during rollout so older app
    // versions can continue to use the existing current/default offering.
    final offering = offerings.all['credits_v1'] ?? offerings.current;
    final packages = offering?.availablePackages ?? const <Package>[];

    // RevenueCat package identifiers are configurable and may differ from the
    // Google Play product IDs used by our server-side credit catalog. Match
    // by the actual store product, while preserving the package for purchase.
    return {
      for (final package in packages)
        package.storeProduct.identifier: package,
    };
  }

  Future<void> purchase(
    Package package, {
    String? oldProductId,
    StoreReplacementMode? replacementMode,
  }) async {
    try {
      await Purchases.purchase(
        PurchaseParams.package(
          package,
          productChangeInfo: Platform.isAndroid && oldProductId != null
              ? StoreProductChangeInfo(
                  oldProductId,
                  replacementMode: replacementMode,
                )
              : null,
        ),
      );
    } on PlatformException catch (exception) {
      if (PurchasesErrorHelper.getErrorCode(exception) ==
          PurchasesErrorCode.purchaseCancelledError) {
        throw const BillingPurchaseCancelled();
      }
      if (PurchasesErrorHelper.getErrorCode(exception) ==
          PurchasesErrorCode.paymentPendingError) {
        throw const BillingPurchasePending();
      }

      rethrow;
    }
  }

  Future<void> restorePurchases() async {
    await Purchases.restorePurchases();
  }

  Future<String> purchaseConsumable(Package package) async {
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      return result.storeTransaction.transactionIdentifier;
    } on PlatformException catch (exception) {
      final code = PurchasesErrorHelper.getErrorCode(exception);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        throw const BillingPurchaseCancelled();
      }
      if (code == PurchasesErrorCode.paymentPendingError) {
        throw const BillingPurchasePending();
      }
      rethrow;
    }
  }
}
