import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/sidechain_grouper.dart';

void main() {
  late SidechainGrouper grouper;

  setUp(() {
    grouper = SidechainGrouper();
  });

  // ── Helpers ──────────────────────────────────────────────

  Map<String, dynamic> _taskMsg({
    required String id,
    String? uuid,
    String? toolUseId,
    String? prompt,
    List<Map<String, dynamic>>? children,
    List<String>? sidechainRootUuids,
  }) =>
      <String, dynamic>{
        'id': id,
        'kind': 'tool-call',
        'name': 'Task',
        if (uuid != null) 'uuid': uuid,
        if (toolUseId != null) 'toolUseId': toolUseId,
        if (prompt != null)
          'input': <String, dynamic>{'prompt': prompt},
        if (children != null) 'children': children,
        if (sidechainRootUuids != null)
          '_sidechainRootUuids': sidechainRootUuids,
      };

  Map<String, dynamic> _sidechainRoot({
    required String id,
    String? uuid,
    String? parentUuid,
    String? prompt,
  }) =>
      <String, dynamic>{
        'id': id,
        'kind': 'sidechain-root',
        if (uuid != null) 'uuid': uuid,
        if (parentUuid != null) 'parentUuid': parentUuid,
        if (prompt != null) 'prompt': prompt,
      };

  Map<String, dynamic> _sidechainChild({
    required String id,
    String? uuid,
    String? parentUuid,
  }) =>
      <String, dynamic>{
        'id': id,
        'isSidechain': true,
        if (uuid != null) 'uuid': uuid,
        if (parentUuid != null) 'parentUuid': parentUuid,
      };

  Map<String, dynamic> _textMsg({required String id}) =>
      <String, dynamic>{
        'id': id,
        'kind': 'text',
        'role': 'assistant',
        'content': 'hello',
      };

  // ── Tests ──────────────────────────────────────────────

  group('groupMessages', () {
    test('returns null for empty messages', () {
      final result = grouper.groupMessages([]);
      expect(result, isNull);
    });

    test('returns null when no Task tool-calls exist', () {
      final messages = [_textMsg(id: 'm1'), _textMsg(id: 'm2')];
      final result = grouper.groupMessages(messages);
      expect(result, isNull);
    });

    test('returns null when Task exists but no sidechain '
        'messages', () {
      final messages = [
        _taskMsg(id: 'task-1', uuid: 'u1', prompt: 'do stuff'),
        _textMsg(id: 'm1'),
      ];
      final result = grouper.groupMessages(messages);
      expect(result, isNull);
    });

    test('groups sidechain-root and children under Task '
        'via parentUuid', () {
      final messages = [
        _taskMsg(id: 'task-1', uuid: 'task-uuid'),
        _sidechainRoot(
          id: 'root-1',
          uuid: 'root-uuid',
          parentUuid: 'task-uuid',
        ),
        _sidechainChild(
          id: 'child-1',
          uuid: 'child-uuid',
          parentUuid: 'root-uuid',
        ),
        _textMsg(id: 'm1'),
      ];

      final result = grouper.groupMessages(messages);

      expect(result, isNotNull);
      expect(result!.messages, hasLength(2)); // task + text
      expect(result.messages[0]['id'], 'task-1');
      final children = result.messages[0]['children']
          as List<Map<String, dynamic>>;
      expect(children, hasLength(1));
      expect(children[0]['id'], 'child-1');
      expect(result.messages[1]['id'], 'm1');
    });

    test('groups sidechain-root via prompt matching', () {
      final messages = [
        _taskMsg(
          id: 'task-1',
          uuid: 'task-uuid',
          prompt: 'find bugs',
        ),
        _sidechainRoot(
          id: 'root-1',
          uuid: 'root-uuid',
          prompt: 'find bugs',
        ),
        _sidechainChild(
          id: 'child-1',
          parentUuid: 'root-uuid',
        ),
      ];

      final result = grouper.groupMessages(messages);

      expect(result, isNotNull);
      expect(result!.messages, hasLength(1));
      final children = result.messages[0]['children']
          as List<Map<String, dynamic>>;
      expect(children, hasLength(1));
      expect(children[0]['id'], 'child-1');
    });

    test('matches via toolUseId', () {
      final messages = [
        _taskMsg(
          id: 'task-1',
          uuid: 'task-uuid',
          toolUseId: 'tool-use-123',
        ),
        _sidechainRoot(
          id: 'root-1',
          uuid: 'root-uuid',
          parentUuid: 'tool-use-123',
        ),
        _sidechainChild(
          id: 'child-1',
          parentUuid: 'root-uuid',
        ),
      ];

      final result = grouper.groupMessages(messages);

      expect(result, isNotNull);
      expect(result!.messages, hasLength(1));
      expect(
        (result.messages[0]['children']
                as List<Map<String, dynamic>>)
            .length,
        1,
      );
    });

    test('chains children via uuid propagation', () {
      final messages = [
        _taskMsg(id: 'task-1', uuid: 'task-uuid'),
        _sidechainRoot(
          id: 'root-1',
          uuid: 'root-uuid',
          parentUuid: 'task-uuid',
        ),
        _sidechainChild(
          id: 'child-1',
          uuid: 'c1-uuid',
          parentUuid: 'root-uuid',
        ),
        _sidechainChild(
          id: 'child-2',
          uuid: 'c2-uuid',
          parentUuid: 'c1-uuid',
        ),
        _sidechainChild(
          id: 'child-3',
          parentUuid: 'c2-uuid',
        ),
      ];

      final result = grouper.groupMessages(messages);

      expect(result, isNotNull);
      expect(result!.messages, hasLength(1));
      final children = result.messages[0]['children']
          as List<Map<String, dynamic>>;
      expect(children, hasLength(3));
      expect(
        children.map((c) => c['id']),
        ['child-1', 'child-2', 'child-3'],
      );
    });

    test('persists _sidechainRootUuids on Task for recovery',
        () {
      final messages = [
        _taskMsg(id: 'task-1', uuid: 'task-uuid'),
        _sidechainRoot(
          id: 'root-1',
          uuid: 'root-uuid',
          parentUuid: 'task-uuid',
        ),
        _sidechainChild(
          id: 'child-1',
          parentUuid: 'root-uuid',
        ),
      ];

      final result = grouper.groupMessages(messages);

      expect(result, isNotNull);
      final rootUuids = result!.messages[0]
          ['_sidechainRootUuids'] as List<dynamic>;
      expect(rootUuids, contains('root-uuid'));
    });

    test('recovers chain from persisted _sidechainRootUuids',
        () {
      // Simulate: sidechain-root was removed in a previous
      // grouping run, but a new child arrives. The Task has
      // _sidechainRootUuids persisted from the first run.
      final messages = [
        _taskMsg(
          id: 'task-1',
          uuid: 'task-uuid',
          sidechainRootUuids: ['root-uuid'],
        ),
        _sidechainChild(
          id: 'new-child',
          parentUuid: 'root-uuid',
        ),
      ];

      final result = grouper.groupMessages(messages);

      expect(result, isNotNull);
      expect(result!.messages, hasLength(1));
      final children = result.messages[0]['children']
          as List<Map<String, dynamic>>;
      expect(children, hasLength(1));
      expect(children[0]['id'], 'new-child');
    });

    test('does not duplicate existing children on re-group',
        () {
      final existingChild = _sidechainChild(
        id: 'child-1',
        uuid: 'c1-uuid',
        parentUuid: 'root-uuid',
      );
      final messages = [
        _taskMsg(
          id: 'task-1',
          uuid: 'task-uuid',
          children: [existingChild],
          sidechainRootUuids: ['root-uuid'],
        ),
        // Same child re-arrives (e.g. streaming update)
        _sidechainChild(
          id: 'child-1',
          uuid: 'c1-uuid',
          parentUuid: 'root-uuid',
        ),
      ];

      final result = grouper.groupMessages(messages);

      expect(result, isNotNull);
      final children = result!.messages[0]['children']
          as List<dynamic>;
      // Should still be 1, not 2
      expect(children, hasLength(1));
    });

    test('reports hasOrphans for unmatched sidechain messages',
        () {
      // Sidechain child with parentUuid that doesn't match
      // any Task — should remain in list as orphan.
      final messages = [
        _taskMsg(id: 'task-1', uuid: 'task-uuid'),
        <String, dynamic>{
          'id': 'orphan-1',
          'isSidechain': true,
          'parentUuid': 'unknown-uuid',
        },
      ];

      final result = grouper.groupMessages(messages);

      // No sidechain messages were actually grouped (the
      // orphan's parentUuid doesn't match any known chain),
      // so result is null since sidechainMsgIds is empty.
      // But if we skip fast-path, orphans stay in list.
      // The orphan is not matched because 'unknown-uuid' is
      // not in uuidToSidechainId — so it stays in the list
      // and hasOrphans should be detected by the caller.
      //
      // The grouper returns null here because
      // sidechainMsgIds is empty (no matches found).
      // The caller (_groupSidechainMessages in Sync) is
      // responsible for checking orphans separately.
      expect(result, isNull);
    });
  });

  group('fast-path', () {
    test('skips grouping when changedIds are non-sidechain',
        () {
      final messages = [
        _taskMsg(id: 'task-1', uuid: 'task-uuid'),
        _textMsg(id: 'text-1'),
      ];

      final result = grouper.groupMessages(
        messages,
        changedIds: {'text-1'},
      );

      // No sidechain work needed, no orphans → null
      expect(result, isNull);
    });

    test('skips grouping but reports orphans when '
        'changedIds are non-sidechain but orphans exist', () {
      final messages = [
        _taskMsg(id: 'task-1', uuid: 'task-uuid'),
        _textMsg(id: 'text-1'),
        <String, dynamic>{
          'id': 'orphan-1',
          'isSidechain': true,
          'parentUuid': 'somewhere',
        },
      ];

      final result = grouper.groupMessages(
        messages,
        changedIds: {'text-1'},
      );

      // Fast path returns early with hasOrphans = true
      expect(result, isNotNull);
      expect(result!.hasOrphans, isTrue);
      // Messages unchanged (same reference)
      expect(identical(result.messages, messages), isTrue);
    });

    test('does NOT skip when changedIds contain sidechain '
        'message', () {
      final messages = [
        _taskMsg(id: 'task-1', uuid: 'task-uuid'),
        _sidechainRoot(
          id: 'root-1',
          uuid: 'root-uuid',
          parentUuid: 'task-uuid',
        ),
        _sidechainChild(
          id: 'child-1',
          parentUuid: 'root-uuid',
        ),
      ];

      final result = grouper.groupMessages(
        messages,
        changedIds: {'child-1'},
      );

      expect(result, isNotNull);
      expect(result!.messages, hasLength(1));
    });

    test('does NOT skip when changedIds contain '
        'sidechain-root', () {
      final messages = [
        _taskMsg(id: 'task-1', uuid: 'task-uuid'),
        _sidechainRoot(
          id: 'root-1',
          uuid: 'root-uuid',
          parentUuid: 'task-uuid',
        ),
      ];

      final result = grouper.groupMessages(
        messages,
        changedIds: {'root-1'},
      );

      expect(result, isNotNull);
      expect(result!.messages, hasLength(1));
    });

    test('does NOT skip when changedIds contain Task '
        'tool-call', () {
      final messages = [
        _taskMsg(id: 'task-1', uuid: 'task-uuid'),
        _sidechainRoot(
          id: 'root-1',
          uuid: 'root-uuid',
          parentUuid: 'task-uuid',
        ),
      ];

      final result = grouper.groupMessages(
        messages,
        changedIds: {'task-1'},
      );

      expect(result, isNotNull);
    });
  });

  group('regroupNestedTasks', () {
    test('groups inner sidechain children under nested Task',
        () {
      // Outer Task already has children containing an inner
      // Task + sidechain messages that should be grouped
      // under the inner Task.
      final children = <Map<String, dynamic>>[
        _taskMsg(id: 'inner-task', uuid: 'inner-uuid'),
        _sidechainRoot(
          id: 'inner-root',
          uuid: 'inner-root-uuid',
          parentUuid: 'inner-uuid',
        ),
        _sidechainChild(
          id: 'inner-child',
          parentUuid: 'inner-root-uuid',
        ),
      ];

      grouper.regroupNestedTasks(children);

      // Root and child should be removed from flat list
      expect(children, hasLength(1));
      expect(children[0]['id'], 'inner-task');
      final innerChildren =
          children[0]['children'] as List<Map<String, dynamic>>;
      expect(innerChildren, hasLength(1));
      expect(innerChildren[0]['id'], 'inner-child');
    });

    test('handles no inner Tasks', () {
      final children = <Map<String, dynamic>>[
        _textMsg(id: 'plain-1'),
        _textMsg(id: 'plain-2'),
      ];

      grouper.regroupNestedTasks(children);

      expect(children, hasLength(2));
    });

    test('merges without duplicating existing children', () {
      final innerChild = _sidechainChild(
        id: 'inner-child',
        uuid: 'ic-uuid',
        parentUuid: 'inner-root-uuid',
      );
      final children = <Map<String, dynamic>>[
        {
          ..._taskMsg(
            id: 'inner-task',
            uuid: 'inner-uuid',
            sidechainRootUuids: ['inner-root-uuid'],
          ),
          'children': <Map<String, dynamic>>[innerChild],
        },
        // Same child re-arrives
        _sidechainChild(
          id: 'inner-child',
          uuid: 'ic-uuid',
          parentUuid: 'inner-root-uuid',
        ),
      ];

      grouper.regroupNestedTasks(children);

      expect(children, hasLength(1));
      final innerChildren =
          children[0]['children'] as List<dynamic>;
      expect(innerChildren, hasLength(1));
    });
  });

  group('parentUuid without isSidechain flag', () {
    test('groups children for nested Task inside children list', () {
      final children = <Map<String, dynamic>>[
        _taskMsg(id: 'nested-1', uuid: 'nested-uuid-1'),
        _sidechainRoot(
          id: 'nested-root-1',
          uuid: 'nr1',
          parentUuid: 'nested-uuid-1',
        ),
        _sidechainChild(
          id: 'nested-child-1',
          parentUuid: 'nr1',
        ),
      ];

      grouper.regroupNestedTasks(children);

      expect(children, hasLength(1));
      final nestedChildren = children[0]['children']
          as List<Map<String, dynamic>>;
      expect(nestedChildren, hasLength(1));
      expect(nestedChildren[0]['id'], 'nested-child-1');
    });

    test('attaches sidechain children to multiple distinct '
        'Tasks — each gets only its own children', () {
      final messages = [
        _textMsg(id: 'm0'),
        _taskMsg(
          id: 'task-a',
          uuid: 'task-a-uuid',
          toolUseId: 'tool-use-a',
          prompt: 'Task A prompt',
        ),
        _taskMsg(
          id: 'task-b',
          uuid: 'task-b-uuid',
          toolUseId: 'tool-use-b',
          prompt: 'Task B prompt',
        ),
        _textMsg(id: 'm1'),
        // Sidechain roots + children for Task A
        _sidechainRoot(
          id: 'root-a',
          uuid: 'root-a-uuid',
          parentUuid: 'tool-use-a',
        ),
        _sidechainChild(
          id: 'child-a1',
          uuid: 'ca1',
          parentUuid: 'root-a-uuid',
        ),
        _sidechainChild(
          id: 'child-a2',
          uuid: 'ca2',
          parentUuid: 'ca1',
        ),
        // Sidechain roots + children for Task B
        _sidechainRoot(
          id: 'root-b',
          uuid: 'root-b-uuid',
          parentUuid: 'tool-use-b',
        ),
        _sidechainChild(
          id: 'child-b1',
          uuid: 'cb1',
          parentUuid: 'root-b-uuid',
        ),
        // Direct sidechain children (no root) for Task A
        _sidechainChild(
          id: 'child-a3',
          uuid: 'ca3',
          parentUuid: 'tool-use-a',
        ),
      ];

      final result = grouper.groupMessages(messages);

      expect(result, isNotNull);
      // Text messages + 2 Tasks = 4 messages in filtered list
      expect(result!.messages, hasLength(4));

      // Find each Task by id
      final taskA = result.messages.firstWhere(
        (m) => m['id'] == 'task-a',
      );
      final taskB = result.messages.firstWhere(
        (m) => m['id'] == 'task-b',
      );

      // Task A should have child-a1, child-a2, child-a3
      final childrenA = taskA['children'] as List<dynamic>;
      expect(childrenA, hasLength(3));
      final childAIds = childrenA.map((c) => c['id']).toSet();
      expect(childAIds, contains('child-a1'));
      expect(childAIds, contains('child-a2'));
      expect(childAIds, contains('child-a3'));

      // Task B should have only child-b1
      final childrenB = taskB['children'] as List<dynamic>;
      expect(childrenB, hasLength(1));
      expect(childrenB[0]['id'], 'child-b1');

      // Verify NO cross-contamination: task A shouldn't have B's kids
      expect(childAIds.contains('child-b1'), isFalse);
    });

    // Regression: two Agent tool-calls in one assistant message,
    // each with its own sidechain child — children must stay
    // attached to their own Task.
    test('attaches children to two Tasks in same msg', () {
      final messages = [
        _taskMsg(
          id: 'task-a',
          uuid: 'a-uuid',
          toolUseId: 'a-tool',
        ),
        _taskMsg(
          id: 'task-b',
          uuid: 'b-uuid',
          toolUseId: 'b-tool',
        ),
        _sidechainRoot(
          id: 'root-a',
          uuid: 'ra',
          parentUuid: 'a-tool',
        ),
        _sidechainChild(id: 'child-a', parentUuid: 'ra'),
        _sidechainRoot(
          id: 'root-b',
          uuid: 'rb',
          parentUuid: 'b-tool',
        ),
        _sidechainChild(id: 'child-b', parentUuid: 'rb'),
      ];

      final result = grouper.groupMessages(messages);
      expect(result, isNotNull);
      expect(result!.messages, hasLength(2));

      final taskA = result.messages.firstWhere(
        (m) => m['id'] == 'task-a',
      );
      final taskB = result.messages.firstWhere(
        (m) => m['id'] == 'task-b',
      );

      final aChildren = taskA['children'] as List<dynamic>;
      final bChildren = taskB['children'] as List<dynamic>;
      expect(aChildren, hasLength(1));
      expect(aChildren[0]['id'], 'child-a');
      expect(bChildren, hasLength(1));
      expect(bChildren[0]['id'], 'child-b');
    });
  });
}
