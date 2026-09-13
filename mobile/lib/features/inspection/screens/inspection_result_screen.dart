import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_icon_box.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/widgets/app_status_badge.dart';

import '../models/damage_inspection.dart';
import '../services/inspection_service.dart';
import 'nearby_services_screen.dart';

class InspectionResultScreen extends StatefulWidget {
  const InspectionResultScreen({super.key, required this.inspection});

  final DamageInspection inspection;

  @override
  State<InspectionResultScreen> createState() => _InspectionResultScreenState();
}

class _InspectionResultScreenState extends State<InspectionResultScreen> {
  final InspectionService _inspectionService = const InspectionService();

  late DamageInspection _inspection;

  bool _isRegeneratingReport = false;

  @override
  void initState() {
    super.initState();

    _inspection = widget.inspection;
  }

  Future<void> _regenerateReport() async {
    if (_isRegeneratingReport) {
      return;
    }

    setState(() {
      _isRegeneratingReport = true;
    });

    try {
      final updated = await _inspectionService.regenerateReport(_inspection.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _inspection = updated;
      });
    } catch (exception) {
      if (!mounted) {
        return;
      }

      final message = exception is ApiException
          ? exception.message
          : 'AI raporu yeniden oluşturulamadı.';

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _isRegeneratingReport = false;
        });
      }
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

  String _severityDisplayText(String? severity) {
    return switch (severity) {
      'NONE' => 'Görünür Hasar Tespit Edilmedi',
      'MINOR' => 'Hafif Seviye Hasar',
      'MODERATE' => 'Orta Seviye Hasar',
      'SEVERE' => 'Ağır Seviye Hasar',
      _ => 'Hasar Seviyesi Belirsiz',
    };
  }

  String _severityShortText(String? severity) {
    return switch (severity) {
      'NONE' => 'Hasar Yok',
      'MINOR' => 'Hafif',
      'MODERATE' => 'Orta',
      'SEVERE' => 'Ağır',
      _ => 'Belirsiz',
    };
  }

  Color _severityColor(String? severity) {
    return switch (severity) {
      'NONE' => AppTheme.severityNone,
      'MINOR' => AppTheme.severityMinor,
      'MODERATE' => AppTheme.severityModerate,
      'SEVERE' => AppTheme.severitySevere,
      _ => AppTheme.severityUnknown,
    };
  }

  Color _severitySoftColor(String? severity) {
    return switch (severity) {
      'NONE' => AppTheme.successSoft,
      'MINOR' => AppTheme.warningSoft,
      'MODERATE' => const Color(0xFFFFEDD5),
      'SEVERE' => AppTheme.dangerSoft,
      _ => const Color(0xFFF1F5F9),
    };
  }

  IconData _severityIcon(String? severity) {
    return switch (severity) {
      'NONE' => Icons.verified_outlined,
      'MINOR' => Icons.info_outline_rounded,
      'MODERATE' => Icons.warning_amber_rounded,
      'SEVERE' => Icons.report_problem_outlined,
      _ => Icons.help_outline_rounded,
    };
  }

  String _damageTypeLabel(String type) {
    return switch (type) {
      'NO_VISIBLE_DAMAGE' => 'Görünür Hasar Yok',
      'SCRATCH' => 'Çizik',
      'PAINT_DAMAGE' => 'Boya Hasarı',
      'DENT' => 'Göçük',
      'CRACK' => 'Çatlak',
      'BROKEN_PART' => 'Kırık Parça',
      'BROKEN_GLASS' => 'Kırık Cam',
      'DEFORMATION' => 'Deformasyon',
      _ => type,
    };
  }

  String _vehiclePartLabel(String part) {
    return switch (part) {
      'UNKNOWN' => 'Bilinmeyen Parça',
      'FRONT_BUMPER' => 'Ön Tampon',
      'REAR_BUMPER' => 'Arka Tampon',
      'FRONT_DOOR' => 'Ön Kapı',
      'REAR_DOOR' => 'Arka Kapı',
      'FRONT_WHEEL' => 'Ön Tekerlek',
      'REAR_WHEEL' => 'Arka Tekerlek',
      'FRONT_WINDOW' => 'Ön Yan Cam',
      'REAR_WINDOW' => 'Arka Yan Cam',
      'WINDSHIELD' => 'Ön Cam',
      'REAR_WINDSHIELD' => 'Arka Cam',
      'FENDER' => 'Çamurluk',
      'QUARTER_PANEL' => 'Arka Çamurluk Paneli',
      'ROCKER_PANEL' => 'Marşpiyel',
      'GRILLE' => 'Ön Izgara',
      'HEADLIGHT' => 'Far',
      'TAIL_LIGHT' => 'Arka Stop Lambası',
      'HOOD' => 'Kaput',
      'LICENSE_PLATE' => 'Plaka',
      'MIRROR' => 'Yan Ayna',
      'ROOF' => 'Tavan',
      'TRUNK' => 'Bagaj Kapağı',
      _ => part,
    };
  }

  String _repairActionLabel(String action) {
    return switch (action) {
      'NO_ACTION' => 'İşlem Gerekmiyor',
      'POLISHING' => 'Pasta / Cila',
      'PAINT_TOUCH_UP' => 'Lokal Boya Rötuşu',
      'FULL_PAINTING' => 'Tam Boyama',
      'PAINTLESS_DENT_REPAIR' => 'Boyasız Göçük Düzeltme',
      'DENT_REPAIR' => 'Göçük Düzeltme',
      'PLASTIC_REPAIR' => 'Plastik Onarımı',
      'PART_REPAIR' => 'Parça Onarımı',
      'PART_REPLACEMENT' => 'Parça Değişimi',
      'GLASS_REPAIR' => 'Cam Onarımı',
      'GLASS_REPLACEMENT' => 'Cam Değişimi',
      'HEADLIGHT_REPAIR' => 'Far Onarımı',
      'HEADLIGHT_REPLACEMENT' => 'Far Değişimi',
      _ => action,
    };
  }

  String _reportStatusMessage() {
    if (_inspection.isReportProcessing) {
      return 'AI raporu oluşturuluyor...';
    }

    if (_inspection.isReportFailed) {
      return _inspection.reportMessage ?? 'AI raporu oluşturulamadı.';
    }

    return _inspection.reportMessage ?? 'AI raporu henüz oluşturulmadı.';
  }

  String _formatPrice(double value) {
    final rounded = value.round();

    final source = rounded.toString();

    final result = StringBuffer();

    for (int i = 0; i < source.length; i++) {
      final remaining = source.length - i;

      result.write(source[i]);

      if (remaining > 1 && remaining % 3 == 1) {
        result.write('.');
      }
    }

    return result.toString();
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '-';
    }

    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    return '$day.$month.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final report = _inspection.report;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analiz Sonucu'),
        leading: IconButton(
          tooltip: 'Kapat',
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),

            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),

              children: [
                _ResultHero(
                  inspection: _inspection,

                  severityText: _severityShortText(_inspection.damageSeverity),

                  severityDescription: _severityDisplayText(
                    _inspection.damageSeverity,
                  ),

                  severityColor: _severityColor(_inspection.damageSeverity),

                  severitySoftColor: _severitySoftColor(
                    _inspection.damageSeverity,
                  ),

                  severityIcon: _severityIcon(_inspection.damageSeverity),

                  date: _formatDate(
                    _inspection.completedAt ?? _inspection.createdAt,
                  ),
                ),

                if (_inspection.confidenceScore != null) ...[
                  const SizedBox(height: 16),

                  _ConfidenceCard(confidence: _inspection.confidenceScore!),
                ],

                if (_inspection.damageTypes.isNotEmpty) ...[
                  const SizedBox(height: 16),

                  _SectionCard(
                    icon: Icons.car_crash_outlined,
                    title: 'Tespit Edilen Hasarlar',
                    subtitle:
                        '${_inspection.damageTypes.length} hasar türü belirlendi',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _inspection.damageTypes
                          .map(
                            (type) => _ResultChip(
                              icon: Icons.warning_amber_rounded,
                              label: _damageTypeLabel(type),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],

                if (_inspection.affectedParts.isNotEmpty) ...[
                  const SizedBox(height: 16),

                  _SectionCard(
                    icon: Icons.directions_car_outlined,
                    title: 'Etkilenen Parçalar',
                    subtitle:
                        '${_inspection.affectedParts.length} araç parçası',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _inspection.affectedParts
                          .map(
                            (part) => _ResultChip(
                              icon: Icons.build_outlined,
                              label: _vehiclePartLabel(part),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],

                if (_inspection.repairRecommendations.isNotEmpty) ...[
                  const SizedBox(height: 16),

                  _SectionCard(
                    icon: Icons.handyman_outlined,
                    title: 'Onarım Önerileri',
                    subtitle: 'AI modelinin önerdiği işlemler',
                    child: Column(
                      children: _inspection.repairRecommendations
                          .asMap()
                          .entries
                          .map((entry) {
                            final index = entry.key;

                            final recommendation = entry.value;

                            final parts = recommendation.affectedParts
                                .map(_vehiclePartLabel)
                                .join(', ');

                            return Padding(
                              padding: EdgeInsets.only(
                                bottom:
                                    index ==
                                        _inspection
                                                .repairRecommendations
                                                .length -
                                            1
                                    ? 0
                                    : 12,
                              ),

                              child: _RepairRecommendationTile(
                                action: _repairActionLabel(
                                  recommendation.recommendedAction,
                                ),

                                parts: parts,

                                replacementRequired:
                                    recommendation.partReplacementRequired,
                              ),
                            );
                          })
                          .toList(),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                if (report != null) ...[
                  _AiReportCard(
                    title: report.title,
                    summary: report.summary,
                    damageDescription: report.damageDescription,
                    repairRecommendation: report.repairRecommendation,
                  ),

                  const SizedBox(height: 16),

                  _PriceEstimateCard(
                    minimum: _formatPrice(report.estimatedMinimumPrice),

                    maximum: _formatPrice(report.estimatedMaximumPrice),

                    currency: report.currency,

                    city: _inspection.locationCity,

                    priceInformation: report.priceInformation,

                    sourceDescription: report.priceSourceDescription,

                    disclaimer: report.disclaimer,
                  ),

                  if (_inspection.locationLatitude != null &&
                      _inspection.locationLongitude != null) ...[
                    const SizedBox(height: 16),

                    _NearbyServicesCard(onExplore: _openNearbyServices),
                  ],
                ] else ...[
                  _ReportStatusCard(
                    inspection: _inspection,
                    message: _reportStatusMessage(),
                    isLoading: _isRegeneratingReport,
                    onRegenerate: _regenerateReport,
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

class _ResultHero extends StatelessWidget {
  const _ResultHero({
    required this.inspection,
    required this.severityText,
    required this.severityDescription,
    required this.severityColor,
    required this.severitySoftColor,
    required this.severityIcon,
    required this.date,
  });

  final DamageInspection inspection;

  final String severityText;
  final String severityDescription;

  final Color severityColor;
  final Color severitySoftColor;

  final IconData severityIcon;

  final String date;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(22),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIconBox(
                icon: Icons.directions_car_filled_rounded,
                size: 58,
                iconSize: 29,
                borderRadius: 19,
                iconColor: Colors.white,
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inspection.vehiclePlate,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Wrap(
                      spacing: 12,
                      runSpacing: 5,
                      children: [
                        _HeroMeta(
                          icon: Icons.location_on_outlined,
                          text: inspection.locationCity,
                        ),
                        _HeroMeta(
                          icon: Icons.calendar_today_outlined,
                          text: date,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          Divider(color: colorScheme.outlineVariant, height: 1),

          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),

            decoration: BoxDecoration(
              color: severitySoftColor,

              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),

            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIconBox(
                  icon: severityIcon,
                  size: 48,
                  iconSize: 25,
                  borderRadius: 24,
                  backgroundColor: severityColor.withValues(alpha: 0.13),
                  iconColor: severityColor,
                ),

                const SizedBox(width: 13),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HASAR SEVİYESİ',
                        style: textTheme.labelSmall?.copyWith(
                          color: severityColor,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),

                      const SizedBox(height: 6),

                      AppStatusBadge(
                        label: severityText,
                        color: severityColor,
                        backgroundColor: severityColor.withValues(alpha: 0.10),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        severityDescription,
                        style: textTheme.bodyMedium?.copyWith(
                          color: severityColor.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),

        const SizedBox(width: 4),

        Text(
          text,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ConfidenceCard extends StatelessWidget {
  const _ConfidenceCard({required this.confidence});

  final double confidence;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final textTheme = Theme.of(context).textTheme;

    final safeConfidence = confidence.clamp(0.0, 1.0).toDouble();

    final percentage = safeConfidence * 100;

    return AppCard(
      showShadow: false,
      backgroundColor: colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.all(18),

      child: Column(
        children: [
          Row(
            children: [
              const AppIconBox(
                icon: Icons.analytics_outlined,
                size: 42,
                iconSize: 21,
                borderRadius: 14,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Model Güveni',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      'Görüntü analizinin güven skoru',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                '%${percentage.toStringAsFixed(1)}',
                style: textTheme.titleLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            child: LinearProgressIndicator(
              value: safeConfidence,
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;

  final String title;
  final String subtitle;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(icon: icon, title: title, subtitle: subtitle),

          const SizedBox(height: 18),

          child,
        ],
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),

      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,

        borderRadius: BorderRadius.circular(AppTheme.radiusPill),

        border: Border.all(color: colorScheme.outlineVariant),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),

          const SizedBox(width: 6),

          Text(
            label,
            style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _RepairRecommendationTile extends StatelessWidget {
  const _RepairRecommendationTile({
    required this.action,
    required this.parts,
    required this.replacementRequired,
  });

  final String action;
  final String parts;

  final bool replacementRequired;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(15),

      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,

        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppIconBox(
            icon: Icons.handyman_outlined,
            size: 40,
            iconSize: 20,
            borderRadius: 13,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        action,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),

                    if (replacementRequired)
                      const AppStatusBadge(
                        label: 'Değişim',
                        color: AppTheme.warningColor,
                        backgroundColor: AppTheme.warningSoft,
                        compact: true,
                      ),
                  ],
                ),

                if (parts.isNotEmpty) ...[
                  const SizedBox(height: 5),

                  Text(
                    parts,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiReportCard extends StatelessWidget {
  const _AiReportCard({
    required this.title,
    required this.summary,
    required this.damageDescription,
    required this.repairRecommendation,
  });

  final String title;
  final String summary;

  final String damageDescription;
  final String repairRecommendation;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),

        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.08),
            colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),

        boxShadow: AppTheme.softShadow,
      ),

      padding: const EdgeInsets.all(22),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            icon: Icons.auto_awesome_rounded,
            title: 'AI İnceleme Raporu',
            subtitle: 'Yapay zekâ tarafından oluşturuldu',
          ),

          const SizedBox(height: 22),

          Text(
            title,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),

          const SizedBox(height: 9),

          Text(summary, style: textTheme.bodyMedium?.copyWith(height: 1.55)),

          const SizedBox(height: 22),

          _ReportSection(
            icon: Icons.search_rounded,
            title: 'Hasar Açıklaması',
            text: damageDescription,
          ),

          const SizedBox(height: 18),

          _ReportSection(
            icon: Icons.build_circle_outlined,
            title: 'Onarım Önerisi',
            text: repairRecommendation,
          ),
        ],
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 19, color: colorScheme.primary),

            const SizedBox(width: 7),

            Text(
              title,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Text(
          text,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _PriceEstimateCard extends StatelessWidget {
  const _PriceEstimateCard({
    required this.minimum,
    required this.maximum,
    required this.currency,
    required this.city,
    required this.priceInformation,
    required this.sourceDescription,
    required this.disclaimer,
  });

  final String minimum;
  final String maximum;
  final String currency;

  final String city;

  final String priceInformation;
  final String sourceDescription;
  final String disclaimer;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.all(22),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            icon: Icons.payments_outlined,
            title: 'Tahmini Onarım Maliyeti',
            subtitle: 'Bölgesel tahmini servis maliyeti',
          ),

          const SizedBox(height: 22),

          Container(
            width: double.infinity,

            padding: const EdgeInsets.all(18),

            decoration: BoxDecoration(
              color: AppTheme.successSoft,

              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppTheme.successColor,
                    ),

                    const SizedBox(width: 5),

                    Expanded(
                      child: Text(
                        city,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Text(
                  'TAHMİNİ ARALIK',
                  style: textTheme.labelSmall?.copyWith(
                    color: AppTheme.successColor,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 7),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,

                  child: Text(
                    '$minimum - $maximum $currency',
                    style: textTheme.headlineSmall?.copyWith(
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (priceInformation.trim().isNotEmpty) ...[
            const SizedBox(height: 18),

            Text(
              priceInformation,
              style: textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],

          if (sourceDescription.trim().isNotEmpty) ...[
            const SizedBox(height: 18),

            Text(
              'Fiyat Tahmini Hakkında',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 7),

            Text(
              sourceDescription,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],

          if (disclaimer.trim().isNotEmpty) ...[
            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(14),

              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,

                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),

              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),

                  const SizedBox(width: 9),

                  Expanded(
                    child: Text(
                      disclaimer,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NearbyServicesCard extends StatelessWidget {
  const _NearbyServicesCard({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            icon: Icons.location_on_outlined,
            title: 'Yakındaki Uygun Servisler',
            subtitle: 'Araç ve hasar bilgilerine göre servis keşfi',
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIconBox(
                  icon: Icons.auto_awesome_rounded,
                  size: 44,
                  iconSize: 22,
                  borderRadius: 14,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                  iconColor: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Yapay zekânın araç markası, modeli ve tespit edilen '
                    'hasara göre belirlediği aramalarla yakınınızdaki gerçek '
                    'servisleri haritada görüntüleyin.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onExplore,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Haritada Keşfet'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportStatusCard extends StatelessWidget {
  const _ReportStatusCard({
    required this.inspection,
    required this.message,
    required this.isLoading,
    required this.onRegenerate,
  });

  final DamageInspection inspection;

  final String message;

  final bool isLoading;

  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final textTheme = Theme.of(context).textTheme;

    final isFailed = inspection.isReportFailed;

    final isProcessing = isLoading || inspection.isReportProcessing;

    return AppCard(
      padding: const EdgeInsets.all(22),

      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,

            decoration: BoxDecoration(
              color: isFailed
                  ? colorScheme.errorContainer
                  : colorScheme.primaryContainer,

              borderRadius: BorderRadius.circular(22),
            ),

            child: isProcessing
                ? Padding(
                    padding: const EdgeInsets.all(22),
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: colorScheme.primary,
                    ),
                  )
                : Icon(
                    isFailed
                        ? Icons.error_outline_rounded
                        : Icons.description_outlined,
                    size: 34,
                    color: isFailed ? colorScheme.error : colorScheme.primary,
                  ),
          ),

          const SizedBox(height: 18),

          Text(
            isFailed ? 'AI raporu oluşturulamadı' : 'AI raporu hazırlanıyor',
            textAlign: TextAlign.center,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),

          const SizedBox(height: 8),

          Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),

          if (inspection.isFailed &&
              inspection.analysisMessage != null &&
              inspection.analysisMessage!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),

            Text(
              inspection.analysisMessage!,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
          ],

          if (inspection.isCompleted && !inspection.isReportProcessing) ...[
            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,

              child: FilledButton.tonalIcon(
                onPressed: isLoading ? null : onRegenerate,

                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),

                label: const Text('AI Raporunu Tekrar Oluştur'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
