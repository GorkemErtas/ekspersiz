import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/models/onboarding_step.dart';
import 'package:mobile/features/onboarding/screens/onboarding_screen.dart';
import 'package:mobile/features/profile/screens/profile_screen.dart';

import '../../support/ui_test_app.dart';
import 'support/memory_onboarding_store.dart';
import 'support/guide_test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(installGuideTestFonts);

  testWidgets('swipe, next, back and start persist only on completion', (
    tester,
  ) async {
    final store = MemoryOnboardingStore();
    var finished = 0;
    await tester.pumpWidget(
      uiTestApp(
        home: OnboardingScreen(store: store, onFinished: () => finished++),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 / 6'), findsOneWidget);
    expect(find.text('Geri'), findsNothing);
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 6'), findsOneWidget);
    await tester.tap(find.text('Geri'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 6'), findsOneWidget);
    for (var i = 1; i < onboardingSteps.length; i++) {
      await tester.tap(find.text('İleri'));
      await tester.pumpAndSettle();
    }
    expect(store.writes, 0);
    expect(find.text('Başla'), findsOneWidget);
    await tester.tap(find.text('Başla'));
    await tester.pump();
    expect(store.completed, isTrue);
    expect(finished, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('skip awaits persistence and prevents duplicate completion', (
    tester,
  ) async {
    final pending = Completer<void>();
    final store = MemoryOnboardingStore()..beforeWrite = () => pending.future;
    var finished = 0;
    await tester.pumpWidget(
      uiTestApp(
        home: OnboardingScreen(store: store, onFinished: () => finished++),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atla'));
    await tester.pump();
    await tester.tap(find.text('Atla'));
    await tester.pump();
    expect(store.writes, 1);
    expect(finished, 0);
    pending.complete();
    await tester.pump();
    expect(store.completed, isTrue);
    expect(finished, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('closing mid-guide starts at page one without a marker', (
    tester,
  ) async {
    final store = MemoryOnboardingStore();
    Widget app() => uiTestApp(
      home: OnboardingScreen(store: store, onFinished: () {}),
    );
    await tester.pumpWidget(app());
    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('1 / 6'), findsOneWidget);
    expect(store.writes, 0);
    expect(store.completed, isFalse);
  });

  testWidgets('failed persistence stays on guide and can retry', (
    tester,
  ) async {
    final store = MemoryOnboardingStore()..failWrite = true;
    var finished = 0;
    await tester.pumpWidget(
      uiTestApp(
        home: OnboardingScreen(store: store, onFinished: () => finished++),
      ),
    );
    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();
    expect(
      find.text('Tercihin kaydedilemedi. Lütfen yeniden dene.'),
      findsOneWidget,
    );
    expect(finished, 0);
    store.failWrite = false;
    await tester.tap(find.text('Yeniden Dene'));
    await tester.pump();
    expect(finished, 1);
    expect(store.completed, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('system back goes to previous page without completing', (
    tester,
  ) async {
    final store = MemoryOnboardingStore();
    await tester.pumpWidget(
      uiTestApp(
        home: OnboardingScreen(store: store, onFinished: () {}),
      ),
    );
    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('1 / 6'), findsOneWidget);
    expect(store.completed, isFalse);
  });

  for (final exitAction in ['Kapat', 'Tamam', 'system back']) {
    testWidgets('profile replays offline and returns via $exitAction', (
      tester,
    ) async {
      await tester.pumpWidget(
        uiTestApp(
          home: const ProfileScreen(
            fullName: 'Test User',
            email: 'user@example.com',
            subscriptionPlan: 'FREE',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Uygulama Rehberi'), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uygulama Rehberi'));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      if (exitAction == 'Tamam') {
        for (var i = 1; i < onboardingSteps.length; i++) {
          await tester.tap(find.text('İleri'));
          await tester.pumpAndSettle();
        }
      }
      if (exitAction == 'system back') {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.text(exitAction));
      }
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reduced motion and screen reader progress are supported', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      uiTestApp(reduceMotion: true, home: OnboardingScreen(onFinished: () {})),
    );
    await tester.tap(find.text('İleri'));
    await tester.pump();
    expect(find.text('2 / 6'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Adım 2 / 6: İKİ FOTOĞRAF · AI ANALİZİ'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'guide controls have accessible labels, contrast and touch targets in $brightness',
      (tester) async {
        await setUiSize(tester, const Size(390, 844));
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          uiTestApp(
            brightness: brightness,
            home: OnboardingScreen(onFinished: () {}),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await tester.tap(find.text('İleri'));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        semantics.dispose();
      },
    );
  }

  for (final brightness in Brightness.values) {
    for (final scenario in [
      (size: const Size(320, 568), scale: 1.0),
      (size: const Size(320, 568), scale: 2.0),
      (size: const Size(320, 568), scale: 3.0),
      (size: const Size(390, 844), scale: 1.0),
      (size: const Size(844, 390), scale: 1.5),
      (size: const Size(1024, 768), scale: 2.0),
    ]) {
      testWidgets('all six pages fit $brightness $scenario', (tester) async {
        await setUiSize(tester, scenario.size);
        const previewKey = ValueKey('guide-preview');
        await tester.pumpWidget(
          RepaintBoundary(
            key: previewKey,
            child: uiTestApp(
              brightness: brightness,
              textScale: scenario.scale,
              home: OnboardingScreen(onFinished: () {}),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (var i = 0; i < onboardingSteps.length; i++) {
          expect(find.text('${i + 1} / 6'), findsOneWidget);
          final page = find.byKey(ValueKey('guide-page-$i'));
          final vertical = find.descendant(
            of: page,
            matching: find.byType(Scrollable),
          );
          await tester.scrollUntilVisible(
            find.text(onboardingSteps[i].hint),
            150,
            scrollable: vertical,
          );
          expect(
            find.text(onboardingSteps[i].hint).hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull, reason: 'page $i');
          if (const bool.fromEnvironment('UPDATE_ONBOARDING_PREVIEWS') &&
              scenario.size.width == 390) {
            await tester.drag(vertical, const Offset(0, 2000));
            await tester.pumpAndSettle();
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(previewKey),
            );
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 2);
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                'build/onboarding-preview/${brightness.name}-$i.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
          }
          if (i < onboardingSteps.length - 1) {
            await tester.tap(find.text('İleri'));
            await tester.pumpAndSettle();
          }
        }
      });
    }
  }
}
