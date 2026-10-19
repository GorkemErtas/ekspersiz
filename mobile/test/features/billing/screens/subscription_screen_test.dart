import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/billing/models/billing_overview.dart';
import 'package:mobile/features/billing/models/billing_plan.dart';
import 'package:mobile/features/billing/models/billing_status.dart';
import 'package:mobile/features/billing/models/credit_catalog.dart';
import 'package:mobile/features/billing/screens/subscription_screen.dart';
import 'package:mobile/features/billing/services/billing_service.dart';

void main() {
  testWidgets('company member opens shared balance without payment controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionScreen(
          billingService: FakeBillingService(company: true),
          preferCompany: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Şirketin ortak bakiyesi'), findsOneWidget);
    expect(find.text('99 analiz kredisi'), findsOneWidget);
    expect(find.textContaining('yalnızca şirket sahibi'), findsOneWidget);
    expect(find.text('Business'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    await tester.tap(find.text('Kişisel'));
    await tester.pumpAndSettle();
    expect(find.text('3 analiz kredisi'), findsOneWidget);
    expect(find.text('Satın al'), findsWidgets);
  });
  testWidgets('shows actual store totals, unit price and savings', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionScreen(billingService: FakeBillingService()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Krediler ve Paketler'), findsOneWidget);
    expect(find.text('3 analiz kredisi'), findsOneWidget);
    expect(find.text('189,95 TL'), findsOneWidget);
    expect(find.textContaining('%5 indirim'), findsOneWidget);
    expect(find.textContaining('10,00'), findsWidgets);
    expect(find.text('Aylık abonelikler'), findsNothing);
  });
  testWidgets('missing store products cannot be purchased', (tester) async {
    final service = FakeBillingService(configured: false);
    await tester.pumpWidget(
      MaterialApp(home: SubscriptionScreen(billingService: service)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Referans fiyat:'), findsWidgets);
    expect(find.textContaining('tasarruf'), findsNothing);
    final buttons = tester.widgetList<FilledButton>(find.byType(FilledButton));
    expect(buttons.every((b) => b.onPressed == null), isTrue);
  });
  testWidgets('purchase refreshes balance only after backend confirmation', (
    tester,
  ) async {
    final service = FakeBillingService();
    await tester.pumpWidget(
      MaterialApp(home: SubscriptionScreen(billingService: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Satın al').first);
    await tester.pumpAndSettle();
    expect(service.purchased, 'eksper_analysis_1');
    expect(find.text('4 analiz kredisi'), findsOneWidget);
    expect(
      find.text('Satın alma doğrulandı. Bakiyeniz güncellendi.'),
      findsOneWidget,
    );
  });
  testWidgets('pending payment never displays purchase success', (
    tester,
  ) async {
    final service = FakeBillingService(confirmed: false);
    await tester.pumpWidget(
      MaterialApp(home: SubscriptionScreen(billingService: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Satın al').first);
    await tester.pumpAndSettle();
    expect(find.text('3 analiz kredisi'), findsOneWidget);
    expect(find.textContaining('Ödemeniz doğrulanıyor'), findsOneWidget);
    expect(find.textContaining('Satın alma doğrulandı'), findsNothing);
  });
  testWidgets(
    'business credits are shared and single-purchase comparison is explicit',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SubscriptionScreen(billingService: FakeBillingService()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Business'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('4.999,99 TL / ay'), findsOneWidget);
      expect(find.textContaining('10 ortak araç slotu'), findsOneWidget);
      expect(find.textContaining('997,01'), findsOneWidget);
      expect(
        find.textContaining('indirimli paketler dahil değildir'),
        findsOneWidget,
      );
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets('320px and large text fit in $brightness', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: SubscriptionScreen(billingService: FakeBillingService()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Business'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  test(
    'savings use numeric matching currencies and never advertise a surcharge',
    () {
      expect(
        PriceSavings.compare(
          const StorePrice(200, 'TRY', ''),
          const StorePrice(39.99, 'TRY', ''),
          5,
        ),
        isNull,
      );
      expect(
        PriceSavings.compare(
          const StorePrice(10, 'USD', ''),
          const StorePrice(39.99, 'TRY', ''),
          5,
        ),
        isNull,
      );
      expect(
        PriceSavings.compare(null, const StorePrice(39.99, 'TRY', ''), 5),
        isNull,
      );
      final value = PriceSavings.compare(
        const StorePrice(639.84, 'TRY', ''),
        const StorePrice(39.99, 'TRY', ''),
        20,
      )!;
      expect(value.amount, 159.96);
      expect(value.percent, closeTo(20, .001));
    },
  );
}

class FakeBillingService extends BillingService {
  FakeBillingService({
    this.configured = true,
    this.confirmed = true,
    this.company = false,
  });
  final bool company;
  final bool configured;
  final bool confirmed;
  int balance = 3;
  String? purchased;
  @override
  Future<CreditOverview> credits() async => CreditOverview.fromJson({
    if (company)
      'company': {
        'canPurchase': false,
        'owner': false,
        'usedSlots': 3,
        'totalSlots': 10,
        'balances': {
          'ANALYSIS': {'available': 99, 'periodic': 99},
          'ASSISTANT': {'available': 200, 'periodic': 200},
        },
      },
    'personal': {
      'canPurchase': true,
      'usedSlots': 1,
      'totalSlots': 2,
      'balances': {
        'ANALYSIS': {'available': balance},
        'ASSISTANT': {'available': 2},
      },
    },
    'products': [
      {
        'productId': 'eksper_analysis_1',
        'resource': 'ANALYSIS',
        'quantity': 1,
        'referencePrice': 39.99,
      },
      {
        'productId': 'eksper_analysis_5',
        'resource': 'ANALYSIS',
        'quantity': 5,
        'referencePrice': 189.95,
      },
      {
        'productId': 'eksper_assistant_1',
        'resource': 'ASSISTANT',
        'quantity': 1,
        'referencePrice': 9.99,
      },
    ],
  });
  @override
  Future<bool> purchaseCredit(CreditProduct product) async {
    purchased = product.id;
    if (confirmed) balance += product.quantity;
    return confirmed;
  }

  @override
  Future<BillingPageData> load() async => BillingPageData(
    overview: const BillingOverview(
      status: BillingStatus(
        billingCustomerId: 'billing-id',
        currentPlan: 'FREE',
        status: 'NONE',
        autoRenewing: false,
        sandbox: true,
      ),
      plans: [
        BillingPlan(
          plan: 'BUSINESS',
          title: 'Business',
          description: 'Ekipler için',
          productId: 'eksper_business_monthly',
          packageIdentifier: 'business_monthly',
          fallbackMonthlyPrice: 4999.99,
          currency: 'TRY',
          highlighted: false,
          features: [],
        ),
      ],
    ),
    storeConfigured: configured,
    localizedPrices: const {},
    storePrices: configured
        ? const {
            'eksper_analysis_1': StorePrice(39.99, 'TRY', '39,99 TL'),
            'eksper_analysis_5': StorePrice(189.95, 'TRY', '189,95 TL'),
            'eksper_assistant_1': StorePrice(9.99, 'TRY', '9,99 TL'),
            'business_monthly': StorePrice(4999.99, 'TRY', '4.999,99 TL'),
          }
        : const {},
  );
}
