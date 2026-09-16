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
  final _nextMileage = TextEditingController();
  late String _type;
  late DateTime _date;
  DateTime? _nextDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _type = r?.maintenanceType ?? 'PERIODIC_MAINTENANCE';
    _date = r?.maintenanceDate ?? DateTime.now();
    _nextDate = r?.nextRecommendedDate;
    _mileage.text = (r?.mileage ?? widget.currentMileage).toString();
    _cost.text = r?.cost?.toString() ?? '';
    _note.text = r?.note ?? '';
    _nextMileage.text = r?.nextRecommendedMileage?.toString() ?? '';
  }

  @override
  void dispose() {
    _mileage.dispose();
    _cost.dispose();
    _note.dispose();
    _nextMileage.dispose();
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
      if (_nextDate != null) 'nextRecommendedDate': _iso(_nextDate!),
      if (_nextMileage.text.trim().isNotEmpty)
        'nextRecommendedMileage': int.parse(_nextMileage.text),
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
            content: Text(
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
      title: Text(widget.record == null ? 'Bakım Ekle' : 'Bakımı Düzenle'),
    ),
    body: SafeArea(
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Bakım Türü'),
              items: _types
                  .map(
                    (e) => DropdownMenuItem(value: e, child: Text(_label(e))),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bakım Tarihi'),
              subtitle: Text(_dateText(_date)),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: () async {
                final d = await _pick(_date);
                if (d != null) setState(() => _date = d);
              },
            ),
            TextFormField(
              controller: _mileage,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Kilometre',
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
              decoration: const InputDecoration(
                labelText: 'Maliyet (isteğe bağlı)',
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
              controller: _nextMileage,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Sonraki bakım kilometresi',
                suffixText: 'km',
              ),
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return null;
                final parsed = int.tryParse(value);
                if (parsed == null || parsed < 0 || parsed > 2000000) {
                  return 'Geçerli kilometre girin.';
                }
                final current = int.tryParse(_mileage.text);
                return current != null && parsed < current
                    ? 'Sonraki kilometre bakım kilometresinden küçük olamaz.'
                    : null;
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sonraki bakım tarihi'),
              subtitle: Text(_dateText(_nextDate)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_nextDate != null)
                    IconButton(
                      onPressed: () => setState(() => _nextDate = null),
                      icon: const Icon(Icons.close),
                    ),
                  const Icon(Icons.calendar_month_outlined),
                ],
              ),
              onTap: () async {
                final d = await _pick(_nextDate ?? DateTime.now());
                if (d != null) setState(() => _nextDate = d);
              },
            ),
            TextFormField(
              controller: _note,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(labelText: 'Not'),
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
              label: const Text('Kaydet'),
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
        'CUSTOM': 'Diğer',
      }[value] ??
      value;
}
