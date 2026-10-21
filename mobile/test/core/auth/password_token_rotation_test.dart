import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/storage/token_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await TokenStorage.saveAccessToken('old-token');
  });

  test(
    'password change keeps this device signed in with rotated token',
    () async {
      await http.runWithClient(
        () async {
          await const ApiClient().post('/auth/change-password', body: {});
          expect(await TokenStorage.getAccessToken(), 'new-token');
        },
        () => MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer old-token');
          return http.Response(
            '',
            204,
            headers: {'authorization': 'Bearer new-token'},
          );
        }),
      );
    },
  );

  test('legacy 204 response keeps compatible session', () async {
    await http.runWithClient(() async {
      await const ApiClient().post('/auth/change-password', body: {});
      expect(await TokenStorage.getAccessToken(), 'old-token');
    }, () => MockClient((_) async => http.Response('', 204)));
  });

  test('failed password change cannot replace token', () async {
    await http.runWithClient(
      () async {
        await expectLater(
          const ApiClient().post('/auth/change-password', body: {}),
          throwsException,
        );
        expect(await TokenStorage.getAccessToken(), 'old-token');
      },
      () => MockClient(
        (_) async => http.Response(
          '{}',
          400,
          headers: {'authorization': 'Bearer attacker-token'},
        ),
      ),
    );
  });
}
