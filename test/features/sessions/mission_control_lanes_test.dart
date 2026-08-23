import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/session_ui_state_notifier.dart';
import 'package:happy_flutter/core/utils/session_utils.dart';
import 'package:happy_flutter/features/sessions/widgets/mission_control_view.dart';
import 'package:happy_flutter/features/sessions/widgets/workspace_identity.dart';

/// Lane assignment invariants for Mission Control: one lane per session,
/// archived sessions never reach the focus queue, and the row/lane model
/// stays keyed by the session id it was derived from.
void main() {
  Session buildSession(
    String id, {
    bool thinking = false,
    String presence = 'online',
    bool archived = false,
    bool permission = false,
    String path = '/home/dev/app',
    String machineId = 'm1',
    int? activeAt,
    int? lastMessageAt,
    int updatedAt = 1,
  }) {
    return Session(
      id: id,
      seq: 1,
      createdAt: 1,
      updatedAt: updatedAt,
      active: !archived,
      activeAt: activeAt ?? DateTime.now().millisecondsSinceEpoch,
      metadataVersion: 1,
      agentStateVersion: 1,
      thinking: thinking,
      archived: archived,
      presence: presence,
      lastMessageAt: lastMessageAt,
      agentState: permission
          ? AgentState(
              requests: {'r': const RequestInfo(tool: 'Bash', createdAt: 1)},
            )
          : null,
      metadata: Metadata(host: 'host', path: path, machineId: machineId),
    );
  }

  MissionLane expectedLane({
    required bool online,
    required bool permission,
    required bool thinking,
    required bool error,
    required int unread,
  }) {
    if (online && permission) return MissionLane.blocked;
    if (error) return MissionLane.error;
    if (unread > 0) return MissionLane.unread;
    if (online && thinking) return MissionLane.live;
    return MissionLane.quiet;
  }

  group('missionLaneFor', () {
    test('every input combination lands in exactly the priority lane', () {
      final random = Random(2026);
      for (var round = 0; round < 200; round++) {
        final online = random.nextBool();
        final permission = random.nextBool();
        final thinking = random.nextBool();
        final error = random.nextBool();
        final unread = random.nextInt(3);
        final session = buildSession(
          'p$round',
          presence: online ? 'online' : 'offline',
          permission: permission,
          thinking: thinking,
        );
        final entry = SessionUiEntry(
          unreadCount: unread,
          lastMessageIsError: error,
        );
        final lane = missionLaneFor(session, entry);
        expect(
          lane,
          expectedLane(
            online: online,
            permission: permission,
            thinking: thinking,
            error: error,
            unread: unread,
          ),
          reason:
              'online=$online permission=$permission thinking=$thinking '
              'error=$error unread=$unread',
        );
        expect(MissionLane.values.where((l) => l == lane).length, 1);
      }
    });

    test('an archived offline session is quiet unless it carries unread', () {
      final archived = buildSession(
        'arch',
        archived: true,
        presence: 'offline',
        thinking: true,
        permission: true,
      );
      expect(missionLaneFor(archived, SessionUiEntry.empty), MissionLane.quiet);
      expect(
        missionLaneFor(archived, const SessionUiEntry(unreadCount: 1)),
        MissionLane.unread,
      );
      expect(
        missionLaneFor(
          archived,
          const SessionUiEntry(lastMessageIsError: true),
        ),
        MissionLane.error,
      );
    });

    test('the lane is a function of the entry for the same id only', () {
      final session = buildSession('same');
      const quiet = SessionUiEntry();
      const unread = SessionUiEntry(unreadCount: 2);
      expect(missionLaneFor(session, quiet), MissionLane.quiet);
      expect(missionLaneFor(session, unread), MissionLane.unread);
    });
  });

  group('missionLastActivityAt', () {
    test('prefers the cached message timestamp, then lastMessageAt', () {
      final session = buildSession(
        's',
        activeAt: 100,
        updatedAt: 200,
        lastMessageAt: 300,
      );
      expect(
        missionLastActivityAt(
          session,
          const SessionUiEntry(lastMessageTimestamp: 400),
        ),
        400,
      );
      expect(missionLastActivityAt(session, SessionUiEntry.empty), 300);
    });

    test('falls back to the newer of activeAt and updatedAt', () {
      expect(
        missionLastActivityAt(
          buildSession('a', activeAt: 100, updatedAt: 200),
          SessionUiEntry.empty,
        ),
        200,
      );
      expect(
        missionLastActivityAt(
          buildSession('b', activeAt: 500, updatedAt: 200),
          SessionUiEntry.empty,
        ),
        500,
      );
    });
  });

  group('MissionControlView lane partition', () {
    testWidgets('each active session is queued once; archived never', (
      tester,
    ) async {
      final blocked = buildSession('blocked', permission: true);
      final errored = buildSession('errored');
      final unread = buildSession('unread');
      final live = buildSession('live', thinking: true);
      final quiet = buildSession('quiet');
      final archived = [
        buildSession('arch-1', archived: true, presence: 'offline'),
        buildSession('arch-2', archived: true, presence: 'offline'),
      ];
      final uiState = SessionUiState(
        bySessionId: {
          'errored': const SessionUiEntry(
            lastMessageIsError: true,
            unreadCount: 1,
          ),
          'unread': const SessionUiEntry(unreadCount: 3),
          // Unread on an archived row must not resurrect it in the queue.
          'arch-1': const SessionUiEntry(unreadCount: 9),
        },
      );
      final built = <String, List<MissionLane>>{};

      await tester.pumpWidget(
        _app(
          activeSessions: [quiet, live, unread, errored, blocked],
          inactiveSessions: archived,
          uiState: uiState,
          onBuilt: (session, lane, {entry}) =>
              built.putIfAbsent(session.id, () => []).add(lane),
        ),
      );
      await tester.pump();

      expect(built.keys.toSet(), {'blocked', 'errored', 'unread', 'live'});
      expect(built['blocked'], [MissionLane.blocked]);
      expect(built['errored'], [MissionLane.error]);
      expect(built['unread'], [MissionLane.unread]);
      expect(built['live'], [MissionLane.live]);
      expect(built.containsKey('quiet'), isFalse);
      expect(built.containsKey('arch-1'), isFalse);
      expect(built.containsKey('arch-2'), isFalse);
    });

    testWidgets('row data handed to the builder belongs to the same id', (
      tester,
    ) async {
      final sessions = [
        for (var i = 0; i < 4; i++) buildSession('row-$i', thinking: true),
      ];
      final uiState = SessionUiState(
        bySessionId: {
          for (var i = 0; i < 4; i++)
            'row-$i': SessionUiEntry(
              lastMessageTimestamp: 1000 + i,
              lastMessagePreview: 'preview row-$i',
            ),
        },
      );
      final seen = <String, SessionUiEntry>{};
      await tester.pumpWidget(
        _app(
          activeSessions: sessions.reversed.toList(),
          inactiveSessions: const [],
          uiState: uiState,
          onBuilt: (session, lane, {entry}) {
            if (entry != null) seen[session.id] = entry;
          },
        ),
      );
      await tester.pump();
      expect(seen.keys.toSet(), {'row-0', 'row-1', 'row-2', 'row-3'});
      for (final id in seen.keys) {
        expect(seen[id]!.lastMessagePreview, 'preview $id');
        expect(identical(seen[id], uiState.bySessionId[id]), isTrue);
      }
    });
  });

  group('workspace identity', () {
    testWidgets('same path on different machines gets distinct hues', (
      tester,
    ) async {
      late Color first;
      late Color second;
      late Color firstAgain;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final a = buildSession('a', machineId: 'm1');
              final b = buildSession('b', machineId: 'm2');
              first = workspaceIdentityColor(context, sessionFolderKey(a));
              second = workspaceIdentityColor(context, sessionFolderKey(b));
              firstAgain = workspaceIdentityColor(
                context,
                sessionFolderKey(buildSession('c', machineId: 'm1')),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(first, isNot(equals(second)));
      expect(first, equals(firstAgain));
    });
  });
}

Widget _app({
  required List<Session> activeSessions,
  required List<Session> inactiveSessions,
  required SessionUiState uiState,
  required void Function(
    Session session,
    MissionLane lane, {
    SessionUiEntry? entry,
  })
  onBuilt,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: MissionControlView(
        activeSessions: activeSessions,
        inactiveSessions: inactiveSessions,
        machines: const {},
        uiState: uiState,
        actionCardBuilder:
            (
              session,
              entry,
              lane, {
              required animateActivity,
              required highlighted,
            }) {
              onBuilt(session, lane, entry: entry);
              return Text('action-${session.id}');
            },
        onOpenWorkspace: (_) {},
      ),
    ),
  );
}
