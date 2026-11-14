part of 'sessions_screen.dart';

/// Dispatches each confirmed batch action to its per-session background
/// operation.
///
/// Nothing here awaits the network: the rows leave at once, selection mode
/// closes immediately, and the list stays interactive while the operations
/// sync. A failure restores its row and is reported app-wide with Retry by
/// [OperationFailureListener] — the same contract as a single-row archive or
/// delete.
extension _SessionBatchActions on _SessionsScreenState {
  /// Pins or unpins the whole selection. Pin state is device-local, so the
  /// rows update in the same frame.
  void _pinOrUnpinSelected(SelectionState selection) {
    final sessions = ref.read(sessionsNotifierProvider);
    final notifier = ref.read(sessionsNotifierProvider.notifier);
    final hasPinned = _hasPinnedInSelection(selection);
    for (final id in selection.selectedIds) {
      final session = sessions[id];
      if (session == null) continue;
      if (hasPinned) {
        if (session.pinned) unawaited(notifier.unpinSession(id));
      } else if (!session.pinned) {
        unawaited(notifier.pinSession(id));
      }
    }
  }

  Future<void> _confirmBatchArchive(
    BuildContext context,
    SelectionState selection,
  ) async {
    final l10n = context.l10n;
    final sessions = ref.read(sessionsNotifierProvider);
    // Only rows the server treats as open can be archived; a running
    // lifecycle keeps an flagged row out of this filter's way.
    final targets = [
      for (final id in selection.selectedIds) ?sessions[id],
    ].where(isSessionOpen).toList();
    if (targets.isEmpty) return;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.sessionsArchiveSession,
      content: l10n.sessionsArchiveNConfirm(targets.length),
      confirmLabel: l10n.sessionsArchive,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    final operations = ref.read(sessionOperationsNotifierProvider.notifier);
    _exitSelectionMode();
    // Each row archives independently: one stuck stop or Pod pause never
    // holds up the rest, and the screen is free the moment this returns.
    for (final session in targets) {
      operations.archive(session);
    }
  }

  Future<void> _confirmBatchDelete(
    BuildContext context,
    SelectionState selection,
  ) async {
    final l10n = context.l10n;
    final ids = selection.selectedIds.toList();
    if (ids.isEmpty) return;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.chatDeleteSession,
      content: l10n.sessionsDeleteNConfirm(ids.length),
      confirmLabel: l10n.commonDelete,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    final operations = ref.read(sessionOperationsNotifierProvider.notifier);
    _exitSelectionMode();
    // Rows leave synchronously (optimistic delete) and each delete syncs on
    // its own; a refusal restores that row and reports it app-wide.
    for (final id in ids) {
      operations.delete(id);
    }
  }
}
