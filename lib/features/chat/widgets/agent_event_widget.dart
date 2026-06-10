import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// Renders a centered system-style label for agent lifecycle events.
///
/// Returns an empty widget for unknown or null event types.
class AgentEventWidget extends StatelessWidget {
  const AgentEventWidget({required this.event, super.key});

  final dynamic event;

  /// Resolves the user-visible label for an agent event, or `null` when
  /// the event has no renderable representation (unknown or telemetry-only
  /// types such as `usage_report`). Callers building message lists use
  /// this to skip label-less events entirely so they never occupy a
  /// padded list row.
  static String? labelFor(dynamic event) => _eventLabel(event);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _eventLabel(event);
    if (label == null) return const SizedBox.shrink();
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
}
