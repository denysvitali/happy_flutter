import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/sessions_api.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/session.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/logger_service.dart' show logger;
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_tokens.dart';

/// Dismissible wrapper for active sessions (swipe left → archive).
class DismissibleActiveSession extends ConsumerWidget {
  const DismissibleActiveSession({
    required this.session,
    required this.child,
    super.key,
  });

  final Session session;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('active-${session.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmArchive(context, ref),
      onDismissed: (_) {},
      background: Container(
        alignment: Alignment.centerRight,
        color: cs.tertiary,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.archive_outlined, color: cs.onTertiary, size: 22),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.l10n.sessionsArchive,
              style: TextStyle(
                color: cs.onTertiary,
                fontSize: AppFontSize.sm,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      child: child,
    );
  }

  Future<bool> _confirmArchive(BuildContext context, WidgetRef ref) async {
    // Capture the notifier reference BEFORE any async gap so that we never
    // touch `ref` after the surrounding widget may have been unmounted
    // (e.g. swiped-away `Dismissible` removed from the tree during the
    // archive request). See GlitchTip HAPPY_FLUTTER-396.
    final sessionsNotifier = ref.read(sessionsNotifierProvider.notifier);
    final failedArchiveMsg = context.l10n.sessionsFailedToArchive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l10n.sessionsArchiveSession),
          content: Text(l10n.sessionsArchiveConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error,
              ),
              child: Text(l10n.sessionsArchive),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return false;

    try {
      await SessionsApi().setSessionArchived(session.id, true);
      // Mark optimistically archived to prevent reappear during server lag.
      sync.markSessionArchived(session.id);
      sessionsNotifier.loadFromSync();
      return true;
    } catch (e, st) {
      logger.error('Failed to archive session: sessionId=${session.id}', e, st);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failedArchiveMsg)),
        );
      }
      return false;
    }
  }
}

/// Dismissible wrapper for inactive sessions
/// (swipe left → delete).
class DismissibleInactiveSession extends ConsumerWidget {
  const DismissibleInactiveSession({
    required this.session,
    required this.child,
    super.key,
  });

  final Session session;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('inactive-${session.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context, ref),
      onDismissed: (_) {},
      background: Container(
        alignment: Alignment.centerRight,
        color: cs.error,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: cs.onError, size: 22),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.l10n.commonDelete,
              style: TextStyle(
                color: cs.onError,
                fontSize: AppFontSize.sm,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      child: child,
    );
  }

  Future<bool> _confirmDelete(BuildContext context, WidgetRef ref) async {
    // Capture the notifier reference BEFORE any async gap so that we never
    // touch `ref` after the surrounding widget may have been unmounted.
    // See GlitchTip HAPPY_FLUTTER-396.
    final sessionsNotifier = ref.read(sessionsNotifierProvider.notifier);
    final failedDeleteMsg = context.l10n.sessionsFailedToDelete;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l10n.chatDeleteSession),
          content: Text(l10n.sessionsDeleteConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error,
              ),
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return false;

    // Optimistic: remove from UI immediately, roll back on failure.
    final success = await sessionsNotifier.optimisticDelete(session.id);

    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failedDeleteMsg)),
      );
    }
    return success;
  }
}
