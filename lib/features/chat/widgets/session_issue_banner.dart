import 'package:flutter/material.dart';

import '../../../core/theme/app_color_scheme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import 'chat_app_bar.dart' show SendIssue;

/// Sticky banner shown above the chat input when the session has a
/// lifecycle error (e.g. the local agent process is gone, or the
/// session is in a recoverable error state).
///
/// Renders in two variants based on [SendIssue.blocksSend]:
/// - blocksSend=true: error-colored banner (red theme), suggests
///   the user can retry by sending a message which will restart
///   the local agent.
/// - blocksSend=false: warning-colored banner (amber theme),
///   indicates the session will auto-restart on the next send.
///
/// Extracted from chat_screen.dart in batch 17. The widget takes
/// the public [SendIssue] record (defined alongside
/// [buildChatStatusChips] in chat_app_bar.dart) so it can be
/// tested in isolation.
class SessionIssueBanner extends StatelessWidget {
  const SessionIssueBanner({required this.issue, this.onCopy, super.key});

  final SendIssue issue;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appColors = theme.extension<AppColorScheme>();
    final containerColor = issue.blocksSend
        ? cs.errorContainer
        : appColors?.warningContainer ?? cs.tertiaryContainer;
    final borderColor = issue.blocksSend
        ? cs.error
        : appColors?.warning ?? AppColors.warning;
    final foregroundColor = issue.blocksSend
        ? cs.onErrorContainer
        : appColors?.onWarning ?? cs.onTertiaryContainer;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: containerColor.withValues(alpha: 0.65),
        border: Border(
          top: BorderSide(color: borderColor.withValues(alpha: 0.22)),
          bottom: BorderSide(color: borderColor.withValues(alpha: 0.22)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              issue.blocksSend
                  ? Icons.error_outline_rounded
                  : Icons.restart_alt_rounded,
              size: 18,
              color: foregroundColor,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    issue.title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    issue.message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: foregroundColor,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            if (onCopy != null)
              IconButton(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded),
                tooltip: MaterialLocalizations.of(context).copyButtonLabel,
                constraints: const BoxConstraints(
                  minWidth: AppTouchTarget.min,
                  minHeight: AppTouchTarget.min,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}
