import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

/// Tests for orphan sidechain absorption.
///
/// Background: when a session's parent Task tool-call is missing from
/// the loaded message window (cache truncation, server pagination, or
/// a partial restore), all of that Task's sidechain children sit at
/// the top of the message list with `isSidechain: true`.  The chat
/// list filters those out (only grouped Task children are rendered)
/// and the AgentsListSheet enumerates only top-level Task tool-calls.
/// The net effect: 100+ messages can be silently invisible.
///
/// The fix detects stuck orphans in the deferred regroup sweep and
/// absorbs them into synthetic Task placeholders, which render as
/// normal Task rows in the chat and in the AgentsListSheet.
void main() {
  group('orphan recovery', () {
    late Sync sync;

    setUp(() {
      sync = createTestSync();
    });

    tearDown(() {
      sync.testClearSessionMessageState('s1');
    });

    test('absorbs orphan sidechains grouped by parentUuid into '
        'synthetic Task placeholders', () {
      sync.testSetSessionMessages('s1', [
        <String, dynamic>{
          'id': 'text-1',
          'kind': 'text',
          'role': 'user',
          'content': 'hello',
          'seq': 1,
          'createdAt': 100,
        },
        <String, dynamic>{
          'id': 'orph-1',
          'isSidechain': true,
          'parentUuid': 'parent-A',
          'uuid': 'u-1',
          'kind': 'text',
          'role': 'agent',
          'content': 'A first',
          'seq': 2,
          'createdAt': 200,
        },
        <String, dynamic>{
          'id': 'orph-2',
          'isSidechain': true,
          'parentUuid': 'parent-A',
          'uuid': 'u-2',
          'kind': 'text',
          'role': 'agent',
          'content': 'A second',
          'seq': 3,
          'createdAt': 300,
        },
        <String, dynamic>{
          'id': 'orph-3',
          'isSidechain': true,
          'parentUuid': 'parent-B',
          'uuid': 'u-3',
          'kind': 'text',
          'role': 'agent',
          'content': 'B first',
          'seq': 4,
          'createdAt': 400,
        },
      ]);

      final absorbed = sync.testAbsorbOrphansIntoSyntheticTasks('s1');
      expect(absorbed, isTrue);

      final messages = sync.testGetSessionMessages('s1');
      // Original text + one synthetic Task per parentUuid (A, B).
      expect(messages, hasLength(3));

      // No top-level isSidechain entries remain.
      expect(
        messages.where((m) => m['isSidechain'] == true).toList(),
        isEmpty,
        reason: 'orphans must be moved off the top-level list',
      );

      final tasks = messages
          .where((m) =>
              m['kind'] == 'tool-call' && m['name'] == 'Task')
          .toList();
      expect(tasks, hasLength(2));

      // Synthetic Task A should contain its two children.
      final taskA = tasks.firstWhere(
        (t) => t['uuid'] == 'parent-A',
      );
      expect(taskA['_orphanRecovery'], isTrue);
      expect(taskA['id'], 'orphan-recovery-parent-A');
      final childrenA =
          (taskA['children'] as List).cast<Map<String, dynamic>>();
      expect(childrenA.map((c) => c['id']), ['orph-1', 'orph-2']);

      // Synthetic Task B should contain its single child.
      final taskB = tasks.firstWhere(
        (t) => t['uuid'] == 'parent-B',
      );
      final childrenB =
          (taskB['children'] as List).cast<Map<String, dynamic>>();
      expect(childrenB.map((c) => c['id']), ['orph-3']);
    });

    test('returns false when there are no orphan sidechains', () {
      sync.testSetSessionMessages('s1', [
        <String, dynamic>{
          'id': 'text-1',
          'kind': 'text',
          'role': 'user',
          'content': 'hello',
          'seq': 1,
        },
      ]);

      final absorbed = sync.testAbsorbOrphansIntoSyntheticTasks('s1');
      expect(absorbed, isFalse);

      final messages = sync.testGetSessionMessages('s1');
      expect(messages, hasLength(1));
      expect(messages.first['id'], 'text-1');
    });

    test('groups orphans without parentUuid into a single bucket', () {
      sync.testSetSessionMessages('s1', [
        <String, dynamic>{
          'id': 'orph-1',
          'isSidechain': true,
          'kind': 'text',
          'role': 'agent',
          'content': 'unparented A',
          'seq': 5,
        },
        <String, dynamic>{
          'id': 'orph-2',
          'isSidechain': true,
          'kind': 'text',
          'role': 'agent',
          'content': 'unparented B',
          'seq': 6,
        },
      ]);

      final absorbed = sync.testAbsorbOrphansIntoSyntheticTasks('s1');
      expect(absorbed, isTrue);

      final messages = sync.testGetSessionMessages('s1');
      expect(messages, hasLength(1));
      final task = messages.first;
      expect(task['kind'], 'tool-call');
      expect(task['name'], 'Task');
      expect(task['uuid'], isNull,
          reason: 'unparented orphans must not invent a uuid');
      final children =
          (task['children'] as List).cast<Map<String, dynamic>>();
      expect(children.map((c) => c['id']), ['orph-1', 'orph-2']);
    });

    test('synthetic Task uses the earliest seq and createdAt of its '
        'children (sort stability)', () {
      sync.testSetSessionMessages('s1', [
        <String, dynamic>{
          'id': 'orph-late',
          'isSidechain': true,
          'parentUuid': 'parent-A',
          'kind': 'text',
          'seq': 50,
          'createdAt': 5000,
        },
        <String, dynamic>{
          'id': 'orph-early',
          'isSidechain': true,
          'parentUuid': 'parent-A',
          'kind': 'text',
          'seq': 10,
          'createdAt': 1000,
        },
      ]);

      sync.testAbsorbOrphansIntoSyntheticTasks('s1');

      final messages = sync.testGetSessionMessages('s1');
      final task = messages.first;
      expect(task['seq'], 10);
      expect(task['createdAt'], 1000);
    });

    test('synthetic Task uuid lets future orphan-grouping passes '
        'attach later sidechains for the same parent', () {
      // Cold start: cache restore yields orphans with no Task in
      // the list.  Absorb them; a brand-new sidechain then arrives
      // via socket inline processing.  When the grouper next runs
      // (e.g. after onSessionVisible re-fetch), the synthetic
      // Task's uuid==parentUuid lets it index as a Task and the
      // new sidechain attaches naturally.
      sync.testSetSessionMessages('s1', [
        <String, dynamic>{
          'id': 'orph-1',
          'isSidechain': true,
          'parentUuid': 'parent-X',
          'kind': 'text',
          'seq': 1,
        },
      ]);

      sync.testAbsorbOrphansIntoSyntheticTasks('s1');

      final after = sync.testGetSessionMessages('s1');
      expect(after, hasLength(1));
      final synthetic = after.first;
      expect(synthetic['uuid'], 'parent-X');
      expect(synthetic['kind'], 'tool-call');
      expect(synthetic['name'], 'Task');
    });
  });
}
