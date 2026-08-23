import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/utils/session_utils.dart';
import 'package:happy_flutter/features/sessions/widgets/session_list_helpers.dart';

/// Pure ordering invariants for the sessions collection: deterministic
/// tie-breaks, lossless active/inactive partition, optimistic-archive
/// exclusion, and the sorted-session cache.
void main() {
  final now = DateTime.now().millisecondsSinceEpoch;

  Session buildSession(
    String id, {
    bool archived = false,
    bool active = true,
    String presence = 'online',
    int? activeAt,
    int? updatedAt,
    int? lastMessageAt,
    String path = '/home/dev/app',
    String machineId = 'm1',
    String? name,
    String? summary,
  }) {
    return Session(
      id: id,
      seq: 1,
      createdAt: updatedAt ?? now - 1000,
      updatedAt: updatedAt ?? now - 1000,
      active: active,
      activeAt: activeAt ?? now - 1000,
      metadataVersion: 1,
      agentStateVersion: 1,
      thinking: false,
      archived: archived,
      presence: presence,
      lastMessageAt: lastMessageAt,
      metadata: Metadata(
        host: 'host',
        path: path,
        machineId: machineId,
        name: name,
        summary: summary == null
            ? null
            : Summary(text: summary, updatedAt: now),
      ),
    );
  }

  SortedSessions sortOnce(
    Map<String, Session> sessions, {
    Set<String> archived = const {},
    int? Function(String id)? timestamps,
    String query = '',
  }) {
    return computeSortedSessions(
      sessions,
      previous: null,
      lastSessions: null,
      lastSearchQuery: null,
      optimisticallyArchivedIds: archived,
      getLastMessageTimestamp: timestamps ?? (_) => null,
      searchQuery: query,
    );
  }

  /// Builds a session map whose iteration order follows [order].
  Map<String, Session> mapInOrder(List<Session> order) {
    return {for (final session in order) session.id: session};
  }

  group('computeSortedSessions ordering', () {
    test('equal timestamps tie-break by id regardless of insertion order', () {
      // 40 entries exceeds Dart's insertion-sort threshold so an unstable
      // sort would otherwise make the order depend on input position.
      final pool = [
        for (var i = 0; i < 40; i++)
          buildSession('s-${i.toString().padLeft(2, '0')}', activeAt: now),
      ];
      final expected = pool.map((s) => s.id).toList()..sort();
      final random = Random(42);
      for (var round = 0; round < 50; round++) {
        final shuffled = [...pool]..shuffle(random);
        final sorted = sortOnce(mapInOrder(shuffled));
        expect(sorted.inactive, isEmpty);
        expect(sorted.active.map((s) => s.id).toList(), expected);
      }
    });

    test('inactive ties break by id regardless of insertion order', () {
      final pool = [
        for (var i = 0; i < 40; i++)
          buildSession(
            'a-${i.toString().padLeft(2, '0')}',
            archived: true,
            active: false,
            presence: 'offline',
            updatedAt: 5000,
          ),
      ];
      final expected = pool.map((s) => s.id).toList()..sort();
      final random = Random(7);
      for (var round = 0; round < 50; round++) {
        final shuffled = [...pool]..shuffle(random);
        final sorted = sortOnce(mapInOrder(shuffled));
        expect(sorted.active, isEmpty);
        expect(sorted.inactive.map((s) => s.id).toList(), expected);
      }
    });

    test('newer timestamp wins; id only decides exact ties', () {
      final sessions = mapInOrder([
        buildSession('z-old', activeAt: now - 5000),
        buildSession('a-old', activeAt: now - 5000),
        buildSession('m-new', activeAt: now - 1000),
      ]);
      final sorted = sortOnce(sessions);
      expect(sorted.active.map((s) => s.id).toList(), [
        'm-new',
        'a-old',
        'z-old',
      ]);
    });

    test('online sessions precede offline ones regardless of timestamp', () {
      final sessions = mapInOrder([
        buildSession('offline-new', presence: 'offline', activeAt: now - 10),
        buildSession('online-old', activeAt: now - 100000),
      ]);
      final sorted = sortOnce(sessions);
      expect(sorted.active.map((s) => s.id).toList(), [
        'online-old',
        'offline-new',
      ]);
    });

    test('cached message timestamp outranks lastMessageAt and activeAt', () {
      final sessions = mapInOrder([
        buildSession('by-active', activeAt: now - 10),
        buildSession(
          'by-last-message',
          activeAt: now - 50000,
          lastMessageAt: now - 20,
        ),
        buildSession('by-cache', activeAt: now - 90000),
      ]);
      final sorted = sortOnce(
        sessions,
        timestamps: (id) => id == 'by-cache' ? now : null,
      );
      expect(sorted.active.map((s) => s.id).toList(), [
        'by-cache',
        'by-active',
        'by-last-message',
      ]);
    });
  });

  group('computeSortedSessions partition', () {
    test('every session lands in exactly one list across random mixes', () {
      final random = Random(1234);
      for (var round = 0; round < 50; round++) {
        final count = 5 + random.nextInt(40);
        final sessions = <Session>[];
        for (var i = 0; i < count; i++) {
          final archived = random.nextBool();
          sessions.add(
            buildSession(
              'r$round-s$i',
              archived: archived,
              active: !archived && random.nextBool(),
              presence: random.nextBool() ? 'online' : 'offline',
              activeAt: now - random.nextInt(100000),
            ),
          );
        }
        final sorted = sortOnce(mapInOrder(sessions));
        final seen = <String>[
          ...sorted.active.map((s) => s.id),
          ...sorted.inactive.map((s) => s.id),
        ];
        expect(seen.length, count, reason: 'round $round lost a session');
        expect(seen.toSet().length, count, reason: 'round $round duplicated');
        for (final session in sorted.active) {
          expect(isSessionActive(session), isTrue);
        }
        for (final session in sorted.inactive) {
          expect(isSessionActive(session), isFalse);
        }
      }
    });

    test('optimistically archived ids are hidden from both lists', () {
      final sessions = mapInOrder([
        buildSession('keep-active'),
        buildSession('hide-active'),
        buildSession('keep-inactive', archived: true, active: false),
        buildSession('hide-inactive', archived: true, active: false),
      ]);
      final sorted = sortOnce(
        sessions,
        archived: {'hide-active', 'hide-inactive'},
      );
      expect(sorted.active.map((s) => s.id), ['keep-active']);
      expect(sorted.inactive.map((s) => s.id), ['keep-inactive']);
    });

    test('search query matches name, path, or summary case-insensitively', () {
      final sessions = mapInOrder([
        buildSession('by-name', name: 'Rocket Launcher'),
        buildSession('by-path', path: '/home/dev/rocket-science'),
        buildSession('by-summary', summary: 'Fix the ROCKET'),
        buildSession('unrelated', name: 'Bike', path: '/home/dev/bike'),
      ]);
      final sorted = sortOnce(sessions, query: '  rOcKeT ');
      expect(sorted.active.map((s) => s.id).toSet(), {
        'by-name',
        'by-path',
        'by-summary',
      });
    });
  });

  group('computeSortedSessions cache', () {
    test('a fresh map with identical content reuses the previous result', () {
      final a = buildSession('a');
      final b = buildSession('b', archived: true, active: false);
      final first = sortOnce(mapInOrder([a, b]));
      final second = computeSortedSessions(
        mapInOrder([a, b]),
        previous: first,
        lastSessions: mapInOrder([a, b]),
        lastSearchQuery: '',
        optimisticallyArchivedIds: const {},
        getLastMessageTimestamp: (_) => null,
      );
      expect(identical(second, first), isTrue);
    });

    test('a changed cached timestamp invalidates the previous result', () {
      final a = buildSession('a');
      final b = buildSession('b');
      final sessions = mapInOrder([a, b]);
      final first = sortOnce(sessions, timestamps: (_) => now - 100);
      final second = computeSortedSessions(
        sessions,
        previous: first,
        lastSessions: sessions,
        lastSearchQuery: '',
        optimisticallyArchivedIds: const {},
        getLastMessageTimestamp: (id) => id == 'b' ? now : now - 100,
      );
      expect(identical(second, first), isFalse);
      expect(second.active.first.id, 'b');
    });

    test('newly archived id invalidates the previous result', () {
      final a = buildSession('a');
      final b = buildSession('b');
      final sessions = mapInOrder([a, b]);
      final first = sortOnce(sessions);
      final second = computeSortedSessions(
        sessions,
        previous: first,
        lastSessions: sessions,
        lastSearchQuery: '',
        optimisticallyArchivedIds: const {'a'},
        lastOptimisticallyArchivedIds: const {},
        getLastMessageTimestamp: (_) => null,
      );
      expect(identical(second, first), isFalse);
      expect(second.active.map((s) => s.id), ['b']);
    });
  });

  group('TabletSessionSelectionProjection', () {
    test('excludes archived sessions and tie-breaks equal activeAt by id', () {
      final pool = [
        buildSession('c', activeAt: 100),
        buildSession('a', activeAt: 100),
        buildSession('b', activeAt: 200),
        buildSession('archived', archived: true, activeAt: 900),
      ];
      final random = Random(3);
      for (var round = 0; round < 20; round++) {
        final shuffled = [...pool]..shuffle(random);
        final projection = TabletSessionSelectionProjection.fromSessions(
          mapInOrder(shuffled),
        );
        expect(projection.sessionIds, ['b', 'a', 'c']);
      }
    });

    test('equality follows the resulting id order only', () {
      final first = TabletSessionSelectionProjection.fromSessions(
        mapInOrder([buildSession('a', activeAt: 1)]),
      );
      final same = TabletSessionSelectionProjection.fromSessions(
        mapInOrder([buildSession('a', activeAt: 1, name: 'renamed')]),
      );
      final different = TabletSessionSelectionProjection.fromSessions(
        mapInOrder([buildSession('b', activeAt: 1)]),
      );
      expect(first, equals(same));
      expect(first, isNot(equals(different)));
    });
  });

  group('selectableSessionIds', () {
    final active = buildSession('active', path: '/p/one');
    final hidden = buildSession(
      'archived-one',
      archived: true,
      active: false,
      path: '/p/one',
    );
    final otherFolder = buildSession(
      'archived-two',
      archived: true,
      active: false,
      path: '/p/two',
    );

    test('hides archived rows when live sessions are present', () {
      final ids = selectableSessionIds(
        sessions: [active, hidden, otherFolder],
        hideInactive: true,
      );
      expect(ids, {'active'});
    });

    test('shows archived rows when nothing is live or hiding is off', () {
      expect(
        selectableSessionIds(
          sessions: [hidden, otherFolder],
          hideInactive: true,
        ),
        {'archived-one', 'archived-two'},
      );
      expect(
        selectableSessionIds(
          sessions: [active, hidden, otherFolder],
          hideInactive: false,
        ),
        {'active', 'archived-one', 'archived-two'},
      );
    });

    test('scopes to the open folder by folder key', () {
      final header = SessionFolderHeader(
        displayPath: '/p/two',
        machineName: 'host',
        sessionCount: 1,
        folderKey: sessionFolderKey(otherFolder),
      );
      final ids = selectableSessionIds(
        sessions: [active, hidden, otherFolder],
        hideInactive: true,
        folder: header,
      );
      expect(ids, {'archived-two'});
    });
  });

  group('inferProjectName', () {
    test('strips home prefixes and returns the first segment', () {
      expect(inferProjectName('/home/alice/projects/happy'), 'projects');
      expect(inferProjectName('/Users/bob/work/api'), 'work');
      expect(inferProjectName('~/work/api'), 'work');
      expect(inferProjectName('/tmp/scratch'), 'tmp');
    });

    test('falls back to the raw path when nothing meaningful remains', () {
      expect(inferProjectName('/home/alice'), '/home/alice');
      expect(inferProjectName('   '), '   ');
      expect(inferProjectName('/'), '/');
    });
  });

  group('ListItem descriptors', () {
    test('session rows carry the session they represent', () {
      final session = buildSession('row');
      final active = ListItem.activeSession(session, 3);
      expect(active.type, ListItemType.activeSession);
      expect(active.session?.id, 'row');
      expect(active.staggerIndex, 3);

      final archived = ListItem.archivedSession(
        session,
        4,
        isFirst: true,
        isLast: false,
        isSingle: false,
      );
      expect(archived.type, ListItemType.archivedSession);
      expect(identical(archived.session, session), isTrue);
      expect(archived.isFirst, isTrue);
      expect(archived.isLast, isFalse);
      expect(archived.isSingle, isFalse);

      final entry = ListItem.folderEntry(
        session,
        5,
        isFirst: true,
        isLast: true,
        isSingle: true,
      );
      expect(entry.type, ListItemType.folderEntry);
      expect(entry.session?.id, 'row');
      expect(entry.isSingle, isTrue);
    });

    test('header rows carry their grouping keys and counts', () {
      final date = ListItem.dateHeader('2026-08-23', 'Today', 2, 0);
      expect(date.type, ListItemType.dateHeader);
      expect(date.dateKey, '2026-08-23');
      expect(date.title, 'Today');
      expect(date.sessionCount, 2);

      final project = ListItem.projectHeader('happy', 4, 1, false, 1);
      expect(project.projectKey, 'happy');
      expect(project.sessionCount, 4);
      expect(project.activeSessionCount, 1);

      final path = ListItem.pathHeader('m1:/p', 3, false, 2);
      expect(path.pathKey, 'm1:/p');
      expect(path.sessionCount, 3);

      final header = SessionFolderHeader(
        displayPath: '~/p',
        machineName: 'host',
        sessionCount: 1,
        folderKey: 'm1:/p',
      );
      final folder = ListItem.folderHeader(header, 6);
      expect(folder.type, ListItemType.folderHeader);
      expect(folder.folderHeader?.folderKey, 'm1:/p');
      expect(folder.session, isNull);
    });
  });
}
