import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/auth/session_manager.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/storage/token_storage.dart';
import 'package:mobile/features/auth/services/auth_service.dart';
import 'package:mobile/features/inspection/services/inspection_image_cache.dart';
import 'package:mobile/features/inspection/services/inspection_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late InspectionImageCache cache;
  late InspectionService service;
  late Uint8List photo;
  var status = 200;
  var downloads = 0;
  var userId = 1;
  int? businessId;
  String? role;

  http.Response json(Object data, [int code = 200]) => http.Response(
    jsonEncode(data),
    code,
    headers: {'content-type': 'application/json'},
  );

  http.Client client() => MockClient((request) async {
    if (request.url.path.endsWith('/auth/login')) {
      return json({'accessToken': 'same-token'});
    }
    if (request.url.path.endsWith('/auth/me')) {
      return json({
        'id': userId,
        if (businessId != null)
          'businessAccount': {'id': businessId, 'role': role},
      });
    }
    if (request.url.path.endsWith('/auth/account')) {
      return http.Response('', 204);
    }
    if (status != 200) return json({'message': 'Denied'}, status);
    if (request.url.path.endsWith('/image')) {
      downloads++;
      return http.Response.bytes(photo, 200);
    }
    return json({'id': 1, 'imagePath': 'image.png'});
  });

  setUpAll(() async {
    final data = await rootBundle.load('assets/images/ekspersiz_logo.png');
    photo = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  });
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await TokenStorage.saveAccessToken('user-a');
    cache = InspectionImageCache();
    service = InspectionService(imageCache: cache);
    status = 200;
    downloads = 0;
    userId = 1;
    businessId = null;
    role = null;
  });
  tearDown(() => cache.dispose());

  test(
    'logout, new login, token replacement, clearAll and account deletion clear RAM',
    () async {
      await http.runWithClient(() async {
        await service.getInspectionImage(1);
        await const AuthService().logout();
        expect(cache.entryCount, 0);
        expect(await TokenStorage.getAccessToken(), isNull);
        await expectLater(service.getInspectionImage(1), throwsStateError);
        await TokenStorage.saveAccessToken('user-b');
        await service.getInspectionImage(1);
        expect(downloads, 2);
        await const AuthService().login(
          email: 'test@example.com',
          password: 'password',
        );
        expect(cache.entryCount, 0);
        await service.getInspectionImage(1);
        final oldScope = SessionManager.imageScope.value;
        await const AuthService().login(
          email: 'test@example.com',
          password: 'password',
        );
        expect(SessionManager.imageScope.value, isNot(same(oldScope)));
        expect(cache.entryCount, 0);
        await service.getInspectionImage(1);
        await TokenStorage.clearAll();
        expect(cache.entryCount, 0);
        await TokenStorage.saveAccessToken('user-b');
        await service.getInspectionImage(1);
        await const AuthService().deleteAccount();
        expect(cache.entryCount, 0);
        expect(await TokenStorage.getAccessToken(), isNull);
      }, client);
    },
  );

  for (final code in [401, 403]) {
    test(
      'real HTTP $code clears cached photos and preserves auth semantics',
      () async {
        await http.runWithClient(() async {
          await service.getInspectionImage(1);
          status = code;
          await expectLater(
            service.getInspectionImage(1),
            throwsA(
              isA<ApiException>().having(
                (e) => e.statusCode,
                'statusCode',
                code,
              ),
            ),
          );
          expect(cache.entryCount, 0);
          expect(
            await TokenStorage.getAccessToken(),
            code == 401 ? isNull : 'user-a',
          );
          expect(SessionManager.imagesAllowed, code != 401);
        }, client);
      },
    );
  }

  test('real connection failure never serves stale cached bytes', () async {
    await http.runWithClient(() => service.getInspectionImage(1), client);
    await http.runWithClient(() async {
      await expectLater(
        service.getInspectionImage(1),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 0),
        ),
      );
      expect(cache.entryCount, 0);
    }, () => MockClient((_) async => throw http.ClientException('offline')));
  });

  testWidgets('HTTP timeout propagates without serving a cached photo', (
    tester,
  ) async {
    await tester.runAsync(
      () => http.runWithClient(() => service.getInspectionImage(1), client),
    );
    await http.runWithClient(() async {
      final result = expectLater(
        service.getInspectionImage(1),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 408),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 31));
      await result;
      expect(cache.entryCount, 0);
    }, () => MockClient((_) => Completer<http.Response>().future));
  });

  test(
    'profile user, business and role changes rotate the opaque image scope',
    () async {
      await http.runWithClient(() async {
        await const AuthService().getCurrentUser();
        await service.getInspectionImage(1);
        final initial = SessionManager.imageScope.value;
        await const AuthService().getCurrentUser();
        expect(SessionManager.imageScope.value, same(initial));
        businessId = 10;
        role = 'MEMBER';
        await const AuthService().getCurrentUser();
        expect(cache.entryCount, 0);
        await service.getInspectionImage(1);
        role = 'OWNER';
        await const AuthService().getCurrentUser();
        expect(cache.entryCount, 0);
        await service.getInspectionImage(1);
        businessId = 11;
        await const AuthService().getCurrentUser();
        expect(cache.entryCount, 0);
        await service.getInspectionImage(1);
        userId = 2;
        await const AuthService().getCurrentUser();
        expect(cache.entryCount, 0);
      }, client);
    },
  );

  test(
    '403 from an obsolete request cannot reenable images after logout',
    () async {
      final gate = Completer<http.Response>();
      await http.runWithClient(() async {
        final request = service.getInspectionImage(1);
        await Future<void>.delayed(Duration.zero);
        await const AuthService().logout();
        gate.complete(json({'message': 'Denied'}, 403));
        await expectLater(request, throwsA(isA<ApiException>()));
        expect(SessionManager.imagesAllowed, isFalse);
        expect(cache.entryCount, 0);
      }, () => MockClient((_) => gate.future));
    },
  );
}
