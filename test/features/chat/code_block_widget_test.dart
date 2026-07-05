import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/code_block_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CodeBlockWidget', () {
    testWidgets('renders line numbers and code', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CodeBlockWidget(
              code: 'void main() {}',
              language: 'dart',
              showLineNumbers: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('void main()'), findsOneWidget);
      // Line numbers are rendered as a single Text widget starting with '1\n'.
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.startsWith('1\n') ?? false),
        ),
        findsOneWidget,
      );
    });

    testWidgets('pins line numbers during horizontal scroll', (tester) async {
      // A very long line forces horizontal scrolling.
      final code = 'const x = "${"a" * 200}";\nline 2';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeBlockWidget(
              code: code,
              language: 'dart',
              showLineNumbers: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final lineNumberFinder = find.byWidgetPredicate(
        (w) => w is Text && (w.data?.startsWith('1\n') ?? false),
      );
      expect(lineNumberFinder, findsOneWidget);
      final before = tester.getTopLeft(lineNumberFinder);

      final horizontalScroll = find.byWidgetPredicate(
        (w) {
          return w is SingleChildScrollView &&
              w.scrollDirection == Axis.horizontal;
        },
      );
      expect(horizontalScroll, findsOneWidget);

      await tester.drag(horizontalScroll, const Offset(-100, 0));
      await tester.pumpAndSettle();

      final after = tester.getTopLeft(lineNumberFinder);
      // Line numbers should not have moved horizontally.
      expect(after.dx, equals(before.dx));
    });
  });
}
