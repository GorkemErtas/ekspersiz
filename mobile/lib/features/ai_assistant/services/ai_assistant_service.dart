import '../../../core/network/api_client.dart';
import '../models/ai_assistant_models.dart';
import 'dart:math';
import 'dart:convert';

class AiAssistantService {
  AiAssistantService({this.apiClient = const ApiClient()});

  final ApiClient apiClient;
  String? _pendingPayload;
  String? _pendingId;

  Future<AiAssistantEntitlement> entitlement() async {
    final data = await apiClient.get('/ai-assistant/entitlement');
    return AiAssistantEntitlement.fromJson(data as Map<String, dynamic>);
  }

  Future<AiAssistantReply> ask(
    String question, {
    int? vehicleId,
    List<AiChatMessage> history = const [],
  }) async {
    final payload = jsonEncode([
      question,
      vehicleId,
      history.map((m) => [m.isUser, m.text]).toList(),
    ]);
    if (_pendingPayload != payload) {
      _pendingPayload = payload;
      final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
      bytes[6] = (bytes[6] & 15) | 64;
      bytes[8] = (bytes[8] & 63) | 128;
      final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      _pendingId =
          '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    }
    final data = await apiClient.post(
      '/ai-assistant/chat',
      body: {
        'question': question,
        'requestId': _pendingId,
        'vehicleId': ?vehicleId,
        'history': history
            .takeLast(6)
            .map(
              (message) => {
                'role': message.isUser ? 'user' : 'assistant',
                'content': message.text,
              },
            )
            .toList(growable: false),
      },
      timeout: const Duration(seconds: 75),
    );
    final reply = AiAssistantReply.fromJson(data as Map<String, dynamic>);
    _pendingPayload = null;
    _pendingId = null;
    return reply;
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
