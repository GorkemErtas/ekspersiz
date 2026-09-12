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

  Future<void> _openEditVehicleScreen(
      Vehicle vehicle,
      ) async {
    final updatedVehicle =
    await Navigator.of(context).push<Vehicle>(
      MaterialPageRoute<Vehicle>(
        builder: (_) =>
            AddVehicleScreen(
              vehicle: vehicle,
            ),
      ),
    );

    if (!mounted ||
        updatedVehicle == null) {
      return;
    }

    setState(_loadVehicles);

    _showMessage(
      '${updatedVehicle.displayName} başarıyla güncellendi.',
    );
  }

  Future<void> _confirmDeleteVehicle(
      Vehicle vehicle,
      ) async {
    final shouldDelete =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colorScheme =
            Theme.of(dialogContext).colorScheme;

        final textTheme =
            Theme.of(dialogContext).textTheme;

        return AlertDialog(
          icon: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color:
              colorScheme.errorContainer,
              borderRadius:
              BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.delete_outline_rounded,
              color:
              colorScheme.error,
              size: 29,
            ),
          ),

          title: const Text(
            'Araç garajdan kaldırılsın mı?',
            textAlign: TextAlign.center,
          ),

          content: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              Text(
                '${vehicle.displayName} aktif araçlarınızdan kaldırılacak.',
                textAlign:
                TextAlign.center,
                style:
                textTheme.bodyLarge,
              ),

              const SizedBox(
                height: 10,
              ),

              Text(
                'Geçmiş analizleriniz korunmaya devam eder.',
                textAlign:
                TextAlign.center,
                style:
                textTheme.bodyMedium
                    ?.copyWith(
                  color:
                  colorScheme
                      .onSurfaceVariant,
                ),
              ),

              const SizedBox(
                height: 14,
              ),

              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.all(12),
                decoration:
                BoxDecoration(
                  color:
                  colorScheme
                      .surfaceContainerHighest
                      .withValues(
                    alpha: 0.45,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    AppTheme.radiusMedium,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 18,
                      color:
                      colorScheme
                          .onSurfaceVariant,
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    Expanded(
                      child: Text(
                        vehicle.plate,
                        style:
                        textTheme.bodyMedium
                            ?.copyWith(
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text(
                'Vazgeç',
              ),
            ),

            FilledButton(
              style:
              FilledButton.styleFrom(
                backgroundColor:
                colorScheme.error,
                foregroundColor:
                colorScheme.onError,
              ),
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child: const Text(
                'Garajdan Kaldır',
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    await _deleteVehicle(vehicle);
  }

  Future<void> _deleteVehicle(
      Vehicle vehicle,
      ) async {
    try {
      await _vehicleService.deleteVehicle(
        vehicle.id,
      );

      if (!mounted) {
        return;
      }

      setState(_loadVehicles);

      _showMessage(
        '${vehicle.displayName} garajdan kaldırıldı.',
      );
    } catch (exception) {
      if (!mounted) {
        return;
      }

      final message =
      switch (exception) {
        ApiException() =>
        exception.message,
        FormatException() =>
        exception.message,
        _ =>
        'Araç garajdan kaldırılamadı.',
      };

      _showMessage(message);
    }
  }

  void _showMessage(
      String message,
      ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
          Text(message),
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
                        onEdit: () =>
                            _openEditVehicleScreen(
                              vehicle,
                            ),
                        onDelete: () =>
                            _confirmDeleteVehicle(
                              vehicle,
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
          textTheme.headlineSmall
              ?.copyWith(
            fontWeight:
            FontWeight.w900,
          ),
        ),

        const SizedBox(
          height: 6,
        ),

        Text(
          'Kayıtlı araçlarınızı buradan '
              'görüntüleyebilir, düzenleyebilir ve yönetebilirsiniz.',
          style:
          textTheme.bodyLarge
              ?.copyWith(
            color:
            colorScheme
                .onSurfaceVariant,
            height:
            1.45,
          ),
        ),

        const SizedBox(
          height: 20,
        ),

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
    required this.onEdit,
    required this.onDelete,
  });

  final Vehicle vehicle;
  final String mileage;

  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
        CrossAxisAlignment.start,
        children: [
          const AppIconBox(
            icon:
            Icons
                .directions_car_filled_rounded,
            size: 64,
            iconSize: 32,
            borderRadius: 20,
          ),

          const SizedBox(
            width: 16,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
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
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    _VehicleActionsMenu(
                      onEdit:
                      onEdit,
                      onDelete:
                      onDelete,
                    ),
                  ],
                ),

                const SizedBox(
                  height: 10,
                ),

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

                const SizedBox(
                  height: 12,
                ),

                Row(
                  children: [
                    Icon(
                      Icons.speed_rounded,
                      size: 17,
                      color:
                      colorScheme
                          .onSurfaceVariant,
                    ),

                    const SizedBox(
                      width: 6,
                    ),

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

enum _VehicleAction {
  edit,
  delete,
}

class _VehicleActionsMenu
    extends StatelessWidget {
  const _VehicleActionsMenu({
    required this.onEdit,
    required this.onDelete,
  });

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(
      BuildContext context,
      ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return PopupMenuButton<_VehicleAction>(
      tooltip:
      'Araç işlemleri',
      icon:
      const Icon(
        Icons.more_vert_rounded,
      ),
      onSelected: (action) {
        switch (action) {
          case _VehicleAction.edit:
            onEdit();
            break;
          case _VehicleAction.delete:
            onDelete();
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value:
          _VehicleAction.edit,
          child: Row(
            children: [
              Icon(
                Icons.edit_outlined,
                size: 20,
              ),
              SizedBox(
                width: 12,
              ),
              Text(
                'Düzenle',
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value:
          _VehicleAction.delete,
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color:
                colorScheme.error,
              ),
              const SizedBox(
                width: 12,
              ),
              Text(
                'Garajdan Kaldır',
                style:
                TextStyle(
                  color:
                  colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ],
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

          const SizedBox(
            width: 5,
          ),

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