import 'dart:io';

import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class BillingPurchaseCancelled implements Exception {
  const BillingPurchaseCancelled();
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
    final packages = offerings.current?.availablePackages ?? const <Package>[];

    return {for (final package in packages) package.identifier: package};
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

      rethrow;
    }
  }

  Future<void> restorePurchases() async {
    await Purchases.restorePurchases();
  }
}
