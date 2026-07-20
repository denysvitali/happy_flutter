import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/workflow_run.dart';
import 'package:happy_flutter/features/workflows/workflow_card.dart';

Widget _harness(WorkflowRun run) => MaterialApp(
  home: Scaffold(
    body: WorkflowCard(run: run, onTap: () {}),
  ),
);

WorkflowRun _run({
  required String runId,
  required String name,
  String? summary,
  int? agentCount,
  int? totalTokens,
  int? totalToolCalls,
}) => WorkflowRun(
  runId: runId,
  workflowName: name,
  status: 'completed',
  summary: summary,
  agentCount: agentCount,
  totalTokens: totalTokens,
  totalToolCalls: totalToolCalls,
);

void main() {
  testWidgets('replaces an opaque wf_* name and shows the run id', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(_run(runId: 'wf_43911709-675', name: 'wf_43911709-675')),
    );

    expect(find.text('Workflow run'), findsOneWidget);
    expect(find.text('wf_43911709-675'), findsOneWidget);
    // Bare daemon snapshot: placeholder instead of an empty card body.
    expect(find.text('No progress details'), findsOneWidget);
  });

  testWidgets('keeps a friendly workflow name without the run id', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        _run(
          runId: 'wf_43911709-675',
          name: 'h77-enabler-recon',
          summary: 'Find the h77 constructor',
        ),
      ),
    );

    expect(find.text('h77-enabler-recon'), findsOneWidget);
    expect(find.text('wf_43911709-675'), findsNothing);
    expect(find.text('No progress details'), findsNothing);
  });

  testWidgets('compacts large token and tool counts in the stats line', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        _run(
          runId: 'wf_1',
          name: 'audit',
          agentCount: 8,
          totalTokens: 178241,
          totalToolCalls: 167,
        ),
      ),
    );

    expect(find.text('8 agents · 178k tokens · 167 tools'), findsOneWidget);
  });
}
