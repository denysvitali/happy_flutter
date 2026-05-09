import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/components/app_status_dot.dart';
import '../../../core/models/session.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_utils.dart';
import '../session_avatar.dart';
import 'session_badges.dart';
import 'session_cards.dart';

const double _folderStatusDotSlotSize = 17;

class FolderSessionGroup extends StatelessWidget {
  const FolderSessionGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1)
            Divider(
              height: 1,
              thickness: AppBorder.hairline,
              indent: AppSpacing.xxxl + AppSpacing.xl,
              color: cs.outlineVariant.withValues(alpha: 0.45),
            ),
        ],
      ],
    );
  }
}

class FolderSessionRow extends StatelessWidget {
  const FolderSessionRow({
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
    this.archiveCountdownLabel,
    this.muted = false,
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
  final String? archiveCountdownLabel;
  final bool muted;

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
    final rowColor = isSelected
        ? cs.primary.withValues(alpha: 0.10)
        : unreadCount > 0
        ? cs.primary.withValues(alpha: 0.045)
        : Colors.transparent;
    final titleColor = muted ? cs.onSurfaceVariant : cs.onSurface;

    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: rowColor,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          onLongPress: onLongPress,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: hasPreview ? 76 : 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  if (selectionMode) ...[
                    SelectionCheckbox(
                      isSelected: isSelected,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ] else ...[
                    SizedBox.square(
                      dimension: _folderStatusDotSlotSize,
                      child: Center(
                        child: AppStatusDot(
                          color: muted
                              ? cs.outlineVariant
                              : Color(derived.status.statusDotColor),
                          pulse: derived.status.isPulsing && !muted,
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
                    size: 40,
                    showFlavorIcon: showFlavorIcon,
                    hasDraft: hasDraft,
                    avatarStyle: avatarStyle,
                    monochrome: muted,
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
                            fontWeight: FontWeight.w600,
                            color: titleColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (statusWidget != null && !muted) ...[
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
                              height: 1.25,
                            ),
                            maxLines: 1,
                          ),
                        ] else ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            derived.subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontFamily: 'monospace',
                              fontSize: AppFontSize.xs,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                    unreadCount: unreadCount,
                    todoProgress: todoProgress,
                    archiveCountdownLabel: archiveCountdownLabel,
                  ),
                  if (session.pinned) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      Icons.push_pin,
                      size: AppSpacing.lg,
                      color: cs.primary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FolderOverviewCard extends StatelessWidget {
  const FolderOverviewCard({
    required this.header,
    required this.onTap,
    super.key,
  });

  final SessionFolderHeader header;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final latestActivity = header.latestActivityAt > 0
        ? formatTimestamp(header.latestActivityAt, relative: true)
        : null;

    return Container(
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.folder_outlined,
                    color: cs.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _folderName(header.displayPath),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        _sessionCountLabel(header.sessionCount),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (latestActivity != null)
                      Text(
                        latestActivity,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (header.unreadCount > 0)
                      Padding(
                        padding: EdgeInsets.only(
                          top: latestActivity != null ? AppSpacing.xxs : 0,
                        ),
                        child: UnreadBadge(count: header.unreadCount),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _folderName(String displayPath) {
    if (displayPath.isEmpty || displayPath == 'Unknown') {
      return displayPath;
    }
    final parts = displayPath.split('/');
    final last = parts.isNotEmpty ? parts.last : displayPath;
    return last.isEmpty ? displayPath : last;
  }

  String _sessionCountLabel(int count) {
    return count == 1 ? '1 session' : '$count sessions';
  }
}
