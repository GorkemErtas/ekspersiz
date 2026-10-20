import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/ui_test_app.dart';

double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(installOfflineTestFonts);

  for (final brightness in Brightness.values) {
    testWidgets('button hierarchy and contrast: $brightness', (tester) async {
      await tester.pumpWidget(
        uiTestApp(
          brightness: brightness,
          home: Scaffold(
            body: Column(
              children: [
                FilledButton(onPressed: () {}, child: const Text('Primary')),
                FilledButton.tonal(
                  onPressed: () {},
                  child: const Text('Secondary'),
                ),
                OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
                TextButton(onPressed: () {}, child: const Text('Text')),
                const FilledButton(onPressed: null, child: Text('Disabled')),
                const OutlinedButton(
                  onPressed: null,
                  child: Text('Unavailable'),
                ),
                IconButton.filled(
                  onPressed: () {},
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Material materialFor(Finder control) => tester.widget<Material>(
        find.descendant(of: control, matching: find.byType(Material)).first,
      );
      final primary = materialFor(find.widgetWithText(FilledButton, 'Primary'));
      final secondary = materialFor(
        find.widgetWithText(FilledButton, 'Secondary'),
      );
      final outlined = materialFor(
        find.widgetWithText(OutlinedButton, 'Outlined'),
      );
      final disabled = materialFor(
        find.widgetWithText(FilledButton, 'Disabled'),
      );
      final scheme = Theme.of(
        tester.element(find.byType(Scaffold)),
      ).colorScheme;

      expect(primary.color, scheme.primary);
      expect(secondary.color, scheme.secondaryContainer);
      expect(primary.color, isNot(secondary.color));
      expect(disabled.color, isNot(primary.color));
      expect(
        _contrast(primary.color!, primary.textStyle!.color!),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(secondary.color!, secondary.textStyle!.color!),
        greaterThanOrEqualTo(4.5),
      );
      final border = (outlined.shape! as OutlinedBorder).side;
      expect(_contrast(border.color, outlined.color!), greaterThanOrEqualTo(3));
      final disabledBorder =
          (materialFor(
                    find.widgetWithText(OutlinedButton, 'Unavailable'),
                  ).shape!
                  as OutlinedBorder)
              .side;
      expect(disabledBorder.color, isNot(border.color));

      final iconColor = IconTheme.of(
        tester.element(find.byIcon(Icons.send)),
      ).color!;
      final iconMaterial = materialFor(find.byType(IconButton));
      expect(
        _contrast(iconColor, iconMaterial.color!),
        greaterThanOrEqualTo(4.5),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('dialog actions fit at 320px with large text: $brightness', (
      tester,
    ) async {
      await setUiSize(tester, const Size(320, 640));
      var confirmed = false;
      await tester.pumpWidget(
        uiTestApp(
          brightness: brightness,
          textScale: 2,
          home: Scaffold(
            body: AlertDialog(
              title: const Text('Değişiklikleri kaydet'),
              actions: [
                TextButton(onPressed: () {}, child: const Text('Vazgeç')),
                FilledButton(
                  onPressed: () => confirmed = true,
                  child: const Text('Kaydet'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaydet'));
      expect(confirmed, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
