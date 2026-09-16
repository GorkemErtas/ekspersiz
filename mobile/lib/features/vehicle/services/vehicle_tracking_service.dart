import '../../../core/network/api_client.dart';
import '../models/maintenance_record.dart';
import '../models/vehicle_history_item.dart';
import '../models/vehicle_overview.dart';
import '../models/vehicle_reminder.dart';

class VehicleTrackingService {
  const VehicleTrackingService({this.apiClient = const ApiClient()});
  final ApiClient apiClient;

  Future<VehicleOverview> getOverview(int vehicleId) async =>
      VehicleOverview.fromJson(
        Map<String, dynamic>.from(
          await apiClient.get('/vehicles/$vehicleId/overview') as Map,
        ),
      );

  Future<List<MaintenanceRecord>> getMaintenance(int vehicleId) async {
    final data =
        await apiClient.get('/vehicles/$vehicleId/maintenance') as List;
    return data
        .map(
          (e) =>
              MaintenanceRecord.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<MaintenanceRecord> addMaintenance(
    int vehicleId,
    Map<String, dynamic> body,
  ) async => MaintenanceRecord.fromJson(
    Map<String, dynamic>.from(
      await apiClient.post('/vehicles/$vehicleId/maintenance', body: body)
          as Map,
    ),
  );

  Future<MaintenanceRecord> updateMaintenance(
    int vehicleId,
    int recordId,
    Map<String, dynamic> body,
  ) async => MaintenanceRecord.fromJson(
    Map<String, dynamic>.from(
      await apiClient.put(
            '/vehicles/$vehicleId/maintenance/$recordId',
            body: body,
          )
          as Map,
    ),
  );

  Future<void> deleteMaintenance(int vehicleId, int recordId) =>
      apiClient.delete('/vehicles/$vehicleId/maintenance/$recordId');

  Future<List<VehicleReminder>> getReminders(int vehicleId) async {
    final data = await apiClient.get('/vehicles/$vehicleId/reminders') as List;
    return data
        .map(
          (e) => VehicleReminder.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<VehicleReminder> addReminder(
    int vehicleId,
    Map<String, dynamic> body,
  ) async => VehicleReminder.fromJson(
    Map<String, dynamic>.from(
      await apiClient.post('/vehicles/$vehicleId/reminders', body: body) as Map,
    ),
  );

  Future<VehicleReminder> updateReminder(
    int vehicleId,
    int reminderId,
    Map<String, dynamic> body,
  ) async => VehicleReminder.fromJson(
    Map<String, dynamic>.from(
      await apiClient.put(
            '/vehicles/$vehicleId/reminders/$reminderId',
            body: body,
          )
          as Map,
    ),
  );

  Future<VehicleReminder> setReminderCompleted(
    int vehicleId,
    int reminderId,
    bool completed,
  ) async => VehicleReminder.fromJson(
    Map<String, dynamic>.from(
      await apiClient.put(
            '/vehicles/$vehicleId/reminders/$reminderId/completion?completed=$completed',
            body: const {},
          )
          as Map,
    ),
  );

  Future<void> deleteReminder(int vehicleId, int reminderId) =>
      apiClient.delete('/vehicles/$vehicleId/reminders/$reminderId');

  Future<List<VehicleHistoryItem>> getHistory(int vehicleId) async {
    final data = await apiClient.get('/vehicles/$vehicleId/history') as List;
    return data
        .map(
          (e) =>
              VehicleHistoryItem.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }
}
