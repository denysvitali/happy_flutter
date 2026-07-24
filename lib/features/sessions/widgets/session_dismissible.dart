import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/sessions_api.dart';
import '../../../core/dialogs/confirm_dialog.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/session.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/logger_service.dart' show logger;
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/snack.dart';

enum _SwipeAction { archive, delete }

/// Dismissible wrapper for active sessions (swipe left → shows Archive +
/// Delete side-by-side; tapping either half selects that action).
class DismissibleActiveSession extends ConsumerStatefulWidget {
  const DismissibleActiveSession({
    required this.session,
    required this.child,
    super.key,
  });

  final Session session;
  final Widget child;

  @override
  ConsumerState<DismissibleActiveSession> createState() =>
      _DismissibleActiveSessionState();
}

class _DismissibleActiveSessionState
    extends ConsumerState<DismissibleActiveSession> {
  _SwipeAction _pendingAction = _SwipeAction.archive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('active-${widget.session.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _onConfirmDismiss(context),
      onDismissed: (_) {},
      background: _DualActionBackground(
        colorScheme: cs,
        pendingAction: _pendingAction,
        onSelectAction: (action) {
          if (_pendingAction != action) {
            setState(() => _pendingAction = action);
          }
        },
      ),
      child: widget.child,
    );
  }

  Future<bool> _onConfirmDismiss(BuildContext context) async {
    if (_pendingAction == _SwipeAction.delete) {
      return _confirmDelete(context);
    }
    return _confirmArchive(context);
  }

  Future<bool> _confirmArchive(BuildContext context) async {
    // Capture notifier reference BEFORE any async gap to avoid ref-after-dispose.
    // See GlitchTip HAPPY_FLUTTER-396.
    final sessionsNotifier = ref.read(sessionsNotifierProvider.notifier);
    final failedArchiveMsg = context.l10n.sessionsFailedToArchive;
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.sessionsArchiveSession,
      content: l10n.sessionsArchiveConfirm,
      confirmLabel: l10n.sessionsArchive,
      isDestructive: true,
    );

    if (!confirmed) return false;

    try {
      await SessionsApi().setSessionArchived(widget.session.id, true);
      // Mark optimistically archived to prevent reappear during server lag.
      await sessionsNotifier.markSessionArchived(widget.session.id, true);
      sessionsNotifier.loadFromSync();
      return true;
    } catch (e, st) {
      logger.error(
        'Failed to archive session: sessionId=${widget.session.id}',
        e,
        st,
      );
      if (context.mounted) {
        context.showSnack(failedArchiveMsg);
      }
      return false;
    }
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    // Capture notifier reference BEFORE any async gap to avoid ref-after-dispose.
    // See GlitchTip HAPPY_FLUTTER-396.
    final sessionsNotifier = ref.read(sessionsNotifierProvider.notifier);
    final failedDeleteMsg = context.l10n.sessionsFailedToDelete;
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.chatDeleteSession,
      content: l10n.sessionsDeleteConfirm,
      confirmLabel: l10n.commonDelete,
      isDestructive: true,
    );

    if (!confirmed) return false;

    // Optimistic: remove from UI immediately, roll back on failure.
    final success = await sessionsNotifier.optimisticDelete(widget.session.id);

    if (!success && context.mounted) {
      context.showSnack(failedDeleteMsg);
    }
    return success;
  }
}

/// The two-panel swipe background.  The left half selects Archive; the right
/// half selects Delete.  The active panel is highlighted; the inactive one is
/// shown at reduced opacity so the user knows both are available.
class _DualActionBackground extends StatelessWidget {
  const _DualActionBackground({
    required this.colorScheme,
    required this.pendingAction,
    required this.onSelectAction,
  });

  final ColorScheme colorScheme;
  final _SwipeAction pendingAction;
  final ValueChanged<_SwipeAction> onSelectAction;

  @override
  Widget build(BuildContext context) {
    final archiveActive = pendingAction == _SwipeAction.archive;
    final deleteActive = pendingAction == _SwipeAction.delete;

    return Row(
      children: [
        // Left spacer so the two panels appear on the right side.
        const Spacer(),
        // Archive panel
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelectAction(_SwipeAction.archive),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            color: colorScheme.tertiary.withValues(
              alpha: archiveActive ? 1.0 : 0.55,
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.archive_outlined,
                  color: colorScheme.onTertiary,
                  size: 22,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  context.l10n.sessionsArchive,
                  style: TextStyle(
                    color: colorScheme.onTertiary,
                    fontSize: AppFontSize.sm,
                    fontWeight: archiveActive
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Delete panel
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelectAction(_SwipeAction.delete),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            color: colorScheme.error.withValues(
              alpha: deleteActive ? 1.0 : 0.55,
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.delete_outline,
                  color: colorScheme.onError,
                  size: 22,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  context.l10n.commonDelete,
                  style: TextStyle(
                    color: colorScheme.onError,
                    fontSize: AppFontSize.sm,
                    fontWeight: deleteActive
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.chatDeleteSession,
      content: l10n.sessionsDeleteConfirm,
      confirmLabel: l10n.commonDelete,
      isDestructive: true,
    );

    if (!confirmed) return false;

    // Optimistic: remove from UI immediately, roll back on failure.
    final success = await sessionsNotifier.optimisticDelete(session.id);

    if (!success && context.mounted) {
      context.showSnack(failedDeleteMsg);
    }
    return success;
  }
}
