import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/ai_assistant/widgets/assistant_message_body.dart';

import '../../support/ui_test_app.dart';

const _answer = '''## Güvenli kontrol

**Aracı güvenli bir yere alın.** Uyarı sürüyorsa sürüşe devam etmeyin.

- Lastikleri soğukken kontrol edin.
- Üreticinin belirttiği değeri kullanın.

1. Kapı etiketine bakın.
2. [Kılavuzu](https://example.com/manual) kontrol edin.
''';

Iterable<TextSpan> _spans(InlineSpan span) sync* {
  if (span is TextSpan) {
    yield span;
    for (final child in span.children ?? <InlineSpan>[]) {
      yield* _spans(child);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(installOfflineTestFonts);

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Markdown is readable at 320px: $brightness, $scale', (
        tester,
      ) async {
        await setUiSize(tester, const Size(320, 640));
        await tester.pumpWidget(
          uiTestApp(
            brightness: brightness,
            textScale: scale,
            home: const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(18),
                child: AssistantMessageBody(text: _answer),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final texts = tester.widgetList<SelectableText>(
          find.byType(SelectableText),
        );
        final spans = texts.expand((text) => _spans(text.textSpan!)).toList();
        final rendered = texts
            .map((text) => text.textSpan!.toPlainText())
            .join('\n');
        expect(rendered, contains('Güvenli kontrol'));
        expect(rendered, contains('Aracı güvenli bir yere alın.'));
        expect(rendered, contains('sürüşe devam etmeyin.'));
        expect(rendered, isNot(contains('##')));
        expect(rendered, isNot(contains('**')));
        expect(rendered, isNot(contains('](')));
        expect(
          spans.any((span) => span.style?.fontWeight == FontWeight.bold),
          isTrue,
        );
        expect(spans.any((span) => span.recognizer != null), isTrue);
        expect(
          tester
              .widget<MarkdownBody>(find.byType(MarkdownBody))
              .styleSheet!
              .textScaler!
              .scale(14),
          14 * scale,
        );
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -400),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('remote images stay text and non-web links do not launch', (
    tester,
  ) async {
    await tester.pumpWidget(
      uiTestApp(
        home: const Scaffold(
          body: AssistantMessageBody(
            text:
                '![Şema](https://example.com/image.png)\n\n[Aç](file:///private/file)',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.text('Şema'), findsOneWidget);
    final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    markdown.onTapLink!('Aç', 'file:///private/file', '');
    markdown.onTapLink!('Aç', 'javascript:alert(1)', '');
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
