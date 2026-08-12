import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/task_label.dart';
import '../tools/known_tools.dart';

/// Renders a centered system-style label for agent lifecycle events.
///
/// Returns an empty widget for telemetry-only events and malformed payloads.
class AgentEventWidget extends StatelessWidget {
  const AgentEventWidget({required this.event, this.message, super.key});

  final dynamic event;

  /// The full parent message map. Used to surface sub-agent tool activity
  /// (e.g. `subAgentLastTool`) that lives on the message envelope rather
  /// than on the inner `event` payload.
  final Map<String, dynamic>? message;

  static const Set<String> _hiddenEventTypes = <String>{
    'ready',
    'thinking',
    'thinking_done',
    'thinking_start',
    'tool-execution-update',
    // "<Tool> running (Ns)..." polls; the tool row's elapsed chip
    // already shows this live, and per-poll centered rows buried the
    // transcript (four identical lines for one long Bash).
    'tool-progress',
    'usage_report',
    // Raw ACP stream envelopes from older CLI builds. Content is already
    // materialised as durable message/thinking/tool-call rows; replaying the
    // raw events only produces "Unsupported agent event" spam.
    'grok-event',
    'opencode-event',
  };

  /// Resolves the user-visible label for an agent event, or `null` when
  /// the event has no renderable representation (unknown or telemetry-only
  /// types such as `usage_report`). Unknown event types are still
  /// renderable via a generic fallback label.
  static String? labelFor(dynamic event) => _eventLabel(event);

  /// Matches the legacy "tool running (Ns)..." progress label. Older
  /// builds emitted those polls as type-'message' events, and cached
  /// messages keep that shape until evicted — hide them by content so
  /// existing installs stop rendering the backlog too.
  static final RegExp _legacyToolProgressLabel = RegExp(
    r' running( \(\d+s\))?\.\.\.$',
  );

  /// Returns `false` for telemetry-only event types that intentionally do
  /// do not render in the main chat timeline.
  static bool shouldRenderInChat(dynamic event) {
    if (event is! Map<String, dynamic>) return false;
    final type = event['type'];
    // Malformed/legacy payloads without a type keep the generic
    // fallback row — hiding them would drop real agent output that
    // merely predates the type field (chat_screen_test pins this).
    if (type is! String) return true;
    if (_hiddenEventTypes.contains(type)) return false;
    if (type == 'message') {
      final message = event['message'];
      if (message is String && _legacyToolProgressLabel.hasMatch(message)) {
        return false;
      }
    }
    return true;
  }

  /// The sub-agent's currently running tool, when one is being tracked via
  /// `task_progress` events. Empty/null when the chip represents anything
  /// else (mode switch, completion summary, etc.).
  String? get _subAgentToolName {
    final raw = message?['subAgentLastTool'];
    if (raw is String && raw.isNotEmpty) return raw;
    return null;
  }

  /// Whether this chip is a sub-agent task lifecycle row (start/progress).
  /// Completion arrives as a `kind: text` card, never here.
  bool get _isTaskEvent => message?['taskEvent'] == true;

  /// `true` for the row marking where a task was spawned, so the timeline
  /// shows a start marker instead of only a completion card.
  bool get _isTaskStart => message?['taskPhase'] == 'task_started';

  /// Prefix shown before the label for a task lifecycle row. Derived from
  /// the phase so an update row does not claim the task is "running".
  String get _taskPhaseLabel => switch (message?['taskPhase']) {
    'task_started' => 'Task started',
    'task_updated' || 'task_notification' => 'Task updated',
    _ => 'Task running',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!shouldRenderInChat(event)) return const SizedBox.shrink();
    final label = event is Map<String, dynamic>
        ? _eventLabel(event) ?? _fallbackEventLabel(event)
        : null;
    if (label == null || label.isEmpty) return const SizedBox.shrink();
    final isUnrendered =
        event is Map<String, dynamic> && event['type'] == 'unrendered';
    final eventType = event is Map<String, dynamic>
        ? event['type'] as String?
        : null;
    final color = switch (eventType) {
      'message-steered' => theme.colorScheme.primary,
      'message-queued' => theme.colorScheme.secondary,
      _ when isUnrendered => theme.colorScheme.error,
      _ => theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
    };
    final subAgentTool = _subAgentToolName;
    // The leading chip already prints [subAgentTool]; task_progress wire
    // labels repeat it — either as the "<tool> · <description>" prefix
    // this handler composes, or inside the description itself (workflow
    // agents describe themselves as "<Description>: <agent-label>").
    // Strip every occurrence so the chip and the label don't say the same
    // thing twice.
    final displayLabel = subAgentTool == null
        ? label
        : stripToolName(label, subAgentTool);
    // Task lifecycle rows left-align into the same column as the tool
    // rows (sm outer + sm+2 inner); centered min-width blocks made the
    // labels zigzag horizontally down the transcript. Plain system
    // notices keep the centered divider treatment.
    // A payload with no description falls back to the phase name, which
    // would print "Task updated · Task updated". Show the prefix only.
    final labelIsPhaseOnly =
        _isTaskEvent &&
        (displayLabel.trim().isEmpty ||
            displayLabel.trim() == _taskPhaseLabel ||
            displayLabel.trim() == 'Task');
    final titleStyle = theme.textTheme.labelMedium?.copyWith(
      color: color,
      fontWeight: isUnrendered ? FontWeight.w600 : null,
    );
    final titleText = compactTaskLabel(displayLabel);
    final toolChip = subAgentTool == null
        ? const <Widget>[]
        : <Widget>[
            IconTheme(
              data: IconThemeData(size: 12, color: color),
              child: KnownTools.iconFor(subAgentTool, 12, color),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              subAgentTool,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ];
    if (_isTaskEvent) {
      // Status + tool on line 1; title on its own full-width line.
      // Cramming the title into the leftover strip after
      // "Task running · Bash" wrapped mid-word (`Read` / `ing …`).
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isTaskStart
                      ? Icons.play_circle_outline_rounded
                      : Icons.autorenew_rounded,
                  size: 13,
                  color: color,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  _taskPhaseLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (toolChip.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '·',
                    style: theme.textTheme.labelSmall?.copyWith(color: color),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  ...toolChip,
                ],
              ],
            ),
            if (!labelIsPhaseOnly)
              Padding(
                padding: const EdgeInsets.only(
                  left: 13 + AppSpacing.xs,
                  top: 1,
                ),
                child: Text(
                  titleText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                  textAlign: TextAlign.start,
                ),
              ),
          ],
        ),
      );
    }
    final rowChildren = <Widget>[
      if (subAgentTool != null) ...[
        ...toolChip,
        const SizedBox(width: AppSpacing.xs),
      ] else if (eventType == 'message-steered') ...[
        Icon(Icons.alt_route_rounded, size: 14, color: color),
        const SizedBox(width: AppSpacing.xs),
      ] else if (eventType == 'message-queued') ...[
        Icon(Icons.schedule_send_rounded, size: 14, color: color),
        const SizedBox(width: AppSpacing.xs),
      ] else if (isUnrendered) ...[
        Icon(Icons.warning_amber_rounded, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
      ],
      if (!labelIsPhaseOnly)
        Flexible(
          child: Text(
            // Defensive clamp: cached/legacy events can carry a whole
            // multi-line shell command as their label, which would
            // otherwise dump a wall of centered text into the timeline.
            titleText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
            textAlign: TextAlign.start,
          ),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Center(
        child: Row(mainAxisSize: MainAxisSize.min, children: rowChildren),
      ),
    );
  }

  /// Removes every whole-token occurrence of [tool] from [label] and
  /// tidies up the separator punctuation it leaves behind.
  ///
  /// `"hunt:a · Hunt: hunt:a"` with tool `"hunt:a"` becomes `"Hunt"`.
  /// `"Reading ~/.claude/foo"` with tool `"Read"` stays intact — a
  /// substring replace used to print `ing ~/.claude/foo`.
  /// Returns an empty string when nothing but the tool name remains.
  @visibleForTesting
  static String stripToolName(String label, String tool) {
    if (tool.isEmpty || !label.contains(tool)) return label;
    final token = RegExp(
      '(?<![A-Za-z0-9])${RegExp.escape(tool)}(?![A-Za-z0-9])',
    );
    final flattened = label
        .replaceAll(token, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return flattened
        .replaceAll(RegExp(r'^[:·\-–—,]+'), '')
        .replaceAll(RegExp(r'[:·\-–—,]+$'), '')
        .trim();
  }

  static String? _eventLabel(dynamic event) {
    if (event is! Map<String, dynamic>) return null;
    final type = event['type'] as String?;
    switch (type) {
      case 'switch':
        final mode = event['mode'] as String?;
        return mode != null ? 'Switched to $mode mode' : 'Mode switched';
      case 'message':
        return event['message'] as String?;
      case 'limit-reached':
        return event['message'] as String? ?? 'Usage limit reached';
      case 'unrendered':
        return event['message'] as String? ?? 'Unsupported agent message';
      case 'message-steered':
        return event['message'] as String? ?? 'Update sent to the active task';
      case 'message-queued':
        return event['message'] as String? ??
            'Message queued for the next turn';
      default:
        return null;
    }
  }

  static String? _fallbackEventLabel(Map<String, dynamic> event) {
    final message = event['message'];
    if (message is String && message.isNotEmpty) return message;

    final type = event['type'];
    if (type is String && type.isNotEmpty) {
      return 'Unsupported agent event ($type)';
    }

    return 'Unsupported agent event';
  }
}
