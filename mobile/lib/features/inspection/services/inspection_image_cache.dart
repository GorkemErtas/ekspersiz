import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../core/auth/session_manager.dart';

typedef _ImageKey = (Object, int, String);

/// Application-owned RAM only; never an HTTP, disk or proxy cache.
/// Every read requires fresh server authorization, including cache hits.
class InspectionImageCache extends ChangeNotifier with WidgetsBindingObserver {
  InspectionImageCache({
    this.maxBytes = 12 * 1024 * 1024,
    this.maxEntries = 3,
    this.maxImageBytes = 8 * 1024 * 1024,
    this.ttl = const Duration(minutes: 5),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    SessionManager.imageScope.addListener(clear);
    WidgetsBinding.instance.addObserver(this);
  }

  static final instance = InspectionImageCache();

  final int maxBytes;
  final int maxEntries;
  final int maxImageBytes;
  final Duration ttl;
  final DateTime Function() _now;
  final Map<_ImageKey, _ImageEntry> _entries = <_ImageKey, _ImageEntry>{};
  final _flights = <int, Future<Uint8List>>{};
  final _tickets = <int, Object>{};
  Object _epoch = Object();
  int _byteCount = 0;
  ({int? inspectionId, bool resourceRelease}) _invalidation = (
    inspectionId: null,
    resourceRelease: false,
  );

  Object get epoch => _epoch;

  /// Scope and cause of the current synchronous listener notification.
  ({int? inspectionId, bool resourceRelease}) get invalidation => _invalidation;

  @visibleForTesting
  int get byteCount => _byteCount;
  @visibleForTesting
  int get entryCount => _entries.length;

  Future<Uint8List> load({
    required int inspectionId,
    required Future<String?> Function() authorize,
    required Future<Uint8List> Function() download,
    bool forceRefresh = false,
  }) {
    if (!SessionManager.imagesAllowed) {
      return Future.error(StateError('Görüntü oturumu geçersiz.'));
    }
    if (forceRefresh) invalidate(inspectionId);
    final pending = _flights[inspectionId];
    if (pending != null) return pending;

    final scope = SessionManager.imageScope.value;
    final epoch = _epoch;
    final ticket = Object();
    _tickets[inspectionId] = ticket;
    void checkCurrent() {
      if (!identical(scope, SessionManager.imageScope.value) ||
          !identical(epoch, _epoch) ||
          !identical(ticket, _tickets[inspectionId]) ||
          !SessionManager.imagesAllowed) {
        throw StateError('Görüntü isteği artık geçerli değil.');
      }
    }

    final future = () async {
      try {
        final path = await authorize();
        checkCurrent();
        _removeWhere((key) => key.$2 == inspectionId && key.$3 != path);
        if (path == null || path.isEmpty) {
          throw const FormatException('İnceleme fotoğrafı bulunamadı.');
        }
        final key = (scope, inspectionId, path);
        _removeWhere((key) => !_now().isBefore(_entries[key]!.expiresAt));
        final cached = _entries.remove(key);
        if (cached != null) {
          _entries[key] = cached; // LRU, without extending the absolute TTL.
          return cached.bytes;
        }

        final bytes = await download();
        checkCurrent();
        await _validate(bytes);
        checkCurrent();
        // The image endpoint resolves the current file by ID. Verify that a
        // replacement during the download cannot be stored under the old path.
        final currentPath = await authorize();
        checkCurrent();
        if (currentPath != path) {
          throw const FormatException(
            'Fotoğraf değişti. Lütfen tekrar deneyin.',
          );
        }
        _store(key, bytes);
        return bytes;
      } catch (_) {
        // Do not let an obsolete failure evict a newer request's result.
        if (identical(ticket, _tickets[inspectionId])) {
          _removeWhere((key) => key.$2 == inspectionId);
        }
        rethrow;
      } finally {
        if (identical(ticket, _tickets[inspectionId])) {
          _flights.remove(inspectionId);
          _tickets.remove(inspectionId);
        }
      }
    }();
    _flights[inspectionId] = future;
    return future;
  }

  /// Only called after the backend accepts the exact original upload bytes.
  Future<void> seed({
    required Object scope,
    required Object epoch,
    required int inspectionId,
    required String imagePath,
    required Uint8List bytes,
  }) async {
    if (!_fits(bytes) || imagePath.isEmpty) return;
    try {
      await _validate(bytes);
    } catch (_) {
      return; // A display codec failure must not change upload/analysis behavior.
    }
    if (!identical(scope, SessionManager.imageScope.value) ||
        !identical(epoch, _epoch) ||
        !SessionManager.imagesAllowed) {
      return;
    }
    _removeWhere((key) => key.$2 == inspectionId);
    _store((scope, inspectionId, imagePath), bytes);
  }

  bool _fits(Uint8List bytes) =>
      bytes.isNotEmpty &&
      bytes.lengthInBytes <= maxImageBytes &&
      bytes.lengthInBytes <= maxBytes &&
      maxEntries > 0;

  Future<void> _validate(Uint8List bytes) async {
    if (bytes.isEmpty) throw const FormatException('Fotoğraf boş.');
    // Decode a disposable 1 px frame to reject corrupt bodies without keeping
    // a full-resolution bitmap or putting it in Flutter's global ImageCache.
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 1,
      targetHeight: 1,
      allowUpscaling: false,
    );
    try {
      final frame = await codec.getNextFrame();
      frame.image.dispose();
    } finally {
      codec.dispose();
    }
  }

  void _store(_ImageKey key, Uint8List bytes) {
    if (!_fits(bytes)) return; // Large files use the normal download result.
    _removeWhere(
      (candidate) =>
          candidate == key || !_now().isBefore(_entries[candidate]!.expiresAt),
    );
    while (_entries.length >= maxEntries ||
        _byteCount + bytes.lengthInBytes > maxBytes) {
      _removeWhere((candidate) => candidate == _entries.keys.first);
    }
    _entries[key] = _ImageEntry(bytes, _now().add(ttl));
    _byteCount += bytes.lengthInBytes;
  }

  void _removeWhere(bool Function(_ImageKey) test) {
    for (final key in _entries.keys.where(test).toList()) {
      _byteCount -= _entries.remove(key)!.bytes.lengthInBytes;
    }
  }

  void invalidate(int inspectionId) {
    _removeWhere((key) => key.$2 == inspectionId);
    _flights.remove(inspectionId);
    _tickets.remove(inspectionId);
    // Also release completed FutureBuilder snapshots on mounted result routes.
    _invalidation = (inspectionId: inspectionId, resourceRelease: false);
    notifyListeners();
  }

  void clear({bool releaseResources = false}) {
    _epoch = Object();
    _entries.clear();
    _flights.clear();
    _tickets.clear();
    _byteCount = 0;
    _invalidation = (inspectionId: null, resourceRelease: releaseResources);
    notifyListeners();
  }

  @override
  void didHaveMemoryPressure() => clear(releaseResources: true);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) clear(releaseResources: true);
  }

  @override
  void dispose() {
    SessionManager.imageScope.removeListener(clear);
    WidgetsBinding.instance.removeObserver(this);
    _entries.clear();
    _flights.clear();
    _tickets.clear();
    _byteCount = 0;
    _epoch = Object();
    super.dispose();
  }
}

class _ImageEntry {
  const _ImageEntry(this.bytes, this.expiresAt);
  final Uint8List bytes;
  final DateTime expiresAt;
}
