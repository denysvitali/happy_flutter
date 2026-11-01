import 'package:flutter/material.dart';
import 'package:happy_flutter/core/components/app_banner.dart';

import '../../../core/theme/app_tokens.dart';
import 'chat_app_bar.dart' show SendIssue;

/// Sticky banner shown above the chat input when the session has a
/// lifecycle error (e.g. the local agent process is gone, or the
/// session is in a recoverable error state).
///
/// Renders through [AppBanner], so it shares geometry and the tone palette
/// with every other alert in the app.
///
/// Renders in two variants based on [SendIssue.blocksSend]:
/// - blocksSend=true: error-colored banner with an explicit recovery action.
/// - blocksSend=false: warning-colored banner explaining next-send recovery.
/// The issue text owns the distinction between restart and fresh session.
///
/// Extracted from chat_screen.dart in batch 17. The widget takes
/// the public [SendIssue] record (defined alongside
/// [buildChatStatusChips] in chat_app_bar.dart) so it can be
/// tested in isolation.
class SessionIssueBanner extends StatelessWidget {
  const SessionIssueBanner({
    required this.issue,
    this.onCopy,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final SendIssue issue;
  final VoidCallback? onCopy;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tone = issue.blocksSend ? AppBadgeTone.danger : AppBadgeTone.warning;
    final foreground = AppToneColors.of(context, tone).foreground;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: AppBanner(
        tone: tone,
        elevated: true,
        icon: issue.blocksSend
            ? Icons.error_outline_rounded
            : Icons.restart_alt_rounded,
        title: issue.title,
        message: issue.message,
        footer: actionLabel != null && onAction != null
            ? TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: foreground,
                  // Align the label with the message text above it.
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, AppTouchTarget.min),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(actionLabel!),
              )
            : null,
        trailing: onCopy == null
            ? null
            : IconButton(
                onPressed: onCopy,
                icon: Icon(Icons.copy_rounded, color: foreground),
                tooltip: MaterialLocalizations.of(context).copyButtonLabel,
                constraints: const BoxConstraints(
                  minWidth: AppTouchTarget.min,
                  minHeight: AppTouchTarget.min,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
      ),
    );
  }
}
