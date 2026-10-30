import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/ui/agent_identity.dart';
import 'package:happy_flutter/core/utils/theme_helper.dart';
import 'package:happy_flutter/features/chat/tools/permission_footer.dart';
import 'package:happy_flutter/features/chat/widgets/chat_agent_scope.dart';

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

      expect(find.text('Allow once'), findsOneWidget);
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
      expect(find.text('Allow once'), findsOneWidget);
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
      expect(find.text('Allow once'), findsOneWidget);
    });

    testWidgets('Allow shows loading spinner while callback runs', (
      tester,
    ) async {
      final completer = Completer<void>();
      final semantics = tester.ensureSemantics();

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
      await tester.tap(find.text('Allow once'));
      await tester.pump();

      // Progress is announced while the stable controls remain disabled.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Allow once'), findsOneWidget);
      expect(find.text('Deny'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Allow once'),
            )
            .onPressed,
        isNull,
      );
      final progress = find.semantics.byLabel(
        RegExp('Permission action in progress'),
      );
      expect(progress, findsOne);
      expect(progress, isSemantics(isLiveRegion: true));

      // Complete the callback
      completer.complete();
      await tester.pump();

      // Buttons should reappear
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Allow once'), findsOneWidget);
      semantics.dispose();
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
      expect(find.text('Allow once'), findsOneWidget);
      expect(find.text('All edits'), findsOneWidget);

      completer.complete();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Allow once'), findsOneWidget);
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
      await tester.tap(find.text('Allow once'));
      await tester.pump();
      expect(callCount, 1);

      // Stable disabled controls cannot emit a duplicate action.
      await tester.tap(find.text('Allow once'));
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

      await tester.tap(find.text('Allow once'));
      await tester.pump();

      // Error is caught in _wrap, loading clears, buttons
      // reappear
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Allow once'), findsOneWidget);
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

      expect(find.text('Allow once'), findsNothing);
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

      expect(find.text('Allow once'), findsOneWidget);
      expect(find.text('Deny'), findsOneWidget);
      expect(find.text('All edits'), findsNothing);
      expect(find.text('YOLO'), findsNothing);

      await tester.tap(find.text('More approval options'));
      await tester.pump();

      expect(find.text('All edits'), findsOneWidget);
      expect(find.text('YOLO'), findsNothing);
    });

    testWidgets('renders Allow once, For session, Deny for Bash tool', (
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

      expect(find.text('Allow once'), findsOneWidget);
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
        find.widgetWithText(FilledButton, 'Allow once'),
        find.widgetWithText(FilledButton, 'Deny'),
        find.widgetWithText(TextButton, 'More approval options'),
      ];
      for (final finder in interactive) {
        expect(tester.getSize(finder).height, greaterThanOrEqualTo(44));
      }
    });
  });

  group('PermissionFooter codex buttons', () {
    testWidgets('renders Allow once, For session, Stop for codex flavor', (
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

      expect(find.text('Allow once'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);
      expect(find.text('For session'), findsNothing);

      await tester.tap(find.text('More approval options'));
      await tester.pump();
      expect(find.text('For session'), findsOneWidget);
    });
  });

  group('PermissionFooter button colors', () {
    // The themed FilledButton paints a gradient through backgroundBuilder, so
    // the primary action is painted solid through AppButtonStyle.solidFilled:
    // an ink pill (onSurface fill, surface label) — the one strong control on
    // the card — for both Claude and Codex.
    Widget themed(Widget child) => MaterialApp(
      theme: ThemeHelper.buildDarkTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

    Color labelColor(WidgetTester tester, String text) {
      final element = tester.element(find.text(text));
      return DefaultTextStyle.of(element).style.color!;
    }

    Color? fillOf(WidgetTester tester, String text) {
      final button = tester.widget<FilledButton>(
        find.ancestor(of: find.text(text), matching: find.byType(FilledButton)),
      );
      final ink = button.style!.backgroundBuilder!(
        tester.element(find.text(text)),
        const <WidgetState>{},
        null,
      );
      return ((ink as Ink).decoration! as BoxDecoration).color;
    }

    testWidgets('Allow once is a solid ink pill in the dark theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        themed(
          PermissionFooter(
            permission: _pending(),
            sessionId: 's1',
            toolName: 'Bash',
            onAllow: () async {},
            onDeny: () async {},
          ),
        ),
      );

      final cs = ThemeHelper.buildDarkTheme().colorScheme;
      expect(fillOf(tester, 'Allow once'), cs.onSurface);
      expect(labelColor(tester, 'Allow once'), cs.surface);
      // Declining is a normal answer: a quiet tonal pill, not a red outline.
      expect(fillOf(tester, 'Deny'), cs.surfaceContainerHighest);
      expect(labelColor(tester, 'Deny'), cs.onSurface);
    });

    testWidgets('Codex approve uses the same ink pill', (tester) async {
      await tester.pumpWidget(
        themed(
          PermissionFooter(
            permission: _pending(),
            sessionId: 's1',
            toolName: 'CodexBash',
            flavor: 'codex',
            onCodexApprove: () async {},
            onCodexAbort: () async {},
          ),
        ),
      );

      final cs = ThemeHelper.buildDarkTheme().colorScheme;
      expect(fillOf(tester, 'Allow once'), cs.onSurface);
      expect(labelColor(tester, 'Allow once'), cs.surface);
      expect(find.text('Stop'), findsOneWidget);
    });
  });

  group('PermissionFooter question card', () {
    Widget scoped(Widget child) => _wrap(
      ChatAgentScope(
        value: ChatAgentContext(
          agentName: 'Claude',
          identity: agentIdentityForSeed(
            's1',
            brightness: Brightness.light,
            flavor: 'claude',
          ),
          machineLabel: 'k2 cluster',
          workspaceLabel: '~/k2-gitops',
          workspacePath: '/home/denys/k2-gitops',
        ),
        child: child,
      ),
    );

    testWidgets('asks as the agent with the exact command, place and risk', (
      tester,
    ) async {
      await tester.pumpWidget(
        scoped(
          PermissionFooter(
            permission: _pending(),
            sessionId: 's1',
            toolName: 'Bash',
            toolInput: const {
              'command': 'kubectl -n happy rollout restart deploy/happy-server',
            },
            onAllow: () async {},
            onDeny: () async {},
          ),
        ),
      );

      expect(find.text('Allow Claude to run this command?'), findsOneWidget);
      expect(find.text('k2 cluster · ~/k2-gitops'), findsOneWidget);
      // The full command, not the 42-character description.
      expect(
        find.text(r'$ kubectl -n happy rollout restart deploy/happy-server'),
        findsOneWidget,
      );
      expect(find.text('Changes live infrastructure.'), findsOneWidget);
      expect(find.text('Allow once'), findsOneWidget);
    });

    testWidgets('edits outside the workspace say so', (tester) async {
      await tester.pumpWidget(
        scoped(
          PermissionFooter(
            permission: _pending(),
            sessionId: 's1',
            toolName: 'Write',
            toolInput: const {'file_path': '/etc/hosts'},
            onAllow: () async {},
            onDeny: () async {},
          ),
        ),
      );

      expect(find.text('Allow Claude to create hosts?'), findsOneWidget);
      expect(
        find.text('Changes a file outside this workspace.'),
        findsOneWidget,
      );
    });

    testWidgets('falls back to the flavor name without a chat scope', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PermissionFooter(
            permission: _pending(),
            sessionId: 's1',
            toolName: 'Bash',
            flavor: 'claude',
            toolInput: const {'command': 'ls'},
            onAllow: () async {},
            onDeny: () async {},
          ),
        ),
      );

      expect(find.text('Allow Claude to run this command?'), findsOneWidget);
      expect(
        find.text('Runs a shell command on this machine.'),
        findsOneWidget,
      );
    });

    testWidgets('an offline session explains why it cannot be answered', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PermissionFooter(
            permission: _pending(),
            sessionId: 's1',
            toolName: 'Bash',
            isSessionOnline: false,
            onAllow: () async {},
            onDeny: () async {},
          ),
        ),
      );

      expect(
        find.text('The session is offline. Reconnect its machine to answer.'),
        findsOneWidget,
      );
      expect(find.text('Allow once'), findsNothing);
    });

    for (final (status, label) in [
      ('denied', 'Denied · not run'),
      ('canceled', 'Expired · not run'),
    ]) {
      testWidgets('a $status request collapses to one line', (tester) async {
        await tester.pumpWidget(
          _wrap(
            PermissionFooter(
              permission: <String, dynamic>{'status': status},
              sessionId: 's1',
              toolName: 'Bash',
              onAllow: () async {},
              onDeny: () async {},
            ),
          ),
        );

        expect(find.text(label), findsOneWidget);
        expect(find.text('Allow once'), findsNothing);
        expect(find.text('Deny'), findsNothing);
      });
    }
  });
}
