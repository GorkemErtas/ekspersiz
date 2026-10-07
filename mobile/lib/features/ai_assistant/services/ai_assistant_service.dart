import '../../../core/network/api_client.dart';
import '../models/ai_assistant_models.dart';

class AiAssistantService {
  AiAssistantService({this.apiClient = const ApiClient()});

  final ApiClient apiClient;

  Future<AiAssistantEntitlement> entitlement() async {
    final data = await apiClient.get('/ai-assistant/entitlement');
    return AiAssistantEntitlement.fromJson(data as Map<String, dynamic>);
  }

  Future<AiAssistantEntitlement> startTrial() async {
    final data = await apiClient.post('/ai-assistant/trial');
    return AiAssistantEntitlement.fromJson(data as Map<String, dynamic>);
  }

  Future<AiAssistantReply> ask(
    String question, {
    int? vehicleId,
    List<AiChatMessage> history = const [],
  }) async {
    final data = await apiClient.post(
      '/ai-assistant/chat',
      body: {
        'question': question,
        'vehicleId': ?vehicleId,
        'history': history
            .takeLast(6)
            .map((message) => {
                  'role': message.isUser ? 'user' : 'assistant',
                  'content': message.text,
                })
            .toList(growable: false),
      },
      timeout: const Duration(seconds: 75),
    );
    return AiAssistantReply.fromJson(data as Map<String, dynamic>);
  }
}


extension _TakeLast<T> on Iterable<T> {
  Iterable<T> takeLast(int count) {
    if (count <= 0) return const Iterable.empty();
    final values = toList(growable: false);
    final start = values.length > count ? values.length - count : 0;
    return values.skip(start);
  }
}
