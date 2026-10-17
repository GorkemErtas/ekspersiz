import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/auth/session_manager.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/inspection/services/inspection_image_cache.dart';
import 'package:mobile/features/inspection/services/inspection_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List photo;
  late InspectionImageCache cache;
  late _ImageApi api;
  late InspectionService service;

  setUpAll(() async {
    final data = await rootBundle.load('assets/images/ekspersiz_logo.png');
    photo = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  });
  setUp(() {
    SessionManager.invalidateImages(allowImages: true);
    cache = InspectionImageCache();
    api = _ImageApi(photo);
    service = InspectionService(apiClient: api, imageCache: cache);
  });
  tearDown(() => cache.dispose());

  test(
    'reopening authorizes each read but downloads only once, without copying',
    () async {
      expect(await service.getInspectionImage(1), same(photo));
      expect(await service.getInspectionImage(1), same(photo));
      expect(api.downloads, 1);
      expect(api.authorizations, 3); // Before/after first GET, then cache hit.
    },
  );

  test('concurrent reads share authorization and one download', () async {
    final gate = Completer<Uint8List>();
    api.pending = gate.future;
    final a = service.getInspectionImage(1);
    final b = service.getInspectionImage(1);
    expect(a, same(b));
    gate.complete(photo);
    expect(await a, same(await b));
    expect(api.downloads, 1);
  });

  test(
    'accepted original upload seeds the first result without a photo GET',
    () async {
      await service.uploadImage(
        inspectionId: 1,
        imageBytes: photo,
        filename: 'photo.png',
        contentType: 'image/png',
      );
      expect(api.uploadBytes, same(photo));
      expect(await service.getInspectionImage(1), same(photo));
      expect(api.downloads, 0);
      expect(api.authorizations, 1);
    },
  );

  test('failed or mismatched uploads cannot seed reuse', () async {
    api.uploadError = const ApiException(statusCode: 400, message: 'Rejected');
    await expectLater(
      service.uploadImage(
        inspectionId: 1,
        imageBytes: photo,
        filename: 'photo.png',
        contentType: 'image/png',
      ),
      throwsA(isA<ApiException>()),
    );
    expect(cache.entryCount, 0);
    api.uploadError = null;
    api.uploadId = 2;
    await service.uploadImage(
      inspectionId: 1,
      imageBytes: photo,
      filename: 'photo.png',
      contentType: 'image/png',
    );
    expect(cache.entryCount, 0);
  });

  test('path replacement and removal never reuse the old photo', () async {
    await service.getInspectionImage(1);
    api.path = 'replacement.png';
    await service.getInspectionImage(1);
    expect(api.downloads, 2);
    expect(cache.entryCount, 1);
    api.path = null;
    await expectLater(service.getInspectionImage(1), throwsFormatException);
    expect(cache.entryCount, 0);
  });

  test('replacement during download is rejected', () async {
    final gate = Completer<Uint8List>();
    api.pending = gate.future;
    final request = service.getInspectionImage(1);
    await Future<void>.delayed(Duration.zero);
    api.path = 'new.png';
    gate.complete(photo);
    await expectLater(request, throwsFormatException);
    expect(cache.entryCount, 0);
  });

  test('retry bypasses a valid entry', () async {
    await service.getInspectionImage(1);
    await service.getInspectionImage(1, forceRefresh: true);
    expect(api.downloads, 2);
  });

  test('an obsolete completion cannot overwrite a refreshed request', () async {
    final gate = Completer<Uint8List>();
    api.pending = gate.future;
    final obsolete = service.getInspectionImage(1);
    await Future<void>.delayed(Duration.zero);
    api.pending = null;
    await service.getInspectionImage(1, forceRefresh: true);
    gate.complete(photo);
    await expectLater(obsolete, throwsStateError);
    expect(cache.entryCount, 1);
    await service.getInspectionImage(1);
    expect(api.downloads, 2);
  });

  test(
    'oversized upload skips seeding and uses the normal download fallback',
    () async {
      cache.dispose();
      cache = InspectionImageCache(maxImageBytes: photo.length - 1);
      service = InspectionService(apiClient: api, imageCache: cache);
      await service.uploadImage(
        inspectionId: 1,
        imageBytes: photo,
        filename: 'photo.png',
        contentType: 'image/png',
      );
      expect(cache.entryCount, 0);
      expect(await service.getInspectionImage(1), same(photo));
      expect(api.downloads, 1);
      expect(cache.entryCount, 0);
    },
  );

  test('user A session cannot populate or return bytes to user B', () async {
    final gate = Completer<Uint8List>();
    api.pending = gate.future;
    final old = service.getInspectionImage(1);
    await Future<void>.delayed(Duration.zero);
    SessionManager.invalidateImages(allowImages: false);
    expect(cache.entryCount, 0);
    SessionManager.invalidateImages(allowImages: true);
    gate.complete(photo);
    await expectLater(old, throwsStateError);
    expect(cache.entryCount, 0);
    api.pending = null;
    await service.getInspectionImage(1);
    expect(api.downloads, 2);
  });

  test(
    'an upload completing after a session transition does not seed',
    () async {
      final gate = Completer<dynamic>();
      api.uploadPending = gate.future;
      final upload = service.uploadImage(
        inspectionId: 1,
        imageBytes: photo,
        filename: 'photo.png',
        contentType: 'image/png',
      );
      SessionManager.invalidateImages(allowImages: true);
      gate.complete({'id': 1, 'imagePath': 'image.png'});
      await upload;
      expect(cache.entryCount, 0);
    },
  );

  for (final status in [401, 403, 404, 408, 0]) {
    test('authorization $status is never hidden by a cached image', () async {
      await service.getInspectionImage(1);
      api.error = ApiException(statusCode: status, message: 'Denied');
      await expectLater(
        service.getInspectionImage(1),
        throwsA(isA<ApiException>()),
      );
      expect(cache.entryCount, 0);
      expect(api.downloads, 1);
    });
    test('download $status failure is retried normally', () async {
      api.downloadError = ApiException(statusCode: status, message: 'Failed');
      await expectLater(
        service.getInspectionImage(1),
        throwsA(isA<ApiException>()),
      );
      expect(cache.entryCount, 0);
      api.downloadError = null;
      await service.getInspectionImage(1);
      expect(api.downloads, 2);
    });
  }

  for (final bad in [
    Uint8List(0),
    Uint8List.fromList(utf8.encode('not an image')),
  ]) {
    test('empty/corrupt bodies are not cached or reused', () async {
      api.bytes = bad;
      await expectLater(service.getInspectionImage(1), throwsA(anything));
      expect(cache.entryCount, 0);
      api.bytes = photo;
      await service.getInspectionImage(1);
      expect(api.downloads, 2);
    });
  }

  test('LRU, count limit and absolute TTL are enforced', () async {
    cache.dispose();
    var now = DateTime(2026);
    cache = InspectionImageCache(now: () => now);
    service = InspectionService(apiClient: api, imageCache: cache);
    await service.getInspectionImage(1);
    await service.getInspectionImage(2);
    await service.getInspectionImage(3);
    await service.getInspectionImage(1); // Make 1 most recently used.
    await service.getInspectionImage(4); // Evicts 2.
    expect(cache.entryCount, 3);
    expect(api.downloads, 4);
    await service.getInspectionImage(1);
    expect(api.downloads, 4);
    await service.getInspectionImage(2);
    expect(api.downloads, 5);
    now = now.add(const Duration(minutes: 5));
    await service.getInspectionImage(2);
    expect(api.downloads, 6);
    expect(cache.entryCount, 1);
  });

  test(
    'total bytes evict LRU, oversized bodies return without retention',
    () async {
      cache.dispose();
      cache = InspectionImageCache(
        maxBytes: photo.length * 2,
        maxImageBytes: photo.length,
      );
      service = InspectionService(apiClient: api, imageCache: cache);
      for (final id in [1, 2, 3]) {
        await service.getInspectionImage(id);
      }
      expect(cache.entryCount, 2);
      expect(cache.byteCount, photo.length * 2);
      cache.dispose();
      cache = InspectionImageCache(maxImageBytes: photo.length - 1);
      service = InspectionService(apiClient: api, imageCache: cache);
      expect(await service.getInspectionImage(1), same(photo));
      await service.getInspectionImage(1);
      expect(cache.entryCount, 0);
      expect(cache.byteCount, 0);
      expect(api.downloads, 5);
    },
  );

  test(
    'memory pressure cancels stale completions and releases retained data',
    () async {
      await service.getInspectionImage(1);
      final gate = Completer<Uint8List>();
      api.pending = gate.future;
      final old = service.getInspectionImage(2);
      await Future<void>.delayed(Duration.zero);
      cache.didHaveMemoryPressure();
      expect(cache.entryCount, 0);
      expect(cache.byteCount, 0);
      gate.complete(photo);
      await expectLater(old, throwsStateError);
      expect(cache.entryCount, 0);
    },
  );
}

class _ImageApi extends ApiClient {
  _ImageApi(this.bytes);
  Uint8List bytes;
  String? path = 'image.png';
  int downloads = 0;
  int authorizations = 0;
  int uploadId = 1;
  List<int>? uploadBytes;
  ApiException? error;
  ApiException? downloadError;
  ApiException? uploadError;
  Future<Uint8List>? pending;
  Future<dynamic>? uploadPending;

  @override
  Future<dynamic> get(String path) async {
    authorizations++;
    if (error != null) throw error!;
    return {'id': int.parse(path.split('/').last), 'imagePath': this.path};
  }

  @override
  Future<Uint8List> getBytes(String path) async {
    downloads++;
    if (downloadError != null) throw downloadError!;
    return pending ?? bytes;
  }

  @override
  Future<dynamic> postMultipart(
    String path, {
    required List<int> fileBytes,
    required String filename,
    String fileFieldName = 'image',
    String contentType = 'image/jpeg',
  }) async {
    uploadBytes = fileBytes;
    if (uploadError != null) throw uploadError!;
    return uploadPending ?? {'id': uploadId, 'imagePath': this.path};
  }
}
