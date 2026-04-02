import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/tools/views/glob_view.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GlobView', () {
    testWidgets('renders pattern badge', (tester) async {
      await tester.pumpWidget(
        _wrap(
          GlobView(
            tool: {
              'input': {'pattern': '*.dart'},
              'state': 'completed',
              'result': ['main.dart', 'utils.dart'],
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('glob'), findsOneWidget);
      expect(find.text('*.dart'), findsOneWidget);
    });

    testWidgets('renders file count', (tester) async {
      await tester.pumpWidget(
        _wrap(
          GlobView(
            tool: {
              'input': {'pattern': '*.ts'},
              'state': 'completed',
              'result': ['a.ts', 'b.ts', 'c.ts'],
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('3 files found'), findsOneWidget);
    });

    testWidgets('renders single file count correctly', (tester) async {
      await tester.pumpWidget(
        _wrap(
          GlobView(
            tool: {
              'input': {'pattern': 'README.md'},
              'state': 'completed',
              'result': ['README.md'],
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('1 file found'), findsOneWidget);
    });

    testWidgets('shows "No files found" for empty results',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          GlobView(
            tool: {
              'input': {'pattern': '*.xyz'},
              'state': 'completed',
              'result': <String>[],
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('No files found'), findsOneWidget);
    });

    testWidgets('renders file names', (tester) async {
      await tester.pumpWidget(
        _wrap(
          GlobView(
            tool: {
              'input': {'pattern': '*.dart'},
              'state': 'completed',
              'result': ['/lib/main.dart', '/lib/utils.dart'],
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('main.dart'), findsOneWidget);
      expect(find.text('utils.dart'), findsOneWidget);
    });

    testWidgets('shows file extension tags', (tester) async {
      await tester.pumpWidget(
        _wrap(
          GlobView(
            tool: {
              'input': {'pattern': '*'},
              'state': 'completed',
              'result': ['app.dart', 'config.json'],
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('dart'), findsOneWidget);
      expect(find.text('json'), findsOneWidget);
    });

    testWidgets('renders path chip when path is provided',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          GlobView(
            tool: {
              'input': {'pattern': '*.dart', 'path': '/lib'},
              'state': 'completed',
              'result': ['main.dart'],
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('/lib'), findsOneWidget);
    });

    testWidgets('shows "Show all" button for many results',
        (tester) async {
      final files = List.generate(15, (i) => 'file$i.dart');
      await tester.pumpWidget(
        _wrap(
          GlobView(
            tool: {
              'input': {'pattern': '*.dart'},
              'state': 'completed',
              'result': files,
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Show all 15 files'), findsOneWidget);
    });

    testWidgets('handles result as map with files key',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          GlobView(
            tool: {
              'input': {'pattern': '*.ts'},
              'state': 'completed',
              'result': {
                'files': ['a.ts', 'b.ts'],
              },
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('a.ts'), findsOneWidget);
      expect(find.text('b.ts'), findsOneWidget);
    });

    testWidgets('renders travel_explore icon in pattern badge',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          GlobView(
            tool: {
              'input': {'pattern': '*'},
              'state': 'completed',
              'result': <String>[],
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.travel_explore), findsOneWidget);
    });
  });

  group('GlobFile', () {
    test('displayName returns basename when set', () {
      final file = GlobFile(
        path: '/lib/main.dart',
        basename: 'main.dart',
      );
      expect(file.displayName, 'main.dart');
    });

    test('displayName falls back to path last segment', () {
      final file = GlobFile(path: '/lib/main.dart');
      expect(file.displayName, 'main.dart');
    });

    test('extension returns lowercase extension', () {
      final file = GlobFile(path: '/App.DART');
      expect(file.extension, 'dart');
    });

    test('extension returns empty for no dot', () {
      final file = GlobFile(path: '/Makefile');
      expect(file.extension, '');
    });
  });
}
