import '../wire/wire_parsers.dart';
import '../native/generated/api/sidechain_api.dart' as native_api;
import '../native/native_core.dart';

/// Returns true for messages that should count as visible orphans
/// (i.e. would render as their own subagent tile if not grouped).
/// Hidden chain-bridge entries (kind == 'sidechain-link') exist only
/// so the grouper can walk parentUuid through user-tool_result
/// messages that produce no visible display; they must not contribute
/// to orphan detection or trigger synthetic Task absorption.
bool isVisibleSidechainOrphan(Map<String, dynamic> m) {
  if (m['isSidechain'] != true) return false;
  return m['kind'] != 'sidechain-link';
}

bool _isAgentContainerTool(Map<String, dynamic> m) {
  final name = m['name'];
  return m['kind'] == 'tool-call' &&
      (name == 'Task' || name == 'Agent' || name == 'Workflow');
}

/// Sidechain message grouping logic.
///
/// Groups sidechain messages (Task/Agent tool-call children) into
/// their parent Task tool-call messages using a 4-pass algorithm:
///
/// 1. Index Task tool-calls by uuid, toolUseId, and prompt
/// 2. Find sidechain roots and match children via parentUuid
/// 3. Remove sidechain messages from main list, attach as children
/// 4. Recursively regroup nested Task children
class SidechainGrouper {
  /// Result from the optional native planner. [handled] distinguishes a
  /// successful native no-op from an unavailable/faulted native core, where
  /// the caller must run the Dart implementation.
  ({bool handled, List<Map<String, dynamic>> messages, bool hasOrphans})?
  _tryNativeGrouping(List<Map<String, dynamic>> messages) {
    final nodes = <Map<String, dynamic>>[];
    final rows = <native_api.SidechainRow>[];
    final tasks = <String, Map<String, dynamic>>{};
    final visited = <Map<String, dynamic>>{};

    String stringValue(Object? value) => value is String ? value : '';

    String promptFor(Map<String, dynamic> message) {
      final direct = message['prompt'];
      if (direct is String && direct.isNotEmpty) return direct;
      final input = WireParsers.asMap(message['input']);
      return stringValue(input?['prompt']);
    }

    List<String> rootUuidsFor(Map<String, dynamic> message) {
      final raw = message['_sidechainRootUuids'];
      if (raw is! List) return const <String>[];
      return raw.whereType<String>().where((v) => v.isNotEmpty).toList();
    }

    void walk(
      List<dynamic> values, {
      required bool topLevel,
      String? ancestorTaskId,
    }) {
      for (final value in values) {
        if (value is! Map<String, dynamic> || !visited.add(value)) continue;
        final kind = stringValue(value['kind']);
        final name = stringValue(value['name']);
        final id = stringValue(value['id']);
        final isTask =
            kind == 'tool-call' &&
            (name == 'Task' || name == 'Agent' || name == 'Workflow') &&
            id.isNotEmpty;
        nodes.add(value);
        rows.add(
          native_api.SidechainRow(
            id: id,
            uuid: stringValue(value['uuid']),
            parentUuid: stringValue(value['parentUuid']),
            parentToolUseId: stringValue(value['parentToolUseId']),
            toolUseId: stringValue(value['toolUseId']),
            prompt: promptFor(value),
            agentId: stringValue(value['agentId']),
            kind: kind,
            name: name,
            isSidechain: value['isSidechain'] == true,
            isTaskEvent: value['taskEvent'] == true,
            topLevel: topLevel,
            ancestorTaskId: ancestorTaskId ?? '',
            rootUuids: rootUuidsFor(value),
          ),
        );
        if (isTask) tasks[id] = value;

        final children = value['children'];
        if (children is List) {
          walk(
            children,
            topLevel: false,
            ancestorTaskId: isTask ? id : ancestorTaskId,
          );
        }
      }
    }

    walk(messages, topLevel: true);
    final assignments = NativeCore.instance.planSidechainGrouping(rows: rows);
    if (assignments == null || assignments.length != nodes.length) return null;

    final childRows = <String, List<Map<String, dynamic>>>{};
    final removedIds = <String>{};
    for (var i = 0; i < assignments.length; i++) {
      final taskId = assignments[i];
      if (taskId == null) continue;
      final message = nodes[i];
      final id = stringValue(message['id']);
      final task = tasks[taskId];
      if (id.isEmpty || task == null || id == taskId) return null;

      if (rows[i].kind == 'sidechain-root') {
        final uuid = rows[i].uuid;
        if (uuid.isNotEmpty) {
          final roots =
              (task['_sidechainRootUuids'] as List<dynamic>?) ?? <dynamic>[];
          if (!roots.contains(uuid)) {
            task['_sidechainRootUuids'] = [...roots, uuid];
          }
        }
      } else if (rows[i].kind != 'sidechain-link') {
        childRows
            .putIfAbsent(taskId, () => <Map<String, dynamic>>[])
            .add(message);
      }
      removedIds.add(id);
    }

    childRows.forEach((taskId, newChildren) {
      final task = tasks[taskId];
      if (task == null) return;
      final existing = task['children'] as List<dynamic>?;
      if (existing != null && existing.isNotEmpty) {
        final existingIds = <String>{};
        for (final child in existing) {
          if (child is Map<String, dynamic>) {
            existingIds.addAll(_messageIdentityKeys(child));
          }
        }
        for (final child in newChildren) {
          final newKeys = _messageIdentityKeys(child);
          if (newKeys.isEmpty || existingIds.intersection(newKeys).isEmpty) {
            existing.add(child);
            existingIds.addAll(newKeys);
          }
        }
      } else {
        task['children'] = newChildren;
      }
    });

    final filtered = messages
        .where((message) => !removedIds.contains(message['id']))
        .toList();
    for (final task in tasks.values) {
      final children = task['children'] as List<dynamic>?;
      if (children != null && children.isNotEmpty) {
        regroupNestedTasks(children.whereType<Map<String, dynamic>>().toList());
      }
    }
    return (
      handled: true,
      messages: filtered,
      hasOrphans: filtered.any(isVisibleSidechainOrphan),
    );
  }

  /// Returns both the normalized message id and ids embedded in the raw
  /// Claude payload. Delivery envelopes can have different outer ids while
  /// representing the same inner message.
  Set<String> _messageIdentityKeys(Map<String, dynamic> message) {
    final keys = <String>{};
    void addString(Object? value) {
      if (value is String && value.isNotEmpty) keys.add(value);
    }

    addString(message['id']);
    addString(message['toolUseId']);
    final nested = message['message'];
    if (nested is Map) {
      addString(nested['id']);
    }
    final content = message['content'];
    if (content is List) {
      for (final block in content) {
        if (block is Map) {
          addString(block['id']);
          addString(block['tool_use_id']);
        }
      }
    }
    return keys;
  }

  /// Groups sidechain messages into their parent Task tool-call
  /// messages.
  ///
  /// Operates on [messages] in-place and returns a filtered list
  /// with sidechain messages removed and attached as `children`
  /// arrays on their parent Task messages.
  ///
  /// When [changedIds] is provided, performs a fast-path check:
  /// if none of the changed messages are sidechain-relevant, the
  /// method returns `null` to indicate no grouping was needed.
  /// A non-null return means the list was modified.
  ///
  /// Returns `null` if no grouping was performed (fast-path or
  /// no Task tool-calls found), or the filtered message list if
  /// grouping occurred.
  ///
  /// The [hasOrphans] output parameter (via the return record)
  /// indicates whether orphaned sidechain messages remain in the
  /// list after grouping — the caller should schedule a deferred
  /// re-group sweep.
  ({List<Map<String, dynamic>> messages, bool hasOrphans})? groupMessages(
    List<Map<String, dynamic>> messages, {
    Set<String>? changedIds,
  }) {
    if (messages.isEmpty) return null;

    // Fast path: if the caller told us which messages changed
    // and none of them are sidechain-related, there is nothing
    // to regroup — skip all four passes.
    if (changedIds != null && changedIds.isNotEmpty) {
      var hasSidechainRelevant = false;
      for (final msg in messages) {
        final id = msg['id'] as String?;
        if (id == null || !changedIds.contains(id)) continue;
        final kind = msg['kind'] as String?;
        final name = msg['name'] as String?;
        if (msg['isSidechain'] == true ||
            kind == 'sidechain-root' ||
            (kind == 'tool-call' &&
                (name == 'Task' || name == 'Agent' || name == 'Workflow'))) {
          hasSidechainRelevant = true;
          break;
        }
      }
      if (!hasSidechainRelevant) {
        // Fast path: the changed messages aren't
        // sidechain-relevant, but there may still be orphans
        // in the list from previous sidechain batches.
        final hasOrphans = messages.any(isVisibleSidechainOrphan);
        return hasOrphans ? (messages: messages, hasOrphans: true) : null;
      }
    }

    final nativeResult = _tryNativeGrouping(messages);
    if (nativeResult != null && nativeResult.handled) {
      if (nativeResult.messages.length == messages.length &&
          !nativeResult.hasOrphans) {
        return null;
      }
      return (
        messages: nativeResult.messages,
        hasOrphans: nativeResult.hasOrphans,
      );
    }

    // Pass 1: Walk the entire tree (top-level + every nested
    // children subtree) and index:
    //   • taskIdToTask — every Task's id → its map reference,
    //     so Pass 3 can attach children to a nested Task
    //     directly without having to find it in the flat list.
    //   • uuidToTaskId / promptToTaskId — every Task's
    //     identifiers, so a sidechain-root whose parentUuid
    //     points to a *nested* Task can still be matched.
    //   • uuidToSidechainId — every descendant's uuid and
    //     parentUuid → the nearest-ancestor Task's id, so
    //     new sidechain messages arriving later in the flat
    //     list can be routed to the correct Task regardless
    //     of nesting depth.
    //
    // This fixes the bug where a sub-agent-of-a-sub-agent only
    // ever shows its first few children: the old code indexed
    // only top-level Tasks, so new sidechain messages whose
    // parent chain terminated at a nested Task stayed
    // orphaned forever.
    final taskIdToTask = <String, Map<String, dynamic>>{};
    final uuidToTaskId = <String, String>{};
    final promptToTaskId = <String, String>{};
    final uuidToSidechainId = <String, String>{};
    // Async background agents stamp `agentId` (the SDK-assigned task
    // id) on every sidechain message and on `task_started` events.
    // Building this map lets us coalesce orphan runs whose
    // `parent_tool_use_id` is missing (e.g. legacy cached entries
    // that pre-date the parent_tool_use_id propagation fix).
    final agentIdToTaskId = <String, String>{};

    // Identity-based visited set guards against cycles in the
    // children graph (e.g. msg['children'] contains msg itself).
    // Map has no == override so default equality is by identity.
    final visitedWalk = <Map<String, dynamic>>{};

    void walkAndIndex(
      List<dynamic> msgs,
      String? ancestorTaskId, {
      int depth = 0,
    }) {
      if (depth >= _maxNestingDepth) return;
      for (final m in msgs) {
        if (m is! Map<String, dynamic>) continue;
        if (!visitedWalk.add(m)) continue;
        final isTask = _isAgentContainerTool(m);
        var nextAncestorId = ancestorTaskId;
        if (isTask) {
          final taskId = m['id'] as String?;
          if (taskId == null || taskId.isEmpty) continue;
          taskIdToTask[taskId] = m;
          nextAncestorId = taskId;
          uuidToTaskId[taskId] = taskId;
          uuidToSidechainId[taskId] = taskId;
          final uuid = m['uuid'] as String?;
          if (uuid != null && uuid.isNotEmpty) {
            uuidToTaskId[uuid] = taskId;
            uuidToSidechainId[uuid] = taskId;
          }
          final toolUseId = m['toolUseId'] as String?;
          if (toolUseId != null && toolUseId.isNotEmpty) {
            uuidToTaskId[toolUseId] = taskId;
            uuidToSidechainId[toolUseId] = taskId;
          }
          final rootUuids = m['_sidechainRootUuids'] as List<dynamic>?;
          if (rootUuids != null) {
            for (final ru in rootUuids) {
              if (ru is String && ru.isNotEmpty) {
                uuidToSidechainId[ru] = taskId;
              }
            }
          }
          final input = WireParsers.asMap(m['input']);
          final prompt = input?['prompt'] as String?;
          if (prompt != null && prompt.isNotEmpty) {
            promptToTaskId[prompt] = taskId;
          }
        } else if (ancestorTaskId != null) {
          // Non-Task descendant: link its uuid and parentUuid
          // to its nearest Task ancestor.  Use putIfAbsent so
          // an earlier (more specific) mapping wins over a
          // later ancestor-level one.
          final id = m['id'] as String?;
          if (id != null && id.isNotEmpty) {
            uuidToSidechainId.putIfAbsent(id, () => ancestorTaskId);
          }
          final uuid = m['uuid'] as String?;
          if (uuid != null && uuid.isNotEmpty) {
            uuidToSidechainId.putIfAbsent(uuid, () => ancestorTaskId);
          }
          final toolUseId = m['toolUseId'] as String?;
          if (toolUseId != null && toolUseId.isNotEmpty) {
            uuidToSidechainId.putIfAbsent(toolUseId, () => ancestorTaskId);
          }
          final parentUuid = m['parentUuid'] as String?;
          if (parentUuid != null && parentUuid.isNotEmpty) {
            uuidToSidechainId.putIfAbsent(parentUuid, () => ancestorTaskId);
          }
        }
        final children = m['children'] as List<dynamic>?;
        if (children != null) {
          walkAndIndex(children, nextAncestorId, depth: depth + 1);
        }
      }
    }

    walkAndIndex(messages, null);

    if (taskIdToTask.isEmpty) {
      // No Tasks indexed but sidechain messages may still be present
      // (e.g. cache restore where parent Tasks were truncated, or a
      // session whose Task lives outside the loaded message window).
      // Return hasOrphans:true so the deferred sweep is scheduled and
      // can absorb the stuck sidechains into a synthetic Task —
      // otherwise they remain invisible: the chat hides isSidechain
      // entries and the AgentsListSheet only enumerates Tasks.
      final hasOrphans = messages.any(isVisibleSidechainOrphan);
      return hasOrphans ? (messages: messages, hasOrphans: true) : null;
    }

    // Pass 1.5: Index every sidechain message in the flat list
    // by its uuid so Pass 2 can walk parentUuid chains
    // transitively.  Subagent transcripts chain via the
    // *previous sidechain message's* uuid — not the parent
    // Task's uuid.  Without transitive walking, Pass 2
    // resolution is iteration-order-sensitive: a chain message
    // whose direct parent (the prior sidechain message) hasn't
    // been processed yet stays orphaned, even though the chain
    // ultimately terminates at an indexed Task.  Orphan sidechain
    // messages are preserved at the top level (no synthetic
    // absorption) so the chat renders them inline; the worst case
    // here is subagent runs arriving as several top-level bubbles
    // instead of being grouped under one Task.
    final sidechainByUuid = <String, Map<String, dynamic>>{};
    for (final msg in messages) {
      if (msg['isSidechain'] == true || msg['kind'] == 'sidechain-root') {
        final uuid = msg['uuid'] as String?;
        if (uuid != null && uuid.isNotEmpty) {
          sidechainByUuid[uuid] = msg;
        }
      }
    }

    // Pass 1.7: derive (agentId → taskId) by walking every
    // sidechain message that already resolves via parentToolUseId
    // or parentUuid.  This is the source of truth for
    // agentId-based fallback in Pass 2.
    for (final msg in messages) {
      final agentId = msg['agentId'] as String?;
      if (agentId == null || agentId.isEmpty) continue;
      if (agentIdToTaskId.containsKey(agentId)) continue;
      final ptu = msg['parentToolUseId'] as String?;
      if (ptu != null && ptu.isNotEmpty) {
        final taskId = uuidToTaskId[ptu];
        if (taskId != null) {
          agentIdToTaskId[agentId] = taskId;
          continue;
        }
      }
      final pu = msg['parentUuid'] as String?;
      if (pu != null && pu.isNotEmpty) {
        final taskId = uuidToTaskId[pu];
        if (taskId != null) {
          agentIdToTaskId[agentId] = taskId;
        }
      }
    }

    // Walk parentUuid up through unresolved sidechain ancestors
    // until we hit one whose uuid is in [uuidToSidechainId]
    // (meaning it transitively belongs to an indexed Task).
    // Returns the Task id when found, or null if the chain
    // dead-ends.  Memoizes intermediate uuids so a future
    // lookup short-circuits.
    String? walkChainToTaskId(String? startParentUuid) {
      if (startParentUuid == null || startParentUuid.isEmpty) {
        return null;
      }
      final walked = <String>[];
      var current = startParentUuid;
      final visited = <String>{};
      while (current.isNotEmpty && visited.add(current)) {
        final mapped = uuidToSidechainId[current];
        if (mapped != null) {
          for (final w in walked) {
            uuidToSidechainId[w] = mapped;
          }
          return mapped;
        }
        walked.add(current);
        final ancestor = sidechainByUuid[current];
        if (ancestor == null) return null;
        final next = ancestor['parentUuid'] as String?;
        if (next == null || next.isEmpty) return null;
        current = next;
      }
      return null;
    }

    // Pass 2: Combined pass to find sidechain roots and group
    // child messages in a single iteration.  Operates on the
    // flat top-level list only — sidechain messages for
    // nested Tasks still arrive here before being grouped.
    final sidechainChildren = <String, List<Map<String, dynamic>>>{};
    final sidechainMsgIds = <String>{};

    for (final msg in messages) {
      if (msg['kind'] == 'sidechain-root') {
        final prompt = msg['prompt'] as String?;
        final uuid = msg['uuid'] as String?;
        final parentUuid = msg['parentUuid'] as String?;
        final parentToolUseId = msg['parentToolUseId'] as String?;
        // Sidechain-root usually points directly at the Task.
        // Fall back to chain walking for the rare case where the
        // root's parent is itself a (yet-unresolved) sidechain
        // message — happens after partial regroups where the
        // original root was attached but a later root chains
        // off an intermediate sidechain.
        String? sidechainId;
        if (parentToolUseId != null &&
            parentToolUseId.isNotEmpty &&
            uuidToTaskId.containsKey(parentToolUseId)) {
          sidechainId = uuidToTaskId[parentToolUseId];
        }
        sidechainId ??=
            (parentUuid != null && uuidToTaskId.containsKey(parentUuid))
            ? uuidToTaskId[parentUuid]
            : (prompt != null ? promptToTaskId[prompt] : null);
        sidechainId ??= walkChainToTaskId(parentUuid);
        // agentId fallback — see Pass 1.7 commentary.
        if (sidechainId == null) {
          final agentId = msg['agentId'] as String?;
          if (agentId != null && agentId.isNotEmpty) {
            sidechainId = agentIdToTaskId[agentId];
          }
        }
        if (sidechainId != null) {
          if (uuid != null) {
            uuidToSidechainId[uuid] = sidechainId;
            // Persist the root's uuid on the Task so the
            // pre-seed can recover the chain after this root
            // is removed from the message list.  Uses
            // taskIdToTask so the Task is found even if it's
            // nested inside another Task's children.
            final task = taskIdToTask[sidechainId];
            if (task != null) {
              final roots =
                  (task['_sidechainRootUuids'] as List<dynamic>?) ?? <String>[];
              if (!roots.contains(uuid)) {
                task['_sidechainRootUuids'] = [...roots, uuid];
              }
            }
          }
          // Guard: a null id can neither be tracked for removal from the
          // flat list nor deduped in Pass 3 — leave the message inline
          // rather than throwing (or rendering it twice).
          final msgId = msg['id'] as String?;
          if (msgId != null) sidechainMsgIds.add(msgId);
        }
      } else if (msg['isSidechain'] == true ||
          msg['kind'] == 'sidechain-link' ||
          msg['taskEvent'] == true ||
          ((msg['parentToolUseId'] as String?)?.isNotEmpty ?? false)) {
        final uuid = msg['uuid'] as String?;
        final parentUuid = msg['parentUuid'] as String?;
        final parentToolUseId = msg['parentToolUseId'] as String?;
        final kind = msg['kind'] as String?;
        // Hidden bridge entries (sidechain-link) exist only so
        // walkChainToTaskId can step through user-tool_result
        // messages that produce no visible display. Remove them
        // from the top-level list once their containing chain is
        // anchored to a Task, but never attach them as visible
        // children.
        final isChainLink = kind == 'sidechain-link';
        // Try prompt fallback for isSidechain children: if the parent
        // couldn't be found by uuid, the message's prompt field (from
        // WireParsers.asMap(input)['prompt']) might match a Task.
        final promptInput = WireParsers.asMap(msg['input']);
        final prompt = promptInput != null
            ? promptInput['prompt'] as String?
            : null;

        // Resolution order:
        //   0. parentToolUseId (Claude `parent_tool_use_id`) — the
        //      most authoritative key: the CLI stamps it on every
        //      sidechain message and it points directly at the
        //      spawning Task/Agent tool_use, with no chain to walk.
        //   1. Direct uuidToSidechainId hit (parent already
        //      indexed — either a Task or a prior chain step).
        //   2. Transitive chain walk through other unresolved
        //      sidechain messages — fixes order-sensitivity
        //      when chain[i+1] is iterated before chain[i].
        //   3. Prompt fallback (matches by Task input.prompt).
        String? sidechainId;
        if (parentToolUseId != null &&
            parentToolUseId.isNotEmpty &&
            uuidToSidechainId.containsKey(parentToolUseId)) {
          sidechainId = uuidToSidechainId[parentToolUseId];
        } else if (parentUuid != null) {
          final p = parentUuid;
          if (uuidToSidechainId.containsKey(p)) {
            sidechainId = uuidToSidechainId[p];
          } else {
            sidechainId = walkChainToTaskId(p);
            if (sidechainId == null &&
                prompt != null &&
                promptToTaskId.containsKey(prompt)) {
              sidechainId = promptToTaskId[prompt];
            }
          }
        } else if (prompt != null && promptToTaskId.containsKey(prompt)) {
          sidechainId = promptToTaskId[prompt];
        }
        // agentId fallback — last-resort lookup for sidechain
        // messages from async background agents that lost their
        // parent_tool_use_id (legacy cached entries).
        if (sidechainId == null) {
          final agentId = msg['agentId'] as String?;
          if (agentId != null && agentId.isNotEmpty) {
            sidechainId = agentIdToTaskId[agentId];
          }
        }

        if (sidechainId != null) {
          final id = msg['id'] as String?;
          // Refuse to make a message a child of itself.  Without this
          // guard, a Task whose parentUuid resolves to its own id/uuid/
          // toolUseId would be attached to its own children array,
          // producing a cycle that blows the stack in walkAndIndex and
          // regroupNestedTasks on the next grouping pass.
          if (id != null && id == sidechainId) {
            continue;
          }
          if (id != null && id.isNotEmpty) {
            uuidToSidechainId[id] = sidechainId;
          }
          if (uuid != null) {
            uuidToSidechainId[uuid] = sidechainId;
          }
          final toolUseId = msg['toolUseId'] as String?;
          if (toolUseId != null && toolUseId.isNotEmpty) {
            uuidToSidechainId[toolUseId] = sidechainId;
          }
          // Guard: without an id the message cannot be removed from the
          // flat list (removal is keyed by id), so adding it to the Task's
          // children would render it twice. Keep it inline instead.
          final msgId = msg['id'] as String?;
          if (msgId != null) {
            if (!isChainLink) {
              sidechainChildren.putIfAbsent(sidechainId, () => []).add(msg);
            }
            sidechainMsgIds.add(msgId);
          }
        }
      }
    }

    if (sidechainMsgIds.isEmpty) {
      final hasOrphans = messages.any(isVisibleSidechainOrphan);
      return hasOrphans ? (messages: messages, hasOrphans: true) : null;
    }

    // Pass 3: Attach sidechain children directly to their
    // target Task via taskIdToTask (works for top-level AND
    // nested Tasks — the Task map is mutated in place, so the
    // parent structure picks up the new children via
    // reference).
    sidechainChildren.forEach((taskId, newChildren) {
      final task = taskIdToTask[taskId];
      if (task == null) return;
      final existing = task['children'] as List<dynamic>?;
      if (existing != null && existing.isNotEmpty) {
        final existingIds = <String>{};
        for (final c in existing) {
          if (c is Map<String, dynamic>) {
            existingIds.addAll(_messageIdentityKeys(c));
          }
        }
        for (final newChild in newChildren) {
          final newKeys = _messageIdentityKeys(newChild);
          if (newKeys.isEmpty || existingIds.intersection(newKeys).isEmpty) {
            existing.add(newChild);
            existingIds.addAll(newKeys);
          }
        }
      } else {
        task['children'] = newChildren;
      }
    });

    // Build filtered flat list (sidechain messages are now
    // owned by their Task's children array, so remove from
    // the top-level stream).
    final filtered = <Map<String, dynamic>>[];
    for (final msg in messages) {
      if (sidechainMsgIds.contains(msg['id'])) continue;
      filtered.add(msg);
    }

    // Pass 4: Defence-in-depth — recursively regroup within
    // every Task's children (not just top-level).  Pass 3
    // should have placed messages correctly via the recursive
    // uuidToSidechainId, but this catches any residual cases
    // (e.g. inner Task uuid wasn't yet in the map when its
    // children arrived in the same batch).
    for (final task in taskIdToTask.values) {
      final children = task['children'] as List<dynamic>?;
      if (children != null && children.isNotEmpty) {
        regroupNestedTasks(children.whereType<Map<String, dynamic>>().toList());
      }
    }

    final hasOrphans = filtered.any(isVisibleSidechainOrphan);
    return (messages: filtered, hasOrphans: hasOrphans);
  }

  /// Maximum nesting depth for regroupNestedTasks recursion.
  /// Defence-in-depth against malformed payloads that produce very
  /// deep (but non-cyclic) children trees.
  static const int _maxNestingDepth = 20;

  /// Recursively regroup sidechain children so nested
  /// Task tool-calls within a children array get their
  /// own children sub-arrays.
  ///
  /// [visited] tracks message identities across the recursion so a
  /// cyclic children graph (e.g. a prior bug or malformed payload
  /// that left `msg['children']` containing `msg`) cannot blow the
  /// stack.  Callers at the top level can omit it; internal
  /// recursion threads the same set through each descent.
  ///
  /// [depth] is the current recursion depth.  When it exceeds
  /// [_maxNestingDepth] the method returns early to prevent stack
  /// overflow on pathological payloads.
  void regroupNestedTasks(
    List<Map<String, dynamic>> children, {
    Set<Map<String, dynamic>>? visited,
    int depth = 0,
  }) {
    if (depth >= _maxNestingDepth) return;
    visited ??= <Map<String, dynamic>>{};
    // Filter to unvisited maps to prevent infinite recursion when
    // a cycle exists in the tree.  We mutate `children` below
    // (indices and removals), so we don't rebuild the list — we
    // just skip already-visited entries at the decision points.
    // Find inner Task tool-calls and their stable identifiers.
    final uuidToTask = <String, Map<String, dynamic>>{};
    final promptToTask = <String, Map<String, dynamic>>{};
    for (final child in children) {
      if (!visited.add(child)) continue;
      if (_isAgentContainerTool(child)) {
        final taskId = child['id'] as String?;
        if (taskId != null && taskId.isNotEmpty) {
          uuidToTask[taskId] = child;
        }
        final uuid = child['uuid'] as String?;
        if (uuid != null && uuid.isNotEmpty) {
          uuidToTask[uuid] = child;
        }
        final toolUseId = child['toolUseId'] as String?;
        if (toolUseId != null && toolUseId.isNotEmpty) {
          uuidToTask[toolUseId] = child;
        }
        final input = WireParsers.asMap(child['input']);
        final prompt = input?['prompt'] as String?;
        if (prompt != null && prompt.isNotEmpty) {
          promptToTask[prompt] = child;
        }
      }
    }
    if (uuidToTask.isEmpty && promptToTask.isEmpty) return;

    // Pre-seed uuidToGroupedTask from inner Tasks' own uuids,
    // toolUseIds, persisted sidechain-root uuids, and existing
    // children's uuids so new arrivals can be matched.
    final uuidToGroupedTask = <String, Map<String, dynamic>>{};
    for (final child in children) {
      if (child['kind'] == 'tool-call' &&
          (child['name'] == 'Task' ||
              child['name'] == 'Agent' ||
              child['name'] == 'Workflow')) {
        final id = child['id'] as String?;
        if (id != null && id.isNotEmpty) {
          uuidToGroupedTask[id] = child;
        }
        final taskUuid = child['uuid'] as String?;
        if (taskUuid != null && taskUuid.isNotEmpty) {
          uuidToGroupedTask[taskUuid] = child;
        }
        final toolUseId = child['toolUseId'] as String?;
        if (toolUseId != null && toolUseId.isNotEmpty) {
          uuidToGroupedTask[toolUseId] = child;
        }
        final rootUuids = child['_sidechainRootUuids'] as List<dynamic>?;
        if (rootUuids != null) {
          for (final ru in rootUuids) {
            if (ru is String && ru.isNotEmpty) {
              uuidToGroupedTask[ru] = child;
            }
          }
        }
        final existingChildren = child['children'] as List<dynamic>?;
        if (existingChildren != null) {
          for (final ec in existingChildren) {
            if (ec is Map<String, dynamic>) {
              final ecId = ec['id'] as String?;
              if (ecId != null && ecId.isNotEmpty) {
                uuidToGroupedTask[ecId] = child;
              }
              final ecUuid = ec['uuid'] as String?;
              if (ecUuid != null && ecUuid.isNotEmpty) {
                uuidToGroupedTask[ecUuid] = child;
              }
              final ecToolUseId = ec['toolUseId'] as String?;
              if (ecToolUseId != null && ecToolUseId.isNotEmpty) {
                uuidToGroupedTask[ecToolUseId] = child;
              }
              final ecParentUuid = ec['parentUuid'] as String?;
              if (ecParentUuid != null && ecParentUuid.isNotEmpty) {
                uuidToGroupedTask[ecParentUuid] = child;
              }
            }
          }
        }
      }
    }

    // Find sidechain-root messages matching inner Tasks.
    final toRemove = <int>{};

    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      if (child['kind'] == 'sidechain-root') {
        final prompt = child['prompt'] as String?;
        final uuid = child['uuid'] as String?;
        final parentUuid = child['parentUuid'] as String?;
        final task = (parentUuid != null && uuidToTask.containsKey(parentUuid))
            ? uuidToTask[parentUuid]
            : (prompt != null ? promptToTask[prompt] : null);
        if (task != null && uuid != null) {
          uuidToGroupedTask[uuid] = task;
          final roots =
              (task['_sidechainRootUuids'] as List<dynamic>?) ?? <String>[];
          if (!roots.contains(uuid)) {
            task['_sidechainRootUuids'] = [...roots, uuid];
          }
          toRemove.add(i);
        }
      }
    }

    // Group sidechain children under their inner Tasks.
    final taskChildren = <String, List<Map<String, dynamic>>>{};
    for (var i = 0; i < children.length; i++) {
      if (toRemove.contains(i)) continue;
      final child = children[i];
      if (child['isSidechain'] == true) {
        final parentUuid = child['parentUuid'] as String?;
        final uuid = child['uuid'] as String?;
        if (parentUuid != null && uuidToGroupedTask.containsKey(parentUuid)) {
          final task = uuidToGroupedTask[parentUuid]!;
          final taskId = task['id'] as String?;
          if (taskId == null || taskId.isEmpty) continue;
          // Refuse to attach a message to itself.  A Task whose
          // parentUuid resolves to its own id/uuid/toolUseId would
          // otherwise end up in its own children array, creating a
          // cycle that crashes subsequent grouping passes.
          if (identical(child, task)) continue;
          final childId = child['id'] as String?;
          if (childId != null && childId == taskId) continue;
          taskChildren.putIfAbsent(taskId, () => []).add(child);
          final id = child['id'] as String?;
          if (id != null && id.isNotEmpty) {
            uuidToGroupedTask[id] = task;
          }
          if (uuid != null) {
            uuidToGroupedTask[uuid] = task;
          }
          final toolUseId = child['toolUseId'] as String?;
          if (toolUseId != null && toolUseId.isNotEmpty) {
            uuidToGroupedTask[toolUseId] = task;
          }
          toRemove.add(i);
        }
      }
    }

    // Attach children to inner Tasks (merge with existing).
    for (final entry in taskChildren.entries) {
      for (final child in children) {
        if (child['id'] == entry.key) {
          final existing = child['children'] as List<dynamic>?;
          if (existing != null && existing.isNotEmpty) {
            final existingIds = <String>{};
            for (final c in existing) {
              if (c is Map<String, dynamic>) {
                existingIds.addAll(_messageIdentityKeys(c));
              }
            }
            for (final newChild in entry.value) {
              final newKeys = _messageIdentityKeys(newChild);
              if (newKeys.isEmpty ||
                  existingIds.intersection(newKeys).isEmpty) {
                existing.add(newChild);
                existingIds.addAll(newKeys);
              }
            }
            regroupNestedTasks(
              existing.cast<Map<String, dynamic>>(),
              visited: visited,
              depth: depth + 1,
            );
          } else {
            child['children'] = entry.value;
            regroupNestedTasks(entry.value, visited: visited, depth: depth + 1);
          }
          break;
        }
      }
    }

    // Remove regrouped messages (reverse order).
    final indices = toRemove.toList()..sort((a, b) => b.compareTo(a));
    for (final i in indices) {
      children.removeAt(i);
    }
  }
}
