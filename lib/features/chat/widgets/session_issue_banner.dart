import 'package:flutter/material.dart';

import '../../../core/theme/app_color_scheme.dart';
import '../../../core/theme/app_tokens.dart';
import 'chat_app_bar.dart' show SendIssue;

/// Sticky banner shown above the chat input when the session has a
/// lifecycle error (e.g. the local agent process is gone, or the
/// session is in a recoverable error state).
///
/// Aurora glass family: the same rounded panel geometry and hairline
/// border rhythm as [SessionGoalBanner], but the status material stays
/// danger/warning — semantics live in colour, not in silhouette.
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
    final appCs = theme.extension<AppColorScheme>() ?? AppColorScheme.dark();
    final containerColor = issue.blocksSend
        ? cs.errorContainer
        : appCs.warningContainer;
    final borderColor = issue.blocksSend ? cs.error : appCs.warning;
    final foregroundColor = issue.blocksSend
        ? cs.onErrorContainer
        : appCs.onWarning;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Material(
        color: containerColor.withValues(alpha: 0.72),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: borderColor.withValues(alpha: 0.35),
            width: AppBorder.hairline,
          ),
        ),
        elevation: AppElevation.low,
        shadowColor: Colors.black.withValues(alpha: 0.24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.smd,
            AppSpacing.sm,
            AppSpacing.xxs,
            AppSpacing.sm,
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
              const SizedBox(width: AppSpacing.smd),
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
                  icon: Icon(Icons.copy_rounded, color: foregroundColor),
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
      ),
    );
  }
}
