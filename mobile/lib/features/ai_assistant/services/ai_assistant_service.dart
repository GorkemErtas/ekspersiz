import '../../../core/network/api_client.dart';
import '../models/ai_assistant_models.dart';

class AiAssistantService {
  AiAssistantService({ApiClient apiClient = const ApiClient()})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<AiAssistantEntitlement> entitlement() async {
    final data = await _apiClient.get('/api/ai-assistant/entitlement');
    return AiAssistantEntitlement.fromJson(data as Map<String, dynamic>);
  }

  Future<AiAssistantEntitlement> startTrial() async {
    final data = await _apiClient.post('/api/ai-assistant/trial');
    return AiAssistantEntitlement.fromJson(data as Map<String, dynamic>);
  }

  Future<AiAssistantReply> ask(String question, {int? vehicleId}) async {
    final data = await _apiClient.post(
      '/api/ai-assistant/chat',
      body: {
        'question': question,
        if (vehicleId != null) 'vehicleId': vehicleId,
      },
      timeout: const Duration(seconds: 75),
    );
    return AiAssistantReply.fromJson(data as Map<String, dynamic>);
  }
}
