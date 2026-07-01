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

  // ── In-band control-event routing ──────────────────────────────────────

  /// Agent-event `data.type` discriminators the daemon uses to push loop
  /// state changes over the encrypted session message stream.
  static const Set<String> _loopControlEventTypes = {
    'loops-updated',
    'loop-fired',
    'loop-expired',
  };

  static bool _isDeadLoopSessionError(StateError error) {
    return error.message.contains('Session encryption not found') ||
        error.message.contains('no scheduler for session');
  }

  /// The daemon (`happy-cli-go`) has no server-modeled loop entity, so it
  /// broadcasts loop state changes as in-band session events via
  /// `SendSessionEvent` — they arrive decoded as `agent-event` messages with
  /// `event.type` in [_loopControlEventTypes], NOT as top-level `update`
  /// socket frames. (The `update`-channel handlers in `_sync_socket_events`
  /// only fire if a future server learns to model loops.)
  ///
  /// This routes those control events into loop state and returns [messages]
  /// with them stripped out, so they never render as chat rows. Called on the
  /// main isolate from the ingestion pipeline, just before messages are
  /// upserted (see `_processMessageBatch`).
  List<Map<String, dynamic>> consumeLoopControlMessages(
    String sessionId,
    List<Map<String, dynamic>> messages,
  ) {
    // Fast path: nothing to do for the overwhelmingly common case of a batch
    // with no loop control events.
    final hasControlEvent = messages.any(_isLoopControlMessage);
    if (!hasControlEvent) return messages;

    final passthrough = <Map<String, dynamic>>[];
    for (final message in messages) {
      if (!_isLoopControlMessage(message)) {
        passthrough.add(message);
        continue;
      }
      // The daemon always stamps `sid`, but default to the owning session so
      // a malformed payload still updates the right list (the spread lets a
      // present `sid` win over the default).
      final event = <String, dynamic>{
        'sid': sessionId,
        ...Map<String, dynamic>.from(message['event'] as Map),
      };
      switch (event['type'] as String?) {
        case 'loops-updated':
          _handleLoopsUpdated(event);
          break;
        case 'loop-fired':
          _handleLoopFired(event);
          break;
        case 'loop-expired':
          _handleLoopExpired(event);
          break;
      }
    }
    return passthrough;
  }

  bool _isLoopControlMessage(Map<String, dynamic> message) {
    if (message['kind'] != 'agent-event') return false;
    final event = message['event'];
    if (event is! Map) return false;
    return _loopControlEventTypes.contains(event['type']);
  }

  // ── Socket event handlers ──────────────────────────────────────────────

  /// Apply a `loops-updated` event from the socket.
  ///
  /// The payload is `{sid, loops: Loop[]}` per `docs/LOOPS.md`. We treat it
  /// as the source of truth and replace the local list wholesale.
  /// Malformed entries are skipped with a warning rather than
  /// poisoning the entire batch — see [Loop.tryFromJson] for the
  /// lenient parser.
  void _applyLoopsUpdate(String sessionId, List<dynamic> loopsJson) {
    final loops = _parseLoopList(
      sessionId: sessionId,
      loopsJson: loopsJson,
      source: '_applyLoopsUpdate',
    );
    _publishLoopsForSession(sessionId, loops);
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
    _publishLoopsForSession(sessionId, updated);
  }

  /// Apply a `loop-expired` event. Removes the loop from the local list and
  /// persists the trimmed list.
  void _applyLoopExpired(String sessionId, String loopId) {
    final loops = _loopsBySession[sessionId];
    if (loops == null) return;
    final filtered = loops.where((l) => l.id != loopId).toList();
    if (filtered.length == loops.length) return;
    _publishLoopsForSession(sessionId, filtered);
  }

  /// Apply a locally confirmed delete. A later `loops-updated` event can
  /// still replace this mirror with the daemon's full authoritative list.
  void _applyLoopDeleted(String sessionId, String loopId) {
    final loops = _loopsBySession[sessionId];
    if (loops == null) return;
    final filtered = loops.where((l) => l.id != loopId).toList();
    if (filtered.length == loops.length) return;
    _publishLoopsForSession(sessionId, filtered, notifyDataChanged: true);
  }

  List<Loop> _parseLoopList({
    required String sessionId,
    required List<dynamic> loopsJson,
    required String source,
  }) {
    final loops = <Loop>[];
    for (final entry in loopsJson) {
      if (entry is Map) {
        final loop = Loop.tryFromJson(Map<String, dynamic>.from(entry));
        if (loop != null) {
          loops.add(loop);
        } else {
          logger.warning(
            '[loops] $source($sessionId) skipping malformed entry',
          );
        }
      }
    }
    return loops;
  }

  void _publishLoopsForSession(
    String sessionId,
    List<Loop> loops, {
    bool notifyDataChanged = false,
  }) {
    final next = List<Loop>.unmodifiable(loops);
    _loopsBySession[sessionId] = next;
    LoopStorage.instance.save(sessionId, next);
    _loopsChangeController.add(sessionId);
    if (notifyDataChanged) {
      _notifyDataChanged({SyncDomain.loops});
    }
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
  /// Fires the per-session stream and bumps the domain counter so
  /// subscribers see the removal immediately — symmetric with every
  /// other mutation path in this file (which all fire
  /// [_loopsChangeController] + [_notifyDataChanged]). Without this,
  /// the loops screen for the deleted session would render a stale
  /// list until the next unrelated change.
  void clearLoopsForSession(String sessionId) {
    _loopsBySession.remove(sessionId);
    LoopStorage.instance.clear(sessionId);
    _loopsChangeController.add(sessionId);
    _notifyDataChanged({SyncDomain.loops});
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

  /// Delete a loop. The daemon is authoritative, but after it confirms the
  /// delete we also trim the local mirror immediately. A later
  /// `loops-updated` event still wins with the full daemon list.
  ///
  /// Optimistically removes the loop from local state before the RPC so
  /// the UI updates without waiting for the round-trip. If the daemon
  /// rejects because the session is dead ("no scheduler for session" or
  /// "Session encryption not found"), the optimistic removal is retained —
  /// the on-disk loop file will be cleaned up by the daemon's disk-fallback
  /// handler when it restarts. Socket disconnection or RPC timeouts are also
  /// swallowed; the authoritative state will be refreshed on reconnect.
  Future<void> deleteLoop({
    required String sessionId,
    required String loopId,
  }) async {
    // Optimistic: remove from local state immediately so the UI updates
    // without waiting for the RPC round-trip.
    _applyLoopDeleted(sessionId, loopId);

    dynamic raw;
    try {
      raw = await sessionRPC(
        sessionId,
        'loop-delete',
        <String, dynamic>{'loopId': loopId},
      );
    } on StateError catch (e) {
      if (_isDeadLoopSessionError(e)) {
        // Session is dead — the optimistic removal is the best we can do.
        // The daemon's disk-fallback handler (happy-cli-go) will clean up
        // the on-disk file if it ever restarts this session.
        logger.info(
          '[loops] deleteLoop($sessionId, $loopId) — session dead, '
          'optimistic removal retained',
        );
        return;
      }
      // Unexpected StateError — rethrow so the caller can show an error.
      rethrow;
    } on SocketNotConnectedException {
      // Socket down — keep the optimistic removal. A reconnect will
      // refresh the full list via loops-updated.
      logger.info(
        '[loops] deleteLoop($sessionId, $loopId) — socket disconnected, '
        'optimistic removal retained',
      );
      return;
    } on SocketAckTimeoutException {
      // Daemon may be wedged — keep the optimistic removal. The user
      // can refresh later; a timeout here is not a reason to resurrect
      // the loop in the UI.
      logger.info(
        '[loops] deleteLoop($sessionId, $loopId) — RPC timed out, '
        'optimistic removal retained',
      );
      return;
    }

    if (raw is! Map) {
      throw StateError(
        'loop-delete returned unexpected type: ${raw.runtimeType}',
      );
    }
    final ok = raw['ok'];
    if (ok == false) {
      final err = raw['error']?.toString() ?? 'unknown error';
      // Daemon explicitly rejected — roll back the optimistic removal
      // so the user can retry or investigate.
      logger.warning(
        '[loops] deleteLoop($sessionId, $loopId) daemon rejected: $err — '
        'rolling back optimistic removal',
      );
      // Rollback: re-fetch the authoritative list from the daemon.
      // We can't reconstruct the single loop, so we refresh the whole
      // session's loops. This is rare (daemon rejection with live session).
      await listLoops(sessionId: sessionId);
      throw StateError('loop-delete failed: $err');
    }
    // RPC confirmed — optimistic state is already correct.
  }

  /// Pause or resume a loop. Same optimistic pattern as [deleteLoop]:
  /// toggles the paused flag locally first, then confirms with the daemon.
  /// If the session is dead, socket is down, or the RPC times out, the
  /// optimistic state is retained and will be reconciled on reconnect.
  Future<void> pauseLoop({
    required String sessionId,
    required String loopId,
    required bool paused,
  }) async {
    // Optimistic: toggle the paused flag locally so the UI updates
    // immediately without waiting for the RPC round-trip.
    final loops = _loopsBySession[sessionId];
    if (loops != null) {
      final idx = loops.indexWhere((l) => l.id == loopId);
      if (idx >= 0) {
        final updated = List<Loop>.from(loops);
        updated[idx] = loops[idx].copyWith(paused: paused);
        _loopsBySession[sessionId] = List<Loop>.unmodifiable(updated);
        LoopStorage.instance.save(sessionId, updated);
        _loopsChangeController.add(sessionId);
        _notifyDataChanged({SyncDomain.loops});
      }
    }

    dynamic raw;
    try {
      raw = await sessionRPC(
        sessionId,
        'loop-pause',
        <String, dynamic>{'loopId': loopId, 'paused': paused},
      );
    } on StateError catch (e) {
      if (_isDeadLoopSessionError(e)) {
        logger.info(
          '[loops] pauseLoop($sessionId, $loopId) — session dead, '
          'optimistic pause retained',
        );
        return;
      }
      rethrow;
    } on SocketNotConnectedException {
      logger.info(
        '[loops] pauseLoop($sessionId, $loopId) — socket disconnected, '
        'optimistic pause retained',
      );
      return;
    } on SocketAckTimeoutException {
      logger.info(
        '[loops] pauseLoop($sessionId, $loopId) — RPC timed out, '
        'optimistic pause retained',
      );
      return;
    }

    if (raw is! Map) {
      throw StateError(
        'loop-pause returned unexpected type: ${raw.runtimeType}',
      );
    }
    final ok = raw['ok'];
    if (ok == false) {
      final err = raw['error']?.toString() ?? 'unknown error';
      // Rollback: re-fetch the authoritative list from the daemon.
      logger.warning(
        '[loops] pauseLoop($sessionId, $loopId) daemon rejected: $err — '
        'rolling back optimistic pause',
      );
      await listLoops(sessionId: sessionId);
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
    if (raw['ok'] == false) {
      final err = raw['error']?.toString() ?? 'unknown error';
      throw StateError('loop-list failed: $err');
    }
    final loopsJson = raw['loops'];
    if (loopsJson is! List) {
      // Some daemons return an empty list under a different key — fall
      // back to treating the response as a zero-loop list. We still
      // must mirror the empty list into in-memory state, persist it,
      // and bump the domain counter so subscribers (and the notifier's
      // counter guard) see the change — otherwise a daemon that
      // legitimately has no loops would leave the user looking at a
      // stale cached list forever. The previous silent early-return
      // was a real bug: no breadcrumb, no stream fire, no counter
      // bump, no MMKV clear.
      logger.warning(
        '[loops] listLoops($sessionId) returned non-list "loops" '
        'payload (${loopsJson.runtimeType}); treating as empty',
      );
      _publishLoopsForSession(
        sessionId,
        const <Loop>[],
        notifyDataChanged: true,
      );
      return const <Loop>[];
    }
    final loops = _parseLoopList(
      sessionId: sessionId,
      loopsJson: loopsJson,
      source: 'listLoops',
    );
    // Mirror into in-memory state and bump the domain counter so
    // LoopsNotifier.loadFromSync picks up the change. Without the
    // counter bump, client-initiated listLoops would publish to
    // onLoopsChanged but the notifier's _lastChangeCounter guard
    // would short-circuit, leaving the screen's Riverpod state empty
    // even though the data is right there in _loopsBySession.
    _publishLoopsForSession(sessionId, loops, notifyDataChanged: true);
    return loops;
  }

  /// Hydrate [loopsBySession] from MMKV for every known session, then
  /// publish so [LoopsNotifier] subscribers see the cached state.
  ///
  /// Instant — no network. Called before [refreshAllLoops] so the UI can
  /// render cached data immediately instead of a blank spinner while the
  /// server fetch resolves (or hangs). Idempotent: re-hydrating an
  /// already-loaded session is a no-op via [hydrateLoopsForSession].
  void hydrateAllFromCache() {
    for (final sessionId in _sessions.keys) {
      hydrateLoopsForSession(sessionId);
    }
    // Bump the domain counter so LoopsNotifier.loadFromSync picks up the
    // newly-hydrated state. Without this, cold-start users would see the
    // spinner until either refreshAllLoops completes or a real
    // `loops-updated` socket event arrives.
    _notifyDataChanged({SyncDomain.loops});
    // Also fire the onLoopsChanged stream so notifier subscribers that
    // were built BEFORE the cold-start hydrate (e.g. a user who tapped
    // the Loops tab while sync was still initializing) actually wake
    // up and reload. The notifier's loadFromSync short-circuits on the
    // domain counter check, so without a stream event the only thing
    // that could have woken it up was either the user's explicit
    // hydrateFromCache() call (which already returned false because
    // !isInitialized at the time) or a real server-pushed
    // `loops-updated`. One fire per cold start is enough — the
    // notifier reads the full _loopsBySession map regardless of which
    // sessionId we pass.
    if (_loopsBySession.isNotEmpty) {
      _loopsChangeController.add(_loopsBySession.keys.first);
    }
  }

  /// Refresh loops for every known session.
  ///
  /// Best-effort — sessions whose `sessionRPC` call fails are logged and
  /// skipped. Used by `LoopsNotifier.refreshFromSync()`.
  ///
  /// Bounded by a hard total [_refreshAllLoopsDeadline] so that a slow
  /// or unresponsive daemon cannot stack N × 30 s ACK timeouts into a
  /// multi-minute UI hang. On a transient error, iteration stops
  /// immediately (every remaining session would fail the same way and
  /// `loops-updated` socket events will refresh us once the forwarding
  /// path recovers).
  static const Duration _refreshAllLoopsDeadline = Duration(seconds: 10);

  Future<void> refreshAllLoops() async {
    if (!isInitialized) return;
    if (!_isSocketConnected()) {
      // No point waiting 10 s per session for emitWithAck to time out; the
      // cached/MMKV state is the best we can show while disconnected, and
      // `loops-updated` events will refresh us after reconnect.
      logger.debug('[loops] refreshAllLoops skipped — socket not connected');
      return;
    }
    final sessionIds = _sessions.keys.toList(growable: false);
    if (sessionIds.isEmpty) return;

    // Sort by recent activity so a transient error on one stale
    // session doesn't strand the active ones we'd most want to
    // refresh. We rely on `Session.activeAt` (ms timestamp of last
    // user-visible activity) — 0 means unknown/never and sorts last.
    sessionIds.sort((a, b) {
      final aa = _sessions[a]?.activeAt ?? 0;
      final bb = _sessions[b]?.activeAt ?? 0;
      return bb.compareTo(aa); // most-recent-first
    });

    final startedAt = DateTime.now();
    for (final sessionId in sessionIds) {
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed >= _refreshAllLoopsDeadline) {
        // Out of time. Any remaining sessions will be refreshed by the
        // next `loops-updated` event or the next manual refresh. We
        // compare against the elapsed Duration rather than subtracting
        // it from the deadline because `Duration.operator-` throws on
        // negative results — and elapsed can exceed the deadline if
        // the previous iteration's listLoops ran slow.
        logger.debug(
          '[loops] refreshAllLoops deadline exceeded — '
          'skipping ${sessionIds.length - sessionIds.indexOf(sessionId)} '
          'remaining sessions',
        );
        break;
      }
      final remaining = _refreshAllLoopsDeadline - elapsed;
      try {
        // Per-call timeout shrinks to match the remaining budget so a
        // single wedged RPC cannot block the whole loop until its
        // internal 30 s ACK timer fires.
        await listLoops(sessionId: sessionId).timeout(
          remaining,
          onTimeout: () {
            logger.debug(
              '[loops] listLoops($sessionId) hit refresh deadline — '
              'breaking out of refreshAllLoops',
            );
            throw TimeoutException(
              'refreshAllLoops deadline exceeded on $sessionId',
            );
          },
        );
      } on TimeoutException {
        // Hit the total deadline — stop admitting more RPCs.
        break;
      } on StateError catch (e) {
        if (_isDeadLoopSessionError(e)) {
          logger.debug(
            '[loops] listLoops($sessionId) skipped - session dead: $e',
          );
          continue;
        }
        if (Sync._isRpcMethodNotAvailable(e)) {
          // Daemon predates the loop-* methods — skip silently.
          logger.debug(
            '[loops] listLoops($sessionId) skipped — RPC unavailable',
          );
          continue;
        }
        if (Sync._isTransientRpcError(e)) {
          // Infra-side forwarding broke (Redis replica timeout, or
          // daemon's response channel closed mid-flight). Stop iterating
          // — every remaining session would fail the same way, and the
          // `loops-updated` socket events will refresh us once the
          // forwarding path recovers.
          logger.debug(
            '[loops] listLoops($sessionId) skipped — transient: $e',
          );
          break;
        }
        logger.warning(
          '[loops] listLoops($sessionId) failed: $e',
          e,
        );
      } catch (e, st) {
        if (Sync._isTransientConnectionError(e)) {
          // Local socket dropped mid-iteration. Stop the loop so we don't
          // issue N more doomed emits (each one waits for emitWithAck
          // to time out).
          logger.debug(
            '[loops] listLoops($sessionId) skipped — transient: $e',
          );
          break;
        }
        logger.warning(
          '[loops] listLoops($sessionId) failed: $e',
          e,
          st,
        );
      }
    }
  }
}
