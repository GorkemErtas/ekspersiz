import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_icon_box.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/widgets/app_state_view.dart';

import '../models/damage_inspection.dart';
import '../services/inspection_service.dart';
import 'inspection_result_screen.dart';

class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({super.key, required this.inspection});

  final DamageInspection inspection;

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen>
    with SingleTickerProviderStateMixin {
  final InspectionService _inspectionService = const InspectionService();

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  bool _hasError = false;
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

    _pulseController.repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) => _analyze());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    setState(() {
      _hasError = false;
      _errorMessage = null;
    });

    if (!_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }

    try {
      final analyzedInspection = await _inspectionService.analyzeInspection(
        widget.inspection.id,
      );

      if (!mounted) {
        return;
      }

      if (analyzedInspection.isFailed) {
        _pulseController.stop();

        setState(() {
          _hasError = true;

          _errorMessage =
              analyzedInspection.analysisMessage ??
              'Hasar analizi tamamlanamadı. '
                  'Lütfen tekrar deneyin.';
        });

        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              InspectionResultScreen(inspection: analyzedInspection),
        ),
      );
    } catch (exception) {
      if (!mounted) {
        return;
      }

      _pulseController.stop();

      final message = exception is ApiException
          ? exception.message
          : 'Hasar analizi tamamlanamadı.';

      setState(() {
        _hasError = true;
        _errorMessage = message;
      });
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
                      title: 'Analiz tamamlanamadı',
                      message: _errorMessage ?? 'Beklenmeyen bir hata oluştu.',
                      actionLabel: 'Analizi Tekrar Dene',
                      actionIcon: Icons.refresh_rounded,
                      onActionPressed: _analyze,
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 36),

                      child: _AnalyzingContent(
                        inspection: widget.inspection,
                        pulseAnimation: _pulseAnimation,
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
  });

  final DamageInspection inspection;
  final Animation<double> pulseAnimation;

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
            width: 112,
            height: 112,

            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),

              borderRadius: BorderRadius.circular(34),

              boxShadow: AppTheme.primaryShadow,
            ),

            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 78,
                  height: 78,

                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                    shape: BoxShape.circle,
                  ),
                ),

                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 44,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 28),

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

              Text(
                'AI ANALİZİ DEVAM EDİYOR',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        Text(
          'Aracınız analiz ediliyor',
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),

        const SizedBox(height: 10),

        Text(
          'Yapay zekâ görüntüyü inceliyor, '
          'hasarlı bölgeleri ve etkilenen parçaları belirliyor.',
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 28),

        AppCard(
          showShadow: false,
          backgroundColor: colorScheme.surfaceContainerLow,
          padding: const EdgeInsets.all(18),

          child: Row(
            children: [
              const AppIconBox(
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
                    Text(
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
                          child: Text(
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

        const SizedBox(height: 16),

        AppCard(
          padding: const EdgeInsets.all(20),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSectionHeader(
                icon: Icons.analytics_outlined,
                title: 'Analiz süreci',
                subtitle: 'AI modeli görüntüyü birkaç aşamada değerlendiriyor.',
              ),

              const SizedBox(height: 20),

              const _AnalysisStep(
                icon: Icons.image_search_outlined,
                title: 'Görüntü inceleniyor',
                description:
                    'Araç ve hasarlı bölgeler görüntü üzerinde değerlendiriliyor.',
                showLine: true,
              ),

              const _AnalysisStep(
                icon: Icons.car_crash_outlined,
                title: 'Hasar tespiti',
                description:
                    'Hasar türleri ve etkilenen araç parçaları belirleniyor.',
                showLine: true,
              ),

              const _AnalysisStep(
                icon: Icons.description_outlined,
                title: 'Sonuç hazırlanıyor',
                description:
                    'Hasar seviyesi ve onarım önerileri oluşturuluyor.',
                showLine: false,
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        Container(
          padding: const EdgeInsets.all(16),

          decoration: BoxDecoration(
            color: AppTheme.infoSoft,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),

          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppIconBox(
                icon: Icons.hourglass_top_rounded,
                size: 38,
                iconSize: 19,
                borderRadius: 12,
                backgroundColor: Colors.white,
                iconColor: AppTheme.infoColor,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  'Analiz tamamlanana kadar bu ekranda kalın. '
                  'İşlem tamamlandığında sonuç ekranı otomatik olarak açılacak.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppTheme.infoColor,
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
  });

  final IconData icon;
  final String title;
  final String description;
  final bool showLine;

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
                  icon: icon,
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
                  Text(
                    title,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
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
