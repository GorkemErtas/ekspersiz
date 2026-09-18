import 'package:mobile/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../models/billing_overview.dart';
import '../models/billing_plan.dart';
import '../services/billing_service.dart';
import '../services/revenue_cat_gateway.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({
    super.key,
    this.billingService = const BillingService(),
  });

  final BillingService billingService;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  BillingPageData? _data;
  String? _error;
  String? _busyPlan;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
    });

    try {
      final data = await widget.billingService.load();

      if (mounted) {
        setState(() {
          _data = data;
        });
      }
    } catch (exception) {
      if (mounted) {
        setState(() {
          _error = _message(exception);
        });
      }
    }
  }

  Future<void> _purchase(BillingPlan plan) async {
    final data = _data;

    if (data == null) {
      return;
    }

    setState(() {
      _busyPlan = plan.plan;
    });

    try {
      final overview = await widget.billingService.purchase(
        plan,
        currentPlan: data.overview.status.currentPlan,
        currentProductId: data.overview.status.productId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _data = BillingPageData(
          overview: overview,
          storeConfigured: data.storeConfigured,
          localizedPrices: data.localizedPrices,
        );
      });
      _showMessage('${plan.title} planınız aktif edildi.');
    } on BillingPurchaseCancelled {
      return;
    } catch (exception) {
      if (mounted) {
        _showMessage(_message(exception));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyPlan = null;
        });
      }
    }
  }

  Future<void> _restore() async {
    final data = _data;

    if (data == null) {
      return;
    }

    setState(() {
      _restoring = true;
    });

    try {
      final overview = await widget.billingService.restore();

      if (!mounted) {
        return;
      }

      setState(() {
        _data = BillingPageData(
          overview: overview,
          storeConfigured: data.storeConfigured,
          localizedPrices: data.localizedPrices,
        );
      });
      _showMessage('Satın alımlarınız geri yüklendi.');
    } catch (exception) {
      if (mounted) {
        _showMessage(_message(exception));
      }
    } finally {
      if (mounted) {
        setState(() {
          _restoring = false;
        });
      }
    }
  }

  Future<void> _manageSubscription() async {
    final url = _data?.overview.status.managementUrl;

    if (url == null ||
        !await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        )) {
      if (mounted) {
        _showMessage('Abonelik yönetimi açılamadı.');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: AppText(message), behavior: SnackBarBehavior.floating),
      );
  }

  String _message(Object exception) {
    return exception
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('Bad state: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _busyPlan == null && !_restoring,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const AppText('Abonelik ve Ödeme')),
        body: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_data == null && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_data == null) {
      return Center(
        child: Padding(
          padding: AppTheme.pagePadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppText(_error ?? 'Abonelik bilgisi alınamadı.'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const AppText('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _data!;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppTheme.maxContentWidth),
        child: ListView(
          padding: AppTheme.pagePadding,
          children: [
            _CurrentSubscriptionCard(overview: data.overview),
            if (!data.storeConfigured) ...[
              const SizedBox(height: 16),
              AppCard(
                showShadow: false,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: AppText(
                        'Satın alma anahtarı bu sürümde tanımlı değil. '
                        'Planları inceleyebilirsiniz; ödeme düğmeleri mağaza '
                        'yapılandırması tamamlandığında açılır.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            AppText(
              'Planlar',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            for (final plan in data.overview.plans) ...[
              _PlanCard(
                plan: plan,
                currentPlan: data.overview.status.currentPlan,
                localizedPrice: data.localizedPrices[plan.packageIdentifier],
                storeConfigured: data.storeConfigured,
                loading: _busyPlan == plan.plan,
                disabled: _busyPlan != null || _restoring,
                onPurchase: () => _purchase(plan),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            if (data.storeConfigured)
              OutlinedButton.icon(
                onPressed: _restoring || _busyPlan != null ? null : _restore,
                icon: _restoring
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.restore_rounded),
                label: const AppText('Satın Alımları Geri Yükle'),
              ),
            if (data.overview.status.managementUrl != null) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _manageSubscription,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const AppText('Aboneliği Mağazada Yönet'),
              ),
            ],
            const SizedBox(height: 16),
            AppText(
              'Ödeme Apple App Store veya Google Play tarafından güvenli '
              'şekilde alınır. Abonelik iptal edilmediği sürece aylık yenilenir. '
              'İptalden sonra mevcut fatura döneminin sonuna kadar erişim sürer.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentSubscriptionCard extends StatelessWidget {
  const _CurrentSubscriptionCard({required this.overview});

  final BillingOverview overview;

  @override
  Widget build(BuildContext context) {
    final status = overview.status;
    final plan = overview.plans
        .where((item) => item.plan == status.currentPlan)
        .firstOrNull;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'Mevcut plan',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AppText(
                      plan?.title ?? status.currentPlan,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              AppStatusBadge(
                label: _statusLabel(status.status),
                color: status.currentPlan == 'FREE'
                    ? AppTheme.neutralColorFor(context)
                    : AppTheme.successColorFor(context),
                backgroundColor: status.currentPlan == 'FREE'
                    ? AppTheme.neutralSoftFor(context)
                    : AppTheme.successSoftFor(context),
                icon: Icons.verified_rounded,
              ),
            ],
          ),
          if (status.currentPeriodEndsAt != null) ...[
            const SizedBox(height: 14),
            AppText(
              status.autoRenewing
                  ? 'Sonraki yenileme: ${_date(status.currentPeriodEndsAt!)}'
                  : 'Erişim bitişi: ${_date(status.currentPeriodEndsAt!)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (status.sandbox) ...[
            const SizedBox(height: 8),
            AppText(
              'Test mağazası işlemi',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _statusLabel(String status) {
    return switch (status) {
      'ACTIVE' => 'Aktif',
      'CANCELLED' => 'İptal edildi',
      'BILLING_ISSUE' => 'Ödeme sorunu',
      'EXPIRED' => 'Süresi doldu',
      _ => 'Ücretsiz',
    };
  }

  static String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.${local.year}';
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.currentPlan,
    required this.localizedPrice,
    required this.storeConfigured,
    required this.loading,
    required this.disabled,
    required this.onPurchase,
  });

  final BillingPlan plan;
  final String currentPlan;
  final String? localizedPrice;
  final bool storeConfigured;
  final bool loading;
  final bool disabled;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    final isCurrent = plan.plan == currentPlan;
    final canPurchase = plan.plan != 'FREE' && storeConfigured && !disabled;

    return AppCard(
      showShadow: plan.highlighted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText(
                  plan.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              if (plan.highlighted)
                AppStatusBadge(
                  label: 'Önerilen',
                  color: Theme.of(context).colorScheme.primary,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  icon: Icons.auto_awesome_rounded,
                ),
            ],
          ),
          const SizedBox(height: 6),
          AppText(
            plan.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          AppText(
            _price(),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          for (final feature in plan.features)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 19,
                    color: AppTheme.successColorFor(context),
                  ),
                  const SizedBox(width: 9),
                  Expanded(child: AppText(feature)),
                ],
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: isCurrent
                ? OutlinedButton(
                    onPressed: null,
                    child: const AppText('Mevcut Plan'),
                  )
                : FilledButton(
                    onPressed: canPurchase ? onPurchase : null,
                    child: loading
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : AppText(
                            plan.plan == 'FREE'
                                ? 'Ücretsiz Plan'
                                : 'Mağazadan Abone Ol',
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  String _price() {
    if (plan.plan == 'FREE') {
      return 'Ücretsiz';
    }

    if (localizedPrice != null) {
      return '$localizedPrice / ay';
    }

    final price = plan.fallbackMonthlyPrice
        .toStringAsFixed(2)
        .replaceAll('.', ',');
    return '₺$price / ay';
  }
}
