part of 'sync_service.dart';

/// Encapsulates staleness/recent-checking logic for session state evaluation.
///
/// Evaluates whether a session appears healthy ("looks ready") based on:
/// - Lifecycle state and its timestamp
/// - Spawn timestamp (to avoid auto-restore races)
/// - Online presence cross-checked with last ephemeral event
class SyncHealth {
  const SyncHealth({
    required this.session,
    required Map<String, int> sessionSpawnedAt,
    required Map<String, int> lastEphemeralAt,
  }) : _sessionSpawnedAt = sessionSpawnedAt,
       _lastEphemeralAt = lastEphemeralAt;

  final Session session;
  final Map<String, int> _sessionSpawnedAt;
  final Map<String, int> _lastEphemeralAt;

  static const int _recentThresholdMs = 120000;

  /// Returns true if [timestamp] is within [_recentThresholdMs] of now.
  bool _isRecent(int? timestamp) {
    if (timestamp == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    return now - timestamp < _recentThresholdMs;
  }

  /// Whether the session's online presence is trustworthy.
  ///
  /// After a daemon restart, presence='online' can persist for up to 60s
  /// while the session is actually dead. Cross-checking with the last
  /// ephemeral event (keep-alive / activity) ensures the presence is
  /// backed by a recent real-time signal.
  bool get isOnlineTrusted {
    final ephemeralAt = _lastEphemeralAt[session.id];
    final ephemeralRecent = _isRecent(ephemeralAt);
    return session.isOnline && ephemeralRecent;
  }

  /// Whether the session appears ready to receive messages.
  ///
  /// A session "looks ready" when it is not archived AND either:
  /// - Its online presence is trusted (isOnlineTrusted), OR
  /// - The agent is starting/running AND the lifecycle state timestamp
  ///   is recent (guards against stale 'running' after a crash), OR
  /// - The agent is `running` and currently present as online.
  ///
  /// The last clause is load-bearing for Codex. `lifecycleStateSince` is
  /// only stamped at spawn, so a healthy process older than 2 minutes
  /// used to fail `lcRecent`. Combined with a missed `session-alive`
  /// ephemeral, `looksReady` went false and sendMessage auto-restored —
  /// killing the live Codex app-server and starting a new thread with
  /// no conversation history.
  bool get looksReady {
    final lifecycleState = session.effectiveLifecycleState;
    final isArchived = lifecycleState == 'archived';
    final agentIsStartingOrRunning =
        lifecycleState == 'starting' || lifecycleState == 'running';
    final runningAndOnline = lifecycleState == 'running' && session.isOnline;

    return !isArchived &&
        (isOnlineTrusted ||
            (agentIsStartingOrRunning && lcRecent) ||
            runningAndOnline);
  }

  /// Whether the lifecycle state timestamp is recent.
  bool get lcRecent => _isRecent(session.metadata?.lifecycleStateSince);

  /// Whether the session was spawned recently (within [_recentThresholdMs]).
  ///
  /// Used to skip auto-restore while the daemon's lifecycle update propagates.
  bool get wasRecentlySpawned {
    final spawnedAtMs = _sessionSpawnedAt[session.id];
    return _isRecent(spawnedAtMs);
  }
}
