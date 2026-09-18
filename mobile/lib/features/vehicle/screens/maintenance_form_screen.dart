import 'package:mobile/core/localization/app_text.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../models/maintenance_record.dart';
import '../services/vehicle_tracking_service.dart';

class MaintenanceFormScreen extends StatefulWidget {
  const MaintenanceFormScreen({
    super.key,
    required this.vehicleId,
    required this.currentMileage,
    this.record,
  });
  final int vehicleId;
  final int currentMileage;
  final MaintenanceRecord? record;
  @override
  State<MaintenanceFormScreen> createState() => _MaintenanceFormScreenState();
}

class _MaintenanceFormScreenState extends State<MaintenanceFormScreen> {
  static const _types = [
    'ENGINE_OIL',
    'OIL_FILTER',
    'AIR_FILTER',
    'CABIN_FILTER',
    'BRAKE_PADS',
    'BRAKE_FLUID',
    'BATTERY',
    'TIRES',
    'TIMING_SYSTEM',
    'TRANSMISSION',
    'PERIODIC_MAINTENANCE',
    'CUSTOM',
  ];
  final _form = GlobalKey<FormState>();
  final _mileage = TextEditingController();
  final _cost = TextEditingController();
  final _note = TextEditingController();
  final _intervalMonths = TextEditingController();
  final _intervalMileage = TextEditingController();
  late String _type;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _type = r?.maintenanceType ?? 'PERIODIC_MAINTENANCE';
    _date = r?.maintenanceDate ?? DateTime.now();
    _mileage.text = (r?.mileage ?? widget.currentMileage).toString();
    _cost.text = r?.cost?.toString() ?? '';
    _note.text = r?.note ?? '';
    _intervalMonths.text = r?.intervalMonths?.toString() ?? '';
    _intervalMileage.text = r?.intervalMileage?.toString() ?? '';
  }

  @override
  void dispose() {
    _mileage.dispose();
    _cost.dispose();
    _note.dispose();
    _intervalMonths.dispose();
    _intervalMileage.dispose();
    super.dispose();
  }

  String _iso(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  String _dateText(DateTime? value) => value == null
      ? 'Seçilmedi'
      : '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  Future<DateTime?> _pick(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(1950),
    lastDate: DateTime.now().add(const Duration(days: 3650)),
  );

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'maintenanceType': _type,
      'maintenanceDate': _iso(_date),
      'mileage': int.parse(_mileage.text),
      if (_cost.text.trim().isNotEmpty)
        'cost': double.parse(_cost.text.replaceAll(',', '.')),
      if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
      if (_intervalMonths.text.trim().isNotEmpty)
        'intervalMonths': int.parse(_intervalMonths.text),
      if (_intervalMileage.text.trim().isNotEmpty)
        'intervalMileage': int.parse(_intervalMileage.text),
      if (widget.record != null &&
          _intervalMonths.text.trim().isEmpty &&
          _intervalMileage.text.trim().isEmpty &&
          widget.record!.intervalMonths == null &&
          widget.record!.intervalMileage == null &&
          widget.record!.nextRecommendedDate != null)
        'nextRecommendedDate': _iso(widget.record!.nextRecommendedDate!),
      if (widget.record != null &&
          _intervalMonths.text.trim().isEmpty &&
          _intervalMileage.text.trim().isEmpty &&
          widget.record!.intervalMonths == null &&
          widget.record!.intervalMileage == null &&
          widget.record!.nextRecommendedMileage != null)
        'nextRecommendedMileage': widget.record!.nextRecommendedMileage,
    };
    try {
      const service = VehicleTrackingService();
      final result = widget.record == null
          ? await service.addMaintenance(widget.vehicleId, body)
          : await service.updateMaintenance(
              widget.vehicleId,
              widget.record!.id,
              body,
            );
      if (mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AppText(
              e is ApiException ? e.message : 'Bakım kaydı kaydedilemedi.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: AppText(widget.record == null ? 'Bakım Ekle' : 'Bakımı Düzenle'),
    ),
    body: SafeArea(
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: InputDecoration(labelText: 'Bakım Türü'.tr),
              items: _types
                  .map(
                    (e) => DropdownMenuItem(value: e, child: AppText(_label(e))),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const AppText('Bakım Tarihi'),
              subtitle: AppText(_dateText(_date)),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: () async {
                final d = await _pick(_date);
                if (d != null) setState(() => _date = d);
              },
            ),
            TextFormField(
              controller: _mileage,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Kilometre'.tr,
                suffixText: 'km',
              ),
              validator: (v) => int.tryParse(v ?? '') == null
                  ? 'Geçerli kilometre girin.'
                  : int.parse(v!) < 0 || int.parse(v) > 2000000
                  ? 'Kilometre 0 ile 2.000.000 arasında olmalıdır.'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _cost,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Maliyet (isteğe bağlı)'.tr,
                suffixText: '₺',
              ),
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return null;
                final parsed = double.tryParse(value.replaceAll(',', '.'));
                return parsed == null || parsed < 0
                    ? 'Geçerli bir maliyet girin.'
                    : null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _intervalMonths,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Bakım aralığı (ay)'.tr,
              ),
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return null;
                final parsed = int.tryParse(value);
                return parsed == null || parsed < 1 || parsed > 600
                    ? '1-600 arasında ay girin.'
                    : null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _intervalMileage,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Bakım aralığı (km)'.tr,
                suffixText: 'km',
              ),
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return null;
                final parsed = int.tryParse(value);
                return parsed == null || parsed < 1 || parsed > 2000000
                    ? 'Geçerli kilometre aralığı girin.'
                    : null;
              },
            ),
            const SizedBox(height: 8),
            const AppText(
              'Üretici veya servis planındaki aralığı girin. Sonraki bakım tarihi ve kilometresi sunucuda hesaplanır.',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _note,
              maxLines: 3,
              maxLength: 1000,
              decoration: InputDecoration(labelText: 'Not'.tr),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const AppText('Kaydet'),
            ),
          ],
        ),
      ),
    ),
  );

  String _label(String value) =>
      const {
        'ENGINE_OIL': 'Motor yağı',
        'OIL_FILTER': 'Yağ filtresi',
        'AIR_FILTER': 'Hava filtresi',
        'CABIN_FILTER': 'Polen filtresi',
        'BRAKE_PADS': 'Fren balataları',
        'BRAKE_FLUID': 'Fren hidroliği',
        'BATTERY': 'Akü',
        'TIRES': 'Lastikler',
        'TIMING_SYSTEM': 'Triger / zincir',
        'TRANSMISSION': 'Şanzıman',
        'PERIODIC_MAINTENANCE': 'Periyodik bakım',
        'CUSTOM': 'Özel bakım'
      }[value] ??
          value;
}
