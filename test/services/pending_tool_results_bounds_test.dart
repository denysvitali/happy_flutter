import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/power_diagnostics_otel_reporter.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/services/tool_result_processor.dart';

import '../helpers/test_helpers.dart';

class _BatchSessionEncryption implements SessionEncryption {
  _BatchSessionEncryption(this.batch);

  final ProcessedMessages batch;

  @override
  bool get canDecryptAes => true;

  @override
  Future<ProcessedMessages> decryptAndProcessMessages(
    List<Map<String, dynamic>> messages,
    String sessionId,
  ) async => batch;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BatchEncryption implements Encryption {
  _BatchEncryption(ProcessedMessages batch)
    : sessionEncryption = _BatchSessionEncryption(batch);

  final SessionEncryption sessionEncryption;

  @override
  SessionEncryption? getSessionEncryption(String sessionId) =>
      sessionEncryption;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
    PowerDiagnosticsOtelReporter.instance.resetDebugBumpTotals();
  });

  tearDown(() {
    sync.testPendingToolResultNowMsOverride = null;
    sync.testClearAllSessionMessageState();
    sync.testSessions.remove('s1');
  });

  group('pending tool-result queue bounds', () {
    test('duplicate toolUseId refreshes payload and re-arms one entry', () {
      sync.testApplyToolResults('s1', results(2));
      sync.testPendingToolResultNowMsOverride = 2000;
      sync.testApplyToolResults('s1', [
        {'toolUseId': 'tool-0', 'result': 'new output', 'createdAt': 10},
        {'toolUseId': 'tool-0', 'result': 'latest output', 'createdAt': 11},
      ]);

      final pending = sync.testPendingToolResults('s1');
      expect(pending, hasLength(2));
      expect(pending.last['toolUseId'], 'tool-0');
      expect(pending.last['result'], 'latest output');
      expect(pending.last[Sync.pendingToolResultQueuedAtKey], 2000);
      sync.testPendingToolResultNowMsOverride =
          1000 + Sync.pendingToolResultTtlMs + 1;
      sync.testApplyToolResults('s1', pending);
      expect(pending.single['toolUseId'], 'tool-0');
    });

    test('append prunes expired entries before charging cap losses', () {
      sync.testApplyToolResults(
        's1',
        results(Sync.maxPendingToolResultsPerSession),
      );
      sync.testPendingToolResultNowMsOverride =
          1000 + Sync.pendingToolResultTtlMs + 1;
      sync.testApplyToolResults('s1', results(1, prefix: 'fresh'));

      final pending = sync.testPendingToolResults('s1');
      expect(pending, hasLength(1));
      expect(pending.single['toolUseId'], 'fresh-0');
      expect(
        PowerDiagnosticsOtelReporter
            .instance
            .debugBumpTotals['happy_flutter.tool_results.dropped'],
        isNull,
      );
    });

    test('ingestion replays pending before inserting fresh results', () async {
      sync.testApplyToolResults(
        's1',
        results(Sync.maxPendingToolResultsPerSession),
      );
      sync.encryption = _BatchEncryption(
        ProcessedMessages(
          messages: [
            {
              'id': 'arriving-call',
              'seq': 1,
              'createdAt': 1,
              'kind': 'tool-call',
              'toolUseId': 'tool-0',
              'state': 'running',
            },
          ],
          toolResults: results(1, prefix: 'fresh'),
          usageUpdates: const [],
          maxSeq: 1,
        ),
      );

      await sync.ingestFromHttp(
        FetchResponseBatch(
          sessionId: 's1',
          rawMessages: [
            {'id': 'wire-1', 'seq': 1, 'content': 'encrypted'},
          ],
          traceId: 'pending-replay-order',
          isVisibleSession: true,
        ),
        applyMutations: true,
      );

      final row = sync.testSessionMessages('s1')!.single;
      expect(row['state'], 'completed');
      expect(row['result'], 'output 0');
      final pending = sync.testPendingToolResults('s1');
      expect(pending, hasLength(Sync.maxPendingToolResultsPerSession));
      expect(pending.any((r) => r['toolUseId'] == 'tool-0'), isFalse);
      expect(pending.last['toolUseId'], 'fresh-0');
      expect(
        PowerDiagnosticsOtelReporter
            .instance
            .debugBumpTotals['happy_flutter.tool_results.dropped'],
        isNull,
      );
    });

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

    // A dropped result can never be matched to its tool call, so the row
    // renders without its output. This used to be INFO-only with no counter,
    // which hid the loss from any `> 0` alert (2026-09-14 audit: six drops in
    // 3.4 s on one live session).
    test('overflow is counted, not just logged', () {
      sync.testSetSessionMessages('s1', const []);
      const overflow = 50;
      sync.testApplyToolResults(
        's1',
        results(Sync.maxPendingToolResultsPerSession + overflow),
      );

      expect(
        PowerDiagnosticsOtelReporter
            .instance
            .debugBumpTotals['happy_flutter.tool_results.dropped'],
        overflow,
      );
    });
  });

  // GlitchTip 8832 / 8831: the sidechain orphan sweep calls
  // `fetchOlderMessages`, which merges a page from far behind the resident
  // window and then immediately trims it away. Every tool result on that page
  // is unmatchable by construction, yet they were all queued — one page on
  // session c11a301a contributed 154 of them, pushed the queue past its cap
  // and dropped the 151 oldest entries, which were the results still waiting
  // for a tool-call that had not arrived yet.
  group('history backfill must not queue unmatchable tool results', () {
    List<Map<String, dynamic>> residentCalls(List<String> ids) => [
      for (final id in ids)
        {'kind': 'tool-call', 'toolUseId': id, 'state': 'running'},
    ];

    test('a backfill burst leaves genuinely pending results untouched', () {
      sync.testSetSessionMessages('s1', residentCalls(const ['resident-1']));

      // A result whose tool-call is still in flight over the socket: this is
      // exactly what the queue exists for, and it must survive.
      sync.testApplyToolResults('s1', results(1, prefix: 'waiting'));
      expect(sync.testPendingToolResults('s1'), hasLength(1));

      // History backfill far behind the window — none of these can match.
      sync.testApplyToolResults(
        's1',
        results(Sync.maxPendingToolResultsPerSession + 50, prefix: 'backfill'),
        queueUnmatched: false,
      );

      final pending = sync.testPendingToolResults('s1');
      expect(pending, hasLength(1));
      expect(pending.single['toolUseId'], 'waiting-0');
      expect(
        PowerDiagnosticsOtelReporter
            .instance
            .debugBumpTotals['happy_flutter.tool_results.dropped'],
        isNull,
        reason: 'nothing matchable should have been evicted',
      );
    });

    test('the socket path still queues results whose call has not arrived', () {
      sync.testSetSessionMessages('s1', residentCalls(const ['resident-1']));

      sync.testApplyToolResults('s1', results(2, prefix: 'late'));

      final pending = sync.testPendingToolResults('s1');
      expect(pending, hasLength(2));
      expect(
        pending.map((r) => r['toolUseId']),
        containsAll(<String>['late-0', 'late-1']),
      );
    });

    test(
      'a backfill result that does match its resident call still applies',
      () {
        sync.testSetSessionMessages('s1', residentCalls(const ['shared-0']));

        sync.testApplyToolResults(
          's1',
          results(1, prefix: 'shared'),
          queueUnmatched: false,
        );

        expect(sync.testPendingToolResults('s1'), isEmpty);
        expect(
          sync.testSessionMessages('s1')!.single['state'],
          'completed',
          reason: 'suppressing the queue must not suppress the match',
        );
      },
    );

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

  // GlitchTip 8869 / 8868: long-running subagents emit many sidechain
  // tool_result messages after their parent Task has left the resident
  // window. Those results cannot render, and 200 of them evicted a result
  // that was waiting for a live tool-call.
  group('sidechain result residency', () {
    test('orphan sidechain burst does not evict a live pending result', () {
      sync.testSetSessionMessages('s1', [
        {'kind': 'text', 'id': 'resident', 'createdAt': 1},
      ]);
      sync.testApplyToolResults('s1', results(1, prefix: 'waiting'));

      sync.testApplyToolResults('s1', [
        for (var i = 0; i < Sync.maxPendingToolResultsPerSession + 60; i++)
          {
            'toolUseId': 'sidechain-$i',
            'parentToolUseId': 'trimmed-task',
            'isSidechain': true,
            'result': 'output $i',
            'createdAt': i + 1,
          },
      ]);

      final pending = sync.testPendingToolResults('s1');
      expect(pending, hasLength(1));
      expect(pending.single['toolUseId'], 'waiting-0');
      expect(
        PowerDiagnosticsOtelReporter
            .instance
            .debugBumpTotals['happy_flutter.tool_results.dropped'],
        isNull,
      );
    });

    test('sidechain result waits for a child call under resident parent', () {
      sync.testSetSessionMessages('s1', [
        {
          'id': 'task',
          'kind': 'tool-call',
          'toolUseId': 'parent-task',
          'children': <Map<String, dynamic>>[],
        },
      ]);
      sync.testApplyToolResults('s1', [
        {
          'toolUseId': 'child-tool',
          'parentToolUseId': 'parent-task',
          'isSidechain': true,
          'result': 'child output',
          'createdAt': 2,
        },
      ]);
      expect(sync.testPendingToolResults('s1'), hasLength(1));

      sync.testSetSessionMessages('s1', [
        {
          'id': 'task',
          'kind': 'tool-call',
          'toolUseId': 'parent-task',
          'children': [
            {
              'id': 'child',
              'kind': 'tool-call',
              'toolUseId': 'child-tool',
              'state': 'running',
            },
          ],
        },
      ]);
      sync.testApplyToolResults('s1', sync.testPendingToolResults('s1'));

      final task = sync.testSessionMessages('s1')!.single;
      final children = task['children'] as List<dynamic>;
      expect(
        (children.single as Map<String, dynamic>)['result'],
        'child output',
      );
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
        reason:
            'a row waiting on an unresolved permission is parked, '
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
