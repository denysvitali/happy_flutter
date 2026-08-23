@Timeout(Duration(minutes: 10))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/utils/session_utils.dart';
import 'package:happy_flutter/features/sessions/widgets/session_list_helpers.dart';

import 'bench_runner.dart';
import 'fixtures.dart';

/// Session-collection compute benchmarks at Mission Control scale
/// (200 sessions, matching the production collection that exposed the
/// frozen-frame tail in ROADMAP).
///
/// Covers three shapes:
/// - cold sort (collection changed): full comparator path
/// - unchanged fast path (identity hit): what steady-state frames pay
/// - folder grouping for the workspace-grouped list
void main() {
  final reporter = BenchReporter(group: 'sessions');

  tearDownAll(() => reporter.finish());

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
    final sessions =
        _buildSessions(200).values.toList(growable: false);

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
