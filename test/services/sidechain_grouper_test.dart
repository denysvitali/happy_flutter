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

    test('matches direct children via Task message id', () {
      const taskId = 'dc41b5f7-4561-4d7e-a978-113873a47d61';
      const firstEventUuid = 'f2d38d3a-88ed-40b5-89c4-b0876b191205';
      const secondEventUuid = 'a7427d7e-819a-44ae-995a-58a508191bc8';
      const callId = 'call_function_ja15yjondy30_1';
      final messages = [
        _taskMsg(
          id: taskId,
          uuid: 'task-uuid',
        ),
        {
          ..._sidechainChild(
            id: 'agent-event-1',
            uuid: firstEventUuid,
            parentUuid: taskId,
          ),
          'kind': 'agent-event',
        },
        {
          ..._sidechainChild(
            id: 'tool-call-1',
            uuid: callId,
            parentUuid: taskId,
          ),
          'kind': 'tool-call',
          'name': 'Read',
        },
        {
          ..._sidechainChild(
            id: 'agent-event-2',
            uuid: secondEventUuid,
            parentUuid: callId,
          ),
          'kind': 'agent-event',
        },
      ];

      final result = grouper.groupMessages(messages);

      expect(result, isNotNull);
      expect(result!.hasOrphans, isFalse);
      expect(result.messages, hasLength(1));
      final children =
          result.messages.first['children'] as List<dynamic>;
      expect(
        children.map((c) => (c as Map<String, dynamic>)['id']),
        ['agent-event-1', 'tool-call-1', 'agent-event-2'],
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

    test('resolves out-of-order chain via transitive '
        'parentUuid walk', () {
      // Regression: subagent transcripts chain via the previous
      // sidechain message's uuid (not the parent Task uuid).
      // When a chain message is iterated before its direct
      // ancestor (e.g. due to seq/createdAt tie-breaks or
      // re-ordering after merge), the per-step memoization in
      // uuidToSidechainId hasn't seen the ancestor yet and the
      // child stays orphaned.  Pre-fix this fragmented one
      // subagent run into many singleton "Subagent output
      // (recovered)" tiles via _absorbOrphansIntoSyntheticTasks.
      //
      // Here the flat list deliberately presents child-3 first,
      // then child-2, then child-1, then the root. The grouper
      // must walk the parentUuid chain transitively through
      // sidechainByUuid to find the indexed Task.
      final messages = [
        _taskMsg(id: 'task-1', uuid: 'task-uuid'),
        _sidechainChild(
          id: 'child-3',
          uuid: 'c3-uuid',
          parentUuid: 'c2-uuid',
        ),
        _sidechainChild(
          id: 'child-2',
          uuid: 'c2-uuid',
          parentUuid: 'c1-uuid',
        ),
        _sidechainChild(
          id: 'child-1',
          uuid: 'c1-uuid',
          parentUuid: 'root-uuid',
        ),
        _sidechainRoot(
          id: 'root-1',
          uuid: 'root-uuid',
          parentUuid: 'task-uuid',
        ),
      ];

      final result = grouper.groupMessages(messages);

      expect(result, isNotNull);
      expect(result!.hasOrphans, isFalse,
          reason: 'every chain link must transitively '
              'resolve to the indexed Task');
      expect(result.messages, hasLength(1));
      final children = result.messages[0]['children']
          as List<Map<String, dynamic>>;
      final ids = children.map((c) => c['id']).toSet();
      expect(ids, {'child-1', 'child-2', 'child-3'});
    });

    test('long chain (50 messages) does not fragment into '
        'orphans', () {
      // Production symptom: a single subagent run with many
      // chained messages produced N "Subagent output
      // (recovered)" synthetic Tasks (one per orphan
      // parentUuid bucket).  This guards the long-chain
      // resolution when timestamps are equal and order is
      // partially reversed.
      const chainLength = 50;
      final chain = <Map<String, dynamic>>[];
      for (var i = 0; i < chainLength; i++) {
        final parent = i == 0 ? 'root-uuid' : 'c${i - 1}-uuid';
        chain.add(_sidechainChild(
          id: 'child-$i',
          uuid: 'c$i-uuid',
          parentUuid: parent,
        ));
      }
      // Reverse half the chain to break iteration order.
      final shuffled = [
        ...chain.sublist(chainLength ~/ 2).reversed,
        ...chain.sublist(0, chainLength ~/ 2),
      ];
      final messages = [
        _taskMsg(id: 'task-1', uuid: 'task-uuid'),
        _sidechainRoot(
          id: 'root-1',
          uuid: 'root-uuid',
          parentUuid: 'task-uuid',
        ),
        ...shuffled,
      ];

      final result = grouper.groupMessages(messages);

      expect(result, isNotNull);
      expect(result!.hasOrphans, isFalse,
          reason: 'long out-of-order chain must fully '
              'resolve to the single indexed Task');
      expect(result.messages, hasLength(1));
      final children = result.messages[0]['children']
          as List<Map<String, dynamic>>;
      expect(children, hasLength(chainLength));
    });

    test('inner sidechain Task whose uuid (JSONL) differs from '
        'toolUseId attaches descendants chained via either', () {
      // Regression for the "subagent (recovered)" fragmentation
      // bug: inner Task tool_uses live inside another sidechain
      // message whose JSONL uuid (e.g. 41047909-...) is distinct
      // from the Anthropic-assigned toolUseId (e.g. toolu_01...).
      // Pre-fix the encryption pipeline overwrote the inner Task's
      // uuid with the toolu_*, so any descendant that chained via
      // parentUuid==<JSONL uuid> (the assistant message wrapping
      // the tool_use) failed to resolve.  Now both uuid (JSONL)
      // and toolUseId are indexed.
      final messages = [
        _taskMsg(
          id: 'outer-task',
          uuid: 'outer-uuid',
          toolUseId: 'toolu_outer',
        ),
        _sidechainRoot(
          id: 'outer-root',
          uuid: 'outer-root-uuid',
          parentUuid: 'toolu_outer',
        ),
        // Inner Task — its uuid is the JSONL message uuid (post-fix);
        // its toolUseId is the Anthropic block id.
        <String, dynamic>{
          'id': 'inner-task',
          'kind': 'tool-call',
          'name': 'Agent',
          'uuid': 'inner-jsonl-uuid',
          'toolUseId': 'toolu_inner',
          'isSidechain': true,
          'parentUuid': 'outer-root-uuid',
        },
        // Chain head: chains directly via toolUseId.
        _sidechainChild(
          id: 'inner-root',
          uuid: 'inner-root-uuid',
          parentUuid: 'toolu_inner',
        ),
        // Subsequent: chains via JSONL uuid of inner-task itself.
        _sidechainChild(
          id: 'inner-child-via-jsonl',
          uuid: 'icj-uuid',
          parentUuid: 'inner-jsonl-uuid',
        ),
        // Deeper descendant chains via the prior child's uuid.
        _sidechainChild(
          id: 'inner-grandchild',
          uuid: 'igc-uuid',
          parentUuid: 'icj-uuid',
        ),
      ];

      final result = grouper.groupMessages(messages);

      expect(result, isNotNull);
      expect(result!.hasOrphans, isFalse,
          reason: 'JSONL-uuid and toolUseId chains must both '
              'resolve to the inner Task');
      // Outer Task remains at top level.
      expect(result.messages, hasLength(1));
      final outer = result.messages[0];
      final outerChildren =
          (outer['children'] as List).cast<Map<String, dynamic>>();
      // Inner Task got moved into outer Task's children list.
      final innerTask = outerChildren.firstWhere(
        (c) => c['id'] == 'inner-task',
      );
      final innerChildren = (innerTask['children'] as List)
          .cast<Map<String, dynamic>>();
      final innerChildIds = innerChildren.map((c) => c['id']).toSet();
      expect(innerChildIds, containsAll([
        'inner-root',
        'inner-child-via-jsonl',
        'inner-grandchild',
      ]));
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
      // any Task — stays as orphan in the list.  The grouper
      // reports hasOrphans=true so the caller can schedule a
      // deferred regroup (more context may arrive later).
      final messages = [
        _taskMsg(id: 'task-1', uuid: 'task-uuid'),
        <String, dynamic>{
          'id': 'orphan-1',
          'isSidechain': true,
          'parentUuid': 'unknown-uuid',
        },
      ];

      final result = grouper.groupMessages(messages);

      expect(result, isNotNull);
      expect(result!.hasOrphans, isTrue);
      // Messages unchanged (same reference — nothing attached)
      expect(identical(result.messages, messages), isTrue);
    });

    test('reports hasOrphans when sidechains exist but no Tasks '
        'are indexed', () {
      // Cache restore / message-window scenario: the parent
      // Task lives outside the loaded message window so the
      // grouper indexes zero Tasks, but isSidechain entries are
      // present in the list.  Pre-fix the grouper short-circuited
      // and returned null, so the caller never scheduled a
      // deferred sweep — orphans stayed invisible forever.
      final messages = [
        _textMsg(id: 'm1'),
        _sidechainChild(
          id: 'orphan-1',
          uuid: 'orph-1-uuid',
          parentUuid: 'missing-task-uuid',
        ),
        _sidechainChild(
          id: 'orphan-2',
          uuid: 'orph-2-uuid',
          parentUuid: 'missing-task-uuid',
        ),
      ];

      final result = grouper.groupMessages(messages);

      expect(result, isNotNull,
          reason: 'must not short-circuit when orphans are '
              'present even if no Tasks are indexed');
      expect(result!.hasOrphans, isTrue);
      expect(identical(result.messages, messages), isTrue);
    });

    test('attaches new children to a nested sub-agent Task', () {
      // Regression: sub-agent-of-a-sub-agent.  Outer Task A
      // has been grouped previously and its children include
      // an inner Task B (nested) which has its own children.
      // A new sidechain message arrives in the flat list
      // whose parentUuid chains back to B's subtree — it must
      // be attached to B's children, not A's.
      //
      // Before the fix, Pass 1 only indexed top-level Tasks
      // so B's uuid chain was never mapped and new children
      // for B stayed orphaned forever (`sync=3` symptom).
      final innerTask = _taskMsg(
        id: 'task-inner',
        uuid: 'inner-uuid',
        children: [
          _sidechainChild(
            id: 'inner-child-1',
            uuid: 'ic1-uuid',
            parentUuid: 'inner-uuid',
          ),
        ],
        sidechainRootUuids: ['inner-root-uuid'],
      );
      final messages = [
        _taskMsg(
          id: 'task-outer',
          uuid: 'outer-uuid',
          children: [innerTask],
          sidechainRootUuids: ['outer-root-uuid'],
        ),
        // New sidechain message chaining off inner-child-1.
        _sidechainChild(
          id: 'inner-child-2',
          uuid: 'ic2-uuid',
          parentUuid: 'ic1-uuid',
        ),
      ];

      final result = grouper.groupMessages(messages);

      expect(result, isNotNull);
      // Only the outer Task remains top-level — the new
      // sidechain child was removed from the flat list.
      expect(result!.messages, hasLength(1));
      expect(result.messages[0]['id'], 'task-outer');

      // The inner Task now has TWO children (ic1 + ic2),
      // attached directly to the nested Task map.
      final outerChildren =
          result.messages[0]['children'] as List<dynamic>;
      expect(outerChildren, hasLength(1));
      final nested =
          outerChildren[0] as Map<String, dynamic>;
      expect(nested['id'], 'task-inner');
      final nestedChildren = nested['children'] as List<dynamic>;
      expect(nestedChildren, hasLength(2));
      expect(
        nestedChildren.map((c) => (c as Map)['id']),
        ['inner-child-1', 'inner-child-2'],
      );
    });

    test('routes new children to the inner Task when a '
        'message chains off its uuid directly', () {
      // Regression: a sidechain message with parentUuid
      // pointing straight at a nested Task's uuid must land
      // inside that nested Task, not on the outer Task.
      final innerTask = _taskMsg(
        id: 'task-inner',
        uuid: 'inner-uuid',
      );
      final messages = [
        _taskMsg(
          id: 'task-outer',
          uuid: 'outer-uuid',
          children: [innerTask],
        ),
        _sidechainChild(
          id: 'new-inner-child',
          uuid: 'nic-uuid',
          parentUuid: 'inner-uuid',
        ),
      ];

      final result = grouper.groupMessages(messages);

      expect(result, isNotNull);
      expect(result!.messages, hasLength(1));
      final outerChildren =
          result.messages[0]['children'] as List<dynamic>;
      // Inner Task still the only outer child.
      expect(outerChildren, hasLength(1));
      final nested =
          outerChildren[0] as Map<String, dynamic>;
      final nestedChildren = nested['children'] as List<dynamic>;
      expect(nestedChildren, hasLength(1));
      expect(
        (nestedChildren[0] as Map)['id'],
        'new-inner-child',
      );
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

  // ── Cycle prevention ─────────────────────────────────────
  //
  // Production incident: a session with many running agents could
  // blow the stack (57k+ identical frames) and freeze the app when
  // a Task message's parentUuid resolved to its own identifier, or
  // when a prior corruption left `msg['children']` containing
  // `msg`.  These tests lock down both the creation guard and the
  // defence-in-depth visited-set recursion limit.
  group('cycle prevention', () {
    test(
        'Task whose parentUuid matches its own uuid is not '
        'attached to itself', () {
      final task = <String, dynamic>{
        'id': 'task-1',
        'kind': 'tool-call',
        'name': 'Task',
        'uuid': 'task-uuid',
        // Malformed: parent points back to self.
        'parentUuid': 'task-uuid',
        'isSidechain': true,
      };
      final result = grouper.groupMessages([task]);
      // Either no grouping (null) or a result where the task has
      // no children (and is not its own child).
      if (result != null) {
        final children =
            task['children'] as List<dynamic>?;
        if (children != null) {
          expect(
            children.any((c) => identical(c, task)),
            isFalse,
            reason: 'Task must not be its own child',
          );
        }
      }
    });

    test(
        'Task whose parentUuid matches its own id is not '
        'attached to itself', () {
      const taskId = 'task-1';
      final task = <String, dynamic>{
        'id': taskId,
        'kind': 'tool-call',
        'name': 'Task',
        'uuid': 'task-uuid',
        'parentUuid': taskId,
        'isSidechain': true,
      };
      final result = grouper.groupMessages([task]);
      if (result != null) {
        final children = task['children'] as List<dynamic>?;
        if (children != null) {
          expect(
            children.any((c) => identical(c, task)),
            isFalse,
          );
        }
      }
    });

    test(
        'pre-existing cyclic children graph does not blow the '
        'stack (walkAndIndex guard)', () {
      // Simulate a cycle that might have leaked in from a prior
      // bug or corrupted payload: task.children contains task.
      final task = <String, dynamic>{
        'id': 'task-1',
        'kind': 'tool-call',
        'name': 'Task',
        'uuid': 'task-uuid',
      };
      task['children'] = <Map<String, dynamic>>[task];

      // Must terminate instead of recursing forever.
      // Any return value is acceptable — the assertion is that
      // the call completes without a stack overflow.
      expect(() => grouper.groupMessages([task]), returnsNormally);
    });

    test(
        'pre-existing cyclic children graph does not blow the '
        'stack (regroupNestedTasks guard)', () {
      final task = <String, dynamic>{
        'id': 'task-1',
        'kind': 'tool-call',
        'name': 'Task',
        'uuid': 'task-uuid',
      };
      final cyclicChildren = <Map<String, dynamic>>[task];
      task['children'] = cyclicChildren;

      expect(
        () => grouper.regroupNestedTasks(cyclicChildren),
        returnsNormally,
      );
    });

    test(
        'two-node cycle (A↔B via children) does not blow the '
        'stack', () {
      final taskA = <String, dynamic>{
        'id': 'task-a',
        'kind': 'tool-call',
        'name': 'Task',
        'uuid': 'a-uuid',
      };
      final taskB = <String, dynamic>{
        'id': 'task-b',
        'kind': 'tool-call',
        'name': 'Task',
        'uuid': 'b-uuid',
      };
      taskA['children'] = <Map<String, dynamic>>[taskB];
      taskB['children'] = <Map<String, dynamic>>[taskA];

      expect(
        () => grouper.groupMessages([taskA, taskB]),
        returnsNormally,
      );
    });
  });
}
