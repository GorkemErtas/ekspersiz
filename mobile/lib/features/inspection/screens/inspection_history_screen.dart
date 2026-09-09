import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../models/damage_inspection.dart';
import '../services/inspection_service.dart';
import 'inspection_result_screen.dart';

class InspectionHistoryScreen extends StatefulWidget {
  const InspectionHistoryScreen({super.key});

  @override
  State<InspectionHistoryScreen> createState() =>
      _InspectionHistoryScreenState();
}

class _InspectionHistoryScreenState
    extends State<InspectionHistoryScreen> {
  final InspectionService _inspectionService =
  const InspectionService();

  late Future<List<DamageInspection>> _inspectionsFuture;

  @override
  void initState() {
    super.initState();
    _loadInspections();
  }

  void _loadInspections() {
    _inspectionsFuture =
        _inspectionService.getInspections();
  }

  Future<void> _refreshInspections() async {
    setState(_loadInspections);

    try {
      await _inspectionsFuture;
    } catch (_) {
    }
  }

  Future<void> _openInspection(
      DamageInspection inspection,
      ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InspectionResultScreen(
          inspection: inspection,
        ),
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
      'UNKNOWN' => 'Hasar Seviyesi Belirsiz',
      _ => 'Analiz Bekleniyor',
    };
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '-';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month =
    date.month.toString().padLeft(2, '0');

    return '$day.$month.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analizler'),
      ),
      body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1100,
              ),
              child: FutureBuilder<List<DamageInspection>>(
          future: _inspectionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              final error = snapshot.error;

              final message = error is ApiException
                  ? error.message
                  : 'Analiz geçmişi yüklenemedi.';

              return _InspectionErrorState(
                message: message,
                onRetry: () {
                  setState(_loadInspections);
                },
              );
            }

            final inspections =
                snapshot.data ??
                    const <DamageInspection>[];

            if (inspections.isEmpty) {
              return const _InspectionEmptyState();
            }

            return RefreshIndicator(
              onRefresh: _refreshInspections,
              child: ListView.separated(
                physics:
                const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  28,
                ),
                itemCount: inspections.length,
                separatorBuilder: (_, __) =>
                const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final inspection =
                  inspections[index];

                  return AppCard(
                    onTap: () =>
                        _openInspection(
                          inspection,
                        ),
                    child: Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: colorScheme
                                .primaryContainer,
                            borderRadius:
                            BorderRadius.circular(
                              18,
                            ),
                          ),
                          child: Icon(
                            Icons
                                .car_crash_outlined,
                            color:
                            colorScheme.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [
                              Text(
                                _severityLabel(
                                  inspection
                                      .damageSeverity,
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight:
                                  FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${inspection.vehiclePlate} • ${inspection.locationCity}',
                                style: TextStyle(
                                  color: colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _formatDate(
                                  inspection
                                      .completedAt ??
                                      inspection
                                          .createdAt,
                                ),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              if (inspection
                                  .affectedParts
                                  .isNotEmpty) ...[
                                const SizedBox(
                                  height: 8,
                                ),
                                Text(
                                  inspection.affectedParts
                                      .take(3)
                                      .map(_vehiclePartLabel)
                                      .join(', '),
                                  maxLines: 1,
                                  overflow:
                                  TextOverflow
                                      .ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color:
                          colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
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

class _InspectionEmptyState extends StatelessWidget {
  const _InspectionEmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius:
                BorderRadius.circular(26),
              ),
              child: Icon(
                Icons.description_outlined,
                size: 42,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Henüz analiz bulunmuyor',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Yeni bir hasar analizi oluşturduğunuzda burada görüntülenecek.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InspectionErrorState extends StatelessWidget {
  const _InspectionErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 52,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                'Tekrar Dene',
              ),
            ),
          ],
        ),
      ),
    );
  }
}