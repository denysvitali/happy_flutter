import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/session_ui_state_notifier.dart';
import 'package:happy_flutter/features/sessions/widgets/mission_control_view.dart';

/// Mission Control triages sessions into lanes: a pending permission
/// outranks unread, unread outranks "working", and everything else is
/// quiet. Getting that order wrong buries a stalled agent.
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

  testWidgets('a quiet workspace stays collapsed until tapped', (
    tester,
  ) async {
    final session = _session(id: 'ws', path: '/home/dev/project');

    await tester.pumpWidget(_app(activeSessions: [session]));
    await tester.pump();

    // One line for the workspace, no session rows.
    expect(find.text('Workspaces'), findsOneWidget);
    expect(find.textContaining('project'), findsOneWidget);
    expect(find.text('row-ws'), findsNothing);

    await tester.tap(find.textContaining('project'));
    await tester.pump();

    expect(find.text('row-ws'), findsOneWidget);
  });

  testWidgets('a workspace with unread work opens itself', (tester) async {
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

    // Promoted to the attention lane, so the workspace lists it as a
    // dot only — never twice.
    expect(find.text('card-hot'), findsOneWidget);
    expect(find.text('row-hot'), findsNothing);
  });

  testWidgets('a workspace line counts lanes instead of drawing a dot '
      'per session', (tester) async {
    final unread = _session(id: 'u', path: '/home/dev/project');
    final quiet1 = _session(id: 'q1', path: '/home/dev/project');
    final quiet2 = _session(id: 'q2', path: '/home/dev/project');

    await tester.pumpWidget(
      _app(
        activeSessions: [unread, quiet1, quiet2],
        uiState: const SessionUiState(
          bySessionId: {'u': SessionUiEntry(unreadCount: 1)},
        ),
      ),
    );
    await tester.pump();

    // Last two path segments only, plus the total session count.
    expect(find.text('dev/project'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  test('missionShortPath keeps the last two segments', () {
    expect(missionShortPath('~/git/fw-analyzer/.firmware'),
        'fw-analyzer/.firmware');
    expect(missionShortPath('~/kernel'), 'kernel');
    expect(missionShortPath('~'), '~');
  });

  testWidgets('the summary line hides empty lanes', (tester) async {
    final session = _session(id: 'q', path: '/home/dev/project');

    await tester.pumpWidget(_app(activeSessions: [session]));
    await tester.pump();

    expect(find.text('idle'), findsOneWidget);
    expect(find.text('blocked'), findsNothing);
    expect(find.text('unread'), findsNothing);
    expect(find.text('working'), findsNothing);
  });

  testWidgets('an expanded workspace folds its tail behind … +n', (
    tester,
  ) async {
    final sessions = [
      for (var i = 0; i < 8; i++)
        _session(id: 's$i', path: '/home/dev/project'),
    ];

    await tester.pumpWidget(_app(activeSessions: sessions));
    await tester.pump();

    await tester.tap(find.textContaining('dev/project'));
    await tester.pump();

    expect(find.textContaining('row-s'), findsNWidgets(6));
    expect(find.text('… +2'), findsOneWidget);

    await tester.tap(find.text('… +2'));
    await tester.pump();

    expect(find.textContaining('row-s'), findsNWidgets(8));
    expect(find.text('Show less'), findsOneWidget);
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
}

Widget _app({
  required List<Session> activeSessions,
  SessionUiState uiState = SessionUiState.empty,
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
