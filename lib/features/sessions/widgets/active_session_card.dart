import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/session.dart';
import '../../../core/theme/app_tokens.dart';
import '../session_avatar.dart';
import 'session_cards.dart';

/// Active session card with smooth press animation and
/// clear visual hierarchy.
class ActiveSessionCard extends StatefulWidget {
  const ActiveSessionCard({
    required this.session,
    required this.showFlavorIcon,
    super.key,
    this.onTap,
    this.avatarStyle,
    this.lastMessageTimestamp,
    this.lastMessagePreview,
    this.lastMessageRole,
    this.unreadCount = 0,
  });

  final Session session;
  final VoidCallback? onTap;
  final bool showFlavorIcon;
  final AvatarStyle? avatarStyle;
  final int? lastMessageTimestamp;
  final String? lastMessagePreview;
  final String? lastMessageRole;
  final int unreadCount;

  @override
  State<ActiveSessionCard> createState() =>
      _ActiveSessionCardState();
}

class _ActiveSessionCardState extends State<ActiveSessionCard> {
  bool _pressed = false;
  late SessionDerived _d;

  @override
  void initState() {
    super.initState();
    _d = SessionDerived.from(widget.session);
  }

  @override
  void didUpdateWidget(ActiveSessionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _d = SessionDerived.from(widget.session);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final session = widget.session;
    final hasPreview = widget.lastMessagePreview != null &&
        widget.lastMessagePreview!.isNotEmpty;
    final statusWidget = buildStatusText(_d.status, theme.textTheme);
    final todoProgress = getTodoProgress(session.todos);
    final sessionFlavor = session.metadata?.flavor;
    final hasDraft =
        session.draft != null && session.draft!.isNotEmpty;

    return AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: AppDuration.fast,
      curve: AppCurve.standard,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          color: cs.primary.withValues(alpha: 0.04),
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.12),
            width: AppBorder.hairline,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          clipBehavior: Clip.hardEdge,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onTap?.call();
            },
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            splashColor: cs.primary.withValues(alpha: 0.08),
            highlightColor: cs.primary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      buildSessionAvatar(
                        sessionId: session.id,
                        avatarId: _d.avatarId,
                        sessionFlavor: sessionFlavor,
                        size: 44,
                        showFlavorIcon: true,
                        hasDraft: hasDraft,
                        avatarStyle: widget.avatarStyle,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            buildNameRow(
                              name: _d.name,
                              sessionStatus: _d.status,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              _d.subtitle,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontFamily: 'monospace',
                                fontSize: AppFontSize.xs,
                                height: 1.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            if (hasPreview) ...[
                              const SizedBox(
                                height: AppSpacing.xxs,
                              ),
                              buildPreviewText(
                                context: context,
                                preview:
                                    widget.lastMessagePreview!,
                                role: widget.lastMessageRole,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(
                                  fontSize: AppFontSize.xs,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                              ),
                            ],
                            if (statusWidget != null) ...[
                              const SizedBox(
                                height: AppSpacing.xxs,
                              ),
                              statusWidget,
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      buildTimestampBadges(
                        timestamp:
                            widget.lastMessageTimestamp ??
                                session.updatedAt,
                        theme: theme,
                        cs: cs,
                        unreadCount: widget.unreadCount,
                        todoProgress: todoProgress,
                        badgeGap: AppSpacing.xxs,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: Color(_d.status.statusDotColor),
                      borderRadius: const BorderRadius.only(
                        topLeft:
                            Radius.circular(AppRadius.md),
                        bottomLeft:
                            Radius.circular(AppRadius.md),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
