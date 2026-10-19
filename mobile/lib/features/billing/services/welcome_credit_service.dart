import 'dart:io';
import 'package:flutter/services.dart';
import '../../../core/network/api_client.dart';

class WelcomeCreditService {
  static const _channel = MethodChannel('ekspersiz/integrity');
  static Future<String> claim() async {
    if (!Platform.isAndroid) {
      return 'Bu cihazda başlangıç kredisi doğrulaması kullanılamıyor.';
    }
    const api = ApiClient();
    final deviceId = await _channel.invokeMethod<String>('deviceId');
    final challenge = await api.post(
      '/credits/welcome/challenge',
      body: {'deviceId': deviceId},
    );
    if (challenge is! Map) return 'Başlangıç kredisi bilgisi alınamadı.';
    if (challenge['available'] != true) {
      return challenge['message'] as String? ??
          'Başlangıç kredisi doğrulaması şu anda kullanılamıyor.';
    }
    final token = await _channel.invokeMethod<String>('token', {
      'cloudProjectNumber': challenge['cloudProjectNumber'],
      'requestHash': challenge['requestHash'],
    });
    await api.post(
      '/credits/welcome/claim',
      body: {'challengeId': challenge['id'], 'token': token},
    );
    return 'Cihaz doğrulaması tamamlandı. Uygun hesaplar için 1 analiz ve 2 asistan kredisi bir kez tanımlanır.';
  }
}
