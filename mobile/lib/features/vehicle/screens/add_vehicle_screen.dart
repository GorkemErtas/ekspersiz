import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/primary_button.dart';
import '../models/vehicle.dart';
import '../services/vehicle_service.dart';

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  State<AddVehicleScreen> createState() =>
      _AddVehicleScreenState();
}

class _AddVehicleScreenState
    extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();

  final _plateController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _modelYearController = TextEditingController();
  final _mileageController = TextEditingController();

  final VehicleService _vehicleService =
  const VehicleService();

  bool _isLoading = false;

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

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final modelYear = int.tryParse(
      _modelYearController.text.trim(),
    );

    final mileage = int.tryParse(
      _mileageController.text.trim(),
    );

    if (modelYear == null || mileage == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final vehicle =
      await _vehicleService.createVehicle(
        plate: _plateController.text,
        brand: _brandController.text,
        model: _modelController.text,
        modelYear: modelYear,
        mileage: mileage,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop<Vehicle>(
        vehicle,
      );
    } catch (exception) {
      if (!mounted) {
        return;
      }

      final message = switch (exception) {
        ApiException() => exception.message,
        FormatException() => exception.message,
        _ => 'Araç kaydedilemedi.',
      };

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            behavior:
            SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Araç Ekle'),
      ),
      body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1100,
              ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              28,
            ),
            children: [
              Text(
                'Araç bilgileri',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hasar analizi oluşturmak için aracınızın temel bilgilerini girin.',
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              Text(
                'Plaka',
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _plateController,
                textCapitalization:
                TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: '35ABC123',
                  prefixIcon: Icon(
                    Icons.badge_outlined,
                  ),
                ),
                validator: (value) {
                  final plate = (value ?? '')
                      .trim()
                      .toUpperCase()
                      .replaceAll(
                    RegExp(r'[^0-9A-Z]'),
                    '',
                  );

                  if (plate.isEmpty) {
                    return 'Plaka girin.';
                  }

                  final pattern = RegExp(
                    r'^[0-9]{2}[A-Z]{1,3}[0-9]{2,4}$',
                  );

                  if (!pattern.hasMatch(plate)) {
                    return 'Geçerli bir plaka girin. Örnek: 32 TYH 345';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 18),

              Text(
                'Marka',
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _brandController,
                textCapitalization:
                TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'Honda',
                  prefixIcon: Icon(
                    Icons.factory_outlined,
                  ),
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Marka girin.';
                  }

                  if (value.trim().length > 50) {
                    return 'Marka en fazla 50 karakter olabilir.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 18),

              Text(
                'Model',
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _modelController,
                textCapitalization:
                TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'City',
                  prefixIcon: Icon(
                    Icons.directions_car_outlined,
                  ),
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Model girin.';
                  }

                  if (value.trim().length > 50) {
                    return 'Model en fazla 50 karakter olabilir.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 18),

              Text(
                'Model Yılı',
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _modelYearController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: '2009',
                  prefixIcon: Icon(
                    Icons.calendar_today_outlined,
                  ),
                ),
                validator: (value) {
                  final year = int.tryParse(
                    value?.trim() ?? '',
                  );

                  if (year == null) {
                    return 'Geçerli bir model yılı girin.';
                  }

                  final currentYear = DateTime.now().year;
                  final maximumYear = currentYear + 1;

                  if (year < 1950 || year > maximumYear) {
                    return 'Model yılı 1950-$maximumYear arasında olmalıdır.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 18),

              Text(
                'Kilometre',
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _mileageController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _saveVehicle(),
                decoration: const InputDecoration(
                  hintText: '145000',
                  suffixText: 'km',
                  prefixIcon: Icon(
                    Icons.speed_outlined,
                  ),
                ),
                validator: (value) {
                  final mileage = int.tryParse(
                    value?.trim() ?? '',
                  );

                  if (mileage == null) {
                    return 'Geçerli kilometre girin.';
                  }

                  if (mileage < 0 ||
                      mileage > 2000000) {
                    return 'Kilometre 0-2.000.000 arasında olmalıdır.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 30),

              PrimaryButton(
                label: 'Aracı Kaydet',
                icon: Icons.check_rounded,
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