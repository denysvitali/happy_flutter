import '../models/session.dart';
import '../utils/wire_parsers.dart';

/// Processes tool results and permission requests against
/// message lists.
///
/// Extracted from [Sync] to enable isolated testing of:
/// - tool result → tool-call message matching
/// - permission stamping from AgentState
/// - stale permission cleanup
class ToolResultProcessor {
  /// Apply tool results to tool-call messages by matching
  /// `toolUseId`. Recurses into `children` arrays.
  ///
  /// Returns `(updatedMessages, changed, matchedToolUseIds)`.
  ({List<Map<String, dynamic>> messages, bool changed, Set<String> matchedIds})
  applyToolResults(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> toolResults,
  ) {
    final toolResultsById = <String, Map<String, dynamic>>{};
    for (final result in toolResults) {
      final toolUseId = result['toolUseId'] as String?;
      if (toolUseId == null || toolUseId.isEmpty) continue;
      toolResultsById[toolUseId] = result;
    }
    if (toolResultsById.isEmpty) {
      return (messages: messages, changed: false, matchedIds: <String>{});
    }

    final (updated, changed, matched) = _applyRecursive(
      messages,
      toolResultsById,
      visited: <Map<String, dynamic>>{},
    );
    return (messages: updated, changed: changed, matchedIds: matched);
  }

  (List<Map<String, dynamic>>, bool, Set<String>) _applyRecursive(
    List<Map<String, dynamic>> messages,
    Map<String, Map<String, dynamic>> toolResultsById, {
    required Set<Map<String, dynamic>> visited,
  }) {
    var changed = false;
    final matchedIds = <String>{};
    final updated = <Map<String, dynamic>>[];

    for (final msg in messages) {
      if (!visited.add(msg)) {
        updated.add(msg);
        continue;
      }

      var next = msg;

      final children = msg['children'];
      if (children is List<dynamic>) {
        final typedChildren = children
            .whereType<Map<String, dynamic>>()
            .toList();
        final (updatedChildren, childChanged, childMatched) = _applyRecursive(
          typedChildren,
          toolResultsById,
          visited: visited,
        );
        if (childChanged) {
          next = {...next, 'children': updatedChildren};
          changed = true;
        }
        matchedIds.addAll(childMatched);
      }

      if (msg['kind'] == 'tool-call') {
        final toolUseId = msg['toolUseId'] as String?;
        final result = toolUseId != null ? toolResultsById[toolUseId] : null;
        if (result != null) {
          final isError = result['isError'] == true;

          Map<String, dynamic>? permissionUpdate;
          final perms = result['permissions'];
          if (perms is Map<String, dynamic>) {
            final permResult = perms['result'] as String?;
            final status = permResult == 'approved' ? 'approved' : 'denied';
            permissionUpdate = {
              'id': toolUseId,
              'status': status,
              if (perms['date'] != null) 'date': perms['date'],
              if (perms['mode'] != null) 'mode': perms['mode'],
              if (perms['allowedTools'] != null)
                'allowedTools': perms['allowedTools'],
              if (perms['decision'] != null) 'decision': perms['decision'],
            };
          }

          next = {
            ...next,
            'state': isError ? 'error' : 'completed',
            'result': result['result'],
            'completedAt': result['createdAt'],
            'permission': ?permissionUpdate,
          };
          changed = true;
          matchedIds.add(toolUseId!);
        }
      }

      updated.add(next);
    }

    return (updated, changed, matchedIds);
  }

  /// Stamp permission data from [AgentState] onto tool-call
  /// messages.
  ///
  /// Returns `(updatedMessages, changed, resolvedPermIds)`
  /// where [resolvedPermIds] contains IDs from
  /// `completedRequests` that should have their notifications
  /// canceled.
  ({
    List<Map<String, dynamic>> messages,
    bool changed,
    Set<String> resolvedPermIds,
  })
  applyPermissionRequests(
    List<Map<String, dynamic>> messages,
    AgentState agentState,
    Set<String> notifiedPermissionIds,
  ) {
    final requests = agentState.requests;
    final completedRequests = agentState.completedRequests;
    final resolvedPermIds = <String>{};

    if ((requests == null || requests.isEmpty) &&
        (completedRequests == null || completedRequests.isEmpty)) {
      return (
        messages: messages,
        changed: false,
        resolvedPermIds: resolvedPermIds,
      );
    }

    // Build a lookup: toolUseId → index in list.
    final toolUseIdToIndex = <String, int>{};
    for (var i = 0; i < messages.length; i++) {
      final msg = messages[i];
      if (msg['kind'] == 'tool-call') {
        final id = msg['toolUseId'] as String?;
        if (id != null) toolUseIdToIndex[id] = i;
      }
    }

    var result = messages;
    var copied = false;

    void ensureCopied() {
      if (!copied) {
        result = List<Map<String, dynamic>>.from(messages);
        copied = true;
      }
    }

    // Stamp pending permissions.
    if (requests != null) {
      for (final entry in requests.entries) {
        final permId = entry.key;
        final idx = toolUseIdToIndex[permId];
        if (idx == null) continue;

        final msg = result[idx];
        final existingPerm = WireParsers.asMap(msg['permission']);
        if (existingPerm == null) {
          ensureCopied();
          result[idx] = {
            ...msg,
            'permission': {'id': permId, 'status': 'pending'},
          };
        } else if (existingPerm['id'] == null) {
          ensureCopied();
          result[idx] = {
            ...msg,
            'permission': {...existingPerm, 'id': permId},
          };
        }
      }
    }

    // Stamp completed permissions.
    if (completedRequests != null) {
      for (final entry in completedRequests.entries) {
        final permId = entry.key;
        final info = entry.value;

        if (notifiedPermissionIds.contains(permId)) {
          resolvedPermIds.add(permId);
        }

        final idx = toolUseIdToIndex[permId];
        if (idx == null) continue;

        final msg = result[idx];
        final existingPerm = WireParsers.asMap(msg['permission']);
        if (existingPerm != null &&
            existingPerm['status'] != 'pending' &&
            existingPerm['id'] != null) {
          continue;
        }

        ensureCopied();
        result[idx] = {
          ...msg,
          'permission': {
            'id': permId,
            'status': info.status,
            if (info.mode != null) 'mode': info.mode,
            if (info.allowedTools != null) 'allowedTools': info.allowedTools,
            if (info.decision != null) 'decision': info.decision,
            if (info.reason != null) 'reason': info.reason,
          },
        };
      }
    }

    // Clear stale pending permissions.
    final pendingIds = requests?.keys.toSet() ?? <String>{};
    for (var i = 0; i < result.length; i++) {
      final msg = result[i];
      if (msg['kind'] != 'tool-call') continue;
      final perm = WireParsers.asMap(msg['permission']);
      if (perm == null) continue;
      final status = perm['status'] as String?;
      if (status != 'pending') continue;
      final permId = perm['id'] as String?;
      if (permId != null && !pendingIds.contains(permId)) {
        ensureCopied();
        result[i] = {
          ...msg,
          'permission': {...perm, 'status': 'canceled'},
        };
      }
    }

    return (
      messages: result,
      changed: copied,
      resolvedPermIds: resolvedPermIds,
    );
  }
}
