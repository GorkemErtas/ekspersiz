import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/auth/session_manager.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/storage/token_storage.dart';
import 'package:mobile/core/workspace/workspace_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    WorkspaceSession.clear();
    FlutterSecureStorage.setMockInitialValues({'access_token': 'token'});
    SessionManager.invalidateImages(allowImages: true);
  });
  tearDown(WorkspaceSession.clear);

  Future<void> member({int id = 1}) => WorkspaceSession.initialize(
    userId: id,
    businessId: 7,
    companyName: 'Company',
    role: 'MEMBER',
  );
  http.Response response(
    http.Request request,
    Object body, {
    int status = 200,
  }) => http.Response(
    jsonEncode(body),
    status,
    headers: {
      'content-type': 'application/json',
      if (request.headers['X-Workspace'] != null)
        'x-workspace': request.headers['X-Workspace']!,
    },
  );

  test(
    'preference is user bound, survives restart and is corrected after removal',
    () async {
      await member();
      expect(WorkspaceSession.state.value!.isBusiness, isTrue);
      await WorkspaceSession.select(WorkspaceType.personal);
      WorkspaceSession.clear();
      await member();
      expect(WorkspaceSession.state.value!.isBusiness, isFalse);
      WorkspaceSession.clear();
      await member(id: 2);
      expect(WorkspaceSession.state.value!.isBusiness, isTrue);
      await WorkspaceSession.initialize(userId: 2);
      expect(WorkspaceSession.state.value!.type, WorkspaceType.personal);
      expect(WorkspaceSession.state.value!.businessId, isNull);
      WorkspaceSession.clear();
      await member(id: 2);
      expect(WorkspaceSession.state.value!.type, WorkspaceType.personal);
    },
  );

  test(
    'a workspace change rotates image scope and invalidates old request snapshots',
    () async {
      await member();
      final image = SessionManager.imageScope.value;
      final snapshot = WorkspaceSession.capture();
      await WorkspaceSession.select(WorkspaceType.personal);
      expect(SessionManager.imageScope.value, isNot(same(image)));
      expect(
        () => WorkspaceSession.check(snapshot),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test(
    'JSON, binary and multipart requests carry the same explicit workspace',
    () async {
      await member();
      final methods = <String>[];
      await http.runWithClient(
        () async {
          const api = ApiClient();
          await api.get('/vehicles');
          await api.post('/inspections', body: {'vehicleId': 1});
          await api.put('/vehicles/1', body: {'mileage': 1000});
          await api.delete('/vehicles/1');
          await api.getBytes('/inspections/1/image');
          await api.postMultipart(
            '/inspections/1/image',
            fileBytes: [1, 2],
            filename: 'photo.jpg',
          );
        },
        () => MockClient((request) async {
          expect(request.headers['X-Workspace'], 'BUSINESS');
          expect(request.headers['Authorization'], 'Bearer token');
          methods.add(request.method);
          return response(request, {});
        }),
      );
      expect(methods, ['GET', 'POST', 'PUT', 'DELETE', 'GET', 'POST']);
    },
  );

  test('old backend without workspace acknowledgment fails closed', () async {
    await member();
    await http.runWithClient(() async {
      await expectLater(
        const ApiClient().get('/vehicles'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 503)),
      );
      await expectLater(
        const ApiClient().getBytes('/inspections/1/image'),
        throwsA(isA<ApiException>()),
      );
    }, () => MockClient((_) async => http.Response('[]', 200)));
  });

  test('a late company response cannot reach the personal workspace', () async {
    await member();
    final gate = Completer<http.Response>();
    final started = Completer<http.Request>();
    await http.runWithClient(
      () async {
        final future = const ApiClient().get('/inspections');
        final request = await started.future;
        expect(request.headers['X-Workspace'], 'BUSINESS');
        await WorkspaceSession.select(WorkspaceType.personal);
        final rejected = expectLater(
          future,
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 409),
          ),
        );
        gate.complete(
          response(request, [
            {'id': 99},
          ]),
        );
        await rejected;
      },
      () => MockClient((request) {
        started.complete(request);
        return gate.future;
      }),
    );
  });

  test('obsolete 401 cannot log out the next authenticated user', () async {
    await member();
    final gate = Completer<http.Response>();
    final started = Completer<void>();
    await http.runWithClient(
      () async {
        final future = const ApiClient().get('/vehicles');
        await started.future;
        await TokenStorage.deleteAccessToken();
        await TokenStorage.saveAccessToken('next-token');
        await member(id: 2);
        final rejected = expectLater(future, throwsA(isA<ApiException>()));
        gate.complete(http.Response('{}', 401));
        await rejected;
        expect(await TokenStorage.getAccessToken(), 'next-token');
        expect(WorkspaceSession.state.value!.userId, 2);
      },
      () => MockClient((request) {
        started.complete();
        return gate.future;
      }),
    );
  });

  test(
    'revocation response selects personal without deleting the session',
    () async {
      await member();
      await http.runWithClient(
        () async {
          await expectLater(
            const ApiClient().get('/vehicles'),
            throwsA(isA<ApiException>()),
          );
          expect(WorkspaceSession.state.value!.type, WorkspaceType.personal);
          expect(WorkspaceSession.state.value!.businessId, isNull);
          expect(await TokenStorage.getAccessToken(), 'token');
        },
        () => MockClient(
          (request) async => response(request, {
            'message': 'Removed',
            'validationErrors': {'code': 'WORKSPACE_UNAVAILABLE'},
          }, status: 403),
        ),
      );
    },
  );

  test(
    'nonmember cannot select a company and logout clears workspace state',
    () async {
      await WorkspaceSession.initialize(userId: 1);
      await expectLater(
        WorkspaceSession.select(WorkspaceType.business),
        throwsStateError,
      );
      await TokenStorage.deleteAccessToken();
      expect(WorkspaceSession.state.value, isNull);
      expect(SessionManager.imagesAllowed, isFalse);
    },
  );
}
