import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
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
        final completedInspections =
        inspections
            .where(
              (inspection) =>
          inspection.status == 'COMPLETED',
        )
            .toList();

        if (completedInspections.isNotEmpty) {
          completedInspections.sort(
                (a, b) {
              final aDate =
                  a.completedAt ??
                      a.createdAt ??
                      DateTime.fromMillisecondsSinceEpoch(
                        0,
                      );

              final bDate =
                  b.completedAt ??
                      b.createdAt ??
                      DateTime.fromMillisecondsSinceEpoch(
                        0,
                      );

              return bDate.compareTo(aDate);
            },
          );

          latestInspection =
              completedInspections.first;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _vehicle =
        vehicles.isNotEmpty
            ? vehicles.first
            : null;

        _latestInspection =
            latestInspection;

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
    final inspection =
        _latestInspection;

    if (inspection == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            InspectionResultScreen(
              inspection: inspection,
            ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadHomeData();
  }

  String _severityLabel(
      String? severity,
      ) {
    return switch (severity) {
      'NONE' =>
      'Görünür Hasar Tespit Edilmedi',
      'MINOR' =>
      'Hafif Seviye Hasar',
      'MODERATE' =>
      'Orta Seviye Hasar',
      'SEVERE' =>
      'Ağır Seviye Hasar',
      'UNKNOWN' =>
      'Hasar Seviyesi Belirsiz',
      _ =>
      'Analiz Sonucu',
    };
  }

  String _severityShortLabel(
      String? severity,
      ) {
    return switch (severity) {
      'NONE' => 'HASAR YOK',
      'MINOR' => 'HAFİF',
      'MODERATE' => 'ORTA',
      'SEVERE' => 'AĞIR',
      _ => 'BELİRSİZ',
    };
  }

  Color _severityColor(
      String? severity,
      ) {
    return switch (severity) {
      'NONE' =>
      AppTheme.severityNone,
      'MINOR' =>
      AppTheme.severityMinor,
      'MODERATE' =>
      AppTheme.severityModerate,
      'SEVERE' =>
      AppTheme.severitySevere,
      _ =>
      AppTheme.severityUnknown,
    };
  }

  String _damageSummary(
      DamageInspection inspection,
      ) {
    if (inspection.affectedParts.isEmpty) {
      return 'Hasar analizi tamamlandı';
    }

    return inspection.affectedParts
        .take(3)
        .map(_vehiclePartLabel)
        .join(' • ');
  }

  String _vehiclePartLabel(
      String part,
      ) {
    return switch (part) {
      'UNKNOWN' =>
      'Bilinmeyen Parça',

      'FRONT_BUMPER' =>
      'Ön Tampon',

      'REAR_BUMPER' =>
      'Arka Tampon',

      'FRONT_DOOR' =>
      'Ön Kapı',

      'REAR_DOOR' =>
      'Arka Kapı',

      'FRONT_WHEEL' =>
      'Ön Tekerlek',

      'REAR_WHEEL' =>
      'Arka Tekerlek',

      'FRONT_WINDOW' =>
      'Ön Yan Cam',

      'REAR_WINDOW' =>
      'Arka Yan Cam',

      'WINDSHIELD' =>
      'Ön Cam',

      'REAR_WINDSHIELD' =>
      'Arka Cam',

      'FENDER' =>
      'Çamurluk',

      'QUARTER_PANEL' =>
      'Arka Çamurluk Paneli',

      'ROCKER_PANEL' =>
      'Marşpiyel',

      'GRILLE' =>
      'Ön Izgara',

      'HEADLIGHT' =>
      'Far',

      'TAIL_LIGHT' =>
      'Arka Stop Lambası',

      'HOOD' =>
      'Kaput',

      'LICENSE_PLATE' =>
      'Plaka',

      'MIRROR' =>
      'Yan Ayna',

      'ROOF' =>
      'Tavan',

      'TRUNK' =>
      'Bagaj Kapağı',

      _ => part,
    };
  }

  String _formatDate(
      DateTime? date,
      ) {
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

  String _firstName() {
    final value =
    widget.fullName.trim();

    if (value.isEmpty) {
      return 'Kullanıcı';
    }

    return value
        .split(RegExp(r'\s+'))
        .first;
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final textTheme =
        Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
            const BoxConstraints(
              maxWidth:
              AppTheme.maxContentWidth,
            ),
            child: RefreshIndicator(
              onRefresh:
              _loadHomeData,
              child: ListView(
                physics:
                const AlwaysScrollableScrollPhysics(),

                padding:
                AppTheme.pagePadding,

                children: [
                  _HomeHeader(
                    fullName:
                    widget.fullName,
                    firstName:
                    _firstName(),
                  ),

                  const SizedBox(
                    height:
                    AppTheme.spacingL,
                  ),

                  _AnalysisHeroCard(
                    onPressed:
                    _startInspection,
                  ),

                  const SizedBox(
                    height:
                    AppTheme.spacingXL,
                  ),

                  SectionTitle(
                    title:
                    'Aracım',
                    actionLabel:
                    'Tümünü Gör',
                    onActionPressed:
                    widget.onOpenVehicles,
                  ),

                  const SizedBox(
                    height:
                    AppTheme.spacingM,
                  ),

                  if (_isLoading)
                    const _LoadingCard()
                  else if (_vehicle != null)
                    AppCard(
                      onTap:
                      widget
                          .onOpenVehicles,

                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,

                            decoration:
                            BoxDecoration(
                              color:
                              colorScheme
                                  .primaryContainer,

                              borderRadius:
                              BorderRadius.circular(
                                AppTheme
                                    .radiusMedium,
                              ),
                            ),

                            child: Icon(
                              Icons
                                  .directions_car_filled_rounded,

                              color:
                              colorScheme
                                  .primary,

                              size: 30,
                            ),
                          ),

                          const SizedBox(
                            width: 16,
                          ),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,

                              children: [
                                Text(
                                  _vehicle!
                                      .displayName,

                                  style:
                                  textTheme
                                      .titleMedium
                                      ?.copyWith(
                                    fontWeight:
                                    FontWeight
                                        .w800,
                                  ),
                                ),

                                const SizedBox(
                                  height: 6,
                                ),

                                Text(
                                  '${_vehicle!.plate}  •  '
                                      '${_vehicle!.modelYear}',

                                  style:
                                  textTheme
                                      .bodyMedium,
                                ),
                              ],
                            ),
                          ),

                          Container(
                            width: 36,
                            height: 36,

                            decoration:
                            BoxDecoration(
                              color:
                              colorScheme
                                  .surfaceContainer,

                              borderRadius:
                              BorderRadius.circular(
                                12,
                              ),
                            ),

                            child: Icon(
                              Icons
                                  .arrow_forward_ios_rounded,

                              size: 15,

                              color:
                              colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    AppCard(
                      onTap:
                      widget
                          .onOpenVehicles,

                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,

                            decoration:
                            BoxDecoration(
                              color:
                              colorScheme
                                  .primaryContainer,

                              borderRadius:
                              BorderRadius.circular(
                                AppTheme
                                    .radiusMedium,
                              ),
                            ),

                            child: Icon(
                              Icons
                                  .add_rounded,

                              color:
                              colorScheme
                                  .primary,
                            ),
                          ),

                          const SizedBox(
                            width: 14,
                          ),

                          const Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,

                              children: [
                                Text(
                                  'Araç ekleyin',

                                  style:
                                  TextStyle(
                                    fontWeight:
                                    FontWeight
                                        .w800,
                                  ),
                                ),

                                SizedBox(
                                  height: 4,
                                ),

                                Text(
                                  'Analiz başlatmak için önce aracınızı kaydedin.',
                                ),
                              ],
                            ),
                          ),

                          const Icon(
                            Icons
                                .chevron_right_rounded,
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(
                    height:
                    AppTheme.spacingXL,
                  ),

                  SectionTitle(
                    title:
                    'Son Analiz',
                    actionLabel:
                    'Geçmiş',
                    onActionPressed:
                    widget
                        .onOpenInspections,
                  ),

                  const SizedBox(
                    height:
                    AppTheme.spacingM,
                  ),

                  if (_isLoading)
                    const _LoadingCard()
                  else if (_latestInspection !=
                      null)
                    _LatestInspectionCard(
                      inspection:
                      _latestInspection!,

                      title:
                      _severityLabel(
                        _latestInspection!
                            .damageSeverity,
                      ),

                      severityLabel:
                      _severityShortLabel(
                        _latestInspection!
                            .damageSeverity,
                      ),

                      severityColor:
                      _severityColor(
                        _latestInspection!
                            .damageSeverity,
                      ),

                      summary:
                      _damageSummary(
                        _latestInspection!,
                      ),

                      date:
                      _formatDate(
                        _latestInspection!
                            .completedAt ??
                            _latestInspection!
                                .createdAt,
                      ),

                      onTap:
                      _openLatestInspection,
                    )
                  else
                    AppCard(
                      onTap:
                      _startInspection,

                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,

                            decoration:
                            BoxDecoration(
                              color:
                              colorScheme
                                  .surfaceContainer,

                              borderRadius:
                              BorderRadius.circular(
                                AppTheme
                                    .radiusMedium,
                              ),
                            ),

                            child: Icon(
                              Icons
                                  .analytics_outlined,

                              color:
                              colorScheme
                                  .primary,
                            ),
                          ),

                          const SizedBox(
                            width: 14,
                          ),

                          const Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,

                              children: [
                                Text(
                                  'Henüz analiz yok',

                                  style:
                                  TextStyle(
                                    fontWeight:
                                    FontWeight
                                        .w800,
                                  ),
                                ),

                                SizedBox(
                                  height: 4,
                                ),

                                Text(
                                  'İlk AI hasar analizini başlatın.',
                                ),
                              ],
                            ),
                          ),

                          const Icon(
                            Icons
                                .chevron_right_rounded,
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
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.fullName,
    required this.firstName,
  });

  final String fullName;
  final String firstName;

  @override
  Widget build(
      BuildContext context,
      ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final textTheme =
        Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              Text(
                'Hoş geldin',

                style:
                textTheme.bodyMedium
                    ?.copyWith(
                  color:
                  colorScheme
                      .onSurfaceVariant,

                  fontWeight:
                  FontWeight.w600,
                ),
              ),

              const SizedBox(
                height: 3,
              ),

              Text(
                firstName,

                style:
                textTheme
                    .headlineMedium
                    ?.copyWith(
                  fontWeight:
                  FontWeight.w900,
                ),
              ),
            ],
          ),
        ),

        Container(
          width: 48,
          height: 48,

          decoration:
          BoxDecoration(
            gradient:
            const LinearGradient(
              colors: [
                AppTheme.primaryColor,
                AppTheme.secondaryColor,
              ],

              begin:
              Alignment.topLeft,

              end:
              Alignment.bottomRight,
            ),

            borderRadius:
            BorderRadius.circular(
              16,
            ),

            boxShadow:
            AppTheme.primaryShadow,
          ),

          alignment:
          Alignment.center,

          child: Text(
            _initials(
              fullName,
            ),

            style:
            const TextStyle(
              color:
              Colors.white,

              fontWeight:
              FontWeight.w900,

              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  static String _initials(
      String fullName,
      ) {
    final parts =
    fullName
        .trim()
        .split(
      RegExp(r'\s+'),
    )
        .where(
          (part) =>
      part.isNotEmpty,
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
        parts.first
            .substring(0, 1) +
            parts.last
                .substring(0, 1)
    ).toUpperCase();
  }
}

class _AnalysisHeroCard
    extends StatelessWidget {
  const _AnalysisHeroCard({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(
      BuildContext context,
      ) {
    final textTheme =
        Theme.of(context).textTheme;

    return Container(
      padding:
      const EdgeInsets.all(
        24,
      ),

      decoration:
      BoxDecoration(
        gradient:
        const LinearGradient(
          colors: [
            Color(
              0xFF0F3D74,
            ),
            AppTheme.primaryColor,
            AppTheme.secondaryColor,
          ],

          begin:
          Alignment.topLeft,

          end:
          Alignment.bottomRight,
        ),

        borderRadius:
        BorderRadius.circular(
          AppTheme.radiusXLarge,
        ),

        boxShadow:
        AppTheme.primaryShadow,
      ),

      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -45,

            child: Container(
              width: 150,
              height: 150,

              decoration:
              BoxDecoration(
                color:
                Colors.white
                    .withValues(
                  alpha: 0.06,
                ),

                shape:
                BoxShape.circle,
              ),
            ),
          ),

          Positioned(
            right: 30,
            bottom: -70,

            child: Container(
              width: 130,
              height: 130,

              decoration:
              BoxDecoration(
                color:
                Colors.white
                    .withValues(
                  alpha: 0.05,
                ),

                shape:
                BoxShape.circle,
              ),
            ),
          ),

          Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              Row(
                children: [
                  Container(
                    padding:
                    const EdgeInsets
                        .symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),

                    decoration:
                    BoxDecoration(
                      color:
                      Colors.white
                          .withValues(
                        alpha: 0.14,
                      ),

                      borderRadius:
                      BorderRadius.circular(
                        AppTheme.radiusPill,
                      ),
                    ),

                    child:
                    const Row(
                      mainAxisSize:
                      MainAxisSize.min,

                      children: [
                        Icon(
                          Icons
                              .auto_awesome_rounded,

                          size: 15,

                          color:
                          Colors.white,
                        ),

                        SizedBox(
                          width: 6,
                        ),

                        Text(
                          'AI INSPECTION',

                          style:
                          TextStyle(
                            color:
                            Colors.white,

                            fontSize: 11,

                            fontWeight:
                            FontWeight
                                .w800,

                            letterSpacing:
                            0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 20,
              ),

              Text(
                'Aracını yapay zekâ\nile analiz et',

                style:
                textTheme
                    .headlineMedium
                    ?.copyWith(
                  color:
                  Colors.white,

                  fontWeight:
                  FontWeight.w900,

                  height: 1.08,

                  letterSpacing:
                  -0.8,
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              Text(
                'Hasarlı bölgenin fotoğrafını yükle. '
                    'AI hasarı, etkilenen parçaları ve '
                    'onarım önerilerini analiz etsin.',

                style:
                textTheme
                    .bodyMedium
                    ?.copyWith(
                  color:
                  Colors.white
                      .withValues(
                    alpha: 0.82,
                  ),

                  height: 1.5,
                ),
              ),

              const SizedBox(
                height: 22,
              ),

              FilledButton.icon(
                onPressed:
                onPressed,

                style:
                FilledButton
                    .styleFrom(
                  backgroundColor:
                  Colors.white,

                  foregroundColor:
                  AppTheme
                      .primaryDark,

                  minimumSize:
                  const Size(
                    double.infinity,
                    52,
                  ),

                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius
                        .circular(
                      AppTheme
                          .radiusMedium,
                    ),
                  ),
                ),

                icon:
                const Icon(
                  Icons
                      .photo_camera_outlined,
                ),

                label:
                const Text(
                  'Yeni Analiz Başlat',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LatestInspectionCard
    extends StatelessWidget {
  const _LatestInspectionCard({
    required this.inspection,
    required this.title,
    required this.severityLabel,
    required this.severityColor,
    required this.summary,
    required this.date,
    required this.onTap,
  });

  final DamageInspection inspection;

  final String title;
  final String severityLabel;

  final Color severityColor;

  final String summary;
  final String date;

  final VoidCallback onTap;

  @override
  Widget build(
      BuildContext context,
      ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final textTheme =
        Theme.of(context).textTheme;

    return AppCard(
      onTap:
      onTap,

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),

                decoration:
                BoxDecoration(
                  color:
                  severityColor
                      .withValues(
                    alpha: 0.12,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    AppTheme.radiusPill,
                  ),
                ),

                child: Row(
                  mainAxisSize:
                  MainAxisSize.min,

                  children: [
                    Container(
                      width: 7,
                      height: 7,

                      decoration:
                      BoxDecoration(
                        color:
                        severityColor,

                        shape:
                        BoxShape.circle,
                      ),
                    ),

                    const SizedBox(
                      width: 6,
                    ),

                    Text(
                      severityLabel,

                      style:
                      TextStyle(
                        fontSize: 11,

                        color:
                        severityColor,

                        fontWeight:
                        FontWeight
                            .w800,

                        letterSpacing:
                        0.4,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              Icon(
                Icons
                    .north_east_rounded,

                size: 19,

                color:
                colorScheme
                    .onSurfaceVariant,
              ),
            ],
          ),

          const SizedBox(
            height: 18,
          ),

          Text(
            title,

            style:
            textTheme
                .titleLarge
                ?.copyWith(
              fontWeight:
              FontWeight.w900,
            ),
          ),

          const SizedBox(
            height: 7,
          ),

          Text(
            summary,

            maxLines: 2,

            overflow:
            TextOverflow.ellipsis,

            style:
            textTheme.bodyMedium,
          ),

          const SizedBox(
            height: 18,
          ),

          Row(
            children: [
              Icon(
                Icons
                    .directions_car_outlined,

                size: 17,

                color:
                colorScheme
                    .onSurfaceVariant,
              ),

              const SizedBox(
                width: 6,
              ),

              Expanded(
                child: Text(
                  inspection
                      .vehiclePlate,

                  style:
                  textTheme
                      .bodySmall
                      ?.copyWith(
                    fontWeight:
                    FontWeight
                        .w700,
                  ),
                ),
              ),

              Icon(
                Icons
                    .calendar_today_outlined,

                size: 15,

                color:
                colorScheme
                    .onSurfaceVariant,
              ),

              const SizedBox(
                width: 6,
              ),

              Text(
                date,

                style:
                textTheme
                    .bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingCard
    extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(
      BuildContext context,
      ) {
    return const AppCard(
      child: SizedBox(
        height: 68,

        child: Center(
          child:
          CircularProgressIndicator(),
        ),
      ),
    );
  }
}