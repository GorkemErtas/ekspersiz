import 'package:flutter/material.dart';
import '../../../core/network/api_exception.dart';
import '../models/vehicle_reminder.dart';
import '../services/vehicle_tracking_service.dart';

class ReminderFormScreen extends StatefulWidget {
  const ReminderFormScreen({super.key, required this.vehicleId, this.reminder});
  final int vehicleId;
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
  final _mileage = TextEditingController();
  final _note = TextEditingController();
  late String _type;
  DateTime? _date;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    final r = widget.reminder;
    _type = r?.reminderType ?? 'VEHICLE_INSPECTION';
    _date = r?.dueDate;
    _title.text = r?.title ?? '';
    _mileage.text = r?.dueMileage?.toString() ?? '';
    _note.text = r?.note ?? '';
  }

  @override
  void dispose() {
    _title.dispose();
    _mileage.dispose();
    _note.dispose();
    super.dispose();
  }

  String _iso(DateTime v) =>
      '${v.year.toString().padLeft(4, '0')}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'reminderType': _type,
      if (_title.text.trim().isNotEmpty) 'title': _title.text.trim(),
      if (_date != null) 'dueDate': _iso(_date!),
      if (_mileage.text.trim().isNotEmpty)
        'dueMileage': int.parse(_mileage.text),
      if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
    };
    try {
      const s = VehicleTrackingService();
      final result = widget.reminder == null
          ? await s.addReminder(widget.vehicleId, body)
          : await s.updateReminder(widget.vehicleId, widget.reminder!.id, body);
      if (mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : 'Hatırlatma kaydedilemedi.',
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
      title: Text(
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
              decoration: const InputDecoration(labelText: 'Hatırlatma Türü'),
              items: _types
                  .map(
                    (e) => DropdownMenuItem(value: e, child: Text(_label(e))),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            if (_type == 'CUSTOM') ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _title,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Başlık'),
                validator: (v) => v!.trim().isEmpty ? 'Başlık girin.' : null,
              ),
            ],
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Son tarih'),
              subtitle: Text(
                _date == null
                    ? 'Seçilmedi'
                    : '${_date!.day}.${_date!.month}.${_date!.year}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_date != null)
                    IconButton(
                      onPressed: () => setState(() => _date = null),
                      icon: const Icon(Icons.close),
                    ),
                  const Icon(Icons.calendar_month_outlined),
                ],
              ),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(
                    const Duration(days: 3650),
                  ),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
            TextFormField(
              controller: _mileage,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Hedef kilometre',
                suffixText: 'km',
              ),
              validator: (v) {
                final value = v?.trim() ?? '';
                if (_date == null && value.isEmpty) {
                  return 'Tarih veya kilometre girin.';
                }
                if (value.isEmpty) return null;
                final parsed = int.tryParse(value);
                return parsed == null || parsed < 0 || parsed > 2000000
                    ? 'Geçerli kilometre girin.'
                    : null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _note,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(labelText: 'Not'),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    ),
  );
  String _label(String v) =>
      const {
        'PERIODIC_MAINTENANCE': 'Periyodik bakım',
        'VEHICLE_INSPECTION': 'Araç muayenesi',
        'TRAFFIC_INSURANCE': 'Trafik sigortası',
        'COMPREHENSIVE_INSURANCE': 'Kasko',
        'TIRE_CHECK': 'Lastik kontrolü',
        'CUSTOM': 'Özel',
      }[v] ??
      v;
}
