import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/primary_button.dart';

import '../../vehicle/models/vehicle.dart';
import '../../vehicle/services/vehicle_service.dart';

import '../models/damage_inspection.dart';
import '../services/inspection_service.dart';
import 'upload_damage_image_screen.dart';

class CreateInspectionScreen extends StatefulWidget {
  const CreateInspectionScreen({
    super.key,
  });

  @override
  State<CreateInspectionScreen> createState() =>
      _CreateInspectionScreenState();
}

class _CreateInspectionScreenState
    extends State<CreateInspectionScreen> {
  final VehicleService _vehicleService =
  const VehicleService();

  final InspectionService _inspectionService =
  const InspectionService();

  late Future<List<Vehicle>> _vehiclesFuture;

  Vehicle? _selectedVehicle;
  String? _selectedCity;

  bool _isCreating = false;

  static const List<String> _cities = [
    'Adana',
    'Ankara',
    'Antalya',
    'Bursa',
    'İstanbul',
    'İzmir',
    'Kocaeli',
    'Konya',
    'Mersin',
  ];

  @override
  void initState() {
    super.initState();

    _vehiclesFuture =
        _vehicleService.getVehicles();
  }

  Future<void> _createInspection() async {
    if (_isCreating) {
      return;
    }

    final vehicle =
        _selectedVehicle;

    final city =
        _selectedCity;

    if (vehicle == null) {
      _showMessage(
        'Lütfen analiz yapılacak aracı seçin.',
      );
      return;
    }

    if (city == null ||
        city.isEmpty) {
      _showMessage(
        'Lütfen şehir seçin.',
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final inspection =
      await _inspectionService.createInspection(
        vehicleId: vehicle.id,
        city: city,
      );

      if (!mounted) {
        return;
      }

      final uploadedInspection =
      await Navigator.of(context)
          .push<DamageInspection>(
        MaterialPageRoute<DamageInspection>(
          builder: (_) =>
              UploadDamageImageScreen(
                inspection:
                inspection,
              ),
        ),
      );

      if (!mounted ||
          uploadedInspection == null) {
        return;
      }

      Navigator.of(context)
          .pop<DamageInspection>(
        uploadedInspection,
      );
    } catch (exception) {
      if (!mounted) {
        return;
      }

      final message =
      exception is ApiException
          ? exception.message
          : 'Hasar incelemesi oluşturulamadı.';

      _showMessage(
        message,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
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

  @override
  Widget build(
      BuildContext context,
      ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final textTheme =
        Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Yeni Hasar Analizi',
        ),
      ),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
            const BoxConstraints(
              maxWidth: 760,
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
                    'Analiz için kayıtlı araçlarınız hazırlanıyor.',
                  );
                }

                if (snapshot.hasError) {
                  final error =
                      snapshot.error;

                  final message =
                  error is ApiException
                      ? error.message
                      : 'Araçlar yüklenemedi.';

                  return AppStateView.error(
                    title:
                    'Araçlar yüklenemedi',
                    message:
                    message,
                    onActionPressed:
                        () {
                      setState(() {
                        _vehiclesFuture =
                            _vehicleService
                                .getVehicles();
                      });
                    },
                  );
                }

                final vehicles =
                    snapshot.data ??
                        const <Vehicle>[];

                if (vehicles.isEmpty) {
                  return const AppStateView.empty(
                    icon:
                    Icons
                        .directions_car_outlined,
                    title:
                    'Önce bir araç ekleyin',
                    message:
                    'Hasar analizi oluşturmak için hesabınızda en az bir kayıtlı araç bulunmalıdır.',
                  );
                }

                return ListView(
                  padding:
                  const EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    36,
                  ),

                  children: [
                    const AppPageHeader(
                      icon:
                      Icons
                          .auto_awesome_rounded,
                      title:
                      'AI hasar analizi',
                      subtitle:
                      'Aracınızı ve bulunduğunuz şehri seçin. Bir sonraki adımda hasarlı bölgenin fotoğrafını ekleyeceksiniz.',
                      badge:
                      'AI INSPECTION',
                    ),

                    const SizedBox(
                      height: 24,
                    ),

                    AppCard(
                      padding:
                      const EdgeInsets.all(
                        20,
                      ),

                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          const AppSectionHeader(
                            icon:
                            Icons
                                .directions_car_outlined,
                            title:
                            'Araç seçimi',
                            subtitle:
                            'Hasar analizi yapılacak aracınızı seçin.',
                          ),

                          const SizedBox(
                            height: 18,
                          ),

                          ...vehicles.map(
                                (
                                vehicle,
                                ) {
                              final selected =
                                  _selectedVehicle
                                      ?.id ==
                                      vehicle.id;

                              return Padding(
                                padding:
                                const EdgeInsets.only(
                                  bottom: 12,
                                ),
                                child:
                                _VehicleSelectionCard(
                                  vehicle:
                                  vehicle,
                                  selected:
                                  selected,
                                  onTap: () {
                                    setState(() {
                                      _selectedVehicle =
                                          vehicle;
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    AppCard(
                      padding:
                      const EdgeInsets.all(
                        20,
                      ),

                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          const AppSectionHeader(
                            icon:
                            Icons
                                .location_city_outlined,
                            title:
                            'Konum',
                            subtitle:
                            'Fiyat tahmini için kullanılacak şehri seçin.',
                          ),

                          const SizedBox(
                            height: 18,
                          ),

                          DropdownButtonFormField<
                              String>(
                            initialValue:
                            _selectedCity,
                            isExpanded:
                            true,
                            decoration:
                            const InputDecoration(
                              labelText:
                              'Şehir',
                              hintText:
                              'Şehir seçin',
                              prefixIcon:
                              Icon(
                                Icons
                                    .location_on_outlined,
                              ),
                            ),
                            items:
                            _cities
                                .map(
                                  (
                                  city,
                                  ) =>
                                  DropdownMenuItem<
                                      String>(
                                    value:
                                    city,
                                    child:
                                    Text(
                                      city,
                                    ),
                                  ),
                            )
                                .toList(),
                            onChanged:
                            _isCreating
                                ? null
                                : (
                                value,
                                ) {
                              setState(() {
                                _selectedCity =
                                    value;
                              });
                            },
                          ),

                          const SizedBox(
                            height: 14,
                          ),

                          Container(
                            padding:
                            const EdgeInsets.all(
                              14,
                            ),
                            decoration:
                            BoxDecoration(
                              color:
                              colorScheme
                                  .primaryContainer
                                  .withValues(
                                alpha: 0.40,
                              ),
                              borderRadius:
                              BorderRadius.circular(
                                AppTheme
                                    .radiusMedium,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons
                                      .info_outline_rounded,
                                  size: 19,
                                  color:
                                  colorScheme
                                      .primary,
                                ),

                                const SizedBox(
                                  width: 10,
                                ),

                                Expanded(
                                  child:
                                  Text(
                                    'Şehir bilgisi, AI tarafından oluşturulan tahmini onarım maliyetinin bölgesel fiyatlara göre hazırlanmasında kullanılır.',
                                    style:
                                    textTheme.bodySmall
                                        ?.copyWith(
                                      color:
                                      colorScheme
                                          .onSurfaceVariant,
                                      height:
                                      1.45,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 26,
                    ),

                    PrimaryButton(
                      label:
                      'Fotoğraf Eklemeye Devam Et',
                      icon:
                      Icons
                          .arrow_forward_rounded,
                      isLoading:
                      _isCreating,
                      onPressed:
                      _createInspection,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _VehicleSelectionCard
    extends StatelessWidget {
  const _VehicleSelectionCard({
    required this.vehicle,
    required this.selected,
    required this.onTap,
  });

  final Vehicle vehicle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(
      BuildContext context,
      ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final textTheme =
        Theme.of(context).textTheme;

    return Material(
      color:
      Colors.transparent,
      borderRadius:
      BorderRadius.circular(
        AppTheme.radiusMedium,
      ),

      child: InkWell(
        onTap:
        onTap,
        borderRadius:
        BorderRadius.circular(
          AppTheme.radiusMedium,
        ),

        child: AnimatedContainer(
          duration:
          const Duration(
            milliseconds: 180,
          ),
          curve:
          Curves.easeOut,
          padding:
          const EdgeInsets.all(
            16,
          ),

          decoration:
          BoxDecoration(
            color:
            selected
                ? colorScheme
                .primaryContainer
                .withValues(
              alpha: 0.55,
            )
                : colorScheme
                .surfaceContainerLow,

            borderRadius:
            BorderRadius.circular(
              AppTheme.radiusMedium,
            ),

            border:
            Border.all(
              color:
              selected
                  ? colorScheme.primary
                  : colorScheme
                  .outlineVariant,
              width:
              selected
                  ? 1.6
                  : 1,
            ),
          ),

          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration:
                BoxDecoration(
                  color:
                  selected
                      ? colorScheme
                      .primary
                      : colorScheme
                      .surfaceContainerHighest,
                  borderRadius:
                  BorderRadius.circular(
                    16,
                  ),
                ),
                child: Icon(
                  Icons
                      .directions_car_filled_rounded,
                  color:
                  selected
                      ? colorScheme
                      .onPrimary
                      : colorScheme
                      .onSurfaceVariant,
                  size: 25,
                ),
              ),

              const SizedBox(
                width: 14,
              ),

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
                        FontWeight.w800,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      '${vehicle.plate} • ${vehicle.modelYear}',
                      style:
                      textTheme.bodyMedium
                          ?.copyWith(
                        color:
                        colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              AnimatedContainer(
                duration:
                const Duration(
                  milliseconds: 180,
                ),
                width: 28,
                height: 28,
                decoration:
                BoxDecoration(
                  color:
                  selected
                      ? colorScheme
                      .primary
                      : Colors
                      .transparent,
                  shape:
                  BoxShape.circle,
                  border:
                  Border.all(
                    color:
                    selected
                        ? colorScheme
                        .primary
                        : colorScheme
                        .outline,
                  ),
                ),
                child:
                selected
                    ? Icon(
                  Icons
                      .check_rounded,
                  size: 17,
                  color:
                  colorScheme
                      .onPrimary,
                )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}