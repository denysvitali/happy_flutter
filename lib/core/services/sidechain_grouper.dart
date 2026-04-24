import '../utils/wire_parsers.dart';

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
  ({List<Map<String, dynamic>> messages, bool hasOrphans})?
      groupMessages(
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
                (name == 'Task' || name == 'Agent'))) {
          hasSidechainRelevant = true;
          break;
        }
      }
      if (!hasSidechainRelevant) {
        // Fast path: the changed messages aren't
        // sidechain-relevant, but there may still be orphans
        // in the list from previous sidechain batches.
        final hasOrphans = messages.any(
          (m) => m['isSidechain'] == true,
        );
        return hasOrphans
            ? (messages: messages, hasOrphans: true)
            : null;
      }
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

    void walkAndIndex(
      List<dynamic> msgs,
      String? ancestorTaskId,
    ) {
      for (final m in msgs) {
        if (m is! Map<String, dynamic>) continue;
        final isTask = m['kind'] == 'tool-call' &&
            (m['name'] == 'Task' || m['name'] == 'Agent');
        var nextAncestorId = ancestorTaskId;
        if (isTask) {
          final taskId = m['id'] as String;
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
          final rootUuids =
              m['_sidechainRootUuids'] as List<dynamic>?;
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
            uuidToSidechainId.putIfAbsent(
              toolUseId,
              () => ancestorTaskId,
            );
          }
          final parentUuid = m['parentUuid'] as String?;
          if (parentUuid != null && parentUuid.isNotEmpty) {
            uuidToSidechainId.putIfAbsent(
              parentUuid,
              () => ancestorTaskId,
            );
          }
        }
        final children = m['children'] as List<dynamic>?;
        if (children != null) walkAndIndex(children, nextAncestorId);
      }
    }

    walkAndIndex(messages, null);

    if (taskIdToTask.isEmpty) return null;

    // Pass 2: Combined pass to find sidechain roots and group
    // child messages in a single iteration.  Operates on the
    // flat top-level list only — sidechain messages for
    // nested Tasks still arrive here before being grouped.
    final sidechainChildren =
        <String, List<Map<String, dynamic>>>{};
    final sidechainMsgIds = <String>{};

    for (final msg in messages) {
      if (msg['kind'] == 'sidechain-root') {
        final prompt = msg['prompt'] as String?;
        final uuid = msg['uuid'] as String?;
        final parentUuid = msg['parentUuid'] as String?;
        final sidechainId = (parentUuid != null &&
                uuidToTaskId.containsKey(parentUuid))
            ? uuidToTaskId[parentUuid]
            : (prompt != null ? promptToTaskId[prompt] : null);
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
                  (task['_sidechainRootUuids'] as List<dynamic>?) ??
                      <String>[];
              if (!roots.contains(uuid)) {
                task['_sidechainRootUuids'] = [...roots, uuid];
              }
            }
          }
          sidechainMsgIds.add(msg['id'] as String);
        }
      } else if (msg['isSidechain'] == true ||
          ((msg['parentUuid'] as String?)?.isNotEmpty ?? false)) {
        final uuid = msg['uuid'] as String?;
        final parentUuid = msg['parentUuid'] as String?;
        // Try prompt fallback for isSidechain children: if the parent
        // couldn't be found by uuid, the message's prompt field (from
        // WireParsers.asMap(input)['prompt']) might match a Task.
        final prompt = WireParsers.asMap(msg['input'])['prompt'] as String?;

        // First try uuidToSidechainId (nearest-ancestor index),
        // then fall back to promptToTaskId like sidechain-root does.
        String? sidechainId;
        if (parentUuid != null) {
          final p = parentUuid;
          if (uuidToSidechainId.containsKey(p)) {
            sidechainId = uuidToSidechainId[p];
          } else if (prompt != null && promptToTaskId.containsKey(prompt)) {
            sidechainId = promptToTaskId[prompt];
          }
        } else if (prompt != null && promptToTaskId.containsKey(prompt)) {
          sidechainId = promptToTaskId[prompt];
        }

        if (sidechainId != null) {
          final id = msg['id'] as String?;
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
          sidechainChildren
              .putIfAbsent(sidechainId, () => [])
              .add(msg);
          sidechainMsgIds.add(msg['id'] as String);
        }
      }
    }

    if (sidechainMsgIds.isEmpty) {
      final hasOrphans = messages.any((m) => m['isSidechain'] == true);
      return hasOrphans
          ? (messages: messages, hasOrphans: true)
          : null;
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
            final id = c['id'] as String?;
            if (id != null) existingIds.add(id);
          }
        }
        for (final newChild in newChildren) {
          final newId = newChild['id'] as String?;
          if (newId == null || !existingIds.contains(newId)) {
            existing.add(newChild);
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
        regroupNestedTasks(
          children.whereType<Map<String, dynamic>>().toList(),
        );
      }
    }

    final hasOrphans = filtered.any(
      (m) => m['isSidechain'] == true,
    );
    return (messages: filtered, hasOrphans: hasOrphans);
  }

  /// Recursively regroup sidechain children so nested
  /// Task tool-calls within a children array get their
  /// own children sub-arrays.
  void regroupNestedTasks(List<Map<String, dynamic>> children) {
    // Find inner Task tool-calls and their stable identifiers.
    final uuidToTask = <String, Map<String, dynamic>>{};
    final promptToTask = <String, Map<String, dynamic>>{};
    for (final child in children) {
      if (child['kind'] == 'tool-call' &&
          (child['name'] == 'Task' ||
              child['name'] == 'Agent')) {
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
              child['name'] == 'Agent')) {
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
        final rootUuids =
            child['_sidechainRootUuids'] as List<dynamic>?;
        if (rootUuids != null) {
          for (final ru in rootUuids) {
            if (ru is String && ru.isNotEmpty) {
              uuidToGroupedTask[ru] = child;
            }
          }
        }
        final existingChildren =
            child['children'] as List<dynamic>?;
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
              final ecParentUuid =
                  ec['parentUuid'] as String?;
              if (ecParentUuid != null &&
                  ecParentUuid.isNotEmpty) {
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
        final task = (parentUuid != null &&
                uuidToTask.containsKey(parentUuid))
            ? uuidToTask[parentUuid]
            : (prompt != null ? promptToTask[prompt] : null);
        if (task != null && uuid != null) {
          uuidToGroupedTask[uuid] = task;
          final roots = (task['_sidechainRootUuids']
                  as List<dynamic>?) ??
              <String>[];
          if (!roots.contains(uuid)) {
            task['_sidechainRootUuids'] = [...roots, uuid];
          }
          toRemove.add(i);
        }
      }
    }

    // Group sidechain children under their inner Tasks.
    final taskChildren =
        <String, List<Map<String, dynamic>>>{};
    for (var i = 0; i < children.length; i++) {
      if (toRemove.contains(i)) continue;
      final child = children[i];
      if (child['isSidechain'] == true) {
        final parentUuid = child['parentUuid'] as String?;
        final uuid = child['uuid'] as String?;
        if (parentUuid != null &&
            uuidToGroupedTask.containsKey(parentUuid)) {
          final task = uuidToGroupedTask[parentUuid]!;
          final taskId = task['id'] as String;
          taskChildren
              .putIfAbsent(taskId, () => [])
              .add(child);
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
          final existing =
              child['children'] as List<dynamic>?;
          if (existing != null && existing.isNotEmpty) {
            final existingIds = <String>{};
            for (final c in existing) {
              if (c is Map<String, dynamic>) {
                final id = c['id'] as String?;
                if (id != null) existingIds.add(id);
              }
            }
            for (final newChild in entry.value) {
              final newId = newChild['id'] as String?;
              if (newId == null ||
                  !existingIds.contains(newId)) {
                existing.add(newChild);
              }
            }
            regroupNestedTasks(
              existing.cast<Map<String, dynamic>>(),
            );
          } else {
            child['children'] = entry.value;
            regroupNestedTasks(entry.value);
          }
          break;
        }
      }
    }

    // Remove regrouped messages (reverse order).
    final indices = toRemove.toList()
      ..sort((a, b) => b.compareTo(a));
    for (final i in indices) {
      children.removeAt(i);
    }
  }
}
