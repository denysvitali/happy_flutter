import 'dart:async';

import 'package:riverpod/riverpod.dart';

import '../models/loop.dart';
import '../services/logger_service.dart' show logger;
import '../services/sync_service.dart';

/// Per-session loop state mirrored from the daemon.
///
/// Listens to [Sync.onLoopsChanged] and exposes the in-memory map via
/// [state]. Mutations (create / delete / pause) call through to the
/// daemon via [Sync] RPC wrappers and rely on the resulting
/// `loops-updated` socket event to refresh local state.
class LoopsNotifier extends Notifier<Map<String, List<Loop>>> {
  StreamSubscription<String>? _sub;
  int _lastChangeCounter = -1;

  @override
  Map<String, List<Loop>> build() {
    _sub = sync.onLoopsChanged.listen(_handleLoopsChanged);
    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
    });
    return <String, List<Loop>>{};
  }

  void _handleLoopsChanged(String sessionId) {
    loadFromSync();
  }

  /// Instant read from in-memory sync state.
  ///
  /// Mirrors the [SessionsNotifier.loadFromSync] pattern: cheap, called
  /// on every `onLoopsChanged` tick. For the initial population after
  /// reconnect, prefer [refreshFromSync].
  void loadFromSync() {
    if (!sync.isInitialized) return;
    final counter = sync.domainChangeCounter(SyncDomain.loops);
    if (counter == _lastChangeCounter) return;
    _lastChangeCounter = counter;
    final next = sync.loopsBySession;
    if (_mapsIdentical(state, next)) return;
    state = Map<String, List<Loop>>.from(
      next.map(
        (key, value) => MapEntry(
          key,
          List<Loop>.unmodifiable(value),
        ),
      ),
    );
  }

  /// Hydrate in-memory loop state from MMKV and publish to listeners.
  ///
  /// Fast (synchronous MMKV read). Used to render cached data
  /// immediately while the server fetch runs in the background — see
  /// `LoopsScreen._refresh` for the hydrate-then-refresh flow.
  ///
  /// Returns `true` if any cached loops were found, so callers can
  /// decide whether to show a loading spinner or skip straight to the
  /// populated list. Idempotent.
  bool hydrateFromCache() {
    if (!sync.isInitialized) return false;
    sync.hydrateAllFromCache();
    loadFromSync();
    return sync.loopsBySession.values.any((l) => l.isNotEmpty);
  }

  /// Server-fetch + read. Best-effort — failures are logged and ignored.
  Future<void> refreshFromSync() async {
    if (!sync.isInitialized) return;
    try {
      await sync.refreshAllLoops();
    } catch (e, st) {
      logger.warning('LoopsNotifier.refreshFromSync failed: $e', e, st);
    }
    loadFromSync();
  }

  /// Returns the loops for [sessionId] (empty list if none).
  List<Loop> loopsForSession(String sessionId) =>
      state[sessionId] ?? const <Loop>[];

  /// Returns the count of loops for [sessionId].
  int countForSession(String sessionId) {
    final list = state[sessionId];
    return list?.length ?? 0;
  }

  /// Create a new loop on the daemon. Returns the canonical [Loop]
  /// returned by the RPC.
  Future<Loop> createLoop({
    required String sessionId,
    required String expression,
    required String prompt,
    required bool recurring,
  }) {
    return sync.createLoop(
      sessionId: sessionId,
      expression: expression,
      prompt: prompt,
      recurring: recurring,
    );
  }

  /// Delete a loop. Throws [StateError] when the daemon rejects.
  Future<void> deleteLoop({
    required String sessionId,
    required String loopId,
  }) {
    return sync.deleteLoop(sessionId: sessionId, loopId: loopId);
  }

  /// Pause or resume a loop. Throws [StateError] when the daemon rejects.
  Future<void> pauseLoop({
    required String sessionId,
    required String loopId,
    required bool paused,
  }) {
    return sync.pauseLoop(
      sessionId: sessionId,
      loopId: loopId,
      paused: paused,
    );
  }

  /// Per-session map identity check that ignores outer wrapper
  /// differences (e.g. `Map.unmodifiable`).
  bool _mapsIdentical(
    Map<String, List<Loop>> a,
    Map<String, List<Loop>> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null) return false;
      if (other.length != entry.value.length) return false;
      for (var i = 0; i < entry.value.length; i++) {
        if (entry.value[i] != other[i]) return false;
      }
    }
    return true;
  }
}

final loopsNotifierProvider =
    NotifierProvider<LoopsNotifier, Map<String, List<Loop>>>(LoopsNotifier.new);
