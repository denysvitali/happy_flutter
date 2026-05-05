import 'dart:async';

import 'package:riverpod/riverpod.dart';

import '../services/sync_service.dart';

/// Whether any sync operation is currently running.
class SyncState {
  const SyncState({this.isSyncing = false, this.progress});
  final bool isSyncing;
  final SyncProgress? progress;
}

class SyncStateNotifier extends Notifier<SyncState> {
  StreamSubscription<void>? _subscription;

  @override
  SyncState build() {
    _subscription?.cancel();
    _subscription = sync.onSyncStateChanged.listen((_) {
      state = SyncState(isSyncing: sync.isSyncing, progress: sync.syncProgress);
    });
    ref.onDispose(() => _subscription?.cancel());
    return SyncState(isSyncing: sync.isSyncing, progress: sync.syncProgress);
  }
}

final syncStateNotifierProvider =
    NotifierProvider<SyncStateNotifier, SyncState>(() {
      return SyncStateNotifier();
    });
