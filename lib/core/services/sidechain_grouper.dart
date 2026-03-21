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

    // Pass 1: Find Task tool calls → map stable identifiers to
    // task message ID. We index by uuid, toolUseId, AND prompt
    // so that sidechain messages can be matched even when
    // multiple Agent/Task calls share the same assistant message
    // uuid (common when Claude batches tool calls).
    final uuidToTaskId = <String, String>{};
    final promptToTaskId = <String, String>{};
    for (final msg in messages) {
      if (msg['kind'] == 'tool-call' &&
          (msg['name'] == 'Task' || msg['name'] == 'Agent')) {
        final taskId = msg['id'] as String;
        final uuid = msg['uuid'] as String?;
        if (uuid != null && uuid.isNotEmpty) {
          uuidToTaskId[uuid] = taskId;
        }
        final toolUseId = msg['toolUseId'] as String?;
        if (toolUseId != null && toolUseId.isNotEmpty) {
          uuidToTaskId[toolUseId] = taskId;
        }
        final input = msg['input'] as Map<String, dynamic>?;
        final prompt = input?['prompt'] as String?;
        if (prompt != null && prompt.isNotEmpty) {
          promptToTaskId[prompt] = taskId;
        }
      }
    }
    if (uuidToTaskId.isEmpty && promptToTaskId.isEmpty) return null;

    // Pre-seed uuidToSidechainId from Task uuids, persisted
    // sidechain-root uuids, and already-grouped children so
    // that new sidechain messages arriving after the
    // sidechain-root was removed can still be matched.
    final uuidToSidechainId = <String, String>{};
    for (final msg in messages) {
      if (msg['kind'] == 'tool-call' &&
          (msg['name'] == 'Task' || msg['name'] == 'Agent')) {
        final taskId = msg['id'] as String;
        final taskUuid = msg['uuid'] as String?;
        if (taskUuid != null && taskUuid.isNotEmpty) {
          uuidToSidechainId[taskUuid] = taskId;
        }
        final toolUseId = msg['toolUseId'] as String?;
        if (toolUseId != null && toolUseId.isNotEmpty) {
          uuidToSidechainId[toolUseId] = taskId;
        }
        final rootUuids =
            msg['_sidechainRootUuids'] as List<dynamic>?;
        if (rootUuids != null) {
          for (final ru in rootUuids) {
            if (ru is String && ru.isNotEmpty) {
              uuidToSidechainId[ru] = taskId;
            }
          }
        }
        final existing = msg['children'] as List<dynamic>?;
        if (existing != null) {
          for (final child in existing) {
            if (child is Map<String, dynamic>) {
              final childUuid = child['uuid'] as String?;
              if (childUuid != null && childUuid.isNotEmpty) {
                uuidToSidechainId[childUuid] = taskId;
              }
              final childParentUuid =
                  child['parentUuid'] as String?;
              if (childParentUuid != null &&
                  childParentUuid.isNotEmpty) {
                uuidToSidechainId[childParentUuid] = taskId;
              }
            }
          }
        }
      }
    }

    // Pass 2: Combined pass to find sidechain roots and group
    // child messages in a single iteration
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
            // is removed from the message list.
            for (final m in messages) {
              if (m['id'] == sidechainId) {
                final roots = (m['_sidechainRootUuids']
                        as List<dynamic>?) ??
                    <String>[];
                if (!roots.contains(uuid)) {
                  m['_sidechainRootUuids'] = [...roots, uuid];
                }
                break;
              }
            }
          }
          sidechainMsgIds.add(msg['id'] as String);
        }
      } else if (msg['isSidechain'] == true ||
          (msg['parentUuid'] as String?)?.isNotEmpty == true) {
        final uuid = msg['uuid'] as String?;
        final parentUuid = msg['parentUuid'] as String?;

        if (parentUuid != null &&
            uuidToSidechainId.containsKey(parentUuid)) {
          final sidechainId = uuidToSidechainId[parentUuid]!;
          if (uuid != null) {
            uuidToSidechainId[uuid] = sidechainId;
          }
          sidechainChildren
              .putIfAbsent(sidechainId, () => [])
              .add(msg);
          sidechainMsgIds.add(msg['id'] as String);
        }
      }
    }

    if (sidechainMsgIds.isEmpty) return null;

    // Pass 3: Remove sidechain messages from main list, attach
    // children to Task tool-call messages
    final filtered = <Map<String, dynamic>>[];
    for (final msg in messages) {
      final msgId = msg['id'] as String;
      if (sidechainMsgIds.contains(msgId)) continue;

      if (sidechainChildren.containsKey(msgId)) {
        final existing = msg['children'] as List<dynamic>?;
        if (existing != null && existing.isNotEmpty) {
          // Merge: append new children, skip duplicates.
          final existingIds = <String>{};
          for (final c in existing) {
            if (c is Map<String, dynamic>) {
              final id = c['id'] as String?;
              if (id != null) existingIds.add(id);
            }
          }
          for (final newChild in sidechainChildren[msgId]!) {
            final newId = newChild['id'] as String?;
            if (newId == null || !existingIds.contains(newId)) {
              existing.add(newChild);
            }
          }
        } else {
          msg['children'] = sidechainChildren[msgId];
        }
      }
      filtered.add(msg);
    }

    // Pass 4: Recursively group nested Task children.
    for (final msg in filtered) {
      final children = msg['children'] as List<dynamic>?;
      if (children != null && children.isNotEmpty) {
        regroupNestedTasks(
          children.cast<Map<String, dynamic>>(),
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
        final uuid = child['uuid'] as String?;
        if (uuid != null && uuid.isNotEmpty) {
          uuidToTask[uuid] = child;
        }
        final toolUseId = child['toolUseId'] as String?;
        if (toolUseId != null && toolUseId.isNotEmpty) {
          uuidToTask[toolUseId] = child;
        }
        final input = child['input'] as Map<String, dynamic>?;
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
              final ecUuid = ec['uuid'] as String?;
              if (ecUuid != null && ecUuid.isNotEmpty) {
                uuidToGroupedTask[ecUuid] = child;
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
          if (uuid != null) {
            uuidToGroupedTask[uuid] = task;
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
