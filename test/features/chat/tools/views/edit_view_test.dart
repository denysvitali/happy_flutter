import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/tools/tool_view.dart';
import 'package:happy_flutter/features/chat/tools/views/edit_view.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EditView', () {
    testWidgets('renders Claude edit fields', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EditView(
            tool: {
              'input': {
                'file_path': '/src/app.dart',
                'old_string': 'final value = 1;',
                'new_string': 'final value = 2;',
              },
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(_findRichTextContaining('/src/app.dart'), findsOneWidget);
      expect(find.text('DIFF'), findsOneWidget);
      expect(find.text('-1'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
    });

    testWidgets('renders ACP file-edit fields', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EditView(
            tool: {
              'input': {
                'filePath': '/src/app.dart',
                'diff': '-old line\n+new line',
              },
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(_findRichTextContaining('/src/app.dart'), findsOneWidget);
      expect(find.text('DIFF'), findsOneWidget);
      expect(find.text('-1'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
    });
  });

  group('ToolView file-edit', () {
    testWidgets('uses the edit view instead of generic fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ToolView(
            tool: {
              'name': 'file-edit',
              'state': 'running',
              'input': {'filePath': '/src/app.dart', 'diff': '-before\n+after'},
            },
          ),
        ),
      );

      await tester.pump();
      // Tap the header to expand — running tools no longer auto-expand.
      await tester.tap(find.byType(ToolView));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Apply Changes'), findsOneWidget);
      expect(_findRichTextContaining('/src/app.dart'), findsAtLeastNWidgets(1));
      expect(find.text('DIFF'), findsOneWidget);
      expect(find.text('INPUT'), findsNothing);
    });
  });
}

Finder _findRichTextContaining(String text) {
  return find.byWidgetPredicate(
    (w) => w is RichText && w.text.toPlainText().contains(text),
  );
}
