import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../models/damage_inspection.dart';
import '../services/inspection_service.dart';
import 'inspection_result_screen.dart';

class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({
    super.key,
    required this.inspection,
  });

  final DamageInspection inspection;

  @override
  State<AnalyzingScreen> createState() =>
      _AnalyzingScreenState();
}

class _AnalyzingScreenState
    extends State<AnalyzingScreen> {
  final InspectionService _inspectionService =
  const InspectionService();

  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
          (_) => _analyze(),
    );
  }

  Future<void> _analyze() async {
    setState(() {
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final analyzedInspection =
      await _inspectionService.analyzeInspection(
        widget.inspection.id,
      );

      if (!mounted) {
        return;
      }

      if (analyzedInspection.isFailed) {
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
        MaterialPageRoute(
          builder: (_) => InspectionResultScreen(
            inspection: analyzedInspection,
          ),
        ),
      );
    } catch (exception) {
      if (!mounted) {
        return;
      }

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
    final colorScheme =
        Theme.of(context).colorScheme;

    final textTheme =
        Theme.of(context).textTheme;

    return PopScope(
      canPop: _hasError,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1100,
              ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 420,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_hasError) ...[
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          color:
                          colorScheme.primaryContainer,
                          borderRadius:
                          BorderRadius.circular(28),
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          size: 42,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 30),
                      const SizedBox(
                        width: 42,
                        height: 42,
                        child:
                        CircularProgressIndicator(
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Araç analiz ediliyor',
                        textAlign: TextAlign.center,
                        style: textTheme
                            .headlineSmall
                            ?.copyWith(
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Hasarlı bölgeler, etkilenen parçalar ve AI raporu hazırlanıyor.',
                        textAlign: TextAlign.center,
                        style:
                        textTheme.bodyLarge?.copyWith(
                          color: colorScheme
                              .onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 26),
                      _AnalysisStep(
                        icon:
                        Icons.image_search_outlined,
                        label:
                        'Hasar tespiti yapılıyor',
                      ),
                      const SizedBox(height: 10),
                      _AnalysisStep(
                        icon: Icons
                            .directions_car_outlined,
                        label:
                        'Araç parçaları belirleniyor',
                      ),
                      const SizedBox(height: 10),
                      _AnalysisStep(
                        icon:
                        Icons.description_outlined,
                        label:
                        'AI raporu hazırlanıyor',
                      ),
                    ] else ...[
                      Icon(
                        Icons.error_outline_rounded,
                        size: 64,
                        color: colorScheme.error,
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Analiz tamamlanamadı',
                        textAlign: TextAlign.center,
                        style: textTheme
                            .headlineSmall
                            ?.copyWith(
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _errorMessage ??
                            'Beklenmeyen bir hata oluştu.',
                        textAlign: TextAlign.center,
                        style:
                        textTheme.bodyLarge?.copyWith(
                          color: colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 26),
                      FilledButton.icon(
                        onPressed: _analyze,
                        icon: const Icon(
                          Icons.refresh_rounded,
                        ),
                        label: const Text(
                          'Tekrar Dene',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text(
                          'Geri Dön',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
        ),
      ),
    );
  }
}

class _AnalysisStep extends StatelessWidget {
  const _AnalysisStep({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment:
      MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 20,
          color: colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color:
              colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}