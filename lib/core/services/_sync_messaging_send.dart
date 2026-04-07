part of 'sync_service.dart';

class _AgentStartupTimeout implements Exception {
  const _AgentStartupTimeout(this.sessionId);

  final String sessionId;

  @override
  String toString() =>
      'StateError: Agent did not become ready for session $sessionId';
}

extension SyncMessagingSend on Sync {
  /// Send message to session.
  ///
  /// Returns the target session ID synchronously after the optimistic
  /// message is inserted and the UI is notified. The actual REST POST
  /// and socket emit run in the background — callers should NOT await
  /// this method if they want instant feedback.
  ///
  /// The optimistic message carries a `'sendStatus'` field:
  /// - `'sending'` — immediately after insert
  /// - `'sent'`    — after server ACK
  /// - `'failed'`  — on error (message is kept so the user can see it)
  Future<String> sendMessage(
    String sessionId,
    String text, {
    String? displayText,
    String? permissionMode,
    String? modelMode,
    String? profileId,
  }) async {
    var sessionEncryption = encryption.getSessionEncryption(sessionId);
    if (sessionEncryption == null) {
      logger.info(
        '[sendMessage] encryption missing for session=$sessionId, '
        'attempting recovery',
      );
      // Try fetching just this session before doing a full list re-fetch.
      await fetchSingleSession(sessionId);
      sessionEncryption = encryption.getSessionEncryption(sessionId);
      if (sessionEncryption == null) {
        await sessionsSync.invalidateAndAwait();
        sessionEncryption = encryption.getSessionEncryption(sessionId);
      }
      if (sessionEncryption == null) {
        _forceFullFetchNext = true;
        await sessionsSync.invalidateAndAwait();
        sessionEncryption = encryption.getSessionEncryption(sessionId);
      }
      if (sessionEncryption == null) {
        throw StateError('Session encryption not initialized for $sessionId');
      }
    }

    var session = _sessions[sessionId];
    if (session == null) {
      // Try fetching just this session instead of a full list re-fetch.
      session = await fetchSingleSession(sessionId);
      if (session == null) {
        _forceFullFetchNext = true;
        await sessionsSync.invalidateAndAwait();
        session = _sessions[sessionId];
      }
    }
    if (session == null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      session = Session(
        id: sessionId,
        seq: 0,
        createdAt: now,
        updatedAt: now,
        active: true,
        activeAt: now,
        metadata: Metadata(host: '', lifecycleState: 'starting'),
        metadataVersion: 0,
        agentStateVersion: 0,
        thinking: false,
        presence: 'offline',
        permissionMode: permissionMode,
        modelMode: modelMode,
      );
      _sessions[sessionId] = session;
      _notifyDataChanged({SyncDomain.sessions});
    }

    final requestedPermissionMode = permissionMode;
    final sandboxEnabled = session.metadata?.sandboxEnabled ?? false;
    final storedPermissionMode = session.permissionMode;
    final effectivePermissionMode =
        requestedPermissionMode != null && requestedPermissionMode != 'default'
        ? requestedPermissionMode
        : (storedPermissionMode != null && storedPermissionMode != 'default')
        ? storedPermissionMode
        : (sandboxEnabled ? 'bypassPermissions' : 'default');

    final sendTarget = await _resolveSendTargetSession(
      sessionId: sessionId,
      session: session,
      sessionEncryption: sessionEncryption,
      effectivePermissionMode: effectivePermissionMode,
      profileId: profileId,
    );
    final targetSessionId = sendTarget.sessionId;
    session = sendTarget.session;
    sessionEncryption = sendTarget.sessionEncryption;

    final wirePermissionMode =
        Sync._supportedPermissionModes.contains(effectivePermissionMode)
        ? effectivePermissionMode
        : 'default';
    if (wirePermissionMode != effectivePermissionMode) {
      logger.warning(
        '[sendMessage] unsupported permission mode '
        '"$effectivePermissionMode" for session=$sessionId; '
        'falling back to "$wirePermissionMode"',
      );
    }
    final flavor = session.metadata?.flavor;
    final isGemini = flavor == 'gemini';
    final requestedModelMode = modelMode;
    final effectiveModelMode =
        requestedModelMode != null && requestedModelMode != 'default'
        ? requestedModelMode
        : isGemini
        ? 'gemini-2.5-pro'
        : 'default';
    final localId = encryption.generateId();
    final sentFrom = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'mac',
      _ => 'web',
    };
    final model = effectiveModelMode != 'default' ? effectiveModelMode : null;

    final rawRecord = <String, dynamic>{
      'role': 'user',
      'content': <String, dynamic>{'type': 'text', 'text': text},
      'meta': <String, dynamic>{
        'sentFrom': sentFrom,
        'permissionMode': wirePermissionMode,
        'model': model,
        'fallbackModel': null,
        'appendSystemPrompt': Sync._appendSystemPrompt,
        'displayText': ?displayText,
      },
    };
    logger.info(
      '[sendMessage] START session=$targetSessionId '
      'localId=$localId '
      'requestedSession=$sessionId '
      'mode=$wirePermissionMode '
      'model=${model ?? 'default'} '
      'textLen=${text.length}',
    );

    // Start a Sentry transaction covering the entire send flow.
    final sendTransaction =
        Sentry.startTransaction('chat.sendMessage', 'task', bindToScope: false)
          ..setData('sessionId', targetSessionId)
          ..setData('localId', localId)
          ..setData('textLength', text.length)
          ..setData('permissionMode', wirePermissionMode)
          ..setData('model', model ?? 'default');

    // Ensure catch-up polling is active for this session. Without this,
    // if sendMessage() is called before onSessionVisible() (e.g. from the
    // sessions list before the chat screen initialises), _startPostSendCatchUp
    // silently no-ops and the agent response never appears.
    if (!messagesSync.containsKey(targetSessionId)) {
      onSessionVisible(targetSessionId);
    }

    // ── Optimistic insert — UI sees the message immediately ──
    // This runs BEFORE encryption so the user gets instant feedback on tap.
    _upsertSessionMessages(targetSessionId, [
      {
        'id': localId,
        'localId': localId,
        'seq': 0,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'role': 'user',
        'kind': 'text',
        'content': text,
        'raw': rawRecord,
        'sendStatus': 'sending',
      },
    ]);
    // Notify listeners so the chat screen renders it NOW.
    if (!_sessionMessageChangeController.isClosed) {
      _sessionMessageChangeController.add(targetSessionId);
    }

    // Encrypt after the optimistic insert so the user sees instant feedback.
    // The encrypted record is only needed for the HTTP POST to the server.
    final encryptSpan = sendTransaction.startChild(
      'chat.encrypt',
      description: 'Encrypt message for session',
    );
    final encryptedRawRecord = await sessionEncryption.encryptRawRecord(
      rawRecord,
    );
    unawaited(encryptSpan.finish());

    // ── Background: REST POST + socket emit ──
    // Fire-and-forget — the caller returns targetSessionId immediately.
    // lastCompleteSendFuture is exposed for tests to synchronise on.
    final completeSendFuture = _completeSend(
      targetSessionId: targetSessionId,
      localId: localId,
      text: text,
      rawRecord: rawRecord,
      encryptedRawRecord: encryptedRawRecord,
      transaction: sendTransaction,
    );
    lastCompleteSendFuture = completeSendFuture;
    unawaited(completeSendFuture);

    return targetSessionId;
  }

  /// Background half of [sendMessage]: waits for agent, POSTs to REST,
  /// emits socket event, and updates the optimistic message status.
  Future<void> _completeSend({
    required String targetSessionId,
    required String localId,
    required String text,
    required Map<String, dynamic> rawRecord,
    required String encryptedRawRecord,
    required ISentrySpan transaction,
  }) async {
    final apiClient = ApiClient();
    var sent = false;
    var catchUpStopAfterSeq = (_sessionLastSeq[targetSessionId] ?? 0) + 1;
    try {
      // Wait for agent readiness. Use a longer timeout for sessions we
      // just spawned, since the agent needs time to connect Socket.IO
      // and update lifecycleState before it can receive messages.
      final waitSpan = transaction.startChild(
        'chat.waitForAgent',
        description: 'Wait for agent readiness',
      );
      final spawnedAt = _sessionSpawnedAt[targetSessionId];
      final recentlySpawned =
          spawnedAt != null &&
          DateTime.now().millisecondsSinceEpoch - spawnedAt < 30000;
      final ready = await waitForAgentReady(
        targetSessionId,
        recentlySpawned ? 15000 : Sync.sessionReadyTimeoutMs,
      );
      waitSpan
        ..setData('ready', ready)
        ..setData('recentlySpawned', recentlySpawned);
      unawaited(
        waitSpan.finish(
          status: ready
              ? const SpanStatus.ok()
              : const SpanStatus.deadlineExceeded(),
        ),
      );
      if (!ready) {
        if (recentlySpawned) {
          logger.warning(
            '[sendMessage] recently spawned session did not become ready '
            'within timeout, sending anyway session=$targetSessionId',
          );
        }
        logger.info(
          '[sendMessage] agent not ready for '
          '$targetSessionId, sending anyway',
        );
      }

      final socketConnected = _isSocketConnected();
      logger.info(
        '[sendMessage] socketConnected=$socketConnected '
        'socketStatus=${socketIoClient.connectionStatus} '
        'session=$targetSessionId',
      );
      final postSpan = transaction.startChild(
        'http.client',
        description: 'POST /v3/sessions/$targetSessionId/messages',
      );
      final response = await apiClient.post(
        '/v3/sessions/$targetSessionId/messages',
        data: {
          'messages': [
            {'content': encryptedRawRecord, 'localId': localId},
          ],
        },
      );
      postSpan.setData('statusCode', response.statusCode ?? 0);
      unawaited(
        postSpan.finish(
          status: apiClient.isSuccess(response)
              ? const SpanStatus.ok()
              : SpanStatus.fromHttpStatusCode(response.statusCode ?? 500),
        ),
      );
      logger.info(
        '[sendMessage] POST '
        '/v3/sessions/$targetSessionId/messages '
        'status=${response.statusCode} '
        'localId=$localId',
      );

      if (apiClient.isSuccess(response)) {
        final data = WireParsers.asMap(response.data);
        final serverMessages = (data?['messages'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        logger.info(
          '[sendMessage] response contained '
          '${serverMessages.length} message(s) localId=$localId',
        );

        Map<String, dynamic>? ackedServerMsg;
        for (final msg in serverMessages) {
          if (msg['localId'] == localId) {
            ackedServerMsg = msg;
            break;
          }
        }

        if (ackedServerMsg != null) {
          sent = true;
          final serverId = ackedServerMsg['id'] as String?;
          final serverSeq = _asInt(ackedServerMsg['seq']);
          final serverCreatedAt = _asInt(ackedServerMsg['createdAt']);
          if (serverSeq != null) {
            catchUpStopAfterSeq = serverSeq;
          }
          logger.info(
            '[sendMessage] ACK localId=$localId '
            'serverId=${serverId ?? 'null'} '
            'seq=${serverSeq ?? -1}',
          );
          if (serverId != null &&
              serverSeq != null &&
              serverCreatedAt != null) {
            _upsertSessionMessages(targetSessionId, [
              {
                'id': serverId,
                'localId': localId,
                'seq': serverSeq,
                'createdAt': serverCreatedAt,
                'role': 'user',
                'kind': 'text',
                'content': text,
                'raw': rawRecord,
                'sendStatus': 'sent',
              },
            ]);
            _notifySessionMessagesChanged(targetSessionId);
          } else {
            // Mark sent even without full server fields.
            _updateMessageSendStatus(targetSessionId, localId, 'sent');
            _notifySessionMessagesChanged(targetSessionId);
            logger.warning(
              '[sendMessage] server ack missing '
              'id/seq/createdAt '
              'session=$targetSessionId localId=$localId',
            );
          }

          final socketNow = _isSocketConnected();
          if (socketNow) {
            logger.info(
              '[sendMessage] emitting socket message event '
              'session=$targetSessionId localId=$localId',
            );
            _socketSend('message', {
              'sid': targetSessionId,
              'message': encryptedRawRecord,
              'localId': localId,
            });
          } else {
            logger.warning(
              '[sendMessage] socket not connected, skipping '
              'daemon notification '
              'session=$targetSessionId localId=$localId',
            );
          }
        } else {
          logger.warning(
            '[sendMessage] REST send had no localId ack; '
            'falling back to socket emit '
            'session=$targetSessionId localId=$localId',
          );
          if (socketConnected) {
            _socketSend('message', {
              'sid': targetSessionId,
              'message': encryptedRawRecord,
              'localId': localId,
            });
            sent = true;
            _updateMessageSendStatus(targetSessionId, localId, 'sent');
            _notifySessionMessagesChanged(targetSessionId);
          } else {
            throw StateError(
              'Failed to send message: '
              'server did not acknowledge message',
            );
          }
        }

        if (sent && messagesSync.containsKey(targetSessionId)) {
          _startPostSendCatchUp(
            targetSessionId,
            stopAfterSeq: catchUpStopAfterSeq,
          );
        }
      } else {
        logger.error(
          '[sendMessage] FAILED: status=${response.statusCode} '
          'session=$targetSessionId '
          'body=${response.data}',
        );
        throw StateError('Failed to send message: ${response.statusCode}');
      }
      await transaction.finish(status: const SpanStatus.ok());
    } catch (e, stack) {
      logger.error('[sendMessage] error sending', e, stack);
      transaction.setData('error', e.toString());
      await transaction.finish(status: const SpanStatus.internalError());
      if (!sent && e is _AgentStartupTimeout) {
        _updateMessageSendStatus(targetSessionId, localId, 'failed');
        _notifySessionMessagesChanged(targetSessionId);
      } else if (!sent) {
        // Queue in the outbox for automatic retry with backoff.
        final entry = OutboxEntry(
          localId: localId,
          sessionId: targetSessionId,
          text: text,
          encryptedContent: encryptedRawRecord,
          rawRecord: rawRecord,
          queuedAt: DateTime.now().millisecondsSinceEpoch,
        );
        unawaited(messageOutbox.add(entry));
        // The outbox onStatusChanged callback sets 'pending' status.
      }
    }
    // Notify so the UI picks up status changes (sent/failed/pending).
    if (!_sessionMessageChangeController.isClosed) {
      _sessionMessageChangeController.add(targetSessionId);
    }
  }

  /// Outbox delivery callback: re-attempt a single queued message.
  ///
  /// Returns `true` on success, `false` to schedule a retry.
  Future<bool> _deliverOutboxEntry(OutboxEntry entry) async {
    if (!isInitialized) return false;

    final apiClient = ApiClient();
    try {
      final response = await apiClient.post(
        '/v3/sessions/${entry.sessionId}/messages',
        data: {
          'messages': [
            {'content': entry.encryptedContent, 'localId': entry.localId},
          ],
        },
      );

      if (!apiClient.isSuccess(response)) {
        logger.warning(
          '[MessageOutbox] re-send failed '
          'status=${response.statusCode} '
          'localId=${entry.localId}',
        );
        return false;
      }

      final data = WireParsers.asMap(response.data);
      final serverMessages = (data?['messages'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();

      Map<String, dynamic>? ackedMsg;
      for (final msg in serverMessages) {
        if (msg['localId'] == entry.localId) {
          ackedMsg = msg;
          break;
        }
      }

      if (ackedMsg != null) {
        final serverId = ackedMsg['id'] as String?;
        final serverSeq = _asInt(ackedMsg['seq']);
        final serverCreatedAt = _asInt(ackedMsg['createdAt']);
        if (serverId != null && serverSeq != null && serverCreatedAt != null) {
          _upsertSessionMessages(entry.sessionId, [
            {
              'id': serverId,
              'localId': entry.localId,
              'seq': serverSeq,
              'createdAt': serverCreatedAt,
              'role': 'user',
              'kind': 'text',
              'content': entry.text,
              'raw': entry.rawRecord,
              'sendStatus': 'sent',
            },
          ]);
        } else {
          // Mark sent even without full server fields — matches
          // the else-case in _completeSend.  Without this the
          // optimistic placeholder stays stuck in "sending" state
          // forever after the outbox removes the entry.
          _updateMessageSendStatus(entry.sessionId, entry.localId, 'sent');
          _notifySessionMessagesChanged(entry.sessionId);
          logger.warning(
            '[MessageOutbox] server ack missing id/seq/createdAt '
            'session=${entry.sessionId} '
            'localId=${entry.localId}',
          );
        }
        if (_isSocketConnected()) {
          _socketSend('message', {
            'sid': entry.sessionId,
            'message': entry.encryptedContent,
            'localId': entry.localId,
          });
        }
        if (messagesSync.containsKey(entry.sessionId)) {
          _startPostSendCatchUp(entry.sessionId, stopAfterSeq: serverSeq ?? 0);
        }
        logger.info(
          '[MessageOutbox] delivered localId=${entry.localId} '
          'session=${entry.sessionId}',
        );
        return true;
      }

      // Server accepted but no localId ack. Trust the HTTP 200 since the
      // server uses idempotent storage (ON CONFLICT DO NOTHING).
      logger.warning(
        '[MessageOutbox] no localId ack '
        'localId=${entry.localId} — HTTP 200 accepted, treating as delivered',
      );
      return true;
    } catch (e, stack) {
      // Exceptions during local processing (after HTTP 200 was received)
      // do NOT count as delivery failures — the server has already stored
      // the message. Only non-2xx responses count as real failures.
      // Counting exceptions as failures risks permanently losing a message
      // that the server already has (e.g., after 3 retries the client marks
      // it as failed even though the server stored it).
      logger.error(
        '[MessageOutbox] local processing threw after HTTP 200 '
        'localId=${entry.localId} — '
        'server has message, treating as delivered',
        e,
        stack,
      );
      return true;
    }
  }

  /// Update the `sendStatus` field of an optimistic message in-place.
  void _updateMessageSendStatus(
    String sessionId,
    String localId,
    String status,
  ) {
    final msgs = _sessionMessages[sessionId];
    if (msgs == null) return;
    for (var i = 0; i < msgs.length; i++) {
      final m = msgs[i];
      if (m['localId'] == localId || m['id'] == localId) {
        msgs[i] = {...m, 'sendStatus': status};
        _sessionMessagesCache = null;
        _sessionMessagesViewCache.remove(sessionId);
        break;
      }
    }
  }

  /// Retry a failed message send.
  ///
  /// Re-queues the message in the outbox with reset retry count.
  /// The message must have a 'raw' field containing the original
  /// unencrypted message record.
  Future<void> retryFailedMessage(String sessionId, String localId) async {
    final msgs = _sessionMessages[sessionId];
    if (msgs == null) {
      logger.warning('[retryFailedMessage] session not found: $sessionId');
      return;
    }

    // Find the failed message
    Map<String, dynamic>? failedMessage;
    for (final m in msgs) {
      if (m['localId'] == localId || m['id'] == localId) {
        failedMessage = m;
        break;
      }
    }

    if (failedMessage == null) {
      logger.warning(
        '[retryFailedMessage] message not found: '
        'sessionId=$sessionId localId=$localId',
      );
      return;
    }

    // Get the raw record from the message
    final raw = failedMessage['raw'];
    if (raw == null || raw is! Map<String, dynamic>) {
      logger.warning(
        '[retryFailedMessage] message missing raw data: localId=$localId',
      );
      return;
    }

    final text =
        failedMessage['text'] as String? ??
        failedMessage['content'] as String? ??
        '';

    // Get session encryption
    var sessionEncryption = encryption.getSessionEncryption(sessionId);
    if (sessionEncryption == null) {
      logger.info(
        '[retryFailedMessage] encryption missing for session=$sessionId, '
        'attempting recovery',
      );
      await fetchSingleSession(sessionId);
      sessionEncryption = encryption.getSessionEncryption(sessionId);
    }
    if (sessionEncryption == null) {
      logger.warning(
        '[retryFailedMessage] cannot get encryption for session=$sessionId',
      );
      return;
    }

    // Re-encrypt the raw record
    final encryptedRawRecord = await sessionEncryption.encryptRawRecord(raw);

    // Create and queue the outbox entry
    final entry = OutboxEntry(
      localId: localId,
      sessionId: sessionId,
      text: text,
      encryptedContent: encryptedRawRecord,
      rawRecord: raw,
      queuedAt: DateTime.now().millisecondsSinceEpoch,
      retryCount: 0, // Reset retry count
    );

    // Update status to 'sending' before queuing
    _updateMessageSendStatus(sessionId, localId, 'sending');

    // Add to outbox
    await messageOutbox.add(entry);

    logger.info(
      '[retryFailedMessage] queued for retry: '
      'sessionId=$sessionId localId=$localId',
    );

    // Notify listeners
    _notifySessionMessagesChanged(sessionId);
  }

  void _startPostSendCatchUp(String sessionId, {required int stopAfterSeq}) {
    _postSendCatchUpTimers.remove(sessionId)?.cancel();
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    // Immediate fetch so we do not wait for the first timer tick.
    messagesSync[sessionId]?.invalidate();

    _postSendCatchUpTimers[sessionId] = Timer.periodic(
      const Duration(seconds: 10),
      (timer) {
        if (!isInitialized ||
            !messagesSync.containsKey(sessionId) ||
            DateTime.now().isAfter(deadline)) {
          timer.cancel();
          _postSendCatchUpTimers.remove(sessionId);
          logger.info(
            '[sendMessage] catch-up polling ended '
            'session=$sessionId reason=timeout_or_inactive',
          );
          return;
        }

        final currentSeq = _sessionLastSeq[sessionId] ?? 0;
        if (currentSeq > stopAfterSeq) {
          timer.cancel();
          _postSendCatchUpTimers.remove(sessionId);
          logger.info(
            '[sendMessage] catch-up polling ended '
            'session=$sessionId reason=seq_advanced '
            'stopAfter=$stopAfterSeq current=$currentSeq',
          );
          return;
        }

        // If already caught up (cursor == serverLastSeq), skip the
        // HTTP round-trip — the agent hasn't produced a response yet,
        // and socket events will advance the seq when it does.
        final session = _sessions[sessionId];
        final serverLastSeq = session?.lastSeq ?? 0;
        if (currentSeq > 0 &&
            serverLastSeq > 0 &&
            currentSeq >= serverLastSeq) {
          return;
        }

        // Skip polling for non-visible sessions — socket events already
        // trigger message fetches via _handleNewMessage, so the periodic
        // poll is redundant and wastes HTTP round-trips (each returning 0
        // messages).  When the user navigates back, onSessionVisible()
        // triggers a fresh fetch to pick up anything missed.
        // However, if socket events were missed (connection drop), the
        // invalidation below ensures catch-up via HTTP on next poll.
        messagesSync[sessionId]?.invalidate();
        if (sessionId != _visibleSessionId) {
          return;
        }
      },
    );
  }
}
