import 'dart:async';

import 'package:riverpod/riverpod.dart';

import '../services/sync_service.dart';

/// Whether any sync operation is currently running.
class SyncState {
  const SyncState({
    this.isSyncing = false,
    this.progress,
    this.hasCriticalFailure = false,
  });
  final bool isSyncing;
  final SyncProgress? progress;
  final bool hasCriticalFailure;
}

class SyncStateNotifier extends Notifier<SyncState> {
  StreamSubscription<void>? _subscription;

  @override
  SyncState build() {
    _subscription?.cancel();
    _subscription = sync.onSyncStateChanged.listen((_) {
      final next = SyncState(
        isSyncing: sync.isSyncing,
        progress: sync.syncProgress,
        hasCriticalFailure: sync.hasUnrecoveredCriticalSyncFailure,
      );
      final cur = state;
      final curP = cur.progress;
      final nextP = next.progress;
      final progressSame =
          identical(curP, nextP) ||
          (curP != null &&
              nextP != null &&
              curP.label == nextP.label &&
              curP.completed == nextP.completed &&
              curP.total == nextP.total) ||
          (curP == null && nextP == null);
      if (cur.isSyncing == next.isSyncing &&
          cur.hasCriticalFailure == next.hasCriticalFailure &&
          progressSame) {
        return;
      }
      state = next;
    });
    ref.onDispose(() => _subscription?.cancel());
    return SyncState(
      isSyncing: sync.isSyncing,
      progress: sync.syncProgress,
      hasCriticalFailure: sync.hasUnrecoveredCriticalSyncFailure,
    );
  }
}

final syncStateNotifierProvider =
    NotifierProvider<SyncStateNotifier, SyncState>(() {
      return SyncStateNotifier();
    });
