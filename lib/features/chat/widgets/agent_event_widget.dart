import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// Renders a centered system-style label for agent lifecycle events.
///
/// Returns an empty widget for telemetry-only events and malformed payloads.
class AgentEventWidget extends StatelessWidget {
  const AgentEventWidget({required this.event, super.key});

  final dynamic event;

  static const Set<String> _hiddenEventTypes = <String>{
    'ready',
    'thinking',
    'tool-execution-update',
    'usage_report',
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
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55)
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isUnrendered) ...[
              Icon(
                Icons.help_outline_rounded,
                size: 12,
                color: color,
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(color: color),
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
