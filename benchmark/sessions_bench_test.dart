@Timeout(Duration(minutes: 10))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/session_ui_state_notifier.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/utils/session_utils.dart';
import 'package:happy_flutter/features/sessions/widgets/mission_control_types.dart';
import 'package:happy_flutter/features/sessions/widgets/session_list_helpers.dart';
import 'package:riverpod/riverpod.dart';

import '../test/helpers/test_helpers.dart';
import 'bench_runner.dart';
import 'fixtures.dart';

/// Session-collection compute benchmarks at Mission Control scale
/// (200 sessions, matching the production collection that exposed the
/// frozen-frame tail in ROADMAP).
///
/// Also measures notifier publication at 500 sessions across repeated map
/// compactions with a live listener: preview-only, advancing timestamps,
/// unread/lane changes, and interleaved updates from 32 concurrent sessions.
///
/// Covers three collection shapes:
/// - cold sort (collection changed): full comparator path
/// - unchanged fast path (identity hit): what steady-state frames pay
/// - folder grouping for the workspace-grouped list
void main() {
  final reporter = BenchReporter(group: 'sessions');

  tearDownAll(() => reporter.finish());

  for (final workload in ['preview', 'timestamp', 'unread', 'concurrent']) {
    test('$workload publication at 500 sessions across compactions', () {
      const updatesPerIteration = 64;
      const iterations = 30;
      const warmup = 3;
      final sessions = _buildSessions(500);
      final targetId = sessions.keys.last;
      final concurrentIds = sessions.keys.toList().reversed.take(32).toList();
      final expectedUpdates = <String, int>{};
      createTestSync();
      sync
        ..testSessions.clear()
        ..testClearSpawnGuardState()
        ..testResetDataChangeCounters()
        ..testIsInitialized = true;
      sync.testSessions.addAll(sessions);
      for (final id in sessions.keys) {
        sync.testClearSessionMessageState(id);
        sync.testSeedUnread(id, 0);
      }
      final container = ProviderContainer();
      addTearDown(() {
        container.dispose();
        for (final id in sessions.keys) {
          sync.testClearSessionMessageState(id);
          sync.testSeedUnread(id, 0);
        }
        sync
          ..testSessions.clear()
          ..testClearSpawnGuardState()
          ..testIsInitialized = false;
      });
      String setPreview(int update) {
        final id = workload == 'concurrent'
            ? concurrentIds[update % concurrentIds.length]
            : targetId;
        expectedUpdates[id] = update;
        sync.testSetSessionMessages(id, [
          {
            'id': 'bench-preview',
            'localId': 'bench-local',
            'role': 'agent',
            'content': 'preview $update',
            'createdAt': workload == 'preview' || workload == 'unread'
                ? 2000
                : 2000 + update,
          },
        ]);
        if (workload == 'unread' || workload == 'concurrent') {
          // Each session alternates live/unread on successive visits.
          final visit = workload == 'concurrent'
              ? update ~/ concurrentIds.length
              : update;
          sync.testSeedUnread(id, visit.isOdd ? 2 : 0);
          sync.testSessions[id] = sessions[id]!.copyWith(
            presence: 'online',
            thinking: true,
          );
        }
        return id;
      }

      setPreview(0);
      final notifier = container.read(sessionUiStateNotifierProvider.notifier);
      final before = container.read(sessionUiStateNotifierProvider);
      var publications = 0;
      SessionUiState? published;
      final subscription = container.listen(sessionUiStateNotifierProvider, (
        _,
        next,
      ) {
        publications++;
        published = next;
      });
      addTearDown(subscription.close);
      var update = 0;
      // Include state publication and the live listener, not just derivation.
      // Each batch crosses the map's 16-layer compaction boundary repeatedly.
      reporter.measureSync(
        workload == 'preview'
            ? 'publish_last_session_500_compaction'
            : 'publish_${workload}_500_compaction',
        () {
          for (var i = 0; i < updatesPerIteration; i++) {
            final id = setPreview(++update);
            notifier.loadSessionFromSync(id);
          }
        },
        iterations: iterations,
        warmup: warmup,
        opsPerIteration: updatesPerIteration,
      );

      final after = container.read(sessionUiStateNotifierProvider);
      expect(update, (iterations + warmup) * updatesPerIteration);
      expect(publications, update);
      expect(published, same(after));
      expect(after.bySessionId.length, 500);
      if (workload == 'preview' || workload == 'unread') {
        expect(after.ordering, same(before.ordering));
      } else {
        expect(after.ordering.revision, before.ordering.revision + update);
      }
      if (workload == 'preview') {
        expect(after.missionControl, same(before.missionControl));
      } else {
        expect(after.missionControl, isNot(same(before.missionControl)));
      }
      for (final id in sessions.keys) {
        final lastUpdate = expectedUpdates[id];
        if (lastUpdate == null) {
          expect(after.bySessionId[id], same(before.bySessionId[id]));
          continue;
        }
        final entry = after.bySessionId[id]!;
        expect(entry.lastMessagePreview, 'preview $lastUpdate');
        expect(
          entry.lastMessageTimestamp,
          workload == 'preview' || workload == 'unread'
              ? 2000
              : 2000 + lastUpdate,
        );
        expect(after.ordering.timestamps[id], entry.lastMessageTimestamp);
        expect(
          after.missionControl.bySessionId[id]!.lastMessageTimestamp,
          entry.lastMessageTimestamp,
        );
        if (workload == 'unread' || workload == 'concurrent') {
          final visit = workload == 'concurrent'
              ? lastUpdate ~/ concurrentIds.length
              : lastUpdate;
          expect(entry.unreadCount, visit.isOdd ? 2 : 0);
          expect(
            after.missionControl.bySessionId[id]!.unreadCount,
            entry.unreadCount,
          );
          expect(
            missionLaneFor(sync.testSessions[id]!, entry),
            visit.isOdd ? MissionLane.unread : MissionLane.live,
          );
        }
      }
      for (final id in expectedUpdates.keys) {
        notifier.loadSessionFromSync(id);
      }
      expect(publications, update);
    });
  }

  test('sorted-sessions compute at 200 sessions', () {
    final sessions = _buildSessions(200);
    final timestamps = <String, int>{
      for (final s in sessions.values)
        s.id: s.updatedAt - (s.id.hashCode % 60000),
    };
    int? getTimestamp(String id) => timestamps[id];

    var total = -1;
    reporter.measureSync(
      'compute_sorted_sessions_200_cold',
      () {
        final out = computeSortedSessions(
          sessions,
          previous: null,
          lastSessions: null,
          lastSearchQuery: null,
          optimisticallyArchivedIds: const <String>{},
          getLastMessageTimestamp: getTimestamp,
        );
        total = out.active.length + out.inactive.length;
      },
      iterations: 30,
      warmup: 3,
    );
    expect(total, 200);
  });

  test('sorted-sessions identity fast path at 200 sessions', () {
    final sessions = _buildSessions(200);
    final timestamps = <String, int>{
      for (final s in sessions.values)
        s.id: s.updatedAt - (s.id.hashCode % 60000),
    };
    int? getTimestamp(String id) => timestamps[id];
    const revision = 'bench-revision';
    final previous = computeSortedSessions(
      sessions,
      previous: null,
      lastSessions: null,
      lastSearchQuery: null,
      optimisticallyArchivedIds: const <String>{},
      getLastMessageTimestamp: getTimestamp,
      timestampRevision: revision,
    );

    var calls = 0;
    reporter.measureSync(
      'compute_sorted_sessions_200_fastpath',
      () {
        final out = computeSortedSessions(
          sessions,
          previous: previous,
          lastSessions: sessions,
          lastSearchQuery: '',
          optimisticallyArchivedIds: const <String>{},
          getLastMessageTimestamp: getTimestamp,
          timestampRevision: revision,
          lastTimestampRevision: revision,
        );
        calls++;
        expect(identical(out, previous), isTrue);
      },
      iterations: 30,
      warmup: 3,
    );
    expect(calls, 33);
  });

  test('folder grouping across 8 workspaces, 200 sessions', () {
    final sessions = _buildSessions(200).values.toList(growable: false);

    var items = 0;
    reporter.measureSync(
      'group_all_sessions_by_folder_200',
      () {
        final grouped = groupSessionsByFolder(
          sessions,
          const <String, Machine>{},
          getLastMessageTimestamp: (id) => null,
        );
        items = grouped.length;
      },
      iterations: 30,
      warmup: 3,
    );
    expect(items, greaterThan(0));
  });
}

Map<String, Session> _buildSessions(int count) {
  final rows = makeSessionRows(count);
  return <String, Session>{
    for (final row in rows) row['id'] as String: Session.fromJson(row),
  };
}
