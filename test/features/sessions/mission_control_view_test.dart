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

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MissionControlView(
            activeSessions: [live, blocked],
            inactiveSessions: const [],
            machines: const {},
            uiState: const SessionUiState(),
            attentionCardBuilder: (session, entry) =>
                Text('card-${session.id}'),
            rowBuilder: (session, entry) => Text('row-${session.id}'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Waiting on you'), findsOneWidget);
    expect(find.text('Live now'), findsOneWidget);
    expect(find.text('card-blocked'), findsOneWidget);
    expect(find.text('row-live'), findsWidgets);
    final cardY = tester.getTopLeft(find.text('card-blocked')).dy;
    final liveY = tester.getTopLeft(find.text('row-live').first).dy;
    expect(cardY, lessThan(liveY));
  });

  testWidgets('workspace groups collapse in place', (tester) async {
    final session = _session(id: 'ws', path: '/home/dev/project');

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MissionControlView(
            activeSessions: [session],
            inactiveSessions: const [],
            machines: const {},
            uiState: const SessionUiState(),
            attentionCardBuilder: (s, e) => Text('card-${s.id}'),
            rowBuilder: (s, e) => Text('row-${s.id}'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Workspaces'), findsOneWidget);
    expect(find.text('row-ws'), findsOneWidget);

    await tester.tap(find.textContaining('project'));
    await tester.pump();

    expect(find.text('row-ws'), findsNothing);
  });
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
