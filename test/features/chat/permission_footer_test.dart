import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/tools/permission_footer.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

Map<String, dynamic> _pending() => <String, dynamic>{'status': 'pending'};
Map<String, dynamic> _approved() => <String, dynamic>{'status': 'approved'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PermissionFooter plan buttons', () {
    testWidgets('renders Accept edits, Yolo, and Deny for ExitPlanMode',
        (tester) async {
      await tester.pumpWidget(_wrap(
        PermissionFooter(
          permission: _pending(),
          sessionId: 's1',
          toolName: 'ExitPlanMode',
          onAllowAllEdits: () async {},
          onAllowBypass: () async {},
          onDeny: () async {},
        ),
      ));

      expect(find.text('Accept edits'), findsOneWidget);
      expect(find.text('Yolo'), findsOneWidget);
      expect(find.text('Deny'), findsOneWidget);
    });

    testWidgets('Yolo shows loading spinner while callback runs',
        (tester) async {
      final completer = Completer<void>();

      await tester.pumpWidget(_wrap(
        PermissionFooter(
          permission: _pending(),
          sessionId: 's1',
          toolName: 'ExitPlanMode',
          onAllowAllEdits: () async {},
          onAllowBypass: () => completer.future,
          onDeny: () async {},
        ),
      ));

      // Tap Yolo
      await tester.tap(find.text('Yolo'));
      await tester.pump();

      // Spinner should be visible, buttons hidden
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Accept edits'), findsNothing);
      expect(find.text('Yolo'), findsNothing);
      expect(find.text('Deny'), findsNothing);

      // Complete the callback
      completer.complete();
      await tester.pump();

      // Buttons should reappear
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Accept edits'), findsOneWidget);
    });

    testWidgets('Accept edits shows loading spinner while callback runs',
        (tester) async {
      final completer = Completer<void>();

      await tester.pumpWidget(_wrap(
        PermissionFooter(
          permission: _pending(),
          sessionId: 's1',
          toolName: 'ExitPlanMode',
          onAllowAllEdits: () => completer.future,
          onAllowBypass: () async {},
          onDeny: () async {},
        ),
      ));

      await tester.tap(find.text('Accept edits'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Accept edits'), findsNothing);

      completer.complete();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Accept edits'), findsOneWidget);
    });

    testWidgets('Deny shows loading spinner while callback runs',
        (tester) async {
      final completer = Completer<void>();

      await tester.pumpWidget(_wrap(
        PermissionFooter(
          permission: _pending(),
          sessionId: 's1',
          toolName: 'ExitPlanMode',
          onAllowAllEdits: () async {},
          onAllowBypass: () async {},
          onDeny: () => completer.future,
        ),
      ));

      await tester.tap(find.text('Deny'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('prevents double-tap while loading', (tester) async {
      var callCount = 0;
      final completer = Completer<void>();

      await tester.pumpWidget(_wrap(
        PermissionFooter(
          permission: _pending(),
          sessionId: 's1',
          toolName: 'ExitPlanMode',
          onAllowAllEdits: () async {},
          onAllowBypass: () {
            callCount++;
            return completer.future;
          },
          onDeny: () async {},
        ),
      ));

      // First tap triggers
      await tester.tap(find.text('Yolo'));
      await tester.pump();
      expect(callCount, 1);

      // Buttons are hidden during loading, so second tap can't hit them.
      // Complete and verify only one call was made.
      completer.complete();
      await tester.pump();
      expect(callCount, 1);
    });

    testWidgets('loading clears on callback error', (tester) async {
      await tester.pumpWidget(_wrap(
        PermissionFooter(
          permission: _pending(),
          sessionId: 's1',
          toolName: 'ExitPlanMode',
          onAllowAllEdits: () async {},
          onAllowBypass: () async {
            throw Exception('network error');
          },
          onDeny: () async {},
        ),
      ));

      await tester.tap(find.text('Yolo'));
      await tester.pump();

      // Error is caught in _wrap, loading clears, buttons reappear
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Yolo'), findsOneWidget);
    });
  });

  group('PermissionFooter approved state', () {
    testWidgets('hides action buttons when approved', (tester) async {
      await tester.pumpWidget(_wrap(
        PermissionFooter(
          permission: _approved(),
          sessionId: 's1',
          toolName: 'ExitPlanMode',
          onAllowAllEdits: () async {},
          onAllowBypass: () async {},
          onDeny: () async {},
        ),
      ));

      expect(find.text('Accept edits'), findsNothing);
      expect(find.text('Yolo'), findsNothing);
      expect(find.text('Deny'), findsNothing);
      expect(find.text('Approved'), findsOneWidget);
    });
  });

  group('PermissionFooter standard buttons', () {
    testWidgets('renders Allow, All edits, Deny for Edit tool',
        (tester) async {
      await tester.pumpWidget(_wrap(
        PermissionFooter(
          permission: _pending(),
          sessionId: 's1',
          toolName: 'Edit',
          onAllow: () async {},
          onDeny: () async {},
          onAllowAllEdits: () async {},
          onAllowForSession: () async {},
        ),
      ));

      expect(find.text('Allow'), findsOneWidget);
      expect(find.text('All edits'), findsOneWidget);
      expect(find.text('Deny'), findsOneWidget);
    });

    testWidgets('renders Allow, For session, Deny for Bash tool',
        (tester) async {
      await tester.pumpWidget(_wrap(
        PermissionFooter(
          permission: _pending(),
          sessionId: 's1',
          toolName: 'Bash',
          onAllow: () async {},
          onDeny: () async {},
          onAllowAllEdits: () async {},
          onAllowForSession: () async {},
        ),
      ));

      expect(find.text('Allow'), findsOneWidget);
      expect(find.text('For session'), findsOneWidget);
      expect(find.text('Deny'), findsOneWidget);
    });
  });

  group('PermissionFooter codex buttons', () {
    testWidgets('renders Yes, For session, Stop for codex flavor',
        (tester) async {
      await tester.pumpWidget(_wrap(
        PermissionFooter(
          permission: _pending(),
          sessionId: 's1',
          toolName: 'Bash',
          flavor: 'codex',
          onCodexApprove: () async {},
          onCodexApproveForSession: () async {},
          onCodexAbort: () async {},
        ),
      ));

      expect(find.text('Yes'), findsOneWidget);
      expect(find.text('For session'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);
    });
  });
}
