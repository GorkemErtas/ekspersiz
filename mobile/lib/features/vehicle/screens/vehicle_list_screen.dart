import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_icon_box.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/app_status_badge.dart';

import '../models/vehicle.dart';
import '../services/vehicle_service.dart';
import 'add_vehicle_screen.dart';

class VehicleListScreen extends StatefulWidget {
  const VehicleListScreen({
    super.key,
  });

  @override
  State<VehicleListScreen> createState() =>
      _VehicleListScreenState();
}

class _VehicleListScreenState
    extends State<VehicleListScreen> {
  final VehicleService _vehicleService =
  const VehicleService();

  late Future<List<Vehicle>> _vehiclesFuture;

  @override
  void initState() {
    super.initState();

    _loadVehicles();
  }

  void _loadVehicles() {
    _vehiclesFuture =
        _vehicleService.getVehicles();
  }

  Future<void> _refreshVehicles() async {
    setState(_loadVehicles);

    try {
      await _vehiclesFuture;
    } catch (_) {
      // FutureBuilder hata durumunu gösterecek.
    }
  }

  Future<void> _openAddVehicleScreen() async {
    final createdVehicle =
    await Navigator.of(context).push<Vehicle>(
      MaterialPageRoute<Vehicle>(
        builder: (_) =>
        const AddVehicleScreen(),
      ),
    );

    if (!mounted ||
        createdVehicle == null) {
      return;
    }

    setState(_loadVehicles);

    _showMessage(
      '${createdVehicle.displayName} başarıyla eklendi.',
    );
  }

  void _showMessage(
      String message,
      ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  String _formatMileage(
      int mileage,
      ) {
    final value =
    mileage.toString();

    final buffer =
    StringBuffer();

    for (
    int index = 0;
    index < value.length;
    index++
    ) {
      final reversedIndex =
          value.length - index;

      buffer.write(
        value[index],
      );

      if (reversedIndex > 1 &&
          reversedIndex % 3 == 1) {
        buffer.write('.');
      }
    }

    return buffer.toString();
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Araçlarım',
        ),
      ),

      floatingActionButton:
      FloatingActionButton.extended(
        onPressed:
        _openAddVehicleScreen,
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: const Text(
          'Araç Ekle',
        ),
      ),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
            const BoxConstraints(
              maxWidth:
              AppTheme.maxContentWidth,
            ),

            child:
            FutureBuilder<List<Vehicle>>(
              future:
              _vehiclesFuture,

              builder:
                  (
                  context,
                  snapshot,
                  ) {
                if (snapshot
                    .connectionState ==
                    ConnectionState.waiting) {
                  return const AppStateView.loading(
                    title:
                    'Araçlar yükleniyor',
                    message:
                    'Garajınızdaki araçlar hazırlanıyor.',
                    bottomPadding:
                    110,
                  );
                }

                if (snapshot.hasError) {
                  final error =
                      snapshot.error;

                  final message =
                  switch (error) {
                    ApiException() =>
                    error.message,
                    FormatException() =>
                    error.message,
                    _ =>
                    'Araçlar yüklenemedi.',
                  };

                  return AppStateView.error(
                    title:
                    'Araçlar yüklenemedi',
                    message:
                    message,
                    bottomPadding:
                    110,
                    onActionPressed:
                        () {
                      setState(
                        _loadVehicles,
                      );
                    },
                  );
                }

                final vehicles =
                    snapshot.data ??
                        const <Vehicle>[];

                if (vehicles.isEmpty) {
                  return AppStateView.empty(
                    icon:
                    Icons
                        .directions_car_outlined,
                    title:
                    'Garajınız henüz boş',
                    message:
                    'AI destekli hasar analizi başlatmak için önce aracınızı kaydedin.',
                    actionLabel:
                    'İlk Aracımı Ekle',
                    actionIcon:
                    Icons.add_rounded,
                    bottomPadding:
                    110,
                    onActionPressed:
                    _openAddVehicleScreen,
                  );
                }

                return RefreshIndicator(
                  onRefresh:
                  _refreshVehicles,

                  child:
                  ListView.separated(
                    physics:
                    const AlwaysScrollableScrollPhysics(),

                    padding:
                    const EdgeInsets.fromLTRB(
                      20,
                      16,
                      20,
                      120,
                    ),

                    itemCount:
                    vehicles.length + 1,

                    separatorBuilder:
                        (
                        context,
                        index,
                        ) =>
                        SizedBox(
                          height:
                          index == 0
                              ? 18
                              : 14,
                        ),

                    itemBuilder:
                        (
                        context,
                        index,
                        ) {
                      if (index == 0) {
                        return _VehicleHeader(
                          vehicleCount:
                          vehicles.length,
                        );
                      }

                      final vehicle =
                      vehicles[
                      index - 1];

                      return _VehicleCard(
                        vehicle:
                        vehicle,
                        mileage:
                        _formatMileage(
                          vehicle.mileage,
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

class _VehicleHeader extends StatelessWidget {
  const _VehicleHeader({
    required this.vehicleCount,
  });

  final int vehicleCount;

  @override
  Widget build(
      BuildContext context,
      ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final textTheme =
        Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          'Garajınız',
          style:
          textTheme.headlineSmall?.copyWith(
            fontWeight:
            FontWeight.w900,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          'Kayıtlı araçlarınızı buradan '
              'görüntüleyebilir ve yeni araç ekleyebilirsiniz.',
          style:
          textTheme.bodyLarge?.copyWith(
            color:
            colorScheme.onSurfaceVariant,
            height:
            1.45,
          ),
        ),

        const SizedBox(height: 20),

        AppStatusBadge(
          icon:
          Icons.garage_outlined,
          label:
          '$vehicleCount kayıtlı araç',
          color:
          colorScheme.primary,
          backgroundColor:
          colorScheme.primaryContainer,
        ),
      ],
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.mileage,
  });

  final Vehicle vehicle;
  final String mileage;

  @override
  Widget build(
      BuildContext context,
      ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final textTheme =
        Theme.of(context).textTheme;

    return AppCard(
      padding:
      const EdgeInsets.all(18),

      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.center,
        children: [
          const AppIconBox(
            icon:
            Icons
                .directions_car_filled_rounded,
            size: 64,
            iconSize: 32,
            borderRadius: 20,
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.displayName,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style:
                  textTheme.titleMedium
                      ?.copyWith(
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 10),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoBadge(
                      icon:
                      Icons.badge_outlined,
                      label:
                      vehicle.plate,
                    ),

                    _InfoBadge(
                      icon:
                      Icons
                          .calendar_today_outlined,
                      label:
                      '${vehicle.modelYear}',
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Icon(
                      Icons.speed_rounded,
                      size: 17,
                      color:
                      colorScheme
                          .onSurfaceVariant,
                    ),

                    const SizedBox(width: 6),

                    Text(
                      '$mileage km',
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
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(
      BuildContext context,
      ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final textTheme =
        Theme.of(context).textTheme;

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration:
      BoxDecoration(
        color:
        colorScheme
            .surfaceContainerHighest
            .withValues(
          alpha: 0.55,
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
          Icon(
            icon,
            size: 14,
            color:
            colorScheme
                .onSurfaceVariant,
          ),

          const SizedBox(width: 5),

          Text(
            label,
            style:
            textTheme.labelMedium
                ?.copyWith(
              color:
              colorScheme
                  .onSurfaceVariant,
              fontWeight:
              FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}