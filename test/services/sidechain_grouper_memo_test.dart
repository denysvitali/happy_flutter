import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

/// Perf pass 9, 2026-08-25: sidechain-grouper revision memo.
///
/// Six of the nine production grouper call sites pass no `changedIds`, so
/// each one re-walked the whole resident transcript (up to 1000 rows, five
/// passes) even when nothing had changed since the previous pass. The memo
/// records the message-window mutation generation at which the last full
/// pass finished *clean* and skips a full pass requested at that same
/// generation. It must stay strictly subordinate to grouping correctness:
/// any mutation (append, replace, in-place streaming update, trim) re-arms
/// it, and orphan outcomes are never memoized so the deferred walk-back
/// sweep keeps working.
void main() {
  late Sync sync;
  const s = 'sess-memo';

  Map<String, dynamic> task(String id, int seq, {String? uuid}) => {
    'id': id,
    'seq': seq,
    'createdAt': seq * 1000,
    'kind': 'tool-call',
    'name': 'Task',
    'uuid': uuid ?? '$id-uuid',
    'role': 'assistant',
  };

  Map<String, dynamic> root(String id, int seq, String parentUuid) => {
    'id': id,
    'seq': seq,
    'createdAt': seq * 1000,
    'kind': 'sidechain-root',
    'uuid': '$id-uuid',
    'parentUuid': parentUuid,
    'isSidechain': true,
    'role': 'assistant',
  };

  Map<String, dynamic> child(String id, int seq, String parentUuid) => {
    'id': id,
    'seq': seq,
    'createdAt': seq * 1000,
    'isSidechain': true,
    'uuid': '$id-uuid',
    'parentUuid': parentUuid,
    'role': 'assistant',
    'content': 'child $id',
  };

  Map<String, dynamic> text(String id, int seq, [String? content]) => {
    'id': id,
    'seq': seq,
    'createdAt': seq * 1000,
    'kind': 'text',
    'role': 'assistant',
    'content': content ?? 'text $id',
  };

  List<Map<String, dynamic>> childrenOf(String taskId) {
    final row = sync
        .messagesForSession(s)
        .firstWhere((m) => m['id'] == taskId);
    return (row['children'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  setUp(() {
    sync = createTestSync();
    sync.testClearAllSessionMessageState();
    sync.testSetVisibleSessionId(s);
  });

  tearDown(() {
    sync.testClearAllSessionMessageState();
    sync.testSetVisibleSessionId(null);
  });

  test('a full pass over an unchanged window is skipped, and the grouped '
      'children survive the skip', () {
    sync.testSetSessionMessages(s, [
      task('t1', 1),
      root('r1', 2, 't1-uuid'),
      child('c1', 3, 'r1-uuid'),
      text('m1', 4),
    ]);

    sync.testGroupSidechainMessages(s);
    expect(sync.testSidechainGrouperRuns, 1);
    expect(childrenOf('t1').map((m) => m['id']), ['c1']);
    expect(sync.messagesForSession(s), hasLength(2));

    sync.testGroupSidechainMessages(s);
    sync.testGroupSidechainMessages(s);
    expect(sync.testSidechainGrouperRuns, 1, reason: 'memo hit');
    expect(sync.testSidechainGrouperSkips, 2);
    expect(childrenOf('t1').map((m) => m['id']), ['c1']);
    expect(sync.messagesForSession(s), hasLength(2));
  });

  test('a window with nothing to group is memoized too', () {
    sync.testSetSessionMessages(s, [text('m1', 1), text('m2', 2)]);
    sync.testGroupSidechainMessages(s);
    sync.testGroupSidechainMessages(s);
    expect(sync.testSidechainGrouperRuns, 1);
    expect(sync.testSidechainGrouperSkips, 1);
  });

  test('any message-window mutation re-arms the memo', () {
    sync.testSetSessionMessages(s, [
      task('t1', 1),
      root('r1', 2, 't1-uuid'),
      child('c1', 3, 'r1-uuid'),
    ]);
    sync.testGroupSidechainMessages(s);
    expect(sync.testSidechainGrouperRuns, 1);

    // A plain append (non-sidechain) still counts as a mutation.
    sync.testUpsertSessionMessages(s, [text('m1', 4)]);
    sync.testGroupSidechainMessages(s);
    expect(sync.testSidechainGrouperRuns, 2);
    expect(childrenOf('t1').map((m) => m['id']), ['c1']);

    // And the clean result is memoized again.
    sync.testGroupSidechainMessages(s);
    expect(sync.testSidechainGrouperRuns, 2);
  });

  test('a late sidechain child arriving without changedIds is still '
      'grouped', () {
    sync.testSetSessionMessages(s, [
      task('t1', 1),
      root('r1', 2, 't1-uuid'),
      child('c1', 3, 'r1-uuid'),
    ]);
    sync.testGroupSidechainMessages(s);
    sync.testGroupSidechainMessages(s);
    expect(sync.testSidechainGrouperSkips, 1);

    sync.testUpsertSessionMessages(s, [child('c2', 4, 'r1-uuid')]);
    sync.testGroupSidechainMessages(s);
    expect(sync.testSidechainGrouperRuns, 2);
    expect(childrenOf('t1').map((m) => m['id']), ['c1', 'c2']);
    expect(
      sync.messagesForSession(s).where((m) => m['isSidechain'] == true),
      isEmpty,
      reason: 'no sidechain row may remain in the flat list',
    );
  });

  test('an in-place streaming update (same list reference) is not '
      'mistaken for an unchanged window', () {
    sync.testSetSessionMessages(s, [
      task('t1', 1),
      root('r1', 2, 't1-uuid'),
      child('c1', 3, 'r1-uuid'),
      text('m1', 4, 'partial'),
    ]);
    sync.testGroupSidechainMessages(s);
    final before = sync.messagesForSession(s);

    sync.testUpsertSessionMessages(s, [text('m1', 4, 'partial plus tokens')]);
    final after = sync.messagesForSession(s);
    expect(after.last['content'], 'partial plus tokens');

    sync.testGroupSidechainMessages(s);
    expect(
      sync.testSidechainGrouperRuns,
      2,
      reason:
          'the mutation generation, not list identity '
          '(identical=${identical(before, after)}), drives the memo',
    );
  });

  test('orphan outcomes are never memoized and still schedule the '
      'deferred sweep', () {
    sync.testSetSessionMessages(s, [
      text('m1', 1),
      child('c1', 2, 'missing-root-uuid'),
    ]);

    sync.testGroupSidechainMessages(s);
    sync.testGroupSidechainMessages(s);
    sync.testGroupSidechainMessages(s);
    expect(sync.testSidechainGrouperRuns, 3, reason: 'orphans never memoized');
    expect(sync.testSidechainGrouperSkips, 0);
    expect(sync.testHasSidechainRegroupTimer(s), isTrue);
  });

  test('a late parent absorbs existing orphans, then the clean result '
      'is memoized', () {
    sync.testSetSessionMessages(s, [
      root('r1', 2, 't1-uuid'),
      child('c1', 3, 'r1-uuid'),
    ]);
    sync.testGroupSidechainMessages(s);
    expect(
      sync.messagesForSession(s).where((m) => m['isSidechain'] == true),
      hasLength(2),
      reason: 'orphans render inline until the parent arrives',
    );

    sync.testUpsertSessionMessages(s, [task('t1', 1)]);
    sync.testGroupSidechainMessages(s);
    expect(childrenOf('t1').map((m) => m['id']), ['c1']);
    expect(sync.messagesForSession(s), hasLength(1));

    final runs = sync.testSidechainGrouperRuns;
    sync.testGroupSidechainMessages(s);
    expect(sync.testSidechainGrouperRuns, runs);
  });

  test('the deferred sweep still re-runs the grouper after a mutation', () {
    sync.testSetSessionMessages(s, [
      root('r1', 2, 't1-uuid'),
      child('c1', 3, 'r1-uuid'),
    ]);
    sync.testGroupSidechainMessages(s);
    sync.testUpsertSessionMessages(s, [task('t1', 1)]);

    final runs = sync.testSidechainGrouperRuns;
    sync.testRunDeferredRegroupSweep(s);
    expect(sync.testSidechainGrouperRuns, runs + 1);
    expect(childrenOf('t1').map((m) => m['id']), ['c1']);
  });

  test('clearing a session resets its memo', () {
    sync.testSetSessionMessages(s, [text('m1', 1)]);
    sync.testGroupSidechainMessages(s);
    sync.testClearSessionMessageState(s);
    sync.testSetSessionMessages(s, [text('m1', 1)]);
    sync.testGroupSidechainMessages(s);
    expect(sync.testSidechainGrouperRuns, 2);
    expect(sync.testSidechainGrouperSkips, 0);
  });
}
