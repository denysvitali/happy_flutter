import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../api/api_client.dart';
import '../api/sessions_api.dart';
import '../encryption/encryption_manager.dart';
import '../models/session.dart';
import '../services/logger_service.dart';
import '../utils/invalidate_sync.dart';
import '../utils/sync_domain.dart';
import '../utils/wire_parsers.dart';
import 'sync_progress.dart';

/// Manages session state and session-related operations extracted from
/// the Sync god object as part of Phase 4b refactoring.
///
/// This class owns the in-memory session cache, session fetching,
/// encryption key management, presence timers, and optimistic archive
/// tracking. It delegates to callbacks for cross-cutting concerns
/// (data change notifications, message changes, permission requests)
/// to avoid circular dependencies with the Sync singleton.
class SessionManager {
  SessionManager({
    required Encryption encryption,
    required InvalidateSync Function() sessionsSyncGetter,
    required void Function(Set<SyncDomain>) onDataChanged,
    required void Function(String) onSessionMessagesChanged,
    required Future<void> Function(String sessionId, Uint8List? dataKey)
        ensureSessionEncryptionInitialized,
    required bool Function(Object) isTransientConnectionError,
    required Future<bool> Function(String sessionId) applyPermissionRequests,
    required void Function(Iterable<Session>) checkForNewPermissionRequests,
    void Function()? onFetchSessionsStarted,
    void Function(SyncProgress?)? onSyncProgress,
    void Function()? scheduleSaveSessionsCache,
  })  : _encryption = encryption,
        _sessionsSyncGetter = sessionsSyncGetter,
        _onDataChanged = onDataChanged,
        _onSessionMessagesChanged = onSessionMessagesChanged,
        _ensureSessionEncryptionInitialized =
            ensureSessionEncryptionInitialized,
        _isTransientConnectionError = isTransientConnectionError,
        _applyPermissionRequests = applyPermissionRequests,
        _checkForNewPermissionRequests = checkForNewPermissionRequests,
        _onSyncProgress = onSyncProgress,
        _scheduleSaveSessionsCache = scheduleSaveSessionsCache;

  // ── Dependencies ───────────────────────────────────────────────────────

  final Encryption _encryption;
  final InvalidateSync Function() _sessionsSyncGetter;
  final void Function(Set<SyncDomain>) _onDataChanged;
  final void Function(String) _onSessionMessagesChanged;
  final Future<void> Function(String sessionId, Uint8List? dataKey)
      _ensureSessionEncryptionInitialized;
  final bool Function(Object) _isTransientConnectionError;
  final Future<bool> Function(String sessionId) _applyPermissionRequests;
  final void Function(Iterable<Session>) _checkForNewPermissionRequests;
  final void Function(SyncProgress?)? _onSyncProgress;
  final void Function()? _scheduleSaveSessionsCache;

  // ── State ────────────────────────────────────────────────────────────

  Map<String, Session> _sessions = <String, Session>{};
  int? _lastSessionsFetchedAt;
  bool _forceFullFetchNext = false;
  final Set<String> _optimisticallyArchivedSessions = {};
  final Map<String, Timer> _presenceTimers = {};
  final Map<String, String> _sessionEncryptedDataKeys = {};
  final Set<String> _dekFallbackCaptured = {};
  Timer? _sessionsRefreshDebounceTimer;
  final Set<String> _pendingNewSessionIds = <String>{};

  // TODO(user): These are still managed by Sync but referenced here.
  // They will be passed in or moved as the refactor continues.
  // For now, we use late fields that will be set by Sync after construction.
  late final Map<String, List<Map<String, dynamic>>> _sessionMessages;
  late final void Function(String sessionId) _onSessionDeleted;

  /// Bind late dependencies that still live on Sync. Called once by Sync
  /// after constructing this manager.
  void bindLateDependencies({
    required Map<String, List<Map<String, dynamic>>> sessionMessages,
    required void Function(String sessionId) onSessionDeleted,
  }) {
    _sessionMessages = sessionMessages;
    _onSessionDeleted = onSessionDeleted;
  }

  // ── Constants ────────────────────────────────────────────────────────

  static const Duration _sessionsRefreshDebounce = Duration(seconds: 2);

  // ── Public API ───────────────────────────────────────────────────────

  Map<String, Session> get sessions => Map.unmodifiable(_sessions);

  int? lastSessionsFetchedAt;

  bool forceFullFetchNext = false;

  Set<String> get pendingNewSessionIds => _pendingNewSessionIds;

  Map<String, String> get sessionEncryptedDataKeys =>
      Map.unmodifiable(_sessionEncryptedDataKeys);

  /// Mark a session as optimistically archived.
  void markSessionArchived(String sessionId) {
    _optimisticallyArchivedSessions.add(sessionId);
    _onDataChanged({SyncDomain.sessions});
  }

  /// Mark a session as optimistically unarchived.
  void markSessionUnarchived(String sessionId) {
    _optimisticallyArchivedSessions.remove(sessionId);
    _onDataChanged({SyncDomain.sessions});
  }

  /// Returns whether a session is optimistically archived.
  bool isSessionOptimisticallyArchived(String sessionId) {
    return _optimisticallyArchivedSessions.contains(sessionId);
  }

  /// Returns a copy of all optimistically archived session IDs.
  Set<String> getOptimisticallyArchivedIds() {
    return Set<String>.from(_optimisticallyArchivedSessions);
  }

  /// Refresh sessions from server via InvalidateSync.
  Future<void> refreshSessions() async {
    await _sessionsSyncGetter().invalidateAndAwait();
  }

  /// Refreshes session-list domain syncs in one bounded operation.
  ///
  /// `sessions` is always refreshed. `machines` is optional and
  /// intentionally deferred to avoid competing with the first session paint.
  Future<void> refreshSessionsListData({
    required InvalidateSync machinesSync,
    bool includeMachines = false,
    bool deferMachineRefresh = true,
  }) {
    final inFlight = _sessionListRefreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final futures = <Future<void>>[_sessionsSyncGetter().invalidateAndAwait()];
    if (includeMachines) {
      if (deferMachineRefresh) {
        futures.add(
          Future<void>.delayed(
            const Duration(milliseconds: 800),
            () => machinesSync.invalidateAndAwait(),
          ),
        );
      } else {
        futures.add(machinesSync.invalidateAndAwait());
      }
    }

    final task = Future.wait(futures).whenComplete(() {
      _sessionListRefreshInFlight = null;
    });

    _sessionListRefreshInFlight = task;
    return task;
  }

  Future<void>? _sessionListRefreshInFlight;

  /// Schedule a debounced sessions refresh.
  void scheduleSessionsRefresh() {
    _sessionsRefreshDebounceTimer?.cancel();
    _sessionsRefreshDebounceTimer = Timer(
      _sessionsRefreshDebounce,
      () => unawaited(_flushScheduledSessionsRefresh()),
    );
  }

  /// Flush any pending debounced sessions refresh.
  Future<void> flushScheduledSessionsRefresh() async {
    return _flushScheduledSessionsRefresh();
  }

  Future<void> _flushScheduledSessionsRefresh() async {
    _sessionsRefreshDebounceTimer?.cancel();
    _sessionsRefreshDebounceTimer = null;

    await _sessionsSyncGetter().invalidateAndAwait();

    if (_pendingNewSessionIds.isEmpty) {
      return;
    }

    final sessionIdsNeedingFullFetch = _pendingNewSessionIds
        .where(
          (sessionId) => _encryption.getSessionEncryption(sessionId) == null,
        )
        .toList();
    _pendingNewSessionIds.clear();

    if (sessionIdsNeedingFullFetch.isEmpty) {
      return;
    }

    // A newly created session can miss the first delta fetch due to clock
    // skew or replication lag. Retry once with a full fetch so its encryption
    // key is initialized before the user opens it.
    _forceFullFetchNext = true;
    await _sessionsSyncGetter().invalidateAndAwait();
  }

  /// Delete a session by ID.
  Future<bool> deleteSession(String sessionId) async {
    try {
      final api = ApiClient();
      final response = await api.delete('/v1/sessions/$sessionId');
      if (!api.isSuccess(response)) {
        return false;
      }

      _handleDeleteSession(<String, dynamic>{'sid': sessionId});
      return true;
    } catch (error, stack) {
      logger.error('Failed to delete session $sessionId', error, stack);
      return false;
    }
  }

  /// Handle a session deletion event (from socket or local API call).
  void _handleDeleteSession(Map<String, dynamic> data) {
    final sessionId = data['sid'] as String?;
    if (sessionId == null) return;

    _presenceTimers.remove(sessionId)?.cancel();
    _sessionEncryptedDataKeys.remove(sessionId);
    _optimisticallyArchivedSessions.remove(sessionId);
    _sessions.remove(sessionId);
    _onSessionDeleted(sessionId);
    _onDataChanged({SyncDomain.sessions});
  }

  /// Fetch sessions from server, decrypt, and merge into local cache.
  Future<void> fetchSessions() async {
    logger.info('Fetching sessions...');

    final fetchStartMs = DateTime.now().millisecondsSinceEpoch;
    final forceFullFetch = _forceFullFetchNext;
    if (forceFullFetch) _forceFullFetchNext = false;
    final changedSince = forceFullFetch ? null : _lastSessionsFetchedAt;
    var showedConversationProgress = false;

    try {
      final apiClient = ApiClient();
      final allSessions = await SessionsApi(
        client: apiClient,
      ).fetchSessions(limit: 50, changedSince: changedSince);

      if (logger.shouldLog(LogLevel.info)) {
        logger.info(
          'fetchSessions: received ${allSessions.length} sessions '
          '(changedSince=$changedSince)',
        );
      }
      if (allSessions.isNotEmpty) {
        showedConversationProgress = true;
        _onSyncProgress?.call(
          SyncProgress(
            label: 'Fetching conversations',
            completed: 0,
            total: allSessions.length,
          ),
        );
      }

      if (allSessions.isEmpty) {
        if (changedSince != null) {
          // Delta fetch with no changes -- update timestamp and return.
          _lastSessionsFetchedAt = fetchStartMs;
          _scheduleSaveSessionsCache?.call();
          logger.info('fetchSessions: no changes since delta fetch');
        } else {
          logger.warning(
            'fetchSessions: full fetch returned 0 sessions -- '
            'possible auth/server issue',
          );
        }
        return;
      }

      final sessionKeys = <String, Uint8List?>{};

      final sessionDecryptTasks =
          <({String sessionId, String dataEncryptionKey})>[];
      for (final session in allSessions) {
        if (session is! Map<String, dynamic>) {
          logger.warning(
            'Skipping session with invalid payload type',
            'Session data: $session',
          );
          continue;
        }

        final sessionId = WireParsers.parseString(session['id']);
        if (sessionId == null || sessionId.isEmpty) {
          logger.warning(
            'Skipping session with missing/empty ID',
            'Session data: $session',
          );
          continue;
        }

        final dataEncryptionKey = WireParsers.parseString(
          session['dataEncryptionKey'],
        );

        if (dataEncryptionKey != null) {
          _sessionEncryptedDataKeys[sessionId] = dataEncryptionKey;
          sessionDecryptTasks.add((
            sessionId: sessionId,
            dataEncryptionKey: dataEncryptionKey,
          ));
        } else {
          _sessionEncryptedDataKeys.remove(sessionId);
          sessionKeys[sessionId] = null;
        }
      }

      if (sessionDecryptTasks.isNotEmpty) {
        final decryptedKeys = await Future.wait(
          sessionDecryptTasks.map(
            (t) => _encryption
                .decryptEncryptionKey(t.dataEncryptionKey)
                .catchError((Object e) {
                  if (logger.shouldLog(LogLevel.info)) {
                    logger.info(
                      '[Encryption] DEK decryption threw for session '
                      '${t.sessionId}: $e '
                      '-- falling back to legacy encryption.',
                    );
                  }
                  return null;
                }),
          ),
        );

        for (var i = 0; i < sessionDecryptTasks.length; i++) {
          final sessionId = sessionDecryptTasks[i].sessionId;
          final decryptedKey = decryptedKeys[i];
          if (decryptedKey != null) {
            sessionKeys[sessionId] = decryptedKey;
          } else {
            logger.warning(
              '[Encryption] DEK decryption failed for session '
              '$sessionId (returned null) -- falling back to legacy '
              'encryption. Run `happy auth debug` and test the printed '
              'vector in Flutter to confirm key mismatch.',
            );
            if (_dekFallbackCaptured.add(sessionId)) {
              unawaited(
                Sentry.captureMessage(
                  '[Encryption] DEK decryption failed — legacy fallback',
                  level: SentryLevel.warning,
                  withScope: (scope) {
                    scope.setTag('dek_fallback_session', sessionId);
                  },
                ),
              );
            }
            sessionKeys[sessionId] = null;
          }
        }
      }

      // Parallelize the per-session encryptor open.
      await Future.wait(
        sessionKeys.entries.map(
          (e) => _ensureSessionEncryptionInitialized(e.key, e.value),
        ),
      );

      // Pre-decrypt metadata + agentState for every session concurrently
      final preDecryptStartMs = DateTime.now().millisecondsSinceEpoch;
      final preDecrypted = await _preDecryptSessions(allSessions);
      final preDecryptMs =
          DateTime.now().millisecondsSinceEpoch - preDecryptStartMs;
      if (allSessions.length > 1 && logger.shouldLog(LogLevel.info)) {
        logger.info(
          '[fetchSessions] Pre-decrypted ${preDecrypted.length} '
          'sessions in ${preDecryptMs}ms',
        );
      }

      final decryptedSessions = <Session>[];
      for (var i = 0; i < allSessions.length; i++) {
        if (i == 0 || (i + 1) % 10 == 0 || i == allSessions.length - 1) {
          _onSyncProgress?.call(
            SyncProgress(
              label: 'Fetching conversations',
              completed: i + 1,
              total: allSessions.length,
            ),
          );
        }
        final session = allSessions[i];

        if (session is! Map<String, dynamic>) {
          logger.warning(
            'Skipping session with invalid payload type',
            'Session data: $session',
          );
          continue;
        }

        final sessionId = WireParsers.parseString(session['id']);
        if (sessionId == null || sessionId.isEmpty) {
          logger.warning(
            'Skipping session with missing/empty ID',
            'Session data: $session',
          );
          continue;
        }

        try {
          final existing = _sessions[sessionId];
          final seq = _asSessionInt(session['seq']) ?? existing?.seq ?? 0;
          final createdAt =
              _asSessionInt(session['createdAt']) ?? existing?.createdAt ?? 0;
          final updatedAt =
              _asSessionInt(session['updatedAt']) ?? existing?.updatedAt ?? 0;
          final active =
              _asSessionBool(session['active']) ?? existing?.active ?? false;
          final now = DateTime.now().millisecondsSinceEpoch;
          final activeAt =
              _clampTimestampToNow(_asSessionInt(session['activeAt']), now) ??
              existing?.activeAt ??
              0;
          final metadataVersion =
              _asSessionInt(session['metadataVersion']) ?? 0;
          final agentStateVersion =
              _asSessionInt(session['agentStateVersion']) ?? 0;
          final lastSeq = max(
            _asSessionInt(session['lastSeq']) ?? 0,
            _sessions[sessionId]?.lastSeq ?? 0,
          );

          final wireLastMessage = session['lastMessage'];
          int? lastMessageAt;
          if (wireLastMessage is Map) {
            final created = _asSessionInt(wireLastMessage['createdAt']);
            if (created != null) lastMessageAt = created;
          }
          final existingLm = existing?.lastMessageAt;
          if (existingLm != null &&
              (lastMessageAt == null || existingLm > lastMessageAt)) {
            lastMessageAt = existingLm;
          }

          final pre = preDecrypted[sessionId];
          final metadata = pre?.metadata;
          final agentState = pre?.agentState;

          Metadata? parsedMetadata;
          if (metadata != null) {
            try {
              parsedMetadata = Metadata.fromJson(metadata);
            } catch (e) {
              logger.warning(
                'Failed to parse session metadata for $sessionId',
                e,
              );
            }
          }

          AgentState? parsedAgentState;
          if (agentState != null && agentState.isNotEmpty) {
            try {
              parsedAgentState = AgentState.fromJson(agentState);
            } catch (e) {
              logger.warning(
                'Failed to parse session agentState for $sessionId',
                e,
              );
            }
          }

          final processedSession = Session(
            id: sessionId,
            seq: seq,
            createdAt: createdAt,
            updatedAt: updatedAt,
            active: active,
            activeAt: activeAt,
            archived: _asSessionBool(session['archived']) ?? false,
            metadata: parsedMetadata,
            metadataVersion: metadataVersion,
            agentState: parsedAgentState,
            agentStateVersion: agentStateVersion,
            thinking: false,
            thinkingAt: null,
            presence:
                _sessions[sessionId]?.presence ??
                (active &&
                        DateTime.now().millisecondsSinceEpoch - activeAt <
                            60000
                    ? 'online'
                    : 'offline'),
            lastSeq: lastSeq,
            lastMessageAt: lastMessageAt,
          );

          decryptedSessions.add(processedSession);
        } catch (error) {
          logger.error('Failed to process session $sessionId', error);
        }
      }

      if (changedSince == null) {
        // Full fetch: selectively cancel presence timers.
        final newSessions = Map<String, Session>.fromEntries(
          decryptedSessions.map((s) => MapEntry(s.id, s)),
        );

        // TODO(user): _sessionSpawnedAt is still on Sync. We need a
        // callback or to move it here. For now, preserve all existing
        // sessions that are not in the new map (Sync handles spawn tracking).
        _sessions = newSessions;

        // Cancel timers for sessions that were removed or went offline.
        final staleTimerIds = <String>[];
        for (final entry in _presenceTimers.entries) {
          final newSession = newSessions[entry.key];
          if (newSession == null || newSession.presence != 'online') {
            entry.value.cancel();
            staleTimerIds.add(entry.key);
          }
        }
        for (final id in staleTimerIds) {
          _presenceTimers.remove(id);
        }
      } else {
        // Delta fetch: merge updated sessions, cancel their stale timers.
        for (final session in decryptedSessions) {
          _sessions[session.id] = session;
          _presenceTimers.remove(session.id)?.cancel();
        }
      }

      // Clear optimistic archive flags for sessions that the server has
      // confirmed as archived or inactive.
      for (final session in decryptedSessions) {
        if (session.archived || !session.active) {
          _optimisticallyArchivedSessions.remove(session.id);
        }
      }
      // On full fetch, clear any optimistic archives for sessions not in
      // the response (deleted or truly archived on server).
      if (changedSince == null) {
        _optimisticallyArchivedSessions.removeWhere(
          (sessionId) => !_sessions.containsKey(sessionId),
        );
      }

      // Start 60 s staleness timers for sessions that came back 'online'.
      for (final s in decryptedSessions) {
        if (s.presence == 'online' && !_presenceTimers.containsKey(s.id)) {
          _presenceTimers[s.id] = Timer(const Duration(seconds: 60), () {
            _presenceTimers.remove(s.id);
            final current = _sessions[s.id];
            if (current != null && current.presence == 'online') {
              _sessions[s.id] = current.copyWith(
                presence: 'offline',
                thinking: false,
              );
              _onDataChanged({SyncDomain.sessions});
            }
          });
        }
      }

      // Re-apply permission data only for sessions that changed.
      for (final session in decryptedSessions) {
        if (_sessionMessages.containsKey(session.id)) {
          final messagesChanged = await _applyPermissionRequests(session.id);
          if (messagesChanged) {
            _onSessionMessagesChanged(session.id);
          }
        }
      }

      // Fire local notifications for any new permission requests.
      _checkForNewPermissionRequests(decryptedSessions);

      logger.info('Fetched and decrypted ${decryptedSessions.length} sessions');
      _lastSessionsFetchedAt = fetchStartMs;
      _scheduleSaveSessionsCache?.call();
      _onDataChanged({SyncDomain.sessions});
    } on DioException {
      rethrow;
    } catch (error, stack) {
      if (error is SessionsApiException ||
          _isTransientConnectionError(error)) {
        logger.warning('Error fetching sessions', error, stack);
      } else {
        logger.error('Error fetching sessions', error, stack);
      }
    } finally {
      if (showedConversationProgress) {
        _onSyncProgress?.call(null);
      }
    }
  }

  /// Fetch a single session by ID from the server, decrypt it, and add it
  /// to the local cache. Returns the session if found, or null otherwise.
  Future<Session?> fetchSingleSession(String sessionId) async {
    try {
      final apiClient = ApiClient();
      final raw = await SessionsApi(
        client: apiClient,
      ).fetchSessionById(sessionId);
      if (raw == null) return null;

      final dataEncryptionKey = WireParsers.parseString(
        raw['dataEncryptionKey'],
      );
      Uint8List? sessionKey;
      if (dataEncryptionKey != null) {
        _sessionEncryptedDataKeys[sessionId] = dataEncryptionKey;
        try {
          sessionKey = await _encryption.decryptEncryptionKey(
            dataEncryptionKey,
          );
        } catch (e) {
          logger.info(
            '[Encryption] DEK decryption threw for single session '
            '$sessionId: $e -- falling back to legacy encryption.',
          );
        }
      } else {
        _sessionEncryptedDataKeys.remove(sessionId);
      }
      await _ensureSessionEncryptionInitialized(sessionId, sessionKey);

      final sessionEncryption = _encryption.getSessionEncryption(sessionId);

      final metadataVersion = _asSessionInt(raw['metadataVersion']) ?? 0;
      final agentStateVersion = _asSessionInt(raw['agentStateVersion']) ?? 0;

      Map<String, dynamic>? metadata;
      Map<String, dynamic>? agentState;
      if (sessionEncryption != null) {
        try {
          metadata = await sessionEncryption.decryptMetadata(
            metadataVersion,
            WireParsers.parseString(raw['metadata']) ?? '',
          );
        } catch (e) {
          logger.warning('fetchSingleSession: decrypt metadata failed', e);
        }
        try {
          agentState = await sessionEncryption.decryptAgentState(
            agentStateVersion,
            WireParsers.parseString(raw['agentState']),
          );
        } catch (e) {
          logger.warning('fetchSingleSession: decrypt agentState failed', e);
        }
      }

      Metadata? parsedMetadata;
      if (metadata != null) {
        try {
          parsedMetadata = Metadata.fromJson(metadata);
        } catch (e) {
          logger.warning(
            'fetchSingleSession: parse metadata failed '
            'for $sessionId',
            e,
          );
        }
      }

      AgentState? parsedAgentState;
      if (agentState != null && agentState.isNotEmpty) {
        try {
          parsedAgentState = AgentState.fromJson(agentState);
        } catch (e) {
          logger.warning(
            'fetchSingleSession: parse agentState failed '
            'for $sessionId',
            e,
          );
        }
      }

      final existing = _sessions[sessionId];
      final session = Session(
        id: sessionId,
        seq: _asSessionInt(raw['seq']) ?? existing?.seq ?? 0,
        createdAt: _asSessionInt(raw['createdAt']) ?? existing?.createdAt ?? 0,
        updatedAt: _asSessionInt(raw['updatedAt']) ?? existing?.updatedAt ?? 0,
        active: _asSessionBool(raw['active']) ?? existing?.active ?? false,
        archived:
            _asSessionBool(raw['archived']) ?? existing?.archived ?? false,
        activeAt:
            _clampTimestampToNow(
              _asSessionInt(raw['activeAt']),
              DateTime.now().millisecondsSinceEpoch,
            ) ??
            existing?.activeAt ??
            0,
        metadata: parsedMetadata,
        metadataVersion: metadataVersion,
        agentState: parsedAgentState,
        agentStateVersion: agentStateVersion,
        thinking: false,
        presence: _sessions[sessionId]?.presence ?? 'offline',
        lastSeq: max(
          _asSessionInt(raw['lastSeq']) ?? 0,
          _sessions[sessionId]?.lastSeq ?? 0,
        ),
        lastMessageAt: () {
          final wireLastMessage = raw['lastMessage'];
          int? lm;
          if (wireLastMessage is Map) {
            lm = _asSessionInt(wireLastMessage['createdAt']);
          }
          final existingLm = existing?.lastMessageAt;
          if (existingLm != null && (lm == null || existingLm > lm)) {
            return existingLm;
          }
          return lm;
        }(),
      );

      _sessions[sessionId] = session;
      _onDataChanged({SyncDomain.sessions});
      _scheduleSaveSessionsCache?.call();
      return session;
    } catch (error, stack) {
      if (error is SessionsApiException ||
          _isTransientConnectionError(error)) {
        logger.warning(
          'fetchSingleSession failed for $sessionId',
          error,
          stack,
        );
      } else {
        logger.error('fetchSingleSession failed for $sessionId', error, stack);
      }
      return null;
    }
  }

  // ── Internal helpers ─────────────────────────────────────────────────

  /// Decrypt every session's `metadata` + `agentState` concurrently.
  Future<Map<String, _DecryptedSessionContent>> _preDecryptSessions(
    List<dynamic> allSessions,
  ) async {
    final tasks = <Future<MapEntry<String, _DecryptedSessionContent>?>>[];
    for (final raw in allSessions) {
      if (raw is! Map<String, dynamic>) continue;
      final sessionId = WireParsers.parseString(raw['id']);
      if (sessionId == null || sessionId.isEmpty) continue;
      final sessionEncryption = _encryption.getSessionEncryption(sessionId);
      if (sessionEncryption == null) continue;
      final metadataVersion = _asSessionInt(raw['metadataVersion']) ?? 0;
      final agentStateVersion = _asSessionInt(raw['agentStateVersion']) ?? 0;
      final metadataCipher = WireParsers.parseString(raw['metadata']) ?? '';
      final agentStateCipher = WireParsers.parseString(raw['agentState']);
      tasks.add(() async {
        Future<Map<String, dynamic>?> metadataFuture;
        Future<Map<String, dynamic>> agentStateFuture;
        try {
          metadataFuture = sessionEncryption.decryptMetadata(
            metadataVersion,
            metadataCipher,
          );
        } catch (e) {
          logger.warning(
            'Failed to start session metadata decrypt for $sessionId',
            e,
          );
          metadataFuture = Future<Map<String, dynamic>?>.value(null);
        }
        try {
          agentStateFuture = sessionEncryption.decryptAgentState(
            agentStateVersion,
            agentStateCipher,
          );
        } catch (e) {
          logger.warning(
            'Failed to start session agentState decrypt for $sessionId',
            e,
          );
          agentStateFuture = Future<Map<String, dynamic>>.value({});
        }
        Map<String, dynamic>? metadata;
        Map<String, dynamic>? agentState;
        try {
          metadata = await metadataFuture;
        } catch (e) {
          logger.warning(
            'Failed to decrypt session metadata for $sessionId',
            e,
          );
        }
        try {
          agentState = await agentStateFuture;
        } catch (e) {
          logger.warning(
            'Failed to decrypt session agentState for $sessionId',
            e,
          );
        }
        return MapEntry(
          sessionId,
          _DecryptedSessionContent(metadata: metadata, agentState: agentState),
        );
      }());
    }
    final results = await Future.wait(tasks);
    final map = <String, _DecryptedSessionContent>{};
    for (final entry in results) {
      if (entry == null) continue;
      map[entry.key] = entry.value;
    }
    return map;
  }

  // ── Static helpers (copied from Sync) ────────────────────────────────

  static int? _asSessionInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return null;
  }

  static bool? _asSessionBool(dynamic value) {
    if (value is bool) return value;
    return null;
  }

  static int? _clampTimestampToNow(int? timestamp, int now) {
    if (timestamp == null) return null;
    if (timestamp > now) return now;
    return timestamp;
  }
}

/// Decrypted bundle for one session — output of [_preDecryptSessions].
class _DecryptedSessionContent {
  const _DecryptedSessionContent({
    required this.metadata,
    required this.agentState,
  });

  final Map<String, dynamic>? metadata;
  final Map<String, dynamic>? agentState;
}
