// Phase 2: a single Notifier that hoists the build-time `sync.*` reads
// (lastMessageTimestamp, lastMessagePreview, lastMessageRole,
// unreadCount, optimisticallyArchivedIds, hasOlderMessages,
// isLoadingOlderMessages, isSessionReadyForMessages, sessionUsage)
// out of widget `build()` methods into reactive Riverpod state.
//
// Widgets access per-session derived data via [sessionUiEntryProvider]
// and the optimistic-archived set via [optimisticallyArchivedIdsProvider]
// (added in `derived_view_providers.dart`).
import 'package:flutter/foundation.dart';
import 'package:riverpod/riverpod.dart';

import '../services/auto_archive_service.dart';
import '../services/logger_service.dart' show logger;
import '../services/opentelemetry_service.dart';
import '../services/sync_service.dart';
import '../utils/performance_buckets.dart';

/// Per-session derived UI data, all of which used to be read directly
/// from the `Sync` singleton inside widget `build()` methods.
@immutable
class SessionUiEntry {
  const SessionUiEntry({
    this.lastMessageTimestamp,
    this.lastMessagePreview,
    this.lastMessageRole,
    this.unreadCount = 0,
    this.hasOlderMessages = false,
    this.isLoadingOlderMessages = false,
    this.isSessionReadyForMessages = false,
    this.sessionUsage = const {},
    this.hasUnsettledSend = false,
  });

  final int? lastMessageTimestamp;
  final String? lastMessagePreview;
  final String? lastMessageRole;
  final int unreadCount;
  final bool hasOlderMessages;
  final bool isLoadingOlderMessages;
  final bool isSessionReadyForMessages;
  final Map<String, dynamic> sessionUsage;
  final bool hasUnsettledSend;

  /// Default (empty) entry — used when a session isn't in the cache yet
  /// or has been cleared. Widgets that consume the entry can render an
  /// empty/unread-zero state without null checks.
  static const empty = SessionUiEntry();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SessionUiEntry) return false;
    return lastMessageTimestamp == other.lastMessageTimestamp &&
        lastMessagePreview == other.lastMessagePreview &&
        lastMessageRole == other.lastMessageRole &&
        unreadCount == other.unreadCount &&
        hasOlderMessages == other.hasOlderMessages &&
        isLoadingOlderMessages == other.isLoadingOlderMessages &&
        isSessionReadyForMessages == other.isSessionReadyForMessages &&
        hasUnsettledSend == other.hasUnsettledSend &&
        mapEquals(sessionUsage, other.sessionUsage);
  }

  @override
  int get hashCode => Object.hash(
    lastMessageTimestamp,
    lastMessagePreview,
    lastMessageRole,
    unreadCount,
    hasOlderMessages,
    isLoadingOlderMessages,
    isSessionReadyForMessages,
    hasUnsettledSend,
    Object.hashAll(
      sessionUsage.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}

/// Composite state for the notifier. [bySessionId] is keyed by
/// sessionId; [optimisticallyArchivedIds] is a flat set.
@immutable
class SessionUiState {
  const SessionUiState({
    this.bySessionId = const {},
    this.optimisticallyArchivedIds = const <String>{},
  });

  final Map<String, SessionUiEntry> bySessionId;
  final Set<String> optimisticallyArchivedIds;

  static const empty = SessionUiState();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SessionUiState) return false;
    if (optimisticallyArchivedIds.length !=
        other.optimisticallyArchivedIds.length) {
      return false;
    }
    if (!optimisticallyArchivedIds.containsAll(
      other.optimisticallyArchivedIds,
    )) {
      return false;
    }
    if (bySessionId.length != other.bySessionId.length) return false;
    for (final entry in bySessionId.entries) {
      final otherEntry = other.bySessionId[entry.key];
      if (otherEntry == null || otherEntry != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(bySessionId.entries.map((e) => Object.hash(e.key, e.value))),
    Object.hashAllUnordered(optimisticallyArchivedIds),
  );
}

/// Owns the per-session UI data hoisted from `sync.*` reads in
/// widget `build()` methods. Wires up via [loadFromSync] (called from
/// screens that already subscribe to `sync.onDataChanged` via
/// `SyncSubscriptionMixin`).
class SessionUiStateNotifier extends Notifier<SessionUiState> {
  int _lastDataChangeCounter = -1;
  int _lastSessionsDomainCounter = -1;
  int _lastMessagesDomainCounter = -1;
  final Map<String, int> _messageRevisions = {};
  final Map<String, bool> _hasUnsettledSend = {};
  int _lastScaleTraceAtMs = 0;
  int _lastSlowLogAtMs = 0;

  static const int _slowComputeMs = 16;
  static const int _scaleTraceMinSessions = 11;
  static const int _telemetryThrottleMs = 30000;

  @override
  SessionUiState build() {
    // Compute the initial state eagerly when the notifier is first read,
    // so consumers never see an empty cache on their first frame. Further
    // updates are driven by [loadFromSync] from sync-subscription callbacks.
    if (!sync.isInitialized) return SessionUiState.empty;
    final initial = _computeAllFromSync(trigger: 'initial').state;
    _lastDataChangeCounter = sync.dataChangeCounter;
    _lastSessionsDomainCounter = sync.domainChangeCounter(SyncDomain.sessions);
    _lastMessagesDomainCounter = sync.domainChangeCounter(SyncDomain.messages);
    return initial;
  }

  /// Reload derived UI state from `sync` if any of the watched counters
  /// changed since the last call. Idempotent: safe to call from every
  /// `onDataChanged` / `onDomainChanged` callback.
  void loadFromSync() {
    if (!sync.isInitialized) return;

    final dataCounter = sync.dataChangeCounter;
    final sessionsDomainCounter = sync.domainChangeCounter(SyncDomain.sessions);
    final messagesDomainCounter = sync.domainChangeCounter(SyncDomain.messages);

    if (dataCounter == _lastDataChangeCounter &&
        sessionsDomainCounter == _lastSessionsDomainCounter &&
        messagesDomainCounter == _lastMessagesDomainCounter) {
      return;
    }
    final trigger = _computeTrigger(
      sessionsChanged: sessionsDomainCounter != _lastSessionsDomainCounter,
      messagesChanged: messagesDomainCounter != _lastMessagesDomainCounter,
    );
    _lastDataChangeCounter = dataCounter;
    _lastSessionsDomainCounter = sessionsDomainCounter;
    _lastMessagesDomainCounter = messagesDomainCounter;

    final result = _computeAllFromSync(trigger: trigger, previousState: state);
    if (result.state != state) {
      state = result.state;
    }
  }

  /// Refresh only [sessionId] after its message stream changes.
  ///
  /// Chat used to call [loadFromSync] on every streaming tick. With hundreds
  /// of sessions that scanned every cached message window merely to update
  /// one chat header. This path preserves all unrelated entry identities and
  /// limits the expensive message scan to the changed session.
  void loadSessionFromSync(String sessionId) {
    if (!sync.isInitialized) return;

    final stopwatch = Stopwatch()..start();
    final sessions = sync.sessions;
    final session = sessions[sessionId];
    final span = _startScaleTrace('single', sessions.length);
    final previous = state.bySessionId[sessionId];
    final nextEntries = Map<String, SessionUiEntry>.from(state.bySessionId);
    var changed = 0;

    if (session == null) {
      if (nextEntries.remove(sessionId) != null) changed = 1;
      _messageRevisions.remove(sessionId);
      _hasUnsettledSend.remove(sessionId);
    } else {
      final usage = sync.sessionUsage[sessionId];
      final next = _computeEntry(sessionId, previous, usage);
      if (!identical(next, previous)) {
        nextEntries[sessionId] = next;
        changed = 1;
      }
    }

    if (changed > 0) {
      state = SessionUiState(
        bySessionId: Map<String, SessionUiEntry>.unmodifiable(nextEntries),
        optimisticallyArchivedIds: state.optimisticallyArchivedIds,
      );
    }
    _recordCompute(
      stopwatch: stopwatch,
      trigger: 'single',
      sessionCount: sessions.length,
      changedCount: changed,
      span: span,
    );
  }

  ({SessionUiState state, int changed}) _computeAllFromSync({
    required String trigger,
    SessionUiState previousState = SessionUiState.empty,
  }) {
    final stopwatch = Stopwatch()..start();
    final sessions = sync.sessions;
    final usageBySession = sync.sessionUsage;
    final span = _startScaleTrace(trigger, sessions.length);
    final bySessionId = <String, SessionUiEntry>{};
    var changed = 0;
    for (final session in sessions.values) {
      final previous = previousState.bySessionId[session.id];
      final next = _computeEntry(
        session.id,
        previous,
        usageBySession[session.id],
      );
      bySessionId[session.id] = next;
      if (!identical(next, previous)) changed++;
    }
    changed +=
        previousState.bySessionId.length -
        previousState.bySessionId.keys.where(sessions.containsKey).length;

    _messageRevisions.removeWhere((id, _) => !sessions.containsKey(id));
    _hasUnsettledSend.removeWhere((id, _) => !sessions.containsKey(id));

    final result = SessionUiState(
      bySessionId: Map.unmodifiable(bySessionId),
      optimisticallyArchivedIds: Set<String>.unmodifiable(
        sync.getOptimisticallyArchivedIds(),
      ),
    );
    _recordCompute(
      stopwatch: stopwatch,
      trigger: trigger,
      sessionCount: sessions.length,
      changedCount: changed,
      span: span,
    );
    return (state: result, changed: changed);
  }

  SessionUiEntry _computeEntry(
    String sessionId,
    SessionUiEntry? previous,
    Map<String, dynamic>? usage,
  ) {
    final revision = sync.messagesRevision(sessionId);
    final bool unsettled;
    if (_messageRevisions[sessionId] == revision &&
        _hasUnsettledSend.containsKey(sessionId)) {
      unsettled = _hasUnsettledSend[sessionId]!;
    } else {
      unsettled = AutoArchiveService.hasUnsettledSend(
        sync.messagesForSession(sessionId),
      );
      _messageRevisions[sessionId] = revision;
      _hasUnsettledSend[sessionId] = unsettled;
    }

    final rawUsage = usage ?? const <String, dynamic>{};
    final immutableUsage =
        previous != null && mapEquals(previous.sessionUsage, rawUsage)
        ? previous.sessionUsage
        : Map<String, dynamic>.unmodifiable(rawUsage);
    final next = SessionUiEntry(
      lastMessageTimestamp: sync.getLastMessageTimestamp(sessionId),
      lastMessagePreview: sync.getLastMessagePreview(sessionId),
      lastMessageRole: sync.getLastMessageRole(sessionId),
      unreadCount: sync.getUnreadCount(sessionId),
      hasOlderMessages: sync.hasOlderMessages(sessionId),
      isLoadingOlderMessages: sync.isLoadingOlderMessages(sessionId),
      isSessionReadyForMessages: sync.isSessionReadyForMessages(sessionId),
      sessionUsage: immutableUsage,
      hasUnsettledSend: unsettled,
    );
    return previous == next ? previous! : next;
  }

  String _computeTrigger({
    required bool sessionsChanged,
    required bool messagesChanged,
  }) {
    if (sessionsChanged && messagesChanged) return 'sessions_and_messages';
    if (sessionsChanged) return 'sessions';
    if (messagesChanged) return 'messages';
    return 'global';
  }

  OTelSpan? _startScaleTrace(String trigger, int sessionCount) {
    if (sessionCount < _scaleTraceMinSessions) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastScaleTraceAtMs < _telemetryThrottleMs) return null;
    _lastScaleTraceAtMs = now;
    return OpenTelemetryService().startTrace(
      'sessions.ui_state.compute',
      attributes: {
        'compute.trigger': trigger,
        'session.count': sessionCount,
        'session.count_bucket': collectionSizeBucket(sessionCount),
      },
    );
  }

  void _recordCompute({
    required Stopwatch stopwatch,
    required String trigger,
    required int sessionCount,
    required int changedCount,
    required OTelSpan? span,
  }) {
    stopwatch.stop();
    final duration = stopwatch.elapsed;
    OpenTelemetryService().recordDuration(
      'app.sessions.ui_state_compute',
      duration,
      attributes: {
        'compute_trigger': trigger,
        'session_count_bucket': collectionSizeBucket(sessionCount),
        'changed_count_bucket': collectionSizeBucket(changedCount),
      },
      description: 'Time to derive session UI state from Sync',
    );
    span
      ?..setAttribute('entry.changed_count', changedCount)
      ..setAttribute('work.duration_ms', duration.inMilliseconds)
      ..end();

    final now = DateTime.now().millisecondsSinceEpoch;
    if (duration.inMilliseconds >= _slowComputeMs &&
        now - _lastSlowLogAtMs >= _telemetryThrottleMs) {
      _lastSlowLogAtMs = now;
      logger.warning(
        '[Perf] sessions UI state compute '
        'trigger=$trigger sessions=$sessionCount changed=$changedCount '
        'elapsedMs=${duration.inMilliseconds}',
      );
    }
  }

  /// Clear all derived UI state. Called on logout via the standard
  /// `AuthStateNotifier.clear()` cascade.
  void clear() {
    _lastDataChangeCounter = -1;
    _lastSessionsDomainCounter = -1;
    _lastMessagesDomainCounter = -1;
    _messageRevisions.clear();
    _hasUnsettledSend.clear();
    _lastScaleTraceAtMs = 0;
    _lastSlowLogAtMs = 0;
    state = SessionUiState.empty;
  }
}

final sessionUiStateNotifierProvider =
    NotifierProvider<SessionUiStateNotifier, SessionUiState>(() {
      return SessionUiStateNotifier();
    });
