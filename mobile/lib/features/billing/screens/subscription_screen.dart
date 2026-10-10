import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile/core/localization/app_text.dart';

import '../../../core/theme/app_theme.dart';
import '../models/analysis_quota.dart';
import '../models/billing_plan.dart';
import '../models/billing_status.dart';
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

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with WidgetsBindingObserver {
  BillingService get _billing => widget.billingService;
  AnalysisQuotaService get _quotaService => widget.quotaService;

  BillingPageData? _billingData;
  AnalysisQuota? _quota;

  bool _purchaseBusy = false;
  String? _error;

  bool get _isBusiness =>
      _quota?.plan == 'BUSINESS' ||
      _billingData?.overview.status.currentPlan == 'BUSINESS';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _manageSubscription(BillingStatus status) async {
    final rawUrl = status.managementUrl;
    final uri = rawUrl == null ? null : Uri.tryParse(rawUrl);
    final destination = uri != null && uri.scheme == 'https'
        ? uri
        : Uri.parse('https://play.google.com/store/account/subscriptions');
    try {
      if (!await launchUrl(destination, mode: LaunchMode.externalApplication)) {
        throw StateError('Abonelik yönetimi açılamadı. Google Play üzerinden aboneliklerinizi kontrol edin.');
      }
    } catch (_) {
      if (mounted) _showMessage('Abonelik yönetimi açılamadı. Google Play > Ödemeler ve abonelikler bölümünü açın.');
    }
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

  Future<void> _subscribe(BillingPlan plan) async {
    if (_purchaseBusy ||
        _billingData?.overview.status.currentPlan == plan.plan) {
      return;
    }

    setState(() {
      _purchaseBusy = true;
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
          _purchaseBusy = false;
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
            if (_billingData!.overview.status.currentPlan != 'FREE') ...[
              const SizedBox(height: 12),
              _buildSubscriptionStatus(context, _billingData!.overview.status),
            ],

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
              _SubscriptionPlanCard(
                plan: plan,
                active: _billingData!.overview.status.currentPlan == plan.plan,
                busy: _purchaseBusy,
                storeConfigured: _billingData!.storeConfigured,
                localizedPrice: plan.packageIdentifier == null
                    ? null
                    : _billingData!.localizedPrices[plan.packageIdentifier!],
                onBuy: () => _subscribe(plan),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionStatus(BuildContext context, BillingStatus status) {
    final theme = Theme.of(context);
    final endsAt = status.currentPeriodEndsAt?.toLocal();
    final dateLabel = endsAt == null
        ? null
        : '${endsAt.day.toString().padLeft(2, '0')}.${endsAt.month.toString().padLeft(2, '0')}.${endsAt.year}';
    final cancelled = status.status == 'CANCELLED' || !status.autoRenewing;
    final message = cancelled
        ? (dateLabel == null
            ? 'Aboneliğiniz iptal edildi. Mevcut haklarınız ödenmiş dönem sonuna kadar devam eder.'
            : 'Aboneliğiniz iptal edildi. Haklarınız $dateLabel tarihine kadar devam eder.')
        : (dateLabel == null
            ? 'Aboneliğiniz aktif.'
            : 'Aboneliğiniz aktif. Sonraki yenileme: $dateLabel');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            cancelled ? Icons.event_available_outlined : Icons.autorenew_rounded,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(message),
                if (!cancelled) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _manageSubscription(status),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const AppText('Aboneliği İptal Et'),
                  ),
                  const SizedBox(height: 4),
                  const AppText(
                    'Google Play üzerinden otomatik yenilemeyi kapatabilirsiniz. '
                    'Mevcut haklarınız abonelik dönemi bitene kadar devam eder.',
                  ),
                ],
              ],
            ),
          ),
        ],
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
                          ? 'Business aylık analiz kotası'
                          : 'Aylık analiz kotanız',
                      style:
                          theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    const SizedBox(height: 3),
                    AppText(
                      _isBusiness
                          ? '${_quota!.remaining} / ${_quota!.limit} şirket analizi kaldı'
                          : 'Bu ay ${_quota!.freeRemaining} / ${_quota!.limit} analiz hakkı kaldı'
                              '${_quota!.purchasedCredits > 0 ? ' • ${_quota!.purchasedCredits} eski kredi' : ''}',
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

class _SubscriptionPlanCard extends StatelessWidget {
  const _SubscriptionPlanCard({
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
                child: Icon(
                  plan.plan == 'BUSINESS'
                      ? Icons.business_center_rounded
                      : Icons.workspace_premium_rounded,
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
                        Expanded(
                          child: AppText(
                            plan.title,
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
            _SubscriptionFeature(
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
              child: AppText(
                plan.plan == 'BUSINESS'
                    ? 'Business planınız aktif. Şirket araçları ve analiz kotası ekip üyelerinizle ortaktır.'
                    : '${plan.title} aboneliğiniz aktif. Plan haklarınız kullanımınıza açıktır.',
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
                        'Abone Ol',
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubscriptionFeature extends StatelessWidget {
  const _SubscriptionFeature({
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