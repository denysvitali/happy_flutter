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

      await tester.tap(_findRichTextContaining('main.dart'));
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

      await tester.tap(_findRichTextContaining('app.dart'));
      await tester.pumpAndSettle();

      expect(find.text('1 file changed'), findsOneWidget);
      expect(_findRichTextContaining('lib/app.dart'), findsAtLeastNWidgets(1));
      expect(_findRichTextContaining("-const name = 'old';"), findsOneWidget);
      expect(_findRichTextContaining("+const name = 'new';"), findsOneWidget);
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
    });
  });
}

Finder _findRichTextContaining(String text) {
  return find.byWidgetPredicate(
    (w) => w is RichText && w.text.toPlainText().contains(text),
  );
}
