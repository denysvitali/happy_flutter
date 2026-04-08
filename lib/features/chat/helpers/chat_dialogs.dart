import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/draft_storage.dart';
import '../../../core/theme/app_tokens.dart';

/// Shows a modal bottom sheet with session actions (settings, stop,
/// delete).
void showSessionMenu(
  BuildContext outerContext, {
  required String sessionId,
  required VoidCallback onAbort,
}) {
  final l10n = outerContext.l10n;
  final cs = Theme.of(outerContext).colorScheme;
  showModalBottomSheet(
    context: outerContext,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    backgroundColor: cs.surface,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.settings_outlined, color: cs.onSurfaceVariant),
            title: Text(l10n.chatSessionSettings),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(sheetContext);
              outerContext.pushNamed(
                'session-info',
                pathParameters: {'sessionId': sessionId},
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.stop_rounded, color: cs.error),
            title: Text('Stop', style: TextStyle(color: cs.error)),
            onTap: () {
              HapticFeedback.heavyImpact();
              Navigator.pop(sheetContext);
              onAbort();
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: cs.error),
            title: Text(
              l10n.chatDeleteSession,
              style: TextStyle(color: cs.error),
            ),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(sheetContext);
              showConfirmDeleteDialog(outerContext, sessionId: sessionId);
            },
          ),
        ],
      ),
    ),
  );
}

/// Shows a dialog asking the user to confirm leaving with an unsent
/// message.
void showUnsentMessageDialog(
  BuildContext context, {
  required String sessionId,
  required TextEditingController controller,
}) {
  final cs = Theme.of(context).colorScheme;
  final l10n = context.l10n;
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.chatUnsentMessageTitle),
      content: Text(l10n.chatUnsentMessageContent),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.chatStay),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: cs.error),
          onPressed: () {
            controller.clear();
            unawaited(DraftStorage().removeDraft(sessionId));
            Navigator.pop(dialogContext);
            Navigator.of(context).pop();
          },
          child: Text(l10n.chatLeave),
        ),
      ],
    ),
  );
}

/// Shows a confirmation dialog for deleting a session.
void showConfirmDeleteDialog(
  BuildContext context, {
  required String sessionId,
}) {
  final l10n = context.l10n;
  final cs = Theme.of(context).colorScheme;
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.chatDeleteSession),
      content: Text(l10n.chatDeleteSessionConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: cs.error),
          onPressed: () async {
            Navigator.pop(dialogContext);
            final deleted = await ProviderScope.containerOf(context)
                .read(sessionsNotifierProvider.notifier)
                .optimisticDelete(sessionId);
            if (!context.mounted) return;
            if (deleted) {
              Navigator.of(context).pop();
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.chatFailedToDeleteSession)),
            );
          },
          child: Text(l10n.commonDelete),
        ),
      ],
    ),
  );
}
