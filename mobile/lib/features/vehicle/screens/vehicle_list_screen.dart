import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../models/vehicle.dart';
import '../services/vehicle_service.dart';
import 'add_vehicle_screen.dart';

class VehicleListScreen extends StatefulWidget {
  const VehicleListScreen({super.key});

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
    _vehiclesFuture = _vehicleService.getVehicles();
  }

  Future<void> _refreshVehicles() async {
    setState(_loadVehicles);

    try {
      await _vehiclesFuture;
    } catch (_) {
    }
  }

  Future<void> _openAddVehicleScreen() async {
    final createdVehicle =
    await Navigator.of(context).push<Vehicle>(
      MaterialPageRoute<Vehicle>(
        builder: (_) => const AddVehicleScreen(),
      ),
    );

    if (!mounted || createdVehicle == null) {
      return;
    }

    setState(_loadVehicles);

    _showMessage(
      '${createdVehicle.displayName} başarıyla eklendi.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _formatMileage(int mileage) {
    final value = mileage.toString();
    final buffer = StringBuffer();

    for (int index = 0; index < value.length; index++) {
      final reversedIndex = value.length - index;

      buffer.write(value[index]);

      if (reversedIndex > 1 &&
          reversedIndex % 3 == 1) {
        buffer.write('.');
      }
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Araçlarım'),
      ),
      floatingActionButton:
      FloatingActionButton.extended(
        onPressed: _openAddVehicleScreen,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Araç Ekle'),
      ),
      body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1100,
              ),
              child: FutureBuilder<List<Vehicle>>(
          future: _vehiclesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              final error = snapshot.error;

              final message = switch (error) {
                ApiException() => error.message,
                FormatException() => error.message,
                _ => 'Araçlar yüklenemedi.',
              };

              return _VehicleErrorState(
                message: message,
                onRetry: () {
                  setState(_loadVehicles);
                },
              );
            }

            final vehicles =
                snapshot.data ?? const <Vehicle>[];

            if (vehicles.isEmpty) {
              return _VehicleEmptyState(
                onAddVehicle: _openAddVehicleScreen,
              );
            }

            return RefreshIndicator(
              onRefresh: _refreshVehicles,
              child: ListView.separated(
                physics:
                const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  110,
                ),
                itemCount: vehicles.length,
                separatorBuilder: (_, __) =>
                const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final vehicle = vehicles[index];

                  return AppCard(
                    child: Row(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color:
                            colorScheme.primaryContainer,
                            borderRadius:
                            BorderRadius.circular(18),
                          ),
                          child: Icon(
                            Icons
                                .directions_car_filled_outlined,
                            color: colorScheme.primary,
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
                                vehicle.displayName,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight:
                                  FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${vehicle.plate} • '
                                    '${vehicle.modelYear}',
                                style: TextStyle(
                                  color: colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${_formatMileage(vehicle.mileage)} km',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
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

class _VehicleEmptyState extends StatelessWidget {
  const _VehicleEmptyState({
    required this.onAddVehicle,
  });

  final VoidCallback onAddVehicle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Icon(
                Icons.directions_car_outlined,
                size: 42,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Henüz araç eklenmedi',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Hasar analizi başlatmak için önce aracınızı kaydedin.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAddVehicle,
              icon: const Icon(Icons.add_rounded),
              label: const Text('İlk Aracımı Ekle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleErrorState extends StatelessWidget {
  const _VehicleErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge,
            ),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}