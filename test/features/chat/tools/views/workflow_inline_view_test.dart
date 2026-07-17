import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/tools/views/workflow_inline_view.dart';

void main() {
  group('WorkflowInlineView', () {
    testWidgets('renders nothing when children are empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WorkflowInlineView(children: []),
          ),
        ),
      );
      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.text('Read'), findsNothing);
    });

    testWidgets('renders phases and agents from latest progress snapshot',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkflowInlineView(
              children: [
                {
                  'kind': 'agent-event',
                  'workflowProgress': [
                    {
                      'type': 'workflow_phase',
                      'index': 1,
                      'title': 'Read',
                    },
                    {
                      'type': 'workflow_phase',
                      'index': 2,
                      'title': 'Report',
                    },
                    {
                      'type': 'workflow_agent',
                      'agentId': 'a1',
                      'label': 'read-go-mod',
                      'phaseIndex': 1,
                      'phaseTitle': 'Read',
                      'model': 'claude-sonnet-4-6',
                      'state': 'start',
                    },
                  ],
                },
              ],
            ),
          ),
        ),
      );

      expect(find.text('Read'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);
      expect(find.text('Read · read-go-mod'), findsOneWidget);
      expect(find.text('claude-sonnet-4-6'), findsOneWidget);
    });

    testWidgets(
        'uses the most recent workflowProgress snapshot', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkflowInlineView(
              children: [
                {
                  'kind': 'agent-event',
                  'workflowProgress': [
                    {
                      'type': 'workflow_phase',
                      'index': 1,
                      'title': 'Stale',
                    },
                  ],
                },
                {
                  'kind': 'agent-event',
                  'workflowProgress': [
                    {
                      'type': 'workflow_phase',
                      'index': 1,
                      'title': 'Current',
                    },
                  ],
                },
              ],
            ),
          ),
        ),
      );

      expect(find.text('Stale'), findsNothing);
      expect(find.text('Current'), findsOneWidget);
    });

    testWidgets(
        'renders log preview when workflow_log present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkflowInlineView(
              children: [
                {
                  'kind': 'agent-event',
                  'workflowProgress': [
                    {
                      'type': 'workflow_log',
                      'message': 'Starting phase Read',
                    },
                    {
                      'type': 'workflow_log',
                      'message': 'Finished phase Read',
                    },
                  ],
                },
              ],
            ),
          ),
        ),
      );

      expect(find.text('Finished phase Read'), findsOneWidget);
      expect(find.text('Starting phase Read'), findsNothing);
    });

    testWidgets('renders nothing when children is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WorkflowInlineView(children: null),
          ),
        ),
      );
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('skips malformed children and progress entries',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkflowInlineView(
              children: [
                'not-a-map',
                {
                  'kind': 'agent-event',
                  'workflowProgress': 'not-a-list',
                },
                {
                  'kind': 'agent-event',
                  'workflowProgress': [
                    {'type': 'workflow_phase', 'index': 1, 'title': 'Read'},
                    'not-a-map',
                  ],
                },
              ],
            ),
          ),
        ),
      );

      expect(find.text('Read'), findsOneWidget);
    });

    testWidgets('accepts camelCase workflowProgress key', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkflowInlineView(
              children: [
                {
                  'kind': 'agent-event',
                  'workflowProgress': [
                    {'type': 'workflow_phase', 'index': 1, 'title': 'Camel'},
                  ],
                },
              ],
            ),
          ),
        ),
      );

      expect(find.text('Camel'), findsOneWidget);
    });

    testWidgets('renders unknown agent state as pending', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkflowInlineView(
              children: [
                {
                  'kind': 'agent-event',
                  'workflowProgress': [
                    {
                      'type': 'workflow_agent',
                      'agentId': 'a1',
                      'label': 'mystery-agent',
                      'phaseIndex': 1,
                      'phaseTitle': 'Phase',
                      'model': 'claude-sonnet-4-6',
                      'state': 'unknown_state',
                    },
                  ],
                },
              ],
            ),
          ),
        ),
      );

      expect(find.text('Phase · mystery-agent'), findsOneWidget);
    });

    testWidgets('matches 0-based phaseIndex to phase index', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkflowInlineView(
              children: [
                {
                  'kind': 'agent-event',
                  'workflowProgress': [
                    {'type': 'workflow_phase', 'index': 0, 'title': 'Plan'},
                    {'type': 'workflow_phase', 'index': 1, 'title': 'Code'},
                    {
                      'type': 'workflow_agent',
                      'agentId': 'a1',
                      'label': 'coder',
                      'phaseIndex': 1,
                      'phaseTitle': 'Code',
                      'model': 'claude-sonnet-4-6',
                      'state': 'running',
                    },
                  ],
                },
              ],
            ),
          ),
        ),
      );

      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('Code'), findsOneWidget);
      expect(find.text('Code · coder'), findsOneWidget);
    });
  });
}
