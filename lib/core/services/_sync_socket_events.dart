part of 'sync_service.dart';

/// Extract the update type from a socket payload, matching the fallback
/// order in `ApiUpdate.fromJson` (`lib/core/models/api_update.dart`):
///   1. `payload['body']['t']`  (wrapped server format)
///   2. `payload['t']`         (flat Socket.IO event data)
///   3. `payload['type']`      (legacy / unknown)
///   4. `'unknown'`            (final fallback)
String? _extractUpdateType(Map<String, dynamic> payload) {
  final body = payload['body'];
  if (body is Map) {
    final t = body['t'];
    if (t is String && t.isNotEmpty) return t;
  }
  final topT = payload['t'];
  if (topT is String && topT.isNotEmpty) return topT;
  final legacyType = payload['type'];
  if (legacyType is String && legacyType.isNotEmpty) return legacyType;
  return 'unknown';
}

extension SyncSocketEvents on Sync {
  bool _shouldRunReconnectGlobalInvalidation(
    int nowMs, {
    required bool resumeHttpFallbackRecentlyFired,
  }) {
    if (resumeHttpFallbackRecentlyFired) return false;
    if (_forceFullFetchNext) return true;

    final lastRunMs = _lastInvalidateAllSyncsAtMs;
    return lastRunMs == null ||
        nowMs - lastRunMs >= Sync._reconnectGlobalInvalidationCooldownMs;
  }

  /// Subscribe to socket updates
  void subscribeToUpdates() {
    _unsubscribeSocketUpdate?.call();
    _unsubscribeSocketEphemeral?.call();
    _unsubscribeSocketError?.call();
    _unsubscribeSocketReconnected?.call();
    _unsubscribeSocketStatus?.call();

    _unsubscribeSocketUpdate = socketIoClient.onMessage('update', handleUpdate);
    _unsubscribeSocketEphemeral = socketIoClient.onMessage(
      'ephemeral',
      handleEphemeralUpdate,
    );
    _unsubscribeSocketError = socketIoClient.onMessage(
      'error',
      _handleErrorEvent,
    );
    _unsubscribeSocketReconnected = socketIoClient.onReconnected(() {
      logger.info('Socket reconnected');
      // Cancel reconnect watchdog — connection succeeded.
      _reconnectWatchdogTimer?.cancel();
      _reconnectWatchdogTimer = null;
      // A reconnect may be due to a daemon upgrade that now supports
      // workflow-list. Clear the capability block so the next refresh
      // re-probes instead of silently skipping.
      _workflowListUnsupportedCapabilities.clear();
      // Snapshot the visible session's cursor BEFORE any new socket
      // events are processed.  Inline processing of post-reconnect
      // events can advance the cursor past the disconnect gap,
      // causing the reconnection fetch to skip messages that arrived
      // while the socket was down.
      if (_visibleSessionId != null) {
        _reconnectCursorSnapshot = _sessionLastSeq[_visibleSessionId] ?? 0;
      }
      // A reconnect means the local session catalog can be stale, but
      // repeated broad catalog refreshes are expensive. Keep the visible
      // message recovery below on every reconnect, and throttle only the
      // global sessions/catalog recovery path.
      final reconnectNowMs = DateTime.now().millisecondsSinceEpoch;
      final resumeHttpFallbackRecentlyFired =
          _lastResumeHttpFallbackAtMs != null &&
          reconnectNowMs - _lastResumeHttpFallbackAtMs! < 3000;
      // Reconnects are the single highest-volume anomaly in production
      // (~173/day). Which recovery branch each one takes is the grouping
      // that makes them actionable, so record it as a bounded reason.
      final String reconnectReason;
      if (resumeHttpFallbackRecentlyFired) {
        reconnectReason = 'resume_http_fallback';
        logger.debug(
          '[Sync] skipping reconnect global invalidation; '
          'resume HTTP fallback already refreshed sessions',
        );
      } else if (_shouldRunReconnectGlobalInvalidation(
        reconnectNowMs,
        resumeHttpFallbackRecentlyFired: resumeHttpFallbackRecentlyFired,
      )) {
        reconnectReason = _forceFullFetchNext
            ? 'forced_full_fetch'
            : 'global_invalidation';
        _invalidateAllSyncs(force: true);
      } else {
        reconnectReason = 'cooldown_throttled';
        logger.debug(
          '[Sync] skipping reconnect global invalidation; '
          'recent sessions recovery already ran',
        );
      }
      OpenTelemetryService().recordCount(
        'app.socket.reconnects',
        attributes: {
          'reason': reconnectReason,
          // A reconnect that needed no catch-up work is transient churn;
          // one that triggered a full refresh cost the user real latency.
          'transient':
              reconnectReason != 'global_invalidation' &&
              reconnectReason != 'forced_full_fetch',
          'current_route':
              PerformanceContextService().currentRoute ?? 'unknown',
        },
        description: 'Socket reconnects, by the recovery path they took',
      );
      // Refresh _lastEphemeralAt for all sessions that show as online.
      // Without this, stale timestamps from before the disconnect cause
      // looksReady to return false and trigger unnecessary auto-restore.
      // After a reconnect the daemon's ephemeral events will update the
      // timestamps with fresh values; the 90s threshold provides a safety
      // window so we don't falsely trigger auto-restore for live sessions.
      for (final entry in _sessions.entries) {
        if (entry.value.isOnline) {
          _lastEphemeralAt[entry.key] = DateTime.now().millisecondsSinceEpoch;
        }
      }
      // Re-fetch messages for non-visible sessions where the server may have
      // advanced past our local cursor.  Sessions where serverLastSeq
      // equals cursorSeq are caught up (no gap); sessions where both are
      // 0 are empty/new and don't need fetching.  This avoids both the
      // infinite reconnect-loop caused by unconditionally re-adding ALL
      // sessions, and the message-loss from not re-adding at all.
      //
      // Debounce the enumeration to prevent re-adding all sessions on
      // rapid reconnect cycling — each reconnect can re-queue dozens of
      // pending message fetches that cascade into HTTP storms.
      if (_lastReconnectSessionEnumerationMs == null ||
          reconnectNowMs - _lastReconnectSessionEnumerationMs! >= 5000) {
        _lastReconnectSessionEnumerationMs = reconnectNowMs;
        for (final sessionId in _sessionMessages.keys) {
          if (sessionId == _visibleSessionId) continue;
          final cursorSeq = _sessionLastSeq[sessionId] ?? 0;
          final serverLastSeq = _sessions[sessionId]?.lastSeq ?? 0;
          if (serverLastSeq > cursorSeq && serverLastSeq > 0) {
            _sessionsWithPendingSocketMessages.add(sessionId);
          }
        }
      } else {
        logger.debug(
          '[Sync] skipping reconnect session enumeration (5s debounce)',
        );
      }
      // Chain messages fetch after the sessions fetch that
      // _invalidateAllSyncs() already kicked off.  We await the
      // existing queue instead of calling invalidateAndAwait()
      // again, which would start a SECOND HTTP fetch cycle and
      // was the primary cause of the N+1 sessions problem
      // (~12 fetches per app load).
      //
      // Chain a forced message fetch after the sessions fetch.
      // Set the fetch-probe flag INSIDE the .then() callback — not
      // before — so it isn't consumed by the resume timer's earlier
      // chained fetch (which also awaits sessionsSync.awaitQueue()).
      // The probe bypasses fetchMessages' "already caught up" skip
      // even when the delta sessions fetch returned nothing and
      // serverLastSeq is still stale.
      if (_visibleSessionId != null && !resumeHttpFallbackRecentlyFired) {
        unawaited(
          sessionsSync.awaitQueue().then((_) {
            // Snapshot once: `_visibleSessionId` can be cleared by a
            // delete-session event or chat-dispose between the null
            // check and the `!`, even though those happen in the same
            // turn — the `.then()` callback runs after an await gap so
            // any code that mutated `_visibleSessionId` while the
            // sessions fetch was in flight has already landed.
            final vid = _visibleSessionId;
            if (vid != null) {
              _sessionsNeedingFetchProbe.add(vid);
              messagesSync[vid]?.invalidate();
            }
          }),
        );
      }
    });
    _unsubscribeSocketReconnectExhausted?.call();
    _unsubscribeSocketReconnectExhausted = socketIoClient.onReconnectExhausted(
      () {
        logger.warning(
          '[Sync] socket reconnection attempts exhausted — '
          'scheduling fresh reconnect in '
          '${Sync._reconnectWatchdogDelayMs}ms',
        );
        _scheduleReconnectWatchdog();
      },
    );
    _unsubscribeSocketStatus = socketIoClient.onStatusChange((status) {
      _connectionStatus = status;
    });
  }

  /// Handle incoming updates
  Future<void> handleUpdate(dynamic data) async {
    final payload = _normalizeSocketPayload(data, handlerName: 'handleUpdate');
    if (payload == null) {
      return;
    }

    // Wrap each socket event in an OTel span. Parent under the
    // currently-active span (typically chat.send_message) so the
    // downstream sync.on_data_changed and subagent.spawn spans chain
    // naturally in the trace. The type field is the strongest filter
    // for new-message storms; we record it as an attribute rather than
    // branching so the span exists for every event.
    // Compute the real update type using the same fallback order as
    // ApiUpdate.fromJson (body.t -> payload.t -> payload.type -> 'unknown').
    // Previously this read payload['type'] directly, which the server never
    // sends on the update channel — every span was tagged event.type=unknown
    // and Jaeger queries for new-message storms couldn't filter on it.
    final updateType = _extractUpdateType(payload);
    final activeSpan = OpenTelemetryService().currentSpan;
    final socketSpan = activeSpan != null
        ? OpenTelemetryService().startChildSpan(
            'socket.event',
            parent: activeSpan,
            kind: SpanKind.consumer,
            attributes: {
              'event.type': updateType,
              if (payload['sid'] is String)
                'session.id': payload['sid'] as String,
              if (payload['id'] is String) 'entity.id': payload['id'] as String,
            },
          )
        : OpenTelemetryService().startTrace(
            'socket.event',
            kind: SpanKind.consumer,
            attributes: {
              'event.type': updateType,
              if (payload['sid'] is String)
                'session.id': payload['sid'] as String,
              if (payload['id'] is String) 'entity.id': payload['id'] as String,
            },
          );
    var handlerFailed = false;
    Future<void> processUpdate() async {
      ApiUpdate? update;
      try {
        update = ApiUpdate.fromJson(payload);

        // Skip Sentry breadcrumbs for high-frequency streaming events.
        // new-message arrives at 10-50/sec during AI responses — recording
        // each one floods Sentry's ring buffer and wastes allocations.
        if (update.type != 'new-message') {
          unawaited(
            Sentry.addBreadcrumb(
              Breadcrumb(
                message: 'sync update: ${update.type}',
                category: 'sync.update',
                level: SentryLevel.info,
                data: <String, dynamic>{
                  'type': update.type,
                  if (update.data['sid'] is String)
                    'sessionId': update.data['sid'] as String,
                  if (update.data['id'] is String)
                    'entityId': update.data['id'] as String,
                },
              ),
            ),
          );
        }

        switch (update.type) {
          case 'new-message':
            _handleNewMessage(update.data);
            break;
          case 'new-session':
            _handleNewSession(update.data);
            break;
          case 'delete-session':
            _handleDeleteSession(update.data);
            break;
          case 'archive-session':
            _handleArchiveSession(update.data);
            break;
          case 'update-session':
            _handleUpdateSession(update.data);
            break;
          case 'update-account':
            _handleUpdateAccount(update.data);
            break;
          case 'update-machine':
            _handleUpdateMachine(update.data);
            break;
          case 'new-artifact':
            _handleNewArtifact(update.data);
            break;
          case 'update-artifact':
            _handleUpdateArtifact(update.data);
            break;
          case 'delete-artifact':
            _handleDeleteArtifact(update.data);
            break;
          case 'loops-updated':
            _handleLoopsUpdated(update.data);
            break;
          case 'loop-fired':
            _handleLoopFired(update.data);
            break;
          case 'loop-expired':
            _handleLoopExpired(update.data);
            break;
        }
      } catch (error, stack) {
        logger.error('Failed to handle update', error, stack);
        handlerFailed = true;
        socketSpan
          // The exception type is a bounded, groupable value — the message is
          // not, and would make the attribute unqueryable.
          ?..setAttribute('error.reason', error.runtimeType.toString())
          ..recordError(error, stack);
      }
    }

    if (socketSpan == null) {
      await processUpdate();
    } else {
      await OpenTelemetryService().withActiveSpan(socketSpan, processUpdate);
    }
    // Previously an unconditional `end(ok: true)`, so every socket.event span
    // reported OK even when the handler threw and every "failed to handle
    // update" was invisible in Jaeger.
    socketSpan?.end(ok: !handlerFailed);
  }

  /// Socket payloads can arrive as a single-element list depending on the
  /// socket.io transport/codec path. Normalize to a map for parsers.
  Map<String, dynamic>? _normalizeSocketPayload(
    dynamic data, {
    required String handlerName,
  }) {
    dynamic payload = data;
    if (payload is List) {
      if (payload.length == 1) {
        payload = payload.first;
      } else {
        logger.warning(
          '$handlerName: unexpected list payload '
          'length=${payload.length}',
        );
        return null;
      }
    }

    if (payload is Map<String, dynamic>) {
      return payload;
    }
    if (payload is Map) {
      final normalized = <String, dynamic>{};
      for (final entry in payload.entries) {
        if (entry.key is String) {
          normalized[entry.key as String] = entry.value;
        }
      }
      return normalized;
    }

    logger.warning(
      '$handlerName: unexpected data type: ${payload.runtimeType}',
    );
    return null;
  }

  /// Handle new message update
  void _handleNewMessage(Map<String, dynamic> data) {
    final sessionId = data['sid'] as String? ?? data['id'] as String?;
    // Do NOT invalidate sessionsSync here — message events fire on every
    // streaming token and would cause dozens of sessions re-fetches per
    // response. Sessions are updated by _handleUpdateSession (session-level
    // state changes) and by the reconnect / resume handlers.
    if (sessionId == null) return;

    final isVisible = sessionId == _visibleSessionId;

    // Recreate per-session sync lazily for the visible session if needed.
    if (!messagesSync.containsKey(sessionId) && isVisible) {
      messagesSync[sessionId] = _createMessagesSync(sessionId);
    }

    // Deduplicate ALL socket events, not just visible ones.  The server
    // often broadcasts the same new-message event 7-8 times.  Without
    // dedup for non-visible sessions, a background session with an
    // active AI response floods the logger and triggers hundreds of
    // wasteful fetchMessages calls that immediately skip.
    //
    // Keys are added to _pendingInlineMessageKeys before processing and
    // moved to _recentInlineMessageKeys only after a successful inline
    // upsert/apply. Fallback paths release the pending key so socket
    // re-delivery can retry instead of being suppressed forever.
    final embeddedMessage = WireParsers.asMap(data['message']);
    String? inlineDedupKey;
    if (embeddedMessage != null) {
      final msgId = embeddedMessage['id'] as String?;
      final msgSeq = embeddedMessage['seq'];
      // Only dedup when both id and seq are present.  Null values
      // produce a malformed key ("sessionId:null:null") that would
      // cause unrelated messages to collide and be silently dropped.
      if (msgId != null && msgSeq != null) {
        inlineDedupKey = '$sessionId:$msgId:$msgSeq';
        if (!_recentInlineMessageKeys.contains(inlineDedupKey) &&
            !_pendingInlineMessageKeys.add(inlineDedupKey)) {
          return; // already seen (committed or currently processing)
        }
      }
    }

    if (isVisible) {
      if (embeddedMessage != null) {
        // Serialize inline processing per session so sidechain messages
        // (which form a parentUuid chain) are always upserted and grouped
        // in arrival order.  Without this, concurrent decryptions can
        // finish out of order, breaking the chain and leaving messages
        // orphaned outside their parent Task.
        _inlineProcessor.enqueue(
          sessionId,
          () => ingestFromSocket(
            MessageIngressEvent(
              source: MessagePipelineSource.socket,
              sessionId: sessionId,
              rawPayload: embeddedMessage,
              traceId: _newTraceIdForSocketMessage(sessionId, embeddedMessage),
              metadata: <String, dynamic>{
                'mode': 'embedded',
                'dedupKey': inlineDedupKey,
              },
              isVisibleSession: true,
              notifySessionsDomain: false,
            ),
          ),
        );
      } else {
        // Visible session with no embedded message — HTTP fetch.
        // Dedup rapid-fire duplicates: the server often broadcasts the
        // same event 7-18 times; without this gate each duplicate
        // triggers a wasteful fetchMessages HTTP call and logger flood.
        // If the session cursor has not advanced since the last
        // no-embed probe, avoid re-arming the same no-op fetch repeatedly.
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final cursorSeq = _sessionLastSeq[sessionId] ?? 0;
        final lastMs = _lastNoEmbedEventMs[sessionId] ?? 0;
        final lastSeq = _lastNoEmbedEventCursorSeq[sessionId];
        if (cursorSeq == lastSeq &&
            nowMs - lastMs < Sync._noEmbedProbeCooldownMs) {
          return;
        }
        _lastNoEmbedEventMs[sessionId] = nowMs;
        _lastNoEmbedEventCursorSeq[sessionId] = cursorSeq;
        _sessionsNeedingFetchProbe.add(sessionId);
        messagesSync[sessionId]?.invalidate();
      }
      if (logger.shouldLog(LogLevel.debug)) {
        logger.debug('New message received: $sessionId');
      }
    } else {
      // Non-visible session: decrypt and store the embedded message
      // inline so it is available immediately when the user navigates
      // to the session.  Previously we discarded the message and only
      // set a "pending" flag, relying on an HTTP fetch on navigation.
      // This caused messages to appear missing until the fetch
      // completed — or permanently if the fetch was interrupted.
      //
      // Update session.lastSeq so the delta-fetch path in fetchMessages
      // can detect any remaining gap. Also bump lastMessageAt from the
      // embedded message's createdAt so the inbox time/sort/grouping
      // reflects the new message even before the user opens the chat
      // (the local message cache may not include this message until
      // inline decryption finishes, and the next fetchSessions hasn't
      // run yet).
      final msgSeq = embeddedMessage?['seq'] as int?;
      final msgCreatedAt = embeddedMessage?['createdAt'] is int
          ? embeddedMessage!['createdAt'] as int
          : null;
      final session = _sessions[sessionId];
      if (session != null) {
        final newLastSeq = msgSeq != null && (session.lastSeq ?? 0) < msgSeq
            ? msgSeq
            : session.lastSeq;
        final newLastMessageAt =
            msgCreatedAt != null && (session.lastMessageAt ?? 0) < msgCreatedAt
            ? msgCreatedAt
            : session.lastMessageAt;
        if (newLastSeq != session.lastSeq ||
            newLastMessageAt != session.lastMessageAt) {
          _sessions[sessionId] = session.copyWith(
            lastSeq: newLastSeq,
            lastMessageAt: newLastMessageAt,
          );
        }
      }

      // Process the embedded message inline (decrypt + store) so it
      // is immediately available when the user opens this session.
      if (embeddedMessage != null) {
        _inlineProcessor.enqueue(
          sessionId,
          () => ingestFromSocket(
            MessageIngressEvent(
              source: MessagePipelineSource.socket,
              sessionId: sessionId,
              rawPayload: embeddedMessage,
              traceId: _newTraceIdForSocketMessage(sessionId, embeddedMessage),
              metadata: <String, dynamic>{
                'mode': 'embedded',
                'dedupKey': inlineDedupKey,
              },
              isVisibleSession: false,
              notifySessionsDomain: true,
            ),
          ),
        );
      } else {
        // No embedded message — mark pending for HTTP fetch on
        // navigation.
        _sessionsWithPendingSocketMessages.add(sessionId);
      }

      final isNew = _sessionsWithPendingUpdates.add(sessionId);
      if (isNew) {
        logger.debug(
          '[handleNewMessage] NON-VISIBLE session=$sessionId '
          'msgSeq=$msgSeq embedded=${embeddedMessage != null} '
          '— pendingUpdates added',
        );
      }
      // Rate-limit unread increments: during rapid agent streaming,
      // most socket events are sidechain/meta messages that won't be
      // visible in the main chat. Increment at most once per interval
      // to keep the badge count proportional to actual new content.
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final lastIncrMs = _sessionUnreadLastIncrementMs[sessionId] ?? 0;
      final current = _sessionUnreadCounts[sessionId] ?? 0;
      final int newUnread;
      if (current < Sync._maxUnreadCount &&
          nowMs - lastIncrMs >= Sync._unreadIncrementMinIntervalMs) {
        newUnread = current + 1;
        _sessionUnreadCounts[sessionId] = newUnread;
        _sessionUnreadLastIncrementMs[sessionId] = nowMs;
      } else {
        newUnread = current;
      }

      if (isNew) {
        Sentry.addBreadcrumb(
          Breadcrumb(
            message: 'Background message received',
            category: 'chat.background',
            level: SentryLevel.info,
            data: <String, dynamic>{
              'sessionId': sessionId,
              'msgSeq': msgSeq,
              'unreadCount': newUnread,
              'hasEmbedded': embeddedMessage != null,
              'isFirstPending': true,
            },
          ),
        );
      }
    }
  }

  String _newTraceIdForSocketMessage(
    String sessionId,
    Map<String, dynamic> message,
  ) {
    final msgId = message['id'] ?? 'no-id';
    final msgSeq = message['seq'];
    final segment = msgSeq == null ? 'no-seq' : 'seq$msgSeq';
    return '${sessionId}_socket_${segment}_$msgId';
  }

  /// Handle new session update
  void _handleNewSession(Map<String, dynamic> data) {
    final sessionId = data['id'] as String? ?? data['sid'] as String?;
    logger.info('New session received: $sessionId');
    if (sessionId != null && sessionId.isNotEmpty) {
      _pendingNewSessionIds.add(sessionId);
    }
    _scheduleSessionsRefresh();
  }

  /// Handle session deletion
  void _handleDeleteSession(Map<String, dynamic> data) {
    final sessionId = data['sid'] as String?;
    if (sessionId != null) {
      // Clear _visibleSessionId if this was the visible session to
      // prevent stale references pointing to a deleted session.
      if (sessionId == _visibleSessionId) {
        _visibleSessionId = null;
      }
      messagesSync.remove(sessionId)?.dispose();
      _postSendCatchUpTimers.remove(sessionId)?.cancel();
      _loadingOlderMessages.remove(sessionId);
      _sessionMessages.remove(sessionId);
      _invalidatePreviewCache(sessionId);
      _invalidateMessageCaches(sessionId);
      _sessions.remove(sessionId);
      _sessionsNeedingVisibleRegroup.remove(sessionId);
      _presenceTimers.remove(sessionId)?.cancel();
      _sessionDataKeys.remove(sessionId);
      _sessionEncryptedDataKeys.remove(sessionId);
      _sessionsNeedingTailRefresh.remove(sessionId);
      _sessionsWithPendingUpdates.remove(sessionId);
      _sessionsWithPendingSocketMessages.remove(sessionId);
      _sessionsNeedingFetchProbe.remove(sessionId);
      _sessionSpawnedAt.remove(sessionId);
      _sessionSpawnedProfile.remove(sessionId);
      _sessionSpawnedModel.remove(sessionId);
      _sessionSpawnedAgent.remove(sessionId);
      _autoRestoreInFlight.remove(sessionId);
      _pendingToolResults.remove(sessionId);
      // Clear any cached loops for the deleted session so we don't
      // resurrect them on next hydration.
      clearLoopsForSession(sessionId);
      // Clear any cached workflow runs for the deleted session so we don't
      // resurrect them on next hydration.
      clearWorkflowsForSession(sessionId);
      // Clean up per-session collections that were missed
      _lastNoEmbedEventMs.remove(sessionId);
      _sidechainRegroupTimers.remove(sessionId)?.cancel();
      _sidechainRegroupFirstRequestMs.remove(sessionId);
      _lastNoEmbedEventCursorSeq.remove(sessionId);
      _sessionMessageDebounceTimers.remove(sessionId)?.cancel();
      _sessionUnreadCounts.remove(sessionId);
      _sessionUnreadLastIncrementMs.remove(sessionId);
      _lastEphemeralAt.remove(sessionId);
      // Clean up pending inline message keys for this session to prevent
      // unbounded growth of _pendingInlineMessageKeys.
      _pendingInlineMessageKeys.removeWhere(
        (key) => key.startsWith('$sessionId:'),
      );
      if (isInitialized) {
        _sessionLastSeq.remove(sessionId);
        MMKVStorage().saveSessionLastSeq(Map.unmodifiable(_sessionLastSeq));
        _sessionFirstLoadedSeq.remove(sessionId);
        MMKVStorage().saveSessionFirstLoadedSeq(
          Map.unmodifiable(_sessionFirstLoadedSeq),
        );
        _saveMsgsDebounceTimers.remove(sessionId)?.cancel();
        _saveMsgsFirstScheduledAtMs.remove(sessionId);
        MessageCacheService().clearMessages(sessionId);
        if (_encryptionInitialized) {
          encryption.removeSessionEncryption(sessionId);
        }
      }
    }
    _scheduleSaveSessionsCache();
    sessionsSync.invalidate();
    logger.info(
      'Session deletion received'
      '${sessionId != null ? ': $sessionId' : ''}',
    );
  }

  /// Handle server-side error events.
  ///
  /// When the server emits `{code: "session-invalid", sid: "..."}` it
  /// means the session has been deleted server-side while the client
  /// still holds a reference.  We treat this identically to a
  /// `delete-session` update so all local state is cleaned up and the
  /// UI stops showing the stale session.
  void _handleErrorEvent(dynamic data) {
    final payload = _normalizeSocketPayload(
      data,
      handlerName: '_handleErrorEvent',
    );
    if (payload == null) return;
    final code = payload['code'] as String?;
    if (code == 'session-invalid') {
      final sid = payload['sid'] as String?;
      if (sid != null) {
        logger.info('Received session-invalid for $sid — removing local state');
        _handleDeleteSession({'sid': sid});
      }
    }
  }

  /// Handle archive-session WebSocket event.
  ///
  /// The server broadcasts this after a successful archive/unarchive API
  /// call.  We apply the archived flag immediately to the in-memory
  /// session so the UI updates without waiting for a full refetch.
  void _handleArchiveSession(Map<String, dynamic> data) {
    final sessionId = data['sid'] as String?;
    final archived = data['archived'] as bool?;
    if (sessionId == null || archived == null) return;

    final session = _sessions[sessionId];
    if (session == null) return;

    _sessions[sessionId] = session.copyWith(archived: archived);
    if (archived) {
      _optimisticallyArchivedSessions.add(sessionId);
    } else {
      _optimisticallyArchivedSessions.remove(sessionId);
    }
    _notifyDataChanged({SyncDomain.sessions});
    logger.info('Session archive event: $sessionId archived=$archived');
  }

  /// Handle session update
  ///
  /// Applies delta patches directly to the in-memory session for
  /// unencrypted fields (presence, active, activeAt, title, thinking).
  /// Only falls back to [sessionsSync.invalidate()] for encrypted
  /// fields (metadata, agentState) that require decryption.  This
  /// eliminates the ~4 fetchSessions() HTTP calls/sec that were
  /// happening during active streaming even with debouncing.
  void _handleUpdateSession(Map<String, dynamic> data) {
    final sessionId = data['id'] as String? ?? data['sid'] as String?;
    if (sessionId == null) return;

    // Apply delta patch directly to the in-memory session for
    // unencrypted fields. This updates the UI immediately without
    // waiting for a debounced HTTP fetch.
    // Ephemeral events (handleEphemeralUpdate) already handle
    // presence/typing directly -- the update-session event carries the
    // same data plus metadata.
    final session = _sessions[sessionId];
    var needsEncryptedRefresh = session == null;
    if (session != null) {
      final presence = data['presence'] as String?;
      final active = data['active'] as bool?;
      final now = DateTime.now().millisecondsSinceEpoch;
      final eventActiveAt = data['activeAt'] is int
          ? data['activeAt'] as int
          : data['activeAt'] is double
          ? (data['activeAt'] as double).toInt()
          : null;
      final activeAt = _clampTimestampToNow(eventActiveAt, now);
      final thinking = data['thinking'] as bool?;
      final thinkingAt = data['thinkingAt'] is int
          ? data['thinkingAt'] as int
          : data['thinkingAt'] is double
          ? (data['thinkingAt'] as double).toInt()
          : null;
      final archived = data['archived'] as bool?;
      final lastSeq = data['lastSeq'] is int
          ? data['lastSeq'] as int
          : data['lastSeq'] is double
          ? (data['lastSeq'] as double).toInt()
          : null;
      final metadataVersion = WireParsers.parseInt(data['metadataVersion']);
      final agentStateVersion = WireParsers.parseInt(data['agentStateVersion']);

      // Only update if at least one unencrypted field is present AND
      // has actually changed.  Without the value check, copyWith still
      // creates a new object every time and notifies all listeners —
      // including providers that watch the whole sessions map — even when
      // the presence/active/etc. values are identical to current ones.
      final hasChanged =
          (presence != null && presence != session.presence) ||
          (active != null && active != session.active) ||
          (activeAt != null && activeAt != session.activeAt) ||
          (thinking != null && thinking != session.thinking) ||
          (thinkingAt != null && thinkingAt != session.thinkingAt) ||
          (archived != null && archived != session.archived) ||
          (lastSeq != null && (session.lastSeq ?? 0) < lastSeq);
      if (hasChanged) {
        _sessions[sessionId] = session.copyWith(
          presence: presence ?? session.presence,
          active: active ?? session.active,
          activeAt: activeAt ?? session.activeAt,
          thinking: thinking ?? session.thinking,
          thinkingAt: thinkingAt,
          archived: archived ?? session.archived,
          lastSeq: lastSeq != null && (session.lastSeq ?? 0) < lastSeq
              ? lastSeq
              : session.lastSeq,
        );
        _notifyDataChanged({SyncDomain.sessions});
      }
      needsEncryptedRefresh =
          data.containsKey('metadata') ||
          data.containsKey('agentState') ||
          (metadataVersion != null &&
              metadataVersion > session.metadataVersion) ||
          (agentStateVersion != null &&
              agentStateVersion > session.agentStateVersion);
    }

    // Schedule a debounced refresh as a safety net for encrypted
    // fields (metadata, agentState) that we can't decrypt inline here.
    // The refresh is also needed for new sessions that aren't in
    // _sessions yet.
    if (needsEncryptedRefresh) {
      _scheduleSessionsRefresh();
    }

    // Only log the first occurrence per session within a debounce
    // window. The server broadcasts dozens of identical update-session
    // events per second during streaming (typing/tool state changes).
    if (_pendingUpdateSessionIds.add(sessionId)) {
      logger.debug('Session update received: $sessionId');
      if (!needsEncryptedRefresh) {
        Timer(Sync._sessionsRefreshDebounce, () {
          _pendingUpdateSessionIds.remove(sessionId);
        });
      }
    }
  }

  /// Apply a `loops-updated` socket event.
  ///
  /// Payload shape (per `docs/LOOPS.md`):
  /// `{t: 'loops-updated', sid: string, loops: Loop[]}`. The list is the
  /// authoritative replacement — we drop whatever we had locally and persist.
  void _handleLoopsUpdated(Map<String, dynamic> data) {
    final sid = data['sid'] as String?;
    final loops = data['loops'] as List<dynamic>?;
    if (sid == null) {
      logger.warning('[Sync] loops-updated missing sid — skipping');
      return;
    }
    if (loops == null) {
      logger.warning('[Sync] loops-updated missing loops — skipping');
      return;
    }
    _applyLoopsUpdate(sid, loops);
    _notifyDataChanged({SyncDomain.loops});
  }

  /// Apply a `loop-fired` telemetry event.
  ///
  /// Payload: `{t: 'loop-fired', sid, loopId, firedAt, fireCount}`. The
  /// user-visible turn arrives separately via `new-message`; this just
  /// updates the in-memory loop so the Loops screen can show the most
  /// recent fire time.
  void _handleLoopFired(Map<String, dynamic> data) {
    final sid = data['sid'] as String?;
    final loopId = data['loopId'] as String?;
    if (sid == null || loopId == null) {
      logger.warning('[Sync] loop-fired missing sid/loopId — skipping');
      return;
    }
    final firedAt = data['firedAt'];
    final fireCount = data['fireCount'];
    if (firedAt is! num) {
      logger.warning('[Sync] loop-fired missing firedAt — skipping');
      return;
    }
    _applyLoopFired(
      sid,
      loopId,
      firedAt.toInt(),
      fireCount is num ? fireCount.toInt() : 0,
    );
    _notifyDataChanged({SyncDomain.loops});
  }

  /// Apply a `loop-expired` event (one-shot self-delete or 7-day recurring
  /// expiry). Removes the loop from the local mirror.
  void _handleLoopExpired(Map<String, dynamic> data) {
    final sid = data['sid'] as String?;
    final loopId = data['loopId'] as String?;
    if (sid == null || loopId == null) {
      logger.warning('[Sync] loop-expired missing sid/loopId — skipping');
      return;
    }
    _applyLoopExpired(sid, loopId);
    _notifyDataChanged({SyncDomain.loops});
  }
}
