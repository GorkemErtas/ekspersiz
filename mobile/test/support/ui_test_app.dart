import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';

/// Exercises the real theme without HTTP. Font metrics use bundled Roboto,
/// so these are layout/interaction tests, not Inter typography golden tests.
Future<void> installOfflineTestFonts() async {
  GoogleFonts.config.allowRuntimeFetching = false;
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final entries = <String, Object>{
    for (final path in manifest.listAssets())
      path: [
        {'asset': path},
      ],
    for (final weight in [
      'Thin',
      'ExtraLight',
      'Light',
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
      'Black',
    ])
      'assets/fonts/Inter-$weight.ttf': [
        {'asset': 'assets/fonts/Inter-$weight.ttf'},
      ],
  };
  final manifestBytes = const StandardMessageCodec().encodeMessage(entries);
  final regular = File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync();
  final bold = File('assets/fonts/Roboto-Bold.ttf').readAsBytesSync();
  for (final family in ['Roboto', 'Ahem']) {
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.sublistView(regular)))
          ..addFont(Future.value(ByteData.sublistView(bold))))
        .load();
  }
  final icons = File(
    'build/unit_test_assets/fonts/MaterialIcons-Regular.otf',
  ).readAsBytesSync();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(Future.value(ByteData.sublistView(icons)))).load();
  rootBundle.evict('AssetManifest.bin');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
        final path = utf8.decode(
          message!.buffer.asUint8List(
            message.offsetInBytes,
            message.lengthInBytes,
          ),
        );
        if (path == 'AssetManifest.bin') return manifestBytes;
        if (path.startsWith('assets/fonts/Inter-')) {
          return ByteData.sublistView(
            path.contains('Bold') || path.contains('Black') ? bold : regular,
          );
        }
        final file = File(path);
        return file.existsSync()
            ? ByteData.sublistView(file.readAsBytesSync())
            : null;
      });
}

Widget uiTestApp({
  required Widget home,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool reduceMotion = false,
  double keyboardInset = 0,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: brightness == Brightness.dark
      ? AppTheme.darkTheme
      : AppTheme.lightTheme,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: reduceMotion,
      viewInsets: EdgeInsets.only(bottom: keyboardInset),
    ),
    child: child!,
  ),
  home: home,
);

Future<void> setUiSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
