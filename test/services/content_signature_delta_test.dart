import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

/// The decrypt pre-filter keys off `_sessionContentSignatures`. Upserts used
/// to rebuild that map from scratch — a fingerprint per row over the whole
/// up-to-1000-entry window, on the main isolate, once per fetched page. It is
/// now maintained incrementally, so these tests pin the invariants the
/// pre-filter depends on:
///
/// - every row currently in the window has a signature;
/// - no row that left the window keeps one (a stale entry would make the
///   pre-filter skip a message and it would never be merged).
void main() {
  const sessionId = 'sig-s1';
  late Sync sync;

  setUp(() {
    sync = createTestSync();
    sync.testClearSessionMessageState(sessionId);
  });

  tearDown(() {
    sync.testClearSessionMessageState(sessionId);
  });

  test('incremental upsert keeps a signature for every row in the window', () {
    sync.testUpsertSessionMessages(sessionId, [
      _msg('a', 1, 'alpha'),
      _msg('b', 2, 'beta'),
    ]);
    sync.testUpsertSessionMessages(sessionId, [_msg('c', 3, 'gamma')]);

    final signatures = sync.testContentSignatures(sessionId);
    for (final id in ['a', 'b', 'c']) {
      expect(
        signatures.containsKey(id),
        isTrue,
        reason: '$id is in the window and must have a signature',
      );
    }
  });

  test('an updated row gets a fresh signature', () {
    sync.testUpsertSessionMessages(sessionId, [_msg('a', 1, 'alpha')]);
    final before = sync.testContentSignatures(sessionId)['a'];

    sync.testUpsertSessionMessages(sessionId, [_msg('a', 1, 'alpha-edited')]);
    final after = sync.testContentSignatures(sessionId)['a'];

    expect(after, isNot(equals(before)));
  });

  test('rows trimmed out of the window lose their signature', () {
    // Fill past the non-visible cap so the trim drops the oldest rows.
    final cap = Sync.maxBackgroundSessionMessagesForTesting;
    sync.testUpsertSessionMessages(sessionId, [
      for (var i = 0; i < cap; i++) _msg('old-$i', i + 1, 'body-$i'),
    ]);
    expect(sync.testContentSignatures(sessionId).containsKey('old-0'), isTrue);

    // An out-of-order arrival forces the merge path (not the fast append).
    sync.testUpsertSessionMessages(sessionId, [
      _msg('new-1', cap + 10, 'new-body'),
      _msg('new-0', cap + 5, 'new-body'),
    ]);

    final signatures = sync.testContentSignatures(sessionId);
    final window = sync.testGetSessionMessages(sessionId);
    final windowIds = window.map((m) => m['id'] as String).toSet();

    expect(windowIds.contains('old-0'), isFalse, reason: 'trim precondition');
    expect(
      signatures.containsKey('old-0'),
      isFalse,
      reason: 'a trimmed row must not keep a signature',
    );
    for (final id in windowIds) {
      expect(
        signatures.containsKey(id),
        isTrue,
        reason: '$id survived the trim and must keep a signature',
      );
    }
  });
}

Map<String, dynamic> _msg(String id, int seq, String content) =>
    <String, dynamic>{
      'id': id,
      'seq': seq,
      'createdAt': 1700000000000 + seq,
      'role': 'agent',
      'kind': 'text',
      'content': content,
    };
