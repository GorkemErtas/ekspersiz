import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/ai_assistant/models/ai_assistant_models.dart';
import 'package:mobile/features/ai_assistant/services/ai_assistant_service.dart';

class _RecordingClient extends ApiClient {
  final requests = <Map<String, dynamic>>[];
  bool failNext = false;

  @override
  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    Duration? timeout,
    bool includeAuth = true,
    bool clearTokenOnUnauthorized = true,
  }) async {
    expect(path, '/ai-assistant/chat');
    requests.add(body!);
    if (failNext) {
      failNext = false;
      throw const ApiException(statusCode: 503, message: 'Tekrar deneyin.');
    }
    return {'intent': 'GENERAL', 'answer': 'Tam yanıt.'};
  }
}

void main() {
  test(
    'long replies retain opening and ending within the existing history contract',
    () async {
      final client = _RecordingClient();
      final service = AiAssistantService(apiClient: client);
      final longAnswer = 'ÖNEMLİ BAŞLANGIÇ ${'🚗' * 1800} KRİTİK SON UYARI';
      final history = [
        for (var i = 0; i < 6; i++)
          AiChatMessage(text: 'Soru $i', isUser: true),
        AiChatMessage(text: longAnswer, isUser: false),
      ];
      await service.ask('Ayrıntısını açıkla', vehicleId: 7, history: history);
      final body = client.requests.single;
      final sent = body['history'] as List;
      expect(sent, hasLength(6));
      expect((sent.first as Map)['content'], 'Soru 1');
      final content = (sent.last as Map)['content'] as String;
      expect(content.length, lessThanOrEqualTo(2000));
      expect(content, startsWith('ÖNEMLİ BAŞLANGIÇ'));
      expect(content, endsWith('KRİTİK SON UYARI'));
      expect(content, contains('orta bölümü çıkarıldı'));
      expect(utf8.decode(utf8.encode(content)), content);
      expect(
        history.last.text,
        longAnswer,
        reason: 'The visible answer stays complete',
      );
      expect(body['question'], 'Ayrıntısını açıkla');
      expect(body['vehicleId'], 7);
    },
  );

  test(
    'retries reuse the idempotency key for the exact bounded request',
    () async {
      final client = _RecordingClient()..failNext = true;
      final service = AiAssistantService(apiClient: client);
      final recent = [
        for (var i = 0; i < 6; i++)
          AiChatMessage(text: 'Soru $i', isUser: true),
      ];
      await expectLater(
        service.ask('Devam et', history: recent),
        throwsA(isA<ApiException>()),
      );
      await service.ask(
        'Devam et',
        history: [
          const AiChatMessage(
            text: 'Artık gönderilmeyen eski mesaj',
            isUser: true,
          ),
          ...recent,
        ],
      );
      expect(
        client.requests.first['requestId'],
        client.requests.last['requestId'],
      );
      expect(client.requests.first['history'], client.requests.last['history']);
      await service.ask('Devam et', history: recent);
      expect(
        client.requests.last['requestId'],
        isNot(client.requests.first['requestId']),
      );
    },
  );
}
