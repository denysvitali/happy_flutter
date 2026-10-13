import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

void main() {
  const sessionId = 'user-scrollback';
  const firstSeq = 10000;
  final cap = Sync.maxVisibleSessionMessagesForTesting;
  late Sync sync;

  setUp(() {
    sync = createTestSync();
    sync.encryption = _HistoryEncryption();
    sync.testIsInitialized = true;
    sync.testSetVisibleSessionId(sessionId);
    sync.testSetSessionMessages(sessionId, [
      for (var seq = firstSeq; seq < firstSeq + cap; seq++) _row(seq),
    ]);
    sync.testSetSessionFirstLoadedSeq(sessionId, firstSeq);
    sync.testFetchOlderMessagesOverride = (_, afterSeq, limit) async => {
      'messages': [
        for (var seq = afterSeq + 1; seq <= afterSeq + limit; seq++)
          _wireRow(seq),
      ],
      'hasMore': false,
    };
  });

  tearDown(() {
    sync.returnToLatestMessages(sessionId);
    sync.testFetchOlderMessagesOverride = null;
    sync.testClearHistoryFullyLoaded(sessionId);
    sync.testClearHistoryTrimmed(sessionId);
    sync.testClearSessionMessageState(sessionId);
    sync.testSetVisibleSessionId(null);
  });

  test(
    'at-cap user page is visible and keeps the previous oldest anchor',
    () async {
      // Orphan coverage may be far behind the actual resident window.
      sync.testSetSessionFirstLoadedSeq(sessionId, 3000);
      await sync.fetchOlderMessages(sessionId, userInitiated: true);

      final rows = sync.testSessionMessages(sessionId)!;
      expect(rows.first['seq'], firstSeq - 100);
      expect(rows.any((row) => row['id'] == 'm-$firstSeq'), isTrue);
      expect(rows.last['seq'], firstSeq + cap - 1);
      expect(rows.length, cap + 100);
      expect(sync.scrollbackGapBeforeMessageId(sessionId), isNull);
      expect(sync.testSessionFirstLoadedSeq(sessionId), firstSeq - 100);
    },
  );

  test(
    'repeated user pages stay bounded with an explicit middle gap',
    () async {
      for (var page = 0; page < cap ~/ 100 + 3; page++) {
        final anchor = sync.testSessionMessages(sessionId)!.first['id'];
        await sync.fetchOlderMessages(sessionId, userInitiated: true);
        final rows = sync.testSessionMessages(sessionId)!;
        expect(rows.any((row) => row['id'] == anchor), isTrue);
        expect(rows.length, lessThanOrEqualTo(2 * cap));
      }
      final before = sync.testSessionMessages(sessionId)!.first['id'];
      final gap = sync.scrollbackGapBeforeMessageId(sessionId);
      expect(gap, isNotNull);
      expect(
        sync.testSessionMessages(sessionId)!.any((row) => row['id'] == gap),
        isTrue,
      );

      sync.testUpsertSessionMessages(sessionId, [
        for (var seq = firstSeq + cap; seq < firstSeq + 2 * cap; seq++)
          _row(seq),
      ]);
      final rows = sync.testSessionMessages(sessionId)!;
      expect(
        rows.first['id'],
        before,
        reason: 'live tail cannot evict scrollback',
      );
      expect(rows.last['seq'], firstSeq + 2 * cap - 1);
      expect(rows.length, 2 * cap);
      expect(sync.scrollbackGapBeforeMessageId(sessionId), isNotNull);
    },
  );

  test(
    'repeated sends, retry and out-of-order echoes keep canonical localId',
    () async {
      for (var page = 0; page < cap ~/ 100 + 3; page++) {
        await sync.fetchOlderMessages(sessionId, userInitiated: true);
      }
      sync.testUpsertSessionMessages(sessionId, [
        _pending('send-a', 0),
        _pending('send-b', firstSeq + 2 * cap),
      ]);
      sync.testUpsertSessionMessages(sessionId, [
        {..._pending('send-a', 0), 'sendStatus': 'sending'},
      ]);
      expect(
        sync
            .testSessionMessages(sessionId)!
            .where((row) => row['id'] == 'send-a')
            .single['localId'],
        'send-a',
      );

      final ackB = {
        ..._row(firstSeq + 2 * cap + 1),
        'localId': 'send-b',
        'role': 'user',
        'content': 'continue',
      };
      final ackA = {
        ..._row(firstSeq + 2 * cap),
        'localId': 'send-a',
        'role': 'user',
        'content': 'continue',
      };
      // Echo before REST, then REST before echo; identical text is not identity.
      sync.testUpsertSessionMessages(sessionId, [ackB]);
      sync.testUpsertSessionMessages(sessionId, [ackA, ackB]);
      sync.testUpsertSessionMessages(sessionId, [ackA]);
      final rows = sync.testSessionMessages(sessionId)!;
      expect(rows.where((row) => row['localId'] == 'send-a').length, 1);
      expect(rows.where((row) => row['localId'] == 'send-b').length, 1);
      expect(rows.any((row) => row['id'] == 'send-a'), isFalse);
      expect(rows.any((row) => row['id'] == 'send-b'), isFalse);
      expect(rows.map((row) => row['id']).toSet().length, rows.length);
      expect(rows.length, lessThanOrEqualTo(2 * cap));
    },
  );

  test('return latest clears gap and rearms resident older boundary', () async {
    for (var page = 0; page < cap ~/ 100 + 3; page++) {
      await sync.fetchOlderMessages(sessionId, userInitiated: true);
    }
    sync.returnToLatestMessages(sessionId);
    final rows = sync.testSessionMessages(sessionId)!;
    expect(rows.length, cap);
    expect(rows.first['seq'], firstSeq);
    expect(sync.scrollbackGapBeforeMessageId(sessionId), isNull);
    expect(sync.testSessionFirstLoadedSeq(sessionId), firstSeq);
    await sync.fetchOlderMessages(sessionId, userInitiated: true);
    expect(sync.testSessionMessages(sessionId)!.first['seq'], firstSeq - 100);
  });

  test(
    'expanded raw pages preserve the whole oldest anchor group and cursor',
    () async {
      final blocksPerEnvelope = cap ~/ 100 + 2;
      sync.testSetSessionMessages(sessionId, [
        for (var block = 0; block < 3; block++)
          {..._row(firstSeq), 'id': 'anchor-$block'},
        for (var seq = firstSeq + 1; seq < firstSeq + cap - 2; seq++) _row(seq),
      ]);
      sync.testFetchOlderMessagesOverride = (_, afterSeq, limit) async => {
        'messages': [
          for (var seq = afterSeq + 1; seq <= afterSeq + limit; seq++)
            _wireBlocks(seq, blocksPerEnvelope),
        ],
        'hasMore': false,
      };
      await sync.fetchOlderMessages(sessionId, userInitiated: true);
      var rows = sync.testSessionMessages(sessionId)!;
      for (var block = 0; block < 3; block++) {
        expect(rows.any((row) => row['id'] == 'anchor-$block'), isTrue);
      }
      expect(rows.length, lessThanOrEqualTo(2 * cap));
      final residentMin = rows.first['seq'] as int;
      expect(residentMin, greaterThan(firstSeq - 100));
      expect(
        sync.testSessionFirstLoadedSeq(sessionId),
        residentMin,
        reason: 'excluded earlier envelopes must remain fetchable',
      );
      expect(sync.hasOlderMessages(sessionId), isTrue);
      expect(sync.scrollbackGapBeforeMessageId(sessionId), isNotNull);
      expect(
        rows.where((row) => row['seq'] == residentMin).length,
        blocksPerEnvelope,
        reason: 'never retain only part of first envelope',
      );

      final priorOldestIds = rows
          .where((row) => row['seq'] == residentMin)
          .map((row) => row['id'])
          .toSet();
      await sync.fetchOlderMessages(sessionId, userInitiated: true);
      rows = sync.testSessionMessages(sessionId)!;
      expect(rows.first['seq'], lessThan(residentMin));
      expect(
        rows.map((row) => row['id']).toSet().containsAll(priorOldestIds),
        isTrue,
      );
      expect(rows.length, lessThanOrEqualTo(2 * cap));
    },
  );

  test(
    'expanded page reaching seq zero never skips excluded raw groups',
    () async {
      sync.testSetSessionMessages(sessionId, [
        for (var seq = 101; seq < 101 + cap; seq++) _row(seq),
      ]);
      sync.testFetchOlderMessagesOverride = (_, afterSeq, limit) async => {
        'messages': [
          for (var seq = afterSeq + 1; seq <= afterSeq + limit; seq++)
            _wireBlocks(seq, cap ~/ 100 + 2),
        ],
        'hasMore': false,
      };
      await sync.fetchOlderMessages(sessionId, userInitiated: true);
      final residentMin =
          sync.testSessionMessages(sessionId)!.first['seq'] as int;
      expect(residentMin, greaterThan(1));
      expect(sync.testSessionFirstLoadedSeq(sessionId), residentMin);
      expect(sync.hasOlderMessages(sessionId), isTrue);
    },
  );

  test(
    'indivisible expanded envelope fails visibly without losing cursor',
    () async {
      sync.testSetSessionMessages(sessionId, [
        for (var seq = 101; seq < 101 + cap; seq++) _row(seq),
      ]);
      sync.testSetSessionFirstLoadedSeq(sessionId, 101);
      sync.testFetchOlderMessagesOverride = (_, __, ___) async => {
        'messages': [_wireBlocks(100, cap)],
        'hasMore': false,
      };
      // The broadcast error stream delivers asynchronously after the fetch
      // completes; subscribe first and await the event itself.
      final error = sync.onPaginationError.first.timeout(
        const Duration(seconds: 2),
      );
      await sync.fetchOlderMessages(sessionId, userInitiated: true);
      expect(await error, sessionId);
      expect(sync.testSessionMessages(sessionId)!.first['seq'], 101);
      expect(sync.testSessionMessages(sessionId)!.length, cap);
      expect(sync.testSessionFirstLoadedSeq(sessionId), 101);
      expect(sync.hasOlderMessages(sessionId), isTrue);
      expect(sync.testHistoryFullyLoaded(sessionId), isFalse);
      expect(sync.scrollbackGapBeforeMessageId(sessionId), isNull);
    },
  );

  test(
    'split persistence restores only the live cache tail and its cursor',
    () async {
      for (var page = 0; page < cap ~/ 100 + 3; page++) {
        await sync.fetchOlderMessages(sessionId, userInitiated: true);
      }
      final historyBoundary = sync.testSessionFirstLoadedSeq(sessionId)!;
      final persistentCursor = sync
          .testFirstLoadedSeqForPersistence()[sessionId]!;
      final latest = sync.testLatestResidentMessages(sessionId)!;
      final cached = latest.skip(latest.length - 200).toList();
      expect(persistentCursor, firstSeq + cap - Sync.initialLoad);
      expect(persistentCursor, greaterThan(historyBoundary));
      expect(latest.first['seq'], firstSeq);
      expect(cached.every((row) => (row['seq'] as int) >= firstSeq), isTrue);

      // Simulate the cold-start cache/cursor restore. Test replacement clears
      // ephemeral scrollback, just like a runtime reset; only tail rows persist.
      sync.testClearSessionMessageState(sessionId);
      sync.testSetSessionMessages(sessionId, cached);
      sync.testSetSessionFirstLoadedSeq(sessionId, persistentCursor);
      await sync.fetchOlderMessages(sessionId, userInitiated: true);
      final rows = sync.testSessionMessages(sessionId)!;
      expect(rows.first['seq'], firstSeq + cap - 300);
      expect(rows.any((row) => row['seq'] == firstSeq + cap - 201), isTrue);
      expect(sync.scrollbackGapBeforeMessageId(sessionId), isNull);
    },
  );

  test(
    'shutdown-generation flush still excludes the retired split head',
    () async {
      for (var page = 0; page < cap ~/ 100 + 3; page++) {
        await sync.fetchOlderMessages(sessionId, userInitiated: true);
      }
      sync.testAdvanceRuntimeGeneration();
      final latest = sync.testLatestResidentMessages(sessionId)!;
      expect(latest.first['seq'], firstSeq);
      expect(latest.length, cap);
      expect(
        sync.testFirstLoadedSeqForPersistence()[sessionId],
        firstSeq + cap - Sync.initialLoad,
      );
      // The stale state is available only to persistence until reset; it
      // cannot provide a user cursor or visible gap to the next runtime.
      expect(sync.scrollbackGapBeforeMessageId(sessionId), isNull);
    },
  );

  test(
    'switching away and back discards split head before clearing gap',
    () async {
      for (var page = 0; page < cap ~/ 100 + 3; page++) {
        await sync.fetchOlderMessages(sessionId, userInitiated: true);
      }
      expect(sync.scrollbackGapBeforeMessageId(sessionId), isNotNull);
      sync.prepareSessionVisibility('other-history-chat');
      sync.prepareSessionVisibility(sessionId);
      expect(sync.scrollbackGapBeforeMessageId(sessionId), isNull);
      final rows = sync.testSessionMessages(sessionId)!;
      expect(rows.length, cap);
      expect(rows.first['seq'], firstSeq);
    },
  );

  test('recenter rejects a user page still waiting on HTTP', () async {
    await sync.fetchOlderMessages(sessionId, userInitiated: true);
    final response = Completer<Map<String, dynamic>>();
    sync.testFetchOlderMessagesOverride = (_, __, ___) => response.future;
    final pending = sync.fetchOlderMessages(sessionId, userInitiated: true);
    sync.returnToLatestMessages(sessionId);
    response.complete({
      'messages': [_wireRow(firstSeq - 200)],
    });
    await pending;
    expect(sync.testSessionMessages(sessionId)!.first['seq'], firstSeq);
    expect(sync.scrollbackGapBeforeMessageId(sessionId), isNull);
  });

  test(
    'user can reach the beginning even after a trimmed orphan walk',
    () async {
      sync.testSetSessionMessages(sessionId, [
        for (var seq = 101; seq < 101 + cap; seq++) _row(seq),
      ]);
      sync.testUpsertSessionMessages(sessionId, [_row(101 + cap)]);
      expect(sync.testHistoryTrimmed(sessionId), isTrue);
      await sync.fetchOlderMessages(sessionId, userInitiated: true);
      await sync.fetchOlderMessages(sessionId, userInitiated: true);
      expect(sync.testSessionMessages(sessionId)!.first['seq'], 1);
      expect(sync.hasOlderMessages(sessionId), isFalse);
      sync.testUpsertSessionMessages(sessionId, [_row(102 + cap)]);
      expect(sync.testSessionMessages(sessionId)!.first['seq'], 1);
      expect(sync.hasOlderMessages(sessionId), isFalse);
    },
  );

  test(
    'orphan walk keeps newest-N retention without enabling user state',
    () async {
      await sync.fetchOlderMessages(sessionId);
      final rows = sync.testSessionMessages(sessionId)!;
      expect(rows.length, cap);
      expect(rows.first['seq'], firstSeq);
      expect(sync.scrollbackGapBeforeMessageId(sessionId), isNull);
    },
  );
}

Map<String, dynamic> _row(int seq) => {
  'id': 'm-$seq',
  'seq': seq,
  'createdAt': 1700000000000 + seq * 1000,
  'role': 'agent',
  'kind': 'text',
  'content': 'message-$seq',
};

Map<String, dynamic> _pending(String localId, int time) => {
  'id': localId,
  'localId': localId,
  'seq': -1,
  'createdAt': 1700000000000 + time * 1000,
  'role': 'user',
  'kind': 'text',
  'content': 'continue',
  'sendStatus': 'failed',
};

Map<String, dynamic> _wireRow(int seq) => {
  ..._row(seq),
  'content': {
    't': 'encrypted',
    'c': base64Encode(
      utf8.encode(
        jsonEncode({
          'role': 'agent',
          'content': {
            'type': 'output',
            'data': {'type': 'assistant', 'message': 'message-$seq'},
          },
        }),
      ),
    ),
  },
};

Map<String, dynamic> _wireBlocks(int seq, int count) => {
  ..._row(seq),
  'content': {
    't': 'encrypted',
    'c': base64Encode(
      utf8.encode(
        jsonEncode({
          'role': 'agent',
          'content': {
            'type': 'output',
            'data': {
              'type': 'assistant',
              'message': {
                'role': 'assistant',
                'content': [
                  for (var block = 0; block < count; block++)
                    {'type': 'text', 'text': 'seq-$seq-block-$block'},
                ],
              },
            },
          },
        }),
      ),
    ),
  },
};

class _HistoryEncryption implements Encryption {
  final Map<String, SessionEncryption> _sessions = {};

  @override
  SessionEncryption? getSessionEncryption(String sessionId) =>
      _sessions.putIfAbsent(
        sessionId,
        () => SessionEncryption(
          sessionId: sessionId,
          encryptor: _HistoryEncryptor(),
          decryptor: _HistoryEncryptor(),
          cache: EncryptionCache(),
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HistoryEncryptor implements Encryptor {
  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async => data
      .map((item) => Uint8List.fromList(utf8.encode(jsonEncode(item))))
      .toList();

  @override
  Future<List<dynamic>> decrypt(List<Uint8List> data) async =>
      data.map((item) => jsonDecode(utf8.decode(item))).toList();
}
