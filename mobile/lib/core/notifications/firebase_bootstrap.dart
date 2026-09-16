import 'dart:io';

import 'package:firebase_core/firebase_core.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool get isConfigured =>
      _apiKey.isNotEmpty &&
      _appId.isNotEmpty &&
      _senderId.isNotEmpty &&
      _projectId.isNotEmpty;

  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const _senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _iosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
    defaultValue: 'com.gorkem.ekspersiz',
  );

  static String get _appId => Platform.isIOS ? _iosAppId : _androidAppId;

  static FirebaseOptions get options => FirebaseOptions(
    apiKey: _apiKey,
    appId: _appId,
    messagingSenderId: _senderId,
    projectId: _projectId,
    iosBundleId: Platform.isIOS ? _iosBundleId : null,
  );

  static Future<bool> initialize() async {
    if (!isConfigured) return false;
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: options);
    }
    return true;
  }
}
