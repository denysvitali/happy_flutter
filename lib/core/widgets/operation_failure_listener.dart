import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/app_localizations.dart';
import '../i18n/remote_feature_failure_localization.dart';
import '../operations/operation_store.dart';
import '../providers/machine_operations_notifier.dart';
import '../providers/mcp_operations_notifier.dart';
import '../providers/permission_operations_notifier.dart';
import '../providers/session_operations_notifier.dart';
import '../utils/permission_failure.dart';
import '../utils/snack.dart';

/// Reports background operations that failed, app-wide.
///
/// Archive, delete and permission decisions close or replace the surface
/// that started them, so their outcome cannot be shown there. A failure
/// restores the item (the store drops its optimistic overlay) and shows an
/// error snack with Retry; closing the snack any other way dismisses the
/// record.
class OperationFailureListener extends ConsumerWidget {
  const OperationFailureListener({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _listen(
      context,
      ref,
      sessionOperationsNotifierProvider,
      (l10n, failed) => switch (failed.request.action) {
        SessionOperationAction.archive => l10n.sessionsFailedToArchive,
        SessionOperationAction.delete => l10n.sessionsFailedToDelete,
        SessionOperationAction.abort => l10n.missionControlPeekStopFailed,
      },
    );
    _listen(
      context,
      ref,
      machineOperationsNotifierProvider,
      (l10n, failed) =>
          l10n.machineDeleteFailed(int.tryParse(failed.error ?? '') ?? 0),
    );
    _listen(
      context,
      ref,
      permissionOperationsNotifierProvider,
      (l10n, failed) => permissionFailureLabel(l10n, failed.error ?? ''),
      // A permission the session dropped meanwhile cannot be retried.
      retryable: false,
    );
    _listen(
      context,
      ref,
      mcpOperationsNotifierProvider,
      (l10n, failed) => switch (failed.cause) {
        McpOperationFailed(:final response) when response.failureKind != null =>
          response.failureKind.localizedRemoteFeatureFailure(l10n),
        _ =>
          failed.request.action == McpOperationAction.remove
              ? l10n.mcpDeleteFailed(failed.request.server.name)
              : l10n.mcpToggleFailed(failed.request.server.name),
      },
    );
    return child;
  }

  static void _listen<R>(
    BuildContext context,
    WidgetRef ref,
    NotifierProvider<OperationStore<R>, Map<String, Operation<R>>> provider,
    String Function(AppLocalizations l10n, Operation<R> failed) message, {
    bool retryable = true,
  }) {
    ref.listen(provider, (previous, next) {
      for (final MapEntry(:key, value: operation) in next.entries) {
        final before = previous?[key];
        if (!operation.isFailed ||
            before == null ||
            before.id != operation.id ||
            !before.isPending) {
          continue;
        }
        _report(
          context,
          ref.read(provider.notifier),
          operation,
          message(context.l10n, operation),
          retryable: retryable,
        );
      }
    });
  }

  static void _report<R>(
    BuildContext context,
    OperationStore<R> operations,
    Operation<R> failed,
    String message, {
    required bool retryable,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      operations.dismiss(failed.key);
      return;
    }
    var retried = false;
    final controller = messenger.showSnack(
      message,
      tone: SnackTone.error,
      action: retryable
          ? SnackBarAction(
              label: context.l10n.commonRetry,
              onPressed: () {
                retried = true;
                operations.retry(failed.key);
              },
            )
          : null,
    );
    controller.closed.then((_) {
      if (!retried) operations.dismiss(failed.key);
    }, onError: (Object _) => operations.dismiss(failed.key));
  }
}
