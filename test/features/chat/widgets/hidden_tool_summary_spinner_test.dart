import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/widgets/hidden_tool_summary.dart';

/// Progressive-lag remediation, 2026-08-24 (fifth pass).
///
/// The collapsed [HiddenToolSummary] shows an indeterminate
/// `CircularProgressIndicator` while any tool is "pending". A tool row stamped
/// `canceled` by the running->canceled reconcile parses to `ToolState.pending`
/// (the enum has no `canceled` member), so before this fix the spinner kept
/// ticking at full frame rate forever on a resting visible chat — the exact
/// zero-idle-renderer signature the reconcile was meant to stop.
void main() {
  Future<void> pump(WidgetTester tester, List<Map<String, dynamic>> tools) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HiddenToolSummary(data: {'tools': tools}),
        ),
      ),
    );
  }

  testWidgets('a canceled tool does not spin the collapsed summary', (
    tester,
  ) async {
    await pump(tester, [
      {'name': 'Bash', 'state': 'completed'},
      {'name': 'Read', 'state': 'canceled'},
    ]);

    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason:
          'canceled is terminal — no process will finish it, so the '
          'collapsed spinner must not run',
    );
  });

  testWidgets('a genuinely running tool still spins', (tester) async {
    await pump(tester, [
      {'name': 'Bash', 'state': 'completed'},
      {'name': 'Read', 'state': 'running'},
    ]);

    expect(
      find.byType(CircularProgressIndicator),
      findsOneWidget,
      reason: 'in-flight work must still show progress',
    );
  });

  testWidgets('an all-terminal group (completed + canceled) never spins', (
    tester,
  ) async {
    await pump(tester, [
      {'name': 'Bash', 'state': 'completed'},
      {'name': 'Grep', 'state': 'completed'},
      {'name': 'Read', 'state': 'canceled'},
      {'name': 'Edit', 'state': 'error'},
    ]);

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
