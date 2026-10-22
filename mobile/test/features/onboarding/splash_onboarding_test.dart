import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/storage/token_storage.dart';
import 'package:mobile/core/update/app_update_service.dart';
import 'package:mobile/features/auth/models/user_profile.dart';
import 'package:mobile/features/auth/screens/login_screen.dart';
import 'package:mobile/features/auth/screens/register_screen.dart';
import 'package:mobile/features/auth/screens/splash_screen.dart';
import 'package:mobile/features/auth/services/auth_service.dart';
import 'package:mobile/features/home/screens/main_shell.dart';
import 'package:mobile/features/onboarding/screens/onboarding_screen.dart';

import '../../support/ui_mock_api.dart';
import '../../support/ui_test_app.dart';
import 'support/memory_onboarding_store.dart';
import 'support/guide_test_fonts.dart';

class _UpdateService extends AppUpdateService {
  AppUpdateStatus status = AppUpdateStatus.none;
  Future<void>? pending;
  int checks = 0;
  int immediateUpdates = 0;

  @override
  Future<AppUpdateStatus> checkForUpdate() async {
    checks++;
    await pending;
    return status;
  }

  @override
  Future<bool> performImmediateUpdate() async {
    immediateUpdates++;
    status = AppUpdateStatus.none;
    return true;
  }
}

class _AuthService extends AuthService {
  int calls = 0;
  Object? error;

  @override
  Future<UserProfile> getCurrentUser() async {
    calls++;
    if (error != null) throw error!;
    return const UserProfile(
      id: 1,
      fullName: 'Test User',
      email: 'user@example.com',
      subscriptionPlan: 'FREE',
    );
  }
}

// Splash deliberately has an indeterminate progress indicator, including behind
// its error dialogs. Advance frames without waiting for that animation to settle.
Future<void> _advance(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(installGuideTestFonts);
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets(
    'version check precedes guide, then login and registration stay available',
    (tester) async {
      final versionCheck = Completer<void>();
      final update = _UpdateService()..pending = versionCheck.future;
      final store = MemoryOnboardingStore();
      final auth = _AuthService();
      await tester.pumpWidget(
        uiTestApp(
          home: SplashScreen(
            appUpdateService: update,
            onboardingStore: store,
            authService: auth,
          ),
        ),
      );
      await _advance(tester);
      expect(store.reads, 0);
      expect(find.byType(OnboardingScreen), findsNothing);
      versionCheck.complete();
      await _advance(tester);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(auth.calls, 0);
      await tester.tap(find.text('Atla'));
      await _advance(tester);
      expect(store.completed, isTrue);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Google ile Devam Et'), findsOneWidget);
      await tester.ensureVisible(find.text('Yeni Hesap Oluştur'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yeni Hesap Oluştur'));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    },
  );

  testWidgets(
    'mandatory update cannot be dismissed or skipped through the guide',
    (tester) async {
      final update = _UpdateService()
        ..status = const AppUpdateStatus(
          updateRequired: true,
          playUpdateAvailable: true,
          immediateUpdateAllowed: true,
        );
      final store = MemoryOnboardingStore();
      final auth = _AuthService();
      await tester.pumpWidget(
        uiTestApp(
          home: SplashScreen(
            appUpdateService: update,
            onboardingStore: store,
            authService: auth,
          ),
        ),
      );
      await _advance(tester);
      await tester.binding.handlePopRoute();
      await _advance(tester);
      expect(find.text('Güncelleme Gerekli'), findsOneWidget);
      expect(store.reads, 0);
      expect(auth.calls, 0);
      expect(find.byType(OnboardingScreen), findsNothing);
      await tester.tap(find.text('Güncelle'));
      await _advance(tester);
      expect(update.immediateUpdates, 1);
      expect(update.checks, 2);
      expect(find.byType(OnboardingScreen), findsOneWidget);
    },
  );

  testWidgets(
    'completed installation returns directly to login on repeated launches',
    (tester) async {
      final store = MemoryOnboardingStore(completed: true);
      for (var launch = 0; launch < 2; launch++) {
        await tester.pumpWidget(
          uiTestApp(
            home: SplashScreen(
              onboardingStore: store,
              appUpdateService: _UpdateService(),
            ),
          ),
        );
        await _advance(tester);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(OnboardingScreen), findsNothing);
        await tester.pumpWidget(const SizedBox());
      }
      expect(store.writes, 0);
    },
  );

  testWidgets('interrupted first launch shows the guide again on restart', (
    tester,
  ) async {
    final store = MemoryOnboardingStore();
    Widget launch() => uiTestApp(
      home: SplashScreen(
        onboardingStore: store,
        appUpdateService: _UpdateService(),
      ),
    );
    await tester.pumpWidget(launch());
    await _advance(tester);
    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(launch());
    await _advance(tester);
    expect(find.text('1 / 6'), findsOneWidget);
    expect(store.completed, isFalse);
  });

  for (final completed in [false, true]) {
    testWidgets(
      'restored account reaches MainShell, initially completed=$completed',
      (tester) async {
        await TokenStorage.saveAccessToken('existing-account');
        final store = MemoryOnboardingStore(completed: completed);
        final auth = _AuthService();
        await http.runWithClient(() async {
          await tester.pumpWidget(
            uiTestApp(
              home: SplashScreen(
                onboardingStore: store,
                authService: auth,
                appUpdateService: _UpdateService(),
              ),
            ),
          );
          await _advance(tester);
          if (!completed) {
            expect(auth.calls, 0);
            expect(find.byType(MainShell), findsNothing);
            for (var i = 1; i < 6; i++) {
              await tester.tap(find.text('İleri'));
              await tester.pumpAndSettle();
            }
            await tester.tap(find.text('Başla'));
            await _advance(tester);
          }
          expect(find.byType(MainShell), findsOneWidget);
          expect(find.byType(OnboardingScreen), findsNothing);
          expect(auth.calls, 1);
          expect(await TokenStorage.getAccessToken(), 'existing-account');
          await tester.pumpWidget(const SizedBox());
        }, uiMockClient);
      },
    );
  }

  testWidgets(
    'expired session still clears token and routes to login without repeating guide',
    (tester) async {
      await TokenStorage.saveAccessToken('expired');
      final store = MemoryOnboardingStore(completed: true);
      final auth = _AuthService()
        ..error = const ApiException(message: 'Expired', statusCode: 401);
      await tester.pumpWidget(
        uiTestApp(
          home: SplashScreen(
            onboardingStore: store,
            authService: auth,
            appUpdateService: _UpdateService(),
          ),
        ),
      );
      await _advance(tester);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(await TokenStorage.hasAccessToken(), isFalse);
      expect(store.completed, isTrue);
    },
  );

  testWidgets(
    'offline fresh launch can finish; offline session retains existing retry flow',
    (tester) async {
      final store = MemoryOnboardingStore();
      // The real update service's non-Android path and all guide assets require no network.
      await tester.pumpWidget(
        uiTestApp(home: SplashScreen(onboardingStore: store)),
      );
      await _advance(tester);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      await tester.tap(find.text('Atla'));
      await _advance(tester);
      expect(find.byType(LoginScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());

      await TokenStorage.saveAccessToken('offline-account');
      final auth = _AuthService()..error = TimeoutException('Offline');
      await tester.pumpWidget(
        uiTestApp(
          home: SplashScreen(
            onboardingStore: store,
            authService: auth,
            appUpdateService: _UpdateService(),
          ),
        ),
      );
      await _advance(tester);
      expect(find.text('Bağlantı Hatası'), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(await TokenStorage.getAccessToken(), 'offline-account');
      await tester.tap(find.text('Tekrar Dene'));
      await _advance(tester);
      expect(auth.calls, 2);
      await tester.tap(find.text('Giriş Yap'));
      await _advance(tester);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(store.completed, isTrue);
    },
  );
}
