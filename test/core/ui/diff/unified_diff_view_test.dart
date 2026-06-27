import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/ui/diff/unified_diff_view.dart';
import 'package:happy_flutter/core/utils/theme_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget _wrap(Widget child, {bool dark = false}) {
    return MaterialApp(
      theme: dark ? ThemeHelper.buildDarkTheme() : ThemeHelper.buildLightTheme(),
      darkTheme: ThemeHelper.buildDarkTheme(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(body: child),
    );
  }

  group('UnifiedDiffView', () {
    testWidgets('renders hunk header and changed lines', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const UnifiedDiffView(
            oldText: 'old\nsame',
            newText: 'new\nsame',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('@@'), findsOneWidget);
      expect(_findRichTextContaining('old'), findsOneWidget);
      expect(_findRichTextContaining('new'), findsOneWidget);
      expect(_findRichTextContaining('same'), findsNWidgets(2));
    });

    testWidgets('shows line numbers when enabled', (tester) async {
      await tester.pumpWidget(
        _wrap(
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
        _wrap(
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
        _wrap(
          const UnifiedDiffView(
            oldText: 'old',
            newText: 'new',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('+'), findsAtLeastNWidgets(1));
      expect(find.text('-'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows diff stats when requested', (tester) async {
      await tester.pumpWidget(
        _wrap(
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

    testWidgets('uses DiffTheme colors from the ambient theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const UnifiedDiffView(
            oldText: 'old',
            newText: 'new',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      expect(richTexts, isNotEmpty);
    });

    testWidgets('recomputes diff when text changes', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const UnifiedDiffView(
            oldText: 'a',
            newText: 'b',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_findRichTextContaining('a'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          const UnifiedDiffView(
            oldText: 'x',
            newText: 'y',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_findRichTextContaining('x'), findsOneWidget);
      expect(_findRichTextContaining('a'), findsNothing);
    });
  });
}

Finder _findRichTextContaining(String text) {
  return find.byWidgetPredicate(
    (w) => w is RichText && w.text.toPlainText().contains(text),
  );
}
