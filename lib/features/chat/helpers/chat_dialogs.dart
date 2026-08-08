import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_sheet.dart';
import '../../../core/dialogs/app_dialog.dart';
import '../../../core/dialogs/confirm_dialog.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/draft_storage.dart';
import '../../../core/services/logger_service.dart' show logger;
import '../../../core/utils/snack.dart';

/// Shows a modal bottom sheet with session actions (settings, stop,
/// delete).
void showSessionMenu(
  BuildContext outerContext, {
  required String sessionId,
  required VoidCallback onAbort,
}) {
  final l10n = outerContext.l10n;
  final cs = Theme.of(outerContext).colorScheme;
  showAppSheet<void>(
    outerContext,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final hideToolCalls = ref.watch(
          settingsNotifierProvider.select((s) => s.hideToolCalls),
        );

        void updateHideToolCalls(bool value) {
          HapticFeedback.selectionClick();
          unawaited(
            ref
                .read(settingsNotifierProvider.notifier)
                .updateSetting('hideToolCalls', value),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.settings_outlined,
                  color: cs.onSurfaceVariant,
                ),
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
                leading: Icon(
                  Icons.visibility_off_outlined,
                  color: cs.onSurfaceVariant,
                ),
                title: Text(l10n.settingsHideToolCalls),
                subtitle: Text(l10n.settingsHideToolCallsSubtitle),
                trailing: Switch.adaptive(
                  value: hideToolCalls,
                  onChanged: updateHideToolCalls,
                ),
                onTap: () => updateHideToolCalls(!hideToolCalls),
              ),
              ListTile(
                leading: Icon(Icons.stop_rounded, color: cs.error),
                title: Text(
                  l10n.chatStopCurrentTask,
                  style: TextStyle(color: cs.error),
                ),
                onTap: () {
                  HapticFeedback.heavyImpact();
                  Navigator.pop(sheetContext);
                  onAbort();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.power_settings_new_rounded,
                  color: cs.error,
                ),
                title: Text(
                  l10n.chatStopAgentProcess,
                  style: TextStyle(color: cs.error),
                ),
                onTap: () {
                  HapticFeedback.heavyImpact();
                  Navigator.pop(sheetContext);
                  unawaited(
                    _confirmStopAgentProcess(outerContext, ref, sessionId),
                  );
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
                  unawaited(
                    showConfirmDeleteDialog(outerContext, sessionId: sessionId),
                  );
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}

Future<void> _confirmStopAgentProcess(
  BuildContext context,
  WidgetRef ref,
  String sessionId,
) async {
  final l10n = context.l10n;
  final confirmed = await showConfirmDialog(
    context,
    title: l10n.chatStopAgentProcessConfirmTitle,
    content: l10n.chatStopAgentProcessConfirmBody,
    confirmLabel: l10n.chatStopAgentProcess,
    isDestructive: true,
  );
  if (!confirmed || !context.mounted) return;
  try {
    await ref
        .read(chatActionNotifierProvider.notifier)
        .stopSessionProcess(sessionId);
    if (context.mounted) {
      context.showSnack(l10n.chatStopAgentProcessSuccess);
    }
  } catch (error, stackTrace) {
    logger.warning(
      '[ChatSessionMenu] stop process failed session=$sessionId',
      error,
      stackTrace,
    );
    if (context.mounted) {
      context.showSnack(l10n.chatStopAgentProcessFailure);
    }
  }
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
  showAppDialog<void>(
    context,
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
Future<void> showConfirmDeleteDialog(
  BuildContext context, {
  required String sessionId,
}) async {
  final l10n = context.l10n;
  final confirmed = await showConfirmDialog(
    context,
    title: l10n.chatDeleteSession,
    content: l10n.chatDeleteSessionConfirm,
    confirmLabel: l10n.commonDelete,
    isDestructive: true,
  );
  if (!confirmed || !context.mounted) return;
  final deleted = await ProviderScope.containerOf(
    context,
  ).read(sessionsNotifierProvider.notifier).optimisticDelete(sessionId);
  if (!context.mounted) return;
  if (deleted) {
    Navigator.of(context).pop();
    return;
  }
  context.showSnack(l10n.chatFailedToDeleteSession);
}
