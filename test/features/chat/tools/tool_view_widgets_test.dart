import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/tools/tool_view_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CollapsibleOutput', () {
    testWidgets('does not throw when disposed before measuring', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CollapsibleOutput(toolId: 'tool-1', child: Text('content')),
        ),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('measures laid-out content and shows expand control', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CollapsibleOutput(
              toolId: 'tool-1',
              child: Column(
                children: List<Widget>.generate(
                  20,
                  (index) => SizedBox(height: 20, child: Text('line $index')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Show more'), findsOneWidget);
    });
  });
}
