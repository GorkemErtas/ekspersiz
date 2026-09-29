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
  testWidgets('shows free allowance and analysis credit packs', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionScreen(
          billingService: FakeBillingService(storeConfigured: false),
          quotaService: FakeQuotaService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI Analiz Hakları'), findsOneWidget);
    expect(find.textContaining('Bu ay ücretsiz: 1'), findsOneWidget);
    expect(find.textContaining('Satın alınan: 0'), findsOneWidget);
    expect(find.text('1 detaylı analiz'), findsOneWidget);
    expect(find.text('₺20,00'), findsOneWidget);
    expect(find.text('3 detaylı analiz'), findsOneWidget);
    expect(find.text('₺49,99'), findsOneWidget);
  });

  testWidgets('purchases a credit pack', (tester) async {
    final billing = FakeBillingService(storeConfigured: true);
    final quota = FakeQuotaService();

    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionScreen(
          billingService: billing,
          quotaService: quota,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '₺20,00'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(billing.purchasedPackage, 'analysis_1');
  });
}

class FakeQuotaService extends AnalysisQuotaService {
  FakeQuotaService();

  int credits = 0;

  @override
  Future<AnalysisQuota> getQuota() async => AnalysisQuota(
        plan: 'FREE',
        used: 0,
        limit: 1,
        remaining: 1 + credits,
        freeRemaining: 1,
        purchasedCredits: credits,
      );
}

class FakeBillingService extends BillingService {
  FakeBillingService({required this.storeConfigured});

  final bool storeConfigured;
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
            }
          : const {},
    );
  }

  @override
  Future<void> purchaseCreditPack(String packageIdentifier) async {
    purchasedPackage = packageIdentifier;
  }

  BillingOverview _overview() => BillingOverview(
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
            features: ['Temel AI hasar tespiti ücretsiz'],
          ),
        ],
      );
}
