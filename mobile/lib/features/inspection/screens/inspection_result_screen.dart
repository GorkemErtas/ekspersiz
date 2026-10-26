import 'package:mobile/core/localization/app_text.dart';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';

import '../models/damage_inspection.dart';
import '../models/inspection_report_content.dart';
import '../services/inspection_pdf_service.dart';
import '../services/inspection_service.dart';
import 'damage_assessment_record_screen.dart';
import 'nearby_services_screen.dart';
import '../../billing/screens/subscription_screen.dart';

class InspectionResultScreen extends StatefulWidget {
  const InspectionResultScreen({
    super.key,
    required this.inspection,
    this.inspectionService = const InspectionService(),
  });

  final DamageInspection inspection;
  final InspectionService inspectionService;

  @override
  State<InspectionResultScreen> createState() => _InspectionResultScreenState();
}

class _InspectionResultScreenState extends State<InspectionResultScreen>
    with WidgetsBindingObserver {
  late DamageInspection _inspection;
  Future<Uint8List>? _inspectionImageFuture;
  Object _imageLifetime = Object();

  bool _isRegeneratingReport = false;
  bool _isSharingPdf = false;
  Timer? _reportRefreshTimer;
  Timer? _reportRefreshDeadline;
  bool _checkingReport = false;
  bool _reportRefreshStopped = false;

  @override
  void initState() {
    super.initState();

    _inspection = widget.inspection;
    _inspectionService.images.addListener(_clearInspectionImage);
    WidgetsBinding.instance.addObserver(this);
    _loadInspectionImage();
    _scheduleReportRefresh();
  }

  void _clearInspectionImage() {
    if (!mounted) return;
    final invalidation = _inspectionService.images.invalidation;
    if (invalidation.inspectionId != null &&
        invalidation.inspectionId != _inspection.id) {
      return;
    }
    // A discarded request can finish after cleanup, even with its card offscreen.
    _inspectionImageFuture?.ignore();
    setState(() {
      _imageLifetime = Object();
      _inspectionImageFuture =
          _hasInspectionImage && !invalidation.resourceRelease
          ? Future.value(Uint8List(0))
          : null;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(_loadInspectionImage);
      if (_inspection.isProcessing || _inspection.isReportProcessing) {
        _refreshReportStatus(restart: true);
      }
    }
  }

  @override
  void dispose() {
    _reportRefreshTimer?.cancel();
    _reportRefreshDeadline?.cancel();
    _inspectionService.images.removeListener(_clearInspectionImage);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(InspectionResultScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.inspectionService != widget.inspectionService) {
      oldWidget.inspectionService.images.removeListener(_clearInspectionImage);
      _inspectionService.images.addListener(_clearInspectionImage);
    }
    if (oldWidget.inspection != widget.inspection ||
        oldWidget.inspectionService != widget.inspectionService) {
      _inspection = widget.inspection;
      _imageLifetime = Object();
      _loadInspectionImage();
      _resetReportRefresh();
      _scheduleReportRefresh();
    }
  }

  InspectionService get _inspectionService => widget.inspectionService;

  bool get _hasInspectionImage =>
      _inspection.imagePath?.trim().isNotEmpty == true;

  void _loadInspectionImage({bool forceRefresh = false}) {
    _inspectionImageFuture = _hasInspectionImage
        ? _inspectionService.getInspectionImage(
            _inspection.id,
            forceRefresh: forceRefresh,
          )
        : null;
    // A fast failure can precede the next frame (or an offscreen card build).
    // FutureBuilder still receives the same future and displays its real error.
    _inspectionImageFuture?.ignore();
  }

  void _retryInspectionImage() {
    setState(() {
      _imageLifetime = Object();
      _loadInspectionImage(forceRefresh: true);
    });
  }

  Future<void> _regenerateReport({bool recoverStalled = false}) async {
    if (_isRegeneratingReport) {
      return;
    }

    setState(() {
      _isRegeneratingReport = true;
    });

    try {
      DamageInspection updated;
      try {
        // A previous report POST can finish after its HTTP response is lost.
        // Always read its state before starting another Gemini request.
        final current = await _inspectionService.getInspectionById(
          _inspection.id,
        );
        if (!mounted) return;
        setState(() => _applyInspection(current));
        if ((current.isReportProcessing && !recoverStalled) ||
            (current.report != null && current.isReportCompleted)) {
          _scheduleReportRefresh();
          return;
        }
        updated = await _inspectionService.regenerateReport(_inspection.id);
      } on ApiException catch (exception) {
        if (exception.statusCode != 402) {
          rethrow;
        }

        if (mounted) {
          setState(() => _isRegeneratingReport = false);
        }

        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
        );
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _applyInspection(updated);
      });
      _resetReportRefresh();
      _scheduleReportRefresh();
    } catch (exception) {
      if (!mounted) {
        return;
      }

      // Recover a completed/in-flight report without repeating image analysis or billing.
      try {
        final current = await _inspectionService.getInspectionById(
          _inspection.id,
        );
        if (!mounted) return;
        setState(() => _applyInspection(current));
        _resetReportRefresh();
        _scheduleReportRefresh();
        if (current.isReportProcessing || current.report != null) return;
      } catch (_) {
        if (!mounted) return;
      }

      final message = exception is ApiException
          ? exception.message
          : 'Rapor yeniden oluşturulamadı.';

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: AppText(message)));
    } finally {
      if (mounted) {
        setState(() {
          _isRegeneratingReport = false;
        });
      }
    }
  }

  void _applyInspection(DamageInspection updated) {
    final imageChanged = _inspection.imagePath != updated.imagePath;
    _inspection = updated;
    if (imageChanged) {
      _imageLifetime = Object();
      _loadInspectionImage();
    }
  }

  void _scheduleReportRefresh() {
    _reportRefreshTimer?.cancel();
    if (!_inspection.isProcessing && !_inspection.isReportProcessing) {
      _resetReportRefresh();
      return;
    }
    if (_reportRefreshStopped) return;
    _reportRefreshDeadline ??= Timer(const Duration(minutes: 3), () {
      _reportRefreshTimer?.cancel();
      if (mounted) setState(() => _reportRefreshStopped = true);
    });
    _reportRefreshTimer = Timer(
      const Duration(seconds: 2),
      _refreshReportStatus,
    );
  }

  void _resetReportRefresh() {
    _reportRefreshTimer?.cancel();
    _reportRefreshDeadline?.cancel();
    _reportRefreshDeadline = null;
    _reportRefreshStopped = false;
  }

  Future<void> _refreshReportStatus({bool restart = false}) async {
    if (!mounted || _checkingReport) return;
    if (restart) {
      setState(_resetReportRefresh);
    }
    _checkingReport = true;
    try {
      final current = await _inspectionService.getInspectionById(
        _inspection.id,
      );
      if (mounted) setState(() => _applyInspection(current));
    } catch (_) {
      // Preserve the visible findings during a transient connection failure.
    } finally {
      _checkingReport = false;
      if (mounted) _scheduleReportRefresh();
    }
  }

  Future<void> _openNearbyServices() async {
    final latitude = _inspection.locationLatitude;
    final longitude = _inspection.locationLongitude;

    if (latitude == null || longitude == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => NearbyServicesScreen(
          inspectionId: _inspection.id,
          latitude: latitude,
          longitude: longitude,
        ),
      ),
    );
  }

  Future<void> _openDamageRecord() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            DamageAssessmentRecordScreen(inspection: _inspection),
      ),
    );
  }

  Future<void> _sharePdf(BuildContext buttonContext) async {
    if (_isSharingPdf || !_inspection.isCompleted) return;
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _isSharingPdf = true);
    try {
      await InspectionPdfService(
        inspectionService: _inspectionService,
      ).createAndShare(_inspection, sharePositionOrigin: origin);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('PDF oluşturulamadı. Lütfen tekrar deneyin.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSharingPdf = false);
    }
  }

  String _formatDate(DateTime? date) => date == null
      ? '-'
      : '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  @override
  Widget build(BuildContext context) {
    final content = InspectionReportContent(_inspection);
    final report = _inspection.report;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final findings = content.findings;
    final uncertain = _inspection.needsMorePhotos;
    final severityColor = _inspection.isCompleted && !uncertain
        ? switch (_inspection.damageSeverity) {
            'NONE' => AppTheme.successColorFor(context),
            'MINOR' => AppTheme.warningColorFor(context),
            'MODERATE' => AppTheme.moderateColorFor(context),
            'SEVERE' => AppTheme.dangerColorFor(context),
            _ => colors.onSurfaceVariant,
          }
        : colors.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        title: const AppText(
          'Hasar Analiz Raporu',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          tooltip: 'Kapat'.tr,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_inspection.isCompleted)
            Builder(
              builder: (buttonContext) => IconButton(
                tooltip: 'PDF Paylaş'.tr,
                onPressed: _isSharingPdf
                    ? null
                    : () => _sharePdf(buttonContext),
                icon: _isSharingPdf
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share_rounded),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pageInset,
                12,
                AppTheme.pageInset,
                24,
              ),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        '${_inspection.vehiclePlate} · ${_inspection.vehicleBrand} ${_inspection.vehicleModel}',
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AppText(
                        '${_inspection.locationCity} · ${_formatDate(_inspection.completedAt ?? _inspection.createdAt)}',
                        style: text.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            content.noVisibleDamage
                                ? Icons.verified_outlined
                                : uncertain
                                ? Icons.add_a_photo_outlined
                                : Icons.car_crash_outlined,
                            color: severityColor,
                            size: 26,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AppText(
                              content.title,
                              style: text.titleLarge?.copyWith(
                                color: severityColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      for (final note in InspectionReportContent.uniqueText([
                        _inspection.analysisMessage,
                        _inspection.additionalPhotoGuidance,
                      ])) ...[
                        const SizedBox(height: 10),
                        AppText(
                          note,
                          style: text.bodyMedium?.copyWith(height: 1.45),
                        ),
                      ],
                      if (content.noVisibleDamage) ...[
                        const SizedBox(height: 10),
                        const AppText('İşlem Gerekmiyor'),
                      ],
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(height: 1),
                      ),
                      AppText(
                        content.priceTitle,
                        style: text.labelLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AppText(
                        content.price,
                        key: const Key('inspection-price'),
                        style: text.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (report?.priceInformation.trim().isNotEmpty ==
                          true) ...[
                        const SizedBox(height: 8),
                        AppText(
                          report!.priceInformation,
                          style: text.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (findings.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SectionCard(
                    icon: Icons.manage_search_rounded,
                    title: 'Bulgular ve Onarım',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < findings.length; i++) ...[
                          if (i > 0)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Divider(height: 1),
                            ),
                          _FindingRow(finding: findings[i]),
                        ],
                      ],
                    ),
                  ),
                ],
                if (uncertain) ...[
                  const SizedBox(height: 12),
                  const AppText(
                    'Bu sonuç hasarsızlık anlamına gelmez. Fotoğraf yönlendirmesine göre yeni bir inceleme oluşturun.',
                  ),
                ] else if (report == null) ...[
                  const SizedBox(height: 12),
                  _ReportStatus(
                    inspection: _inspection,
                    isLoading: _isRegeneratingReport,
                    stopped: _reportRefreshStopped,
                    onRetry: () => _regenerateReport(
                      recoverStalled: _reportRefreshStopped,
                    ),
                    onRefresh: () => _refreshReportStatus(restart: true),
                  ),
                ],
                const SizedBox(height: 12),
                AppText(
                  content.disclaimer,
                  key: const Key('inspection-disclaimer'),
                  style: text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                if (_inspection.isCompleted &&
                    !content.noVisibleDamage &&
                    _inspection.locationLatitude != null &&
                    _inspection.locationLongitude != null) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _openNearbyServices,
                    icon: const Icon(Icons.map_outlined),
                    label: const AppText('Yakındaki Servisler'),
                  ),
                ],
                if (_inspection.isCompleted) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _openDamageRecord,
                    icon: const Icon(Icons.assignment_outlined),
                    label: const AppText('Tutanak Oluştur / Görüntüle'),
                  ),
                ],
                if (_hasInspectionImage) ...[
                  const SizedBox(height: 16),
                  _InspectionImageCard(
                    key: ValueKey(_imageLifetime),
                    imageFuture: _inspectionImageFuture,
                    onRetry: _retryInspectionImage,
                  ),
                ],
                if (report != null ||
                    _inspection.schemaVersion != null ||
                    _inspection.confidenceScore != null) ...[
                  const SizedBox(height: 12),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: ExpansionTile(
                      key: const Key('inspection-report-details'),
                      shape: const Border(),
                      collapsedShape: const Border(),
                      title: const AppText('Rapor Ayrıntıları'),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final paragraph in content.narrative) ...[
                          AppText(
                            paragraph,
                            style: text.bodyMedium?.copyWith(height: 1.45),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (report?.priceSourceDescription.trim().isNotEmpty ==
                            true)
                          AppText(
                            report!.priceSourceDescription,
                            style: text.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        const SizedBox(height: 8),
                        AppText('EXP-${_inspection.id}', style: text.bodySmall),
                        if (_inspection.schemaVersion != null)
                          AppText(
                            _inspection.schemaVersion!,
                            style: text.bodySmall,
                          ),
                        if (_inspection.modelVersion != null)
                          AppText(
                            _inspection.modelVersion!,
                            style: text.bodySmall,
                          ),
                        if (_inspection.confidenceScore != null &&
                            _inspection.schemaVersion != 'gemini-vision-v1')
                          AppText(
                            'Tarihsel model skoru: ${_inspection.confidenceScore}. Doğruluk garantisi değildir.',
                            style: text.bodySmall,
                          ),
                      ],
                    ),
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

class _FindingRow extends StatelessWidget {
  const _FindingRow({required this.finding});
  final ReportFinding finding;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          finding.part,
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          children: [
            for (final type in finding.damageTypes)
              AppText(
                type,
                style: text.labelLarge?.copyWith(color: colors.primary),
              ),
          ],
        ),
        for (final note in InspectionReportContent.uniqueText(
          finding.observations,
        )) ...[
          const SizedBox(height: 8),
          AppText(note, style: text.bodyMedium?.copyWith(height: 1.4)),
        ],
        if (finding.repairs.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.build_outlined,
                size: 16,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final repair in InspectionReportContent.uniqueText(
                      finding.repairs,
                    ))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: AppText(
                          repair,
                          style: text.bodyMedium?.copyWith(height: 1.4),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppText(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class _ReportStatus extends StatelessWidget {
  const _ReportStatus({
    required this.inspection,
    required this.isLoading,
    required this.stopped,
    required this.onRetry,
    required this.onRefresh,
  });

  final DamageInspection inspection;
  final bool isLoading;
  final bool stopped;
  final VoidCallback onRetry;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final processing =
        inspection.isProcessing || inspection.isReportProcessing || isLoading;
    final canRetry =
        inspection.isCompleted && (!inspection.isReportProcessing || stopped);
    final colors = Theme.of(context).colorScheme;
    return AppCard(
      backgroundColor: colors.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (processing && !stopped)
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: AppText(
                  processing
                      ? stopped
                            ? 'İşlem beklenenden uzun sürüyor'
                            : inspection.isProcessing
                            ? 'Fotoğraflar Değerlendiriliyor'
                            : 'Rapor Hazırlanıyor'
                      : inspection.isCompleted
                      ? 'Rapor Tamamlanamadı'
                      : 'Analiz Tamamlanmadı',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (!processing && inspection.isCompleted) ...[
            const SizedBox(height: 8),
            AppText(
              inspection.reportMessage?.trim().isNotEmpty == true
                  ? inspection.reportMessage!
                  : 'Bulgularınız kaydedildi. Fotoğrafları yeniden analiz etmeden raporu tekrar deneyebilirsiniz.',
            ),
          ],
          if (canRetry) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: isLoading ? null : onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const AppText('Raporu Tekrar Dene'),
            ),
          ] else if (inspection.isProcessing && stopped) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const AppText('Sonucu Kontrol Et'),
            ),
          ],
        ],
      ),
    );
  }
}

class _InspectionImageCard extends StatefulWidget {
  const _InspectionImageCard({
    super.key,
    required this.imageFuture,
    required this.onRetry,
  });

  final Future<Uint8List>? imageFuture;
  final VoidCallback onRetry;

  @override
  State<_InspectionImageCard> createState() => _InspectionImageCardState();
}

class _InspectionImageCardState extends State<_InspectionImageCard> {
  ImageProvider? _provider;

  @override
  void dispose() {
    // MemoryImage keys retain encoded bytes in Flutter's global image cache.
    // Keep that second cache from outliving the screen/session RAM policy.
    _provider?.evict();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _SectionCard(
      icon: Icons.photo_outlined,
      title: 'Analiz Fotoğrafı',
      child: FutureBuilder<Uint8List>(
        future: widget.imageFuture,
        builder: (context, snapshot) {
          if (widget.imageFuture == null) {
            return Container(
              key: const Key('inspection-image-placeholder'),
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.cardPadding),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.photo_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  const AppText(
                    'Fotoğraf bellekte tutulmuyor.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: widget.onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const AppText('Fotoğrafı Yeniden Yükle'),
                  ),
                ],
              ),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return AspectRatio(
              aspectRatio: 16 / 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
            );
          }

          final bytes = snapshot.data;
          if (snapshot.hasError || bytes == null || bytes.isEmpty) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.cardPadding),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.broken_image_outlined, color: colorScheme.error),
                  const SizedBox(height: 8),
                  AppText(
                    'Analiz fotoğrafı yüklenemedi.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: widget.onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const AppText('Tekrar Dene'),
                  ),
                ],
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final width =
                  (constraints.maxWidth *
                          MediaQuery.devicePixelRatioOf(context))
                      .ceil()
                      .clamp(1, 1600);
              final provider = ResizeImage(
                MemoryImage(bytes),
                width: width,
                height: (width * 10 / 16).ceil(),
                policy: ResizeImagePolicy.fit,
                allowUpscaling: false,
              );
              if (_provider != provider) {
                _provider?.evict();
                _provider = provider;
              }
              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ColoredBox(
                  color: colorScheme.surfaceContainerHighest,
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Image(
                      image: provider,
                      key: const Key('inspection-analysis-image'),
                      fit: BoxFit.contain,
                      semanticLabel: 'Analiz için yüklenen araç fotoğrafı'.tr,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
