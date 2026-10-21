import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';

/// Glyph size of the overflow menu; big enough that its dots read next to the
/// row title.
const double missionMenuIconSize = AppIconSize.xl;

/// Overflow triage menu for one action row: quick look, mark read, pin,
/// snooze.
class MissionTriageMenu extends StatelessWidget {
  const MissionTriageMenu({
    required this.isPinned,
    required this.isSnoozed,
    required this.canMarkRead,
    super.key,
    this.onMarkRead,
    this.onTogglePin,
    this.onToggleSnooze,
    this.onPeek,
    this.onArchive,
    this.onSelect,
  });

  final bool isPinned;
  final bool isSnoozed;
  final bool canMarkRead;
  final VoidCallback? onMarkRead;
  final VoidCallback? onTogglePin;
  final ValueChanged<bool>? onToggleSnooze;
  final VoidCallback? onPeek;
  final VoidCallback? onArchive;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        size: missionMenuIconSize,
        color: cs.onSurfaceVariant,
      ),
      padding: EdgeInsets.zero,
      // The glyph sits on the row's right padding edge, mirroring the tile's
      // left inset; the 44dp target extends inward.
      style: const ButtonStyle(alignment: Alignment.centerRight),
      constraints: const BoxConstraints(minWidth: AppTouchTarget.min),
      tooltip: l10n.missionControlTriage,
      onSelected: (action) {
        switch (action) {
          case 'select':
            onSelect?.call();
          case 'archive':
            onArchive?.call();
          case 'peek':
            onPeek?.call();
          case 'read':
            onMarkRead?.call();
          case 'pin':
            onTogglePin?.call();
          case 'snooze':
            onToggleSnooze?.call(true);
          case 'unsnooze':
            onToggleSnooze?.call(false);
        }
      },
      itemBuilder: (context) => [
        if (onSelect != null)
          PopupMenuItem(
            value: 'select',
            child: Text(l10n.sessionsSelectSession),
          ),
        if (onArchive != null)
          PopupMenuItem(value: 'archive', child: Text(l10n.sessionsArchive)),
        if (onPeek != null)
          PopupMenuItem(
            value: 'peek',
            child: Row(
              children: [
                Icon(
                  Icons.visibility_outlined,
                  size: AppIconSize.sm,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(child: Text(l10n.missionControlPeekQuickLook)),
              ],
            ),
          ),
        if (canMarkRead && onMarkRead != null)
          PopupMenuItem(
            value: 'read',
            child: Text(l10n.missionControlMarkRead),
          ),
        if (onTogglePin != null)
          PopupMenuItem(
            value: 'pin',
            child: Text(
              isPinned ? l10n.missionControlUnpin : l10n.missionControlPinToTop,
            ),
          ),
        if (onToggleSnooze != null)
          PopupMenuItem(
            value: isSnoozed ? 'unsnooze' : 'snooze',
            child: Text(
              isSnoozed
                  ? l10n.missionControlUnsnooze
                  : l10n.missionControlSnooze,
            ),
          ),
      ],
    );
  }
}
