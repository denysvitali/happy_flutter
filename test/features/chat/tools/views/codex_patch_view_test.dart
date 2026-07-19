import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/tools/known_tools.dart';
import 'package:happy_flutter/features/chat/tools/tool_view.dart';
import 'package:happy_flutter/features/chat/tools/views/codex_patch_view.dart';

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

  group('CodexPatchView', () {
    testWidgets('renders apply_patch body by file', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CodexPatchView(
            tool: {
              'input': {
                'patch': '''
*** Begin Patch
*** Update File: lib/main.dart
@@
-final value = 1;
+final value = 2;
*** End Patch
''',
              },
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('1 file changed'), findsOneWidget);
      expect(_findRichTextContaining('lib/main.dart'), findsAtLeastNWidgets(1));
      expect(find.text('diff'), findsOneWidget);
      expect(_findRichTextContaining('-final value = 1;'), findsOneWidget);
      expect(_findRichTextContaining('+final value = 2;'), findsOneWidget);
    });

    testWidgets('renders patch text from nested Codex arguments', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CodexPatchView(
            tool: {
              'input': {
                'arguments': {
                  'body': '''
*** Begin Patch
*** Update File: lib/app.dart
@@
-const name = 'old';
+const name = 'new';
*** End Patch
''',
                },
              },
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('1 file changed'), findsOneWidget);
      expect(_findRichTextContaining('lib/app.dart'), findsAtLeastNWidgets(1));
      expect(_findRichTextContaining("-const name = 'old';"), findsOneWidget);
      expect(_findRichTextContaining("+const name = 'new';"), findsOneWidget);
    });

    testWidgets('falls back to raw Codex arguments when input is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CodexPatchView(
            tool: {
              'input': <String, dynamic>{},
              'content': {
                'arguments': {
                  'body': '''
*** Begin Patch
*** Update File: lib/cached.dart
@@
-final cached = false;
+final cached = true;
*** End Patch
''',
                },
              },
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('1 file changed'), findsOneWidget);
      expect(
        _findRichTextContaining('lib/cached.dart'),
        findsAtLeastNWidgets(1),
      );
      expect(_findRichTextContaining('-final cached = false;'), findsOneWidget);
      expect(_findRichTextContaining('+final cached = true;'), findsOneWidget);
    });

    testWidgets('renders structured Map changes without raw JSON', (
      tester,
    ) async {
      // Codex sometimes returns changes as a structured Map (not the
      // '*** Begin Patch' text). The view should still render the diff
      // text from the structured fields, never raw JSON.
      await tester.pumpWidget(
        _wrap(
          CodexPatchView(
            tool: {
              'input': {
                'changes': {
                  'lib/structured.dart': {
                    'add': {'content': 'const answer = 42;\n'},
                  },
                },
              },
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('1 file changed'), findsOneWidget);
      expect(_findRichTextContaining('const answer = 42;'), findsOneWidget);
      // No raw JSON braces/brackets should leak into the rendered output.
      expect(find.textContaining('{'), findsNothing);
      expect(find.textContaining('['), findsNothing);
    });

    testWidgets('recovers diff text from nested Map envelope', (tester) async {
      // Provider sometimes wraps the diff inside a nested Map (e.g. under
      // a 'diff' or 'patch' key whose value is itself a Map with the real
      // text). The view should still surface the diff text, not a JSON dump.
      await tester.pumpWidget(
        _wrap(
          CodexPatchView(
            tool: {
              'input': {
                'changes': {
                  'lib/nested.dart': {
                    'modify': {
                      'diff': {'patch': '@@\n-foo();\n+bar();\n'},
                    },
                  },
                },
              },
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('1 file changed'), findsOneWidget);
      expect(_findRichTextContaining('-foo();'), findsOneWidget);
      expect(_findRichTextContaining('+bar();'), findsOneWidget);
      expect(find.textContaining('{'), findsNothing);
    });

    testWidgets('renders kind-based structured changes', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CodexPatchView(
            tool: {
              'input': {
                'changes': {
                  'lib/kind.dart': {
                    'kind': 'update',
                    'diff': '@@\n-const value = 1;\n+const value = 2;\n',
                  },
                },
              },
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('1 file changed'), findsOneWidget);
      expect(_findRichTextContaining('-const value = 1;'), findsOneWidget);
      expect(_findRichTextContaining('+const value = 2;'), findsOneWidget);
    });

    testWidgets('renders list-shaped structured changes', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CodexPatchView(
            tool: {
              'input': {
                'changes': [
                  {
                    'path': 'lib/list.dart',
                    'operation': 'modify',
                    'patch':
                        '@@\n-final enabled = false;\n+final enabled = true;\n',
                  },
                ],
              },
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('1 file changed'), findsOneWidget);
      expect(
        _findRichTextContaining('-final enabled = false;'),
        findsOneWidget,
      );
      expect(_findRichTextContaining('+final enabled = true;'), findsOneWidget);
    });

    testWidgets('renders path-to-patch maps as editable file changes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CodexPatchView(
            tool: {
              'input': {
                'changes': {
                  'lib/first.dart': '@@\n-old value\n+new value\n',
                  'lib/second.dart': {
                    'updated': {'oldText': 'before', 'newText': 'after'},
                  },
                },
              },
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('2 files changed'), findsOneWidget);
      expect(_findRichTextContaining('first.dart'), findsAtLeastNWidgets(1));
      expect(_findRichTextContaining('second.dart'), findsAtLeastNWidgets(1));
      expect(_findRichTextContaining('-old value'), findsOneWidget);
      expect(_findRichTextContaining('+new value'), findsOneWidget);
      expect(_findRichTextContaining('-before'), findsOneWidget);
      expect(_findRichTextContaining('+after'), findsOneWidget);
    });
  });

  group('ToolView apply_patch', () {
    testWidgets('uses patch view instead of generic fallback', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ToolView(
            tool: {
              'name': 'apply_patch',
              'state': 'running',
              'input': '''
*** Begin Patch
*** Add File: lib/new_file.dart
+const answer = 42;
*** End Patch
''',
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
      expect(find.text('1 file changed'), findsOneWidget);
      expect(_findRichTextContaining('new_file.dart'), findsAtLeastNWidgets(1));
      expect(find.text('INPUT'), findsNothing);
    });

    testWidgets('uses the patch view for provider-prefixed apply_patch', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ToolView(
            tool: {
              'name': 'functions.apply_patch',
              'state': 'running',
              'input': '''
*** Begin Patch
*** Update File: lib/changed_file.dart
@@
-const value = 1;
+const value = 2;
*** End Patch
''',
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
      expect(find.text('1 file changed'), findsOneWidget);
      expect(
        _findRichTextContaining('changed_file.dart'),
        findsAtLeastNWidgets(1),
      );
      expect(find.text('INPUT'), findsNothing);
    });
  });

  group('KnownTools aliases', () {
    test('maps provider and agent aliases to canonical definitions', () {
      expect(
        KnownTools.titleFor('functions.apply_patch', {}, null),
        'Apply Changes',
      );
      expect(KnownTools.titleFor('file-edit', {}, null), 'Apply Changes');
      expect(KnownTools.titleFor('write', {}, null), 'Apply Changes');
      expect(KnownTools.titleFor('bash', {}, null), 'Terminal');
      expect(KnownTools.titleFor('grep', {}, null), 'Search Content');
      expect(KnownTools.titleFor('ls', {}, null), 'List Files');
      expect(KnownTools.titleFor('todo_list', {}, null), 'Todo List');
      // Grok Build ACP built-in names
      expect(KnownTools.titleFor('list_dir', {}, null), 'List Files');
      expect(KnownTools.titleFor('read_file', {}, null), 'Read File');
      expect(KnownTools.titleFor('run_terminal_command', {}, null), 'Terminal');
      expect(KnownTools.titleFor('search_replace', {}, null), 'Apply Changes');
      expect(KnownTools.titleFor('todo_write', {}, null), 'Todo List');
    });

    test('extracts patch subtitle from raw cached content', () {
      final definition = KnownTools.get('functions.apply_patch');
      final subtitle = definition?.extractSubtitle?.call({
        'input': <String, dynamic>{},
        'content': {
          'arguments': '''
*** Begin Patch
*** Update File: lib/cached.dart
@@
-final cached = false;
+final cached = true;
*** End Patch
''',
        },
      }, null);

      expect(subtitle, 'cached.dart');
    });
  });
}

Finder _findRichTextContaining(String text) {
  return find.byWidgetPredicate(
    (w) => w is RichText && w.text.toPlainText().contains(text),
  );
}
