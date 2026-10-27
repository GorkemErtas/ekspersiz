import 'dart:io';

import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../core/workspace/workspace_session.dart';

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

  static Future<void> _configuration = Future<void>.value();

  bool get supportsCurrentPlatform => Platform.isAndroid || Platform.isIOS;

  Future<bool> configure(String appUserId) {
    final scope = WorkspaceSession.capture();
    final next = _configuration.then((_) async {
      WorkspaceSession.check(scope);
      final result = await _configure(appUserId);
      WorkspaceSession.check(scope);
      return result;
    });
    // Purchases has one native identity. Never let an older login finish after
    // configuration for a newer user. A rejected caller must not poison the queue.
    _configuration = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return next;
  }

  Future<bool> _configure(String appUserId) async {
    final apiKey = Platform.isAndroid ? _androidApiKey : _iosApiKey;

    if (!supportsCurrentPlatform || apiKey.trim().isEmpty) {
      return false;
    }

    if (!await Purchases.isConfigured) {
      final configuration = PurchasesConfiguration(apiKey)
        ..appUserID = appUserId;
      await Purchases.configure(configuration);
      if (await Purchases.appUserID != appUserId) {
        throw StateError(
          'Satın alma hesabı doğrulanamadı. Yeniden giriş yapın.',
        );
      }
      return true;
    }

    if (await Purchases.appUserID != appUserId) {
      await Purchases.logIn(appUserId);
    }

    if (await Purchases.appUserID != appUserId) {
      throw StateError('Satın alma hesabı doğrulanamadı. Yeniden giriş yapın.');
    }

    return true;
  }

  // Store state may suppress a duplicate payment, but never grants an entitlement.
  Future<bool> hasActiveSubscription(String productId) async {
    final customer = await Purchases.getCustomerInfo();
    return customer.activeSubscriptions.any(
      (id) => id == productId || id.startsWith('$productId:'),
    );
  }

  Future<Map<String, Package>> getPackages() async {
    final offerings = await Purchases.getOfferings();
    // Credit purchases use a dedicated offering during rollout so older app
    // versions can continue to use the existing current/default offering.
    final offering = offerings.all['credits_v1'] ?? offerings.current;
    final packages = offering?.availablePackages ?? const <Package>[];

    return indexPackages(packages);
  }

  /// Index both the RevenueCat package alias and its real store SKU.
  /// Business subscriptions use package aliases; consumables use store SKUs.
  static Map<String, Package> indexPackages(List<Package> packages) {
    final result = <String, Package>{
      for (final package in packages) package.identifier: package,
    };
    // The real store SKU wins if an unrelated alias happens to collide.
    for (final package in packages) {
      result[package.storeProduct.identifier] = package;
    }
    return result;
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
