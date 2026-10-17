import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../auth/session_manager.dart';

class TokenStorage {
  TokenStorage._();

  static const String _accessTokenKey = 'access_token';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<void> saveAccessToken(String accessToken) async {
    SessionManager.invalidateImages(allowImages: false);
    await _storage.write(key: _accessTokenKey, value: accessToken);
    SessionManager.invalidateImages(allowImages: accessToken.isNotEmpty);
  }

  static Future<String?> getAccessToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  static Future<bool> hasAccessToken() async {
    final token = await getAccessToken();

    return token != null && token.isNotEmpty;
  }

  static Future<void> deleteAccessToken() async {
    SessionManager.invalidateImages(allowImages: false);
    await _storage.delete(key: _accessTokenKey);
  }

  static Future<void> clearAll() async {
    SessionManager.invalidateImages(allowImages: false);
    await _storage.deleteAll();
  }
}
