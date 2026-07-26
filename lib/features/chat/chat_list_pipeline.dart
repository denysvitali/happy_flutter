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
/// - When [hideToolCalls] is true, collapses consecutive hidden
///   tool-calls AND thinking blocks into one `hidden-tool-summary`
///   row. Thinking folds into the same group so an agentic loop
///   (think -> tool -> think -> tool) renders as a single summary
///   instead of an alternating wall of "Thinking" and
///   "1 tool complete" rows. The summary exposes two keys:
///   `tools` (tool-calls only, drives the counts label) and
///   `items` (everything collapsed, in original order).
/// - Inserts a `null` sentinel after a user `/clear` message (divider)
/// - Inserts a `model-change` marker row when the model reported by the
///   agent changes mid-session (a fallback, a `/model` switch, or the CLI
///   downgrading under load). The first model seen produces no marker —
///   only transitions are worth surfacing.
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
  var hiddenGroup = <Map<String, dynamic>>[];
  String? lastModel;

  void flushHiddenGroup() {
    if (hiddenGroup.isEmpty) return;
    final first =
        hiddenGroup.first['id'] as String? ??
        hiddenGroup.first['toolUseId'] as String? ??
        'hidden-tool-${items.length}';
    items.add({
      'kind': 'hidden-tool-summary',
      'id': 'hidden-tool-summary-$first',
      'role': 'agent',
      // Tool calls only — drives the "N tools complete" counts.
      'tools': hiddenGroup
          .where((m) => m['kind'] == 'tool-call')
          .toList(growable: false),
      // Everything collapsed, in original order (tools + thinking) —
      // rendered when the summary row is expanded.
      'items': List<Map<String, dynamic>>.unmodifiable(hiddenGroup),
    });
    hiddenGroup = <Map<String, dynamic>>[];
  }

  for (final msg in visibleMessages) {
    try {
      if (msg['_orphanRecovery'] == true) continue;
      if (msg['kind'] == 'agent-event' &&
          !shouldRenderAgentEvent(msg['event'])) {
        continue;
      }
      // A model switch is worth showing even when it happens inside a
      // run of hidden tool calls, so the check runs before the
      // hide-filters and flushes the group to keep the divider in
      // chronological place.
      final model = _reportedModel(msg);
      if (model != null) {
        if (lastModel != null && lastModel != model) {
          flushHiddenGroup();
          items.add({
            'kind': 'model-change',
            'id': 'model-change-${msg['id'] ?? items.length}',
            'role': 'system',
            'fromModel': lastModel,
            'toModel': model,
          });
        }
        lastModel = model;
      }
      // With tool calls hidden, thinking blocks fold into the same
      // collapsed group — they are working noise too, and leaving them
      // inline would break tool runs into many "1 tool complete" rows.
      if (hideToolCalls && msg['isThinking'] == true) {
        hiddenGroup.add(msg);
        continue;
      }
      if (shouldHideToolCall(msg, hideToolCalls: hideToolCalls)) {
        hiddenGroup.add(msg);
        continue;
      }
      flushHiddenGroup();
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
  flushHiddenGroup();
  return items;
}

/// The inference model a message was produced by, or null when the
/// message says nothing about the model.
///
/// Sidechains are excluded: a subagent legitimately runs a different
/// model, and letting it move [buildChatListItems]'s cursor would emit a
/// spurious pair of dividers around every Task tool call.
String? _reportedModel(Map<String, dynamic> msg) {
  if (msg['role'] != 'agent') return null;
  if (msg['isSidechain'] == true) return null;
  if (msg['parentToolUseId'] != null) return null;
  final model = msg['model'];
  if (model is! String) return null;
  final trimmed = model.trim();
  return trimmed.isEmpty ? null : trimmed;
}
