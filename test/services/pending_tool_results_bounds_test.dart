import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/services/tool_result_processor.dart';

import '../helpers/test_helpers.dart';

/// Progressive-lag remediation, 2026-08-24.
///
/// `_pendingToolResults` grew for the process lifetime (a result whose
/// tool-call was trimmed out of the resident window is permanently
/// unmatchable) and the whole stale queue was re-scanned against every
/// resident row — allocating a full rebuilt list — on every socket batch
/// and fetch page. These tests pin the FIFO cap, the TTL expiry, the
/// no-match zero-allocation fast path, and the stuck-`running` walk-back
/// when a turn ends.
void main() {
  late Sync sync;

  List<Map<String, dynamic>> results(int count, {String prefix = 'tool'}) =>
      List<Map<String, dynamic>>.generate(
        count,
        (i) => {
          'toolUseId': '$prefix-$i',
          'result': 'output $i',
          'createdAt': i + 1,
        },
      );

  setUp(() {
    sync = createTestSync();
    // Sync is a singleton — clear queue state left by earlier tests.
    sync.testClearAllSessionMessageState();
    sync.testPendingToolResultNowMsOverride = 1000;
  });

  tearDown(() {
    sync.testPendingToolResultNowMsOverride = null;
    sync.testClearAllSessionMessageState();
    sync.testSessions.remove('s1');
  });

  group('pending tool-result queue bounds', () {
    test('queue is FIFO-capped per session', () {
      sync.testSetSessionMessages('s1', const []);
      sync.testApplyToolResults(
        's1',
        results(Sync.maxPendingToolResultsPerSession + 50),
      );

      final pending = sync.testPendingToolResults('s1');
      expect(pending, hasLength(Sync.maxPendingToolResultsPerSession));
      expect(
        pending.first['toolUseId'],
        'tool-50',
        reason: 'oldest entries must be the ones dropped',
      );
    });

    test('queued entries carry the local-clock stamp used for expiry', () {
      sync.testSetSessionMessages('s1', const []);
      sync.testApplyToolResults('s1', results(1));

      final pending = sync.testPendingToolResults('s1');
      expect(pending.single[Sync.pendingToolResultQueuedAtKey], 1000);
    });

    test('replaying the pending queue expires entries past the TTL', () {
      sync.testSetSessionMessages('s1', const []);
      sync.testApplyToolResults('s1', results(3));
      expect(sync.testPendingToolResults('s1'), hasLength(3));

      sync.testPendingToolResultNowMsOverride =
          1000 + Sync.pendingToolResultTtlMs + 1;
      // Replay path: production drain sites pass the queue itself.
      sync.testApplyToolResults('s1', sync.testPendingToolResults('s1'));

      expect(
        sync.testPendingToolResults('s1'),
        isEmpty,
        reason: 'expired unmatchable results must not be rescanned forever',
      );
    });

    test('entries within the TTL survive a replay and still match later', () {
      sync.testSetSessionMessages('s1', const []);
      sync.testApplyToolResults('s1', results(1));

      // Replay with no resident rows: nothing matches, nothing expires.
      sync.testApplyToolResults('s1', sync.testPendingToolResults('s1'));
      expect(sync.testPendingToolResults('s1'), hasLength(1));

      // The tool-call finally arrives; the queued result must apply.
      sync.testSetSessionMessages('s1', [
        {
          'id': 'm1',
          'seq': 1,
          'createdAt': 1,
          'kind': 'tool-call',
          'toolUseId': 'tool-0',
          'state': 'running',
        },
      ]);
      sync.testApplyToolResults('s1', sync.testPendingToolResults('s1'));

      final row = sync.testGetSessionMessages('s1').single;
      expect(row['state'], 'completed');
      expect(row['result'], 'output 0');
    });
  });

  group('ToolResultProcessor no-match fast path', () {
    test('returns the identical list when nothing matches', () {
      final processor = ToolResultProcessor();
      final messages = [
        {
          'id': 'm1',
          'kind': 'tool-call',
          'toolUseId': 'tool-a',
          'state': 'running',
          'children': [
            {'id': 'c1', 'kind': 'tool-call', 'toolUseId': 'tool-c'},
          ],
        },
      ];

      final result = processor.applyToolResults(messages, [
        {'toolUseId': 'tool-x', 'result': 'nope'},
      ]);

      expect(result.changed, isFalse);
      expect(
        identical(result.messages, messages),
        isTrue,
        reason:
            'the replay path runs per socket batch — a no-match pass must '
            'not rebuild the resident list',
      );
    });

    test('still matches a tool-call nested in children', () {
      final processor = ToolResultProcessor();
      final messages = [
        {
          'id': 'm1',
          'kind': 'tool-call',
          'toolUseId': 'tool-a',
          'state': 'completed',
          'children': [
            {
              'id': 'c1',
              'kind': 'tool-call',
              'toolUseId': 'tool-c',
              'state': 'running',
            },
          ],
        },
      ];

      final result = processor.applyToolResults(messages, [
        {'toolUseId': 'tool-c', 'result': 'child output', 'createdAt': 5},
      ]);

      expect(result.changed, isTrue);
      expect(result.matchedIds, {'tool-c'});
      final children =
          result.messages.single['children'] as List<Map<String, dynamic>>;
      expect(children.single['state'], 'completed');
    });
  });

  group('stuck running tool walk-back on turn end', () {
    Session session({required bool thinking}) => Session(
      id: 's1',
      seq: 1,
      createdAt: 1700000000000,
      updatedAt: 1700000000000,
      active: true,
      activeAt: 1700000000000,
      metadataVersion: 1,
      agentStateVersion: 1,
      thinking: thinking,
      presence: 'online',
      lastSeq: 1,
    );

    List<Map<String, dynamic>> seedRows() => [
      {
        'id': 'stuck',
        'seq': 1,
        'createdAt': 1,
        'kind': 'tool-call',
        'toolUseId': 'tool-stuck',
        'state': 'running',
      },
      {
        'id': 'parked',
        'seq': 2,
        'createdAt': 2,
        'kind': 'tool-call',
        'toolUseId': 'tool-parked',
        'state': 'running',
        'permission': {'id': 'tool-parked', 'status': 'pending'},
      },
      {
        'id': 'done',
        'seq': 3,
        'createdAt': 3,
        'kind': 'tool-call',
        'toolUseId': 'tool-done',
        'state': 'completed',
        'result': 'ok',
      },
      {
        'id': 'parent',
        'seq': 4,
        'createdAt': 4,
        'kind': 'tool-call',
        'toolUseId': 'tool-parent',
        'state': 'completed',
        'result': 'ok',
        'children': [
          {
            'id': 'child',
            'seq': 5,
            'createdAt': 5,
            'kind': 'tool-call',
            'toolUseId': 'tool-child',
            'state': 'running',
          },
        ],
      },
    ];

    Map<String, dynamic> rowById(String id) => sync
        .testGetSessionMessages('s1')
        .expand(
          (m) => [
            m,
            ...(m['children'] as List<dynamic>? ?? const [])
                .whereType<Map<String, dynamic>>(),
          ],
        )
        .firstWhere((m) => m['id'] == id);

    test('thinking true→false cancels running rows without results', () {
      sync.testSessions['s1'] = session(thinking: true);
      sync.testSetSessionMessages('s1', seedRows());

      sync.handleUpdate({'t': 'update-session', 'id': 's1', 'thinking': false});

      expect(rowById('stuck')['state'], 'canceled');
      expect(
        rowById('parked')['state'],
        'running',
        reason: 'a row waiting on an unresolved permission is parked, '
            'not stuck',
      );
      expect(rowById('done')['state'], 'completed');
      expect(rowById('child')['state'], 'canceled');
    });

    test('a thinking=false update on an already-idle session is a no-op', () {
      sync.testSessions['s1'] = session(thinking: false);
      sync.testSetSessionMessages('s1', seedRows());

      sync.handleUpdate({'t': 'update-session', 'id': 's1', 'thinking': false});

      expect(
        rowById('stuck')['state'],
        'running',
        reason: 'no transition means no evidence the turn just ended',
      );
    });

    test('a late result overwrites a canceled row', () {
      sync.testSessions['s1'] = session(thinking: true);
      sync.testSetSessionMessages('s1', seedRows());
      sync.handleUpdate({'t': 'update-session', 'id': 's1', 'thinking': false});
      expect(rowById('stuck')['state'], 'canceled');

      sync.testApplyToolResults('s1', [
        {'toolUseId': 'tool-stuck', 'result': 'late output', 'createdAt': 9},
      ]);

      expect(rowById('stuck')['state'], 'completed');
      expect(rowById('stuck')['result'], 'late output');
    });
  });
}
