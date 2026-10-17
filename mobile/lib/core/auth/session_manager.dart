import 'dart:async';

import 'package:flutter/foundation.dart';

class SessionManager {
  SessionManager._();

  static final StreamController<void> _unauthorizedController =
      StreamController<void>.broadcast();

  static Stream<void> get unauthorizedStream => _unauthorizedController.stream;

  // Opaque, user-bound lifetime. No token or personal data is an image key.
  static final imageScope = ValueNotifier<Object>(Object());
  static bool imagesAllowed =
      true; // Restored sessions still require server authorization.
  static (int, int?, String?)? _imageUserScope;

  static void invalidateImages({bool? allowImages}) {
    if (allowImages != null) {
      imagesAllowed = allowImages;
      _imageUserScope = null;
    }
    imageScope.value = Object();
  }

  static void updateImageUserScope(int userId, int? businessId, String? role) {
    final next = (userId, businessId, role);
    if (_imageUserScope == next) return;
    _imageUserScope = next;
    invalidateImages();
  }

  static void notifyUnauthorized() {
    invalidateImages(allowImages: false);
    _unauthorizedController.add(null);
  }
}
