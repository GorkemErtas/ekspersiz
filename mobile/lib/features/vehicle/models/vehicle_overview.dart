import 'maintenance_record.dart';
import 'vehicle.dart';
import 'vehicle_reminder.dart';

class VehicleOverview {
  const VehicleOverview({
    required this.vehicle,
    required this.trackingStatus,
    required this.disclaimer,
    this.latestMaintenance,
    required this.upcomingReminders,
    this.latestInspectionId,
    this.latestDamageSeverity,
    this.latestInspectionAt,
  });
  final Vehicle vehicle;
  final String trackingStatus;
  final String disclaimer;
  final MaintenanceRecord? latestMaintenance;
  final List<VehicleReminder> upcomingReminders;
  final int? latestInspectionId;
  final String? latestDamageSeverity;
  final DateTime? latestInspectionAt;

  factory VehicleOverview.fromJson(Map<String, dynamic> json) =>
      VehicleOverview(
        vehicle: Vehicle.fromJson(
          Map<String, dynamic>.from(json['vehicle'] as Map),
        ),
        trackingStatus: json['trackingStatus'] as String? ?? 'GOOD',
        disclaimer: json['disclaimer'] as String? ?? '',
        latestMaintenance: json['latestMaintenance'] is Map
            ? MaintenanceRecord.fromJson(
                Map<String, dynamic>.from(json['latestMaintenance'] as Map),
              )
            : null,
        upcomingReminders: (json['upcomingReminders'] as List? ?? const [])
            .map(
              (e) =>
                  VehicleReminder.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
        latestInspectionId: (json['latestInspectionId'] as num?)?.toInt(),
        latestDamageSeverity: json['latestDamageSeverity'] as String?,
        latestInspectionAt: DateTime.tryParse(
          json['latestInspectionAt'] as String? ?? '',
        ),
      );
}
