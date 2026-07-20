import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/workflow_run.dart';
import 'package:happy_flutter/features/workflows/workflow_status_badge.dart';

Widget _harness(String status) => MaterialApp(
  home: Scaffold(body: WorkflowStatusBadge(status: status)),
);

void main() {
  testWidgets('maps every known status to a friendly label', (tester) async {
    const cases = <String, String>{
      WorkflowStatus.running: 'Running',
      WorkflowStatus.paused: 'Paused',
      WorkflowStatus.completed: 'Completed',
      WorkflowStatus.failed: 'Failed',
      WorkflowStatus.killed: 'Killed',
      WorkflowStatus.cancelled: 'Cancelled',
      WorkflowStatus.asyncLaunched: 'Launching',
      WorkflowStatus.queued: 'Queued',
      WorkflowStatus.pending: 'Queued',
    };
    for (final entry in cases.entries) {
      await tester.pumpWidget(_harness(entry.key));
      expect(
        find.text(entry.value),
        findsOneWidget,
        reason: 'status ${entry.key}',
      );
    }
  });

  testWidgets('falls back to Unknown for an empty status', (tester) async {
    await tester.pumpWidget(_harness(''));
    expect(find.text('Unknown'), findsOneWidget);
  });
}
