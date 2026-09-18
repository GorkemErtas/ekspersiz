import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/localization/app_locale_controller.dart';
import 'package:mobile/features/profile/screens/profile_screen.dart';

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await AppLocaleController.instance.initialize();
  });

  tearDown(() async {
    await AppLocaleController.instance.setLanguage('tr');
  });

  test('Turkish is the default and language selection is persisted', () async {
    final controller = AppLocaleController.instance;

    expect(controller.locale, const Locale('tr'));
    expect(controller.translate('Free'), 'Ücretsiz');

    await controller.setLanguage('en');

    expect(controller.translate('Araçlar'), 'Vehicles');
    expect(
      await const FlutterSecureStorage().read(key: 'preferred_language'),
      'en',
    );
  });

  testWidgets('profile language selector updates visible interface text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppLocaleController.instance;

    await tester.pumpWidget(
      AnimatedBuilder(
        animation: controller,
        builder: (context, _) => MaterialApp(
          locale: controller.locale,
          home: const ProfileScreen(
            fullName: 'Test User',
            email: 'user@example.com',
            subscriptionPlan: 'FREE',
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Dil'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });
}
