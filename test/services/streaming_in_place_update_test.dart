import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

/// Progressive-lag remediation, 2026-08-24 (seventh pass).
///
/// A streaming turn re-delivers the same agent row 20-50x/second. Those
/// updates used to fall through to the full merge path — a whole-list map
/// rebuild, a localId reverse index, an O(resident) prompt-echo scan per row,
/// a full list copy and an order re-check, per token — which is the measured
/// sustained 5-30 s jank window on chat.
///
/// The in-place tail update must stay strictly subordinate to the messaging
/// invariants: anything touching send identity, prompt echoes, user rows, or
/// list ordering has to keep using the full merge path.
void main() {
  late Sync sync;

  List<Map<String, dynamic>> rows(int count) =>
      List<Map<String, dynamic>>.generate(
        count,
        (i) => {
          'id': 'm-$i',
          'seq': i + 1,
          'createdAt': (i + 1) * 1000,
          'role': 'assistant',
          'content': 'row $i',
        },
      );

  setUp(() {
    sync = createTestSync();
    sync.testClearAllSessionMessageState();
    sync.testSetVisibleSessionId(null);
  });

  tearDown(() {
    sync.testClearAllSessionMessageState();
    sync.testSetVisibleSessionId(null);
  });

  test('a streaming update replaces the row in place without reordering or '
      'duplicating it', () {
    sync.testSetSessionMessages('s', rows(50));

    sync.testUpsertSessionMessages('s', [
      {
        'id': 'm-49',
        'seq': 50,
        'createdAt': 50000,
        'role': 'assistant',
        'content': 'row 49 with more tokens',
      },
    ]);

    final after = sync.messagesForSession('s');
    expect(after, hasLength(50), reason: 'an update must not append a row');
    expect(after.last['content'], 'row 49 with more tokens');
    expect(
      [for (final m in after) m['id']],
      [for (var i = 0; i < 50; i++) 'm-$i'],
      reason: 'ordering and identity must be untouched',
    );
  });

  test('repeated streaming updates keep exactly one logical row', () {
    sync.testSetSessionMessages('s', rows(30));

    for (var token = 0; token < 25; token++) {
      sync.testUpsertSessionMessages('s', [
        {
          'id': 'm-29',
          'seq': 30,
          'createdAt': 30000,
          'role': 'assistant',
          'content': 'streaming $token',
        },
      ]);
    }

    final after = sync.messagesForSession('s');
    expect(after, hasLength(30));
    expect(after.last['content'], 'streaming 24');
    expect(
      after.where((m) => m['id'] == 'm-29'),
      hasLength(1),
      reason: 'no duplicate logical message may appear',
    );
  });

  test('duplicate IDs within one append batch merge to the latest row', () {
    sync.testSetSessionMessages('s', rows(5));

    sync.testUpsertSessionMessages('s', [
      for (final content in ['partial', 'complete'])
        {
          'id': 'm-new',
          'seq': 6,
          'createdAt': 6000,
          'role': 'assistant',
          'content': content,
        },
    ]);

    final after = sync.messagesForSession('s');
    expect(after, hasLength(6));
    expect(after.where((m) => m['id'] == 'm-new'), hasLength(1));
    expect(after.last['content'], 'complete');
  });

  test('an older row moved beyond the tail replaces its original ID', () {
    sync.testSetSessionMessages('s', rows(50));

    sync.testUpsertSessionMessages('s', [
      {
        'id': 'm-0',
        'seq': 51,
        'createdAt': 51000,
        'role': 'assistant',
        'content': 'updated timestamp',
      },
    ]);

    final after = sync.messagesForSession('s');
    expect(after, hasLength(50));
    expect(after.where((m) => m['id'] == 'm-0'), hasLength(1));
    expect(after.last['content'], 'updated timestamp');
  });

  test('neighboring replacements compare their final timestamps', () {
    sync.testSetSessionMessages('s', rows(5));

    sync.testUpsertSessionMessages('s', [
      {
        'id': 'm-3',
        'seq': 4,
        'createdAt': 4900,
        'role': 'assistant',
        'content': 'moves after its neighbor',
      },
      {
        'id': 'm-4',
        'seq': 5,
        'createdAt': 4100,
        'role': 'assistant',
        'content': 'moves before its neighbor',
      },
    ]);

    final after = sync.messagesForSession('s');
    expect(after, hasLength(5));
    expect(after.map((m) => m['id']), ['m-0', 'm-1', 'm-2', 'm-4', 'm-3']);
  });

  test('batch replay preserves identical sends and their retry identities', () {
    sync.testSetSessionMessages('s', [
      for (final i in [1, 2])
        {
          'id': 'local-$i',
          'localId': 'local-$i',
          'seq': 0,
          'createdAt': 1000 * i,
          'role': 'user',
          'content': 'continue',
          'sendStatus': i == 1 ? 'failed' : 'sending',
        },
    ]);
    final secondAck = <String, dynamic>{
      'id': 'server-2',
      'localId': 'local-2',
      'seq': 2,
      'createdAt': 2000,
      'role': 'user',
      'content': 'continue',
      'sendStatus': 'sent',
    };

    sync.testUpsertSessionMessages('s', [
      secondAck,
      {...secondAck},
    ]);
    final pendingRetry = sync.messagesForSession('s');
    expect(pendingRetry, hasLength(2));
    expect(pendingRetry.first['id'], 'local-1');
    expect(pendingRetry.first['localId'], 'local-1');
    expect(pendingRetry.first['sendStatus'], 'failed');
    expect(pendingRetry.last['id'], 'server-2');

    sync.testUpsertSessionMessages('s', [
      {
        'id': 'server-1',
        'localId': 'local-1',
        'seq': 1,
        'createdAt': 1000,
        'role': 'user',
        'content': 'continue',
        'sendStatus': 'sent',
      },
      {...secondAck},
    ]);

    final delivered = sync.messagesForSession('s');
    expect(delivered.map((m) => m['id']), ['server-1', 'server-2']);
    expect(delivered.map((m) => m['localId']), ['local-1', 'local-2']);
    expect(delivered.every((m) => m['sendStatus'] == 'sent'), isTrue);
  });

  test('grouped sidechain children survive an in-place update', () {
    final seeded = rows(10);
    seeded[9] = {
      ...seeded[9],
      'children': [
        {'id': 'child-1'},
      ],
      '_sidechainRootUuids': ['root-1'],
    };
    sync.testSetSessionMessages('s', seeded);

    sync.testUpsertSessionMessages('s', [
      {
        'id': 'm-9',
        'seq': 10,
        'createdAt': 10000,
        'role': 'assistant',
        'content': 'updated by server',
      },
    ]);

    final updated = sync.messagesForSession('s').last;
    expect(updated['content'], 'updated by server');
    expect(
      (updated['children'] as List<dynamic>).single,
      containsPair('id', 'child-1'),
      reason:
          'the server copy carries no grouped children — dropping them '
          'strands the sidechain rows permanently',
    );
    expect((updated['_sidechainRootUuids'] as List<dynamic>).single, 'root-1');
  });

  group('identity-sensitive rows keep using the full merge path', () {
    test('an incoming row carrying a localId replaces the optimistic row by '
        'localId', () {
      final seeded = rows(5);
      seeded.add({
        'id': 'local-1',
        'localId': 'local-1',
        'seq': 6,
        'createdAt': 6000,
        'role': 'user',
        'content': 'continue',
      });
      sync.testSetSessionMessages('s', seeded);

      sync.testUpsertSessionMessages('s', [
        {
          'id': 'server-1',
          'localId': 'local-1',
          'seq': 6,
          'createdAt': 6000,
          'role': 'user',
          'content': 'continue',
        },
      ]);

      final after = sync.messagesForSession('s');
      expect(
        after.where((m) => m['localId'] == 'local-1'),
        hasLength(1),
        reason: 'optimistic replacement is by localId, never by position',
      );
      expect(after.last['id'], 'server-1');
    });

    test('a user row without a localId still goes through the merge path', () {
      final seeded = rows(5);
      seeded.add({
        'id': 'u-1',
        'seq': 6,
        'createdAt': 6000,
        'role': 'user',
        'content': 'hello',
      });
      sync.testSetSessionMessages('s', seeded);

      sync.testUpsertSessionMessages('s', [
        {
          'id': 'u-1',
          'seq': 6,
          'createdAt': 6000,
          'role': 'user',
          'content': 'hello',
        },
      ]);

      final after = sync.messagesForSession('s');
      expect(after.where((m) => m['id'] == 'u-1'), hasLength(1));
    });

    test('an out-of-order replacement is rejected and merged instead', () {
      sync.testSetSessionMessages('s', rows(10));

      // Rewriting m-5 with a timestamp past its successor must not be
      // applied in place — that would leave the list unsorted.
      sync.testUpsertSessionMessages('s', [
        {
          'id': 'm-5',
          'seq': 99,
          'createdAt': 99000,
          'role': 'assistant',
          'content': 'moved to the end',
        },
      ]);

      final after = sync.messagesForSession('s');
      expect(after, hasLength(10));
      final createdAts = [for (final m in after) m['createdAt'] as int];
      expect(
        createdAts,
        orderedEquals([...createdAts]..sort()),
        reason: 'the resident window must stay chronologically ordered',
      );
      expect(after.last['id'], 'm-5');
    });

    test('an update to a row outside the tail window uses the merge path', () {
      sync.testSetSessionMessages('s', rows(100));

      sync.testUpsertSessionMessages('s', [
        {
          'id': 'm-0',
          'seq': 1,
          'createdAt': 1000,
          'role': 'assistant',
          'content': 'ancient row edited',
        },
      ]);

      final after = sync.messagesForSession('s');
      expect(after, hasLength(100));
      expect(after.first['content'], 'ancient row edited');
      expect(after.first['id'], 'm-0');
    });
  });

  test('a genuinely new row still appends rather than updating', () {
    sync.testSetSessionMessages('s', rows(10));

    sync.testUpsertSessionMessages('s', [
      {
        'id': 'm-new',
        'seq': 11,
        'createdAt': 11000,
        'role': 'assistant',
        'content': 'fresh',
      },
    ]);

    final after = sync.messagesForSession('s');
    expect(after, hasLength(11));
    expect(after.last['id'], 'm-new');
  });
}
