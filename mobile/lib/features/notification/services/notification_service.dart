import '../../../core/network/api_client.dart';
import '../models/app_notification.dart';

class NotificationService {
  const NotificationService({this.apiClient = const ApiClient()});

  final ApiClient apiClient;

  Future<List<AppNotification>> getNotifications({
    bool unreadOnly = false,
  }) async {
    final response = await apiClient.get(
      '/notifications?unreadOnly=$unreadOnly',
    );
    if (response is! List) {
      throw const FormatException('Bildirimler alınamadı.');
    }
    return response
        .map(
          (item) =>
              AppNotification.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<int> getUnreadCount() async {
    final response = await apiClient.get('/notifications/unread-count');
    if (response is! Map) return 0;
    return (response['unreadCount'] as num?)?.toInt() ?? 0;
  }

  Future<AppNotification> markRead(int id) async {
    final response = await apiClient.put(
      '/notifications/$id/read',
      body: const {},
    );
    return AppNotification.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<void> markAllRead() =>
      apiClient.put('/notifications/read-all', body: const {});
}
