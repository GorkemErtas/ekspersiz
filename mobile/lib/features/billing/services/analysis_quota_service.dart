import '../../../core/network/api_client.dart';
import '../models/analysis_quota.dart';

class AnalysisQuotaService {
  const AnalysisQuotaService({this.apiClient = const ApiClient()});

  final ApiClient apiClient;

  Future<AnalysisQuota> getQuota() async {
    final response = await apiClient.get('/analysis-quota');
    if (response is! Map) {
      throw const FormatException('Analiz kota bilgisi alınamadı.');
    }
    return AnalysisQuota.fromJson(Map<String, dynamic>.from(response));
  }
}
