import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/session_ui_state_notifier.dart';
import 'package:happy_flutter/core/utils/session_utils.dart';
import 'package:happy_flutter/features/sessions/widgets/mission_control_view.dart';

/// Mission Control is an action radar, not a session archive.
///
/// Blocked outranks unread outranks live. Attention and working sessions
/// render in separate sections, status metrics filter the action deck, and
/// workspaces always drill into folder detail.
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
        missionShortHost('workspace@workspace-denys-local-6589959b66-pzg66'),
        'workspace-denys',
      );
      expect(
        missionShortHost('workspace-denys-local-6589959b66-pzg66'),
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

    expect(find.text('action-blocked'), findsOneWidget);
    final cardY = tester.getTopLeft(find.text('action-blocked')).dy;
    final liveY = tester.getTopLeft(find.text('action-live')).dy;
    expect(cardY, lessThan(liveY));
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('Working now'), findsWidgets);
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
    expect(find.text('action-ws'), findsNothing);

    await tester.tap(find.textContaining('project'));
    await tester.pump();

    // Still no inline rows — drill-in only.
    expect(find.text('action-ws'), findsNothing);
    expect(opened, isNotEmpty);
  });

  testWidgets('hot sessions appear in the action deck', (tester) async {
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

    expect(find.text('action-hot'), findsOneWidget);
  });

  testWidgets('each action section folds past four rows', (tester) async {
    final sessions = [
      for (var i = 0; i < 8; i++)
        _session(id: 's$i', thinking: true, path: '/home/dev/p$i'),
    ];

    await tester.pumpWidget(_app(activeSessions: sessions));
    await tester.pump();

    expect(find.textContaining('action-s'), findsNWidgets(4));
    expect(find.text('… +4 more'), findsOneWidget);

    await tester.tap(find.text('… +4 more'));
    await tester.pump();

    expect(find.textContaining('action-s'), findsNWidgets(8));
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

  testWidgets('a live session renders in the action group', (tester) async {
    final session = _session(id: 'live', thinking: true);

    await tester.pumpWidget(_app(activeSessions: [session]));
    await tester.pump();

    expect(find.text('action-live'), findsOneWidget);
  });

  testWidgets('summary keeps zero lanes visible for fleet awareness', (
    tester,
  ) async {
    final session = _session(id: 'q', path: '/home/dev/project');

    await tester.pumpWidget(_app(activeSessions: [session]));
    await tester.pump();

    expect(find.text('idle'), findsOneWidget);
    expect(find.text('blocked'), findsOneWidget);
    expect(find.text('unread'), findsOneWidget);
    expect(find.text('working'), findsOneWidget);
    expect(find.textContaining('All quiet'), findsOneWidget);
  });

  testWidgets('status metrics filter and restore the action deck', (
    tester,
  ) async {
    final unread = _session(id: 'unread');
    final live = _session(id: 'live', thinking: true);

    await tester.pumpWidget(
      _app(
        activeSessions: [unread, live],
        uiState: const SessionUiState(
          bySessionId: {'unread': SessionUiEntry(unreadCount: 2)},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('action-unread'), findsOneWidget);
    expect(find.text('action-live'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mission-filter-unread')));
    await tester.pump();

    expect(find.text('action-unread'), findsOneWidget);
    expect(find.text('action-live'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('mission-filter-unread')));
    await tester.pump();

    expect(find.text('action-live'), findsOneWidget);
  });

  testWidgets('action tiles preserve title width and minimum tap target', (
    tester,
  ) async {
    final session = _session(
      id: 'tile',
      path: '/home/dev/happy_flutter',
      thinking: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MissionActionRow(
            session: session,
            entry: const SessionUiEntry(
              lastMessagePreview: 'Running the analyzer',
            ),
            lane: MissionLane.live,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('happy_flutter'), findsOneWidget);
    expect(find.textContaining('dev/happy_flutter'), findsOneWidget);
    expect(
      tester.getSize(find.byType(MissionActionRow)).height,
      greaterThanOrEqualTo(48),
    );
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
        actionCardBuilder: (session, entry, lane) =>
            Text('action-${session.id}'),
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
