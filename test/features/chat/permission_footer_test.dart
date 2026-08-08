import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/tools/permission_footer.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

Map<String, dynamic> _pending() => <String, dynamic>{'status': 'pending'};
Map<String, dynamic> _approved() => <String, dynamic>{'status': 'approved'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PermissionFooter plan buttons', () {
    testWidgets('keeps primary actions visible and scopes behind disclosure', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PermissionFooter(
            permission: _pending(),
            sessionId: 's1',
            toolName: 'ExitPlanMode',
            onAllow: () async {},
            onAllowAllEdits: () async {},
            onYolo: () async {},
            onDeny: () async {},
          ),
        ),
      );

      expect(find.text('Allow'), findsOneWidget);
      expect(find.text('Deny'), findsOneWidget);
      expect(find.text('All edits'), findsNothing);
      expect(find.text('YOLO'), findsNothing);
      expect(find.text('More approval options'), findsOneWidget);

      final collapsed = tester.getSemantics(
        find.bySemanticsLabel('More approval options'),
      );
      expect(collapsed.flagsCollection.isExpanded, Tristate.isFalse);

      await tester.tap(find.text('More approval options'));
      await tester.pump();

      expect(find.text('All edits'), findsOneWidget);
      expect(find.text('YOLO'), findsOneWidget);
      final expanded = tester.getSemantics(
        find.bySemanticsLabel('Hide approval options'),
      );
      expect(expanded.flagsCollection.isExpanded, Tristate.isTrue);
    });

    testWidgets('YOLO shows loading spinner while callback runs', (
      tester,
    ) async {
      final completer = Completer<void>();

      await tester.pumpWidget(
        _wrap(
          PermissionFooter(
            permission: _pending(),
            sessionId: 's1',
            toolName: 'ExitPlanMode',
            onAllow: () async {},
            onAllowAllEdits: () async {},
            onYolo: () => completer.future,
            onDeny: () async {},
          ),
        ),
      );

      await tester.tap(find.text('More approval options'));
      await tester.pump();
      await tester.tap(find.text('YOLO'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Allow'), findsOneWidget);
      expect(find.text('Deny'), findsOneWidget);
      expect(find.text('YOLO'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'YOLO'))
            .onPressed,
        isNull,
      );

      completer.complete();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Allow'), findsOneWidget);
    });

    testWidgets('Allow shows loading spinner while callback runs', (
      tester,
    ) async {
      final completer = Completer<void>();

      await tester.pumpWidget(
        _wrap(
          PermissionFooter(
            permission: _pending(),
            sessionId: 's1',
            toolName: 'ExitPlanMode',
            onAllow: () => completer.future,
            onAllowAllEdits: () async {},
            onDeny: () async {},
          ),
        ),
      );

      // Tap Allow
      await tester.tap(find.text('Allow'));
      await tester.pump();

      // Progress is announced while the stable controls remain disabled.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Allow'), findsOneWidget);
      expect(find.text('Deny'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Allow'),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.bySemanticsLabel('Permission action in progress'),
        findsOneWidget,
      );

      // Complete the callback
      completer.complete();
      await tester.pump();

      // Buttons should reappear
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Allow'), findsOneWidget);
    });

    testWidgets('All edits shows loading spinner while callback runs', (
      tester,
    ) async {
      final completer = Completer<void>();

      await tester.pumpWidget(
        _wrap(
          PermissionFooter(
            permission: _pending(),
            sessionId: 's1',
            toolName: 'ExitPlanMode',
            onAllow: () async {},
            onAllowAllEdits: () => completer.future,
            onDeny: () async {},
          ),
        ),
      );

      await tester.tap(find.text('More approval options'));
      await tester.pump();
      await tester.tap(find.text('All edits'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Allow'), findsOneWidget);
      expect(find.text('All edits'), findsOneWidget);

      completer.complete();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Allow'), findsOneWidget);
    });

    testWidgets('Deny shows loading spinner while callback runs', (
      tester,
    ) async {
      final completer = Completer<void>();

      await tester.pumpWidget(
        _wrap(
          PermissionFooter(
            permission: _pending(),
            sessionId: 's1',
            toolName: 'ExitPlanMode',
            onAllow: () async {},
            onAllowAllEdits: () async {},
            onDeny: () => completer.future,
          ),
        ),
      );

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

      await tester.pumpWidget(
        _wrap(
          PermissionFooter(
            permission: _pending(),
            sessionId: 's1',
            toolName: 'ExitPlanMode',
            onAllow: () {
              callCount++;
              return completer.future;
            },
            onAllowAllEdits: () async {},
            onDeny: () async {},
          ),
        ),
      );

      // First tap triggers
      await tester.tap(find.text('Allow'));
      await tester.pump();
      expect(callCount, 1);

      // Stable disabled controls cannot emit a duplicate action.
      await tester.tap(find.text('Allow'));
      await tester.pump();
      expect(callCount, 1);

      completer.complete();
      await tester.pump();
      expect(callCount, 1);
    });

    testWidgets('loading clears on callback error', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PermissionFooter(
            permission: _pending(),
            sessionId: 's1',
            toolName: 'ExitPlanMode',
            onAllow: () async {
              throw Exception('network error');
            },
            onAllowAllEdits: () async {},
            onDeny: () async {},
          ),
        ),
      );

      await tester.tap(find.text('Allow'));
      await tester.pump();

      // Error is caught in _wrap, loading clears, buttons
      // reappear
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Allow'), findsOneWidget);
    });

    testWidgets('does not show clear-context button for claude plan tool', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PermissionFooter(
            permission: _pending(),
            sessionId: 's1',
            toolName: 'ExitPlanMode',
            flavor: 'claude',
            onAllow: () async {},
            onAllowAllEdits: () async {},
            onDeny: () async {},
          ),
        ),
      );

      // Clear-context button intentionally omitted (Apple HIG).
      expect(find.text('Accept plan + clear context'), findsNothing);
    });

    testWidgets('does not show clear-context button for non-claude flavors', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PermissionFooter(
            permission: _pending(),
            sessionId: 's1',
            toolName: 'ExitPlanMode',
            flavor: 'codex',
            onAllow: () async {},
            onAllowAllEdits: () async {},
            onDeny: () async {},
          ),
        ),
      );

      expect(find.text('Accept plan + clear context'), findsNothing);
    });
  });

  group('PermissionFooter approved state', () {
    testWidgets('renders nothing when approved', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PermissionFooter(
            permission: _approved(),
            sessionId: 's1',
            toolName: 'ExitPlanMode',
            onAllow: () async {},
            onAllowAllEdits: () async {},
            onDeny: () async {},
          ),
        ),
      );

      expect(find.text('Allow'), findsNothing);
      expect(find.text('All edits'), findsNothing);
      expect(find.text('Deny'), findsNothing);
      // Auto-approved permissions render nothing (Yolo mode).
      expect(find.byType(SizedBox), findsWidgets);
    });
  });

  group('PermissionFooter standard buttons', () {
    testWidgets('reveals edit-wide approvals on request', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PermissionFooter(
            permission: _pending(),
            sessionId: 's1',
            toolName: 'Edit',
            onAllow: () async {},
            onDeny: () async {},
            onAllowAllEdits: () async {},
            onAllowForSession: () async {},
          ),
        ),
      );

      expect(find.text('Allow'), findsOneWidget);
      expect(find.text('Deny'), findsOneWidget);
      expect(find.text('All edits'), findsNothing);
      expect(find.text('YOLO'), findsNothing);

      await tester.tap(find.text('More approval options'));
      await tester.pump();

      expect(find.text('All edits'), findsOneWidget);
      expect(find.text('YOLO'), findsNothing);
    });

    testWidgets('renders Allow, For session, Deny for Bash tool', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PermissionFooter(
            permission: _pending(),
            sessionId: 's1',
            toolName: 'Bash',
            onAllow: () async {},
            onDeny: () async {},
            onAllowAllEdits: () async {},
            onAllowForSession: () async {},
          ),
        ),
      );

      expect(find.text('Allow'), findsOneWidget);
      expect(find.text('Deny'), findsOneWidget);
      expect(find.text('For session'), findsNothing);

      await tester.tap(find.text('More approval options'));
      await tester.pump();
      expect(find.text('For session'), findsOneWidget);
    });

    testWidgets('actions meet touch targets and wrap at large text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(280, 700),
              textScaler: TextScaler.linear(2),
            ),
            child: SizedBox(
              width: 280,
              child: PermissionFooter(
                permission: _pending(),
                sessionId: 's1',
                toolName: 'Edit',
                onAllow: () async {},
                onDeny: () async {},
                onAllowAllEdits: () async {},
                onYolo: () async {},
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final interactive = <Finder>[
        find.widgetWithText(ElevatedButton, 'Allow'),
        find.widgetWithText(OutlinedButton, 'Deny'),
        find.widgetWithText(TextButton, 'More approval options'),
      ];
      for (final finder in interactive) {
        expect(tester.getSize(finder).height, greaterThanOrEqualTo(44));
      }
    });
  });

  group('PermissionFooter codex buttons', () {
    testWidgets('renders Yes, For session, Stop for codex flavor', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PermissionFooter(
            permission: _pending(),
            sessionId: 's1',
            toolName: 'Bash',
            flavor: 'codex',
            onCodexApprove: () async {},
            onCodexApproveForSession: () async {},
            onCodexAbort: () async {},
          ),
        ),
      );

      expect(find.text('Yes'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);
      expect(find.text('For session'), findsNothing);

      await tester.tap(find.text('More approval options'));
      await tester.pump();
      expect(find.text('For session'), findsOneWidget);
    });
  });
}
