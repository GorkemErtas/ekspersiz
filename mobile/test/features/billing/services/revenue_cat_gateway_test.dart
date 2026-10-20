import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:mobile/features/billing/services/revenue_cat_gateway.dart';

void main() {
  test('maps a custom RevenueCat alias to its actual Play consumable SKU', () {
    const analysis = Package(
      'custom_analysis_alias',
      PackageType.custom,
      StoreProduct('eksper_analysis_1', '', 'Analysis', 39.99, '39,99 TL', 'TRY'),
      PresentedOfferingContext('credits_v1', null, null),
    );
    final indexed = RevenueCatGateway.indexPackages([analysis]);

    expect(indexed['custom_analysis_alias'], same(analysis));
    expect(indexed['eksper_analysis_1'], same(analysis));
  });

  test('keeps business_monthly alias while exposing its store product', () {
    const business = Package(
      'business_monthly',
      PackageType.custom,
      StoreProduct(
        'eksper_business_monthly',
        '',
        'Business',
        4999.99,
        '4.999,99 TL',
        'TRY',
      ),
      PresentedOfferingContext('credits_v1', null, null),
    );
    final indexed = RevenueCatGateway.indexPackages([business]);

    expect(indexed['business_monthly'], same(business));
    expect(indexed['eksper_business_monthly'], same(business));
  });

  test('the store product ID wins over a conflicting unrelated alias', () {
    const actual = Package(
      'analysis_1',
      PackageType.custom,
      StoreProduct('eksper_analysis_1', '', 'Analysis', 39.99, '39,99 TL', 'TRY'),
      PresentedOfferingContext('credits_v1', null, null),
    );
    const unrelated = Package(
      'eksper_analysis_1',
      PackageType.custom,
      StoreProduct('eksper_assistant_1', '', 'Assistant', 9.99, '9,99 TL', 'TRY'),
      PresentedOfferingContext('credits_v1', null, null),
    );
    final indexed = RevenueCatGateway.indexPackages([actual, unrelated]);

    expect(indexed['eksper_analysis_1'], same(actual));
    expect(indexed['eksper_assistant_1'], same(unrelated));
  });
}
