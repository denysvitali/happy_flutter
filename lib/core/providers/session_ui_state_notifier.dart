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
    this.lastMessageIsError = false,
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
  final bool lastMessageIsError;
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
        lastMessageIsError == other.lastMessageIsError &&
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
    lastMessageIsError,
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

/// Identity-stable ordering inputs prepared alongside [SessionUiState].
///
/// The sessions screen previously rebuilt this timestamp map and hashed the
/// full collection inside a Riverpod `select` callback for every preview or
/// unread-count update. Preparing it while the notifier is already visiting
/// changed entries makes that selector constant-time on the rendering path.
@immutable
class SessionUiOrdering {
  const SessionUiOrdering._({
    required this.timestamps,
    required this.optimisticallyArchivedIds,
    required this.revision,
    required this.isPrepared,
  });

  static const unprepared = SessionUiOrdering._(
    timestamps: <String, int?>{},
    optimisticallyArchivedIds: <String>{},
    revision: 0,
    isPrepared: false,
  );

  static const empty = SessionUiOrdering._(
    timestamps: <String, int?>{},
    optimisticallyArchivedIds: <String>{},
    revision: 0,
    isPrepared: true,
  );

  final Map<String, int?> timestamps;
  final Set<String> optimisticallyArchivedIds;
  final int revision;

  /// False only for hand-constructed [SessionUiState] fixtures that predate
  /// this projection. Production notifier states are always prepared.
  final bool isPrepared;

  static SessionUiOrdering reconcile({
    required SessionUiOrdering previous,
    required Map<String, int?> timestamps,
    required Set<String> optimisticallyArchivedIds,
  }) {
    if (previous.isPrepared &&
        mapEquals(previous.timestamps, timestamps) &&
        setEquals(
          previous.optimisticallyArchivedIds,
          optimisticallyArchivedIds,
        )) {
      return previous;
    }
    return SessionUiOrdering._(
      timestamps: Map<String, int?>.unmodifiable(timestamps),
      optimisticallyArchivedIds: Set<String>.unmodifiable(
        optimisticallyArchivedIds,
      ),
      revision: previous.revision + 1,
      isPrepared: true,
    );
  }
}

/// Minimal Mission Control model inputs.
///
/// Preview text, usage, pagination, and readiness belong to individual rows;
/// changing them must not rebuild and re-sort the whole dashboard. Only the
/// timestamp, error flag, and unread count affect workspace grouping or lane
/// selection.
@immutable
class MissionControlUiEntry {
  const MissionControlUiEntry({
    required this.lastMessageTimestamp,
    required this.unreadCount,
    this.lastMessageIsError = false,
  });

  final int? lastMessageTimestamp;
  final int unreadCount;
  final bool lastMessageIsError;

  @override
  bool operator ==(Object other) =>
      other is MissionControlUiEntry &&
      lastMessageTimestamp == other.lastMessageTimestamp &&
      unreadCount == other.unreadCount &&
      lastMessageIsError == other.lastMessageIsError;

  @override
  int get hashCode =>
      Object.hash(lastMessageTimestamp, unreadCount, lastMessageIsError);
}

/// Identity-stable projection watched by the Mission Control model.
@immutable
class MissionControlUiProjection {
  const MissionControlUiProjection._(this.bySessionId);

  static const empty = MissionControlUiProjection._({});

  final Map<String, MissionControlUiEntry> bySessionId;

  static MissionControlUiProjection reconcile({
    required MissionControlUiProjection previous,
    required Map<String, MissionControlUiEntry> entries,
  }) {
    if (mapEquals(previous.bySessionId, entries)) return previous;
    return MissionControlUiProjection._(Map.unmodifiable(entries));
  }

  /// Compatibility snapshot for the existing pure MissionControlView API.
  /// Full preview/usage state is watched separately by each action row.
  SessionUiState toUiState() => SessionUiState(
    bySessionId: Map.unmodifiable({
      for (final entry in bySessionId.entries)
        entry.key: SessionUiEntry(
          lastMessageTimestamp: entry.value.lastMessageTimestamp,
          unreadCount: entry.value.unreadCount,
          lastMessageIsError: entry.value.lastMessageIsError,
        ),
    }),
  );
}

/// Composite state for the notifier. [bySessionId] is keyed by
/// sessionId; [optimisticallyArchivedIds] is a flat set.
@immutable
class SessionUiState {
  const SessionUiState({
    this.bySessionId = const {},
    this.optimisticallyArchivedIds = const <String>{},
    this.ordering = SessionUiOrdering.unprepared,
    this.missionControl = MissionControlUiProjection.empty,
  });

  final Map<String, SessionUiEntry> bySessionId;
  final Set<String> optimisticallyArchivedIds;
  final SessionUiOrdering ordering;
  final MissionControlUiProjection missionControl;

  static const empty = SessionUiState(ordering: SessionUiOrdering.empty);

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
  int _fullComputeCount = 0;
  int _targetedEntryMapCopyCount = 0;

  @visibleForTesting
  int get debugFullComputeCount => _fullComputeCount;

  @visibleForTesting
  int get debugTargetedEntryMapCopyCount => _targetedEntryMapCopyCount;

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
    final messagesDomainCounter = sync.domainChangeCounter(
      SyncDomain.messages,
    );

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

  /// Reconciles session catalog membership without rescanning every message
  /// window for metadata-only session-domain events.
  ///
  /// Message ingestion commonly emits a targeted session-message event and a
  /// broad session-domain event as one pair. [loadSessionFromSync] handles the
  /// first; when the catalog IDs are unchanged, the second has no additional
  /// [SessionUiState] work to do.
  void loadCatalogFromSync() {
    if (!sync.isInitialized) return;
    _lastDataChangeCounter = sync.dataChangeCounter;
    _lastSessionsDomainCounter = sync.domainChangeCounter(SyncDomain.sessions);
    final messagesDomainCounter = sync.domainChangeCounter(SyncDomain.messages);
    final pairedMessageEvent =
        messagesDomainCounter != _lastMessagesDomainCounter;
    _lastMessagesDomainCounter = messagesDomainCounter;
    final sessions = sync.sessionsView;
    final sameCatalog =
        sessions.length == state.bySessionId.length &&
        state.bySessionId.keys.every(sessions.containsKey);
    final optimisticallyArchivedIds = Set<String>.unmodifiable(
      sync.getOptimisticallyArchivedIds(),
    );
    final archiveChanged = !setEquals(
      optimisticallyArchivedIds,
      state.optimisticallyArchivedIds,
    );
    if (sameCatalog && (pairedMessageEvent || archiveChanged)) {
      if (archiveChanged) {
        state = SessionUiState(
          bySessionId: state.bySessionId,
          optimisticallyArchivedIds: optimisticallyArchivedIds,
          ordering: SessionUiOrdering.reconcile(
            previous: state.ordering,
            timestamps: state.ordering.timestamps,
            optimisticallyArchivedIds: optimisticallyArchivedIds,
          ),
          missionControl: state.missionControl,
        );
      }
      return;
    }
    final result = _computeAllFromSync(
      trigger: 'catalog',
      previousState: state,
    );
    if (result.state != state) state = result.state;
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
    // Zero-copy view: this runs on every chat message tick; copying the
    // whole catalog (251+ entries) per tick was measurable GC churn.
    final sessions = sync.sessionsView;
    final session = sessions[sessionId];
    final span = _startScaleTrace('single', sessions.length);
    final previous = state.bySessionId[sessionId];
    var changed = 0;
    SessionUiEntry? next;

    if (session == null) {
      if (state.bySessionId.containsKey(sessionId)) changed = 1;
      _messageRevisions.remove(sessionId);
      _hasUnsettledSend.remove(sessionId);
    } else {
      final usage = sync.sessionUsageView[sessionId];
      next = _computeEntry(sessionId, previous, usage);
      if (!identical(next, previous)) changed = 1;
    }

    if (changed > 0) {
      _targetedEntryMapCopyCount++;
      final nextEntries = Map<String, SessionUiEntry>.from(state.bySessionId);
      if (session == null) {
        nextEntries.remove(sessionId);
      } else {
        nextEntries[sessionId] = next!;
      }
      var ordering = state.ordering;
      final nextTimestamp = nextEntries[sessionId]?.lastMessageTimestamp;
      final orderingChanged =
          !ordering.isPrepared ||
          (session == null
              ? ordering.timestamps.containsKey(sessionId)
              : !ordering.timestamps.containsKey(sessionId) ||
                    ordering.timestamps[sessionId] != nextTimestamp);
      if (orderingChanged) {
        final timestamps = ordering.isPrepared
            ? Map<String, int?>.from(ordering.timestamps)
            : <String, int?>{
                for (final entry in nextEntries.entries)
                  entry.key: entry.value.lastMessageTimestamp,
              };
        if (session == null) {
          timestamps.remove(sessionId);
        } else {
          timestamps[sessionId] = nextTimestamp;
        }
        ordering = SessionUiOrdering.reconcile(
          previous: ordering,
          timestamps: timestamps,
          optimisticallyArchivedIds: state.optimisticallyArchivedIds,
        );
      }
      state = SessionUiState(
        bySessionId: Map<String, SessionUiEntry>.unmodifiable(nextEntries),
        optimisticallyArchivedIds: state.optimisticallyArchivedIds,
        ordering: ordering,
        missionControl: _reconcileMissionControlEntry(
          previous: state.missionControl,
          sessionId: sessionId,
          entry: nextEntries[sessionId],
        ),
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
    _fullComputeCount++;
    final stopwatch = Stopwatch()..start();
    // Zero-copy views — read synchronously only (see Sync.sessionsView).
    final sessions = sync.sessionsView;
    final usageBySession = sync.sessionUsageView;
    final span = _startScaleTrace(trigger, sessions.length);
    final bySessionId = <String, SessionUiEntry>{};
    final timestamps = <String, int?>{};
    final missionControlEntries = <String, MissionControlUiEntry>{};
    var changed = 0;
    for (final session in sessions.values) {
      final previous = previousState.bySessionId[session.id];
      final next = _computeEntry(
        session.id,
        previous,
        usageBySession[session.id],
      );
      bySessionId[session.id] = next;
      timestamps[session.id] = next.lastMessageTimestamp;
      final missionControlEntry = MissionControlUiEntry(
        lastMessageTimestamp: next.lastMessageTimestamp,
        unreadCount: next.unreadCount,
        lastMessageIsError: next.lastMessageIsError,
      );
      final previousMissionControlEntry =
          previousState.missionControl.bySessionId[session.id];
      missionControlEntries[session.id] =
          previousMissionControlEntry == missionControlEntry
          ? previousMissionControlEntry!
          : missionControlEntry;
      if (!identical(next, previous)) changed++;
    }
    changed +=
        previousState.bySessionId.length -
        previousState.bySessionId.keys.where(sessions.containsKey).length;

    _messageRevisions.removeWhere((id, _) => !sessions.containsKey(id));
    _hasUnsettledSend.removeWhere((id, _) => !sessions.containsKey(id));

    final optimisticallyArchivedIds = Set<String>.unmodifiable(
      sync.getOptimisticallyArchivedIds(),
    );
    final result = SessionUiState(
      bySessionId: Map.unmodifiable(bySessionId),
      optimisticallyArchivedIds: optimisticallyArchivedIds,
      ordering: SessionUiOrdering.reconcile(
        previous: previousState.ordering,
        timestamps: timestamps,
        optimisticallyArchivedIds: optimisticallyArchivedIds,
      ),
      missionControl: MissionControlUiProjection.reconcile(
        previous: previousState.missionControl,
        entries: missionControlEntries,
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
      lastMessageIsError: sync.getLastMessageIsError(sessionId),
      unreadCount: sync.getUnreadCount(sessionId),
      hasOlderMessages: sync.hasOlderMessages(sessionId),
      isLoadingOlderMessages: sync.isLoadingOlderMessages(sessionId),
      isSessionReadyForMessages: sync.isSessionReadyForMessages(sessionId),
      sessionUsage: immutableUsage,
      hasUnsettledSend: unsettled,
    );
    return previous == next ? previous! : next;
  }

  MissionControlUiProjection _reconcileMissionControlEntry({
    required MissionControlUiProjection previous,
    required String sessionId,
    required SessionUiEntry? entry,
  }) {
    final current = previous.bySessionId[sessionId];
    final next = entry == null
        ? null
        : MissionControlUiEntry(
            lastMessageTimestamp: entry.lastMessageTimestamp,
            unreadCount: entry.unreadCount,
            lastMessageIsError: entry.lastMessageIsError,
          );
    if (current == next &&
        (entry != null || !previous.bySessionId.containsKey(sessionId))) {
      return previous;
    }
    final entries = Map<String, MissionControlUiEntry>.from(
      previous.bySessionId,
    );
    if (next == null) {
      entries.remove(sessionId);
    } else {
      entries[sessionId] = next;
    }
    return MissionControlUiProjection.reconcile(
      previous: previous,
      entries: entries,
    );
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
