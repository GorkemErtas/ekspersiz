import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/core/auth/session_manager.dart';

void initializeUiSession() {
  SessionManager.invalidateImages(allowImages: true);
  FlutterSecureStorage.setMockInitialValues({'access_token': 'ui-test'});
}

const uiVehicleJson = {
  'id': 1,
  'plate': '34 ABC 123',
  'brand': 'Honda',
  'model': 'Civic',
  'modelYear': 2024,
  'mileage': 50000,
  'primaryVehicle': true,
};

http.Response uiJsonResponse(Object data) => http.Response(
  jsonEncode(data),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Client uiMockClient({
  Future<http.Response> Function(http.Request)? onChat,
}) => MockClient((request) async {
  final path = request.url.path;
  if (path.endsWith('/vehicles')) return uiJsonResponse([uiVehicleJson]);
  if (path.endsWith('/inspections')) return uiJsonResponse([]);
  if (path.endsWith('/overview')) {
    return uiJsonResponse({
      'vehicle': uiVehicleJson,
      'trackingStatus': 'GOOD',
      'disclaimer': 'Bakım ve hatırlatmalarınızı takip edin.',
      'upcomingReminders': [],
    });
  }
  if (path.endsWith('/unread-count')) return uiJsonResponse({'unreadCount': 2});
  if (path.endsWith('/notifications') ||
      path.endsWith('/maintenance') ||
      path.endsWith('/reminders') ||
      path.endsWith('/history')) {
    return uiJsonResponse([]);
  }
  if (path.endsWith('/ai-assistant/entitlement')) {
    return uiJsonResponse({
      'status': 'ACTIVE',
      'canAsk': true,
      'dailyLimit': 10,
      'usedToday': 0,
      'remainingToday': 10,
    });
  }
  if (path.endsWith('/ai-assistant/chat') && onChat != null) {
    return onChat(request);
  }
  throw StateError('Unexpected UI test request: ${request.method} $path');
});
