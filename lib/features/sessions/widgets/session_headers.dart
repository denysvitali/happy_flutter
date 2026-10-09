import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_utils.dart';
import 'package:happy_flutter/core/components/app_badge.dart';
import 'package:happy_flutter/core/theme/app_text.dart';

/// How to group archived sessions.
enum ArchivedGrouping { date, folder }

/// Builds the localized active/archived breakdown shown for a session folder.
String folderBreakdownLabel(BuildContext context, SessionFolderHeader header) {
  final l10n = AppLocalizations.of(context);
  final parts = <String>[];
  if (header.activeSessionCount > 0) {
    parts.add(l10n.sessionsFolderActiveCount(header.activeSessionCount));
  }
  if (header.inactiveSessionCount > 0) {
    parts.add(l10n.sessionsFolderArchivedCount(header.inactiveSessionCount));
  }
  return parts.join(' • ');
}

/// Section header for active / archived sessions.
class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppText.label(theme, cs.onSurfaceVariant),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Top-level collapsible project header grouping active sessions
/// by inferred project name (leading path segment).
///
/// Rendered above one or more [PathHeader] rows to give a two-level
/// hierarchy: Project → Path → sessions.
class ProjectHeader extends StatelessWidget {
  const ProjectHeader({
    required this.projectName,
    required this.sessionCount,
    required this.activeCount,
    required this.isCollapsed,
    required this.onToggle,
    super.key,
  });

  final String projectName;
  final int sessionCount;
  final int activeCount;
  final bool isCollapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(
              Icons.workspaces_outlined,
              size: AppIconSize.sm,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                projectName,
                style: AppText.label(theme, cs.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (activeCount > 0) _ActiveBadge(count: activeCount),
            const SizedBox(width: AppSpacing.xs),
            _CollapseChevron(isCollapsed: isCollapsed),
          ],
        ),
      ),
    );
  }
}

/// Small badge showing the active-session count inside a project header.
class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppBadge(
      minWidth: 20,
      label: '$count',
      foregroundColor: cs.primary,
      backgroundColor: cs.primary.withValues(alpha: 0.12),
      borderColor: cs.primary.withValues(alpha: 0.25),
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// Path header for grouping active sessions by working directory.
class PathHeader extends StatelessWidget {
  const PathHeader({
    required this.path,
    required this.sessionCount,
    required this.isCollapsed,
    required this.onToggle,
    super.key,
  });

  final String path;
  final int sessionCount;
  final bool isCollapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                path.split('/').last,
                style: AppText.label(
                  theme,
                  cs.onSurfaceVariant,
                ).copyWith(fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _HeaderCountPill(count: sessionCount),
            const SizedBox(width: AppSpacing.xs),
            _CollapseChevron(isCollapsed: isCollapsed),
          ],
        ),
      ),
    );
  }
}

class _HeaderCountPill extends StatelessWidget {
  const _HeaderCountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return AppBadge(
      minWidth: 24,
      label: '$count',
      foregroundColor: cs.onSurfaceVariant,
      backgroundColor: cs.surfaceContainerHighest,
      borderColor: cs.outlineVariant.withValues(alpha: 0.5),
      labelStyle: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
    );
  }
}

/// Collapsible date section header with session count.
class CollapsibleDateHeader extends StatelessWidget {
  const CollapsibleDateHeader({
    required this.date,
    required this.sessionCount,
    required this.isCollapsed,
    required this.onToggle,
    super.key,
  });

  final String date;
  final int sessionCount;
  final bool isCollapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                date,
                style: AppText.label(theme, cs.onSurfaceVariant),
              ),
            ),
            _HeaderCountPill(count: sessionCount),
            const SizedBox(width: AppSpacing.xs),
            _CollapseChevron(isCollapsed: isCollapsed),
          ],
        ),
      ),
    );
  }
}

/// Collapsible folder header showing the path + machine name.
class CollapsibleFolderHeader extends StatelessWidget {
  const CollapsibleFolderHeader({
    required this.header,
    required this.isCollapsed,
    required this.onToggle,
    super.key,
  });

  final SessionFolderHeader header;
  final bool isCollapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasBreakdown =
        header.activeSessionCount > 0 || header.inactiveSessionCount > 0;
    final unreadLabel = header.unreadCount > 99
        ? '99+'
        : '${header.unreadCount}';
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(
              Icons.folder_outlined,
              size: AppIconSize.md,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    header.displayPath,
                    style: AppText.label(
                      theme,
                      cs.onSurfaceVariant,
                    ).copyWith(fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    header.machineName,
                    style: AppText.secondary(
                      theme,
                      cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  if (hasBreakdown)
                    Text(
                      folderBreakdownLabel(context, header),
                      style: AppText.secondary(
                        theme,
                        cs.onSurfaceVariant.withValues(alpha: 0.72),
                      ),
                    ),
                ],
              ),
            ),
            if (header.hasUpdates) ...[
              AppBadge(
                label: unreadLabel,
                foregroundColor: cs.onPrimary,
                backgroundColor: cs.primary,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Text(
              '${header.sessionCount}',
              style: AppText.secondary(
                theme,
                cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 2),
            _CollapseChevron(isCollapsed: isCollapsed),
          ],
        ),
      ),
    );
  }
}

class FolderSectionHeader extends StatelessWidget {
  const FolderSectionHeader({
    required this.title,
    required this.count,
    super.key,
  });

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxs,
      ),
      child: Row(
        children: [
          Text(title, style: AppText.label(theme, cs.onSurfaceVariant)),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$count',
            style: AppText.secondary(
              theme,
              cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// Archive section header with grouping toggle (date / folder).
///
/// Deliberately carries no count: the group rows immediately below it
/// ("Older", "Yesterday", …) each show their own count pill, so a total
/// here only repeated a number the user is about to read again.
class ArchiveSectionHeader extends StatelessWidget {
  const ArchiveSectionHeader({
    required this.grouping,
    required this.onGroupingChanged,
    super.key,
  });

  final ArchivedGrouping grouping;
  final ValueChanged<ArchivedGrouping> onGroupingChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.sessionHistory,
              style: AppText.label(theme, cs.onSurfaceVariant),
            ),
          ),
          _GroupingToggle(grouping: grouping, onChanged: onGroupingChanged),
        ],
      ),
    );
  }
}

/// Two-icon toggle for switching between date and folder
/// grouping.
class _GroupingToggle extends StatelessWidget {
  const _GroupingToggle({required this.grouping, required this.onChanged});

  final ArchivedGrouping grouping;
  final ValueChanged<ArchivedGrouping> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToggleChip(
          icon: Icons.calendar_today_outlined,
          selected: grouping == ArchivedGrouping.date,
          onTap: () => onChanged(ArchivedGrouping.date),
          tooltip: l10n.sessionsGroupByDate,
        ),
        const SizedBox(width: AppSpacing.xs),
        _ToggleChip(
          icon: Icons.folder_outlined,
          selected: grouping == ArchivedGrouping.folder,
          onTap: () => onChanged(ArchivedGrouping.folder),
          tooltip: l10n.sessionsGroupByFolder,
        ),
      ],
    );
  }
}

/// Single icon chip used by [_GroupingToggle].
class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: AnimatedContainer(
          duration: AppDuration.fast,
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(
            icon,
            size: AppIconSize.md,
            color: selected ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Rotating chevron that marks a collapsible session/project header.
///
/// Four headers in this file drew the same AnimatedRotation + arrow icon.
class _CollapseChevron extends StatelessWidget {
  const _CollapseChevron({required this.isCollapsed});

  final bool isCollapsed;

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: isCollapsed ? -0.25 : 0,
      duration: const Duration(milliseconds: 200),
      child: Icon(
        Icons.keyboard_arrow_down,
        size: AppIconSize.lg,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
