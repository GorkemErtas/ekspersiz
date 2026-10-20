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
    final requestHistory = history
        .takeLast(6)
        .map(
          (message) => {
            'role': message.isUser ? 'user' : 'assistant',
            'content': _historyContent(message.text),
          },
        )
        .toList(growable: false);
    final payload = jsonEncode([question, vehicleId, requestHistory]);
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
        'history': requestHistory,
      },
      timeout: const Duration(seconds: 75),
    );
    final reply = AiAssistantReply.fromJson(data as Map<String, dynamic>);
    _pendingPayload = null;
    _pendingId = null;
    return reply;
  }

  // Keep the displayed answer intact while honoring the API's 2000-character
  // history limit. Retain both the opening and ending of detailed old replies.
  String _historyContent(String text) {
    if (text.length <= 2000) return text;
    const gap = '\n[… önceki mesajın orta bölümü çıkarıldı …]\n';
    var headEnd = 2000 - gap.length - 400;
    var tailStart = text.length - 400;
    // Do not split UTF-16 surrogate pairs (e.g. emoji) at either boundary.
    if ((text.codeUnitAt(headEnd - 1) & 0xFC00) == 0xD800) headEnd--;
    if ((text.codeUnitAt(tailStart) & 0xFC00) == 0xDC00) tailStart++;
    return '${text.substring(0, headEnd)}$gap${text.substring(tailStart)}';
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
