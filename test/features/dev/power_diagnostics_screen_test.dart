import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/power_diagnostics_service.dart';
import 'package:happy_flutter/features/dev/power_diagnostics_screen.dart';

void main() {
  testWidgets(
    'renders the activity chart with legend when samples exist',
    (tester) async {
      powerDiagnostics.reset();
      // One bucket of mixed radio work: socket + rpc burst + sync.
      powerDiagnostics
        ..recordSocketEvent('update')
        ..recordSocketSend('rpc-call', ack: true)
        ..recordSocketSend('rpc-call', ack: true)
        ..recordSyncInvalidation('all', global: true);

      await tester.pumpWidget(
        const MaterialApp(home: PowerDiagnosticsScreen()),
      );
      await tester.pump();

      expect(find.text('Activity over time'), findsOneWidget);
      expect(find.text('Socket'), findsOneWidget);
      expect(find.text('RPC'), findsOneWidget);
      expect(find.text('HTTP'), findsOneWidget);
      expect(find.text('Sync'), findsOneWidget);
      // Peak bucket total = 1 socket + 2 rpc + 1 sync = 4.
      expect(find.text('Peak/bucket: 4'), findsOneWidget);
      // Samples exist, so the empty-state placeholder must not render.
      expect(find.textContaining('Collecting activity'), findsNothing);
    },
  );

  testWidgets('shows the collecting placeholder when no samples', (tester) async {
    powerDiagnostics.reset();

    await tester.pumpWidget(
      const MaterialApp(home: PowerDiagnosticsScreen()),
    );
    await tester.pump();

    expect(find.text('Activity over time'), findsOneWidget);
    expect(find.textContaining('Collecting activity'), findsOneWidget);
    expect(find.text('Peak/bucket: 0'), findsOneWidget);
  });
}
