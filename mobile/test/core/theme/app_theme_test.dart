import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/theme/app_theme_controller.dart';
import 'package:mobile/core/widgets/theme_toggle_button.dart';

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

  testWidgets('global theme button toggles between dark and light themes', (
    tester,
  ) async {
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
          home: Scaffold(
            appBar: AppBar(
              actions: [ThemeToggleButton()],
            ),
            body: SizedBox.expand(),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.dark,
    );

    await tester.tap(find.byType(ThemeToggleButton));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.light,
    );
  });
}
