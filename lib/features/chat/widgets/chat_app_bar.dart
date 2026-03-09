import 'package:flutter/material.dart';
import '../../../core/components/app_status_dot.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/session.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_utils.dart';
import '../../sessions/session_avatar.dart';

/// App bar for the chat screen showing session title
/// and status.
class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({
    required this.session,
    required this.sessionTitle,
    required this.statusText,
    required this.statusColor,
    required this.isThinking,
    required this.onMenuTap,
    super.key,
  });

  final Session? session;
  final String sessionTitle;
  final String statusText;
  final Color statusColor;
  final bool isThinking;
  final VoidCallback onMenuTap;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: _buildTitle(context),
      scrolledUnderElevation: 0.5,
      actions: [
        IconButton(
          icon: const Icon(Icons.more_horiz_rounded),
          iconSize: 22,
          tooltip: context.l10n.chatMoreOptions,
          onPressed: onMenuTap,
        ),
      ],
    );
  }

  Widget _buildTitle(BuildContext context) {
    if (session == null) {
      return Text(context.l10n.chatChat);
    }

    final colorScheme = Theme.of(context).colorScheme;
    final currentSession = session!;
    final flavor = currentSession.metadata?.flavor;
    final avatarId = getSessionAvatarId(currentSession);

    return Row(
      children: [
        Hero(
          tag: 'session-avatar-${currentSession.id}',
          child: SessionAvatar(
            id: avatarId,
            flavor: flavor,
            size: 32,
            showFlavorIcon: true,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      sessionTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (flavor != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    SessionFlavorBadge(flavor: flavor, compact: true),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: isThinking
                    ? _TypingIndicator(
                        key: const ValueKey('typing'),
                        color: colorScheme.primary,
                      )
                    : Row(
                        key: const ValueKey('status'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppStatusDot(
                            color: statusColor,
                            pulse: false,
                            size: 6,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            statusText,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w400,
                                ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Animated three-dot typing indicator shown when the
/// assistant is actively processing.
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator({required this.color, super.key});

  final Color color;

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
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
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              final phase = (_ctrl.value + i * 0.2) % 1.0;
              final y = -2.0 * (phase < 0.5 ? phase * 2 : 2.0 - phase * 2);
              return Transform.translate(offset: Offset(0, y), child: child);
            },
            child: Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: widget.color.withAlpha(180),
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
      ),
    );
  }
}
