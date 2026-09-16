import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../auth/models/business_account.dart';
import '../../vehicle/screens/vehicle_detail_screen.dart';
import '../../vehicle/services/vehicle_service.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key, this.businessAccount});

  final BusinessAccount? businessAccount;

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final _service = const NotificationService();
  bool _loading = true;
  String? _error;
  List<AppNotification> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _service.getNotifications();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'Bildirimler yüklenemedi.';
      });
    }
  }

  Future<void> _markAllRead() async {
    await _service.markAllRead();
    await _load();
  }

  Future<void> _open(AppNotification item) async {
    if (!item.read) await _service.markRead(item.id);
    if (item.vehicleId != null && mounted) {
      try {
        final vehicle = await const VehicleService().getVehicleById(
          item.vehicleId!,
        );
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => VehicleDetailScreen(
              vehicle: vehicle,
              businessAccount: widget.businessAccount,
            ),
          ),
        );
      } catch (_) {
        // Archived or no-longer-accessible vehicles stay in notification history.
      }
    }
    await _load();
  }

  Color _color(String severity) => switch (severity) {
    'CRITICAL' => AppTheme.dangerColor,
    'WARNING' => AppTheme.warningColor,
    _ => AppTheme.infoColor,
  };

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Bildirimler'),
      actions: [
        if (_items.any((item) => !item.read))
          TextButton(onPressed: _markAllRead, child: const Text('Tümünü oku')),
      ],
    ),
    body: SafeArea(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: FilledButton(
                onPressed: _load,
                child: const Text('Tekrar Dene'),
              ),
            )
          : _items.isEmpty
          ? const Center(child: Text('Henüz bildiriminiz yok.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final color = _color(item.severity);
                  return AppCard(
                    onTap: () => _open(item),
                    showShadow: false,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.notifications_rounded,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (!item.read)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.primaryColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(item.body),
                              const SizedBox(height: 8),
                              Text(
                                _date(item.createdAt),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    ),
  );
}
