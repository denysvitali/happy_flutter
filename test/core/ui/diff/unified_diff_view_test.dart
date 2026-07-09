import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/ui/diff/unified_diff_view.dart';
import 'package:happy_flutter/core/utils/theme_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child, {bool dark = false}) {
    return MaterialApp(
      theme: dark
          ? ThemeHelper.buildDarkTheme()
          : ThemeHelper.buildLightTheme(),
      darkTheme: ThemeHelper.buildDarkTheme(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(body: child),
    );
  }

  group('expandTabs', () {
    test('leaves plain text unchanged', () {
      expect(expandTabs('hello'), equals('hello'));
    });

    test('expands a leading tab to tab-size spaces', () {
      expect(expandTabs('\thello'), equals('    hello'));
    });

    test('honours tab stops mid-line', () {
      // "ab\t" starts at col 0; after "ab" col=2 → pad 2 spaces to col 4.
      expect(expandTabs('ab\tx'), equals('ab  x'));
    });

    test('expands multiple tabs independently', () {
      expect(expandTabs('\t\tx'), equals('        x'));
    });
  });

  group('UnifiedDiffView', () {
    testWidgets('renders hunk header and changed lines', (tester) async {
      await tester.pumpWidget(
        wrap(const UnifiedDiffView(oldText: 'old\nsame', newText: 'new\nsame')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('@@'), findsOneWidget);
      expect(_findRichTextContaining('old'), findsOneWidget);
      expect(_findRichTextContaining('new'), findsOneWidget);
      expect(_findRichTextContaining('same'), findsNWidgets(2));
    });

    testWidgets('shows line numbers when enabled', (tester) async {
      await tester.pumpWidget(
        wrap(
          const UnifiedDiffView(
            oldText: 'line1',
            newText: 'line1',
            showLineNumbers: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('  1'), findsOneWidget);
    });

    testWidgets('hides line numbers when disabled', (tester) async {
      await tester.pumpWidget(
        wrap(
          const UnifiedDiffView(
            oldText: 'line1',
            newText: 'line1',
            showLineNumbers: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('  1'), findsNothing);
    });

    testWidgets('shows plus/minus symbols', (tester) async {
      await tester.pumpWidget(
        wrap(const UnifiedDiffView(oldText: 'old', newText: 'new')),
      );
      await tester.pumpAndSettle();

      expect(find.text('+'), findsAtLeastNWidgets(1));
      expect(find.text('-'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows diff stats when requested', (tester) async {
      await tester.pumpWidget(
        wrap(
          const UnifiedDiffView(
            oldText: 'old',
            newText: 'new',
            showDiffStats: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('+1'), findsOneWidget);
      expect(find.text('-1'), findsOneWidget);
      expect(find.text('(2 changes)'), findsOneWidget);
    });

    testWidgets('uses DiffTheme colors from the ambient theme', (tester) async {
      await tester.pumpWidget(
        wrap(const UnifiedDiffView(oldText: 'old', newText: 'new')),
      );
      await tester.pumpAndSettle();

      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      expect(richTexts, isNotEmpty);
    });

    testWidgets('recomputes diff when text changes', (tester) async {
      await tester.pumpWidget(
        wrap(const UnifiedDiffView(oldText: 'a', newText: 'b')),
      );
      await tester.pumpAndSettle();

      expect(_findRichTextContaining('a'), findsOneWidget);

      await tester.pumpWidget(
        wrap(const UnifiedDiffView(oldText: 'x', newText: 'y')),
      );
      await tester.pumpAndSettle();

      expect(_findRichTextContaining('x'), findsOneWidget);
      expect(_findRichTextContaining('a'), findsNothing);
    });

    testWidgets('expands leading tabs so indentation aligns', (tester) async {
      await tester.pumpWidget(
        wrap(
          const UnifiedDiffView(
            // Single tab should expand to 4 spaces → 4 mid-dots.
            oldText: '\treturn 1;',
            newText: '\treturn 2;',
            showLineNumbers: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Leading spaces after tab-expand render as mid-dots (·).
      expect(_findRichTextContaining('····return 1;'), findsOneWidget);
      expect(_findRichTextContaining('····return 2;'), findsOneWidget);
      // Raw tab must not survive into the painted text.
      expect(_findRichTextContaining('\t'), findsNothing);
    });

    testWidgets('uses monospace on every content span including leading dots', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const UnifiedDiffView(
            oldText: '  indented',
            newText: '  indented',
            showLineNumbers: false,
            showPlusMinusSymbols: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      var sawLeadingDots = false;
      for (final rt in richTexts) {
        rt.text.visitChildren((span) {
          if (span is! TextSpan) return true;
          final data = span.text ?? '';
          if (data.contains('·')) {
            sawLeadingDots = true;
            expect(
              span.style?.fontFamily,
              equals('monospace'),
              reason: 'leading-dot span must be monospace',
            );
            expect(
              span.style?.fontSize,
              equals(AppFontSize.sm),
              reason: 'leading-dot span must match body font size',
            );
          }
          if (data.contains('indented')) {
            expect(span.style?.fontFamily, equals('monospace'));
            expect(span.style?.fontSize, equals(AppFontSize.sm));
          }
          return true;
        });
      }
      expect(
        sawLeadingDots,
        isTrue,
        reason: 'expected mid-dot leading whitespace visualization',
      );
    });

    testWidgets('defaults body font size to AppFontSize.sm', (tester) async {
      await tester.pumpWidget(
        wrap(
          const UnifiedDiffView(
            oldText: 'hello',
            newText: 'hello',
            showLineNumbers: false,
            showPlusMinusSymbols: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      var sawBody = false;
      for (final rt in richTexts) {
        rt.text.visitChildren((span) {
          if (span is! TextSpan) return true;
          if ((span.text ?? '').contains('hello')) {
            sawBody = true;
            expect(span.style?.fontSize, equals(AppFontSize.sm));
            expect(span.style?.fontFamily, equals('monospace'));
          }
          return true;
        });
      }
      expect(sawBody, isTrue);
    });
  });
}

Finder _findRichTextContaining(String text) {
  return find.byWidgetPredicate(
    (w) => w is RichText && w.text.toPlainText().contains(text),
  );
}
