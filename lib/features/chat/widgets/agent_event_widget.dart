import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// Renders a centered system-style label for agent lifecycle events.
///
/// Returns an empty widget for unknown or null event types.
class AgentEventWidget extends StatelessWidget {
  const AgentEventWidget({required this.event, super.key});

  final dynamic event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _eventLabel(event);
    if (label == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Center(
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(
              alpha: 0.6,
            ),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  String? _eventLabel(dynamic event) {
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
      default:
        return null;
    }
  }
}
