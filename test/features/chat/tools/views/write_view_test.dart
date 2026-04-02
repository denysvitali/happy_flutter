import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/tools/views/write_view.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WriteView', () {
    testWidgets('renders file path', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WriteView(
            tool: {
              'input': {
                'file_path': '/src/new_file.dart',
                'content': 'void main() {}',
              },
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      // Path is rendered via RichText with TextSpans
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('new_file.dart'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders Created badge', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WriteView(
            tool: {
              'input': {
                'path': '/test.txt',
                'content': 'hello',
              },
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Created'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('renders line count info chip', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WriteView(
            tool: {
              'input': {
                'path': '/test.txt',
                'content': 'line1\nline2\nline3',
              },
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      // '3 lines' appears in both the info chip and code header
      expect(find.text('3 lines'), findsNWidgets(2));
    });

    testWidgets('renders size info chip', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WriteView(
            tool: {
              'input': {
                'path': '/test.txt',
                'content': 'Hello',
              },
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('5B'), findsOneWidget);
    });

    testWidgets('renders content section', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WriteView(
            tool: {
              'input': {
                'path': '/test.txt',
                'content': 'test content',
              },
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('CONTENT'), findsOneWidget);
      expect(find.text('test content'), findsOneWidget);
    });

    testWidgets('renders language hint from extension', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WriteView(
            tool: {
              'input': {
                'path': '/app.dart',
                'content': 'code',
              },
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Dart'), findsOneWidget);
    });

    testWidgets('shows "Show full content" for long files',
        (tester) async {
      final longContent =
          List.generate(20, (i) => 'line $i').join('\n');
      await tester.pumpWidget(
        _wrap(
          WriteView(
            tool: {
              'input': {
                'path': '/long.txt',
                'content': longContent,
              },
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('Show full content'), findsOneWidget);
    });

    testWidgets('does not show toggle for short content',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          WriteView(
            tool: {
              'input': {
                'path': '/short.txt',
                'content': 'short',
              },
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('Show full content'), findsNothing);
    });

    testWidgets('renders line numbers', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WriteView(
            tool: {
              'input': {
                'path': '/test.txt',
                'content': 'first\nsecond',
              },
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('uses path key as fallback for file_path',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          WriteView(
            tool: {
              'input': {
                'path': '/via/path.txt',
                'content': 'test',
              },
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      // Path is rendered via RichText with TextSpans
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('via/path.txt'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders content lines count header', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WriteView(
            tool: {
              'input': {
                'path': '/app.py',
                'content': 'x = 1',
              },
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Python'), findsOneWidget);
    });
  });
}
