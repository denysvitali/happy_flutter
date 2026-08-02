import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/tools/views/file_diff_view.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    // ToolViewCopyButton reads context.l10n.
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FileDiffView', () {
    testWidgets('renders path and line-count badges', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FileDiffView(
            oldText: 'old line',
            newText: 'new line',
            filePath: 'lib/greeter.dart',
            icon: Icons.edit_document,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_findRichTextContaining('lib/'), findsOneWidget);
      expect(_findRichTextContaining('greeter.dart'), findsOneWidget);
      expect(find.text('-1'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
    });

    testWidgets('badges count changed lines, not total text size', (
      tester,
    ) async {
      // 4-line texts sharing 3 unchanged lines: exactly 1 removed and
      // 2 added lines. Total-size counting would show -4 +5.
      await tester.pumpWidget(
        _wrap(
          const FileDiffView(
            oldText: 'a\nb\nc\nd',
            newText: 'a\nb2\nc\nd\ne',
            filePath: 'lib/greeter.dart',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('-1'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      expect(find.text('-4'), findsNothing);
      expect(find.text('+5'), findsNothing);
    });

    testWidgets('shows diff inline when below collapse threshold', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const FileDiffView(
            oldText: 'old',
            newText: 'new',
            collapseThreshold: 2,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_findRichTextContaining('old'), findsAtLeastNWidgets(1));
      expect(_findRichTextContaining('new'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Show diff'), findsNothing);
    });

    testWidgets('hides diff behind toggle when above threshold', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const FileDiffView(
            oldText: 'line1\nline2',
            newText: 'line1\nline2',
            collapseThreshold: 2,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 4 lines total -> above threshold, content hidden.
      expect(_findRichTextContaining('line1'), findsNothing);
      expect(find.textContaining('Show diff'), findsOneWidget);

      await tester.tap(find.textContaining('Show diff'));
      await tester.pumpAndSettle();

      expect(_findRichTextContaining('line1'), findsWidgets);
      expect(find.text('Hide diff'), findsOneWidget);
    });

    testWidgets('copy button is present when rawCopyText is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const FileDiffView(
            oldText: 'a',
            newText: 'b',
            rawCopyText: 'raw diff',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('path tap callback is invoked', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          FileDiffView(
            oldText: 'a',
            newText: 'b',
            filePath: 'lib/main.dart',
            onPathTap: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(_findRichTextContaining('main.dart'));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  group('FileDiffCard', () {
    testWidgets('renders numbered header and diff body', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FileDiffCard(
            number: 3,
            oldText: 'old',
            newText: 'new',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
      expect(find.text('Edit 3'), findsOneWidget);
      expect(_findRichTextContaining('old'), findsAtLeastNWidgets(1));
      expect(_findRichTextContaining('new'), findsAtLeastNWidgets(1));
    });

    testWidgets('toggle collapses and expands diff body', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FileDiffCard(
            number: 1,
            oldText: 'old',
            newText: 'new',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_findRichTextContaining('old'), findsAtLeastNWidgets(1));

      await tester.tap(find.byIcon(Icons.expand_less));
      await tester.pumpAndSettle();

      expect(_findRichTextContaining('old'), findsNothing);

      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      expect(_findRichTextContaining('old'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows replace-all chip when requested', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FileDiffCard(
            number: 1,
            oldText: 'old',
            newText: 'new',
            replaceAll: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('replace all'), findsOneWidget);
    });
  });
}

Finder _findRichTextContaining(String text) {
  return find.byWidgetPredicate(
    (w) => w is RichText && w.text.toPlainText().contains(text),
  );
}
