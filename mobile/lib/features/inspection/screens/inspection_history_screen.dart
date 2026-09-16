import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../auth/models/business_account.dart';

import '../models/damage_inspection.dart';
import '../services/inspection_service.dart';
import 'inspection_result_screen.dart';

class InspectionHistoryScreen extends StatefulWidget {
  const InspectionHistoryScreen({super.key, this.businessAccount});

  final BusinessAccount? businessAccount;

  @override
  State<InspectionHistoryScreen> createState() =>
      _InspectionHistoryScreenState();
}

class _InspectionHistoryScreenState extends State<InspectionHistoryScreen> {
  final InspectionService _inspectionService = const InspectionService();

  late Future<List<DamageInspection>> _inspectionsFuture;

  @override
  void initState() {
    super.initState();

    _loadInspections();
  }

  void _loadInspections() {
    _inspectionsFuture = _inspectionService.getInspections();
  }

  Future<void> _refreshInspections() async {
    setState(_loadInspections);

    try {
      await _inspectionsFuture;
    } catch (_) {
      // FutureBuilder hata durumunu gösterecek.
    }
  }

  Future<void> _openInspection(DamageInspection inspection) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InspectionResultScreen(inspection: inspection),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(_loadInspections);
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

  String _severityLabel(String? severity) {
    return switch (severity) {
      'NONE' => 'Görünür Hasar Yok',
      'MINOR' => 'Hafif Hasar',
      'MODERATE' => 'Orta Hasar',
      'SEVERE' => 'Ağır Hasar',
      _ => 'Hasar Seviyesi Belirsiz',
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
      'MODERATE' => const Color(0xFF33200F),
      'SEVERE' => AppTheme.dangerSoft,
      _ => const Color(0xFF24202B),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.businessAccount == null ? 'Analizler' : 'Şirket Analizleri',
        ),
      ),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppTheme.maxContentWidth,
            ),

            child: FutureBuilder<List<DamageInspection>>(
              future: _inspectionsFuture,

              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppStateView.loading(
                    title: 'Analizler yükleniyor',
                    message: 'Tamamlanan hasar analizleriniz hazırlanıyor.',
                    bottomPadding: 110,
                  );
                }

                if (snapshot.hasError) {
                  final error = snapshot.error;

                  final message = error is ApiException
                      ? error.message
                      : 'Analiz geçmişi yüklenemedi.';

                  return AppStateView.error(
                    title: 'Analizler yüklenemedi',
                    message: message,
                    bottomPadding: 110,
                    onActionPressed: () {
                      setState(_loadInspections);
                    },
                  );
                }

                final allInspections =
                    snapshot.data ?? const <DamageInspection>[];

                final inspections =
                    allInspections
                        .where((inspection) => inspection.status == 'COMPLETED')
                        .toList()
                      ..sort((a, b) {
                        final aDate =
                            a.completedAt ?? a.createdAt ?? DateTime(1970);

                        final bDate =
                            b.completedAt ?? b.createdAt ?? DateTime(1970);

                        return bDate.compareTo(aDate);
                      });

                if (inspections.isEmpty) {
                  return AppStateView.empty(
                    icon: Icons.analytics_outlined,
                    title: 'Henüz tamamlanan analiz yok',
                    message: widget.businessAccount == null
                        ? 'AI destekli bir hasar analizi tamamladığınızda raporunuz burada görüntülenecek.'
                        : 'Şirket üyelerinden biri bir analizi tamamladığında ortak rapor burada görüntülenecek.',
                    bottomPadding: 110,
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refreshInspections,

                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),

                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),

                    itemCount: inspections.length + 1,

                    separatorBuilder: (context, index) =>
                        SizedBox(height: index == 0 ? 18 : 14),

                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _HistoryHeader(
                          inspectionCount: inspections.length,
                          businessAccount: widget.businessAccount,
                        );
                      }

                      final inspection = inspections[index - 1];

                      return _InspectionHistoryCard(
                        inspection: inspection,

                        severityLabel: _severityLabel(
                          inspection.damageSeverity,
                        ),

                        severityColor: _severityColor(
                          inspection.damageSeverity,
                        ),

                        severitySoftColor: _severitySoftColor(
                          inspection.damageSeverity,
                        ),

                        severityIcon: _severityIcon(inspection.damageSeverity),

                        date: _formatDate(
                          inspection.completedAt ?? inspection.createdAt,
                        ),

                        affectedParts: inspection.affectedParts
                            .take(3)
                            .map(_vehiclePartLabel)
                            .toList(),

                        onTap: () => _openInspection(inspection),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.inspectionCount,
    required this.businessAccount,
  });

  final int inspectionCount;
  final BusinessAccount? businessAccount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          businessAccount == null
              ? 'Analiz geçmişiniz'
              : '${businessAccount!.companyName} analizleri',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),

        const SizedBox(height: 7),

        Text(
          businessAccount == null
              ? 'Tamamlanan araç hasar analizlerinizi ve AI raporlarınızı inceleyin.'
              : 'Tüm şirket üyelerinin tamamladığı ortak analizleri ve AI raporlarını inceleyin. Günlük ortak sınır 100 analizdir.',
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),

        const SizedBox(height: 18),

        AppStatusBadge(
          icon: Icons.history_rounded,
          label: '$inspectionCount tamamlanan analiz',
          color: colorScheme.primary,
          backgroundColor: colorScheme.primaryContainer,
        ),
      ],
    );
  }
}

class _InspectionHistoryCard extends StatelessWidget {
  const _InspectionHistoryCard({
    required this.inspection,
    required this.severityLabel,
    required this.severityColor,
    required this.severitySoftColor,
    required this.severityIcon,
    required this.date,
    required this.affectedParts,
    required this.onTap,
  });

  final DamageInspection inspection;

  final String severityLabel;

  final Color severityColor;
  final Color severitySoftColor;

  final IconData severityIcon;

  final String date;

  final List<String> affectedParts;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: severitySoftColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(severityIcon, color: severityColor, size: 27),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inspection.vehiclePlate,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 5),

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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              AppStatusBadge(
                label: severityLabel,
                color: severityColor,
                backgroundColor: severitySoftColor,
                compact: true,
              ),

              const Spacer(),

              Icon(
                Icons.calendar_today_outlined,
                size: 15,
                color: colorScheme.onSurfaceVariant,
              ),

              const SizedBox(width: 5),

              Text(
                date,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          if (affectedParts.isNotEmpty) ...[
            const SizedBox(height: 15),

            Divider(color: colorScheme.outlineVariant, height: 1),

            const SizedBox(height: 14),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.build_outlined,
                  size: 17,
                  color: colorScheme.primary,
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    affectedParts.join(' • '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
