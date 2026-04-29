import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/tools/tool_view.dart';
import 'package:happy_flutter/features/chat/tools/views/codex_patch_view.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
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
      expect(_findRichTextContaining('lib/main.dart'), findsOneWidget);
      expect(find.text('patch'), findsOneWidget);
      expect(_findRichTextContaining('-final value = 1;'), findsOneWidget);
      expect(_findRichTextContaining('+final value = 2;'), findsOneWidget);
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
  });
}

Finder _findRichTextContaining(String text) {
  return find.byWidgetPredicate(
    (w) => w is RichText && w.text.toPlainText().contains(text),
  );
}
