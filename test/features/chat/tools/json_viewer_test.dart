import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/tools/json_viewer.dart';

String _richTextContent(WidgetTester tester) {
  return tester
      .widgetList<RichText>(find.byType(RichText))
      .map((widget) => widget.text.toPlainText())
      .join('\n');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JsonTreeViewer', () {
    testWidgets('renders nested JSON-encoded strings as expandable JSON', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonTreeViewer(
              value: <String, dynamic>{
                'structured_content': <String, dynamic>{
                  'result':
                      '{"query":"archive session","results":[{"score":1}]}',
                },
              },
            ),
          ),
        ),
      );

      final content = _richTextContent(tester);
      expect(content, contains('"query"'));
      expect(content, contains('"results"'));
      expect(content, isNot(contains(r'{\"query\"')));
    });
  });

  group('SmartOutputContainer', () {
    testWidgets('provides horizontal scrolling for wide JSON output', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 120,
              child: SmartOutputContainer(
                content: <String, dynamic>{
                  'very_long_key_that_should_not_fit_without_scrolling':
                      'very_long_value_that_should_not_fit_without_scrolling',
                },
              ),
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        ),
        findsOneWidget,
      );
    });
  });
}
