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
import '../services/sync_service.dart';

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
    if (!optimisticallyArchivedIds
        .containsAll(other.optimisticallyArchivedIds)) {
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
    Object.hashAll(
      bySessionId.entries.map((e) => Object.hash(e.key, e.value)),
    ),
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

  @override
  SessionUiState build() {
    // Compute the initial state eagerly when the notifier is first read,
    // so consumers never see an empty cache on their first frame. Further
    // updates are driven by [loadFromSync] from sync-subscription callbacks.
    if (!sync.isInitialized) return SessionUiState.empty;
    return _computeFromSync();
  }

  /// Reload derived UI state from `sync` if any of the watched counters
  /// changed since the last call. Idempotent: safe to call from every
  /// `onDataChanged` / `onDomainChanged` callback.
  void loadFromSync() {
    if (!sync.isInitialized) return;

    final dataCounter = sync.dataChangeCounter;
    final sessionsDomainCounter =
        sync.domainChangeCounter(SyncDomain.sessions);
    final messagesDomainCounter =
        sync.domainChangeCounter(SyncDomain.messages);

    if (dataCounter == _lastDataChangeCounter &&
        sessionsDomainCounter == _lastSessionsDomainCounter &&
        messagesDomainCounter == _lastMessagesDomainCounter) {
      return;
    }
    _lastDataChangeCounter = dataCounter;
    _lastSessionsDomainCounter = sessionsDomainCounter;
    _lastMessagesDomainCounter = messagesDomainCounter;

    state = _computeFromSync();
  }

  SessionUiState _computeFromSync() {
    final bySessionId = <String, SessionUiEntry>{};
    for (final session in sync.sessions.values) {
      final messages = sync.messagesForSession(session.id);
      bySessionId[session.id] = SessionUiEntry(
        lastMessageTimestamp: sync.getLastMessageTimestamp(session.id),
        lastMessagePreview: sync.getLastMessagePreview(session.id),
        lastMessageRole: sync.getLastMessageRole(session.id),
        unreadCount: sync.getUnreadCount(session.id),
        hasOlderMessages: sync.hasOlderMessages(session.id),
        isLoadingOlderMessages: sync.isLoadingOlderMessages(session.id),
        isSessionReadyForMessages: sync.isSessionReadyForMessages(session.id),
        sessionUsage: Map<String, dynamic>.unmodifiable(
          sync.sessionUsage[session.id] ?? const <String, dynamic>{},
        ),
        hasUnsettledSend: AutoArchiveService.hasUnsettledSend(messages),
      );
    }
    return SessionUiState(
      bySessionId: Map.unmodifiable(bySessionId),
      optimisticallyArchivedIds: Set<String>.unmodifiable(
        sync.getOptimisticallyArchivedIds(),
      ),
    );
  }

  /// Clear all derived UI state. Called on logout via the standard
  /// `AuthStateNotifier.clear()` cascade.
  void clear() {
    _lastDataChangeCounter = -1;
    _lastSessionsDomainCounter = -1;
    _lastMessagesDomainCounter = -1;
    state = SessionUiState.empty;
  }
}

final sessionUiStateNotifierProvider =
    NotifierProvider<SessionUiStateNotifier, SessionUiState>(() {
      return SessionUiStateNotifier();
    });
