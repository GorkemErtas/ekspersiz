import 'package:mobile/core/localization/app_text.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../auth/models/business_account.dart';
import '../../inspection/screens/create_inspection_screen.dart';
import '../models/maintenance_record.dart';
import '../models/vehicle.dart';
import '../models/vehicle_history_item.dart';
import '../models/vehicle_overview.dart';
import '../models/vehicle_reminder.dart';
import '../services/vehicle_tracking_service.dart';
import 'maintenance_form_screen.dart';
import 'reminder_form_screen.dart';

class VehicleDetailScreen extends StatefulWidget {
  const VehicleDetailScreen({
    super.key,
    required this.vehicle,
    this.businessAccount,
  });
  final Vehicle vehicle;
  final BusinessAccount? businessAccount;
  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  final _service = const VehicleTrackingService();
  bool _loading = true;
  String? _error;
  VehicleOverview? _overview;
  List<MaintenanceRecord> _maintenance = const [];
  List<VehicleReminder> _reminders = const [];
  List<VehicleHistoryItem> _history = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Future.wait([
        _service.getOverview(widget.vehicle.id),
        _service.getMaintenance(widget.vehicle.id),
        _service.getReminders(widget.vehicle.id),
        _service.getHistory(widget.vehicle.id),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _overview = r[0] as VehicleOverview;
        _maintenance = r[1] as List<MaintenanceRecord>;
        _reminders = r[2] as List<VehicleReminder>;
        _history = r[3] as List<VehicleHistoryItem>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException
              ? e.message
              : 'Araç bilgileri yüklenemedi.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _openMaintenance([MaintenanceRecord? record]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaintenanceFormScreen(
          vehicleId: widget.vehicle.id,
          currentMileage: widget.vehicle.mileage,
          record: record,
        ),
      ),
    );
    if (result != null) await _load();
  }

  Future<void> _openReminder([VehicleReminder? reminder]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ReminderFormScreen(vehicle: widget.vehicle, reminder: reminder),
      ),
    );
    if (result != null) await _load();
  }

  Future<bool> _confirm(String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const AppText('Kayıt silinsin mi?'),
          content: AppText(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const AppText('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const AppText('Sil'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> _deleteMaintenance(MaintenanceRecord item) async {
    if (!await _confirm('Bu bakım kaydı kalıcı olarak silinecek.')) return;
    await _service.deleteMaintenance(widget.vehicle.id, item.id);
    await _load();
  }

  Future<void> _deleteReminder(VehicleReminder item) async {
    if (!await _confirm('Bu hatırlatma kalıcı olarak silinecek.')) return;
    await _service.deleteReminder(widget.vehicle.id, item.id);
    await _load();
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  String _status(String value) => switch (value) {
    'ATTENTION' => 'Dikkat gerekiyor',
    'DUE_SOON' => 'Yaklaşan işlem var',
    _ => 'İyi',
  };
  Color _statusColor(String value) => switch (value) {
    'ATTENTION' => AppTheme.dangerColorFor(context),
    'DUE_SOON' => AppTheme.warningColorFor(context),
    _ => AppTheme.successColorFor(context),
  };
  String _type(String v) => v
      .replaceAll('_', ' ')
      .toLowerCase()
      .split(' ')
      .map((e) => e.isEmpty ? e : '${e[0].toUpperCase()}${e.substring(1)}')
      .join(' ');

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: AppText(widget.vehicle.displayName)),
    body: SafeArea(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppText(_error!),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _load,
                    child: const AppText('Tekrar Dene'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                children: [
                  _hero(),
                  const SizedBox(height: 16),
                  _statusCard(),
                  const SizedBox(height: 20),
                  _sectionHeader(
                    'Bakım geçmişi',
                    '${_maintenance.length} kayıt',
                    Icons.build_outlined,
                    () => _openMaintenance(),
                  ),
                  const SizedBox(height: 10),
                  if (_maintenance.isEmpty)
                    _empty('Henüz bakım kaydı yok.')
                  else
                    ..._maintenance.map(_maintenanceCard),
                  const SizedBox(height: 20),
                  _sectionHeader(
                    'Hatırlatmalar',
                    'Muayene, sigorta ve bakım',
                    Icons.notifications_none_rounded,
                    () => _openReminder(),
                  ),
                  const SizedBox(height: 10),
                  if (_reminders.isEmpty)
                    _empty('Henüz hatırlatma yok.')
                  else
                    ..._reminders.map(_reminderCard),
                  const SizedBox(height: 20),
                  _sectionHeader(
                    'Araç geçmişi',
                    'Kronolojik durum ve işlemler',
                    Icons.timeline_rounded,
                    null,
                  ),
                  const SizedBox(height: 10),
                  if (_history.isEmpty)
                    _empty('Henüz geçmiş kaydı yok.')
                  else
                    AppCard(
                      child: Column(
                        children: [
                          for (var i = 0; i < _history.length; i++) ...[
                            if (i > 0) const Divider(),
                            _historyTile(_history[i]),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
    ),
  );

  Widget _hero() => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.directions_car_filled_rounded),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    widget.vehicle.displayName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  AppText(
                    '${widget.vehicle.modelYear} • ${widget.vehicle.mileage} km • ${widget.vehicle.plate}',
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateInspectionScreen(
                    businessAccount: widget.businessAccount,
                  ),
                ),
              );
              if (mounted) await _load();
            },
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const AppText('AI Hasar Analizi'),
          ),
        ),
      ],
    ),
  );
  Widget _statusCard() {
    final o = _overview!;
    final c = _statusColor(o.trackingStatus);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety_outlined, color: c),
              const SizedBox(width: 9),
              AppText(
                'Araç takip durumu',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              AppText(
                _status(o.trackingStatus),
                style: TextStyle(color: c, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (o.latestMaintenance != null) ...[
            const SizedBox(height: 14),
            AppText(
              'Son bakım: ${_date(o.latestMaintenance!.maintenanceDate)} • ${o.latestMaintenance!.mileage} km',
            ),
          ],
          if (o.latestDamageSeverity != null) ...[
            const SizedBox(height: 8),
            AppText('Son görünür hasar sonucu: ${_type(o.latestDamageSeverity!)}'),
          ],
          const SizedBox(height: 12),
          AppText(
            o.disclaimer,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback? add,
  ) => Row(
    children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            AppText(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      if (add != null)
        IconButton(
          onPressed: add,
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
    ],
  );
  Widget _empty(String text) => AppCard(
    showShadow: false,
    child: Center(
      child: Padding(padding: const EdgeInsets.all(8), child: AppText(text)),
    ),
  );
  Widget _maintenanceCard(MaintenanceRecord item) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: AppCard(
      showShadow: false,
      child: Row(
        children: [
          const Icon(Icons.build_circle_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  _type(item.maintenanceType),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                AppText('${_date(item.maintenanceDate)} • ${item.mileage} km'),
                if (item.note != null)
                  AppText(
                    item.note!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) =>
                v == 'edit' ? _openMaintenance(item) : _deleteMaintenance(item),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: AppText('Düzenle')),
              PopupMenuItem(value: 'delete', child: AppText('Sil')),
            ],
          ),
        ],
      ),
    ),
  );
  Widget _reminderCard(VehicleReminder item) {
    final overdue = item.status == 'OVERDUE';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        showShadow: false,
        child: Row(
          children: [
            Icon(
              overdue
                  ? Icons.warning_amber_rounded
                  : Icons.notifications_active_outlined,
              color: overdue ? AppTheme.dangerColorFor(context) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    item.title ?? _type(item.reminderType),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  AppText(
                    item.dueDate != null
                        ? _date(item.dueDate!)
                        : '${item.dueMileage} km',
                  ),
                  AppText(
                    switch (item.status) {
                      'OVERDUE' => 'Gecikmiş',
                      'DUE_SOON' => 'Yaklaşıyor',
                      'COMPLETED' => 'Tamamlandı',
                      _ => 'Yaklaşan',
                    },
                    style: TextStyle(
                      color: overdue
                          ? AppTheme.dangerColorFor(context)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Checkbox(
              value: item.status == 'COMPLETED',
              onChanged: (v) async {
                await _service.setReminderCompleted(
                  widget.vehicle.id,
                  item.id,
                  v ?? false,
                );
                await _load();
              },
            ),
            PopupMenuButton<String>(
              onSelected: (v) =>
                  v == 'edit' ? _openReminder(item) : _deleteReminder(item),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: AppText('Düzenle')),
                PopupMenuItem(value: 'delete', child: AppText('Sil')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyTile(VehicleHistoryItem item) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.circle, size: 12),
    title: AppText(item.title),
    subtitle: AppText(item.description),
    trailing: AppText(
      _date(item.occurredAt),
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}
