part of 'sessions_screen.dart';

/// Keeps each confirmed operation attached to its captured selection.
extension _SessionBatchActions on _SessionsScreenState {
  Future<void> _pinOrUnpinSelected(SelectionState selection) async {
    if (_selectionNotifier.value.isBatchDeleting) return;
    final sessions = ref.read(sessionsNotifierProvider);
    final notifier = ref.read(sessionsNotifierProvider.notifier);
    final hasPinned = _hasPinnedInSelection(selection);
    for (final id in selection.selectedIds) {
      final session = sessions[id];
      if (session == null) continue;
      if (hasPinned) {
        if (session.pinned) await notifier.unpinSession(id);
      } else {
        if (!session.pinned) await notifier.pinSession(id);
      }
    }
  }

  Future<void> _confirmBatchArchive(
    BuildContext context,
    SelectionState selection,
  ) async {
    if (_selectionNotifier.value.isBatchDeleting) return;
    final l10n = context.l10n;
    final api = widget.sessionsApi ?? SessionsApi();
    final sessions = ref.read(sessionsNotifierProvider);
    final notifier = ref.read(sessionsNotifierProvider.notifier);
    final ids = selection.selectedIds.where((id) {
      final session = sessions[id];
      return session != null && isSessionActive(session);
    }).toList();
    if (ids.isEmpty) return;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.sessionsArchiveSession,
      content: l10n.sessionsArchiveNConfirm(ids.length),
      confirmLabel: l10n.sessionsArchive,
    );
    if (!confirmed || !mounted) return;
    await _runSelectionBatch(
      selection: selection,
      count: ids.length,
      failureMessage: l10n.sessionsArchivePartialFail,
      operation: () async {
        var failures = 0;
        for (final id in ids) {
          try {
            await api.setSessionArchived(id, true);
            await notifier.markSessionArchived(id, true);
          } catch (error, stack) {
            logger.error('Failed to archive session $id', error, stack);
            failures++;
          }
        }
        if (mounted) notifier.loadFromSync();
        return failures;
      },
    );
  }

  Future<void> _confirmBatchDelete(
    BuildContext context,
    SelectionState selection,
  ) async {
    if (_selectionNotifier.value.isBatchDeleting) return;
    final l10n = context.l10n;
    final notifier = ref.read(sessionsNotifierProvider.notifier);
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
    await _runSelectionBatch(
      selection: selection,
      count: ids.length,
      failureMessage: l10n.sessionsDeletePartialFail,
      operation: () => notifier.optimisticBatchDelete(ids),
    );
  }

  Future<void> _runSelectionBatch({
    required SelectionState selection,
    required int count,
    required String Function(int) failureMessage,
    required Future<int> Function() operation,
  }) async {
    if (!mounted || _selectionNotifier.value.isBatchDeleting) return;
    final messenger = ScaffoldMessenger.of(context);
    _selectionNotifier.value = selection.copyWith(isBatchDeleting: true);
    var failures = count;
    try {
      failures = await operation();
    } catch (error, stack) {
      logger.error('Batch session operation failed', error, stack);
    } finally {
      if (mounted) {
        _exitSelectionMode(completed: true);
        if (failures > 0) {
          messenger.showSnackBar(
            SnackBar(content: Text(failureMessage(failures))),
          );
        }
      }
    }
  }
}
