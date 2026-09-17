import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/theme/app_theme_controller.dart';
import 'package:mobile/features/profile/screens/profile_screen.dart';

void main() {
  test('dark is default and the selected mode is stored locally', () async {
    FlutterSecureStorage.setMockInitialValues({});
    await AppThemeController.instance.initialize();

    expect(AppThemeController.instance.themeMode, ThemeMode.dark);
    expect(AppTheme.backgroundColor, const Color(0xFF08070B));

    await AppThemeController.instance.setDarkMode(false);
    expect(
      await const FlutterSecureStorage().read(key: 'preferred_theme'),
      'light',
    );
    await AppThemeController.instance.setDarkMode(true);
  });

  testWidgets('profile switch animates between dark and light themes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppThemeController.instance;
    await controller.setDarkMode(true);
    addTearDown(() => controller.setDarkMode(true));

    await tester.pumpWidget(
      AnimatedBuilder(
        animation: controller,
        builder: (context, _) => MaterialApp(
          theme: ThemeData.light(useMaterial3: true),
          darkTheme: ThemeData.dark(useMaterial3: true),
          themeMode: controller.themeMode,
          home: const ProfileScreen(
            fullName: 'Test User',
            email: 'user@example.com',
            subscriptionPlan: 'FREE',
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Görünüm'),
      180,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Koyu tema'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(ProfileScreen))).brightness,
      Brightness.dark,
    );

    await tester.tap(find.text('Koyu tema'));
    await tester.pumpAndSettle();

    expect(find.text('Açık tema'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(ProfileScreen))).brightness,
      Brightness.light,
    );
  });
}
