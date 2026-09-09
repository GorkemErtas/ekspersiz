import 'package:flutter/material.dart';

import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_title.dart';

import '../../inspection/models/damage_inspection.dart';
import '../../inspection/screens/create_inspection_screen.dart';
import '../../inspection/screens/inspection_result_screen.dart';
import '../../inspection/services/inspection_service.dart';

import '../../vehicle/models/vehicle.dart';
import '../../vehicle/services/vehicle_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.fullName,
    required this.onOpenVehicles,
    required this.onOpenInspections,
  });

  final String fullName;
  final VoidCallback onOpenVehicles;
  final VoidCallback onOpenInspections;

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final VehicleService _vehicleService =
  const VehicleService();

  final InspectionService _inspectionService =
  const InspectionService();

  bool _isLoading = true;

  Vehicle? _vehicle;
  DamageInspection? _latestInspection;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final results = await Future.wait([
        _vehicleService.getVehicles(),
        _inspectionService.getInspections(),
      ]);

      final vehicles =
      results[0] as List<Vehicle>;

      final inspections =
      results[1] as List<DamageInspection>;

      DamageInspection? latestInspection;

      if (inspections.isNotEmpty) {
        final sorted =
        List<DamageInspection>.from(
          inspections,
        );

        sorted.sort((a, b) {
          final aDate =
              a.completedAt ??
                  a.createdAt ??
                  DateTime.fromMillisecondsSinceEpoch(0);

          final bDate =
              b.completedAt ??
                  b.createdAt ??
                  DateTime.fromMillisecondsSinceEpoch(0);

          return bDate.compareTo(aDate);
        });

        latestInspection = sorted.first;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _vehicle =
        vehicles.isNotEmpty ? vehicles.first : null;

        _latestInspection = latestInspection;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _startInspection() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
        const CreateInspectionScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadHomeData();
  }

  Future<void> _openLatestInspection() async {
    final inspection = _latestInspection;

    if (inspection == null) {
      return;
    }

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

    await _loadHomeData();
  }

  String _severityLabel(String? severity) {
    return switch (severity) {
      'NONE' => 'Görünür Hasar Tespit Edilmedi',
      'MINOR' => 'Hafif Seviyeli Hasar',
      'MODERATE' => 'Orta Seviyeli Hasar',
      'SEVERE' => 'Ağır Seviyeli Hasar',
      'UNKNOWN' => 'Hasar Seviyesi Belirsiz',
      _ => 'Analiz Bekleniyor',
    };
  }

  String _damageSummary(
      DamageInspection inspection,
      ) {
    if (inspection.affectedParts.isEmpty) {
      return 'Hasar analizi tamamlandı';
    }

    final parts = inspection.affectedParts
        .take(3)
        .map(_vehiclePartLabel)
        .join(', ');

    return parts;
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

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '-';
    }

    final months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];

    return '${date.day} '
        '${months[date.month - 1]} '
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final textTheme =
        Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Vehicle Inspector',
        ),
        actions: [
          Padding(
            padding:
            const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 20,
              backgroundColor:
              colorScheme.primaryContainer,
              child: Text(
                _initials(widget.fullName),
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1100,
              ),
              child: RefreshIndicator(
          onRefresh: _loadHomeData,
          child: ListView(
            physics:
            const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              28,
            ),
            children: [
              Text(
                'Hoş geldiniz,',
                style: textTheme.bodyLarge?.copyWith(
                  color:
                  colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.fullName,
                style:
                textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),

              const SizedBox(height: 28),

              SectionTitle(
                title: 'Aracınız',
                actionLabel: 'Tümünü Gör',
                onActionPressed:
                widget.onOpenVehicles,
              ),

              const SizedBox(height: 12),

              if (_isLoading)
                const _LoadingCard()
              else if (_vehicle != null)
                AppCard(
                  onTap: widget.onOpenVehicles,
                  child: Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
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
                              .directions_car_filled_outlined,
                          color:
                          colorScheme.primary,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              _vehicle!.displayName,
                              style:
                              const TextStyle(
                                fontSize: 17,
                                fontWeight:
                                FontWeight.w800,
                              ),
                            ),
                            const SizedBox(
                              height: 5,
                            ),
                            Text(
                              '${_vehicle!.plate} • '
                                  '${_vehicle!.modelYear}',
                              style: TextStyle(
                                color: colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colorScheme
                            .onSurfaceVariant,
                      ),
                    ],
                  ),
                )
              else
                AppCard(
                  onTap: widget.onOpenVehicles,
                  child: Row(
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Henüz araç eklenmemiş. '
                              'Araç eklemek için dokunun.',
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              AppCard(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius:
                        BorderRadius.circular(
                          18,
                        ),
                      ),
                      child: Icon(
                        Icons.camera_alt_outlined,
                        color: colorScheme.onPrimary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Yeni Hasar Analizi',
                      style:
                      textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hasarlı bölgenin fotoğrafını çekin '
                          've AI destekli raporu görüntüleyin.',
                      style:
                      textTheme.bodyMedium?.copyWith(
                        color: colorScheme
                            .onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'Analize Başla',
                      icon:
                      Icons.arrow_forward_rounded,
                      onPressed: _startInspection,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              SectionTitle(
                title: 'Son Analiz',
                actionLabel: 'Geçmiş',
                onActionPressed:
                widget.onOpenInspections,
              ),

              const SizedBox(height: 12),

              if (_isLoading)
                const _LoadingCard()
              else if (_latestInspection != null)
                AppCard(
                  onTap: _openLatestInspection,
                  child: Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: colorScheme
                              .primaryContainer,
                          borderRadius:
                          BorderRadius.circular(
                            17,
                          ),
                        ),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: colorScheme.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              _severityLabel(
                                _latestInspection!
                                    .damageSeverity,
                              ),
                              style:
                              const TextStyle(
                                fontSize: 16,
                                fontWeight:
                                FontWeight.w800,
                              ),
                            ),
                            const SizedBox(
                              height: 6,
                            ),
                            Text(
                              _damageSummary(
                                _latestInspection!,
                              ),
                              style: TextStyle(
                                color: colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(
                              height: 8,
                            ),
                            Text(
                              _formatDate(
                                _latestInspection!
                                    .completedAt ??
                                    _latestInspection!
                                        .createdAt,
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colorScheme
                            .onSurfaceVariant,
                      ),
                    ],
                  ),
                )
              else
                AppCard(
                  onTap: _startInspection,
                  child: Row(
                    children: [
                      Icon(
                        Icons
                            .analytics_outlined,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Henüz hasar analizi '
                              'bulunmuyor.',
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
          ),
      ),
    );
  }

  static String _initials(
      String fullName,
      ) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where(
          (part) => part.isNotEmpty,
    )
        .toList();

    if (parts.isEmpty) {
      return 'VI';
    }

    if (parts.length == 1) {
      return parts.first
          .substring(0, 1)
          .toUpperCase();
    }

    return (
        parts.first.substring(0, 1) +
            parts.last.substring(0, 1)
    ).toUpperCase();
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: SizedBox(
        height: 58,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}