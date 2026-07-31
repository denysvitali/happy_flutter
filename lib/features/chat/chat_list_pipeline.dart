/// Pure list-policy helpers for the chat transcript.
///
/// Extracted so hide-tools / orphan / agent-event filtering can be
/// unit-tested without a widget tree.
library;

import '../../core/services/sidechain_grouper.dart'
    show isVisibleSidechainOrphan;

/// Default number of sidechain orphans rendered inline before the rest
/// collapse behind a "show N more" row.
///
/// Orphans are sub-agent messages whose parent Task never made it into the
/// loaded window. Recovery gives up after a bounded walk-back and the
/// grouper falls back to rendering them inline — which two production
/// sessions turned into 91 and 119 ungrouped tiles in a single transcript,
/// burying the actual conversation. Twenty is enough to see what the
/// sub-agent was doing without the transcript becoming the sub-agent's.
const int kSidechainOrphanInlineCap = 20;

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
/// - Collapses a consecutive run of sub-agent `task_progress` ticks to
///   one row per sub-agent (latest tick wins, first-seen order kept).
///   A workflow fan-out emits a tick per tool call per agent, which
///   otherwise buried the transcript under dozens of near-identical
///   centered chips. Terminal `task_notification` rows are `kind: text`
///   and are never folded.
/// - Caps a run of ungrouped sidechain orphans at
///   [sidechainOrphanInlineCap]: the newest `cap` stay inline and the
///   older ones collapse behind a single `sidechain-orphan-more` row
///   carrying `hiddenCount`. Pass `null` to render every orphan (what the
///   "show N more" affordance switches to).
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
  int? sidechainOrphanInlineCap = kSidechainOrphanInlineCap,
}) {
  final items = <Map<String, dynamic>?>[];
  var hiddenGroup = <Map<String, dynamic>>[];
  var taskGroup = <Map<String, dynamic>>[];
  var orphanGroup = <Map<String, dynamic>>[];
  String? lastModel;

  // Buffered orphans always precede anything appended after them, so every
  // site that appends to [items] flushes this first to stay chronological.
  void flushOrphanGroup() {
    if (orphanGroup.isEmpty) return;
    final cap = sidechainOrphanInlineCap;
    if (cap == null || orphanGroup.length <= cap) {
      items.addAll(orphanGroup);
    } else {
      final hiddenCount = orphanGroup.length - cap;
      final anchor = orphanGroup.first;
      final anchorId =
          anchor['id'] as String? ??
          anchor['toolUseId'] as String? ??
          'at-${items.length}';
      items
        ..add({
          'kind': 'sidechain-orphan-more',
          'id': 'sidechain-orphan-more-$anchorId',
          'role': 'system',
          'hiddenCount': hiddenCount,
        })
        // Keep the newest `cap` inline: the tail is the part of the
        // sub-agent run that leads into whatever comes next.
        ..addAll(orphanGroup.sublist(hiddenCount));
    }
    orphanGroup = <Map<String, dynamic>>[];
  }

  void flushTaskGroup() {
    if (taskGroup.isEmpty) return;
    flushOrphanGroup();
    // Insertion order is first-seen-per-agent so rows keep a stable
    // position while their label updates; the value is the latest tick.
    final latest = <String, Map<String, dynamic>>{};
    for (final msg in taskGroup) {
      latest[_taskTickKey(msg)] = msg;
    }
    items.addAll(latest.values);
    taskGroup = <Map<String, dynamic>>[];
  }

  void flushHiddenGroup() {
    if (hiddenGroup.isEmpty) return;
    flushOrphanGroup();
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
      if (_isTaskProgressTick(msg)) {
        // Ticks are visible rows, so anything already buffered as hidden
        // must land before them to stay chronological.
        flushHiddenGroup();
        taskGroup.add(msg);
        continue;
      }
      flushTaskGroup();
      // A model switch is worth showing even when it happens inside a
      // run of hidden tool calls, so the check runs before the
      // hide-filters and flushes the group to keep the divider in
      // chronological place.
      final model = _reportedModel(msg);
      if (model != null) {
        if (lastModel != null && lastModel != model) {
          flushHiddenGroup();
          flushOrphanGroup();
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
      // Ungrouped sub-agent messages buffer until a non-orphan row forces
      // the decision "render inline or collapse the older ones".
      if (isVisibleSidechainOrphan(msg)) {
        orphanGroup.add(msg);
        continue;
      }
      flushOrphanGroup();
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
  flushTaskGroup();
  flushHiddenGroup();
  flushOrphanGroup();
  return items;
}

/// Whether [msg] is an in-flight sub-agent progress chip. Completed
/// tasks arrive as `kind: text` summaries and are deliberately excluded.
bool _isTaskProgressTick(Map<String, dynamic> msg) =>
    msg['kind'] == 'agent-event' && msg['taskEvent'] == true;

/// Collapse key for a progress tick: the sub-agent it belongs to.
///
/// `agentId` (wire `task_id`) is unique per spawn and is the right
/// grain; the fallbacks only matter for older CLI builds that omitted
/// it, and degrade to "collapse identical chips" rather than merging
/// two different agents.
String _taskTickKey(Map<String, dynamic> msg) {
  final agentId = msg['agentId'];
  if (agentId is String && agentId.isNotEmpty) return 'agent:$agentId';
  final tool = msg['subAgentLastTool'];
  if (tool is String && tool.isNotEmpty) return 'tool:$tool';
  final event = msg['event'];
  if (event is Map) {
    final label = event['message'];
    if (label is String && label.isNotEmpty) return 'label:$label';
  }
  return 'id:${msg['id'] ?? identityHashCode(msg)}';
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
