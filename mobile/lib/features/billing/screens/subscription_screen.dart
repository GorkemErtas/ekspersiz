import 'package:flutter/material.dart';
import 'package:mobile/core/localization/app_text.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../models/analysis_quota.dart';
import '../models/billing_plan.dart';
import '../services/analysis_quota_service.dart';
import '../services/billing_service.dart';
import '../services/revenue_cat_gateway.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({
    super.key,
    this.billingService = const BillingService(),
    this.quotaService = const AnalysisQuotaService(),
  });

  final BillingService billingService;
  final AnalysisQuotaService quotaService;
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  BillingService get _billing => widget.billingService;
  AnalysisQuotaService get _quotaService => widget.quotaService;
  BillingPageData? _billingData;
  AnalysisQuota? _quota;
  String? _busyPack;
  bool _businessBusy = false;
  String? _error;

  BillingPlan? get _businessPlan {
    final plans = _billingData?.overview.plans ?? const <BillingPlan>[];
    for (final plan in plans) {
      if (plan.plan == 'BUSINESS') return plan;
    }
    return null;
  }

  bool get _isBusiness => _quota?.plan == 'BUSINESS' ||
      _billingData?.overview.status.currentPlan == 'BUSINESS';

  static const _packs = [
    ('analysis_1', 1, '₺20,00', '₺20 / analiz'),
    ('analysis_3', 3, '₺49,99', '≈ ₺16,67 / analiz'),
    ('analysis_10', 10, '₺139,99', '≈ ₺14 / analiz'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([_billing.load(), _quotaService.getQuota()]);
      if (!mounted) return;
      setState(() {
        _billingData = values[0] as BillingPageData;
        _quota = values[1] as AnalysisQuota;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

  Future<void> _buy(String packageId) async {
    if (_busyPack != null) return;
    setState(() => _busyPack = packageId);
    try {
      final before = await _quotaService.getQuota();
      await _billing.purchaseCreditPack(packageId);
      AnalysisQuota current = before;
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 750));
        current = await _quotaService.getQuota();
        if (current.purchasedCredits > before.purchasedCredits) break;
      }
      if (!mounted) return;
      setState(() => _quota = current);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: AppText(current.purchasedCredits > before.purchasedCredits
          ? 'Analiz haklarınız hesabınıza eklendi.'
          : 'Ödeme alındı. Haklarınız birkaç saniye içinde hesabınıza eklenecek.')));
    } on BillingPurchaseCancelled {
      return;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText(_message(e))));
    } finally {
      if (mounted) setState(() => _busyPack = null);
    }
  }

  Future<void> _buyBusiness(BillingPlan plan) async {
    if (_businessBusy || _busyPack != null || _isBusiness) return;
    setState(() => _businessBusy = true);
    try {
      await _billing.purchase(
        plan,
        currentPlan: _billingData!.overview.status.currentPlan,
        currentProductId: _billingData!.overview.status.productId,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Business aboneliğiniz etkinleştirildi.')),
      );
    } on BillingPurchaseCancelled {
      return;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AppText(_message(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _businessBusy = false);
    }
  }

  String _message(Object e) => e.toString().replaceFirst('Exception: ', '').replaceFirst('Bad state: ', '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('Planlar ve AI Hakları')),
      body: SafeArea(
        child: _error != null && _quota == null
          ? Center(child: FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: AppText(_error!)))
          : _quota == null || _billingData == null
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: AppTheme.maxContentWidth),
                  child: ListView(
                    padding: AppTheme.pagePadding,
                    children: [
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText('Detaylı AI raporu haklarınız',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 14),
                            AppText(_quota!.plan == 'BUSINESS'
                              ? '${_quota!.remaining} / ${_quota!.limit} şirket analizi kaldı'
                              : 'Bu ay ücretsiz: ${_quota!.freeRemaining}  •  Satın alınan: ${_quota!.purchasedCredits}'),
                            const SizedBox(height: 8),
                            const AppText('Temel görsel hasar tespiti ücretsizdir. Detaylı rapor; AI açıklaması, onarım önerileri ve tahmini maliyet aralığını içerir.'),
                          ],
                        ),
                      ),
                      if (_quota!.plan != 'BUSINESS') ...[
                        const SizedBox(height: 24),
                        AppText('Analiz hakkı ekle',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 12),
                        for (final pack in _packs) ...[
                          AppCard(
                            showShadow: pack.$2 == 3,
                            child: Row(
                              children: [
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AppText('${pack.$2} detaylı analiz',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 4),
                                    AppText(pack.$4),
                                  ],
                                )),
                                FilledButton(
                                  onPressed: !_billingData!.storeConfigured || _busyPack != null ? null : () => _buy(pack.$1),
                                  child: _busyPack == pack.$1
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                    : AppText(_billingData!.localizedPrices[pack.$1] ?? pack.$3),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 8),
                        AppText('Tek seferlik ödeme • Abonelik yok • Satın alınan hakların süresi dolmaz',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ] else ...[
                        const SizedBox(height: 18),
                        AppCard(
                          showShadow: false,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                          child: const Row(
                            children: [
                              Icon(Icons.business_center_rounded),
                              SizedBox(width: 12),
                              Expanded(child: AppText('Business hesabınız şirketin ortak araç ve analiz kotasını kullanıyor.')),
                            ],
                          ),
                        ),
                      ],
                      if (_businessPlan != null) ...[
                        const SizedBox(height: 30),
                        AppText(
                          'EksperSiz Business',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        AppText(
                          'Ekipler ve ortak şirket araçları için aylık kurumsal plan.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _BusinessPlanCard(
                          plan: _businessPlan!,
                          active: _isBusiness,
                          busy: _businessBusy,
                          storeConfigured: _billingData!.storeConfigured,
                          localizedPrice: _businessPlan!.packageIdentifier == null
                              ? null
                              : _billingData!.localizedPrices[_businessPlan!.packageIdentifier!],
                          onBuy: () => _buyBusiness(_businessPlan!),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}


class _BusinessPlanCard extends StatelessWidget {
  const _BusinessPlanCard({
    required this.plan,
    required this.active,
    required this.busy,
    required this.storeConfigured,
    required this.localizedPrice,
    required this.onBuy,
  });

  final BillingPlan plan;
  final bool active;
  final bool busy;
  final bool storeConfigured;
  final String? localizedPrice;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final fallbackPrice =
        '₺${plan.fallbackMonthlyPrice.toStringAsFixed(2).replaceAll('.', ',')}';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppTheme.deepBrandGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.elevatedShadowFor(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.business_center_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppText(
                      'Business',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    AppText(
                      plan.description,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.76),
                      ),
                    ),
                  ],
                ),
              ),
              if (active)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: const AppText(
                    'Aktif',
                    style: TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          for (final feature in plan.features) ...[
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppTheme.successColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: AppText(
                    feature,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
          ],
          const SizedBox(height: 9),
          if (active)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const AppText(
                'Business planınız aktif. Şirket araçları ve analiz kotası ekip üyelerinizle ortaktır.',
                style: TextStyle(color: Colors.white, height: 1.4),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        localizedPrice ?? fallbackPrice,
                        style: textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      AppText(
                        '/ ay',
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.68),
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryDark,
                  ),
                  onPressed: !storeConfigured || busy || plan.packageIdentifier == null
                      ? null
                      : onBuy,
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const AppText('Business’a Geç'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
