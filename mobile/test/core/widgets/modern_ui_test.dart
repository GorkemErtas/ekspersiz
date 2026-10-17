import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/widgets/app_adaptive_columns.dart';
import 'package:mobile/core/widgets/app_card.dart';
import 'package:mobile/core/widgets/app_motion.dart';
import 'package:mobile/core/widgets/app_navigation_bar.dart';
import 'package:mobile/core/widgets/app_page_header.dart';
import 'package:mobile/core/widgets/app_section_header.dart';
import 'package:mobile/core/widgets/app_state_view.dart';
import 'package:mobile/core/widgets/app_status_badge.dart';
import 'package:mobile/core/widgets/primary_button.dart';
import 'package:mobile/core/widgets/section_title.dart';

import '../../support/ui_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(installOfflineTestFonts);

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('shared components at 320px, $brightness, text $scale', (
        tester,
      ) async {
        await setUiSize(tester, const Size(320, 640));
        var taps = 0;
        await tester.pumpWidget(
          uiTestApp(
            brightness: brightness,
            textScale: scale,
            home: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const AppPageHeader(
                    icon: Icons.directions_car,
                    title: 'Araçlar ve analizler',
                    subtitle:
                        'Araç bilgilerinizi ve analiz geçmişinizi buradan yönetin.',
                    badge: 'AI DESTEKLİ ANALİZ',
                  ),
                  SectionTitle(
                    title: 'Şirketin Son Analizi',
                    actionLabel: 'Tümünü görüntüle',
                    onActionPressed: () => taps++,
                  ),
                  AppCard(
                    child: AppSectionHeader(
                      icon: Icons.build,
                      title: 'Bakım ve hatırlatmalar',
                      subtitle: 'Yaklaşan işlemler',
                      trailing: TextButton(
                        onPressed: () => taps++,
                        child: const Text('Yeni kayıt'),
                      ),
                    ),
                  ),
                  const AppStatusBadge(
                    icon: Icons.check,
                    label: 'Analiz başarıyla tamamlandı',
                    color: AppTheme.primaryDark,
                  ),
                  PrimaryButton(
                    label: 'Tutanak Oluştur ve Görüntüle',
                    icon: Icons.assignment_outlined,
                    onPressed: () => taps++,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.byType(PrimaryButton), 200);
        await tester.ensureVisible(find.byType(PrimaryButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PrimaryButton));
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'navigation retains all destinations and selected semantics, $brightness',
      (tester) async {
        await setUiSize(tester, const Size(320, 640));
        var selected = 0;
        await tester.pumpWidget(
          uiTestApp(
            brightness: brightness,
            textScale: 2,
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                bottomNavigationBar: AppNavigationBar(
                  selectedIndex: selected,
                  onDestinationSelected: (value) =>
                      setState(() => selected = value),
                ),
              ),
            ),
          ),
        );
        for (var index = 0; index < 4; index++) {
          await tester.tap(find.byType(NavigationDestination).at(index));
          await tester.pumpAndSettle();
          expect(selected, index);
          final node = tester.getSemantics(
            find.byType(NavigationDestination).at(index),
          );
          expect(node.flagsCollection.isSelected, Tristate.isTrue);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'primary button blocks repeat actions while loading and keeps its label',
    (tester) async {
      var taps = 0;
      var loading = false;
      late StateSetter update;
      await tester.pumpWidget(
        uiTestApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Scaffold(
                body: Center(
                  child: PrimaryButton(
                    label: 'Kaydet',
                    isLoading: loading,
                    onPressed: () => taps++,
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Kaydet'));
      update(() => loading = true);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Kaydet'));
      expect(taps, 1);
      expect(find.text('Kaydet'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      update(() => loading = false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaydet'));
      expect(taps, 2);
    },
  );

  testWidgets(
    'reduced motion reveals delayed content immediately and removes scale motion',
    (tester) async {
      await tester.pumpWidget(
        uiTestApp(
          reduceMotion: true,
          home: Scaffold(
            body: AppFadeSlideIn(
              delay: const Duration(seconds: 5),
              child: AppPressScale(
                onTap: () {},
                child: const SizedBox(
                  width: 120,
                  height: 60,
                  child: Text('Aç'),
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<FadeTransition>(find.byType(FadeTransition).last)
            .opacity
            .value,
        1,
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Aç')),
      );
      await tester.pump();
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
      await gesture.up();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('interactive cards support keyboard activation', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      uiTestApp(
        home: Scaffold(
          body: AppCard(
            onTap: () => taps++,
            child: const Text('Araç detayları'),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('dashboard columns stack when text is enlarged', (tester) async {
    await setUiSize(tester, const Size(1024, 768));
    for (final scale in [1.0, 2.0]) {
      await tester.pumpWidget(
        uiTestApp(
          textScale: scale,
          home: const Scaffold(
            body: AppAdaptiveColumns(
              first: Text('Araç'),
              second: Text('Analiz'),
            ),
          ),
        ),
      );
      final first = tester.getTopLeft(find.text('Araç'));
      final second = tester.getTopLeft(find.text('Analiz'));
      if (scale == 1) {
        expect(first.dy, second.dy);
        expect(second.dx, greaterThan(first.dx));
      } else {
        expect(second.dy, greaterThan(first.dy));
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'error retry remains reachable in short landscape at large text',
    (tester) async {
      await setUiSize(tester, const Size(640, 320));
      var retries = 0;
      await tester.pumpWidget(
        uiTestApp(
          textScale: 2,
          home: Scaffold(
            body: AppStateView.error(
              message: 'Bağlantınızı kontrol ederek yeniden deneyin.',
              onActionPressed: () => retries++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Tekrar Dene'), 150);
      await tester.tap(find.text('Tekrar Dene'));
      expect(retries, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
