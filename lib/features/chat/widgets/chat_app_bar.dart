import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/components/app_status_dot.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_utils.dart';
import '../../sessions/session_avatar.dart';

/// App bar for the chat screen showing session title,
/// status, model info, and action buttons.
class ChatAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ChatAppBar({
    required this.session,
    required this.sessionTitle,
    required this.statusText,
    required this.statusColor,
    required this.isThinking,
    required this.onMenuTap,
    required this.onInfoTap,
    this.modelLabel,
    this.avatarStyle,
    super.key,
  });

  final Session? session;
  final String sessionTitle;
  final String statusText;
  final Color statusColor;
  final bool isThinking;
  final VoidCallback onMenuTap;
  final VoidCallback onInfoTap;
  final String? modelLabel;
  final AvatarStyle? avatarStyle;

  @override
  Size get preferredSize =>
      const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 0,
      title: _buildTitle(context),
      scrolledUnderElevation: 0.5,
      actions: [
        _AppBarAction(
          icon: Icons.info_outline_rounded,
          tooltip: context.l10n.chatSessionSettings,
          onPressed: onInfoTap,
        ),
        _AppBarAction(
          icon: Icons.more_horiz_rounded,
          tooltip: context.l10n.chatMoreOptions,
          onPressed: onMenuTap,
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }

  Widget _buildTitle(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (session == null) {
      return Text(
        context.l10n.chatChat,
        style: textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      );
    }

    final currentSession = session!;
    final flavor = currentSession.metadata?.flavor;
    final avatarId = getSessionAvatarId(currentSession);

    return GestureDetector(
      onTap: onInfoTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Hero(
            tag: 'session-avatar-${currentSession.id}',
            child: SessionAvatar(
              id: avatarId,
              flavor: flavor,
              size: 34,
              showFlavorIcon: true,
              square: true,
              style: avatarStyle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sessionTitle,
                  style: textTheme.titleSmall
                      ?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                _StatusRow(
                  isThinking: isThinking,
                  statusText: statusText,
                  statusColor: statusColor,
                  modelLabel: modelLabel,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated status row that cross-fades between
/// typing indicator and status text.
class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.isThinking,
    required this.statusText,
    required this.statusColor,
    this.modelLabel,
  });

  final bool isThinking;
  final String statusText;
  final Color statusColor;
  final String? modelLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final statusStyle = theme.textTheme.labelSmall
        ?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w400,
          fontSize: AppFontSize.xs,
          height: 1.2,
        );

    return AnimatedSwitcher(
      duration: AppDuration.normal,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) {
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.15),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        );
      },
      child: isThinking
          ? _AppBarTypingIndicator(
              key: const ValueKey('typing'),
              color: cs.primary,
              label: statusText,
            )
          : Row(
              key: ValueKey('status-$statusText'),
              mainAxisSize: MainAxisSize.min,
              children: [
                AppStatusDot(
                  color: statusColor,
                  pulse: statusColor == AppColors.success,
                  size: 6,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    statusText,
                    style: statusStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (modelLabel != null &&
                    modelLabel!.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    child: Text(
                      '\u00B7',
                      style: statusStyle?.copyWith(
                        color: cs.onSurfaceVariant
                            .withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  Text(
                    modelLabel!,
                    style: statusStyle?.copyWith(
                      color: cs.onSurfaceVariant
                          .withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
    );
  }
}

/// Compact action button for the app bar.
class _AppBarAction extends StatelessWidget {
  const _AppBarAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(icon),
      iconSize: 20,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        foregroundColor: cs.onSurfaceVariant,
        padding: const EdgeInsets.all(AppSpacing.sm),
        minimumSize: const Size(36, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () {
        HapticFeedback.selectionClick();
        onPressed();
      },
    );
  }
}

/// Compact three-dot typing indicator for the app bar
/// subtitle. Shows bouncing dots alongside a label.
class _AppBarTypingIndicator extends StatefulWidget {
  const _AppBarTypingIndicator({
    required this.color,
    this.label,
    super.key,
  });

  final Color color;
  final String? label;

  @override
  State<_AppBarTypingIndicator> createState() =>
      _AppBarTypingIndicatorState();
}

class _AppBarTypingIndicatorState
    extends State<_AppBarTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SizedBox(
      height: 16,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _ctrl,
              builder: (context, child) {
                final phase = (_ctrl.value + i * 0.2) % 1.0;
                final y = -2.0 *
                    (phase < 0.5
                        ? phase * 2
                        : 2.0 - phase * 2);
                return Transform.translate(
                  offset: Offset(0, y),
                  child: child,
                );
              },
              child: Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.symmetric(
                  horizontal: 1.5,
                ),
                decoration: BoxDecoration(
                  color: widget.color.withAlpha(200),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
          if (widget.label != null &&
              widget.label!.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(
              widget.label!,
              style: theme.textTheme.labelSmall
                  ?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w500,
                    fontSize: AppFontSize.xs,
                    height: 1.2,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
