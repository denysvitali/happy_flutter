import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/code_block_widget.dart';

/// Finds the line-number gutter [Text] widget.
Finder _lineNumbers() => find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.textAlign == TextAlign.end &&
          w.style?.fontFamily == 'monospace',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  group('CodeBlockWidget', () {
    testWidgets('renders line numbers and code', (tester) async {
      await tester.pumpWidget(
        wrap(
          const CodeBlockWidget(
            code: 'void main() {}',
            language: 'dart',
            showLineNumbers: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('void main()'), findsOneWidget);
      expect(_lineNumbers(), findsOneWidget);
    });

    testWidgets('pins line numbers during horizontal scroll', (tester) async {
      // A very long line forces horizontal scrolling.
      final code = 'const x = "${"a" * 200}";\nline 2';
      await tester.pumpWidget(
        wrap(
          CodeBlockWidget(
            code: code,
            language: 'dart',
            showLineNumbers: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_lineNumbers(), findsOneWidget);
      final before = tester.getTopLeft(_lineNumbers());

      final horizontalScroll = find.byWidgetPredicate(
        (w) {
          return w is SingleChildScrollView &&
              w.scrollDirection == Axis.horizontal;
        },
      );
      expect(horizontalScroll, findsOneWidget);

      await tester.drag(horizontalScroll, const Offset(-100, 0));
      await tester.pumpAndSettle();

      final after = tester.getTopLeft(_lineNumbers());
      // Line numbers should not have moved horizontally.
      expect(after.dx, equals(before.dx));
    });
  });
}
