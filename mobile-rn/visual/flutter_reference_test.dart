// Run from mobile/: flutter test --no-pub ../mobile-rn/visual/flutter_reference_test.dart
// References render the real Flutter screens with real Inter fonts, entirely offline.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/widgets/app_background.dart';
import 'package:mobile/features/auth/screens/login_screen.dart';
import 'package:mobile/features/auth/screens/register_screen.dart';
import 'package:mobile/features/auth/screens/forgot_password_screen.dart';
import 'package:mobile/features/auth/screens/email_verification_screen.dart';

const variants = {
  'Thin': '100Thin',
  'ExtraLight': '200ExtraLight',
  'Light': '300Light',
  'Regular': '400Regular',
  'Medium': '500Medium',
  'SemiBold': '600SemiBold',
  'Bold': '700Bold',
  'ExtraBold': '800ExtraBold',
  'Black': '900Black',
};
Future<void> installInter() async {
  GoogleFonts.config.allowRuntimeFetching = false;
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final entries = <String, Object>{
    for (final path in manifest.listAssets())
      path: [
        {'asset': path},
      ],
    for (final weight in variants.keys)
      'assets/fonts/Inter-$weight.ttf': [
        {'asset': 'assets/fonts/Inter-$weight.ttf'},
      ],
  };
  final manifestBytes = const StandardMessageCodec().encodeMessage(entries);
  final icons = File(
    'build/unit_test_assets/fonts/MaterialIcons-Regular.otf',
  ).readAsBytesSync();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(Future.value(ByteData.sublistView(icons)))).load();
  rootBundle.evict('AssetManifest.bin');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
        final asset = utf8.decode(
          message!.buffer.asUint8List(
            message.offsetInBytes,
            message.lengthInBytes,
          ),
        );
        if (asset == 'AssetManifest.bin') return manifestBytes;
        if (asset.startsWith('assets/fonts/Inter-')) {
          final weight = asset.split('Inter-').last.split('.').first;
          // ThemeData's base text theme requests Regular/Medium. CopyWith changes
          // weight without changing the GoogleFonts family, preserving Flutter's
          // synthetic weight behavior. Never substitute a different Inter version.
          final file = File('assets/fonts/Inter-$weight.ttf');
          return ByteData.sublistView(file.readAsBytesSync());
        }
        final file = File(asset);
        return file.existsSync()
            ? ByteData.sublistView(file.readAsBytesSync())
            : null;
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(installInter);
  const viewports = [
    ('compact', Size(320, 640), 2.0),
    ('phone', Size(390, 844), 1.0),
    ('large', Size(430, 932), 1.5),
    ('landscape', Size(844, 390), 1.5),
    ('tablet', Size(1024, 768), 1.0),
  ];
  for (final mode in Brightness.values) {
    for (final screen in [
      'login',
      'register',
      'forgot-password',
      'verify-email',
    ]) {
      for (final viewport in viewports) {
        testWidgets('$screen ${mode.name} ${viewport.$1} Inter', (
          tester,
        ) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = viewport.$2;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final key = GlobalKey();
          final Widget home = switch (screen) {
            'register' => const RegisterScreen(),
            'forgot-password' => const ForgotPasswordScreen(),
            'verify-email' => const EmailVerificationScreen(
              email: 'deniz@example.com',
            ),
            _ => const LoginScreen(),
          };
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: mode == Brightness.dark
                    ? AppTheme.darkTheme
                    : AppTheme.lightTheme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(viewport.$3),
                    disableAnimations: true,
                  ),
                  child: AppBackground(child: child!),
                ),
                home: home,
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(
            () => precacheImage(
              const AssetImage('assets/images/ekspersiz_logo.png'),
              key.currentContext!,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final directory = Directory(
                '../mobile-rn/visual-artifacts/flutter',
              )..createSync(recursive: true);
              File(
                '${directory.path}/$screen-${mode.name}-${viewport.$1}.png',
              ).writeAsBytesSync(bytes!.buffer.asUint8List());
            } finally {
              image.dispose();
            }
          });
        });
      }
    }
  }
}
