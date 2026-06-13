part of 'sync_service.dart';

extension SyncSocketEvents on Sync {
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
      // Snapshot the visible session's cursor BEFORE any new socket
      // events are processed.  Inline processing of post-reconnect
      // events can advance the cursor past the disconnect gap,
      // causing the reconnection fetch to skip messages that arrived
      // while the socket was down.
      if (_visibleSessionId != null) {
        _reconnectCursorSnapshot = _sessionLastSeq[_visibleSessionId] ?? 0;
      }
      // Force-bypass the 10s cooldown gate — a reconnect means the
      // socket was down and the local session catalog (especially
      // lastSeq) is potentially stale.  Without force, rapid
      // reconnects (or a reconnect shortly after the deferred resume
      // timer) silently skip the sessions fetch.  fetchMessages then
      // sees cursorSeq == serverLastSeq (both stale) and skips the
      // HTTP round-trip, permanently losing messages that arrived
      // during the disconnect gap.
      //
      // Debounce forced invalidation: on cold start, _init() already
      // called _invalidateAllSyncs(force: true) moments before the
      // socket connects.  Without this guard, every cold start pays
      // for two full sync cycles (18 HTTP requests instead of 9).
      final reconnectNowMs = DateTime.now().millisecondsSinceEpoch;
      final resumeHttpFallbackRecentlyFired =
          _lastResumeHttpFallbackAtMs != null &&
          reconnectNowMs - _lastResumeHttpFallbackAtMs! < 3000;
      if (resumeHttpFallbackRecentlyFired) {
        logger.debug(
          '[Sync] skipping reconnect global invalidation; '
          'resume HTTP fallback already refreshed sessions',
        );
      } else if (_lastInvalidateAllSyncsAtMs == null ||
          reconnectNowMs - _lastInvalidateAllSyncsAtMs! >= 2000) {
        _invalidateAllSyncs(force: true);
      }
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
      }
    } catch (error, stack) {
      logger.error('Failed to handle update', error, stack);
    }
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
      messagesSync[sessionId] = InvalidateSync(
        () => fetchMessages(sessionId),
        minInterval: Sync._messagesSyncMinInterval,
        name: 'fetchMessages',
        onRunningChanged: _onSyncRunningChanged,
        maxRetries: 0,
      );
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
    if (embeddedMessage != null) {
      final msgId = embeddedMessage['id'] as String?;
      final msgSeq = embeddedMessage['seq'];
      // Only dedup when both id and seq are present.  Null values
      // produce a malformed key ("sessionId:null:null") that would
      // cause unrelated messages to collide and be silently dropped.
      if (msgId != null && msgSeq != null) {
        final dedupKey = '$sessionId:$msgId:$msgSeq';
        if (!_recentInlineMessageKeys.contains(dedupKey) &&
            !_pendingInlineMessageKeys.add(dedupKey)) {
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
          () => _processInlineMessage(
            sessionId,
            embeddedMessage,
            notifySessionsDomain: false,
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
        if (cursorSeq == lastSeq && nowMs - lastMs < _noEmbedProbeCooldownMs) {
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
          () => _processInlineMessage(
            sessionId,
            embeddedMessage,
            notifySessionsDomain: true,
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

  /// Decrypt and upsert a single message received inline from the socket
  /// event, bypassing the HTTP fetch round-trip.
  ///
  /// Falls back to [InvalidateSync.invalidate] on failure or when the
  /// message produces no displayable content.
  Future<void> _processInlineMessage(
    String sessionId,
    Map<String, dynamic> wireMessage, {
    required bool notifySessionsDomain,
  }) async {
    final msgId = wireMessage['id'] as String?;
    final msgSeq = wireMessage['seq'];
    // Null-safe dedup key — only meaningful when both fields are
    // present (see guard in _handleNewMessage).
    final dedupKey = (msgId != null && msgSeq != null)
        ? '$sessionId:$msgId:$msgSeq'
        : null;

    final sessionEncryption = encryption.getSessionEncryption(sessionId);
    if (sessionEncryption == null) {
      if (dedupKey != null) {
        _pendingInlineMessageKeys.remove(dedupKey);
      }
      messagesSync[sessionId]?.invalidate();
      _notifySessionMessagesChanged(sessionId);
      return;
    }

    try {
      final processed = await sessionEncryption.decryptAndProcessMessages([
        wireMessage,
      ], sessionId);

      if (processed.messages.isEmpty && processed.toolResults.isEmpty) {
        // Nothing displayable from inline processing.  Do NOT advance
        // the seq cursor here — doing so causes the fallback HTTP fetch
        // (below) to be skipped by fetchMessages' "already caught up"
        // guard, permanently losing the message.  Keeping the cursor
        // unchanged lets the fetch retrieve the message from the server.
        _logDroppedReasons('[inline] dropped', processed.droppedReasons);
        if (dedupKey != null) {
          _pendingInlineMessageKeys.remove(dedupKey);
        }
        messagesSync[sessionId]?.invalidate();
        _notifySessionMessagesChanged(sessionId);
        return;
      }

      try {
        if (processed.messages.isNotEmpty) {
          _upsertSessionMessages(sessionId, processed.messages);
        }
        if (processed.toolResults.isNotEmpty) {
          _applyToolResults(sessionId, processed.toolResults);
        }
        // Apply any pending tool results that arrived before these
        // messages. This handles the case where a tool-call-result arrives
        // via socket before the tool-call message itself. Only drain
        // matched results so cross-path ordering can't lose results.
        final pending = _pendingToolResults[sessionId];
        if (pending != null && pending.isNotEmpty) {
          final matched = _applyToolResults(sessionId, pending);
          if (matched.isNotEmpty) {
            pending.removeWhere((r) => matched.contains(r['toolUseId']));
            if (pending.isEmpty) {
              _pendingToolResults.remove(sessionId);
            }
          }
        }
        for (final u in processed.usageUpdates) {
          final usageMap = WireParsers.asMap(u['usage']);
          if (usageMap != null) {
            _updateSessionUsage(
              u['sessionId'] as String,
              usageMap,
              u['timestamp'] as int,
            );
          }
        }
        _applyPermissionRequests(sessionId);

        // Run the sidechain grouper when the incoming messages contain
        // sidechain content.  We intentionally omit changedIds here to
        // force the full 4-pass grouper instead of the fast-path.  The
        // fast-path only checks whether the *changed* messages are
        // sidechain-relevant, which misses orphaned children from
        // previous batches whose parent chain wasn't established yet.
        // During active agent streaming, messages arrive every ~50ms and
        // the deferred regroup timer (300ms) keeps getting cancelled, so
        // orphans accumulate and never get grouped — this is the root
        // cause of agent conversation screens showing incomplete children
        // (only 1-2 tool calls, no thinking or text blocks).
        //
        // The full grouper is O(4n) where n <= 3000 (the message cap),
        // which completes in ~1-2ms — negligible for inline processing.
        final hasSidechain = processed.messages.any(
          (m) => m['isSidechain'] == true || m['kind'] == 'sidechain-root',
        );
        if (hasSidechain) {
          _groupSidechainMessages(sessionId);
        }
      } catch (error, stack) {
        logger.warning(
          'Inline message upsert/grouping failed for session $sessionId '
          '— HTTP fetch will retry',
          error,
          stack,
        );
      }

      // Advance the seq cursor so future incremental fetches don't
      // re-download this message.
      _advanceSeqCursor(sessionId, processed.maxSeq);

      // Commit the dedup key: remove from _pendingInlineMessageKeys and
      // add to _recentInlineMessageKeys with FIFO eviction.
      if (dedupKey != null) {
        _pendingInlineMessageKeys.remove(dedupKey);
        _recentInlineMessageKeys.add(dedupKey);
        _recentInlineMessageKeyOrder.addLast(dedupKey);
        while (_recentInlineMessageKeyOrder.length >
            Sync._maxRecentInlineKeys) {
          _recentInlineMessageKeys.remove(
            _recentInlineMessageKeyOrder.removeFirst(),
          );
        }
      }

      _notifySessionMessagesChanged(sessionId);
      _notifyDataChanged(
        notifySessionsDomain
            ? const {SyncDomain.messages, SyncDomain.sessions}
            : const {SyncDomain.messages},
      );
    } catch (error, stack) {
      logger.warning(
        'Inline message processing failed — HTTP fetch will retry',
        error,
        stack,
      );
      if (dedupKey != null) {
        _pendingInlineMessageKeys.remove(dedupKey);
      }
      messagesSync[sessionId]?.invalidate();
      _notifySessionMessagesChanged(sessionId);
    }
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
      _sessionMessagesCache = null;
      _sessionMessagesViewCache.remove(sessionId);
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
      final activeAt = data['activeAt'] is int
          ? data['activeAt'] as int
          : data['activeAt'] is double
          ? (data['activeAt'] as double).toInt()
          : null;
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
}
