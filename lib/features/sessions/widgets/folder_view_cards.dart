import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/components/app_status_dot.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/session.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_utils.dart';
import '../../../core/utils/utils.dart' show formatRelativeTime;
import '../session_avatar.dart';
import 'mission_control_types.dart';
import 'session_badges.dart';
import 'session_cards.dart';
import 'session_headers.dart';
import 'workspace_identity.dart';

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
    this.displayName,
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
  final String? displayName;
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
    final activity = muted ? null : getSessionActivity(context, session);
    // The activity line already says "<tool> needs approval"; don't
    // repeat it as "Permission required" one row below.
    final statusWidget = activityRestatesStatus(activity)
        ? null
        : buildStatusText(derived.status, theme.textTheme);
    final activityLine = buildActivityLineFor(
      context: context,
      activity: activity,
      preview: lastMessagePreview,
      previewRole: lastMessageRole,
      style: AppText.secondary(theme),
    );
    final hasDraft = session.draft != null && session.draft!.isNotEmpty;
    final todoProgress = getTodoProgress(session.todos);
    final rowColor = isSelected
        ? cs.primary.withValues(alpha: 0.07)
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
            constraints: BoxConstraints(
              minHeight: activityLine != null ? 76 : 64,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stackMetadata =
                      constraints.maxWidth < 320 ||
                      MediaQuery.textScalerOf(context).scale(AppFontSize.base) >
                          AppFontSize.base * 1.3;
                  return Row(
                    children: [
                      if (selectionMode) ...[
                        SelectionCheckbox(
                          isSelected: isSelected,
                          borderRadius: BorderRadius.zero,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      if (!selectionMode) ...[
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
                        size: AppAvatarSize.medium,
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
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    displayName ?? derived.name,
                                    style: AppText.title(theme, titleColor),
                                    maxLines: stackMetadata ? 2 : 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!stackMetadata &&
                                    archiveCountdownLabel != null) ...[
                                  const SizedBox(width: AppSpacing.xs),
                                  ArchiveCountdownBadge(
                                    label: archiveCountdownLabel!,
                                  ),
                                ],
                              ],
                            ),
                            if (statusWidget != null && !muted) ...[
                              const SizedBox(height: AppSpacing.xxs),
                              statusWidget,
                            ] else if (activityLine != null) ...[
                              const SizedBox(height: AppSpacing.xxs),
                              activityLine,
                            ] else ...[
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                derived.subtitle,
                                style: AppText.secondary(
                                  theme,
                                  cs.onSurfaceVariant,
                                ).copyWith(fontFamily: 'monospace'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (stackMetadata) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.xs,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    formatTimestamp(
                                      lastMessageTimestamp ??
                                          session.lastMessageAt ??
                                          session.updatedAt,
                                      relative: true,
                                    ),
                                    style: AppText.secondary(
                                      theme,
                                      cs.onSurfaceVariant,
                                    ),
                                  ),
                                  if (unreadCount > 0)
                                    UnreadBadge(count: unreadCount),
                                  if (todoProgress != null)
                                    TodoProgressBadge(
                                      completed: todoProgress.completed,
                                      total: todoProgress.total,
                                    ),
                                  if (archiveCountdownLabel != null)
                                    ArchiveCountdownBadge(
                                      label: archiveCountdownLabel!,
                                    ),
                                  if (session.pinned)
                                    Icon(
                                      Icons.push_pin,
                                      size: AppIconSize.md,
                                      color: cs.primary,
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!stackMetadata) ...[
                        const SizedBox(width: AppSpacing.sm),
                        buildTimestampBadges(
                          timestamp:
                              lastMessageTimestamp ??
                              session.lastMessageAt ??
                              session.updatedAt,
                          theme: theme,
                          cs: cs,
                          unreadCount: unreadCount,
                          todoProgress: todoProgress,
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
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One workspace in the folder overview: identity-tinted folder tile, name,
/// what its sessions are doing and where they run.
///
/// Renders as a borderless row; place it in an `UnreadFocusListGroup`.
class FolderOverviewCard extends StatelessWidget {
  const FolderOverviewCard({
    required this.header,
    required this.onTap,
    super.key,
    this.laneCounts = const {},
  });

  final SessionFolderHeader header;
  final VoidCallback onTap;

  /// Active sessions in this folder per Mission Control lane.
  final Map<MissionLane, int> laneCounts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final latestActivity = header.latestActivityAt > 0
        ? formatRelativeTime(
            DateTime.fromMillisecondsSinceEpoch(header.latestActivityAt),
            compact: true,
            l10n: context.l10n,
          )
        : null;
    final identity = workspaceIdentityColor(context, header.folderKey);
    final topLane = missionTopLane(laneCounts);
    final laneSummary = missionLaneSummary(context, laneCounts);
    final host = missionShortHost(header.machineName);
    final archivedOnly = header.activeSessionCount == 0;
    final detail = [
      if (host.isNotEmpty) host,
      folderBreakdownLabel(context, header),
    ].join(' · ');

    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppTouchTarget.comfortable,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.smd,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: AppControlSize.sm,
                  height: AppControlSize.sm,
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      identity.withValues(alpha: archivedOnly ? 0.06 : 0.16),
                      cs.surfaceContainerLow,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.smd),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        header.isRepository
                            ? (archivedOnly
                                  ? Icons.source_outlined
                                  : Icons.source_rounded)
                            : archivedOnly
                            ? Icons.folder_outlined
                            : Icons.folder_rounded,
                        size: AppIconSize.md,
                        color: archivedOnly ? cs.onSurfaceVariant : identity,
                      ),
                      if (topLane != MissionLane.quiet)
                        Positioned(
                          right: AppSpacing.xxs,
                          top: AppSpacing.xxs,
                          child: AppStatusDot(
                            color: missionLaneColor(context, topLane),
                            pulse: topLane == MissionLane.live,
                            size: 7,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.smd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _folderName(header.displayPath),
                        style: AppText.title(
                          theme,
                          archivedOnly ? cs.onSurfaceVariant : cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text.rich(
                        TextSpan(
                          children: [
                            if (laneSummary != null)
                              TextSpan(
                                text: '$laneSummary  ·  ',
                                style: AppText.label(
                                  theme,
                                  missionLaneColor(context, topLane),
                                ),
                              ),
                            TextSpan(text: detail),
                          ],
                        ),
                        style: AppText.secondary(theme, cs.onSurfaceVariant),
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
                        style: AppText.secondary(theme, cs.onSurfaceVariant),
                        maxLines: 1,
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
}
