// Regression coverage for the live-stream sidechain grouping bug.
//
// Background: when a WebSocket message arrived for a session the user was
// NOT currently viewing, message_ingestion_orchestrator._processMessageBatch
// gated `_groupSidechainMessages` on `_visibleSessionId == sessionId`. The
// gate skipped grouping whenever the user had navigated away mid-burst,
// stranding sub-agent children as orphans until a later HTTP cold-fetch
// catch-up sweep ran (and only if the user re-opened the session with
// `_sessionsNeedingVisibleRegroup` set). The fix removes the gate and
// passes `changedIds` so the grouper's fast-path can skip a full re-walk
// when the batch carries nothing sidechain-relevant.
//
// This file pins the contract the orchestrator now relies on. It exercises
// the public SidechainGrouper API directly (which is a pure function over
// a `List<Map<String, dynamic>>` plus an optional `changedIds` set), so the
// orchestrator integration is verified by transitivity: the orchestrator
// calls the grouper with `changedIds = _collectJustAppendedIds(...)`, and
// these tests confirm the grouper behaves correctly for every input shape
// the orchestrator can hand it.
//
// Schema reminders (verified by sidechain_grouper.dart internals):
//   * sidechain-root (`kind == 'sidechain-root'`) is FILTERED OUT of the
//     flat list and recorded on the parent Task as `_sidechainRootUuids`.
//     The renderer hydrates root content from those uuids elsewhere.
//   * sidechain-child (`isSidechain == true`) is ATTACHED to the parent
//     Task's `children` list and removed from the flat list.
//   * Both kinds are removed from the top-level result.messages.
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/sidechain_grouper.dart';

void main() {
  late SidechainGrouper grouper;

  setUp(() {
    grouper = SidechainGrouper();
  });

  // ── Helpers (mirror sidechain_grouper_test.dart fixtures) ──

  Map<String, dynamic> taskMsg({
    required String id,
    String name = 'Task',
    String? uuid,
    String? toolUseId,
    List<Map<String, dynamic>>? children,
    List<String>? sidechainRootUuids,
  }) =>
      <String, dynamic>{
        'id': id,
        'kind': 'tool-call',
        'name': name,
        ?uuid == null ? null : 'uuid': uuid,
        ?toolUseId == null ? null : 'toolUseId': toolUseId,
        ?children == null ? null : 'children': children,
        ?sidechainRootUuids == null
            ? null
            : '_sidechainRootUuids': sidechainRootUuids,
      };

  Map<String, dynamic> sidechainRoot({
    required String id,
    String? uuid,
    String? parentUuid,
  }) =>
      <String, dynamic>{
        'id': id,
        'kind': 'sidechain-root',
        ?uuid == null ? null : 'uuid': uuid,
        ?parentUuid == null ? null : 'parentUuid': parentUuid,
      };

  Map<String, dynamic> sidechainChild({
    required String id,
    String? uuid,
    String? parentUuid,
  }) =>
      <String, dynamic>{
        'id': id,
        'isSidechain': true,
        ?uuid == null ? null : 'uuid': uuid,
        ?parentUuid == null ? null : 'parentUuid': parentUuid,
      };

  Map<String, dynamic> textMsg({required String id, String content = 'hi'}) =>
      <String, dynamic>{
        'id': id,
        'kind': 'text',
        'role': 'assistant',
        'content': content,
      };

  // ── Live-stream changedIds contract ──────────────────────────

  group('live-stream sidechain grouping — changedIds contract', () {
    test(
        'changedIds containing ONLY non-sidechain text returns null '
        '(fast-path skipped the full re-walk)', () {
      final messages = [
        taskMsg(id: 't1', uuid: 'task-uuid', toolUseId: 'toolu_1'),
        textMsg(id: 'm1'),
        textMsg(id: 'm2'),
      ];

      // Simulate the orchestrator passing only the just-appended text ids
      // as changedIds. No sidechain-relevant ids in the set -> grouper
      // should NOT run a full pass, even though a Task is present.
      final result = grouper.groupMessages(
        List.of(messages),
        changedIds: {'m1', 'm2'},
      );

      // Per sidechain_grouper.dart fast-path: changedIds set with no
      // sidechain-relevant entries returns either null OR hasOrphans=true.
      // No orphans in this fixture, so null.
      expect(result, isNull,
          reason: 'no sidechain-relevant id in changedIds -> no rebuild');
    });

    test(
        'navigation-away regression: changedIds={root-id, child-id} attaches '
        'the child to its parent Task even when the Task id is NOT in '
        'changedIds (matches the fix removing _visibleSessionId gate)', () {
      // Scenario: user navigated to session A while session B fired a
      // Task tool-call. The Task tool-call arrived in an earlier batch
      // and is already in the session message list. While the user is
      // still on session A, a new sidechain-root + sidechain-child for
      // session B arrive over the WebSocket. The orchestrator passes
      // only the just-arrived ids as changedIds.
      final messages = [
        // Pre-existing Task tool-call (NOT in changedIds for THIS batch).
        taskMsg(id: 't1', uuid: 'task-uuid', toolUseId: 'toolu_1'),
        // Newly-arrived sidechain-root whose parentUuid points at the
        // existing Task's uuid.
        sidechainRoot(id: 'r1', uuid: 'root-uuid', parentUuid: 'task-uuid'),
        // Newly-arrived sidechain-child whose parentUuid points at the
        // root's uuid.
        sidechainChild(id: 'c1', uuid: 'child-uuid', parentUuid: 'root-uuid'),
      ];

      // changedIds matches ONLY the just-arrived root+child ids — not
      // the pre-existing Task. The fast-path must still walk the list
      // because the changed set contains sidechain-relevant ids.
      final result = grouper.groupMessages(
        List.of(messages),
        changedIds: {'r1', 'c1'},
      );

      expect(result, isNotNull,
          reason: 'sidechain-relevant ids in changedIds must force a '
              'full pass even when the parent Task is not in changedIds');
      // Top-level should now contain only the Task (the sidechain-root
      // and sidechain-child got removed from the flat list and the
      // child got attached under the Task).
      expect(result!.messages, hasLength(1));
      final parent = result.messages.first;
      expect(parent['id'], 't1');
      // sidechain-child is the only direct child of the Task.
      final children = parent['children'] as List<Map<String, dynamic>>;
      expect(children, hasLength(1),
          reason: 'sidechain-child must attach under the Task tool-call');
      expect(children.first['id'], 'c1');
      // sidechain-root is recorded on the Task via _sidechainRootUuids
      // so the renderer can hydrate root content elsewhere.
      final roots = parent['_sidechainRootUuids'] as List<dynamic>?;
      expect(roots, isNotNull);
      expect(roots, contains('root-uuid'),
          reason: 'sidechain-root uuid must be persisted on the Task');
    });

    test(
        'multi-level chain: root + grandchild both collapse under the '
        'Task tool-call when changedIds only contains the leaf id', () {
      // Validates the parentUuid chain walk: c1.parentUuid=r1.uuid,
      // r1.parentUuid=t1.uuid. Even if only c1 is "new", the grouper
      // walks the chain and attaches everything.
      final messages = [
        taskMsg(id: 't1', uuid: 'task-uuid'),
        sidechainRoot(id: 'r1', uuid: 'root-uuid', parentUuid: 'task-uuid'),
        sidechainChild(id: 'c1', uuid: 'child-uuid', parentUuid: 'root-uuid'),
        textMsg(id: 'm1'),
      ];

      final result = grouper.groupMessages(
        List.of(messages),
        changedIds: {'c1'},
      );

      expect(result, isNotNull);
      // Top-level: only Task + the unrelated text message (root + child
      // are removed from the flat list).
      expect(result!.messages, hasLength(2));
      final task = result.messages.firstWhere((m) => m['id'] == 't1');
      final children = task['children'] as List<Map<String, dynamic>>;
      expect(children, hasLength(1),
          reason: 'sidechain-child attaches under the Task');
      expect(children.first['id'], 'c1');
      final roots = task['_sidechainRootUuids'] as List<dynamic>?;
      expect(roots, contains('root-uuid'),
          reason: 'sidechain-root uuid persists on the Task');
    });

    test(
        'changedIds containing only a Task whose sidechain is fully '
        'attached returns null OR hasOrphans:false (idempotent — no '
        'rebuild needed)', () {
      // Pre-existing, fully-grouped state (mimics a session loaded
      // previously and then a re-batch arrives referencing the Task id).
      final messages = [
        {
          ...taskMsg(id: 't1', uuid: 'task-uuid', toolUseId: 'toolu_1'),
          'children': <Map<String, dynamic>>[
            {
              ...sidechainRoot(
                  id: 'r1', uuid: 'root-uuid', parentUuid: 'task-uuid'),
              'children': <Map<String, dynamic>>[
                sidechainChild(
                    id: 'c1', uuid: 'child-uuid', parentUuid: 'root-uuid'),
              ],
            },
          ],
        },
      ];

      final result = grouper.groupMessages(
        List.of(messages),
        changedIds: {'t1'},
      );

      // Either null (no-op fast-path) or hasOrphans:false (full pass,
      // no rebuild). Both mean "no UI rebuild needed". The visible
      // contract is that the tree is preserved.
      if (result != null) {
        expect(result.hasOrphans, isFalse);
        // Tree must be preserved with all 3 ids reachable under the Task.
        var foundCount = 0;
        final visited = <String>{};
        void walk(Map<String, dynamic> msg) {
          final id = msg['id'];
          if (id is String) visited.add(id);
          final children = msg['children'];
          if (children is List) {
            for (final c in children) {
              if (c is Map<String, dynamic>) walk(c);
            }
          }
        }

        walk(result.messages.first);
        foundCount = ['t1', 'r1', 'c1']
            .where((id) => visited.contains(id))
            .length;
        expect(foundCount, 3,
            reason: 'must not duplicate or drop existing children');
      }
    });

    test(
        'visibility-agnostic: same input list produces identical grouping '
        'on repeated calls (no per-call visibility context)', () {
      // The grouper itself is a pure function over (messages, changedIds)
      // and has no notion of which session the user is viewing. The
      // orchestrator previously gated invocation on
      // _visibleSessionId == sessionId — a context the grouper does
      // not see. This test pins that calling the grouper twice on the
      // same input yields the same tree, so the orchestrator can
      // invoke it unconditionally without observable side effects
      // beyond a possible (idempotent) rebuild.
      final messages = [
        taskMsg(id: 't1', uuid: 'task-uuid', toolUseId: 'toolu_1'),
        sidechainRoot(id: 'r1', uuid: 'root-uuid', parentUuid: 'task-uuid'),
        sidechainChild(id: 'c1', uuid: 'child-uuid', parentUuid: 'root-uuid'),
      ];

      final firstCall = grouper.groupMessages(List.of(messages));
      // Take a fresh copy of the original fixture; the first call
      // mutated the maps in place.
      final messagesCopy = List.of(messages);
      final secondCall = grouper.groupMessages(messagesCopy);

      expect(firstCall, isNotNull);
      expect(secondCall, isNotNull);
      expect(firstCall!.messages.length, secondCall!.messages.length);
      // Both calls produce one parent Task in result.messages with the
      // same child count and same root uuid list.
      final firstRoots =
          firstCall.messages.first['_sidechainRootUuids'] as List? ?? [];
      final secondRoots =
          secondCall.messages.first['_sidechainRootUuids'] as List? ?? [];
      expect(firstRoots, secondRoots,
          reason: 'same input -> same _sidechainRootUuids, regardless of '
              'any caller-side visibility');
      final firstChildren =
          firstCall.messages.first['children'] as List<Map<String, dynamic>>;
      final secondChildren =
          secondCall.messages.first['children'] as List<Map<String, dynamic>>;
      expect(firstChildren.length, secondChildren.length);
      expect(firstChildren.first['id'], secondChildren.first['id']);
    });
  });
}
