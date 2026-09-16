import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/billing/models/billing_overview.dart';
import 'package:mobile/features/billing/models/billing_plan.dart';
import 'package:mobile/features/billing/models/billing_status.dart';
import 'package:mobile/features/billing/screens/subscription_screen.dart';
import 'package:mobile/features/billing/services/billing_service.dart';

void main() {
  testWidgets('shows backend plans and fallback prices without store keys', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionScreen(
          billingService: FakeBillingService(storeConfigured: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Abonelik ve Ödeme'), findsOneWidget);
    expect(find.text('Free'), findsNWidgets(2));
    expect(
      find.textContaining('Satın alma anahtarı bu sürümde tanımlı değil'),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Plus'), findsOneWidget);
    expect(find.text('₺149,99 / ay'), findsOneWidget);
  });

  testWidgets('purchases a store package and refreshes current plan', (
    tester,
  ) async {
    final service = FakeBillingService(storeConfigured: true);

    await tester.pumpWidget(
      MaterialApp(home: SubscriptionScreen(billingService: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('₺159,99 / ay'), findsOneWidget);

    final purchaseButton = find.widgetWithText(
      FilledButton,
      'Mağazadan Abone Ol',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(purchaseButton.first);
    await tester.pumpAndSettle();

    expect(service.purchasedPlan, 'PLUS');
    expect(find.text('Plus planınız aktif edildi.'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, 800));
    await tester.pumpAndSettle();
    expect(find.text('Aktif'), findsOneWidget);
  });
}

class FakeBillingService extends BillingService {
  FakeBillingService({required this.storeConfigured});

  final bool storeConfigured;
  String? purchasedPlan;

  @override
  Future<BillingPageData> load() async {
    return BillingPageData(
      overview: _overview('FREE'),
      storeConfigured: storeConfigured,
      localizedPrices: storeConfigured
          ? const {'plus_monthly': '₺159,99'}
          : const {},
    );
  }

  @override
  Future<BillingOverview> purchase(
    BillingPlan plan, {
    String currentPlan = 'FREE',
    String? currentProductId,
  }) async {
    purchasedPlan = plan.plan;
    return _overview(plan.plan);
  }

  BillingOverview _overview(String currentPlan) {
    return BillingOverview(
      status: BillingStatus(
        billingCustomerId: 'billing-id',
        currentPlan: currentPlan,
        status: currentPlan == 'FREE' ? 'NONE' : 'ACTIVE',
        productId: currentPlan == 'PLUS' ? 'eksper_plus_monthly' : null,
        autoRenewing: currentPlan != 'FREE',
        sandbox: true,
      ),
      plans: const [
        BillingPlan(
          plan: 'FREE',
          title: 'Free',
          description: 'Temel kullanım',
          fallbackMonthlyPrice: 0,
          currency: 'TRY',
          highlighted: false,
          features: ['1 aktif araç'],
        ),
        BillingPlan(
          plan: 'PLUS',
          title: 'Plus',
          description: 'Daha geniş kullanım',
          productId: 'eksper_plus_monthly',
          packageIdentifier: 'plus_monthly',
          fallbackMonthlyPrice: 149.99,
          currency: 'TRY',
          highlighted: false,
          features: ['5 aktif araç', 'Günde 15 hasar analizi'],
        ),
      ],
    );
  }
}
