import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/localization/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/workspace/workspace_session.dart';
import '../../../core/workspace/workspace_service.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/models/business_account.dart';
import '../../business/screens/business_management_screen.dart';
import '../../business/services/business_service.dart';
import '../models/billing_plan.dart';
import '../models/credit_catalog.dart';
import '../services/analysis_quota_service.dart';
import '../services/billing_service.dart';
import '../services/revenue_cat_gateway.dart';
import '../services/welcome_credit_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({
    super.key,
    this.billingService = const BillingService(),
    this.quotaService = const AnalysisQuotaService(),
    this.initialCategory = 0,
    this.preferCompany = false,
    this.authService = const AuthService(),
    this.businessService = const BusinessService(),
  });
  final BillingService billingService;
  final AnalysisQuotaService quotaService;
  final int initialCategory;
  final bool preferCompany;
  final AuthService authService;
  final BusinessService businessService;
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with WidgetsBindingObserver {
  BillingPageData? _billing;
  CreditOverview? _credits;
  String? _error;
  String? _notice;
  bool _busy = false;
  bool _company = false;
  Future<void>? _refreshing;
  late int _category = widget.initialCategory.clamp(0, 2);
  static const _resources = ['ANALYSIS', 'ASSISTANT', 'SLOT'];
  static const _labels = ['Hasar analizi', 'AI Asistan', 'Araç slotları'];
  CreditAccount get _account =>
      _company ? _credits!.company! : _credits!.personal!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) _load();
  }

  Future<void> _load() =>
      _refreshing ??= _loadData().whenComplete(() => _refreshing = null);

  Future<void> _loadData() async {
    final scope = WorkspaceSession.capture();
    try {
      final billing = await widget.billingService.load();
      final credits = await widget.billingService.credits();
      WorkspaceSession.check(scope);
      if (!mounted) return;
      final workspace = WorkspaceSession.state.value;
      if (workspace != null &&
          (workspace.isBusiness
              ? credits.company == null
              : credits.personal == null)) {
        throw StateError('Seçili çalışma alanının bakiyesi alınamadı.');
      }
      setState(() {
        if (WorkspaceSession.state.value != null) {
          _company = WorkspaceSession.state.value!.isBusiness;
        } else if (_credits == null && widget.preferCompany) {
          _company = credits.company != null;
        }
        _billing = billing;
        _credits = credits;
        _error = null;
        _notice = null;
        if (workspace == null && credits.company == null) _company = false;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

  String _message(Object e) => e
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '');
  void _show(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: AppText(text)));
  }

  Future<void> _perform(Future<String> Function() action) async {
    if (_busy) return;
    final scope = WorkspaceSession.capture();
    setState(() => _busy = true);
    try {
      await _refreshing;
      WorkspaceSession.check(scope);
      final message = await action();
      if (!mounted) return;
      await _load();
      if (mounted) setState(() => _notice = message);
      _show(message);
    } on BillingPurchaseCancelled {
      /* A cancelled payment grants nothing. */
    } on BillingPurchasePending {
      if (!mounted) return;
      const message =
          'Satın alma henüz doğrulanmadı. Ödeme veya sunucu doğrulaması bekleniyor. Tekrar ödeme yapmadan yeniden kontrol edin.';
      setState(() => _notice = message);
      _show(message);
    } catch (e) {
      if (mounted) setState(() => _notice = _message(e));
      _show(_message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _purchase(CreditProduct product) => _perform(() async {
    final confirmed = await widget.billingService.purchaseCredit(product);
    return confirmed
        ? 'Satın alma doğrulandı. Bakiyeniz güncellendi.'
        : 'Ödemeniz doğrulanıyor. Krediler doğrulama tamamlanınca otomatik eklenecek.';
  });
  Future<void> _subscribe(BillingPlan plan) => _perform(() async {
    final result = await widget.billingService.purchase(
      plan,
      currentPlan: _billing!.overview.status.currentPlan,
      currentProductId: _billing!.overview.status.productId,
    );
    if (result.status.currentPlan == 'BUSINESS') {
      await _continueBusiness();
      return WorkspaceSession.state.value?.isBusiness == true
          ? 'Business aboneliğiniz doğrulandı. Business çalışma alanına geçildi.'
          : 'Business aboneliğiniz doğrulandı. Şirket kurulumuna tekrar ödeme yapmadan devam edebilirsiniz.';
    }
    return _verificationMessage(result.status.verificationStatus);
  });
  Future<void> _restore() => _perform(() async {
    final result = await widget.billingService.restore();
    return result.status.currentPlan == 'BUSINESS'
        ? 'Business aboneliğiniz doğrulandı. Şirket kurulumuna devam edebilirsiniz.'
        : _verificationMessage(result.status.verificationStatus);
  });
  String _verificationMessage(String status) => status == 'SANDBOX_REJECTED'
      ? 'Bu test satın alımı sandbox ortamında. Bu sunucu sandbox aboneliklerine Business hakkı vermez. Tekrar satın almayın.'
      : 'Aktif Business aboneliği henüz sunucu tarafından doğrulanmadı. Tekrar ödeme yapmadan yeniden kontrol edin.';

  Future<void> _continueBusiness() async {
    final profile = await widget.authService.getCurrentUser();
    if (!mounted) return;
    if (profile.businessAccount != null) {
      await const WorkspaceService().select(WorkspaceType.business);
      return;
    }
    if (profile.subscriptionPlan != 'BUSINESS') {
      throw StateError(
        'Business aboneliğiniz doğrulanamadı. Yeniden kontrol edin.',
      );
    }
    await Navigator.of(context).push<BusinessAccount>(
      MaterialPageRoute<BusinessAccount>(
        builder: (_) => BusinessManagementScreen(
          subscriptionPlan: profile.subscriptionPlan,
          authService: widget.authService,
          businessService: widget.businessService,
        ),
      ),
    );
  }

  Future<void> _welcome() => _perform(() async {
    return WelcomeCreditService.claim().timeout(const Duration(seconds: 30));
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const AppText('Krediler ve Paketler'),
      actions: [
        IconButton(
          onPressed: _busy ? null : _load,
          tooltip: 'Bakiyeyi yenile',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: _credits == null || _billing == null
          ? (_error == null
                ? const AppStateView.loading()
                : AppStateView.error(message: _error!, onActionPressed: _load))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(AppTheme.pageInset),
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AppText(_error!),
                        ),
                      if (_notice != null ||
                          _billing!.overview.status.verificationStatus ==
                              'SANDBOX_REJECTED')
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText(
                                  _billing!
                                              .overview
                                              .status
                                              .verificationStatus ==
                                          'SANDBOX_REJECTED'
                                      ? _verificationMessage('SANDBOX_REJECTED')
                                      : _notice!,
                                ),
                                TextButton.icon(
                                  onPressed: _busy ? null : _load,
                                  icon: const Icon(Icons.refresh),
                                  label: const AppText('Yeniden kontrol et'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (WorkspaceSession.state.value == null &&
                          _credits!.company != null) ...[
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: false,
                              label: AppText('Kişisel'),
                            ),
                            ButtonSegment(
                              value: true,
                              label: AppText('Şirket'),
                            ),
                          ],
                          selected: {_company},
                          onSelectionChanged: _busy
                              ? null
                              : (value) =>
                                    setState(() => _company = value.first),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _balanceCard(context),
                      if ([
                        'PLUS',
                        'PRO',
                      ].contains(_billing!.overview.status.currentPlan))
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const AppText(
                                  'Önceki aboneliğinizin ödenmiş dönem hakları korunur. Yeni bireysel alımlar kredi paketleriyle yapılır.',
                                ),
                                TextButton(
                                  onPressed: _manage,
                                  child: const AppText(
                                    'Önceki aboneliği yönet / iptal et',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(
                          3,
                          (i) => ChoiceChip(
                            label: AppText(_labels[i]),
                            selected: i == _category,
                            onSelected: (_) => setState(() => _category = i),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppText(
                        _category == 2
                            ? 'Ek slotlar kalıcıdır. Arşivlenen veya silinen aracın slotunu tekrar kullanabilirsiniz.'
                            : 'Satın aldığınız krediler süresizdir. Her başarılı işlem 1 kredi kullanır.',
                      ),
                      if (!_account.canPurchase)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: AppText(
                            _account.owner
                                ? 'Şirket adına kredi alabilmek için Business aboneliğinizi yenileyin.'
                                : 'Şirket adına satın alımları yalnızca şirket sahibi yapabilir.',
                          ),
                        ),
                      const SizedBox(height: 12),
                      for (final product in _credits!.products.where(
                        (p) =>
                            p.business == _company &&
                            p.resource == _resources[_category],
                      ))
                        _productCard(context, product),
                      const SizedBox(height: 20),
                      if (WorkspaceSession.state.value?.role != 'MEMBER' &&
                          (_credits!.company == null ||
                              _credits!.company!.owner))
                        for (final plan in _billing!.overview.plans.where(
                          (p) => p.plan == 'BUSINESS',
                        ))
                          _businessCard(context, plan),
                      const SizedBox(height: 16),
                      if (!_company)
                        TextButton(
                          onPressed: _busy ? null : _welcome,
                          child: const AppText(
                            'Başlangıç kredilerimi kontrol et',
                          ),
                        ),
                      TextButton(
                        onPressed: _busy || !_billing!.storeConfigured
                            ? null
                            : _restore,
                        child: const AppText(
                          'Satın alımları geri yükle / kontrol et',
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    ),
  );
  Widget _balanceCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppTheme.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            _company ? 'Şirketin ortak bakiyesi' : 'Kişisel bakiyeniz',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 12,
            children: [
              AppText('${_account.available('ANALYSIS')} analiz kredisi'),
              AppText('${_account.available('ASSISTANT')} asistan kredisi'),
              AppText(
                '${_account.usedSlots} / ${_account.totalSlots} araç slotu',
              ),
            ],
          ),
          if (_company) ...[
            const SizedBox(height: 8),
            AppText(
              'Dönemlik: ${_account.periodic('ANALYSIS')} analiz · ${_account.periodic('ASSISTANT')} soru. Önce dönemlik krediler kullanılır; dönem sonunda kalan haklar devretmez.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    ),
  );
  Widget _productCard(BuildContext context, CreditProduct product) {
    final price = _billing!.storePrices[product.id];
    final singleId =
        'eksper_${product.resource.toLowerCase()}_1${_company ? '_business' : ''}';
    final savings = PriceSavings.compare(
      price,
      _billing!.storePrices[singleId],
      product.quantity,
    );
    final available =
        price != null && _billing!.storeConfigured && _account.canPurchase;
    final reference = const StorePrice(
      0,
      'TRY',
      '',
    ).format(product.referencePrice);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                AppText(
                  '${product.quantity} ${product.resource == 'SLOT' ? 'ek araç slotu' : 'kredi'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                AppText(
                  price?.label ?? 'Referans fiyat: $reference',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            if (price != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: AppText(
                  '${price.format(price.amount / product.quantity)} / ${product.resource == 'SLOT' ? 'slot' : 'kredi'}',
                ),
              ),
            if (savings != null) ...[
              const SizedBox(height: 6),
              AppText(
                'Tekli alım: ${price!.format(savings.regular)}',
                style: const TextStyle(decoration: TextDecoration.lineThrough),
              ),
              AppText(
                '%${savings.percentLabel} indirim · ${price.format(savings.amount)} tasarruf',
                style: TextStyle(
                  color: AppTheme.successColorFor(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy || !available
                    ? null
                    : () => _purchase(product),
                child: AppText(
                  price == null ? 'Mağazada henüz kullanılamıyor' : 'Satın al',
                ),
              ),
            ),
            if (price == null)
              const AppText('Tahsilat fiyatı mağaza tarafından belirlenir.'),
          ],
        ),
      ),
    );
  }

  Widget _businessCard(BuildContext context, BillingPlan plan) {
    final status = _billing!.overview.status;
    final price = _billing!.storePrices[plan.packageIdentifier];
    final analysis = _billing!.storePrices['eksper_analysis_1'];
    final assistant = _billing!.storePrices['eksper_assistant_1'];
    final regular =
        analysis != null &&
            assistant != null &&
            price != null &&
            analysis.currency == price.currency &&
            assistant.currency == price.currency
        ? analysis.amount * 100 + assistant.amount * 200
        : null;
    final savings = regular != null && regular > price!.amount
        ? regular - price.amount
        : null;
    final active = status.currentPlan == 'BUSINESS';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              'Business${active ? ' · Abonelik aktif' : ''}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            AppText(
              '${price?.label ?? 'Referans: 4.999,99 TL'} / ay',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const AppText(
              '10 ortak araç slotu\nHer dönemde 100 analiz + 200 asistan kredisi\nÇalışan daveti ve ortak araç yönetimi',
            ),
            const SizedBox(height: 8),
            const AppText(
              'Haklar şirketin tamamı içindir. Dönemlik krediler devretmez; ayrıca satın alınan krediler süresizdir.',
            ),
            if (savings != null) ...[
              const SizedBox(height: 10),
              AppText(
                '100 analiz × ${analysis!.format(analysis.amount)} = ${analysis.format(analysis.amount * 100)}',
              ),
              AppText(
                '200 asistan × ${assistant!.format(assistant.amount)} = ${assistant.format(assistant.amount * 200)}',
              ),
              AppText(
                'Kredilerin tekli alım değeri: ${price!.format(regular!)}',
              ),
              AppText(
                'Tekli alıma göre ${price.format(savings)} (%${(savings / regular * 100).toStringAsFixed(2).replaceAll('.', ',')}) tasarruf.',
              ),
              const AppText(
                'Karşılaştırma tekli kredi fiyatlarıyladır; indirimli paketler dahil değildir.',
              ),
            ],
            const SizedBox(height: 12),
            if (active) ...[
              AppText(
                WorkspaceSession.state.value?.isBusiness == true
                    ? 'Aktif çalışma alanı: Business'
                    : 'Aktif çalışma alanı: Kişisel',
              ),
              if (WorkspaceSession.state.value?.isBusiness != true)
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _perform(() async {
                          await _continueBusiness();
                          return 'Business kurulumu kontrol edildi.';
                        }),
                  icon: const Icon(Icons.business_outlined),
                  label: AppText(
                    WorkspaceSession.state.value?.businessId == null
                        ? 'Şirketini oluştur'
                        : 'Business çalışma alanına geç',
                  ),
                ),
              AppText(
                status.autoRenewing
                    ? 'Aboneliğiniz otomatik yenilenir.'
                    : 'Yenileme kapalı. Haklarınız ödenmiş dönem sonuna kadar devam eder.',
              ),
              if (status.currentPeriodEndsAt != null)
                AppText(
                  'Dönem sonu: ${status.currentPeriodEndsAt!.day}.${status.currentPeriodEndsAt!.month}.${status.currentPeriodEndsAt!.year}',
                ),
              TextButton(
                onPressed: _manage,
                child: const AppText('Aboneliği yönet / iptal et'),
              ),
            ] else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy || price == null
                      ? null
                      : () => _subscribe(plan),
                  child: AppText(
                    price == null
                        ? 'Mağazada henüz kullanılamıyor'
                        : 'Business’a geç',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _manage() async {
    final raw = _billing?.overview.status.managementUrl;
    final uri = raw == null ? null : Uri.tryParse(raw);
    try {
      if (!await launchUrl(
        uri != null && uri.scheme == 'https'
            ? uri
            : Uri.parse('https://play.google.com/store/account/subscriptions'),
        mode: LaunchMode.externalApplication,
      )) {
        _show(
          'Abonelik yönetimi açılamadı. Google Play aboneliklerinizi kontrol edin.',
        );
      }
    } catch (_) {
      _show('Abonelik yönetimi açılamadı.');
    }
  }
}
