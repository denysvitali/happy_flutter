import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/session_ui_state_notifier.dart';
import 'package:happy_flutter/core/providers/sessions_notifier.dart';
import 'package:happy_flutter/core/utils/session_utils.dart';
import 'package:happy_flutter/features/sessions/widgets/session_list_helpers.dart';

void main() {
  group('isSessionsCollectionRoute', () {
    test('recognizes both sessions routes and startup', () {
      expect(isSessionsCollectionRoute(null), isTrue);
      expect(isSessionsCollectionRoute('home'), isTrue);
      expect(isSessionsCollectionRoute('sessions'), isTrue);
    });

    test('rejects routes that cover the sessions collection', () {
      expect(isSessionsCollectionRoute('chat'), isFalse);
      expect(isSessionsCollectionRoute('settings'), isFalse);
    });
  });

  group('shouldShowInactiveSessionsSection', () {
    test('returns false when there are no inactive sessions', () {
      expect(
        shouldShowInactiveSessionsSection(
          hideInactive: false,
          activeCount: 1,
          inactiveCount: 0,
        ),
        isFalse,
      );
    });

    test('returns true when hideInactive is disabled', () {
      expect(
        shouldShowInactiveSessionsSection(
          hideInactive: false,
          activeCount: 1,
          inactiveCount: 3,
        ),
        isTrue,
      );
    });

    test('returns false when hideInactive is enabled and active exist', () {
      expect(
        shouldShowInactiveSessionsSection(
          hideInactive: true,
          activeCount: 2,
          inactiveCount: 3,
        ),
        isFalse,
      );
    });

    test('returns true as fallback when only inactive sessions exist', () {
      expect(
        shouldShowInactiveSessionsSection(
          hideInactive: true,
          activeCount: 0,
          inactiveCount: 3,
        ),
        isTrue,
      );
    });
  });

  group('groupAllSessionsByFolder', () {
    Session buildSession(
      String id, {
      required String path,
      required String machineId,
      required int updatedAt,
      required int activeAt,
      required bool active,
      String presence = 'offline',
    }) {
      return Session(
        id: id,
        seq: 1,
        createdAt: updatedAt,
        updatedAt: updatedAt,
        active: active,
        activeAt: activeAt,
        metadataVersion: 1,
        agentStateVersion: 1,
        thinking: false,
        presence: presence,
        metadata: Metadata(
          path: path,
          machineId: machineId,
          host: '$machineId-host',
          homeDir: '/home/dev',
        ),
      );
    }

    final machines = <String, Machine>{
      'm1': Machine(
        id: 'm1',
        seq: 1,
        createdAt: 1,
        updatedAt: 1,
        active: true,
        activeAt: 1,
        metadataVersion: 1,
        daemonStateVersion: 1,
        metadata: const MachineMetadata(
          displayName: 'Work Mac',
          host: 'work-mac',
        ),
      ),
      'm2': Machine(
        id: 'm2',
        seq: 1,
        createdAt: 1,
        updatedAt: 1,
        active: true,
        activeAt: 1,
        metadataVersion: 1,
        daemonStateVersion: 1,
        metadata: const MachineMetadata(
          displayName: 'Linux Box',
          host: 'linux-box',
        ),
      ),
    };

    test('groups active and inactive sessions under one folder header', () {
      final groups = groupAllSessionsByFolder(
        [
          buildSession(
            'active-1',
            path: '/home/dev/app',
            machineId: 'm1',
            updatedAt: 100,
            activeAt: 100,
            active: true,
            presence: 'online',
          ),
        ],
        [
          buildSession(
            'archived-1',
            path: '/home/dev/app',
            machineId: 'm1',
            updatedAt: 90,
            activeAt: 90,
            active: false,
          ),
        ],
        machines,
        getLastMessageTimestamp: (sessionId) =>
            sessionId == 'active-1' ? 110 : 95,
        getUnreadCount: (sessionId) => sessionId == 'active-1' ? 2 : 9,
      );

      expect(groups, hasLength(1));
      final group = groups.single;
      expect(group.header.displayPath, '~/app');
      expect(group.header.machineName, 'Work Mac');
      expect(group.header.activeSessionCount, 1);
      expect(group.header.inactiveSessionCount, 1);
      expect(group.header.unreadCount, 2);
      expect(group.activeSessions.single.id, 'active-1');
      expect(group.inactiveSessions.single.id, 'archived-1');
    });

    test('counts unread messages from active sessions only', () {
      final groups = groupAllSessionsByFolder(
        [
          buildSession(
            'active-1',
            path: '/home/dev/app',
            machineId: 'm1',
            updatedAt: 100,
            activeAt: 100,
            active: true,
          ),
        ],
        [
          buildSession(
            'archived-1',
            path: '/home/dev/app',
            machineId: 'm1',
            updatedAt: 90,
            activeAt: 90,
            active: false,
          ),
        ],
        machines,
        getUnreadCount: (sessionId) => sessionId == 'active-1' ? 4 : 47,
      );

      expect(groups.single.header.unreadCount, 4);
    });

    test('resolves each session activity timestamp only once', () {
      final sessions = [
        buildSession(
          'active-1',
          path: '/home/dev/app',
          machineId: 'm1',
          updatedAt: 100,
          activeAt: 100,
          active: true,
        ),
        buildSession(
          'active-2',
          path: '/home/dev/app',
          machineId: 'm1',
          updatedAt: 90,
          activeAt: 90,
          active: true,
        ),
        buildSession(
          'active-3',
          path: '/home/dev/other',
          machineId: 'm1',
          updatedAt: 80,
          activeAt: 80,
          active: true,
        ),
      ];
      var lookups = 0;

      groupAllSessionsByFolder(
        sessions,
        const [],
        machines,
        getLastMessageTimestamp: (_) {
          lookups++;
          return null;
        },
      );

      expect(lookups, sessions.length);
    });

    test(
      'sorted-session cache skips all collection work when inputs match',
      () {
        final session = buildSession(
          'active-1',
          path: '/home/dev/app',
          machineId: 'm1',
          updatedAt: 100,
          activeAt: 100,
          active: true,
        );
        final sessions = <String, Session>{session.id: session};
        final archived = <String>{};
        final timestampRevision = Object();
        final first = computeSortedSessions(
          sessions,
          previous: null,
          lastSessions: null,
          lastSearchQuery: null,
          optimisticallyArchivedIds: archived,
          getLastMessageTimestamp: (_) => 100,
        );

        final second = computeSortedSessions(
          sessions,
          previous: first,
          lastSessions: sessions,
          lastSearchQuery: '',
          optimisticallyArchivedIds: archived,
          lastOptimisticallyArchivedIds: archived,
          timestampRevision: timestampRevision,
          lastTimestampRevision: timestampRevision,
          getLastMessageTimestamp: (_) =>
              throw StateError('cache hit must not read timestamps'),
        );

        expect(identical(second, first), isTrue);
      },
    );

    test('sorted-session cache tracks effective lifecycle activity', () {
      final inactive = buildSession(
        'session-1',
        path: '/home/dev/app',
        machineId: 'm1',
        updatedAt: 100,
        activeAt: 100,
        active: false,
      );
      final initialSessions = <String, Session>{inactive.id: inactive};
      final archived = <String>{};
      final first = computeSortedSessions(
        initialSessions,
        previous: null,
        lastSessions: null,
        lastSearchQuery: null,
        optimisticallyArchivedIds: archived,
        getLastMessageTimestamp: (_) => null,
      );
      expect(first.active, isEmpty);

      final running = inactive.copyWith(
        metadata: inactive.metadata!.copyWith(
          lifecycleState: 'running',
          lifecycleStateSince: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      final updatedSessions = <String, Session>{running.id: running};
      final second = computeSortedSessions(
        updatedSessions,
        previous: first,
        lastSessions: initialSessions,
        lastSearchQuery: '',
        optimisticallyArchivedIds: archived,
        lastOptimisticallyArchivedIds: archived,
        getLastMessageTimestamp: (_) => null,
      );

      expect(second, isNot(same(first)));
      expect(second.active.single.id, running.id);
    });

    test('collection projection ignores row-only session changes', () {
      final session = buildSession(
        'active-1',
        path: '/home/dev/app',
        machineId: 'm1',
        updatedAt: 100,
        activeAt: 100,
        active: true,
      );
      final initial = SessionCollectionProjection.fromSessions({
        session.id: session,
      });
      final rowOnlyUpdate = SessionCollectionProjection.fromSessions({
        session.id: session.copyWith(thinking: true),
      });
      final regroupingUpdate = SessionCollectionProjection.fromSessions({
        session.id: session.copyWith(
          metadata: session.metadata!.copyWith(path: '/home/dev/other'),
        ),
      });
      expect(rowOnlyUpdate, initial);
      expect(regroupingUpdate, isNot(initial));
    });

    test('collection projection consumes notifier-prepared revision', () {
      final session = buildSession(
        'active-1',
        path: '/home/dev/app',
        machineId: 'm1',
        updatedAt: 100,
        activeAt: 100,
        active: true,
      );
      final sessions = SessionCollectionSnapshot({session.id: session});

      final projection = SessionCollectionProjection.fromSessions(sessions);

      expect(projection.sessions, same(sessions));
      expect(projection.revision, sessions.collectionRevision);
    });

    test(
      'mission projection ignores row-only metadata but tracks live state',
      () {
        final session = buildSession(
          'active-1',
          path: '/home/dev/app',
          machineId: 'm1',
          updatedAt: 100,
          activeAt: 100,
          active: true,
          presence: 'online',
        );
        final initial = MissionControlSessionProjection.fromSessions({
          session.id: session,
        });
        final rowOnlyUpdate = MissionControlSessionProjection.fromSessions({
          session.id: session.copyWith(
            metadata: session.metadata!.copyWith(model: 'opus'),
          ),
        });
        final liveUpdate = MissionControlSessionProjection.fromSessions({
          session.id: session.copyWith(thinking: true),
        });

        expect(rowOnlyUpdate, initial);
        expect(liveUpdate, isNot(initial));
      },
    );

    test('machine-folder projection ignores heartbeat-only updates', () {
      final initial = SessionFolderMachinesProjection.fromMachines(machines);
      final heartbeat = <String, Machine>{
        ...machines,
        'm1': machines['m1']!.copyWith(activeAt: 99, updatedAt: 99),
      };
      final renamed = <String, Machine>{
        ...machines,
        'm1': machines['m1']!.copyWith(
          metadata: machines['m1']!.metadata!.copyWith(
            displayName: 'Renamed Mac',
          ),
        ),
      };

      expect(SessionFolderMachinesProjection.fromMachines(heartbeat), initial);
      expect(
        SessionFolderMachinesProjection.fromMachines(renamed),
        isNot(initial),
      );
    });

    test('ordering projection ignores previews but tracks timestamps', () {
      const initialEntry = SessionUiEntry(
        lastMessageTimestamp: 100,
        lastMessagePreview: 'first',
        unreadCount: 1,
      );
      final initial = SessionOrderingProjection.fromState(
        const SessionUiState(bySessionId: {'active-1': initialEntry}),
      );
      final previewUpdate = SessionOrderingProjection.fromState(
        const SessionUiState(
          bySessionId: {
            'active-1': SessionUiEntry(
              lastMessageTimestamp: 100,
              lastMessagePreview: 'streaming update',
              unreadCount: 2,
            ),
          },
        ),
      );
      final timestampUpdate = SessionOrderingProjection.fromState(
        const SessionUiState(
          bySessionId: {
            'active-1': SessionUiEntry(
              lastMessageTimestamp: 101,
              lastMessagePreview: 'streaming update',
              unreadCount: 2,
            ),
          },
        ),
      );

      expect(previewUpdate, initial);
      expect(timestampUpdate, isNot(initial));
      expect(timestampUpdate.timestampFor('active-1'), 101);
    });

    test('prepared ordering inputs reuse identity for row-only updates', () {
      final initial = SessionUiOrdering.reconcile(
        previous: SessionUiOrdering.empty,
        timestamps: const {'active-1': 100},
        optimisticallyArchivedIds: const <String>{},
      );
      final rowOnlyUpdate = SessionUiOrdering.reconcile(
        previous: initial,
        timestamps: const {'active-1': 100},
        optimisticallyArchivedIds: const <String>{},
      );
      final timestampUpdate = SessionUiOrdering.reconcile(
        previous: rowOnlyUpdate,
        timestamps: const {'active-1': 101},
        optimisticallyArchivedIds: const <String>{},
      );

      expect(identical(rowOnlyUpdate, initial), isTrue);
      expect(timestampUpdate.revision, initial.revision + 1);
      expect(timestampUpdate.timestamps['active-1'], 101);
    });

    test('tablet candidate projection is identity-stable for row updates', () {
      final newer = buildSession(
        'newer',
        path: '/home/dev/app',
        machineId: 'm1',
        updatedAt: 200,
        activeAt: 200,
        active: true,
      );
      final older = buildSession(
        'older',
        path: '/home/dev/app',
        machineId: 'm1',
        updatedAt: 100,
        activeAt: 100,
        active: true,
      );
      final initial = TabletSessionSelectionProjection.fromSessions({
        older.id: older,
        newer.id: newer,
      });
      final rowOnlyUpdate = TabletSessionSelectionProjection.fromSessions({
        older.id: older.copyWith(thinking: true),
        newer.id: newer,
      });

      expect(initial.sessionIds, ['newer', 'older']);
      expect(rowOnlyUpdate, initial);
    });

    test('disambiguates duplicate visible session names with stable ids', () {
      final sessions = [
        buildSession(
          'abcdef-first',
          path: '/home/dev/app',
          machineId: 'm1',
          updatedAt: 100,
          activeAt: 100,
          active: true,
        ),
        buildSession(
          'uvwxyz-second',
          path: '/home/dev/app',
          machineId: 'm1',
          updatedAt: 90,
          activeAt: 90,
          active: true,
        ),
        buildSession(
          'unique-session',
          path: '/home/dev/other',
          machineId: 'm1',
          updatedAt: 80,
          activeAt: 80,
          active: true,
        ),
      ];

      final names = getDisambiguatedSessionNames(sessions);

      expect(names['abcdef-first'], 'app · abcdef');
      expect(names['uvwxyz-second'], 'app · uvwxyz');
      expect(names['unique-session'], 'other');
    });

    test('sorts folders by most recent activity across all sessions', () {
      final groups = groupAllSessionsByFolder(
        [
          buildSession(
            'active-1',
            path: '/home/dev/app',
            machineId: 'm1',
            updatedAt: 100,
            activeAt: 100,
            active: true,
          ),
        ],
        [
          buildSession(
            'archived-1',
            path: '/home/dev/older',
            machineId: 'm2',
            updatedAt: 200,
            activeAt: 200,
            active: false,
          ),
        ],
        machines,
        getLastMessageTimestamp: (sessionId) =>
            sessionId == 'archived-1' ? 250 : 110,
      );

      expect(groups, hasLength(2));
      expect(groups.first.header.displayPath, '~/older');
      expect(groups.last.header.displayPath, '~/app');
    });
  });

  group('sessionFolderKey', () {
    Session make({String? machineId, String? path}) => Session(
      id: 's',
      seq: 1,
      createdAt: 1,
      updatedAt: 1,
      active: true,
      activeAt: 1,
      metadataVersion: 1,
      agentStateVersion: 1,
      thinking: false,
      presence: 'online',
      metadata: Metadata(path: path, machineId: machineId, host: 'h'),
    );

    test('combines machineId and path with a colon', () {
      expect(
        sessionFolderKey(make(machineId: 'm1', path: '/home/dev/app')),
        'm1:/home/dev/app',
      );
    });

    test('treats missing metadata fields as empty strings', () {
      expect(sessionFolderKey(make()), ':');
      expect(sessionFolderKey(make(machineId: 'm1')), 'm1:');
      expect(sessionFolderKey(make(path: '/x')), ':/x');
    });

    test('matches the folderKey produced by groupAllSessionsByFolder', () {
      // This invariant is what makes select-all in folder view scope correctly
      // to the folder — the selection scope derived from sessionFolderKey must
      // equal the header.folderKey used by the list.
      final groups = groupAllSessionsByFolder(
        [
          Session(
            id: 'a',
            seq: 1,
            createdAt: 1,
            updatedAt: 1,
            active: true,
            activeAt: 1,
            metadataVersion: 1,
            agentStateVersion: 1,
            thinking: false,
            presence: 'online',
            metadata: const Metadata(
              path: '/home/dev/app',
              machineId: 'm1',
              host: 'h',
            ),
          ),
        ],
        const [],
        const {},
      );
      expect(groups, hasLength(1));
      expect(
        groups.single.header.folderKey,
        sessionFolderKey(groups.single.activeSessions.single),
      );
    });
  });
}
