import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/tools/views/ls_view.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LSView', () {
    testWidgets('renders path header', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LSView(
            tool: {
              'input': {'path': '/home/user/project'},
              'state': 'completed',
              'result': [],
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('/home/user/project'), findsOneWidget);
      expect(find.byIcon(Icons.folder_open_rounded), findsOneWidget);
    });

    testWidgets('renders directory and file counts', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LSView(
            tool: {
              'input': {'path': '/project'},
              'state': 'completed',
              'result': [
                {'name': 'src', 'isDirectory': true, 'isFile': false},
                {'name': 'lib', 'isDirectory': true, 'isFile': false},
                {
                  'name': 'main.dart',
                  'isDirectory': false,
                  'isFile': true,
                },
              ],
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('2 dirs'), findsOneWidget);
      expect(find.text('1 file'), findsOneWidget);
    });

    testWidgets('renders entry names', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LSView(
            tool: {
              'input': {'path': '/'},
              'state': 'completed',
              'result': [
                {'name': 'src', 'isDirectory': true, 'isFile': false},
                {
                  'name': 'readme.md',
                  'isDirectory': false,
                  'isFile': true,
                },
              ],
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('src'), findsOneWidget);
      expect(find.text('readme.md'), findsOneWidget);
    });

    testWidgets('renders folder icon for directories', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LSView(
            tool: {
              'input': {'path': '/'},
              'state': 'completed',
              'result': [
                {'name': 'docs', 'isDirectory': true, 'isFile': false},
              ],
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.folder_rounded), findsOneWidget);
    });

    testWidgets('renders file extension tags', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LSView(
            tool: {
              'input': {'path': '/'},
              'state': 'completed',
              'result': [
                {
                  'name': 'app.dart',
                  'isDirectory': false,
                  'isFile': true,
                },
                {
                  'name': 'data.json',
                  'isDirectory': false,
                  'isFile': true,
                },
              ],
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('dart'), findsOneWidget);
      expect(find.text('json'), findsOneWidget);
    });

    testWidgets('renders file size', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LSView(
            tool: {
              'input': {'path': '/'},
              'state': 'completed',
              'result': [
                {
                  'name': 'big.txt',
                  'isDirectory': false,
                  'isFile': true,
                  'size': 2048,
                },
              ],
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('2.0 KB'), findsOneWidget);
    });

    testWidgets('sorts directories first', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LSView(
            tool: {
              'input': {'path': '/'},
              'state': 'completed',
              'result': [
                {
                  'name': 'zebra.txt',
                  'isDirectory': false,
                  'isFile': true,
                },
                {
                  'name': 'alpha_dir',
                  'isDirectory': true,
                  'isFile': false,
                },
              ],
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find all SelectableText widgets to check order
      final texts = tester.widgetList<SelectableText>(
        find.byType(SelectableText),
      );
      final textContents = texts
          .map((t) {
            final span = t.textSpan;
            if (span != null) {
              return span.toPlainText();
            }
            return '';
          })
          .where((s) => s.isNotEmpty)
          .toList();

      // alpha_dir (directory) should come before zebra.txt (file)
      final alphaIdx = textContents.indexOf('alpha_dir');
      final zebraIdx = textContents.indexOf('zebra.txt');
      expect(alphaIdx, lessThan(zebraIdx));
    });

    testWidgets('shows "Show all" button for many entries',
        (tester) async {
      final entries = List.generate(
        35,
        (i) => {
          'name': 'file$i.txt',
          'isDirectory': false,
          'isFile': true,
        },
      );

      await tester.pumpWidget(
        _wrap(
          LSView(
            tool: {
              'input': {'path': '/'},
              'state': 'completed',
              'result': entries,
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Show all 35 items'), findsOneWidget);
    });

    testWidgets('renders permissions when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LSView(
            tool: {
              'input': {'path': '/'},
              'state': 'completed',
              'result': [
                {
                  'name': 'script.sh',
                  'isDirectory': false,
                  'isFile': true,
                  'permissions': 'rwxr-xr-x',
                },
              ],
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('rwxr-xr-x'), findsOneWidget);
    });

    testWidgets('handles string entries with trailing slash',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          LSView(
            tool: {
              'input': {'path': '/'},
              'state': 'completed',
              'result': ['src/', 'readme.txt'],
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('src/'), findsOneWidget);
      expect(find.text('readme.txt'), findsOneWidget);
    });
  });

  group('LSEntry', () {
    test('extension returns lowercase extension', () {
      final entry = LSEntry(
        name: 'App.DART',
        isDirectory: false,
        isFile: true,
      );
      expect(entry.extension, 'dart');
    });

    test('extension returns empty for directories', () {
      final entry = LSEntry(
        name: 'src.dart',
        isDirectory: true,
        isFile: false,
      );
      expect(entry.extension, '');
    });

    test('isSymlink is true when not directory and not file', () {
      final entry = LSEntry(
        name: 'link',
        isDirectory: false,
        isFile: false,
      );
      expect(entry.isSymlink, true);
    });

    test('isSymlink is false for regular files', () {
      final entry = LSEntry(
        name: 'file.txt',
        isDirectory: false,
        isFile: true,
      );
      expect(entry.isSymlink, false);
    });
  });
}
