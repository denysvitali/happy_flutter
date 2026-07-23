import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
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

  /// Returns `false` for telemetry-only event types that intentionally do
  /// do not render in the main chat timeline.
  static bool shouldRenderInChat(dynamic event) {
    if (event is! Map<String, dynamic>) return false;
    final type = event['type'];
    return type is! String || !_hiddenEventTypes.contains(type);
  }

  /// The sub-agent's currently running tool, when one is being tracked via
  /// `task_progress` events. Empty/null when the chip represents anything
  /// else (mode switch, completion summary, etc.).
  String? get _subAgentToolName {
    final raw = message?['subAgentLastTool'];
    if (raw is String && raw.isNotEmpty) return raw;
    return null;
  }

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
    final color = isUnrendered
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85);
    final subAgentTool = _subAgentToolName;
    // The leading chip already prints [subAgentTool]; the wire label for
    // task_progress ticks is composed as "<tool> · <description>", which
    // would repeat the tool name. Strip that prefix so the chip and the
    // label don't say the same thing twice.
    var displayLabel = label;
    if (subAgentTool != null) {
      const sep = ' · ';
      if (displayLabel.startsWith('$subAgentTool$sep')) {
        final n = subAgentTool.length + sep.length;
        displayLabel = displayLabel.substring(n);
      } else if (displayLabel == subAgentTool) {
        displayLabel = '';
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (subAgentTool != null) ...[
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
              const SizedBox(width: AppSpacing.xs),
            ] else if (isUnrendered) ...[
              Icon(Icons.warning_amber_rounded, size: 16, color: color),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                displayLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: isUnrendered ? FontWeight.w600 : null,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
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
