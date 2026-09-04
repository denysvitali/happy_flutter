import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/code_block_widget.dart';

/// Finds the line-number gutter [Text] widget (horizontal-scroll mode).
Finder _lineNumbers() => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      w.textAlign == TextAlign.end &&
      w.style?.fontFamily == 'monospace',
);

/// Finds the number rendered for logical line [n] in wrapped mode.
Finder _wrappedNumber(int n) =>
    find.byKey(ValueKey<String>('code-line-number-$n'));

/// Finds the row rendered for logical line [n] in wrapped mode.
Finder _wrappedLine(int n) => find.byKey(ValueKey<String>('code-line-$n'));

Finder _verticalScrollViews() => find.byWidgetPredicate(
  (w) => w is SingleChildScrollView && w.scrollDirection == Axis.vertical,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(CodeBlockWrapPreference.resetForTest);
  tearDown(CodeBlockWrapPreference.resetForTest);

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
          CodeBlockWidget(code: code, language: 'dart', showLineNumbers: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(_lineNumbers(), findsOneWidget);
      final before = tester.getTopLeft(_lineNumbers());

      final horizontalScroll = find.byWidgetPredicate((w) {
        return w is SingleChildScrollView &&
            w.scrollDirection == Axis.horizontal;
      });
      expect(horizontalScroll, findsOneWidget);

      await tester.drag(horizontalScroll, const Offset(-100, 0));
      await tester.pumpAndSettle();

      final after = tester.getTopLeft(_lineNumbers());
      // Line numbers should not have moved horizontally.
      expect(after.dx, equals(before.dx));
    });

    testWidgets('opens a full-screen code reader', (tester) async {
      await tester.pumpWidget(
        wrap(const CodeBlockWidget(code: 'print("hello");', language: 'dart')),
      );

      await tester.tap(find.byTooltip('Open full screen'));
      await tester.pumpAndSettle();

      expect(find.byType(CodeBlockWidget), findsNWidgets(2));
      expect(find.byTooltip('Close'), findsOneWidget);
    });
  });

  group('CodeBlockWidget soft-wrap toggle', () {
    testWidgets('header toggle switches between scroll and wrap', (
      tester,
    ) async {
      final code = 'const x = "${"a" * 200}";\nline 2';
      await tester.pumpWidget(
        wrap(CodeBlockWidget(code: code, language: 'dart')),
      );
      await tester.pumpAndSettle();

      // Default: horizontal scrolling, single joined gutter.
      expect(find.byTooltip('Wrap long lines'), findsOneWidget);
      expect(_wrappedLine(1), findsNothing);

      await tester.tap(find.byTooltip('Wrap long lines'));
      await tester.pumpAndSettle();

      expect(CodeBlockWrapPreference.wrapLines, isTrue);
      expect(find.byTooltip('Scroll long lines'), findsOneWidget);
      expect(_wrappedLine(1), findsOneWidget);
      expect(_wrappedLine(2), findsOneWidget);
      // No horizontal scroll view survives in wrapped mode.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is SingleChildScrollView &&
              w.scrollDirection == Axis.horizontal,
        ),
        findsNothing,
      );

      await tester.tap(find.byTooltip('Scroll long lines'));
      await tester.pumpAndSettle();

      expect(CodeBlockWrapPreference.wrapLines, isFalse);
      expect(_wrappedLine(1), findsNothing);
    });

    testWidgets('preference is app-wide, not per block', (tester) async {
      await tester.pumpWidget(
        wrap(
          const Column(
            children: [
              CodeBlockWidget(code: 'a = 1;\nb = 2;', language: 'dart'),
              CodeBlockWidget(code: 'c = 3;\nd = 4;', language: 'dart'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Wrap long lines').first);
      await tester.pumpAndSettle();

      // Both blocks render wrapped rows after a single toggle.
      expect(_wrappedLine(1), findsNWidgets(2));
      expect(find.byTooltip('Scroll long lines'), findsNWidgets(2));
      expect(find.byTooltip('Wrap long lines'), findsNothing);
    });

    testWidgets('wrapped mode keeps one number per logical line, aligned '
        'with its first visual row', (tester) async {
      // Line 1 is long enough to wrap over several visual rows at the
      // 800x600 default test viewport.
      // Stay within the inline preview budget while wrapping the first line.
      final code = '${"averyLongToken " * 16}\nsecond();\nthird();';
      await tester.pumpWidget(
        wrap(CodeBlockWidget(code: code, language: 'dart', fontSize: 13)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Wrap long lines'));
      await tester.pumpAndSettle();

      // Exactly one number per logical line — a wrapped line is not
      // renumbered per visual row.
      expect(_wrappedNumber(1), findsOneWidget);
      expect(_wrappedNumber(2), findsOneWidget);
      expect(_wrappedNumber(3), findsOneWidget);
      expect(_wrappedNumber(4), findsNothing);

      // Line 1 really did wrap: its row is taller than one line height.
      final firstRowHeight = tester.getSize(_wrappedLine(1)).height;
      expect(firstRowHeight, greaterThan(13 * 1.5 * 2));

      // The number sits at the top of its logical line, i.e. aligned with
      // the first visual row rather than centred over the wrapped block.
      final numberTop = tester.getTopLeft(_wrappedNumber(1)).dy;
      final rowTop = tester.getTopLeft(_wrappedLine(1)).dy;
      expect((numberTop - rowTop).abs(), lessThan(1.0));

      // Line 2's number starts below the whole wrapped line 1.
      final rowBottom = tester.getBottomLeft(_wrappedLine(1)).dy;
      expect(
        tester.getTopLeft(_wrappedNumber(2)).dy,
        greaterThanOrEqualTo(rowBottom - 1.0),
      );
    });
  });

  group('CodeBlockWidget inline gesture safety', () {
    testWidgets('inline block never nests a vertical scrollable', (
      tester,
    ) async {
      final code = List.generate(60, (i) => 'line $i;').join('\n');
      await tester.pumpWidget(
        wrap(
          SingleChildScrollView(
            child: CodeBlockWidget(code: code, language: 'dart'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Only the parent list's scroll view exists.
      expect(_verticalScrollViews(), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('clipped inline block offers the full-screen reader', (
      tester,
    ) async {
      final code = List.generate(60, (i) => 'line $i;').join('\n');
      await tester.pumpWidget(
        wrap(
          SingleChildScrollView(
            child: CodeBlockWidget(code: code, language: 'dart'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 60 lines, 12 rendered inline → 48 hidden.
      expect(find.text('Show 48 more lines'), findsOneWidget);

      await tester.tap(find.text('Show 48 more lines'));
      await tester.pumpAndSettle();

      expect(find.byType(CodeBlockWidget), findsNWidgets(2));
      // The full-screen reader owns its viewport and may scroll vertically.
      expect(find.textContaining('line 59;'), findsOneWidget);
    });

    testWidgets('wrapped inline block is also clipped, not scrollable', (
      tester,
    ) async {
      final code = List.generate(60, (i) => 'line $i;').join('\n');
      await tester.pumpWidget(
        wrap(
          SingleChildScrollView(
            child: CodeBlockWidget(code: code, language: 'dart'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Wrap long lines'));
      await tester.pumpAndSettle();

      expect(_wrappedLine(12), findsOneWidget);
      expect(_wrappedLine(13), findsNothing);
      expect(_verticalScrollViews(), findsOneWidget);
    });
  });
}
