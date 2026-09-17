import 'package:flutter/material.dart';
import 'dart:async';

import '../../../core/ads/free_plan_banner.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/section_title.dart';
import '../../auth/models/business_account.dart';

import '../../inspection/models/damage_inspection.dart';
import '../../inspection/screens/create_inspection_screen.dart';
import '../../inspection/screens/inspection_result_screen.dart';
import '../../inspection/services/inspection_service.dart';

import '../../vehicle/models/vehicle.dart';
import '../../vehicle/services/vehicle_service.dart';
import '../../vehicle/services/vehicle_tracking_service.dart';
import '../../vehicle/models/vehicle_overview.dart';
import '../../notification/screens/notification_center_screen.dart';
import '../../notification/services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.fullName,
    required this.subscriptionPlan,
    this.businessAccount,
    required this.onOpenVehicles,
    required this.onOpenInspections,
    required this.onOpenProfile,
  });

  final String fullName;
  final String subscriptionPlan;
  final BusinessAccount? businessAccount;
  final VoidCallback onOpenVehicles;
  final VoidCallback onOpenInspections;
  final VoidCallback onOpenProfile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final VehicleService _vehicleService = const VehicleService();
  final InspectionService _inspectionService = const InspectionService();
  final VehicleTrackingService _trackingService =
      const VehicleTrackingService();
  final NotificationService _notificationService = const NotificationService();
  StreamSubscription<void>? _notificationSubscription;

  bool _isLoading = true;

  List<Vehicle> _vehicles = const [];
  Vehicle? _mainVehicle;
  DamageInspection? _latestInspection;
  VehicleOverview? _vehicleOverview;
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
    _loadNotificationCount();
    _notificationSubscription = PushNotificationService.instance.events.listen(
      (_) => _loadNotificationCount(),
    );
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadNotificationCount() async {
    try {
      final count = await _notificationService.getUnreadCount();
      if (mounted) setState(() => _unreadNotificationCount = count);
    } catch (_) {
      // Notification count must never block the primary inspection experience.
    }
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
      ]).timeout(const Duration(seconds: 12));

      final vehicles = results[0] as List<Vehicle>;
      final inspections = results[1] as List<DamageInspection>;

      final completedInspections =
          inspections
              .where((inspection) => inspection.status == 'COMPLETED')
              .toList()
            ..sort((a, b) {
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

      Vehicle? mainVehicle;

      for (final vehicle in vehicles) {
        if (vehicle.primaryVehicle) {
          mainVehicle = vehicle;
          break;
        }
      }

      mainVehicle ??= vehicles.isNotEmpty ? vehicles.first : null;

      VehicleOverview? overview;
      if (mainVehicle != null) {
        overview = await _trackingService.getOverview(mainVehicle.id);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _vehicles = vehicles;
        _mainVehicle = mainVehicle;
        _latestInspection = completedInspections.isNotEmpty
            ? completedInspections.first
            : null;
        _vehicleOverview = overview;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('HOME ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  Route<T> _premiumRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, animation, _) => page,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        final slide = Tween<Offset>(
          begin: const Offset(0.04, 0.025),
          end: Offset.zero,
        ).animate(curved);

        return FadeTransition(
          opacity: curved,
          child: SlideTransition(position: slide, child: child),
        );
      },
    );
  }

  Future<void> _startInspection() async {
    await Navigator.of(context).push(
      _premiumRoute<void>(
        CreateInspectionScreen(businessAccount: widget.businessAccount),
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
      await _startInspection();
      return;
    }

    await Navigator.of(
      context,
    ).push(_premiumRoute<void>(InspectionResultScreen(inspection: inspection)));

    if (!mounted) {
      return;
    }

    await _loadHomeData();
  }

  Future<void> _selectMainVehicle() async {
    if (_vehicles.isEmpty) {
      widget.onOpenVehicles();
      return;
    }

    final selectedVehicle = await showModalBottomSheet<Vehicle>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ana Aracı Seç',
                          style: Theme.of(sheetContext).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(
                        '${_vehicles.length} araç',
                        style: Theme.of(sheetContext).textTheme.bodySmall
                            ?.copyWith(
                              color: Theme.of(
                                sheetContext,
                              ).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: _vehicles.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final vehicle = _vehicles[index];
                      final isSelected = vehicle.id == _mainVehicle?.id;

                      return Material(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                                  .withValues(alpha: 0.55)
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.of(sheetContext).pop(vehicle);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.directions_car_filled_rounded,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        vehicle.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${vehicle.plate} • ${vehicle.modelYear}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  )
                                else
                                  Icon(
                                    Icons.circle_outlined,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedVehicle == null || !mounted) {
      return;
    }

    if (selectedVehicle.id == _mainVehicle?.id) {
      return;
    }

    try {
      final updatedVehicle = await _vehicleService.setPrimaryVehicle(
        selectedVehicle.id,
      );
      final overview = await _trackingService.getOverview(updatedVehicle.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _mainVehicle = updatedVehicle;
        _vehicleOverview = overview;
        _vehicles = _vehicles
            .map(
              (vehicle) => Vehicle(
                id: vehicle.id,
                plate: vehicle.plate,
                brand: vehicle.brand,
                model: vehicle.model,
                modelYear: vehicle.modelYear,
                mileage: vehicle.mileage,
                primaryVehicle: vehicle.id == updatedVehicle.id,
                notes: vehicle.notes,
                createdAt: vehicle.createdAt,
              ),
            )
            .toList();
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${updatedVehicle.displayName} ana araç olarak seçildi.',
            ),
          ),
        );
    } catch (error, stackTrace) {
      debugPrint('HOME ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Ana araç değiştirilemedi. Lütfen tekrar deneyin.'),
          ),
        );
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            NotificationCenterScreen(businessAccount: widget.businessAccount),
      ),
    );
    await _loadNotificationCount();
  }

  String _severityLabel(String? severity) {
    return switch (severity) {
      'NONE' => 'Görünür Hasar Tespit Edilmedi',
      'MINOR' => 'Hafif Seviye Hasar',
      'MODERATE' => 'Orta Seviye Hasar',
      'SEVERE' => 'Ağır Seviye Hasar',
      'UNKNOWN' => 'Hasar Seviyesi Belirsiz',
      _ => 'Analiz Sonucu',
    };
  }

  String _severityShortLabel(String? severity) {
    return switch (severity) {
      'NONE' => 'HASAR YOK',
      'MINOR' => 'HAFİF',
      'MODERATE' => 'ORTA',
      'SEVERE' => 'AĞIR',
      _ => 'BELİRSİZ',
    };
  }

  Color _severityColor(String? severity) {
    return switch (severity) {
      'NONE' => AppTheme.successColorFor(context),
      'MINOR' => AppTheme.warningColorFor(context),
      'MODERATE' => AppTheme.moderateColorFor(context),
      'SEVERE' => AppTheme.dangerColorFor(context),
      _ => AppTheme.neutralColorFor(context),
    };
  }

  String _damageSummary(DamageInspection inspection) {
    if (inspection.affectedParts.isEmpty) {
      return 'Hasar analizi tamamlandı';
    }

    return inspection.affectedParts.take(3).map(_vehiclePartLabel).join(' • ');
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

    const months = [
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

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatMileage(int mileage) {
    final value = mileage.toString();
    final buffer = StringBuffer();

    for (var index = 0; index < value.length; index++) {
      final reversedIndex = value.length - index;
      buffer.write(value[index]);

      if (reversedIndex > 1 && reversedIndex % 3 == 1) {
        buffer.write('.');
      }
    }

    return buffer.toString();
  }

  String _firstName() {
    final value = widget.fullName.trim();

    if (value.isEmpty) {
      return 'Kullanıcı';
    }

    return value.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppTheme.maxContentWidth,
            ),
            child: RefreshIndicator(
              onRefresh: _loadHomeData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppTheme.pagePadding,
                children: [
                  AppFadeSlideIn(
                    delay: const Duration(milliseconds: 20),
                    child: _DashboardHeader(
                      fullName: widget.fullName,
                      firstName: _firstName(),
                      onProfileTap: widget.onOpenProfile,
                      onNotificationTap: _openNotifications,
                      unreadCount: _unreadNotificationCount,
                    ),
                  ),
                  if (widget.businessAccount != null) ...[
                    const SizedBox(height: AppTheme.spacingM),
                    AppFadeSlideIn(
                      delay: const Duration(milliseconds: 45),
                      child: _BusinessContextCard(
                        businessAccount: widget.businessAccount!,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppTheme.spacingL),
                  AppFadeSlideIn(
                    delay: const Duration(milliseconds: 70),
                    child: _HeroAnalysisCard(onTap: _startInspection),
                  ),
                  if (!_isLoading && _vehicleOverview != null) ...[
                    const SizedBox(height: AppTheme.spacingM),
                    _TrackingOverviewCard(overview: _vehicleOverview!),
                  ],
                  if (widget.subscriptionPlan == 'FREE' &&
                      widget.businessAccount == null) ...[
                    const SizedBox(height: AppTheme.spacingM),
                    const FreePlanBanner(),
                  ],
                  const SizedBox(height: AppTheme.spacingXL),
                  AppFadeSlideIn(
                    delay: const Duration(milliseconds: 120),
                    child: SectionTitle(
                      title: widget.businessAccount == null
                          ? 'Ana Araç'
                          : 'Şirket Ana Aracı',
                      actionLabel: _vehicles.length > 1
                          ? 'Değiştir'
                          : widget.businessAccount == null
                          ? 'Araçlarım'
                          : 'Şirket Araçları',
                      onActionPressed: _vehicles.length > 1
                          ? _selectMainVehicle
                          : widget.onOpenVehicles,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  AppFadeSlideIn(
                    delay: const Duration(milliseconds: 160),
                    child: _isLoading
                        ? const _LoadingCard()
                        : _mainVehicle == null
                        ? _EmptyVehicleCard(onTap: widget.onOpenVehicles)
                        : _MainVehicleCard(
                            vehicle: _mainVehicle!,
                            mileage: _formatMileage(_mainVehicle!.mileage),
                            onTap: _selectMainVehicle,
                          ),
                  ),
                  const SizedBox(height: AppTheme.spacingXL),
                  AppFadeSlideIn(
                    delay: const Duration(milliseconds: 210),
                    child: SectionTitle(
                      title: widget.businessAccount == null
                          ? 'Son Analiz'
                          : 'Şirketin Son Analizi',
                      actionLabel: 'Geçmiş',
                      onActionPressed: widget.onOpenInspections,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  AppFadeSlideIn(
                    delay: const Duration(milliseconds: 250),
                    child: _isLoading
                        ? const _LoadingCard()
                        : _latestInspection != null
                        ? _LatestInspectionCard(
                            inspection: _latestInspection!,
                            title: _severityLabel(
                              _latestInspection!.damageSeverity,
                            ),
                            severityLabel: _severityShortLabel(
                              _latestInspection!.damageSeverity,
                            ),
                            severityColor: _severityColor(
                              _latestInspection!.damageSeverity,
                            ),
                            summary: _damageSummary(_latestInspection!),
                            date: _formatDate(
                              _latestInspection!.completedAt ??
                                  _latestInspection!.createdAt,
                            ),
                            onTap: _openLatestInspection,
                          )
                        : _EmptyAnalysisCard(onTap: _startInspection),
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

class _TrackingOverviewCard extends StatelessWidget {
  const _TrackingOverviewCard({required this.overview});
  final VehicleOverview overview;

  @override
  Widget build(BuildContext context) {
    final upcoming = overview.upcomingReminders.take(2).toList();
    final status = switch (overview.trackingStatus) {
      'ATTENTION' => 'Dikkat gerekiyor',
      'DUE_SOON' => 'Yaklaşan işlem var',
      _ => 'İyi',
    };
    return AppCard(
      showShadow: false,
      child: Row(
        children: [
          const Icon(Icons.health_and_safety_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Araç takibi',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                if (upcoming.isEmpty)
                  Text(status)
                else
                  ...upcoming.map(
                    (reminder) => Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        reminder.title ??
                            reminder.reminderType.replaceAll('_', ' '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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

class _BusinessContextCard extends StatelessWidget {
  const _BusinessContextCard({required this.businessAccount});

  final BusinessAccount businessAccount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      showShadow: false,
      backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.38),
      child: Row(
        children: [
          Icon(Icons.business_rounded, color: colorScheme.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  businessAccount.companyName,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Şirketin ortak araçları ve analiz geçmişi gösteriliyor.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          AppStatusBadge(
            label: businessAccount.roleLabel,
            color: colorScheme.primary,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.fullName,
    required this.firstName,
    required this.onProfileTap,
    required this.onNotificationTap,
    required this.unreadCount,
  });

  final String fullName;
  final String firstName;
  final VoidCallback onProfileTap;
  final VoidCallback onNotificationTap;
  final int unreadCount;

  static String _initials(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'VI';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        AppPressScale(
          onTap: onProfileTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(fullName),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Merhaba $firstName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
        const SizedBox(width: 12),
        AppPressScale(
          onTap: onNotificationTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.notifications_none_rounded, size: 23),
                if (unreadCount > 0)
                  Positioned(
                    right: 5,
                    top: 5,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 17),
                      height: 17,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerColorFor(context),
                        borderRadius: BorderRadius.all(Radius.circular(9)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroAnalysisCard extends StatelessWidget {
  const _HeroAnalysisCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppPressScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: AppTheme.deepBrandGradient,
          boxShadow: AppTheme.primaryShadowFor(context),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -28,
              top: -38,
              child: Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'AI Hasar Analizi',
                  style: textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Hasarlı bölgenin fotoğrafını yükleyin, AI destekli raporunuzu oluşturun.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      'Yeni Analiz Başlat',
                      style: textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MainVehicleCard extends StatelessWidget {
  const _MainVehicleCard({
    required this.vehicle,
    required this.mileage,
    required this.onTap,
  });

  final Vehicle vehicle;
  final String mileage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(19),
            ),
            child: Icon(
              Icons.directions_car_filled_rounded,
              color: colorScheme.primary,
              size: 31,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        vehicle.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppStatusBadge(
                      label: 'ANA ARAÇ',
                      color: colorScheme.primary,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  '${vehicle.plate} • ${vehicle.modelYear}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$mileage km',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.swap_horiz_rounded, color: colorScheme.primary),
        ],
      ),
    );
  }
}

class _EmptyVehicleCard extends StatelessWidget {
  const _EmptyVehicleCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(Icons.add_rounded, color: colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Henüz araç yok',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'İlk aracınızı ekleyerek analize başlayın.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _LatestInspectionCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppStatusBadge(
                label: severityLabel,
                color: severityColor,
                compact: true,
              ),
              const Spacer(),
              Icon(
                Icons.north_east_rounded,
                size: 19,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Icon(
                Icons.directions_car_outlined,
                size: 17,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  inspection.vehiclePlate,
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.calendar_today_outlined,
                size: 15,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(date, style: textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyAnalysisCard extends StatelessWidget {
  const _EmptyAnalysisCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(Icons.analytics_outlined, color: colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Henüz analiz yok',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'İlk AI hasar analizini başlatın.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: SizedBox(
        height: 72,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
