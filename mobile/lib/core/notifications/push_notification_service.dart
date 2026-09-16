import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../network/api_client.dart';
import 'firebase_bootstrap.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty && FirebaseBootstrap.isConfigured) {
    await Firebase.initializeApp(options: FirebaseBootstrap.options);
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();
  final _events = StreamController<void>.broadcast();
  StreamSubscription<String>? _refreshSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  String? _currentToken;
  bool _firebaseReady = false;

  Stream<void> get events => _events.stream;

  Future<void> initializeFirebase() async {
    try {
      _firebaseReady = await FirebaseBootstrap.initialize();
      if (!_firebaseReady) return;
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      _messageSubscription ??= FirebaseMessaging.onMessage.listen((_) {
        _events.add(null);
      });
      _openedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen((_) {
        _events.add(null);
      });
    } catch (_) {
      _firebaseReady = false;
    }
  }

  Future<void> registerAuthenticatedDevice() async {
    if (!_firebaseReady) return;
    try {
      await FirebaseMessaging.instance.requestPermission(provisional: true);
      if (Platform.isIOS) {
        for (var attempt = 0; attempt < 5; attempt++) {
          if (await FirebaseMessaging.instance.getAPNSToken() != null) break;
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _register(token);
      _refreshSubscription ??= FirebaseMessaging.instance.onTokenRefresh.listen(
        _register,
      );
    } catch (_) {
      // Firebase console configuration is optional in local development.
    }
  }

  Future<void> unregisterCurrentDevice() async {
    final token = _currentToken;
    if (token == null) return;
    try {
      await const ApiClient().delete(
        '/notifications/devices?token=${Uri.encodeQueryComponent(token)}',
      );
    } catch (_) {
      // Logout must continue even if token cleanup cannot reach the backend.
    } finally {
      _currentToken = null;
    }
  }

  Future<void> _register(String token) async {
    await const ApiClient().post(
      '/notifications/devices',
      body: {'token': token, 'platform': Platform.isIOS ? 'IOS' : 'ANDROID'},
    );
    _currentToken = token;
  }
}
