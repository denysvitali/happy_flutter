import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/components/app_status_dot.dart';
import '../../../core/components/pressable_card.dart';
import '../../../core/models/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../session_avatar.dart';
import 'session_badges.dart';
import 'session_cards.dart';

/// Prominent card used in the "Needs Attention" section of the
/// Unread Focus view. Filled with a primary tint and a thick left
/// accent bar, no border — designed to draw the eye.
class NeedsAttentionCard extends StatefulWidget {
  const NeedsAttentionCard({
    required this.session,
    required this.showFlavorIcon,
    required this.onTap,
    required this.onLongPress,
    super.key,
    this.avatarStyle,
    this.lastMessageTimestamp,
    this.lastMessagePreview,
    this.lastMessageRole,
    this.selectionMode = false,
    this.isSelected = false,
    this.unreadCount = 0,
  });

  final Session session;
  final bool showFlavorIcon;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final AvatarStyle? avatarStyle;
  final int? lastMessageTimestamp;
  final String? lastMessagePreview;
  final String? lastMessageRole;
  final bool selectionMode;
  final bool isSelected;
  final int unreadCount;

  @override
  State<NeedsAttentionCard> createState() => _NeedsAttentionCardState();
}

class _NeedsAttentionCardState extends State<NeedsAttentionCard> {
  late SessionDerived _d;

  @override
  void initState() {
    super.initState();
    _d = SessionDerived.from(widget.session);
  }

  @override
  void didUpdateWidget(NeedsAttentionCard oldWidget) {
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
    final hasDraft = session.draft != null && session.draft!.isNotEmpty;
    final todoProgress = getTodoProgress(session.todos);
    final statusWidget = buildStatusText(_d.status, theme.textTheme);
    final hasPreview =
        widget.lastMessagePreview != null &&
        widget.lastMessagePreview!.isNotEmpty;

    final bgColor = widget.isSelected
        ? Color.alphaBlend(
            cs.primary.withValues(alpha: 0.18),
            cs.surfaceContainerHigh,
          )
        : Color.alphaBlend(
            cs.primary.withValues(alpha: 0.08),
            cs.surfaceContainerHigh,
          );

    return PressableCard(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      pressedScale: 0.985,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          color: bgColor,
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          clipBehavior: Clip.hardEdge,
          child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.selectionMode)
                    SelectionCheckbox(
                      isSelected: widget.isSelected,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    )
                  else
                    Container(width: 4, color: cs.primary),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          buildSessionAvatar(
                            sessionId: session.id,
                            avatarId: _d.avatarId,
                            sessionFlavor: session.metadata?.flavor,
                            size: AppAvatarSize.medium,
                            showFlavorIcon: widget.showFlavorIcon,
                            hasDraft: hasDraft,
                            avatarStyle: widget.avatarStyle,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _d.name,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (statusWidget != null) ...[
                                  const SizedBox(height: AppSpacing.xxs),
                                  statusWidget,
                                ],
                                if (hasPreview) ...[
                                  const SizedBox(height: AppSpacing.xxs),
                                  buildPreviewText(
                                    context: context,
                                    preview: widget.lastMessagePreview!,
                                    role: widget.lastMessageRole,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: AppFontSize.xs,
                                      height: 1.25,
                                      color: cs.onSurface.withValues(
                                        alpha: AppOpacity.high,
                                      ),
                                    ),
                                    maxLines: 2,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          buildTimestampBadges(
                            timestamp: widget.lastMessageTimestamp ??
                                session.lastMessageAt ??
                                session.updatedAt,
                            theme: theme,
                            cs: cs,
                            unreadCount: widget.unreadCount,
                            todoProgress: todoProgress,
                          ),
                          if (session.pinned) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Icon(
                              Icons.push_pin,
                              size: AppIconSize.md,
                              color: cs.primary,
                            ),
                          ],
                        ],
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

/// Quiet borderless row used in the "All Sessions" section of the
/// Unread Focus view. Rendered inside [UnreadFocusListGroup] to get
/// hairline dividers between rows and a single rounded surface.
class UnreadFocusListRow extends StatelessWidget {
  const UnreadFocusListRow({
    required this.session,
    required this.showFlavorIcon,
    required this.onTap,
    required this.onLongPress,
    super.key,
    this.avatarStyle,
    this.lastMessageTimestamp,
    this.lastMessagePreview,
    this.lastMessageRole,
    this.selectionMode = false,
    this.isSelected = false,
    this.archiveCountdownLabel,
  });

  final Session session;
  final bool showFlavorIcon;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final AvatarStyle? avatarStyle;
  final int? lastMessageTimestamp;
  final String? lastMessagePreview;
  final String? lastMessageRole;
  final bool selectionMode;
  final bool isSelected;
  final String? archiveCountdownLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final derived = SessionDerived.from(session);
    final statusWidget = buildStatusText(derived.status, theme.textTheme);
    final hasPreview =
        lastMessagePreview != null && lastMessagePreview!.isNotEmpty;
    final hasDraft = session.draft != null && session.draft!.isNotEmpty;
    final todoProgress = getTodoProgress(session.todos);

    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: isSelected
            ? cs.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.smd,
            ),
            child: Row(
              children: [
                if (selectionMode) ...[
                  SelectionCheckbox(
                    isSelected: isSelected,
                    borderRadius: BorderRadius.zero,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ] else ...[
                  SizedBox(
                    width: 12,
                    child: Center(
                      child: AppStatusDot(
                        color: Color(derived.status.statusDotColor),
                        pulse: derived.status.isPulsing,
                        size: 7,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                buildSessionAvatar(
                  sessionId: session.id,
                  avatarId: derived.avatarId,
                  sessionFlavor: session.metadata?.flavor,
                  size: AppAvatarSize.small,
                  showFlavorIcon: showFlavorIcon,
                  hasDraft: hasDraft,
                  avatarStyle: avatarStyle,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        derived.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface.withValues(
                            alpha: AppOpacity.high,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (statusWidget != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        statusWidget,
                      ] else if (hasPreview) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        buildPreviewText(
                          context: context,
                          preview: lastMessagePreview!,
                          role: lastMessageRole,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: AppFontSize.xs,
                            height: 1.2,
                            color: cs.onSurfaceVariant.withValues(
                              alpha: AppOpacity.medium,
                            ),
                          ),
                          maxLines: 1,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                buildTimestampBadges(
                  timestamp: lastMessageTimestamp ??
                      session.lastMessageAt ??
                      session.updatedAt,
                  theme: theme,
                  cs: cs,
                  todoProgress: todoProgress,
                  archiveCountdownLabel: archiveCountdownLabel,
                ),
                if (session.pinned) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    Icons.push_pin,
                    size: AppIconSize.xs,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a list of [UnreadFocusListRow] children in a single
/// rounded surface with hairline dividers between rows.
class UnreadFocusListGroup extends StatelessWidget {
  const UnreadFocusListGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 1,
                thickness: AppBorder.hairline,
                indent: AppSpacing.xl + AppSpacing.xl + AppSpacing.md,
                color: cs.outlineVariant.withValues(alpha: 0.35),
              ),
          ],
        ],
      ),
    );
  }
}
