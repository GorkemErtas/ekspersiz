import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/storage/token_storage.dart';
import 'package:mobile/features/auth/services/auth_service.dart';
import 'package:mobile/features/onboarding/data/onboarding_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late OnboardingStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ekspersiz-onboarding-');
    store = OnboardingStore(directoryProvider: () async => directory);
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() async => directory.delete(recursive: true));

  test('new installation is incomplete until persisted', () async {
    expect(await store.hasCompleted(), isFalse);
    await store.complete();
    final restarted = OnboardingStore(directoryProvider: () async => directory);
    expect(await restarted.hasCompleted(), isTrue);
    await restarted.complete();
    expect(await restarted.hasCompleted(), isTrue);
  });

  test(
    'abandoning the guide and interrupted writes do not complete it',
    () async {
      await File(
        '${directory.path}/onboarding_completed.pending',
      ).writeAsString('com');
      expect(await store.hasCompleted(), isFalse);
      await store.complete();
      expect(await store.hasCompleted(), isTrue);
    },
  );

  test('corrupt completion marker can be repaired', () async {
    await File('${directory.path}/onboarding_completed').writeAsString('');
    expect(await store.hasCompleted(), isFalse);
    await store.complete();
    expect(await store.hasCompleted(), isTrue);
  });

  test(
    'logout, token cleanup and switching accounts preserve installation state',
    () async {
      await store.complete();
      await TokenStorage.saveAccessToken('account-a');
      await const AuthService().logout();
      expect(await store.hasCompleted(), isTrue);
      await TokenStorage.clearAll();
      expect(await store.hasCompleted(), isTrue);
      await TokenStorage.saveAccessToken('account-b');
      expect(await store.hasCompleted(), isTrue);
      expect(await TokenStorage.getAccessToken(), 'account-b');
    },
  );

  test('a separate installation starts fresh', () async {
    await store.complete();
    final newInstall = OnboardingStore(
      directoryProvider: () async => Directory('${directory.path}/new-install'),
    );
    expect(await newInstall.hasCompleted(), isFalse);
  });

  test(
    'read failure offers the guide; write failure remains retryable',
    () async {
      var unavailable = true;
      final unreliable = OnboardingStore(
        directoryProvider: () async {
          if (unavailable) throw PlatformException(code: 'STORAGE_UNAVAILABLE');
          return directory;
        },
      );
      expect(await unreliable.hasCompleted(), isFalse);
      await expectLater(
        unreliable.complete(),
        throwsA(isA<PlatformException>()),
      );
      unavailable = false;
      expect(await unreliable.hasCompleted(), isFalse);
      await unreliable.complete();
      expect(await unreliable.hasCompleted(), isTrue);
    },
  );
}
