import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/widgets/agent_event_widget.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('AgentEventWidget task lifecycle marker', () {
    testWidgets('task_started chip is labelled and shows a start icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AgentEventWidget(
            event: {'type': 'message', 'message': 'Locate the panel module'},
            message: {
              'taskEvent': true,
              'taskPhase': 'task_started',
              'taskType': 'local_bash',
            },
          ),
        ),
      );

      expect(find.text('Task started'), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);
      expect(find.text('Locate the panel module'), findsOneWidget);
    });

    testWidgets('task_progress chip reads as running', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AgentEventWidget(
            event: {'type': 'message', 'message': 'Still grepping'},
            message: {'taskEvent': true, 'taskPhase': 'task_progress'},
          ),
        ),
      );

      expect(find.text('Task running'), findsOneWidget);
      expect(find.byIcon(Icons.autorenew_rounded), findsOneWidget);
    });

    testWidgets('non-task agent events keep the plain centered label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AgentEventWidget(
            event: {'type': 'message', 'message': 'Approaching rate limit'},
          ),
        ),
      );

      expect(find.text('Task started'), findsNothing);
      expect(find.text('Task running'), findsNothing);
      expect(find.text('Approaching rate limit'), findsOneWidget);
    });

    testWidgets('keeps Reading intact when last tool is Read', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const path =
          'Reading ~/.claude/projects/-home-workspace-git-fw-analyzer/ '
          '2150fa82-9.jsonl';
      await tester.pumpWidget(
        _wrap(
          const AgentEventWidget(
            event: {'type': 'message', 'message': path},
            message: {
              'taskEvent': true,
              'taskPhase': 'task_progress',
              'subAgentLastTool': 'Read',
            },
          ),
        ),
      );

      expect(find.text('Task running'), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
      expect(find.textContaining('Reading'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^ing\b')), findsNothing);

      final title = tester.widget<Text>(find.textContaining('Reading'));
      expect(title.maxLines, 2);
      expect(title.overflow, TextOverflow.ellipsis);
    });
  });
}
