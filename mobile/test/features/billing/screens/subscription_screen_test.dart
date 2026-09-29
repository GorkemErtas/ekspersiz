import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/billing/models/analysis_quota.dart';
import 'package:mobile/features/billing/models/billing_overview.dart';
import 'package:mobile/features/billing/models/billing_plan.dart';
import 'package:mobile/features/billing/models/billing_status.dart';
import 'package:mobile/features/billing/screens/subscription_screen.dart';
import 'package:mobile/features/billing/services/analysis_quota_service.dart';
import 'package:mobile/features/billing/services/billing_service.dart';

void main() {
  testWidgets(
    'shows free allowance and analysis credit packs',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SubscriptionScreen(
            billingService: FakeBillingService(
              storeConfigured: false,
            ),
            quotaService: FakeQuotaService(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Planlar ve AI Hakları'),
        findsOneWidget,
      );

      expect(
        find.text('Bu ay 1 ücretsiz • 0 satın alınan'),
        findsOneWidget,
      );

      expect(
        find.text('1 detaylı AI analizi'),
        findsOneWidget,
      );

      expect(
        find.text('₺20,00 ile satın al'),
        findsOneWidget,
      );

      expect(
        find.text('3 detaylı AI analizi'),
        findsOneWidget,
      );

      expect(
        find.text('₺49,99 ile satın al'),
        findsOneWidget,
      );

      expect(
        find.text('Önerilen'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows Business plan separately from credit packs',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SubscriptionScreen(
            billingService: FakeBillingService(
              storeConfigured: false,
            ),
            quotaService: FakeQuotaService(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;

      await tester.scrollUntilVisible(
        find.text('EksperSiz Business'),
        300,
        scrollable: scrollable,
      );

      await tester.pumpAndSettle();

      expect(
        find.text('EksperSiz Business'),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.text('50 ortak aktif araç'),
        200,
        scrollable: scrollable,
      );

      await tester.pumpAndSettle();

      expect(
        find.text('50 ortak aktif araç'),
        findsOneWidget,
      );

      expect(
        find.text('Şirket genelinde ayda 100 AI analizi'),
        findsOneWidget,
      );

      expect(
        find.text('Çalışan daveti ve ortak geçmiş'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'purchases a credit pack',
    (tester) async {
      final quotaService = FakeQuotaService();

      final billingService = FakeBillingService(
        storeConfigured: true,
        onPurchaseCreditPack: quotaService.addCredit,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SubscriptionScreen(
            billingService: billingService,
            quotaService: quotaService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final buyButton = find.widgetWithText(
        FilledButton,
        '₺20,00 ile satın al',
      );

      expect(buyButton, findsOneWidget);

      await tester.tap(buyButton);

      // _buy() içindeki 750 ms polling süresini ilerlet.
      await tester.pump(
        const Duration(milliseconds: 800),
      );

      await tester.pumpAndSettle();

      expect(
        billingService.purchasedPackage,
        'analysis_1',
      );

      expect(
        quotaService.credits,
        1,
      );

      expect(
        find.text('Bu ay 1 ücretsiz • 1 satın alınan'),
        findsOneWidget,
      );
    },
  );
}

class FakeQuotaService extends AnalysisQuotaService {
  FakeQuotaService();

  int credits = 0;

  void addCredit() {
    credits++;
  }

  @override
  Future<AnalysisQuota> getQuota() async {
    return AnalysisQuota(
      plan: 'FREE',
      used: 0,
      limit: 1,
      remaining: 1 + credits,
      freeRemaining: 1,
      purchasedCredits: credits,
    );
  }
}

class FakeBillingService extends BillingService {
  FakeBillingService({
    required this.storeConfigured,
    this.onPurchaseCreditPack,
  });

  final bool storeConfigured;
  final VoidCallback? onPurchaseCreditPack;

  String? purchasedPackage;

  @override
  Future<BillingPageData> load() async {
    return BillingPageData(
      overview: _overview(),
      storeConfigured: storeConfigured,
      localizedPrices: storeConfigured
          ? const {
              'analysis_1': '₺20,00',
              'analysis_3': '₺49,99',
              'analysis_10': '₺139,99',
              'business_monthly': '₺719,99',
            }
          : const {},
    );
  }

  @override
  Future<void> purchaseCreditPack(
    String packageIdentifier,
  ) async {
    purchasedPackage = packageIdentifier;
    onPurchaseCreditPack?.call();
  }

  BillingOverview _overview() {
    return BillingOverview(
      status: const BillingStatus(
        billingCustomerId: 'billing-id',
        currentPlan: 'FREE',
        status: 'NONE',
        autoRenewing: false,
        sandbox: true,
      ),
      plans: const [
        BillingPlan(
          plan: 'FREE',
          title: 'Ücretsiz',
          description: 'Temel kullanım',
          fallbackMonthlyPrice: 0,
          currency: 'TRY',
          highlighted: false,
          features: [
            'Temel AI hasar tespiti ücretsiz',
          ],
        ),
        BillingPlan(
          plan: 'BUSINESS',
          title: 'Kurumsal',
          description:
              'Ekipler ve ortak şirket araçları için',
          productId: 'eksper_business_monthly',
          packageIdentifier: 'business_monthly',
          fallbackMonthlyPrice: 1499.99,
          currency: 'TRY',
          highlighted: false,
          features: [
            '50 ortak aktif araç',
            'Şirket genelinde ayda 100 AI analizi',
            'Çalışan daveti ve ortak geçmiş',
          ],
        ),
      ],
    );
  }
}