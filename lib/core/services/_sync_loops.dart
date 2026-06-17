part of 'sync_service.dart';

/// Loops are scheduled recurring prompts that fire inside an active Claude
/// session (see [Loop], `docs/LOOPS.md`).
///
/// The daemon is the authoritative owner of loop state. The Flutter client
/// mirrors state via two socket events:
///   - `loops-updated` — full replacement list per session
///   - `loop-fired` — telemetry only (the actual user message arrives via
///     `new-message` like any other turn)
/// All loop mutations (create / delete / pause / list) ride the existing
/// session-scoped RPC channel ([sessionRPC]).
extension SyncLoops on Sync {
  // ── State ──────────────────────────────────────────────────────────────

  /// Fires when the loops for a session change (create / update / delete /
  /// fire). Subscribers receive the sessionId so they can refresh only the
  /// affected view.
  Stream<String> get onLoopsChanged => _loopsChangeController.stream;

  /// Read-only snapshot of the in-memory loops map.
  Map<String, List<Loop>> get loopsBySession =>
      Map.unmodifiable(_loopsBySession);

  /// Returns the loops for [sessionId] (empty list if none).
  List<Loop> loopsForSession(String sessionId) =>
      List.unmodifiable(_loopsBySession[sessionId] ?? const <Loop>[]);

  // ── Socket event handlers ──────────────────────────────────────────────

  /// Apply a `loops-updated` event from the socket.
  ///
  /// The payload is `{sid, loops: Loop[]}` per `docs/LOOPS.md`. We treat it
  /// as the source of truth and replace the local list wholesale.
  void _applyLoopsUpdate(String sessionId, List<dynamic> loopsJson) {
    final loops = <Loop>[];
    for (final entry in loopsJson) {
      if (entry is Map) {
        loops.add(Loop.fromJson(Map<String, dynamic>.from(entry)));
      }
    }
    _loopsBySession[sessionId] = List<Loop>.unmodifiable(loops);
    LoopStorage.instance.save(sessionId, loops);
    _loopsChangeController.add(sessionId);
  }

  /// Apply a `loop-fired` event. Telemetry-only — the user-visible message
  /// arrives via the normal `new-message` path. We just bump
  /// `lastFiredAt` + `fireCount` on the matching loop so the Loops screen
  /// can show "last fired 2 minutes ago".
  void _applyLoopFired(
    String sessionId,
    String loopId,
    int firedAt,
    int fireCount,
  ) {
    final loops = _loopsBySession[sessionId];
    if (loops == null) return;
    final idx = loops.indexWhere((l) => l.id == loopId);
    if (idx < 0) return;
    final updated = List<Loop>.from(loops);
    updated[idx] = loops[idx].copyWith(
      lastFiredAt: firedAt,
      fireCount: fireCount,
    );
    _loopsBySession[sessionId] = List<Loop>.unmodifiable(updated);
    LoopStorage.instance.save(sessionId, updated);
    _loopsChangeController.add(sessionId);
  }

  /// Apply a `loop-expired` event. Removes the loop from the local list and
  /// persists the trimmed list.
  void _applyLoopExpired(String sessionId, String loopId) {
    final loops = _loopsBySession[sessionId];
    if (loops == null) return;
    final filtered = loops.where((l) => l.id != loopId).toList();
    if (filtered.length == loops.length) return;
    _loopsBySession[sessionId] = List<Loop>.unmodifiable(filtered);
    LoopStorage.instance.save(sessionId, filtered);
    _loopsChangeController.add(sessionId);
  }

  // ── Hydration ──────────────────────────────────────────────────────────

  /// Restore cached loops for [sessionId] from MMKV into the in-memory map.
  ///
  /// Called lazily on first read so cold start doesn't pay the decode cost
  /// for every session — only the ones the user actually visits.
  void hydrateLoopsForSession(String sessionId) {
    if (_loopsBySession.containsKey(sessionId)) return;
    final cached = LoopStorage.instance.load(sessionId);
    if (cached.isEmpty) return;
    _loopsBySession[sessionId] = List<Loop>.unmodifiable(cached);
  }

  /// Clear all loops for [sessionId] from in-memory state and MMKV.
  ///
  /// Used when a session is deleted (see [_handleDeleteSession]).
  void clearLoopsForSession(String sessionId) {
    _loopsBySession.remove(sessionId);
    LoopStorage.instance.clear(sessionId);
  }

  /// Clear all in-memory loop state. Test-only — production code should
  /// rely on [clearLoopsForSession] when a session is deleted.
  @visibleForTesting
  void testClearAllLoops() {
    _loopsBySession.clear();
  }

  // ── RPC wrappers ───────────────────────────────────────────────────────

  /// Create a new loop on the daemon for [sessionId].
  ///
  /// Returns the created [Loop]. Throws [StateError] when the daemon
  /// rejects the request (e.g. over the 50-cap, or
  /// `CLAUDE_CODE_DISABLE_CRON=1`).
  Future<Loop> createLoop({
    required String sessionId,
    required String expression,
    required String prompt,
    required bool recurring,
  }) async {
    final raw = await sessionRPC(
      sessionId,
      'loop-create',
      <String, dynamic>{
        'expression': expression,
        'prompt': prompt,
        'recurring': recurring,
      },
    );
    if (raw is! Map) {
      throw StateError(
        'loop-create returned unexpected type: ${raw.runtimeType}',
      );
    }
    final ok = raw['ok'];
    if (ok == false) {
      final err = raw['error']?.toString() ?? 'unknown error';
      throw StateError('loop-create failed: $err');
    }
    final loopJson = raw['loop'];
    if (loopJson is! Map) {
      throw StateError('loop-create missing loop payload');
    }
    return Loop.fromJson(Map<String, dynamic>.from(loopJson));
  }

  /// Delete a loop. The daemon is authoritative; the client does not need
  /// to remove the loop from local state — a `loops-updated` event will
  /// arrive with the trimmed list.
  Future<void> deleteLoop({
    required String sessionId,
    required String loopId,
  }) async {
    final raw = await sessionRPC(
      sessionId,
      'loop-delete',
      <String, dynamic>{'loopId': loopId},
    );
    if (raw is! Map) {
      throw StateError(
        'loop-delete returned unexpected type: ${raw.runtimeType}',
      );
    }
    final ok = raw['ok'];
    if (ok == false) {
      final err = raw['error']?.toString() ?? 'unknown error';
      throw StateError('loop-delete failed: $err');
    }
  }

  /// Pause or resume a loop. Same pattern as [deleteLoop].
  Future<void> pauseLoop({
    required String sessionId,
    required String loopId,
    required bool paused,
  }) async {
    final raw = await sessionRPC(
      sessionId,
      'loop-pause',
      <String, dynamic>{'loopId': loopId, 'paused': paused},
    );
    if (raw is! Map) {
      throw StateError(
        'loop-pause returned unexpected type: ${raw.runtimeType}',
      );
    }
    final ok = raw['ok'];
    if (ok == false) {
      final err = raw['error']?.toString() ?? 'unknown error';
      throw StateError('loop-pause failed: $err');
    }
  }

  /// Fetch the loops for [sessionId] from the daemon.
  ///
  /// Returns the latest authoritative list. The daemon may emit a
  /// `loops-updated` event in response; callers that want fresh state
  /// should also subscribe to [onLoopsChanged].
  Future<List<Loop>> listLoops({required String sessionId}) async {
    final raw = await sessionRPC(
      sessionId,
      'loop-list',
      const <String, dynamic>{},
    );
    if (raw is! Map) {
      throw StateError(
        'loop-list returned unexpected type: ${raw.runtimeType}',
      );
    }
    final loopsJson = raw['loops'];
    if (loopsJson is! List) {
      // Some daemons return an empty list under a different key — fall
      // back to checking the raw payload itself.
      return const <Loop>[];
    }
    final loops = <Loop>[];
    for (final entry in loopsJson) {
      if (entry is Map) {
        loops.add(Loop.fromJson(Map<String, dynamic>.from(entry)));
      }
    }
    // Mirror into in-memory state so subscribers see the latest data
    // immediately.
    _loopsBySession[sessionId] = List<Loop>.unmodifiable(loops);
    LoopStorage.instance.save(sessionId, loops);
    _loopsChangeController.add(sessionId);
    return loops;
  }

  /// Refresh loops for every known session.
  ///
  /// Best-effort — sessions whose `sessionRPC` call fails are logged and
  /// skipped. Used by `LoopsNotifier.refreshFromSync()`.
  Future<void> refreshAllLoops() async {
    if (!isInitialized) return;
    final sessionIds = _sessions.keys.toList(growable: false);
    for (final sessionId in sessionIds) {
      try {
        await listLoops(sessionId: sessionId);
      } on StateError catch (e) {
        if (Sync._isRpcMethodNotAvailable(e)) {
          // Daemon predates the loop-* methods — skip silently.
          logger.debug(
            '[loops] listLoops($sessionId) skipped — RPC unavailable',
          );
          continue;
        }
        logger.warning(
          '[loops] listLoops($sessionId) failed: $e',
          e,
        );
      } catch (e, st) {
        logger.warning(
          '[loops] listLoops($sessionId) failed: $e',
          e,
          st,
        );
      }
    }
  }
}
