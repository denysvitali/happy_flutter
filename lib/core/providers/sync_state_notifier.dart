import 'dart:async';

import 'package:riverpod/riverpod.dart';

import '../services/sync_service.dart';

/// Whether any sync operation is currently running.
class SyncState {
  const SyncState({this.isSyncing = false});
  final bool isSyncing;
}

class SyncStateNotifier extends Notifier<SyncState> {
  StreamSubscription<void>? _subscription;

  @override
  SyncState build() {
    _subscription?.cancel();
    _subscription = sync.onSyncStateChanged.listen((_) {
      state = SyncState(isSyncing: sync.isSyncing);
    });
    ref.onDispose(() => _subscription?.cancel());
    return SyncState(isSyncing: sync.isSyncing);
  }
}

final syncStateNotifierProvider =
    NotifierProvider<SyncStateNotifier, SyncState>(() {
  return SyncStateNotifier();
});
