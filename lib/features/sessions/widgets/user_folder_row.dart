import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/components/app_badge.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import 'mission_control_types.dart';

/// Indent per folder level in the Folders view.
const double userFolderIndent = AppSpacing.lg;

enum UserFolderAction { newSubfolder, rename, move, delete }

/// Collapsible row of a user folder: name, session count, an approval
/// marker when a session inside waits for the user, and a menu.
class UserFolderRow extends StatelessWidget {
  const UserFolderRow({
    required this.name,
    required this.sessionCount,
    required this.needsApproval,
    required this.expanded,
    required this.onToggle,
    required this.onAction,
    this.depth = 0,
    this.canAddSubfolder = true,
    super.key,
  });

  final String name;
  final int sessionCount;
  final bool needsApproval;
  final bool expanded;
  final VoidCallback onToggle;

  /// Null hides the menu (read-only folders).
  final ValueChanged<UserFolderAction>? onAction;
  final int depth;
  final bool canAddSubfolder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final muted = cs.onSurfaceVariant;
    final attention = missionLaneColor(context, MissionLane.blocked);
    final action = onAction;
    return Semantics(
      button: true,
      expanded: expanded,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onToggle();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.xxxl),
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: AppSpacing.smd + depth * userFolderIndent,
              end: AppSpacing.xs,
            ),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: expanded ? 0 : -0.25,
                  duration: AppMotion.duration(context, AppDuration.fast),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: AppIconSize.md,
                    color: muted,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  expanded ? Icons.folder_open_outlined : Icons.folder_outlined,
                  size: AppIconSize.md,
                  color: cs.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    name,
                    style: AppText.title(theme),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (needsApproval)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: AppSpacing.xs,
                    ),
                    child: Tooltip(
                      message: l10n.foldersNeedsApproval,
                      child: Icon(
                        Icons.front_hand_outlined,
                        size: AppIconSize.sm,
                        color: attention,
                        semanticLabel: l10n.foldersNeedsApproval,
                      ),
                    ),
                  ),
                AppBadge(minWidth: 24, label: '$sessionCount', outlined: true),
                if (action != null)
                  PopupMenuButton<UserFolderAction>(
                    tooltip: l10n.foldersMenu,
                    icon: Icon(Icons.more_vert, color: muted),
                    onSelected: action,
                    itemBuilder: (_) => [
                      if (canAddSubfolder)
                        _item(
                          UserFolderAction.newSubfolder,
                          Icons.create_new_folder_outlined,
                          l10n.foldersNewSubfolder,
                        ),
                      _item(
                        UserFolderAction.rename,
                        Icons.edit_outlined,
                        l10n.foldersRename,
                      ),
                      _item(
                        UserFolderAction.move,
                        Icons.drive_file_move_outlined,
                        l10n.foldersMove,
                      ),
                      _item(
                        UserFolderAction.delete,
                        Icons.delete_outline,
                        l10n.foldersDelete,
                      ),
                    ],
                  )
                else
                  const SizedBox(width: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static PopupMenuItem<UserFolderAction> _item(
    UserFolderAction value,
    IconData icon,
    String label,
  ) => PopupMenuItem(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: AppIconSize.md),
        const SizedBox(width: AppSpacing.sm),
        Text(label),
      ],
    ),
  );
}

/// Top of the Folders view: a notice when the tree is read-only or
/// unreadable, and the "New folder" action.
class UserFoldersToolbar extends StatelessWidget {
  const UserFoldersToolbar({
    required this.onNewFolder,
    this.notice,
    this.showEmptyHint = false,
    super.key,
  });

  /// Null when folders cannot be edited.
  final VoidCallback? onNewFolder;
  final String? notice;
  final bool showEmptyHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final notice = this.notice;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (notice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: AppIconSize.sm,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      notice,
                      style: AppText.secondary(theme, cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: showEmptyHint
                    ? Text(
                        l10n.foldersEmpty,
                        style: AppText.secondary(theme, cs.onSurfaceVariant),
                      )
                    : const SizedBox.shrink(),
              ),
              TextButton.icon(
                onPressed: onNewFolder,
                icon: const Icon(Icons.create_new_folder_outlined),
                label: Text(l10n.foldersNew),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
