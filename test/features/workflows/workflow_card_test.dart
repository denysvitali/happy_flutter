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
  String status = 'completed',
  int? agentCount,
  int? totalTokens,
  int? totalToolCalls,
}) => WorkflowRun(
  runId: runId,
  workflowName: name,
  status: status,
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

  testWidgets('shows a live indicator for a running run without details',
      (tester) async {
    // Mirrors the reported empty card: a background run that has been
    // launched (async_launched) but whose snapshot is not rich yet must read
    // as live, not as the misleading "No progress details".
    await tester.pumpWidget(
      _harness(
        _run(
          runId: 'wf_5560207c-639',
          name: 'wf_5560207c-639',
          status: 'async_launched',
        ),
      ),
    );

    expect(find.text('Workflow run'), findsOneWidget);
    expect(find.text('Starting…'), findsOneWidget);
    expect(find.text('No progress details'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('queued run shows static wait copy, no spinner', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(_run(runId: 'wf_q', name: 'wf_q', status: 'queued')),
    );

    // 'Queued' appears in both the badge and the body — never a spinner,
    // never the contradictory 'Starting…'.
    expect(find.text('Queued'), findsWidgets);
    expect(find.text('Starting…'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows step count + preview instead of "No progress details"', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkflowCard(
            run: _run(runId: 'wf_abc', name: 'wf_abc'),
            stepCount: 34,
            stepPreview: 'Path-mining workflow',
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('34 steps'), findsOneWidget);
    expect(find.text('Path-mining workflow'), findsOneWidget);
    expect(find.text('No progress details'), findsNothing);
  });
}
