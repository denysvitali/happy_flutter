import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/utils/session_utils.dart';

/// Pure grouping invariants: date bucket boundaries, folder key derivation,
/// lossless folder grouping, and disambiguated display names.
void main() {
  Session buildSession(
    String id, {
    int updatedAt = 1000,
    int? lastMessageAt,
    int? activeAt,
    bool active = false,
    String presence = 'offline',
    String path = '/home/dev/app',
    String machineId = 'm1',
    String? host,
    String? homeDir = '/home/dev',
    String? summary,
  }) {
    return Session(
      id: id,
      seq: 1,
      createdAt: updatedAt,
      updatedAt: updatedAt,
      active: active,
      activeAt: activeAt ?? updatedAt,
      metadataVersion: 1,
      agentStateVersion: 1,
      thinking: false,
      presence: presence,
      lastMessageAt: lastMessageAt,
      metadata: Metadata(
        host: host ?? '$machineId-host',
        path: path,
        machineId: machineId,
        homeDir: homeDir,
        summary: summary == null
            ? null
            : Summary(text: summary, updatedAt: updatedAt),
      ),
    );
  }

  Machine buildMachine(String id, String displayName) {
    return Machine(
      id: id,
      seq: 1,
      createdAt: 1,
      updatedAt: 1,
      active: true,
      activeAt: 1,
      metadataVersion: 1,
      daemonStateVersion: 1,
      metadata: MachineMetadata(displayName: displayName, host: '$id-host'),
    );
  }

  group('groupSessionsByDateCategory boundaries', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int ms(DateTime date) => date.millisecondsSinceEpoch;

    DateGroup bucketOf(int updatedAt) {
      final grouped = groupSessionsByDateCategory([
        buildSession('probe', updatedAt: updatedAt),
      ]);
      expect(grouped.length, 1);
      return grouped.keys.single;
    }

    test('midnight today is Today; one millisecond earlier is Yesterday', () {
      expect(bucketOf(ms(today)), DateGroup.today);
      expect(bucketOf(ms(today) - 1), DateGroup.yesterday);
    });

    test('yesterday spans the whole previous calendar day', () {
      final yesterday = today.subtract(const Duration(days: 1));
      expect(bucketOf(ms(yesterday)), DateGroup.yesterday);
      expect(bucketOf(ms(yesterday) - 1), DateGroup.thisWeek);
    });

    test('this week covers two through six days ago, never seven', () {
      expect(
        bucketOf(ms(today.subtract(const Duration(days: 2)))),
        DateGroup.thisWeek,
      );
      expect(
        bucketOf(ms(today.subtract(const Duration(days: 6)))),
        DateGroup.thisWeek,
      );
      expect(
        bucketOf(ms(today.subtract(const Duration(days: 7)))),
        isIn([DateGroup.thisMonth, DateGroup.older]),
      );
    });

    test('dates in the current month beyond a week are This Month', () {
      final monthStart = DateTime(now.year, now.month);
      if (today.difference(monthStart).inDays < 8) {
        // Early in the month every pre-week day belongs to the previous
        // month; the Older assertion below still pins that branch.
        return;
      }
      expect(bucketOf(ms(monthStart)), DateGroup.thisMonth);
    });

    test('dates before this month and outside the recent week are Older', () {
      final monthStart = DateTime(now.year, now.month);
      // Recent days retain their week bucket across a month boundary.
      final outsideRecentWeek = monthStart.subtract(const Duration(days: 7));
      expect(bucketOf(ms(outsideRecentWeek)), DateGroup.older);
      expect(
        bucketOf(ms(today.subtract(const Duration(days: 400)))),
        DateGroup.older,
      );
    });

    test('cached message timestamp decides the bucket over updatedAt', () {
      final old = ms(today.subtract(const Duration(days: 400)));
      final grouped = groupSessionsByDateCategory([
        buildSession('probe', updatedAt: old),
      ], getLastMessageTimestamp: (_) => ms(today));
      expect(grouped.keys.single, DateGroup.today);
    });

    test('lastMessageAt decides the bucket when no cache timestamp exists', () {
      final old = ms(today.subtract(const Duration(days: 400)));
      final grouped = groupSessionsByDateCategory([
        buildSession('probe', updatedAt: old, lastMessageAt: ms(today) - 1),
      ]);
      expect(grouped.keys.single, DateGroup.yesterday);
    });

    test('never loses or duplicates a session across buckets', () {
      final random = Random(99);
      for (var round = 0; round < 50; round++) {
        final count = 1 + random.nextInt(30);
        final sessions = [
          for (var i = 0; i < count; i++)
            buildSession(
              'r$round-$i',
              updatedAt: ms(today) - random.nextInt(45 * 24 * 3600 * 1000),
            ),
        ];
        final grouped = groupSessionsByDateCategory(sessions);
        final ids = grouped.values.expand((list) => list.map((s) => s.id));
        expect(ids.length, count);
        expect(ids.toSet().length, count);
        expect(grouped.values.any((list) => list.isEmpty), isFalse);
      }
    });

    test('ties inside a bucket break by id regardless of input order', () {
      final pool = [
        for (var i = 0; i < 40; i++)
          buildSession(
            't-${i.toString().padLeft(2, '0')}',
            updatedAt: ms(today),
          ),
      ];
      final expected = pool.map((s) => s.id).toList()..sort();
      final random = Random(5);
      for (var round = 0; round < 50; round++) {
        final shuffled = [...pool]..shuffle(random);
        final grouped = groupSessionsByDateCategory(shuffled);
        expect(grouped[DateGroup.today]!.map((s) => s.id).toList(), expected);
      }
    });

    test('flat history list emits headers in display order', () {
      final items = groupSessionsByDate([
        buildSession('older', updatedAt: ms(today) - 400 * 24 * 3600 * 1000),
        buildSession('today', updatedAt: ms(today)),
        buildSession('yesterday', updatedAt: ms(today) - 1),
      ]);
      final shape = items
          .map(
            (item) => switch (item) {
              SessionHistoryDateHeader(:final date) => 'H:$date',
              SessionHistorySession(:final session) => 'S:${session.id}',
            },
          )
          .toList();
      expect(shape, [
        'H:Today',
        'S:today',
        'H:Yesterday',
        'S:yesterday',
        'H:Older',
        'S:older',
      ]);
    });
  });

  group('folder key derivation', () {
    test('same path on different machines yields distinct keys', () {
      final a = buildSession('a', machineId: 'm1', path: '/home/dev/app');
      final b = buildSession('b', machineId: 'm2', path: '/home/dev/app');
      expect(sessionFolderKey(a), 'm1:/home/dev/app');
      expect(sessionFolderKey(b), 'm2:/home/dev/app');
      expect(sessionFolderKey(a), isNot(sessionFolderKey(b)));
    });

    test('same machine and path share one key even when hosts differ', () {
      final a = buildSession('a', host: 'alpha');
      final b = buildSession('b', host: 'beta');
      expect(sessionFolderKey(a), sessionFolderKey(b));
    });

    test('groupAllSessionsByFolder splits machines but merges paths', () {
      final groups = groupAllSessionsByFolder(
        [buildSession('a1', machineId: 'm1', active: true, presence: 'online')],
        [
          buildSession('a2', machineId: 'm1'),
          buildSession('b1', machineId: 'm2'),
        ],
        {'m1': buildMachine('m1', 'Work Mac'), 'm2': buildMachine('m2', 'Box')},
      );
      expect(groups, hasLength(2));
      final byKey = {for (final g in groups) g.header.folderKey: g};
      expect(byKey.keys, containsAll(['m1:/home/dev/app', 'm2:/home/dev/app']));
      expect(byKey['m1:/home/dev/app']!.header.machineName, 'Work Mac');
      expect(byKey['m2:/home/dev/app']!.header.machineName, 'Box');
      expect(byKey['m1:/home/dev/app']!.header.displayPath, '~/app');
      expect(byKey['m1:/home/dev/app']!.header.sessionCount, 2);
      expect(byKey['m2:/home/dev/app']!.header.sessionCount, 1);
    });

    test('missing machine falls back to session host, then Unknown', () {
      final groups = groupAllSessionsByFolder(const [], [
        buildSession('h', machineId: 'ghost', host: 'ghost-host'),
        Session(
          id: 'bare',
          seq: 1,
          createdAt: 1,
          updatedAt: 1,
          active: false,
          activeAt: 1,
          metadataVersion: 1,
          agentStateVersion: 1,
          thinking: false,
        ),
      ], const {});
      final byKey = {for (final g in groups) g.header.folderKey: g};
      expect(byKey['ghost:/home/dev/app']!.header.machineName, 'ghost-host');
      expect(byKey[':']!.header.machineName, 'Unknown');
      expect(byKey[':']!.header.displayPath, 'Unknown');
    });
  });

  group('groupAllSessionsByFolder invariants', () {
    test('every session appears exactly once, in its own folder group', () {
      final random = Random(2026);
      const machines = ['m1', 'm2', 'm3'];
      const paths = ['/home/dev/a', '/home/dev/b', '/srv/c'];
      for (var round = 0; round < 50; round++) {
        final active = <Session>[];
        final inactive = <Session>[];
        final count = 1 + random.nextInt(40);
        for (var i = 0; i < count; i++) {
          final session = buildSession(
            'r$round-$i',
            machineId: machines[random.nextInt(machines.length)],
            path: paths[random.nextInt(paths.length)],
            updatedAt: 1000 + random.nextInt(50),
            active: random.nextBool(),
            presence: random.nextBool() ? 'online' : 'offline',
          );
          (random.nextBool() ? active : inactive).add(session);
        }
        final groups = groupAllSessionsByFolder(active, inactive, const {});
        final seen = <String>[];
        for (final group in groups) {
          for (final session in group.activeSessions) {
            expect(sessionFolderKey(session), group.header.folderKey);
            expect(active.map((s) => s.id), contains(session.id));
            seen.add(session.id);
          }
          for (final session in group.inactiveSessions) {
            expect(sessionFolderKey(session), group.header.folderKey);
            expect(inactive.map((s) => s.id), contains(session.id));
            seen.add(session.id);
          }
          expect(
            group.header.sessionCount,
            group.activeSessions.length + group.inactiveSessions.length,
          );
        }
        expect(seen.length, count, reason: 'round $round lost a session');
        expect(seen.toSet().length, count, reason: 'round $round duplicated');
        final keys = groups.map((g) => g.header.folderKey).toList();
        expect(keys.toSet().length, keys.length, reason: 'duplicate folder');
      }
    });

    test('folder order ties break by key; sessions by id', () {
      final random = Random(11);
      final pool = [
        for (final key in ['m1:/x', 'm1:/y', 'm2:/x'])
          for (var i = 0; i < 12; i++)
            buildSession(
              '${key.hashCode}-${i.toString().padLeft(2, '0')}',
              machineId: key.split(':').first,
              path: key.split(':').last,
              updatedAt: 777,
            ),
      ];
      for (var round = 0; round < 30; round++) {
        final shuffled = [...pool]..shuffle(random);
        final groups = groupAllSessionsByFolder(const [], shuffled, const {});
        expect(groups.map((g) => g.header.folderKey).toList(), [
          'm1:/x',
          'm1:/y',
          'm2:/x',
        ]);
        for (final group in groups) {
          final ids = group.inactiveSessions.map((s) => s.id).toList();
          expect(ids, [...ids]..sort());
        }
      }
    });

    test('latest activity and unread roll up from the right lists', () {
      final groups = groupAllSessionsByFolder(
        [
          buildSession(
            'live',
            updatedAt: 100,
            active: true,
            presence: 'online',
          ),
        ],
        [buildSession('old', updatedAt: 500)],
        const {},
        getLastMessageTimestamp: (id) => id == 'live' ? 900 : null,
        getUnreadCount: (id) => id == 'live' ? 3 : 7,
      );
      final header = groups.single.header;
      expect(header.latestActivityAt, 900);
      expect(header.activeSessionCount, 1);
      expect(header.inactiveSessionCount, 1);
      // Unread counts only aggregate active sessions.
      expect(header.unreadCount, 3);
      expect(header.hasUpdates, isTrue);
    });
  });

  group('groupSessionsByFolder (flat)', () {
    test('marks first/last/single entries per folder', () {
      final items = groupSessionsByFolder([
        buildSession('a1', path: '/a', updatedAt: 30),
        buildSession('a2', path: '/a', updatedAt: 20),
        buildSession('b1', path: '/b', updatedAt: 10),
      ], const {});
      final entries = items.whereType<SessionFolderEntry>().toList();
      final headers = items.whereType<SessionFolderHeader>().toList();
      expect(headers.map((h) => h.folderKey), ['m1:/a', 'm1:/b']);
      expect(entries.map((e) => e.session.id), ['a1', 'a2', 'b1']);
      expect(entries[0].isFirst, isTrue);
      expect(entries[0].isLast, isFalse);
      expect(entries[1].isLast, isTrue);
      expect(entries[2].isSingle, isTrue);
    });
  });

  group('getDisambiguatedSessionNames', () {
    test('identical fallback names get distinct id suffixes', () {
      final sessions = [
        buildSession('abcdef-1'),
        buildSession('ghijkl-2'),
        buildSession('mnopqr-3'),
      ];
      final names = getDisambiguatedSessionNames(sessions);
      expect(names, {
        'abcdef-1': 'app · abcdef',
        'ghijkl-2': 'app · ghijkl',
        'mnopqr-3': 'app · mnopqr',
      });
      expect(names.values.toSet().length, 3);
    });

    test('unique names and summaries stay untouched', () {
      final sessions = [
        buildSession('one', summary: 'Fix login'),
        buildSession('two', summary: 'Fix signup'),
        buildSession('three', path: '/home/dev/other'),
      ];
      expect(getDisambiguatedSessionNames(sessions), {
        'one': 'Fix login',
        'two': 'Fix signup',
        'three': 'other',
      });
    });

    test('identical summaries are disambiguated like identical paths', () {
      final names = getDisambiguatedSessionNames([
        buildSession('111111-a', summary: 'Refactor'),
        buildSession('222222-b', summary: 'Refactor'),
        buildSession('333333-c', path: '/home/dev/other'),
      ]);
      expect(names['111111-a'], 'Refactor · 111111');
      expect(names['222222-b'], 'Refactor · 222222');
      expect(names['333333-c'], 'other');
    });

    test('short ids are used whole and every id is mapped', () {
      final names = getDisambiguatedSessionNames([
        buildSession('ab'),
        buildSession('cd'),
      ]);
      expect(names.keys, containsAll(['ab', 'cd']));
      expect(names['ab'], 'app · ab');
      expect(names['cd'], 'app · cd');
    });
  });

  group('getSessionName', () {
    test('summary wins over the path segment', () {
      expect(getSessionName(buildSession('s', summary: 'Ship it')), 'Ship it');
    });

    test('workspace hashes are stripped from the last path segment', () {
      expect(
        getSessionName(
          buildSession('s', path: '/tmp/workspace-denys-6589959b66-pzg66'),
        ),
        'workspace-denys',
      );
    });

    test('missing metadata or empty path falls back to Unknown', () {
      expect(getSessionName(buildSession('s', path: '')), 'Unknown');
      expect(
        getSessionName(
          Session(
            id: 'bare',
            seq: 1,
            createdAt: 1,
            updatedAt: 1,
            active: false,
            activeAt: 1,
            metadataVersion: 1,
            agentStateVersion: 1,
            thinking: false,
          ),
        ),
        'Unknown',
      );
    });
  });
}
