import 'dart:async';

import 'package:riverpod/riverpod.dart';

import '../services/sync_service.dart';

/// Whether any sync operation is currently running.
class SyncState {
  const SyncState({
    this.isSyncing = false,
    this.progress,
    this.catalogProgress,
    this.isVisibleChatSyncing = false,
    this.hasCriticalFailure = false,
  });
  final bool isSyncing;
  final SyncProgress? progress;

  /// Conversation work the sessions list waits on; see
  /// [Sync.catalogSyncProgress].
  final SyncProgress? catalogProgress;

  /// Whether the open chat is catching up on messages.
  final bool isVisibleChatSyncing;
  final bool hasCriticalFailure;

  static SyncState read() => SyncState(
    isSyncing: sync.isSyncing,
    progress: sync.syncProgress,
    catalogProgress: sync.catalogSyncProgress,
    isVisibleChatSyncing: sync.isVisibleChatSyncing,
    hasCriticalFailure: sync.hasUnrecoveredCriticalSyncFailure,
  );

  bool sameAs(SyncState other) =>
      isSyncing == other.isSyncing &&
      isVisibleChatSyncing == other.isVisibleChatSyncing &&
      hasCriticalFailure == other.hasCriticalFailure &&
      _sameProgress(progress, other.progress) &&
      _sameProgress(catalogProgress, other.catalogProgress);

  static bool _sameProgress(SyncProgress? a, SyncProgress? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return a.label == b.label &&
        a.completed == b.completed &&
        a.total == b.total;
  }
}

class SyncStateNotifier extends Notifier<SyncState> {
  StreamSubscription<void>? _subscription;

  @override
  SyncState build() {
    _subscription?.cancel();
    _subscription = sync.onSyncStateChanged.listen((_) {
      final next = SyncState.read();
      if (state.sameAs(next)) return;
      state = next;
    });
    ref.onDispose(() => _subscription?.cancel());
    return SyncState.read();
  }
}

final syncStateNotifierProvider =
    NotifierProvider<SyncStateNotifier, SyncState>(() {
      return SyncStateNotifier();
    });
