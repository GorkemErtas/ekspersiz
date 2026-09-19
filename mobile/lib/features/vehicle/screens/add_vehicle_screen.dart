import 'package:mobile/core/localization/app_text.dart';
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

  final _lastMaintenanceMileageController = TextEditingController();
  final _maintenanceIntervalMonthsController = TextEditingController();
  final _maintenanceIntervalMileageController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _lastMaintenanceDate;

  DateTime? _inspectionDate;
  bool _firstInspection = false;

  DateTime? _trafficInsuranceDate;
  DateTime? _comprehensiveInsuranceDate;
  DateTime? _tireCheckDate;

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
      _notesController.text = vehicle.notes ?? '';
    }
  }

  @override
  void dispose() {
    _plateController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _modelYearController.dispose();
    _mileageController.dispose();
    _lastMaintenanceMileageController.dispose();
    _maintenanceIntervalMonthsController.dispose();
    _maintenanceIntervalMileageController.dispose();
    _notesController.dispose();

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

    final lastMaintenanceMileage =
    _lastMaintenanceMileageController.text.trim();

    if ((_lastMaintenanceDate == null) != lastMaintenanceMileage.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText(
            'Son bakım tarihi ve kilometresi birlikte girilmelidir.',
          ),
        ),
      );
      return;
    }

    final hasMonthInterval =
        _maintenanceIntervalMonthsController.text.trim().isNotEmpty;

    final hasMileageInterval =
        _maintenanceIntervalMileageController.text.trim().isNotEmpty;

    if (hasMonthInterval && _lastMaintenanceDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText(
            'Aylık bakım aralığı için son bakım tarihini girin.',
          ),
        ),
      );
      return;
    }

    if (hasMileageInterval && lastMaintenanceMileage.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText(
            'Kilometre bakım aralığı için son bakım kilometresini girin.',
          ),
        ),
      );
      return;
    }

    if ((lastMaintenanceMileage.isNotEmpty &&
        int.tryParse(lastMaintenanceMileage) == null) ||
        (_maintenanceIntervalMonthsController.text.trim().isNotEmpty &&
            int.tryParse(
              _maintenanceIntervalMonthsController.text.trim(),
            ) ==
                null) ||
        (_maintenanceIntervalMileageController.text.trim().isNotEmpty &&
            int.tryParse(
              _maintenanceIntervalMileageController.text.trim(),
            ) ==
                null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('Bakım kilometresi sayı olmalıdır.'),
        ),
      );
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

          notes: _notesController.text.trim(),
        );
      } else {
        vehicle = await _vehicleService.createVehicle(
          plate: _plateController.text,
          brand: _brandController.text,
          model: _modelController.text,
          modelYear: modelYear,
          mileage: mileage,

          tracking: _trackingPayload(),
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
        _ => _isEditing
            ? 'Araç güncellenemedi.'
            : 'Araç kaydedilemedi.',
      };

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: AppText(message),
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

  String _iso(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
          '${value.month.toString().padLeft(2, '0')}-'
          '${value.day.toString().padLeft(2, '0')}';

  Map<String, dynamic>? _trackingPayload() {
    final payload = <String, dynamic>{
      if (_lastMaintenanceDate != null)
        'lastMaintenanceDate': _iso(_lastMaintenanceDate!),

      if (_lastMaintenanceMileageController.text.trim().isNotEmpty)
        'lastMaintenanceMileage': int.parse(
          _lastMaintenanceMileageController.text.trim(),
        ),

      if (_maintenanceIntervalMonthsController.text.trim().isNotEmpty)
        'maintenanceIntervalMonths': int.parse(
          _maintenanceIntervalMonthsController.text.trim(),
        ),

      if (_maintenanceIntervalMileageController.text.trim().isNotEmpty)
        'maintenanceIntervalMileage': int.parse(
          _maintenanceIntervalMileageController.text.trim(),
        ),

      if (_inspectionDate != null)
        'vehicleInspectionDate': _iso(_inspectionDate!),

      if (_inspectionDate != null)
        'firstInspection': _firstInspection,

      if (_trafficInsuranceDate != null)
        'trafficInsuranceExpiryDate': _iso(_trafficInsuranceDate!),

      if (_comprehensiveInsuranceDate != null)
        'comprehensiveInsuranceExpiryDate':
        _iso(_comprehensiveInsuranceDate!),

      if (_tireCheckDate != null)
        'tireCheckDate': _iso(_tireCheckDate!),

      if (_notesController.text.trim().isNotEmpty)
        'notes': _notesController.text.trim(),
    };

    return payload.isEmpty ? null : payload;
  }

  Future<void> _selectDate(
      DateTime? current,
      ValueChanged<DateTime?> update,
      ) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(
        const Duration(days: 3650),
      ),
    );

    if (selected != null) {
      setState(() {
        update(selected);
      });
    }
  }

  String _dateLabel(DateTime? value) {
    if (value == null) {
      return 'Seçilmedi';
    }

    return '${value.day.toString().padLeft(2, '0')}.'
        '${value.month.toString().padLeft(2, '0')}.'
        '${value.year}';
  }

  Widget _dateTile(
      String title,
      DateTime? value,
      ValueChanged<DateTime?> update,
      ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: AppText(title),
      subtitle: AppText(_dateLabel(value)),
      trailing: const Icon(Icons.calendar_month_outlined),
      onTap: () => _selectDate(value, update),
    );
  }

  Widget _inspectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dateTile(
          'Son araç muayene tarihi',
          _inspectionDate,
              (value) => _inspectionDate = value,
        ),

        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              _firstInspection = !_firstInspection;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 6,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: AppText(
                    'Bu ilk muayeneydi',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(width: 12),
                Checkbox(
                  value: _firstInspection,
                  onChanged: (value) {
                    setState(() {
                      _firstInspection = value ?? false;
                    });
                  },
                ),
              ],
            ),
          ),
        ),

        if (_inspectionDate != null) ...[
          const SizedBox(height: 2),
          AppText(
            _firstInspection
                ? 'Sonraki muayene tarihi, bu tarihten 3 yıl sonrası olarak hesaplanacaktır.'
                : 'Sonraki muayene tarihi, bu tarihten 2 yıl sonrası olarak hesaplanacaktır.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  String? _validatePlate(String? value) {
    final plate = (value ?? '')
        .trim()
        .toUpperCase()
        .replaceAll(
      RegExp(r'[^0-9A-Z]'),
      '',
    );

    if (plate.isEmpty) {
      return 'Plaka girin.'.tr;
    }

    final pattern = RegExp(
      r'^[0-9]{2}[A-Z]{1,3}[0-9]{2,4}$',
    );

    if (!pattern.hasMatch(plate)) {
      return 'Geçerli bir plaka girin. Örnek: 35 ABC 123'.tr;
    }

    return null;
  }

  String? _validateBrand(String? value) {
    final brand = value?.trim() ?? '';

    if (brand.isEmpty) {
      return 'Marka girin.'.tr;
    }

    if (brand.length > 50) {
      return 'Marka en fazla 50 karakter olabilir.'.tr;
    }

    return null;
  }

  String? _validateModel(String? value) {
    final model = value?.trim() ?? '';

    if (model.isEmpty) {
      return 'Model girin.'.tr;
    }

    if (model.length > 50) {
      return 'Model en fazla 50 karakter olabilir.'.tr;
    }

    return null;
  }

  String? _validateModelYear(String? value) {
    final year = int.tryParse(
      value?.trim() ?? '',
    );

    if (year == null) {
      return 'Geçerli bir model yılı girin.'.tr;
    }

    final currentYear = DateTime.now().year;
    final maximumYear = currentYear + 1;

    if (year < 1950 || year > maximumYear) {
      return 'Model yılı 1950-$maximumYear arasında olmalıdır.'.tr;
    }

    return null;
  }

  String? _validateMileage(String? value) {
    final mileage = int.tryParse(
      value?.trim() ?? '',
    );

    if (mileage == null) {
      return 'Geçerli kilometre girin.'.tr;
    }

    if (mileage < 0 || mileage > 2000000) {
      return 'Kilometre 0-2.000.000 arasında olmalıdır.'.tr;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: AppText(
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
            constraints: const BoxConstraints(
              maxWidth: 760,
            ),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  36,
                ),
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
                          textCapitalization:
                          TextCapitalization.characters,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            labelText: 'Plaka'.tr,
                            hintText: '35 ABC 123'.tr,
                            prefixIcon:
                            const Icon(Icons.badge_outlined),
                          ),
                          validator: _validatePlate,
                        ),

                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _brandController,
                          textCapitalization:
                          TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Marka'.tr,
                            hintText: 'Honda'.tr,
                            prefixIcon:
                            const Icon(Icons.factory_outlined),
                          ),
                          validator: _validateBrand,
                        ),

                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _modelController,
                          textCapitalization:
                          TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Model'.tr,
                            hintText: 'Civic'.tr,
                            prefixIcon: const Icon(
                              Icons.directions_car_outlined,
                            ),
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
                          subtitle:
                          'Model yılı ve güncel kilometre bilgisi',
                        ),

                        const SizedBox(height: 22),

                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide =
                                constraints.maxWidth > 520;

                            if (!isWide) {
                              return Column(
                                children: [
                                  TextFormField(
                                    controller:
                                    _modelYearController,
                                    keyboardType:
                                    TextInputType.number,
                                    textInputAction:
                                    TextInputAction.next,
                                    decoration: InputDecoration(
                                      labelText: 'Model Yılı'.tr,
                                      hintText: '2020'.tr,
                                      prefixIcon: const Icon(
                                        Icons
                                            .calendar_today_outlined,
                                      ),
                                    ),
                                    validator:
                                    _validateModelYear,
                                  ),

                                  const SizedBox(height: 16),

                                  TextFormField(
                                    controller:
                                    _mileageController,
                                    keyboardType:
                                    TextInputType.number,
                                    textInputAction:
                                    TextInputAction.done,
                                    onFieldSubmitted: (_) {
                                      _saveVehicle();
                                    },
                                    decoration: InputDecoration(
                                      labelText: 'Kilometre'.tr,
                                      hintText: '145000'.tr,
                                      suffixText: 'km',
                                      prefixIcon: const Icon(
                                        Icons.speed_outlined,
                                      ),
                                    ),
                                    validator: _validateMileage,
                                  ),
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller:
                                    _modelYearController,
                                    keyboardType:
                                    TextInputType.number,
                                    textInputAction:
                                    TextInputAction.next,
                                    decoration: InputDecoration(
                                      labelText: 'Model Yılı'.tr,
                                      hintText: '2020'.tr,
                                      prefixIcon: const Icon(
                                        Icons
                                            .calendar_today_outlined,
                                      ),
                                    ),
                                    validator:
                                    _validateModelYear,
                                  ),
                                ),

                                const SizedBox(width: 14),

                                Expanded(
                                  child: TextFormField(
                                    controller:
                                    _mileageController,
                                    keyboardType:
                                    TextInputType.number,
                                    textInputAction:
                                    TextInputAction.done,
                                    onFieldSubmitted: (_) {
                                      _saveVehicle();
                                    },
                                    decoration: InputDecoration(
                                      labelText: 'Kilometre'.tr,
                                      hintText: '145000'.tr,
                                      suffixText: 'km',
                                      prefixIcon: const Icon(
                                        Icons.speed_outlined,
                                      ),
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

                  AppCard(
                    padding: EdgeInsets.zero,
                    child: ExpansionTile(
                      leading:
                      const Icon(Icons.event_note_outlined),
                      title:
                      const AppText('Araç takip bilgileri'),
                      subtitle: const AppText('İsteğe bağlı'),
                      childrenPadding:
                      const EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        20,
                      ),
                      children: [
                        if (!_isEditing) ...[
                          _dateTile(
                            'Son bakım tarihi',
                            _lastMaintenanceDate,
                                (value) =>
                            _lastMaintenanceDate = value,
                          ),

                          TextFormField(
                            controller:
                            _lastMaintenanceMileageController,
                            keyboardType:
                            TextInputType.number,
                            decoration: InputDecoration(
                              labelText:
                              'Son bakım kilometresi'.tr,
                              suffixText: 'km',
                            ),
                          ),

                          const SizedBox(height: 12),

                          TextFormField(
                            controller:
                            _maintenanceIntervalMonthsController,
                            keyboardType:
                            TextInputType.number,
                            decoration: InputDecoration(
                              labelText:
                              'Bakım aralığı (ay)'.tr,
                            ),
                          ),

                          const SizedBox(height: 12),

                          TextFormField(
                            controller:
                            _maintenanceIntervalMileageController,
                            keyboardType:
                            TextInputType.number,
                            decoration: InputDecoration(
                              labelText:
                              'Bakım aralığı (km)'.tr,
                              suffixText: 'km',
                            ),
                          ),

                          const SizedBox(height: 10),

                          _inspectionSection(),

                          const SizedBox(height: 6),

                          _dateTile(
                            'Trafik sigortası bitişi',
                            _trafficInsuranceDate,
                                (value) =>
                            _trafficInsuranceDate = value,
                          ),

                          _dateTile(
                            'Kasko bitişi',
                            _comprehensiveInsuranceDate,
                                (value) =>
                            _comprehensiveInsuranceDate =
                                value,
                          ),

                          _dateTile(
                            'Lastik kontrolü',
                            _tireCheckDate,
                                (value) =>
                            _tireCheckDate = value,
                          ),
                        ],

                        TextFormField(
                          controller: _notesController,
                          maxLines: 3,
                          maxLength: 1000,
                          decoration: InputDecoration(
                            labelText: 'Araç notları'.tr,
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                      colorScheme.primaryContainer.withValues(
                        alpha: 0.42,
                      ),
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: colorScheme.primary,
                          size: 21,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppText(
                            _isEditing
                                ? 'Yaptığınız değişiklikler mevcut analiz geçmişinizi silmez.'
                                : widget.businessAccount == null
                                ? 'Araç bilgilerinizi doğru girmeniz, analiz geçmişinizi araç bazında takip etmenizi kolaylaştırır.'
                                : 'Aktif araç sınırı şirket genelinde 50’dir ve tüm üyeler aynı filoyu kullanır.',
                            style:
                            textTheme.bodyMedium?.copyWith(
                              color:
                              colorScheme.onSurfaceVariant,
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
                    icon: _isEditing
                        ? Icons.save_rounded
                        : Icons.check_rounded,
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