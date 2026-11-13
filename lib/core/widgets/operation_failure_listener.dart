import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/app_localizations.dart';
import '../providers/session_operations_notifier.dart';
import '../utils/snack.dart';

/// Reports background session operations that failed, app-wide.
///
/// Archive and delete close the screen that started them, so their outcome
/// cannot be shown there. A failure restores the session (the store reverts
/// its optimistic hide) and shows an error snack with Retry; closing the
/// snack any other way dismisses the record.
class OperationFailureListener extends ConsumerWidget {
  const OperationFailureListener({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(sessionOperationsNotifierProvider, (previous, next) {
      for (final MapEntry(:key, value: operation) in next.entries) {
        final before = previous?[key];
        if (!operation.isFailed ||
            before == null ||
            before.id != operation.id ||
            !before.isPending) {
          continue;
        }
        _report(context, ref, operation);
      }
    });
    return child;
  }

  void _report(BuildContext context, WidgetRef ref, SessionOperation failed) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final operations = ref.read(sessionOperationsNotifierProvider.notifier);
    if (messenger == null) {
      operations.dismiss(failed.key);
      return;
    }
    final l10n = context.l10n;
    final message = switch (failed.request.action) {
      SessionOperationAction.archive => l10n.sessionsFailedToArchive,
      SessionOperationAction.delete => l10n.sessionsFailedToDelete,
    };
    var retried = false;
    final controller = messenger.showSnack(
      message,
      tone: SnackTone.error,
      action: SnackBarAction(
        label: l10n.commonRetry,
        onPressed: () {
          retried = true;
          operations.retry(failed.key);
        },
      ),
    );
    controller.closed.then((_) {
      if (!retried) operations.dismiss(failed.key);
    }, onError: (Object _) => operations.dismiss(failed.key));
  }
}
