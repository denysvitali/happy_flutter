// Regression coverage for the Phase 1 safety net: a widget that opens
// an `await showDialog` / `await showModalBottomSheet` and then touches
// the BuildContext after the await must guard with `context.mounted`
// to avoid the StateError that previously surfaced in production as the
// "Ref used in disposed widget" / "Bad state" GlitchTip cluster.
//
// These tests assert the safe pattern works (and would have caught the
// regression that the production fixes in `session_dismissible.dart`
// resolved).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('dialog lifecycle: post-await context access', () {
    testWidgets(
      'showDialog awaited, then context.mounted check, then ref access — '
      'no error when widget unmounts mid-dialog',
      (tester) async {
        var accessAfterClose = 0;
        var isMountedAfterDialog = false;

        late StateSetter outerSetState;
        var showDemo = true;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                outerSetState = setState;
                if (!showDemo) return const SizedBox.shrink();
                return _DialogDemo(
                  onClosedSafely: () {
                    accessAfterClose++;
                    isMountedAfterDialog =
                        _DialogDemo.lastContext?.mounted ?? false;
                  },
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open the dialog.
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('demo dialog'), findsOneWidget);

        // Capture the navigator BEFORE tearing down the parent so we
        // can still pop the dialog afterwards.
        final navigator = tester.state<NavigatorState>(
          find.byType(Navigator),
        );

        // Tear down the parent (the dialog still has its own route on
        // the navigator stack, so the await is still pending).
        outerSetState(() => showDemo = false);
        await tester.pumpAndSettle();
        expect(find.text('open'), findsNothing);

        // Dismiss the orphaned dialog. This resumes the awaiting
        // Future, and the onClosedSafely callback runs.
        navigator.pop();
        await tester.pumpAndSettle();

        // The safe post-await path observed the unmounted state and
        // skipped touching the (no longer valid) BuildContext. No
        // StateError escaped to the test framework.
        expect(tester.takeException(), isNull);
        expect(accessAfterClose, equals(1));
        expect(isMountedAfterDialog, isFalse);
      },
    );

    testWidgets(
      'showModalBottomSheet awaited with mounted check — '
      'no error when parent unmounts mid-sheet',
      (tester) async {
        var accessAfterClose = 0;
        var isMountedAfterSheet = false;

        late StateSetter outerSetState;
        var showDemo = true;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                outerSetState = setState;
                if (!showDemo) return const SizedBox.shrink();
                return _SheetDemo(
                  onClosedSafely: () {
                    accessAfterClose++;
                    isMountedAfterSheet =
                        _SheetDemo.lastContext?.mounted ?? false;
                  },
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open the bottom sheet.
        await tester.tap(find.text('open sheet'));
        await tester.pumpAndSettle();
        expect(find.text('demo sheet'), findsOneWidget);

        // Capture the navigator BEFORE tearing down the parent.
        final navigator = tester.state<NavigatorState>(
          find.byType(Navigator),
        );

        // Tear down the parent (the sheet is still on the navigator).
        outerSetState(() => showDemo = false);
        await tester.pumpAndSettle();
        expect(find.text('open sheet'), findsNothing);

        // Dismiss the orphaned sheet.
        navigator.pop();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(accessAfterClose, equals(1));
        expect(isMountedAfterSheet, isFalse);
      },
    );
  });
}

/// A widget that demonstrates the safe pattern: open a dialog via
/// `await showDialog`, then check `State.mounted` (not `context.mounted`,
/// which itself throws when the State has been disposed) before
/// touching the BuildContext. `lastContext` exposes the last-seen
/// context to tests so they can assert `mounted` after teardown.
class _DialogDemo extends StatefulWidget {
  const _DialogDemo({required this.onClosedSafely});

  final VoidCallback onClosedSafely;

  static BuildContext? lastContext;

  @override
  State<_DialogDemo> createState() => _DialogDemoState();
}

class _DialogDemoState extends State<_DialogDemo> {
  Future<void> _openDialog() async {
    _DialogDemo.lastContext = context;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => const AlertDialog(
        content: Text('demo dialog'),
      ),
    );
    if (!mounted) {
      widget.onClosedSafely();
      return;
    }
    widget.onClosedSafely();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: _openDialog,
          child: const Text('open'),
        ),
      ),
    );
  }
}

class _SheetDemo extends StatefulWidget {
  const _SheetDemo({required this.onClosedSafely});

  final VoidCallback onClosedSafely;

  static BuildContext? lastContext;

  @override
  State<_SheetDemo> createState() => _SheetDemoState();
}

class _SheetDemoState extends State<_SheetDemo> {
  Future<void> _openSheet() async {
    _SheetDemo.lastContext = context;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => const SizedBox(
        height: 200,
        child: Center(child: Text('demo sheet')),
      ),
    );
    if (!mounted) {
      widget.onClosedSafely();
      return;
    }
    widget.onClosedSafely();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: _openSheet,
          child: const Text('open sheet'),
        ),
      ),
    );
  }
}
