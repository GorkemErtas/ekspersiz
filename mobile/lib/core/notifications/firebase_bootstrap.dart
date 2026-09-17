import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool get isConfigured => true;

  static FirebaseOptions get options =>
      DefaultFirebaseOptions.currentPlatform;

  static Future<bool> initialize() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    return true;
  }
}