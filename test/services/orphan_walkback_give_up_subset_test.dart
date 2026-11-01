import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

/// Persisted orphan walk-back give-up contract.
///
/// Production (2026-10-31, session c6a146…): every reopen of one chat
/// re-walked its whole history in 500-row (~1.9 MB) pages to seq 0 looking
/// for parent Tasks a previous walk-back had already proven missing. The
/// smaller reopened window (cold-start cache or background trim) held only
/// some of the given-up orphans, so its parent set no longer *equalled* the
/// persisted marker. 79 such pages in 24 h, none of which found a parent,
/// sharing the link with the chat's own tail fetch and sends.
void main() {
  late Sync sync;
  late int fetchOlderCount;

  setUp(() {
    sync = createTestSync();
    sync.encryption = _FakeEncryption();
    sync.testIsInitialized = true;
    sync.testSetVisibleSessionId('s1');
    sync.testSessions['s1'] = _session('s1', lastSeq: 5000);
    fetchOlderCount = 0;
    sync.testFetchOlderMessagesOverride = (sessionId, afterSeq, limit) async {
      fetchOlderCount++;
      return {'messages': <Map<String, dynamic>>[], 'hasMore': true};
    };
  });

  tearDown(() {
    sync.testFetchOlderMessagesOverride = null;
    sync.testClearSessionMessageState('s1');
    sync.testSetVisibleSessionId(null);
  });

  /// Gives up on parents A, B and C with the whole history resident.
  Future<void> exhaustHistoryFor(List<String> parents) async {
    sync.testSetSessionMessages('s1', [
      for (var i = 0; i < parents.length; i++) _orphan('o$i', parents[i], i),
    ]);
    sync.testSetSessionFirstLoadedSeq('s1', 0);
    sync.testRunDeferredRegroupSweep('s1');
    await _drain();
  }

  test('a reopened window holding a subset of given-up orphans does not '
      'walk the history again', () async {
    await exhaustHistoryFor(['toolu_A', 'toolu_B', 'toolu_C']);
    expect(fetchOlderCount, 0, reason: 'history was already resident');
    expect(sync.testOrphanGiveUpParentKeys('s1'), {
      'toolu_A',
      'toolu_B',
      'toolu_C',
    });

    // Reopen with only the newest part of the window resident: older
    // history is available again, but the only orphan's parent is one the
    // exhausted walk-back already searched for.
    sync.testForgetOrphanWalkbackRuntimeState('s1');
    sync.testSetSessionMessages('s1', [_orphan('o2', 'toolu_C', 4900)]);
    sync.testSetSessionFirstLoadedSeq('s1', 4800);
    sync.testRunDeferredRegroupSweep('s1');
    await _drain();

    expect(
      fetchOlderCount,
      0,
      reason:
          'a subset of proven-missing parents must not trigger another '
          'full-history walk-back',
    );
  });

  test('an orphan with a parent outside the marker still walks back', () async {
    await exhaustHistoryFor(['toolu_A']);

    sync.testForgetOrphanWalkbackRuntimeState('s1');
    sync.testSetSessionMessages('s1', [
      _orphan('o0', 'toolu_A', 4900),
      _orphan('o-new', 'toolu_NEW', 4950),
    ]);
    sync.testSetSessionFirstLoadedSeq('s1', 4800);
    sync.testRunDeferredRegroupSweep('s1');
    await _drain();

    expect(
      fetchOlderCount,
      1,
      reason: 'a parent never searched for deserves its own walk-back',
    );
  });

  test('new sidechain children do not clear the marker; a parent '
      'arriving does', () async {
    await exhaustHistoryFor(['toolu_A', 'toolu_B']);

    // A new subagent streams children: before grouping they look like
    // orphans of a parent the marker has never seen.
    sync.testLiftOrphanGiveUp('s1', [_orphan('child', 'toolu_LIVE', 5001)]);
    expect(
      sync.testOrphanGiveUpParentKeys('s1'),
      {'toolu_A', 'toolu_B'},
      reason:
          'clearing here re-armed a full-history walk-back for the old '
          'proven-missing parents on every reopen',
    );

    sync.testLiftOrphanGiveUp('s1', [
      <String, dynamic>{
        'id': 'toolu_B',
        'kind': 'tool-call',
        'name': 'Agent',
        'seq': 5002,
        'createdAt': 5002,
      },
    ]);
    expect(
      sync.testOrphanGiveUpParentKeys('s1'),
      isNull,
      reason: 'a real parent Task must lift the give-up',
    );
  });

  test('a later give-up keeps the parents proven missing earlier', () async {
    await exhaustHistoryFor(['toolu_A', 'toolu_B']);

    // A disjoint group is later exhausted on its own.
    sync.testForgetOrphanWalkbackRuntimeState('s1');
    await exhaustHistoryFor(['toolu_X']);

    expect(sync.testOrphanGiveUpParentKeys('s1'), {
      'toolu_A',
      'toolu_B',
      'toolu_X',
    });

    sync.testForgetOrphanWalkbackRuntimeState('s1');
    sync.testSetSessionMessages('s1', [_orphan('o0', 'toolu_A', 4900)]);
    sync.testSetSessionFirstLoadedSeq('s1', 4800);
    sync.testRunDeferredRegroupSweep('s1');
    await _drain();
    expect(fetchOlderCount, 0);
  });
}

Map<String, dynamic> _orphan(String id, String parent, int seq) =>
    <String, dynamic>{
      'id': id,
      'isSidechain': true,
      'uuid': 'u-$id',
      'parentUuid': 'task-$parent',
      'parentToolUseId': parent,
      'role': 'agent',
      'kind': 'text',
      'seq': seq,
      'createdAt': seq,
    };

Future<void> _drain() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Session _session(String id, {required int lastSeq}) => Session(
  id: id,
  seq: 1,
  createdAt: 1700000000000,
  updatedAt: 1700000000000,
  active: true,
  activeAt: 1700000000000,
  metadataVersion: 1,
  agentStateVersion: 1,
  thinking: false,
  presence: 'offline',
  lastSeq: lastSeq,
);

class _FakeEncryption implements Encryption {
  final Map<String, SessionEncryption> _sessions = {};

  @override
  SessionEncryption? getSessionEncryption(String sessionId) =>
      _sessions.putIfAbsent(
        sessionId,
        () => SessionEncryption(
          sessionId: sessionId,
          encryptor: _JsonEncryptor(),
          decryptor: _JsonEncryptor(),
          cache: EncryptionCache(),
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _JsonEncryptor implements Encryptor {
  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async => [
    for (final item in data) Uint8List.fromList(utf8.encode(jsonEncode(item))),
  ];

  @override
  Future<List<dynamic>> decrypt(List<Uint8List> data) async => [
    for (final item in data) jsonDecode(utf8.decode(item)),
  ];
}
