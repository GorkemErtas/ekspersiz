import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';

/// Use the actual bundled Inter assets for guide layout and preview coverage.
Future<void> installGuideTestFonts() async {
  GoogleFonts.config.allowRuntimeFetching = false;
  for (final family in ['Roboto', 'Ahem']) {
    await (FontLoader(family)
          ..addFont(
            Future.value(
              ByteData.sublistView(
                File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync(),
              ),
            ),
          )
          ..addFont(
            Future.value(
              ByteData.sublistView(
                File('assets/fonts/Roboto-Bold.ttf').readAsBytesSync(),
              ),
            ),
          ))
        .load();
  }
  await (FontLoader('MaterialIcons')..addFont(
        Future.value(
          ByteData.sublistView(
            File(
              'build/unit_test_assets/fonts/MaterialIcons-Regular.otf',
            ).readAsBytesSync(),
          ),
        ),
      ))
      .load();
  AppTheme.lightTheme;
  AppTheme.darkTheme;
  await GoogleFonts.pendingFonts();
}
