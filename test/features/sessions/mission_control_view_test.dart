import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/session_ui_state_notifier.dart';
import 'package:happy_flutter/core/utils/session_utils.dart';
import 'package:happy_flutter/features/sessions/widgets/mission_control_view.dart';

/// Mission Control is an action radar, not a session archive.
///
/// Blocked outranks unread outranks live. Workspaces never expand
/// sessions inline — they drill into the folder detail. Quiet
/// workspaces (no hot sessions, no activity in 3h) hide behind a
/// drawer. Action overflow folds past six rows.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('missionLaneFor', () {
    test('a pending permission request is blocked, even with unread', () {
      final session = _session(
        id: 's1',
        thinking: true,
        agentState: AgentState(
          requests: {'r': const RequestInfo(tool: 'Bash', createdAt: 1)},
        ),
      );
      const entry = SessionUiEntry(unreadCount: 3);
      expect(missionLaneFor(session, entry), MissionLane.blocked);
    });

    test('unread outranks thinking', () {
      final session = _session(id: 's2', thinking: true);
      const entry = SessionUiEntry(unreadCount: 1);
      expect(missionLaneFor(session, entry), MissionLane.unread);
    });

    test('a thinking session with no unread is live', () {
      final session = _session(id: 's3', thinking: true);
      expect(missionLaneFor(session, SessionUiEntry.empty), MissionLane.live);
    });

    test('an idle session is quiet', () {
      final session = _session(id: 's4');
      expect(missionLaneFor(session, SessionUiEntry.empty), MissionLane.quiet);
    });

    test('an offline session is never blocked or live', () {
      final session = _session(
        id: 's5',
        presence: 'offline',
        thinking: true,
        agentState: AgentState(
          requests: {'r': const RequestInfo(tool: 'Bash', createdAt: 1)},
        ),
      );
      expect(missionLaneFor(session, SessionUiEntry.empty), MissionLane.quiet);
    });
  });

  group('formatElapsedShort', () {
    test('formats seconds, minutes and hours', () {
      expect(formatElapsedShort(12000), '12s');
      expect(formatElapsedShort(245000), '4m 05s');
      expect(formatElapsedShort(4320000), '1h 12m');
      expect(formatElapsedShort(-5), '0s');
    });
  });

  group('missionShortPath', () {
    test('keeps the last two segments', () {
      expect(
        missionShortPath('~/git/fw-analyzer/.firmware'),
        'fw-analyzer/.firmware',
      );
      expect(missionShortPath('~/kernel'), 'kernel');
      expect(missionShortPath('~'), '~');
    });
  });

  group('missionShortHost', () {
    test('strips k8s hash tails and user@ prefixes', () {
      expect(
        missionShortHost('workspace@workspace-denys-local-6589959b'),
        'workspace-denys',
      );
      expect(missionShortHost('root@OpenWrt (go)'), 'OpenWrt');
      expect(missionShortHost('happy'), 'happy');
    });
  });

  testWidgets('blocked sessions render above live ones', (tester) async {
    final blocked = _session(
      id: 'blocked',
      agentState: AgentState(
        requests: {'r': const RequestInfo(tool: 'Bash', createdAt: 1)},
      ),
    );
    final live = _session(id: 'live', thinking: true);

    await tester.pumpWidget(_app(activeSessions: [live, blocked]));
    await tester.pump();

    expect(find.text('card-blocked'), findsOneWidget);
    final cardY = tester.getTopLeft(find.text('card-blocked')).dy;
    final liveY = tester.getTopLeft(find.text('row-live')).dy;
    expect(cardY, lessThan(liveY));
  });

  testWidgets('a workspace never expands sessions inline', (tester) async {
    final opened = <String>[];
    final session = _session(id: 'ws', path: '/home/dev/project');

    await tester.pumpWidget(
      _app(
        activeSessions: [session],
        onOpenWorkspace: (header) => opened.add(header.folderKey),
      ),
    );
    await tester.pump();

    expect(find.textContaining('project'), findsOneWidget);
    expect(find.text('row-ws'), findsNothing);

    await tester.tap(find.textContaining('project'));
    await tester.pump();

    // Still no inline rows — drill-in only.
    expect(find.text('row-ws'), findsNothing);
    expect(opened, isNotEmpty);
  });

  testWidgets('hot sessions appear as action rows, not workspace rows', (
    tester,
  ) async {
    final session = _session(id: 'hot', path: '/home/dev/project');

    await tester.pumpWidget(
      _app(
        activeSessions: [session],
        uiState: const SessionUiState(
          bySessionId: {'hot': SessionUiEntry(unreadCount: 2)},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('card-hot'), findsOneWidget);
    expect(find.text('row-hot'), findsNothing);
  });

  testWidgets('action overflow folds past six rows', (tester) async {
    final sessions = [
      for (var i = 0; i < 8; i++)
        _session(
          id: 's$i',
          thinking: true,
          path: '/home/dev/p$i',
        ),
    ];

    await tester.pumpWidget(_app(activeSessions: sessions));
    await tester.pump();

    expect(find.textContaining('row-s'), findsNWidgets(6));
    expect(find.text('… +2 more'), findsOneWidget);

    await tester.tap(find.text('… +2 more'));
    await tester.pump();

    expect(find.textContaining('row-s'), findsNWidgets(8));
    expect(find.text('Show less'), findsOneWidget);
  });

  testWidgets('quiet workspaces hide behind a drawer', (tester) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Quiet window is 3h (missionControlQuietWindow). "recent" must be
    // inside that, "old" outside, or both fold into the quiet drawer.
    final hour = const Duration(hours: 1).inMilliseconds;
    final day = const Duration(days: 1).inMilliseconds;
    final recent = _session(id: 'recent', path: '/home/dev/recent');
    final old = _session(id: 'old', path: '/home/dev/old');

    await tester.pumpWidget(
      _app(
        activeSessions: [recent, old],
        uiState: SessionUiState(
          bySessionId: {
            'recent': SessionUiEntry(lastMessageTimestamp: now - hour),
            'old': SessionUiEntry(lastMessageTimestamp: now - day),
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('recent'), findsOneWidget);
    expect(find.textContaining('old'), findsNothing);
    expect(find.textContaining('quiet workspace'), findsOneWidget);

    await tester.tap(find.textContaining('quiet workspace'));
    await tester.pump();

    expect(find.textContaining('old'), findsOneWidget);
  });

  testWidgets('a live row shows what the session is working on', (
    tester,
  ) async {
    final session = _session(id: 'live', thinking: true);

    await tester.pumpWidget(
      _app(
        activeSessions: [session],
        uiState: const SessionUiState(
          bySessionId: {
            'live': SessionUiEntry(lastMessagePreview: 'rg -n pattern'),
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('rg -n pattern'), findsOneWidget);
  });

  testWidgets('radar hides empty lanes', (tester) async {
    final session = _session(id: 'q', path: '/home/dev/project');

    await tester.pumpWidget(_app(activeSessions: [session]));
    await tester.pump();

    expect(find.text('idle'), findsOneWidget);
    expect(find.text('blocked'), findsNothing);
    expect(find.text('unread'), findsNothing);
    expect(find.text('working'), findsNothing);
    // Idle chip is enough — no duplicate "all quiet" banner.
    expect(find.textContaining('All quiet'), findsNothing);
  });
}

Widget _app({
  required List<Session> activeSessions,
  SessionUiState uiState = SessionUiState.empty,
  void Function(SessionFolderHeader header)? onOpenWorkspace,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: MissionControlView(
        activeSessions: activeSessions,
        inactiveSessions: const [],
        machines: const {},
        uiState: uiState,
        attentionCardBuilder: (session, entry) => Text('card-${session.id}'),
        rowBuilder: (session, entry) => Text('row-${session.id}'),
        onOpenWorkspace: onOpenWorkspace ?? (_) {},
      ),
    ),
  );
}

Session _session({
  required String id,
  String path = '/home/project',
  bool thinking = false,
  String presence = 'online',
  AgentState? agentState,
}) {
  return Session(
    id: id,
    seq: 1,
    createdAt: 1,
    updatedAt: 1,
    active: true,
    activeAt: DateTime.now().millisecondsSinceEpoch,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: thinking,
    presence: presence,
    agentState: agentState,
    metadata: Metadata(host: 'localhost', path: path),
  );
}
