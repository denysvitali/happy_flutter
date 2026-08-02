import 'package:flutter/material.dart';

import '../../../core/components/app_badge.dart';
import '../../../core/components/app_status_dot.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_status.dart';

/// Session status indicator shown next to the session name.
///
/// Colour alone cannot carry this state: it is invisible to screen
/// readers and unreliable for colourblind users. Each state therefore
/// gets a distinct *shape* — filled dot (online), filled dot inside a
/// ring (approval needed), hollow ring (offline) — and a localized
/// [Semantics] label so TalkBack / VoiceOver announce it.
class SessionStatusIndicator extends StatelessWidget {
  const SessionStatusIndicator({
    required this.status,
    super.key,
    this.color,
    this.size = 7,
    this.pulse = false,
  });

  final SessionStatus status;

  /// Overrides the state colour (archived cards mute it).
  final Color? color;
  final double size;

  /// Forces the pulse animation on (e.g. unread messages).
  final bool pulse;

  String _label(BuildContext context) {
    final l10n = context.l10n;
    return switch (status.state) {
      SessionState.disconnected => l10n.statusOffline,
      SessionState.permissionRequired => l10n.statusPermissionRequired,
      SessionState.thinking => l10n.sessionInfoThinking,
      SessionState.waiting => l10n.statusOnline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Color(status.statusDotColor);
    final label = _label(context);

    if (status.state == SessionState.disconnected) {
      return Semantics(
        label: label,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: effectiveColor,
              width: AppBorder.thin,
            ),
          ),
        ),
      );
    }

    final dot = AppStatusDot(
      color: effectiveColor,
      pulse: status.isPulsing || pulse,
      size: size,
      semanticLabel: label,
    );

    if (status.state != SessionState.permissionRequired) return dot;

    // Approval needed: filled dot inside a ring, so it stays
    // distinguishable from plain "online" without relying on hue.
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: effectiveColor, width: AppBorder.hairline),
      ),
      child: dot,
    );
  }
}

/// Circular checkbox shown at the leading edge in selection
/// mode, replacing the status color bar.
class SelectionCheckbox extends StatelessWidget {
  const SelectionCheckbox({
    required this.isSelected,
    required this.borderRadius,
    super.key,
  });

  final bool isSelected;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: AppAvatarSize.small,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected
            ? cs.primary.withValues(alpha: AppOpacity.subtle)
            : Colors.transparent,
        borderRadius: BorderRadius.only(
          topLeft: borderRadius.topLeft,
          bottomLeft: borderRadius.bottomLeft,
        ),
      ),
      child: AnimatedContainer(
        duration: AppDuration.fast,
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? cs.primary : cs.surface,
          border: Border.all(
            color: isSelected
                ? cs.primary
                : cs.outline.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: isSelected
            ? Icon(Icons.check, size: AppIconSize.sm, color: cs.onPrimary)
            : null,
      ),
    );
  }
}

/// Draft icon overlay badge shown on avatar bottom-right corner.
class DraftBadge extends StatelessWidget {
  const DraftBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Positioned(
      bottom: 0,
      right: 0,
      child: Container(
        width: AppSpacing.lg,
        height: AppSpacing.lg,
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.85),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.drive_file_rename_outline,
          size: 10,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Task progress badge shown near the timestamp/status area.
class TodoProgressBadge extends StatelessWidget {
  const TodoProgressBadge({
    required this.completed,
    required this.total,
    super.key,
  });

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    return AppBadge(
      leading: const Icon(Icons.lightbulb_outline, size: 10),
      label: '$completed/$total',
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      labelStyle: const TextStyle(fontWeight: FontWeight.w500),
    );
  }
}

/// Unread message count badge shown on the trailing edge.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({
    required this.count,
    super.key,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          fontSize: AppFontSize.xxs,
          fontWeight: FontWeight.w600,
          color: cs.onPrimary,
        ),
      ),
    );
  }
}
