import 'package:flutter/material.dart';

import '../../../../core/components/app_card.dart';
import '../../../../core/components/settings_section.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../models/connection_event.dart';
import '../../../../core/utils/utils.dart';

/// Card displaying a single connection event
class ConnectionEventCard extends StatelessWidget {
  const ConnectionEventCard({
    required this.event,
    super.key,
  });

  final ConnectionEvent event;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = _getEventIcon();
    final color = _getEventColor(cs);

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          SettingsIconContainer(
            icon: icon,
            color: color,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getEventTitle(),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${event.deviceName}  ·  '
                  '${event.username}'
                  '${event.ipAddress != null ? '  ·  ${event.ipAddress}' : ''}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            _formatTime(event.timestamp),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  IconData _getEventIcon() {
    switch (event.eventType) {
      case ConnectionEventType.connect:
        return Icons.login;
      case ConnectionEventType.disconnect:
        return Icons.logout;
      case ConnectionEventType.authSuccess:
        return Icons.verified_user;
      case ConnectionEventType.authFailure:
        return Icons.gpp_bad;
      case ConnectionEventType.sessionStart:
        return Icons.play_circle;
      case ConnectionEventType.sessionEnd:
        return Icons.stop_circle;
    }
  }

  Color _getEventColor(ColorScheme cs) {
    switch (event.eventType) {
      case ConnectionEventType.connect:
      case ConnectionEventType.sessionStart:
        return cs.primary;
      case ConnectionEventType.disconnect:
      case ConnectionEventType.sessionEnd:
        return cs.onSurfaceVariant;
      case ConnectionEventType.authSuccess:
        return AppColors.success;
      case ConnectionEventType.authFailure:
        return cs.error;
    }
  }

  String _getEventTitle() {
    switch (event.eventType) {
      case ConnectionEventType.connect:
        return 'Connected';
      case ConnectionEventType.disconnect:
        return 'Disconnected'
            '${event.reason != null ? ': ${event.reason}' : ''}';
      case ConnectionEventType.authSuccess:
        return 'Authentication successful';
      case ConnectionEventType.authFailure:
        return 'Authentication failed';
      case ConnectionEventType.sessionStart:
        return 'Session started';
      case ConnectionEventType.sessionEnd:
        final dur = event.duration;
        return 'Session ended'
            '${dur != null ? ' (${formatDuration(dur)})' : ''}';
    }
  }

  String _formatTime(DateTime dt) => formatRelativeTime(dt);
}

/// A filter chip for connection event types
class EventTypeChip extends StatelessWidget {
  const EventTypeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    super.key,
    this.color,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: AppFontSize.sm,
          color: isSelected
              ? Theme.of(context).colorScheme.onPrimary
              : null,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor:
          color ?? Theme.of(context).colorScheme.primary,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
      ),
      materialTapTargetSize:
          MaterialTapTargetSize.shrinkWrap,
    );
  }
}
