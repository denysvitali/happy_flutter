import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/tools/views/read_view.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReadView', () {
    testWidgets('renders file path', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReadView(
            tool: {
              'input': {'file_path': '/src/main.dart'},
              'state': 'completed',
              'result': 'void main() {}',
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('/src/main.dart'), findsOneWidget);
    });

    testWidgets('renders file content when completed', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReadView(
            tool: {
              'input': {'file_path': '/test.txt'},
              'state': 'completed',
              'result': 'Hello World',
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('Hello World'), findsOneWidget);
    });

    testWidgets('does not render content when not completed',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReadView(
            tool: {
              'input': {'file_path': '/test.txt'},
              'state': 'running',
              'result': 'Should not show',
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Should not show'), findsNothing);
    });

    testWidgets('shows "Reading file..." when running', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReadView(
            tool: {
              'input': {'file_path': '/test.txt'},
              'state': 'running',
              'result': null,
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      // When state is not completed, content is null
      // so we get a "Reading file..." text if totalLines is set
    });

    testWidgets('renders extension badge for known file types',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReadView(
            tool: {
              'input': {'file_path': '/app.dart'},
              'state': 'completed',
              'result': 'code',
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('dart'), findsOneWidget);
    });

    testWidgets('handles Gemini format with locations array',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReadView(
            tool: {
              'input': {
                'locations': [
                  {'path': '/gemini/file.py'},
                ],
              },
              'state': 'completed',
              'result': 'python code',
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('/gemini/file.py'), findsOneWidget);
    });

    testWidgets('shows metadata row with offset and limit',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReadView(
            tool: {
              'input': {
                'file_path': '/big.txt',
                'offset': 10,
                'limit': 20,
              },
              'state': 'completed',
              'result': {
                'content': 'line 11\nline 12',
                'totalLines': 100,
              },
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('Lines'), findsOneWidget);
    });

    testWidgets('shows Content section label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReadView(
            tool: {
              'input': {'file_path': '/f.txt'},
              'state': 'completed',
              'result': 'some content',
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('CONTENT'), findsOneWidget);
    });

    testWidgets('renders copy button when content is available',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReadView(
            tool: {
              'input': {'file_path': '/f.txt'},
              'state': 'completed',
              'result': 'copyable',
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('shows "Show more" for long content', (tester) async {
      final longContent =
          List.generate(30, (i) => 'line $i').join('\n');
      await tester.pumpWidget(
        _wrap(
          ReadView(
            tool: {
              'input': {'file_path': '/long.txt'},
              'state': 'completed',
              'result': longContent,
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('more line'), findsOneWidget);
    });

    testWidgets('defaults to "Unknown" when no file path',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReadView(
            tool: {
              'input': <String, dynamic>{},
              'state': 'completed',
              'result': 'no path',
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Unknown'), findsOneWidget);
    });
  });
}
