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

  static const _packs = [
    _AnalysisPack(
      id: 'analysis_1',
      count: 1,
      fallbackPrice: '₺20,00',
      unitPrice: '₺20 / analiz',
    ),
    _AnalysisPack(
      id: 'analysis_3',
      count: 3,
      fallbackPrice: '₺49,99',
      unitPrice: '≈ ₺16,67 / analiz',
      badge: 'Önerilen',
    ),
    _AnalysisPack(
      id: 'analysis_10',
      count: 10,
      fallbackPrice: '₺139,99',
      unitPrice: '≈ ₺14 / analiz',
      badge: 'En avantajlı',
    ),
  ];

  BillingPlan? get _businessPlan {
    final plans = _billingData?.overview.plans ?? const <BillingPlan>[];

    for (final plan in plans) {
      if (plan.plan == 'BUSINESS') {
        return plan;
      }
    }

    return null;
  }

  bool get _isBusiness =>
      _quota?.plan == 'BUSINESS' ||
      _billingData?.overview.status.currentPlan == 'BUSINESS';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        _billing.load(),
        _quotaService.getQuota(),
      ]);

      if (!mounted) return;

      setState(() {
        _billingData = values[0] as BillingPageData;
        _quota = values[1] as AnalysisQuota;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = _message(e);
      });
    }
  }

  Future<void> _buy(String packageId) async {
    if (_busyPack != null || _businessBusy) return;

    setState(() {
      _busyPack = packageId;
    });

    try {
      final before = await _quotaService.getQuota();

      await _billing.purchaseCreditPack(packageId);

      AnalysisQuota current = before;

      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(
          const Duration(milliseconds: 750),
        );

        current = await _quotaService.getQuota();

        if (current.purchasedCredits > before.purchasedCredits) {
          break;
        }
      }

      if (!mounted) return;

      setState(() {
        _quota = current;
      });

      _showMessage(
        current.purchasedCredits > before.purchasedCredits
            ? 'Analiz haklarınız hesabınıza eklendi.'
            : 'Ödeme alındı. Haklarınız birkaç saniye içinde hesabınıza eklenecek.',
      );
    } on BillingPurchaseCancelled {
      return;
    } catch (e) {
      if (mounted) {
        _showMessage(_message(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyPack = null;
        });
      }
    }
  }

  Future<void> _buyBusiness(BillingPlan plan) async {
    if (_businessBusy || _busyPack != null || _isBusiness) {
      return;
    }

    setState(() {
      _businessBusy = true;
    });

    try {
      await _billing.purchase(
        plan,
        currentPlan: _billingData!.overview.status.currentPlan,
        currentProductId: _billingData!.overview.status.productId,
      );

      await _load();

      if (!mounted) return;

      _showMessage(
        'Aboneliğiniz etkinleştirildi.',
      );
    } on BillingPurchaseCancelled {
      return;
    } catch (e) {
      if (mounted) {
        _showMessage(_message(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _businessBusy = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: AppText(message),
        ),
      );
  }

  String _message(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('Bad state: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppText('Planlar ve AI Hakları'),
      ),
      body: SafeArea(
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_error != null && _quota == null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const AppText('Tekrar dene'),
        ),
      );
    }

    if (_quota == null || _billingData == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 720,
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            40,
          ),
          children: [
            _buildQuotaCard(context),

            const SizedBox(height: 24),
            _buildSectionTitle(
              context,
              title: 'Aylık abonelikler',
              subtitle: 'AI Asistan ve hasar analiz haklarınızı planınıza göre artırın.',
            ),
            const SizedBox(height: 14),
            for (final plan in _billingData!.overview.plans.where(
              (item) => item.plan != 'FREE',
            )) ...[
              _BusinessPlanCard(
                plan: plan,
                active: _billingData!.overview.status.currentPlan == plan.plan,
                busy: _businessBusy,
                storeConfigured: _billingData!.storeConfigured,
                localizedPrice: plan.packageIdentifier == null
                    ? null
                    : _billingData!.localizedPrices[plan.packageIdentifier!],
                onBuy: () => _buyBusiness(plan),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotaCard(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(
          AppTheme.radiusLarge,
        ),
        border: Border.all(
          color: colors.outlineVariant.withValues(
            alpha: 0.45,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color:
                      colors.primary.withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    AppText(
                      _isBusiness
                          ? 'Business analiz kotası'
                          : 'AI analiz haklarınız',
                      style:
                          theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    const SizedBox(height: 3),
                    AppText(
                      _isBusiness
                          ? '${_quota!.remaining} / ${_quota!.limit} şirket analizi kaldı'
                          : 'Bu ay ${_quota!.freeRemaining} ücretsiz • ${_quota!.purchasedCredits} satın alınan',
                      style:
                          theme.textTheme.bodyMedium?.copyWith(
                                color:
                                    colors.onSurfaceVariant,
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Divider(
            height: 1,
            color: colors.outlineVariant.withValues(
              alpha: 0.45,
            ),
          ),

          const SizedBox(height: 14),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 19,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: AppText(
                  'Temel görsel hasar tespiti ücretsizdir. '
                  'Detaylı rapor; AI açıklaması, onarım önerileri '
                  've tahmini maliyet aralığını içerir.',
                  style:
                      theme.textTheme.bodySmall?.copyWith(
                            color:
                                colors.onSurfaceVariant,
                            height: 1.45,
                          ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        AppText(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color:
                theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AnalysisPack {
  const _AnalysisPack({
    required this.id,
    required this.count,
    required this.fallbackPrice,
    required this.unitPrice,
    this.badge,
  });

  final String id;
  final int count;
  final String fallbackPrice;
  final String unitPrice;
  final String? badge;
}

class _AnalysisPackCard extends StatelessWidget {
  const _AnalysisPackCard({
    required this.pack,
    required this.localizedPrice,
    required this.loading,
    required this.enabled,
    required this.onPressed,
  });

  final _AnalysisPack pack;
  final String? localizedPrice;
  final bool loading;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final highlighted = pack.badge != null;
    final price =
        localizedPrice ?? pack.fallbackPrice;

    return AppCard(
      showShadow: highlighted,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: highlighted
                      ? colors.primaryContainer
                      : colors.surfaceContainerHighest,
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: AppText(
                  '${pack.count}x',
                  style:
                      theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: highlighted
                                ? colors.onPrimaryContainer
                                : colors.onSurface,
                          ),
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    if (pack.badge != null) ...[
                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color:
                              colors.primaryContainer,
                          borderRadius:
                              BorderRadius.circular(
                            AppTheme.radiusPill,
                          ),
                        ),
                        child: AppText(
                          pack.badge!,
                          style:
                              theme.textTheme.labelSmall
                                  ?.copyWith(
                            color:
                                colors.onPrimaryContainer,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],

                    AppText(
                      '${pack.count} detaylı AI analizi',
                      style:
                          theme.textTheme.titleMedium
                              ?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 3),

                    AppText(
                      pack.unitPrice,
                      style:
                          theme.textTheme.bodySmall
                              ?.copyWith(
                        color:
                            colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed:
                  enabled && !loading
                      ? onPressed
                      : null,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 2,
                ),
                child: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : AppText(
                        '$price ile satın al',
                      ),
              ),
            ),
          ),
        ],
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
    final theme = Theme.of(context);

    final fallbackPrice =
        '₺${plan.fallbackMonthlyPrice.toStringAsFixed(2).replaceAll('.', ',')}';

    final price =
        localizedPrice ?? fallbackPrice;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.deepBrandGradient,
        borderRadius: BorderRadius.circular(
          AppTheme.radiusLarge,
        ),
        boxShadow:
            AppTheme.elevatedShadowFor(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.12,
                  ),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.business_center_rounded,
                  color: Colors.white,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: AppText(
                            'Business',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                        ),

                        if (active)
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.successColor
                                  .withValues(
                                alpha: 0.18,
                              ),
                              borderRadius:
                                  BorderRadius.circular(
                                AppTheme.radiusPill,
                              ),
                            ),
                            child: const AppText(
                              'Aktif',
                              style: TextStyle(
                                color:
                                    AppTheme.successColor,
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    AppText(
                      plan.description,
                      style:
                          theme.textTheme.bodyMedium
                              ?.copyWith(
                        color: Colors.white
                            .withValues(alpha: 0.72),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          for (final feature in plan.features) ...[
            _BusinessFeature(
              text: feature,
            ),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 8),

          if (active)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: 0.09,
                ),
                borderRadius:
                    BorderRadius.circular(14),
              ),
              child: const AppText(
                'Business planınız aktif. Şirket araçları ve '
                'analiz kotası ekip üyelerinizle ortaktır.',
                style: TextStyle(
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
            )
          else ...[
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: AppText(
                    price,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        theme.textTheme.headlineSmall
                            ?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),

                const SizedBox(width: 7),

                Padding(
                  padding:
                      const EdgeInsets.only(bottom: 3),
                  child: AppText(
                    '/ ay',
                    style:
                        theme.textTheme.bodyMedium
                            ?.copyWith(
                      color: Colors.white
                          .withValues(alpha: 0.68),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor:
                      AppTheme.primaryDark,
                ),
                onPressed:
                    !storeConfigured ||
                            busy ||
                            plan.packageIdentifier ==
                                null
                        ? null
                        : onBuy,
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const AppText(
                        'Business’a Geç',
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BusinessFeature extends StatelessWidget {
  const _BusinessFeature({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.check_circle_rounded,
            color: AppTheme.successColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppText(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}