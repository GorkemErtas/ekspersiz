import '../../../core/network/api_client.dart';

import '../models/nearby_service.dart';

class NearbyServiceService {
  const NearbyServiceService({this.apiClient = const ApiClient()});

  final ApiClient apiClient;

  Future<List<NearbyService>> getNearbyServices(int inspectionId) async {
    final response = await apiClient.get(
      '/inspections/$inspectionId/nearby-services',
    );

    if (response is! List) {
      throw const FormatException('Yakındaki servisler alınamadı.');
    }

    return response.map((item) {
      if (item is! Map) {
        throw const FormatException('Yakındaki servis verisi geçersiz.');
      }

      return NearbyService.fromJson(Map<String, dynamic>.from(item));
    }).toList();
  }
}
