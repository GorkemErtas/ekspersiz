import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/widgets/app_navigation_bar.dart';
import 'package:mobile/core/widgets/primary_button.dart';

import '../../support/ui_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(installOfflineTestFonts);

  for (final brightness in Brightness.values) {
    for (final scenario in [
      (width: 320.0, dpr: 1.0, scale: 2.0),
      (width: 390.0, dpr: 3.0, scale: 1.0),
      (width: 430.0, dpr: 2.0, scale: 1.5),
    ]) {
      testWidgets(
        'compact controls retain touch targets: $brightness $scenario',
        (tester) async {
          tester.view.devicePixelRatio = scenario.dpr;
          tester.view.physicalSize = Size(
            scenario.width * scenario.dpr,
            844 * scenario.dpr,
          );
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          await tester.pumpWidget(
            uiTestApp(
              brightness: brightness,
              textScale: scenario.scale,
              reduceMotion: true,
              home: Scaffold(
                appBar: AppBar(title: const Text('Araç ve hesap ayarları')),
                bottomNavigationBar: AppNavigationBar(
                  selectedIndex: 0,
                  onDestinationSelected: (_) {},
                ),
                body: ListView(
                  padding: const EdgeInsets.all(AppTheme.pageInset),
                  children: [
                    PrimaryButton(
                      label: 'Tutanak Oluştur ve Görüntüle',
                      onPressed: () {},
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () {},
                      child: const Text('Değişiklikleri Kaydet'),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('Daha sonra hatırlat'),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        tooltip: 'Menüyü aç',
                        onPressed: () {},
                        icon: const Icon(Icons.more_vert),
                      ),
                    ),
                    const TextField(
                      decoration: InputDecoration(labelText: 'Şehir ve ilçe'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: 1,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Araç bölgesi',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 1,
                          child: Text(
                            'Ön tampon ve çamurluk',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: (_) {},
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final control in [
            find.byType(FilledButton),
            find.byType(OutlinedButton),
            find.byType(TextButton),
            find.byType(IconButton),
          ]) {
            expect(
              tester.getSize(control.first).height,
              greaterThanOrEqualTo(48),
            );
            expect(
              tester.getSize(control.first).width,
              greaterThanOrEqualTo(48),
            );
          }
          final primaryHeight = tester
              .getSize(find.byType(FilledButton))
              .height;
          if (scenario.scale == 1) {
            expect(
              primaryHeight,
              lessThanOrEqualTo(52),
              reason: 'The normal CTA is compact',
            );
          } else if (scenario.scale == 2) {
            expect(
              primaryHeight,
              greaterThan(52),
              reason: 'Large text must grow the control',
            );
          }
          final theme = Theme.of(tester.element(find.byType(Scaffold)));
          expect(theme.textTheme.bodyLarge?.fontSize, 16);
          expect(theme.textTheme.bodyMedium?.fontSize, 14);
          expect(theme.textTheme.bodySmall?.fontSize, 12);
          expect(
            MediaQuery.textScalerOf(
              tester.element(find.byType(TextField)),
            ).scale(16),
            16 * scenario.scale,
          );
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        },
      );
    }
  }
}
