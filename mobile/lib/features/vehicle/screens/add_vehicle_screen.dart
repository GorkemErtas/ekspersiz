import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/models/business_account.dart';

import '../models/vehicle.dart';
import '../services/vehicle_service.dart';

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key, this.vehicle, this.businessAccount});

  final Vehicle? vehicle;
  final BusinessAccount? businessAccount;

  bool get isEditing => vehicle != null;

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();

  final _plateController = TextEditingController();

  final _brandController = TextEditingController();

  final _modelController = TextEditingController();

  final _modelYearController = TextEditingController();

  final _mileageController = TextEditingController();

  final VehicleService _vehicleService = const VehicleService();

  bool _isLoading = false;

  bool get _isEditing => widget.vehicle != null;

  @override
  void initState() {
    super.initState();

    final vehicle = widget.vehicle;

    if (vehicle != null) {
      _plateController.text = vehicle.plate;

      _brandController.text = vehicle.brand;

      _modelController.text = vehicle.model;

      _modelYearController.text = vehicle.modelYear.toString();

      _mileageController.text = vehicle.mileage.toString();
    }
  }

  @override
  void dispose() {
    _plateController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _modelYearController.dispose();
    _mileageController.dispose();

    super.dispose();
  }

  Future<void> _saveVehicle() async {
    if (_isLoading) {
      return;
    }

    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final modelYear = int.tryParse(_modelYearController.text.trim());

    final mileage = int.tryParse(_mileageController.text.trim());

    if (modelYear == null || mileage == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final Vehicle vehicle;

      if (_isEditing) {
        vehicle = await _vehicleService.updateVehicle(
          vehicleId: widget.vehicle!.id,
          plate: _plateController.text,
          brand: _brandController.text,
          model: _modelController.text,
          modelYear: modelYear,
          mileage: mileage,
        );
      } else {
        vehicle = await _vehicleService.createVehicle(
          plate: _plateController.text,
          brand: _brandController.text,
          model: _modelController.text,
          modelYear: modelYear,
          mileage: mileage,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop<Vehicle>(vehicle);
    } catch (exception) {
      if (!mounted) {
        return;
      }

      final message = switch (exception) {
        ApiException() => exception.message,
        FormatException() => exception.message,
        _ => _isEditing ? 'Araç güncellenemedi.' : 'Araç kaydedilemedi.',
      };

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String? _validatePlate(String? value) {
    final plate = (value ?? '').trim().toUpperCase().replaceAll(
      RegExp(r'[^0-9A-Z]'),
      '',
    );

    if (plate.isEmpty) {
      return 'Plaka girin.';
    }

    final pattern = RegExp(r'^[0-9]{2}[A-Z]{1,3}[0-9]{2,4}$');

    if (!pattern.hasMatch(plate)) {
      return 'Geçerli bir plaka girin. Örnek: 35 ABC 123';
    }

    return null;
  }

  String? _validateBrand(String? value) {
    final brand = value?.trim() ?? '';

    if (brand.isEmpty) {
      return 'Marka girin.';
    }

    if (brand.length > 50) {
      return 'Marka en fazla 50 karakter olabilir.';
    }

    return null;
  }

  String? _validateModel(String? value) {
    final model = value?.trim() ?? '';

    if (model.isEmpty) {
      return 'Model girin.';
    }

    if (model.length > 50) {
      return 'Model en fazla 50 karakter olabilir.';
    }

    return null;
  }

  String? _validateModelYear(String? value) {
    final year = int.tryParse(value?.trim() ?? '');

    if (year == null) {
      return 'Geçerli bir model yılı girin.';
    }

    final currentYear = DateTime.now().year;

    final maximumYear = currentYear + 1;

    if (year < 1950 || year > maximumYear) {
      return 'Model yılı 1950-$maximumYear arasında olmalıdır.';
    }

    return null;
  }

  String? _validateMileage(String? value) {
    final mileage = int.tryParse(value?.trim() ?? '');

    if (mileage == null) {
      return 'Geçerli kilometre girin.';
    }

    if (mileage < 0 || mileage > 2000000) {
      return 'Kilometre 0-2.000.000 arasında olmalıdır.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? 'Araç Düzenle'
              : widget.businessAccount == null
              ? 'Araç Ekle'
              : 'Şirket Aracı Ekle',
        ),
      ),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),

            child: Form(
              key: _formKey,

              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),

                children: [
                  AppPageHeader(
                    icon: Icons.directions_car_filled_rounded,
                    title: _isEditing
                        ? 'Araç bilgilerini düzenleyin'
                        : widget.businessAccount == null
                        ? 'Yeni aracınızı ekleyin'
                        : 'Şirket filosuna araç ekleyin',
                    subtitle: _isEditing
                        ? 'Aracınıza ait marka, model, plaka, model yılı ve kilometre bilgilerini güncelleyebilirsiniz.'
                        : widget.businessAccount == null
                        ? 'Araç bilgileri, hasar analizlerinin doğru araçla eşleştirilmesi için kullanılır.'
                        : '${widget.businessAccount!.companyName} araçları bütün şirket üyeleriyle paylaşılır.',
                  ),

                  const SizedBox(height: 24),

                  AppCard(
                    padding: const EdgeInsets.all(20),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionHeader(
                          icon: Icons.badge_outlined,
                          title: 'Araç kimliği',
                          subtitle: 'Plaka ve temel araç bilgileri',
                        ),

                        const SizedBox(height: 22),

                        TextFormField(
                          controller: _plateController,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: const InputDecoration(
                            labelText: 'Plaka',
                            hintText: '35 ABC 123',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: _validatePlate,
                        ),

                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _brandController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Marka',
                            hintText: 'Honda',
                            prefixIcon: Icon(Icons.factory_outlined),
                          ),
                          validator: _validateBrand,
                        ),

                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _modelController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Model',
                            hintText: 'Civic',
                            prefixIcon: Icon(Icons.directions_car_outlined),
                          ),
                          validator: _validateModel,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  AppCard(
                    padding: const EdgeInsets.all(20),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionHeader(
                          icon: Icons.analytics_outlined,
                          title: 'Araç detayları',
                          subtitle: 'Model yılı ve güncel kilometre bilgisi',
                        ),

                        const SizedBox(height: 22),

                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 520;

                            if (!isWide) {
                              return Column(
                                children: [
                                  TextFormField(
                                    controller: _modelYearController,
                                    keyboardType: TextInputType.number,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Model Yılı',
                                      hintText: '2020',
                                      prefixIcon: Icon(
                                        Icons.calendar_today_outlined,
                                      ),
                                    ),
                                    validator: _validateModelYear,
                                  ),

                                  const SizedBox(height: 16),

                                  TextFormField(
                                    controller: _mileageController,
                                    keyboardType: TextInputType.number,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) {
                                      _saveVehicle();
                                    },
                                    decoration: const InputDecoration(
                                      labelText: 'Kilometre',
                                      hintText: '145000',
                                      suffixText: 'km',
                                      prefixIcon: Icon(Icons.speed_outlined),
                                    ),
                                    validator: _validateMileage,
                                  ),
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _modelYearController,
                                    keyboardType: TextInputType.number,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Model Yılı',
                                      hintText: '2020',
                                      prefixIcon: Icon(
                                        Icons.calendar_today_outlined,
                                      ),
                                    ),
                                    validator: _validateModelYear,
                                  ),
                                ),

                                const SizedBox(width: 14),

                                Expanded(
                                  child: TextFormField(
                                    controller: _mileageController,
                                    keyboardType: TextInputType.number,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) {
                                      _saveVehicle();
                                    },
                                    decoration: const InputDecoration(
                                      labelText: 'Kilometre',
                                      hintText: '145000',
                                      suffixText: 'km',
                                      prefixIcon: Icon(Icons.speed_outlined),
                                    ),
                                    validator: _validateMileage,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.42,
                      ),
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: colorScheme.primary,
                          size: 21,
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Text(
                            _isEditing
                                ? 'Yaptığınız değişiklikler mevcut analiz geçmişinizi silmez.'
                                : widget.businessAccount == null
                                ? 'Araç bilgilerinizi doğru girmeniz, analiz geçmişinizi araç bazında takip etmenizi kolaylaştırır.'
                                : 'Aktif araç sınırı şirket genelinde 50’dir ve tüm üyeler aynı filoyu kullanır.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 26),

                  PrimaryButton(
                    label: _isEditing
                        ? 'Değişiklikleri Kaydet'
                        : 'Aracı Kaydet',
                    icon: _isEditing ? Icons.save_rounded : Icons.check_rounded,
                    isLoading: _isLoading,
                    onPressed: _saveVehicle,
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
