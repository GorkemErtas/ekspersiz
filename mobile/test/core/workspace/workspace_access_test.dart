import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/workspace/workspace_service.dart';
import 'package:mobile/core/workspace/workspace_session.dart';
import 'package:mobile/features/auth/services/auth_service.dart';

Map<String, Object?> profile({
  String access = 'ACTIVE',
  String role = 'MEMBER',
}) => {
  'id': 1,
  'userId': 1,
  'fullName': 'Tester',
  'email': 'test@example.com',
  'subscriptionPlan': 'FREE',
  'accessToken': 'token',
  'tokenType': 'Bearer',
  'businessAccount': {
    'id': 7,
    'companyName': 'Company',
    'role': role,
    'workspaceAvailable': access == 'ACTIVE',
    'workspaceAccessStatus': access,
  },
};

http.Response reply(http.Request request, Object body, {int status = 200}) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {
        'content-type': 'application/json',
        if (request.headers['X-Workspace'] != null)
          'x-workspace': request.headers['X-Workspace']!,
      },
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    WorkspaceSession.clear();
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'token',
      'workspace:user:1': 'BUSINESS',
    });
  });
  tearDown(WorkspaceSession.clear);

  for (final role in ['OWNER', 'MEMBER']) {
    test(
      '$role keeps expired membership across profile refresh, restart and login without selecting Business',
      () async {
        final calls = <String>[];
        await http.runWithClient(
          () async {
            for (int refresh = 0; refresh < 3; refresh++) {
              final user = await const AuthService().getCurrentUser();
              expect(user.businessAccount!.id, 7);
              expect(user.businessAccount!.role, role);
              expect(WorkspaceSession.state.value!.businessId, 7);
              expect(WorkspaceSession.state.value!.businessAvailable, isFalse);
              expect(WorkspaceSession.state.value!.isBusiness, isFalse);
              await expectLater(
                const WorkspaceService().select(WorkspaceType.business),
                throwsStateError,
              );
            }
            WorkspaceSession.clear();
            await const AuthService().getCurrentUser();
            expect(WorkspaceSession.state.value!.isBusiness, isFalse);
            await const AuthService().login(
              email: 'test@example.com',
              password: 'password',
            );
            expect(WorkspaceSession.state.value!.businessId, 7);
            expect(WorkspaceSession.state.value!.isBusiness, isFalse);
            expect(
              calls.any(
                (call) =>
                    call.endsWith('/workspace') || call.contains('/billing'),
              ),
              isFalse,
            );
          },
          () => MockClient((request) async {
            calls.add(request.url.path);
            return reply(
              request,
              profile(access: 'SUBSCRIPTION_EXPIRED', role: role),
            );
          }),
        );
      },
    );
  }

  test(
    'renewal makes the same company available but retains the personal selection until server-authorized switch',
    () async {
      String access = 'SUBSCRIPTION_EXPIRED';
      int authorizations = 0;
      await http.runWithClient(
        () async {
          await const AuthService().getCurrentUser();
          access = 'ACTIVE';
          await const AuthService().getCurrentUser();
          expect(
            WorkspaceSession.state.value!.subscriptionPlan,
            'FREE',
          ); // Member's own plan is irrelevant.
          expect(WorkspaceSession.state.value!.businessAvailable, isTrue);
          expect(WorkspaceSession.state.value!.isBusiness, isFalse);
          await const WorkspaceService().select(WorkspaceType.business);
          expect(WorkspaceSession.state.value!.isBusiness, isTrue);
          expect(authorizations, 1);
        },
        () => MockClient((request) async {
          if (request.url.path.endsWith('/workspace')) {
            authorizations++;
            return reply(request, {
              'type': 'BUSINESS',
              'userId': 1,
              'businessId': 7,
            });
          }
          return reply(request, profile(access: access));
        }),
      );
    },
  );

  test(
    '403 followed by expired profile cannot restore access and a profile begun before the 403 is discarded',
    () async {
      final pending = Completer<http.Response>();
      final started = Completer<http.Request>();
      bool delayed = false;
      await http.runWithClient(
        () async {
          await const AuthService().getCurrentUser();
          await WorkspaceSession.select(WorkspaceType.personal);
          delayed = true;
          final oldProfile = const AuthService().getCurrentUser();
          final oldRequest = await started.future;
          await expectLater(
            const ApiClient(
              workspace: WorkspaceType.business,
            ).get('/workspace'),
            throwsA(isA<ApiException>()),
          );
          expect(WorkspaceSession.state.value!.businessId, 7);
          expect(WorkspaceSession.state.value!.businessAvailable, isFalse);
          final discarded = expectLater(
            oldProfile,
            throwsA(
              isA<ApiException>().having((e) => e.statusCode, 'status', 409),
            ),
          );
          pending.complete(reply(oldRequest, profile()));
          await discarded;
          delayed = false;
          await const AuthService().getCurrentUser();
          expect(WorkspaceSession.state.value!.businessAvailable, isFalse);
          expect(WorkspaceSession.state.value!.isBusiness, isFalse);
        },
        () => MockClient((request) async {
          if (request.url.path.endsWith('/workspace')) {
            return reply(request, {
              'validationErrors': {'code': 'WORKSPACE_UNAVAILABLE'},
              'message': 'Unavailable',
            }, status: 403);
          }
          if (delayed) {
            started.complete(request);
            return pending.future;
          }
          return reply(
            request,
            profile(
              access: started.isCompleted ? 'SUBSCRIPTION_EXPIRED' : 'ACTIVE',
            ),
          );
        }),
      );
    },
  );

  test(
    'older expired profile cannot overwrite a newer active profile even when the newer workspace metadata is unchanged',
    () async {
      final pending = Completer<http.Response>();
      final started = Completer<http.Request>();
      int requests = 0;
      await http.runWithClient(
        () async {
          await const AuthService().getCurrentUser();
          final old = const AuthService().getCurrentUser();
          final oldRequest = await started.future;
          await const AuthService().getCurrentUser();
          final discarded = expectLater(
            old,
            throwsA(
              isA<ApiException>().having((e) => e.statusCode, 'status', 409),
            ),
          );
          pending.complete(
            reply(oldRequest, profile(access: 'SUBSCRIPTION_EXPIRED')),
          );
          await discarded;
          expect(WorkspaceSession.state.value!.businessAvailable, isTrue);
        },
        () => MockClient((request) async {
          if (++requests == 2) {
            started.complete(request);
            return pending.future;
          }
          return reply(request, profile());
        }),
      );
    },
  );

  for (final initial in ['ACTIVE', 'SUBSCRIPTION_EXPIRED']) {
    test(
      'transient network/503 failures preserve the last confirmed $initial access',
      () async {
        int request = 0;
        await http.runWithClient(
          () async {
            await const AuthService().getCurrentUser();
            final current = WorkspaceSession.state.value;
            await expectLater(
              const AuthService().getCurrentUser(),
              throwsA(isA<ApiException>()),
            );
            expect(WorkspaceSession.state.value, same(current));
            await expectLater(
              const AuthService().getCurrentUser(),
              throwsA(isA<ApiException>()),
            );
            expect(WorkspaceSession.state.value, same(current));
          },
          () => MockClient((call) async {
            if (++request == 2) throw http.ClientException('offline');
            return reply(
              call,
              profile(access: initial),
              status: request == 3 ? 503 : 200,
            );
          }),
        );
      },
    );
  }

  test(
    'an older server returning membership without availability never grants Business',
    () async {
      await http.runWithClient(
        () async {
          await const AuthService().getCurrentUser();
          expect(WorkspaceSession.state.value!.businessId, 7);
          expect(WorkspaceSession.state.value!.businessAvailable, isFalse);
          expect(WorkspaceSession.state.value!.isBusiness, isFalse);
        },
        () => MockClient((request) async {
          final body = profile();
          (body['businessAccount'] as Map).remove('workspaceAvailable');
          (body['businessAccount'] as Map).remove('workspaceAccessStatus');
          return reply(request, body);
        }),
      );
    },
  );
}
