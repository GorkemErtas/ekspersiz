import 'package:flutter/material.dart';
import 'package:mobile/core/localization/app_text.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../models/analysis_quota.dart';
import '../services/analysis_quota_service.dart';
import '../services/billing_service.dart';
import '../services/revenue_cat_gateway.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final BillingService _billing = const BillingService();
  final AnalysisQuotaService _quotaService = const AnalysisQuotaService();
  BillingPageData? _billingData;
  AnalysisQuota? _quota;
  String? _busyPack;
  String? _error;

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

  String _message(Object e) => e.toString().replaceFirst('Exception: ', '').replaceFirst('Bad state: ', '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('AI Analiz Hakları')),
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
                              ? '\${_quota!.remaining} / \${_quota!.limit} şirket analizi kaldı'
                              : 'Bu ay ücretsiz: \${_quota!.freeRemaining}  •  Satın alınan: \${_quota!.purchasedCredits}'),
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
                                    AppText('\${pack.$2} detaylı analiz',
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
                        const AppText('Şirket hesabınız ortak Business analiz kotasını kullanır.'),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
