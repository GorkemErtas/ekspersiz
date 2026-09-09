import 'dart:async';

class SessionManager {
  SessionManager._();

  static final StreamController<void>
  _unauthorizedController =
  StreamController<void>.broadcast();

  static Stream<void> get unauthorizedStream =>
      _unauthorizedController.stream;

  static void notifyUnauthorized() {
    _unauthorizedController.add(null);
  }
}