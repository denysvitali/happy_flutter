import 'package:flutter/material.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_status.dart';
import '../../../core/utils/session_utils.dart';
import 'session_badges.dart';
import 'session_cards.dart' show ArchiveCountdownBadge;

/// Full-width session content with metadata below the title and preview.
///
/// Metadata wraps independently so long timestamps, counts and larger text
/// never reserve a trailing column or squeeze the session's name.
class SessionListDetails extends StatelessWidget {
  const SessionListDetails({
    required this.name,
    required this.timestamp,
    required this.sessionStatus,
    super.key,
    this.detail,
    this.status,
    this.titleMaxLines = 1,
    this.unreadCount = 0,
    this.todoProgress,
    this.archiveCountdownLabel,
    this.isPinned = false,
  });

  final String name;
  final int timestamp;
  final SessionStatus sessionStatus;
  final Widget? detail;
  final Widget? status;
  final int titleMaxLines;
  final int unreadCount;
  final ({int completed, int total})? todoProgress;
  final String? archiveCountdownLabel;
  final bool isPinned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          style: AppText.title(theme),
          maxLines: titleMaxLines,
          overflow: TextOverflow.ellipsis,
        ),
        if (detail != null) ...[const SizedBox(height: AppSpacing.xs), detail!],
        const SizedBox(height: AppSpacing.xsm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SessionStatusIndicator(status: sessionStatus),
                const SizedBox(width: AppSpacing.xsm),
                Text(
                  formatTimestamp(timestamp, relative: true),
                  style: AppText.secondary(theme),
                ),
              ],
            ),
            ?status,
            if (unreadCount > 0) UnreadBadge(count: unreadCount),
            if (todoProgress case final progress?)
              TodoProgressBadge(
                completed: progress.completed,
                total: progress.total,
              ),
            if (archiveCountdownLabel case final label?)
              ArchiveCountdownBadge(label: label),
            if (isPinned)
              Icon(
                Icons.push_pin_outlined,
                size: AppIconSize.sm,
                color: cs.onSurfaceVariant,
              ),
          ],
        ),
      ],
    );
  }
}
