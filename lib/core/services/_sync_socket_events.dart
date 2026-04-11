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
      _invalidateAllSyncs();
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
      // Re-fetch messages for the visible session immediately.
      // For non-visible sessions that have messages in memory,
      // mark them as having pending socket messages so
      // onSessionVisible() triggers a server fetch when the user
      // navigates to them.  Without this, messages received
      // during the disconnect gap are permanently lost because
      // no socket events were delivered.
      for (final sessionId in _sessionMessages.keys) {
        if (sessionId != _visibleSessionId) {
          _sessionsWithPendingSocketMessages.add(sessionId);
        }
      }
      // Chain messages fetch after the sessions fetch that
      // _invalidateAllSyncs() already kicked off.  We await the
      // existing queue instead of calling invalidateAndAwait()
      // again, which would start a SECOND HTTP fetch cycle and
      // was the primary cause of the N+1 sessions problem
      // (~12 fetches per app load).
      if (_visibleSessionId != null) {
        unawaited(
          sessionsSync.awaitQueue().then((_) {
            if (_visibleSessionId != null) {
              messagesSync[_visibleSessionId]?.invalidate();
            }
          }),
        );
      }
    });
    _unsubscribeSocketReconnectExhausted?.call();
    _unsubscribeSocketReconnectExhausted =
        socketIoClient.onReconnectExhausted(() {
      logger.warning(
        '[Sync] socket reconnection attempts exhausted — '
        'scheduling fresh reconnect in '
        '${Sync._reconnectWatchdogDelayMs}ms',
      );
      _scheduleReconnectWatchdog();
    });
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
        case 'relationship-updated':
          _handleRelationshipUpdated(update.data);
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
        case 'new-feed-post':
          _handleNewFeedPost(update.data);
          break;
        case 'kv-batch-update':
          _handleKvBatchUpdate(update.data);
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
      );
    }

    // Deduplicate ALL socket events, not just visible ones.  The server
    // often broadcasts the same new-message event 7-8 times.  Without
    // dedup for non-visible sessions, a background session with an
    // active AI response floods the logger and triggers hundreds of
    // wasteful fetchMessages calls that immediately skip.
    //
    // Keys are added to _pendingInlineMessageKeys BEFORE processing and
    // moved to _recentInlineMessageKeys AFTER success.  This allows
    // retry on failure: if processing throws, the key stays pending so
    // the HTTP fallback can re-process the message without it being
    // incorrectly deduped as "already seen".
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
          () => _processInlineMessage(sessionId, embeddedMessage),
        );
      } else {
        // Visible session with no embedded message — HTTP fetch.
        // Dedup rapid-fire duplicates: the server often broadcasts the
        // same event 7-18 times; without this gate each duplicate
        // triggers a wasteful fetchMessages HTTP call and logger flood.
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final lastMs = _lastNoEmbedEventMs[sessionId] ?? 0;
        if (nowMs - lastMs < 50) return;
        _lastNoEmbedEventMs[sessionId] = nowMs;
        _sessionsNeedingFetchProbe.add(sessionId);
        messagesSync[sessionId]?.invalidate();
      }
      logger.debug('New message received: $sessionId');
    } else {
      // Non-visible session: decrypt and store the embedded message
      // inline so it is available immediately when the user navigates
      // to the session.  Previously we discarded the message and only
      // set a "pending" flag, relying on an HTTP fetch on navigation.
      // This caused messages to appear missing until the fetch
      // completed — or permanently if the fetch was interrupted.
      //
      // Update session.lastSeq so the delta-fetch path in fetchMessages
      // can detect any remaining gap.
      final msgSeq = embeddedMessage?['seq'] as int?;
      if (msgSeq != null) {
        final session = _sessions[sessionId];
        if (session != null && (session.lastSeq ?? 0) < msgSeq) {
          _sessions[sessionId] = session.copyWith(lastSeq: msgSeq);
        }
      }

      // Process the embedded message inline (decrypt + store) so it
      // is immediately available when the user opens this session.
      if (embeddedMessage != null) {
        _inlineProcessor.enqueue(
          sessionId,
          () => _processInlineMessage(sessionId, embeddedMessage),
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
            'isFirstPending': isNew,
          },
        ),
      );
    }
  }

  /// Decrypt and upsert a single message received inline from the socket
  /// event, bypassing the HTTP fetch round-trip.
  ///
  /// Falls back to [InvalidateSync.invalidate] on failure or when the
  /// message produces no displayable content.
  Future<void> _processInlineMessage(
    String sessionId,
    Map<String, dynamic> wireMessage,
  ) async {
    final msgId = wireMessage['id'] as String?;
    final msgSeq = wireMessage['seq'];
    // Null-safe dedup key — only meaningful when both fields are
    // present (see guard in _handleNewMessage).
    final dedupKey = (msgId != null && msgSeq != null)
        ? '$sessionId:$msgId:$msgSeq'
        : null;

    final sessionEncryption = encryption.getSessionEncryption(sessionId);
    if (sessionEncryption == null) {
      // Leave key in _pendingInlineMessageKeys so retry can re-enter
      // inline path once encryption is initialized.
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
        if (processed.droppedReasons.isNotEmpty) {
          for (final reason in processed.droppedReasons) {
            logger.warning('[inline] dropped: $reason');
          }
        }
        messagesSync[sessionId]?.invalidate();
        _notifySessionMessagesChanged(sessionId);
        return;
      }

      if (processed.messages.isNotEmpty) {
        _upsertSessionMessages(sessionId, processed.messages);
      }
      if (processed.toolResults.isNotEmpty) {
        _applyToolResults(sessionId, processed.toolResults);
      }
      // Apply any pending tool results that arrived before these
      // messages. This handles the case where a tool-call-result arrives
      // via socket before the tool-call message itself.
      final pending = _pendingToolResults.remove(sessionId);
      if (pending != null && pending.isNotEmpty) {
        _applyToolResults(sessionId, pending);
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
      _notifyDataChanged({SyncDomain.messages, SyncDomain.sessions});
      // Remove the completed Future from the queue so new messages can
      // start fresh processing without chaining onto a resolved Future.
      // The queue entry is also removed on error (below) for symmetry.
      _inlineProcessor.clearSession(sessionId);
    } catch (error, stack) {
      logger.warning(
        'Inline message processing failed — HTTP fetch will retry',
        error,
        stack,
      );
      // Leave key in _pendingInlineMessageKeys so retry can re-process.
      // Remove the failed Future from the queue so subsequent messages
      // can re-enter the inline fast path instead of being silently
      // dropped by chaining onto a rejected Future.
      _inlineProcessor.clearSession(sessionId);
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
      _sessionMessagesCache = null;
      _sessionMessagesViewCache.remove(sessionId);
      _todoLists.remove(sessionId);
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
      _autoRestoreInFlight.remove(sessionId);
      _pendingToolResults.remove(sessionId);
      // Clean up per-session collections that were missed
      _lastNoEmbedEventMs.remove(sessionId);
      _sidechainRegroupTimers.remove(sessionId)?.cancel();
      _sidechainRegroupFirstRequestMs.remove(sessionId);
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
          (archived != null && archived != session.archived);
      if (hasChanged) {
        _sessions[sessionId] = session.copyWith(
          presence: presence ?? session.presence,
          active: active ?? session.active,
          activeAt: activeAt ?? session.activeAt,
          thinking: thinking ?? session.thinking,
          thinkingAt: thinkingAt,
          archived: archived ?? session.archived,
        );
        _notifyDataChanged({SyncDomain.sessions});
      }
    }

    // Schedule a debounced refresh as a safety net for encrypted
    // fields (metadata, agentState) that we can't decrypt inline here.
    // The refresh is also needed for new sessions that aren't in
    // _sessions yet.
    _scheduleSessionsRefresh();

    // Only log the first occurrence per session within a debounce
    // window. The server broadcasts dozens of identical update-session
    // events per second during streaming (typing/tool state changes).
    if (_pendingUpdateSessionIds.add(sessionId)) {
      logger.debug('Session update received: $sessionId');
    }
  }
}
