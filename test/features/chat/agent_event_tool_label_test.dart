import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/widgets/agent_event_widget.dart';

// Regression coverage for the duplicated sub-agent name in progress chips.
//
// A task_progress chip renders as `[icon] <subAgentLastTool>  <label>`.
// The wire label repeats the tool name in two ways:
//   1. the "<tool> · <description>" prefix the parser composes, and
//   2. inside the description itself, because workflow agents describe
//      themselves as "<Description>: <agent-label>" where the label is
//      the reported tool name.
// Case 2 shipped as `hunt:bundle-tasks-a Hunt: hunt:bundle-tasks-a`.
Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AgentEventWidget.stripToolName', () {
    test('strips the composed "<tool> · " prefix', () {
      expect(
        AgentEventWidget.stripToolName('Bash · wait for scan', 'Bash'),
        'wait for scan',
      );
    });

    test('strips a trailing occurrence and its separator', () {
      expect(
        AgentEventWidget.stripToolName(
          'Hunt: hunt:bundle-tasks-a',
          'hunt:bundle-tasks-a',
        ),
        'Hunt',
      );
    });

    test('strips every occurrence in a doubly-repeated legacy label', () {
      // Cached messages from before the parser fix carry both shapes.
      expect(
        AgentEventWidget.stripToolName(
          'hunt:bundle-tasks-a · Hunt: hunt:bundle-tasks-a',
          'hunt:bundle-tasks-a',
        ),
        'Hunt',
      );
    });

    test('returns empty when the label is only the tool name', () {
      expect(AgentEventWidget.stripToolName('Read', 'Read'), '');
    });

    test('leaves an unrelated label untouched', () {
      expect(
        AgentEventWidget.stripToolName('wait for scan', 'Bash'),
        'wait for scan',
      );
    });
  });

  group('AgentEventWidget — sub-agent chip', () {
    testWidgets('does not print the sub-agent name twice', (tester) async {
      await tester.pumpWidget(
        _app(
          const AgentEventWidget(
            event: <String, dynamic>{
              'type': 'message',
              'message': 'Hunt: hunt:bundle-tasks-a',
            },
            message: <String, dynamic>{
              'subAgentLastTool': 'hunt:bundle-tasks-a',
            },
          ),
        ),
      );

      expect(find.text('hunt:bundle-tasks-a'), findsOneWidget);
      expect(find.text('Hunt'), findsOneWidget);
    });
  });
}
