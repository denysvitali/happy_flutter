/// Pure list-policy helpers for the chat transcript.
///
/// Extracted so hide-tools / orphan / agent-event filtering can be
/// unit-tested without a widget tree.
library;

/// Predicate: should this agent-event be shown in the main chat.
typedef AgentEventRenderPredicate = bool Function(dynamic event);

/// Predicate: should this tool-call be collapsed into a summary row.
typedef HideToolCallPredicate =
    bool Function(Map<String, dynamic> msg, {required bool hideToolCalls});

/// Optional error sink so a single malformed message cannot abort
/// the list. When null, errors rethrow (unit tests).
typedef MessageErrorHandler =
    void Function(Map<String, dynamic> msg, Object error, StackTrace stack);

/// Builds the display item list for a visible window of messages.
///
/// - Drops `_orphanRecovery` synthetic placeholders
/// - Drops agent-events when [shouldRenderAgentEvent] returns false
/// - Collapses consecutive hidden tool-calls into one
///   `hidden-tool-summary` row when [hideToolCalls] is true
/// - Inserts a `null` sentinel after a user `/clear` message (divider)
///
/// Items may be `null` (cleared-divider markers). Callers that need a
/// non-null list should filter afterward.
List<Map<String, dynamic>?> buildChatListItems({
  required List<Map<String, dynamic>> visibleMessages,
  required bool hideToolCalls,
  required AgentEventRenderPredicate shouldRenderAgentEvent,
  required HideToolCallPredicate shouldHideToolCall,
  MessageErrorHandler? onMessageError,
}) {
  final items = <Map<String, dynamic>?>[];
  var hiddenToolCalls = <Map<String, dynamic>>[];

  void flushHiddenToolCalls() {
    if (hiddenToolCalls.isEmpty) return;
    final first =
        hiddenToolCalls.first['id'] as String? ??
        hiddenToolCalls.first['toolUseId'] as String? ??
        'hidden-tool-${items.length}';
    items.add({
      'kind': 'hidden-tool-summary',
      'id': 'hidden-tool-summary-$first',
      'role': 'agent',
      'tools': hiddenToolCalls,
    });
    hiddenToolCalls = <Map<String, dynamic>>[];
  }

  for (final msg in visibleMessages) {
    try {
      if (msg['_orphanRecovery'] == true) continue;
      if (msg['kind'] == 'agent-event' &&
          !shouldRenderAgentEvent(msg['event'])) {
        continue;
      }
      if (shouldHideToolCall(msg, hideToolCalls: hideToolCalls)) {
        hiddenToolCalls.add(msg);
        continue;
      }
      flushHiddenToolCalls();
      items.add(msg);
      final role = msg['role'] as String?;
      final content = msg['content'] ?? msg['text'];
      final text = content is String ? content : content?.toString() ?? '';
      if (role == 'user' && text.trim() == '/clear') {
        items.add(null);
      }
    } catch (e, st) {
      if (onMessageError != null) {
        onMessageError(msg, e, st);
      } else {
        rethrow;
      }
    }
  }
  flushHiddenToolCalls();
  return items;
}
