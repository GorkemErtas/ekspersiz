import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/widgets/app_background.dart';

import '../../support/ui_test_app.dart';

void main() {
  setUpAll(installOfflineTestFonts);

  for (final brightness in Brightness.values) {
    for (final size in [
      const Size(320, 640),
      const Size(390, 844),
      const Size(430, 932),
      const Size(844, 390),
      const Size(1024, 768),
    ]) {
      testWidgets('studio surface contrast and coverage: $brightness, $size', (
        tester,
      ) async {
        await setUiSize(tester, size);
        final capture = GlobalKey();
        final theme = brightness == Brightness.dark
            ? AppTheme.darkTheme
            : AppTheme.lightTheme;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            builder: (_, child) => RepaintBoundary(
              key: capture,
              child: AppBackground(child: child!),
            ),
            // Also exercise the same nested scaffold structure as MainShell.
            home: const Scaffold(body: Scaffold()),
          ),
        );
        await tester.pumpAndSettle();
        final boundary =
            capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = (await tester.runAsync(() => boundary.toImage()))!;
        final bytes = (await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
        ))!;
        final colors = <Color>{};
        for (var row = 0; row < 11; row++) {
          for (var col = 0; col < 11; col++) {
            final x = ((image.width - 1) * col / 10).round();
            final y = ((image.height - 1) * row / 10).round();
            final index = (y * image.width + x) * 4;
            final color = Color.fromARGB(
              bytes.getUint8(index + 3),
              bytes.getUint8(index),
              bytes.getUint8(index + 1),
              bytes.getUint8(index + 2),
            );
            expect(color.a, 1, reason: 'opaque viewport at $x, $y');
            colors.add(color);
            for (final text in [
              theme.colorScheme.onSurface,
              theme.colorScheme.onSurfaceVariant,
            ]) {
              final luminances = [
                text.computeLuminance(),
                color.computeLuminance(),
              ]..sort();
              final contrast =
                  (luminances.last + .05) / (luminances.first + .05);
              expect(contrast, greaterThanOrEqualTo(4.5));
            }
          }
        }
        // Ensures the real nested pages expose the artwork, not a flat fill.
        expect(colors.length, greaterThan(12));
        image.dispose();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('background stays fixed while scrolling and opening keyboard', (
    tester,
  ) async {
    await setUiSize(tester, const Size(390, 844));
    var taps = 0;
    Widget app(double keyboardInset) => uiTestApp(
      keyboardInset: keyboardInset,
      home: Scaffold(
        body: ListView(
          children: [
            TextButton(onPressed: () => taps++, child: const Text('Action')),
            const SizedBox(height: 2000),
          ],
        ),
      ),
    );
    await tester.pumpWidget(app(0));
    await tester.pumpAndSettle();
    final artwork = find
        .descendant(
          of: find.byType(AppBackground),
          matching: find.byType(CustomPaint),
        )
        .first;
    final painter = tester.widget<CustomPaint>(artwork).painter!;
    final originalSize = tester.getSize(artwork);
    await tester.tap(find.text('Action'));
    expect(taps, 1);
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.widget<CustomPaint>(artwork).painter, same(painter));
    await tester.pumpWidget(app(300));
    await tester.pumpAndSettle();
    expect(tester.getSize(artwork), originalSize);
    expect(
      tester.widget<CustomPaint>(artwork).painter!.shouldRepaint(painter),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('new routes and modal barriers stay above the shared surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      uiTestApp(
        reduceMotion: true,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    appBar: AppBar(title: const Text('Detail')),
                    body: TextButton(
                      child: const Text('Open dialog'),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) =>
                            const AlertDialog(content: Text('Dialog content')),
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('Open page'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open page'));
    await tester.pumpAndSettle();
    expect(find.byType(AppBackground), findsOneWidget);
    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    expect(find.text('Dialog content'), findsOneWidget);
    expect(find.byType(AppBackground), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Dialog content'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Open page'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
