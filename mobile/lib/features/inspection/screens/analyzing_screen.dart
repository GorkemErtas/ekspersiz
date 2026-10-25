import 'package:mobile/core/localization/app_text.dart';
import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_icon_box.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/app_motion.dart';

import '../models/damage_inspection.dart';
import '../services/inspection_service.dart';
import 'inspection_result_screen.dart';
import 'upload_damage_image_screen.dart';
import 'create_inspection_screen.dart';
import '../../billing/screens/subscription_screen.dart';

class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({
    super.key,
    required this.inspection,
    required this.vehicleRegion,
    this.inspectionService = const InspectionService(),
  });

  final DamageInspection inspection;
  final String vehicleRegion;
  final InspectionService inspectionService;

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen>
    with SingleTickerProviderStateMixin {
  InspectionService get _inspectionService => widget.inspectionService;
  Timer? _pollTimer;
  Timer? _deadlineTimer;
  DamageInspection? _progress;
  bool _busy = false;
  bool _requestInFlight = false;
  bool _checkingStatus = false;
  bool _needsStatusCheck = false;
  bool _statusUncertain = false;
  bool _legacyReportStarted = false;
  bool _creatingPhotoAttempt = false;
  int _run = 0;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  bool _hasError = false;
  bool _creditRequired = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _analyze());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduceMotion(context)) {
      _pulseController.stop();
      _pulseController.value = 0.5;
    } else if (!_hasError && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _stopWaiting();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    if (_busy) return;
    _busy = true;
    _requestInFlight = false;
    final run = ++_run;
    setState(() {
      _hasError = false;
      _creditRequired = false;
      _errorMessage = null;
      _statusUncertain = false;
    });

    if (!AppMotion.reduceMotion(context) && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }

    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollStatus(run),
    );
    _deadlineTimer = Timer(const Duration(minutes: 3), () {
      if (!_isCurrent(run)) return;
      final progress = _progress;
      if (progress != null && progress.isCompleted) {
        _showResult(run, progress);
      } else {
        _fail(
          run,
          const ApiException(
            message:
                'İşlem sunucuda devam ediyor olabilir. Analizi yeniden başlatmadan sonucunu kontrol edin.',
          ),
          uncertain: true,
        );
      }
    });

    try {
      // After a lost response, read the existing operation before considering
      // another POST. A report failure is never a reason to run ML again.
      if (_needsStatusCheck) {
        final current = await _inspectionService.getInspectionById(
          widget.inspection.id,
        );
        if (!_isCurrent(run)) return;
        if (current.isCompleted || current.isProcessing) {
          _acceptStatus(run, current);
          return;
        }
      }
      _requestInFlight = true;
      final analyzed = await _inspectionService.analyzeInspection(
        widget.inspection.id,
        vehicleRegion: widget.vehicleRegion,
      );
      if (!_isCurrent(run)) return;
      _requestInFlight = false;
      _acceptStatus(run, analyzed, allowLegacyReport: true);
    } catch (exception) {
      if (!_isCurrent(run)) return;
      _requestInFlight = false;
      await _recover(run, exception);
    }
  }

  bool _isCurrent(int run) => mounted && _busy && run == _run;

  void _stopWaiting() {
    _pollTimer?.cancel();
    _deadlineTimer?.cancel();
  }

  Future<void> _pollStatus(int run) async {
    if (!_isCurrent(run) || _checkingStatus) return;
    _checkingStatus = true;
    try {
      final current = await _inspectionService.getInspectionById(
        widget.inspection.id,
      );
      if (_isCurrent(run)) _acceptStatus(run, current);
    } catch (error) {
      if (_isCurrent(run) &&
          error is ApiException &&
          (error.statusCode == 401 ||
              error.statusCode == 403 ||
              error.statusCode == 404)) {
        _fail(run, error);
      }
      // Transient read failures do not trigger another paid operation.
    } finally {
      _checkingStatus = false;
    }
  }

  void _acceptStatus(
    int run,
    DamageInspection current, {
    bool allowLegacyReport = false,
  }) {
    if (!_isCurrent(run)) return;
    setState(() => _progress = current);
    if (current.isCompleted) {
      if (current.isReportProcessing ||
          (_requestInFlight &&
              current.report == null &&
              !current.isReportFailed)) {
        return;
      }
      if (allowLegacyReport &&
          current.report == null &&
          !current.isReportFailed &&
          !_legacyReportStarted) {
        // Compatibility for older servers that return ML + PENDING instead
        // of automatically generating the report inside /analyze.
        _legacyReportStarted = true;
        _requestInFlight = true;
        _finishLegacyReport(run);
        return;
      }
      _showResult(run, current);
    } else if (current.isFailed && !_requestInFlight) {
      _fail(
        run,
        ApiException(
          message: current.analysisMessage ?? 'Hasar analizi tamamlanamadı.',
        ),
      );
    }
  }

  Future<void> _finishLegacyReport(int run) async {
    try {
      final result = await _inspectionService.regenerateReport(
        widget.inspection.id,
      );
      if (!_isCurrent(run)) return;
      _requestInFlight = false;
      _acceptStatus(run, result);
    } catch (error) {
      if (!_isCurrent(run)) return;
      _requestInFlight = false;
      await _recover(run, error);
    }
  }

  Future<void> _recover(int run, Object error) async {
    _needsStatusCheck = true;
    try {
      final current = await _inspectionService.getInspectionById(
        widget.inspection.id,
      );
      if (!_isCurrent(run)) return;
      if (current.isCompleted || current.isProcessing) {
        _acceptStatus(run, current);
        return;
      }
      if (current.needsMorePhotos) {
        _acceptStatus(run, current);
      } else {
        _fail(run, error);
      }
    } catch (_) {
      if (!_isCurrent(run)) return;
      // Even when status cannot be fetched, already received ML is useful.
      if (_progress?.isCompleted == true) {
        _showResult(run, _progress!);
      } else {
        _fail(run, error, uncertain: true);
      }
    }
  }

  void _fail(int run, Object error, {bool uncertain = false}) {
    if (!_isCurrent(run)) return;
    _stopWaiting();
    _busy = false;
    _needsStatusCheck = true;
    _pulseController.stop();
    setState(() {
      _hasError = true;
      _statusUncertain = uncertain;
      _errorMessage = error is ApiException
          ? error.message
          : 'Hasar analizi tamamlanamadı.';
      _creditRequired = error is ApiException && error.statusCode == 402;
    });
  }

  void _showResult(int run, DamageInspection result) {
    if (!_isCurrent(run)) return;
    _busy = false;
    _stopWaiting();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => InspectionResultScreen(
          inspection: result,
          inspectionService: _inspectionService,
        ),
      ),
    );
  }

  Future<void> _requestNewPhotos() async {
    if (_creatingPhotoAttempt) return;
    _creatingPhotoAttempt = true;
    try {
      final current = _progress ?? widget.inspection;
      // Started inspections remain immutable. A replacement photo pair gets
      // a new attempt; the failed attempt remains in history without a charge.
      if (current.locationLatitude == null ||
          current.locationLongitude == null) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const CreateInspectionScreen(),
          ),
        );
        return;
      }
      final next = await _inspectionService.createInspection(
        vehicleId: current.vehicleId,
        city: current.locationCity,
        latitude: current.locationLatitude!,
        longitude: current.locationLongitude!,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => UploadDamageImageScreen(
            inspection: next,
            inspectionService: _inspectionService,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage = error is ApiException
              ? error.message
              : 'Yeni fotoğraf yükleme adımı başlatılamadı.',
        );
      }
    } finally {
      _creatingPhotoAttempt = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _hasError,

      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),

              child: _hasError
                  ? AppStateView.error(
                      title: _progress?.needsMorePhotos == true
                          ? 'Yeni fotoğraflar gerekli'
                          : 'Analiz tamamlanamadı',
                      message: _errorMessage ?? 'Beklenmeyen bir hata oluştu.',
                      actionLabel: _creditRequired
                          ? 'Analiz kredisi al'
                          : _statusUncertain
                          ? 'Sonucu Kontrol Et'
                          : _progress?.needsMorePhotos == true
                          ? 'Fotoğrafları Güncelle'
                          : 'Analizi Tekrar Dene',
                      actionIcon: Icons.refresh_rounded,
                      onActionPressed: _creditRequired
                          ? () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const SubscriptionScreen(
                                    preferCompany: true,
                                  ),
                                ),
                              );
                              if (mounted) await _analyze();
                            }
                          : _progress?.needsMorePhotos == true
                          ? _requestNewPhotos
                          : _analyze,
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 36),

                      child: _AnalyzingContent(
                        inspection: widget.inspection,
                        pulseAnimation: _pulseAnimation,
                        preparingReport: _progress?.isCompleted == true,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalyzingContent extends StatelessWidget {
  const _AnalyzingContent({
    required this.inspection,
    required this.pulseAnimation,
    required this.preparingReport,
  });

  final DamageInspection inspection;
  final Animation<double> pulseAnimation;
  final bool preparingReport;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        const SizedBox(height: 12),

        ScaleTransition(
          scale: pulseAnimation,

          child: Container(
            width: 104,
            height: 104,

            decoration: BoxDecoration(
              gradient: AppTheme.brandGradient,

              borderRadius: BorderRadius.circular(34),

              boxShadow: AppTheme.primaryShadowFor(context),
            ),

            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,

                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                    shape: BoxShape.circle,
                  ),
                ),

                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 40,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 26),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),

          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),

          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              ),

              const SizedBox(width: 8),

              Flexible(
                child: AppText(
                  preparingReport
                      ? '2 / 2 · AI RAPORU HAZIRLANIYOR'
                      : '1 / 2 · HASAR TESPİT EDİLİYOR',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        AppText(
          preparingReport
              ? 'AI raporunuz hazırlanıyor'
              : 'Aracınız analiz ediliyor',
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),

        const SizedBox(height: 10),

        AppText(
          preparingReport
              ? 'Hasar tespiti tamamlandı. Onarım önerileri, detaylı rapor ve tahmini maliyetler hazırlanıyor.'
              : 'Fotoğrafınız inceleniyor; hasarlar, etkilenen parçalar ve hasar seviyesi belirleniyor.',
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 26),

        AppCard(
          showShadow: false,
          backgroundColor: colorScheme.surfaceContainerLow,
          padding: const EdgeInsets.all(18),

          child: Row(
            children: [
              AppIconBox(
                icon: Icons.directions_car_filled_rounded,
                size: 50,
                iconSize: 25,
                borderRadius: 16,
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      inspection.vehiclePlate,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: colorScheme.onSurfaceVariant,
                        ),

                        const SizedBox(width: 4),

                        Expanded(
                          child: AppText(
                            inspection.locationCity,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppTheme.spacingM),

        AppCard(
          padding: const EdgeInsets.all(AppTheme.cardPadding),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSectionHeader(
                icon: Icons.analytics_outlined,
                title: 'Analiz süreci',
                subtitle:
                    'Hasar tespiti ve detaylı rapor tek işlemde hazırlanır.',
              ),

              const SizedBox(height: 20),

              _AnalysisStep(
                icon: Icons.car_crash_outlined,
                title: 'Hasar tespiti',
                description:
                    'Hasar türleri ve etkilenen araç parçaları belirleniyor.',
                showLine: true,
                completed: preparingReport,
              ),

              const _AnalysisStep(
                icon: Icons.description_outlined,
                title: 'Detaylı AI raporu ve maliyetler',
                description:
                    'İki fotoğraftaki görsel yorumlardan rapor, olası onarımlar ve fiyat tahmini hazırlanır.',
                showLine: false,
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        Container(
          padding: const EdgeInsets.all(16),

          decoration: BoxDecoration(
            color: AppTheme.infoSoftFor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),

          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIconBox(
                icon: Icons.hourglass_top_rounded,
                size: 38,
                iconSize: 19,
                borderRadius: 12,
                backgroundColor: Theme.of(context).colorScheme.surface,
                iconColor: AppTheme.infoColorFor(context),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: AppText(
                  'Analiz tamamlanana kadar bu ekranda kalın. '
                  'İşlem tamamlandığında sonuç ekranı otomatik olarak açılacak.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppTheme.infoColorFor(context),
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnalysisStep extends StatelessWidget {
  const _AnalysisStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.showLine,
    this.completed = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool showLine;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final textTheme = Theme.of(context).textTheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 42,

            child: Column(
              children: [
                AppIconBox(
                  icon: completed ? Icons.check_rounded : icon,
                  iconColor: completed
                      ? AppTheme.successColorFor(context)
                      : null,
                  backgroundColor: completed
                      ? AppTheme.successSoftFor(context)
                      : null,
                  size: 38,
                  iconSize: 19,
                  borderRadius: 19,
                ),

                if (showLine)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusPill,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showLine ? 20 : 0),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    title,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 4),

                  AppText(
                    description,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
