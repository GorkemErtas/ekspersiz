import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/onboarding/screens/onboarding_screen.dart';

void main() {
  testWidgets(
    'real bundled fonts render both themes without network or mock assets',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      expect(
        manifest.listAssets(),
        containsAll([
          'assets/fonts/Inter-Regular.ttf',
          'assets/fonts/Inter-Medium.ttf',
        ]),
      );
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: OnboardingScreen(onFinished: () {}),
          ),
        );
        await tester.runAsync(() => GoogleFonts.pendingFonts());
        await tester.pumpAndSettle();
        expect(find.text('1 / 6'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
