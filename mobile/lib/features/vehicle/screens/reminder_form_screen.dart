import 'package:mobile/core/localization/app_text.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../models/vehicle.dart';
import '../models/vehicle_reminder.dart';
import '../services/vehicle_tracking_service.dart';

class ReminderFormScreen extends StatefulWidget {
  const ReminderFormScreen({super.key, required this.vehicle, this.reminder});

  final Vehicle vehicle;
  final VehicleReminder? reminder;

  @override
  State<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends State<ReminderFormScreen> {
  static const _types = [
    'PERIODIC_MAINTENANCE',
    'VEHICLE_INSPECTION',
    'TRAFFIC_INSURANCE',
    'COMPREHENSIVE_INSURANCE',
    'TIRE_CHECK',
    'CUSTOM',
  ];
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _dueMileage = TextEditingController();
  final _sourceMileage = TextEditingController();
  final _intervalMonths = TextEditingController();
  final _intervalMileage = TextEditingController();
  final _note = TextEditingController();
  late String _type;
  late String _inspectionMode;
  late bool _manualMaintenance;
  DateTime? _dueDate;
  DateTime? _sourceDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final reminder = widget.reminder;
    _type = reminder?.reminderType ?? 'VEHICLE_INSPECTION';
    _dueDate = reminder?.dueDate;
    _sourceDate = reminder?.sourceDate;
    _title.text = reminder?.title ?? '';
    _dueMileage.text = reminder?.dueMileage?.toString() ?? '';
    _sourceMileage.text = (reminder?.sourceMileage ?? widget.vehicle.mileage)
        .toString();
    _intervalMonths.text = reminder?.intervalMonths?.toString() ?? '';
    _intervalMileage.text = reminder?.intervalMileage?.toString() ?? '';
    _note.text = reminder?.note ?? '';
    _inspectionMode = reminder?.firstInspection == true
        ? 'FIRST'
        : reminder?.sourceDate != null
        ? 'LAST'
        : 'EXPLICIT';
    _manualMaintenance =
        reminder != null &&
        reminder.sourceDate == null &&
        reminder.sourceMileage == null &&
        reminder.intervalMonths == null &&
        reminder.intervalMileage == null;
  }

  @override
  void dispose() {
    _title.dispose();
    _dueMileage.dispose();
    _sourceMileage.dispose();
    _intervalMonths.dispose();
    _intervalMileage.dispose();
    _note.dispose();
    super.dispose();
  }

  String _iso(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _dateText(DateTime? value) => value == null
      ? 'Seçilmedi'
      : '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';

  Future<void> _pickDate(DateTime? current, ValueChanged<DateTime> set) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected != null) setState(() => set(selected));
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_type == 'VEHICLE_INSPECTION' &&
        _inspectionMode == 'FIRST' &&
        (widget.vehicle.vehicleCategory == null ||
            widget.vehicle.conformityDate == null)) {
      _message(
        'İlk muayene hesabı için araç kategorisini ve uygunluk belgesindeki imal tarihini araç bilgilerinden girin.',
      );
      return;
    }
    if (_type == 'PERIODIC_MAINTENANCE' && !_manualMaintenance) {
      final hasMonths = _intervalMonths.text.trim().isNotEmpty;
      final hasMileage = _intervalMileage.text.trim().isNotEmpty;
      if (!hasMonths && !hasMileage) {
        _message('Ay veya kilometre bakım aralığı girin.');
        return;
      }
      if (hasMonths && _sourceDate == null) {
        _message('Ay aralığı için son bakım tarihini girin.');
        return;
      }
    }

    setState(() => _saving = true);
    final body = <String, dynamic>{
      'reminderType': _type,
      if (_title.text.trim().isNotEmpty) 'title': _title.text.trim(),
      if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
    };
    if (_type == 'VEHICLE_INSPECTION') {
      if (_inspectionMode == 'FIRST') {
        body['firstInspection'] = true;
      } else if (_inspectionMode == 'LAST' && _sourceDate != null) {
        body['sourceDate'] = _iso(_sourceDate!);
        body['firstInspection'] = false;
      } else if (_inspectionMode == 'EXPLICIT' && _dueDate != null) {
        body['dueDate'] = _iso(_dueDate!);
      }
    } else if (_type == 'PERIODIC_MAINTENANCE' && !_manualMaintenance) {
      if (_sourceDate != null) body['sourceDate'] = _iso(_sourceDate!);
      if (_sourceMileage.text.trim().isNotEmpty) {
        body['sourceMileage'] = int.parse(_sourceMileage.text);
      }
      if (_intervalMonths.text.trim().isNotEmpty) {
        body['intervalMonths'] = int.parse(_intervalMonths.text);
      }
      if (_intervalMileage.text.trim().isNotEmpty) {
        body['intervalMileage'] = int.parse(_intervalMileage.text);
      }
    } else {
      if (_dueDate != null) body['dueDate'] = _iso(_dueDate!);
      if ((_type == 'CUSTOM' || _type == 'TIRE_CHECK' || _manualMaintenance) &&
          _dueMileage.text.trim().isNotEmpty) {
        body['dueMileage'] = int.parse(_dueMileage.text);
      }
    }

    try {
      const service = VehicleTrackingService();
      final result = widget.reminder == null
          ? await service.addReminder(widget.vehicle.id, body)
          : await service.updateReminder(
              widget.vehicle.id,
              widget.reminder!.id,
              body,
            );
      if (mounted) Navigator.pop(context, result);
    } catch (error) {
      if (mounted) {
        _message(
          error is ApiException ? error.message : 'Hatırlatma kaydedilemedi.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: AppText(text)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: AppText(
        widget.reminder == null ? 'Hatırlatma Ekle' : 'Hatırlatmayı Düzenle',
      ),
    ),
    body: SafeArea(
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: InputDecoration(labelText: 'Hatırlatma türü'.tr),
              items: _types
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: AppText(_label(type)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _type = value!),
            ),
            const SizedBox(height: 16),
            ..._typeFields(),
            if (_type == 'CUSTOM') ...[
              TextFormField(
                controller: _title,
                maxLength: 120,
                decoration: InputDecoration(labelText: 'Başlık'.tr),
                validator: (value) =>
                    value!.trim().isEmpty ? 'Başlık girin.' : null,
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _note,
              maxLines: 3,
              maxLength: 1000,
              decoration: InputDecoration(
                labelText: 'Not (isteğe bağlı)'.tr,
              ),
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

  List<Widget> _typeFields() {
    if (_type == 'VEHICLE_INSPECTION') return _inspectionFields();
    if (_type == 'PERIODIC_MAINTENANCE') return _maintenanceFields();
    if (_type == 'TRAFFIC_INSURANCE' || _type == 'COMPREHENSIVE_INSURANCE') {
      return [
        _dateTile(
          'Poliçede yazan bitiş tarihi',
          _dueDate,
          (value) => _dueDate = value,
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: AppText(
            'Hatırlatma poliçedeki gerçek bitiş tarihine göre oluşturulur.',
          ),
        ),
      ];
    }
    return _manualFields();
  }

  List<Widget> _inspectionFields() => [
    DropdownButtonFormField<String>(
      initialValue: _inspectionMode,
      decoration: InputDecoration(labelText: 'Muayene bilgisi'.tr),
      items: const [
        DropdownMenuItem(value: 'FIRST', child: AppText('İlk muayene')),
        DropdownMenuItem(
          value: 'LAST',
          child: AppText('Son onaylanan muayene tarihi'),
        ),
        DropdownMenuItem(
          value: 'EXPLICIT',
          child: AppText('Resmî son geçerlilik tarihi'),
        ),
      ],
      onChanged: (value) => setState(() => _inspectionMode = value!),
    ),
    const SizedBox(height: 12),
    if (_inspectionMode == 'FIRST')
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.calculate_outlined),
        title: const AppText('İlk muayene tarihi otomatik hesaplanacak'),
        subtitle: AppText(
          widget.vehicle.vehicleCategory == null ||
                  widget.vehicle.conformityDate == null
              ? 'Araç kategorisi veya uygunluk belgesi tarihi eksik.'
              : 'Araç profilindeki kategori ve uygunluk belgesi tarihi kullanılacak.',
        ),
      ),
    if (_inspectionMode == 'LAST')
      _dateTile(
        'Son onaylanan muayene tarihi',
        _sourceDate,
        (value) => _sourceDate = value,
      ),
    if (_inspectionMode == 'EXPLICIT')
      _dateTile(
        'Resmî son geçerlilik tarihi',
        _dueDate,
        (value) => _dueDate = value,
      ),
    const Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: AppText(
        'Kategoriye göre yasal periyot backend tarafından uygulanır. Emin değilseniz muayene raporundaki son geçerlilik tarihini girin.',
      ),
    ),
  ];

  List<Widget> _maintenanceFields() {
    if (_manualMaintenance) {
      return [
        const AppText('Bu eski hatırlatma manuel hedef kullanıyor.'),
        TextButton(
          onPressed: () => setState(() => _manualMaintenance = false),
          child: const AppText('Kaynak bilgilerle yeniden hesapla'),
        ),
        ..._manualFields(),
      ];
    }
    return [
      _dateTile(
        'Son bakım tarihi',
        _sourceDate,
        (value) => _sourceDate = value,
      ),
      _numberField(_sourceMileage, 'Son bakım kilometresi'),
      const SizedBox(height: 14),
      _numberField(_intervalMonths, 'Bakım aralığı (ay)'),
      const SizedBox(height: 14),
      _numberField(_intervalMileage, 'Bakım aralığı (km)'),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: AppText(
          'Üretici veya servis planındaki ay ve/veya kilometre aralığını girin. Sonraki bakım hedefi backend tarafından hesaplanır.',
        ),
      ),
    ];
  }

  List<Widget> _manualFields() => [
    _dateTile('Hedef tarih', _dueDate, (value) => _dueDate = value),
    _numberField(_dueMileage, 'Hedef kilometre'),
    const SizedBox(height: 16),
  ];

  Widget _dateTile(
    String label,
    DateTime? value,
    ValueChanged<DateTime> update,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: AppText(label),
    subtitle: AppText(_dateText(value)),
    trailing: const Icon(Icons.calendar_month_outlined),
    onTap: () => _pickDate(value, update),
  );

  Widget _numberField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.isEmpty) return null;
          final parsed = int.tryParse(text);
          return parsed == null || parsed < 0 || parsed > 2000000
              ? 'Geçerli bir değer girin.'
              : null;
        },
      );

  String _label(String value) =>
      const {
        'PERIODIC_MAINTENANCE': 'Periyodik bakım',
        'VEHICLE_INSPECTION': 'Araç muayenesi',
        'TRAFFIC_INSURANCE': 'Trafik sigortası',
        'COMPREHENSIVE_INSURANCE': 'Kasko',
        'TIRE_CHECK': 'Lastik kontrolü',
        'CUSTOM': 'Özel',
      }[value] ??
      value;
}
