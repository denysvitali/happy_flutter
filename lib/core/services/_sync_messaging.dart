part of 'sync_service.dart';

extension _SyncMessaging on Sync {
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
      );
      _sessions[sessionId] = session;
      _notifyDataChanged();
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
    final sendTransaction = Sentry.startTransaction(
      'chat.sendMessage',
      'task',
      bindToScope: false,
    )
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
      unawaited(waitSpan.finish(
        status: ready
            ? const SpanStatus.ok()
            : const SpanStatus.deadlineExceeded(),
      ));
      if (!ready) {
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
        description:
            'POST /v3/sessions/$targetSessionId/messages',
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
      unawaited(postSpan.finish(
        status: apiClient.isSuccess(response)
            ? const SpanStatus.ok()
            : SpanStatus.fromHttpStatusCode(
                response.statusCode ?? 500,
              ),
      ));
      logger.info(
        '[sendMessage] POST '
        '/v3/sessions/$targetSessionId/messages '
        'status=${response.statusCode} '
        'localId=$localId',
      );

      if (apiClient.isSuccess(response)) {
        final data = response.data as Map<String, dynamic>?;
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
      if (!sent) {
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
            {
              'content': entry.encryptedContent,
              'localId': entry.localId,
            },
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

      final data = response.data as Map<String, dynamic>?;
      final serverMessages =
          (data?['messages'] as List<dynamic>? ?? [])
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
        if (serverId != null &&
            serverSeq != null &&
            serverCreatedAt != null) {
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
        }
        if (_isSocketConnected()) {
          _socketSend('message', {
            'sid': entry.sessionId,
            'message': entry.encryptedContent,
            'localId': entry.localId,
          });
        }
        if (messagesSync.containsKey(entry.sessionId)) {
          _startPostSendCatchUp(
            entry.sessionId,
            stopAfterSeq: serverSeq ?? 0,
          );
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
  Future<void> retryFailedMessage(
    String sessionId,
    String localId,
  ) async {
    final msgs = _sessionMessages[sessionId];
    if (msgs == null) {
      logger.warning(
        '[retryFailedMessage] session not found: $sessionId',
      );
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

    final text = failedMessage['text'] as String? ??
        failedMessage['content'] as String? ?? '';

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

  /// RPC call for machines - uses machine-specific encryption.
  Future<dynamic> machineRPC(
    String machineId,
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final machineEncryption = encryption.getMachineEncryption(machineId);
    if (machineEncryption == null) {
      throw StateError('Machine encryption not found for $machineId');
    }

    final encrypted = await machineEncryption.encryptRaw(params);
    final result = await socketIoClient.emitWithAck('rpc-call', {
      'method': '$machineId:$method',
      'params': encrypted,
    }, timeout: timeout);

    if (result is Map && result['ok'] == true) {
      final encryptedResult = result['result'] as String?;
      if (encryptedResult == null) {
        throw StateError('Machine RPC $method returned null result');
      }
      final decrypted = await machineEncryption.decryptRaw(encryptedResult);
      if (decrypted == null) {
        logger.warning('machineRPC $method: decryption returned null');
      }
      return decrypted;
    }
    // Log the failure reason if available
    final errorMsg = result is Map ? result['error'] : result;
    throw StateError('Machine RPC $method failed: $errorMsg');
  }

  /// RPC call for sessions - uses session-specific encryption.
  Future<dynamic> sessionRPC(
    String sessionId,
    String method,
    Map<String, dynamic> params,
  ) async {
    var sessionEncryption = encryption.getSessionEncryption(sessionId);
    if (sessionEncryption == null) {
      unawaited(Sentry.addBreadcrumb(Breadcrumb(
        message: 'fetchMessages: encryption null, '
            'awaiting sessions',
        category: 'sync.messages',
        data: {'sessionId': sessionId},
      )));
      // Encryption may not be initialized yet — wait for pending fetch.
      await sessionsSync.invalidateAndAwait();
      sessionEncryption = encryption.getSessionEncryption(sessionId);
      if (sessionEncryption == null) {
        // Force a full fetch in case changedSince race skipped the session.
        _forceFullFetchNext = true;
        await sessionsSync.invalidateAndAwait();
        sessionEncryption = encryption.getSessionEncryption(sessionId);
      }
      if (sessionEncryption == null) {
        throw StateError('Session encryption not found for $sessionId');
      }
    }

    final encrypted = await sessionEncryption.encryptRaw(params);
    final result = await socketIoClient.emitWithAck('rpc-call', {
      'method': '$sessionId:$method',
      'params': encrypted,
    });

    if (result is Map && result['ok'] == true) {
      final encryptedResult = result['result'] as String?;
      if (encryptedResult == null) return null;
      final decrypted = await sessionEncryption.decryptRaw(encryptedResult);
      return decrypted;
    }
    // Log the failure reason if available
    final errorMsg = result is Map ? result['error'] : result;
    throw StateError('Session RPC $method failed: $errorMsg');
  }

  /// Typed wrapper around [machineRPC] that deserialises the response.
  Future<Resp> _typedMachineRPC<Resp>(
    String machineId,
    String method,
    Map<String, dynamic> params,
    Resp Function(Map<String, dynamic>) fromJson, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final override = testMachineRPCOverride;
    final raw = override != null
        ? await override(machineId, method, params)
        : await machineRPC(machineId, method, params, timeout: timeout);
    // Handle null or non-Map responses gracefully
    if (raw == null) {
      throw StateError(
        'Machine RPC $method returned null - encryption may have failed',
      );
    }
    if (raw is! Map<String, dynamic>) {
      throw StateError(
        'Machine RPC $method returned unexpected type: ${raw.runtimeType} '
        '(value: $raw)',
      );
    }
    return fromJson(raw);
  }

  /// Typed wrapper around [sessionRPC] that deserialises the response.
  Future<Resp> _typedSessionRPC<Resp>(
    String sessionId,
    String method,
    Map<String, dynamic> params,
    Resp Function(Map<String, dynamic>) fromJson,
  ) async {
    final raw = await sessionRPC(sessionId, method, params);
    // Handle null or non-Map responses gracefully
    if (raw == null) {
      throw StateError(
        'Session RPC $method returned null - encryption may have failed',
      );
    }
    if (raw is! Map<String, dynamic>) {
      throw StateError(
        'Session RPC $method returned unexpected type: ${raw.runtimeType} '
        '(value: $raw)',
      );
    }
    return fromJson(raw);
  }

  /// Checks whether the session's CLI process is running.
  ///
  /// If the session is already online or starting/running, returns
  /// `false` (no restore needed).  If the session is offline and has
  /// `machineId`/`path` metadata, sends `spawn-happy-session` to
  /// revive it and returns `true` to signal that a **new** process
  /// was spawned (meaning old in-flight state like pending permissions
  /// is gone).
  ///
  /// Returns `false` when no restore was attempted (session was
  /// already ready, or metadata was missing).
  Future<bool> _ensureSessionProcess(String sessionId) async {
    final session = _sessions[sessionId];
    if (session == null) return false;

    final lifecycleState = session.metadata?.lifecycleState;
    // Guard against stale lifecycleState
    // (same logic as _resolveSendTargetSession).
    final lifecycleStateSince = session.metadata?.lifecycleStateSince;
    final lifecycleRecent =
        lifecycleStateSince != null &&
        DateTime.now().millisecondsSinceEpoch - lifecycleStateSince < 120000;
    final agentIsStartingOrRunning =
        lifecycleState == 'starting' || lifecycleState == 'running';
    final isArchived = lifecycleState == 'archived';
    final looksReady =
        !isArchived &&
        (session.isOnline || (agentIsStartingOrRunning && lifecycleRecent));
    if (looksReady) return false;

    final machineId = session.metadata?.machineId;
    final path = session.metadata?.path;
    if (machineId == null ||
        machineId.isEmpty ||
        path == null ||
        path.isEmpty) {
      return false;
    }

    logger.info(
      '[permission] session=$sessionId appears offline '
      '(presence=${session.presence}, '
      'lifecycleState=$lifecycleState); '
      'attempting auto-restore',
    );

    try {
      // Resolve profile env vars for this session before spawning.
      final spawnResult =
          await _getSpawnEnvVarsForSession(sessionId);
      final req = SpawnSessionRequest(
        type: 'spawn-in-directory',
        directory: path,
        sessionId: sessionId,
        agent: session.metadata?.flavor ?? 'claude',
        permissionMode: session.permissionMode,
        model: _getModelOverride(profile: spawnResult.profile),
        environmentVariables: spawnResult.envVars,
      );
      final result = await _typedMachineRPC(
        machineId,
        'spawn-happy-session',
        req.toJson(),
        SpawnSessionResponse.fromJson,
        timeout: const Duration(seconds: 60),
      );
      if (result.type == 'success') {
        logger.info(
          '[permission] auto-restore succeeded '
          'session=$sessionId',
        );
        return true;
      }
      logger.warning(
        '[permission] auto-restore not successful '
        'session=$sessionId type=${result.type ?? 'null'} '
        'error=${result.errorMessage ?? 'unknown'}',
      );
    } catch (error) {
      if (Sync._isTransientConnectionError(error)) {
        logger.info(
          '[permission] auto-restore failed (transient) '
          'session=$sessionId: $error',
        );
      } else {
        logger.warning(
          '[permission] auto-restore failed '
          'session=$sessionId: $error',
        );
      }
    }
    return false;
  }

  /// Fire local notifications for any newly-detected pending
  /// permission requests that the user hasn't seen yet.
  ///
  /// Called after [fetchSessions] merges updated sessions and
  /// after inline socket updates apply new agent state.
  void _checkForNewPermissionRequests(
    Iterable<Session> sessions,
  ) {
    for (final session in sessions) {
      // Don't notify for the session the user is viewing — they
      // can see the permission footer already.
      if (session.id == _visibleSessionId) continue;

      final requests = session.agentState?.requests;
      if (requests == null || requests.isEmpty) continue;

      for (final entry in requests.entries) {
        final permId = entry.key;
        if (_notifiedPermissionIds.contains(permId)) continue;
        // Evict oldest entries when the cap is reached to bound memory.
        if (_notifiedPermissionIds.length >= Sync._maxNotifiedPermissionIds) {
          _notifiedPermissionIds
              .remove(_notifiedPermissionIds.first);
        }
        _notifiedPermissionIds.add(permId);

        final request = entry.value;
        Map<String, dynamic>? toolInput;
        if (request.arguments is Map) {
          toolInput =
              Map<String, dynamic>.from(request.arguments as Map);
        }

        final sessionName =
            session.metadata?.summary?.text ??
            session.metadata?.path?.split('/').last;

        unawaited(
          NotificationService.instance.showPermissionNotification(
            sessionId: session.id,
            permissionId: permId,
            toolName: request.tool,
            toolInput: toolInput,
            sessionName: sessionName,
          ),
        );
      }
    }
  }

  /// Locally clear stale permission requests from a session's
  /// [AgentState] so the UI immediately unlocks the input box
  /// and hides the "permission required" banner.
  void _clearStalePermissionRequests(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return;
    final hadRequests =
        session.agentState?.requests != null &&
        session.agentState!.requests!.isNotEmpty;
    if (hadRequests) {
      // Cancel any pending permission notifications for this session.
      for (final permId in session.agentState!.requests!.keys) {
        _notifiedPermissionIds.remove(permId);
        unawaited(
          NotificationService.instance
              .cancelPermissionNotification(permId),
        );
      }
      _sessions[sessionId] = session.copyWith(
        agentState: AgentState(
          controlledByUser: session.agentState?.controlledByUser,
          completedRequests: session.agentState?.completedRequests,
        ),
      );
    }
    // Also cancel any pending permissions on tool-call messages so
    // the UI stops showing Allow/Deny buttons that will always fail.
    final messages = _sessionMessages[sessionId];
    if (messages != null) {
      var changed = false;
      final updated = List<Map<String, dynamic>>.from(messages);
      for (var i = 0; i < updated.length; i++) {
        final msg = updated[i];
        if (msg['kind'] != 'tool-call') continue;
        final perm = msg['permission'] as Map<String, dynamic>?;
        if (perm == null || perm['status'] != 'pending') continue;
        updated[i] = {
          ...msg,
          'permission': {...perm, 'status': 'canceled'},
        };
        changed = true;
      }
      if (changed) {
        _sessionMessages[sessionId] = updated;
        _sessionMessagesCache = null;
        _sessionMessagesViewCache.remove(sessionId);
        _notifySessionMessagesChanged(sessionId);
      }
    }
    if (hadRequests || messages != null) {
      _notifyDataChanged();
    }
  }

  /// Allow a permission request for a session.
  ///
  /// The server acknowledges with `ok: true` but the response
  /// payload shape varies — the RN app ignores it entirely, so
  /// we just fire-and-forget the RPC without deserialising.
  Future<void> sessionAllow(
    String sessionId,
    String permissionId, {
    String? mode,
    List<String>? allowTools,
    String? decision,
    Map<String, dynamic>? updatedInput,
  }) async {
    final restored = await _ensureSessionProcess(sessionId);
    if (restored) {
      _clearStalePermissionRequests(sessionId);
      sessionsSync.invalidate();
      messagesSync[sessionId]?.invalidate();
      throw StateError(
        'Session was restarted — this permission has expired. '
        'The agent will re-request it if still needed.',
      );
    }
    try {
      final response = await sessionRPC(
        sessionId,
        'permission',
        PermissionRequest(
          id: permissionId,
          approved: true,
          mode: mode,
          allowTools: allowTools,
          decision: decision,
          updatedInput: updatedInput,
        ).toJson(),
      );
      _throwIfPermissionRpcFailed(response, 'allow');
    } on StateError {
      // Permission was rejected by the server — clear stale local
      // state so the UI unlocks.
      _clearStalePermissionRequests(sessionId);
      rethrow;
    } finally {
      sessionsSync.invalidate();
      messagesSync[sessionId]?.invalidate();
    }
  }

  /// Deny a permission request for a session.
  ///
  /// See [sessionAllow] — response payload is ignored.
  Future<void> sessionDeny(
    String sessionId,
    String permissionId, {
    String? decision,
  }) async {
    final restored = await _ensureSessionProcess(sessionId);
    if (restored) {
      _clearStalePermissionRequests(sessionId);
      sessionsSync.invalidate();
      messagesSync[sessionId]?.invalidate();
      throw StateError(
        'Session was restarted — this permission has expired. '
        'The agent will re-request it if still needed.',
      );
    }
    try {
      final response = await sessionRPC(
        sessionId,
        'permission',
        PermissionRequest(
          id: permissionId,
          approved: false,
          decision: decision,
        ).toJson(),
      );
      _throwIfPermissionRpcFailed(response, 'deny');
    } on StateError {
      _clearStalePermissionRequests(sessionId);
      rethrow;
    } finally {
      sessionsSync.invalidate();
      messagesSync[sessionId]?.invalidate();
    }
  }

  void _throwIfPermissionRpcFailed(dynamic response, String action) {
    if (response is! Map) return;
    final success = response['success'];
    final ok = response['ok'];
    final isFailure = success == false || ok == false;
    if (!isFailure) return;
    final error = response['error'];
    throw StateError(
      'Permission $action failed: ${error?.toString() ?? 'unknown error'}',
    );
  }

  /// Kill a session's agent process.
  Future<KillSessionResponse> killSession(String sessionId) async {
    return _typedSessionRPC(
      sessionId,
      'killSession',
      const {},
      KillSessionResponse.fromJson,
    );
  }

  /// Abort the current agent turn without killing the session.
  Future<AbortResponse> abortSession(
    String sessionId, {
    String reason = '',
  }) async {
    return _typedSessionRPC(sessionId, 'abort', {
      'reason': reason,
    }, AbortResponse.fromJson);
  }

  /// Apply settings delta
  Future<void> applySettings(Map<String, dynamic> delta) async {
    _settingsSnapshot = Settings.fromJson({
      ..._settingsSnapshot.toJson(),
      ...delta,
    });
    pendingSettings = {...pendingSettings, ...delta};
    settingsSync.invalidate();
  }

  /// Refresh purchases data
  Future<void> refreshPurchases() async {
    purchasesSync.invalidate();
  }

  /// Refresh profile data
  Future<void> refreshProfile() async {
    await profileSync.invalidateAndAwait();
  }

  /// Get authentication credentials
  AuthCredentials getCredentials() {
    return credentials;
  }

  /// On session visible handler
  void onSessionVisible(String sessionId) {
    _visibleSessionId = sessionId;
    _sessionUnreadCounts.remove(sessionId);
    _sessionUnreadLastIncrementMs.remove(sessionId);
    // Clear any residual failed Future from the inline queue so that
    // new messages can enter the inline fast path immediately.
    _inlineProcessor.clearSession(sessionId);
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'onSessionVisible',
      category: 'sync.messages',
      data: {
        'sessionId': sessionId,
        'hasPending':
            _sessionsWithPendingSocketMessages
                .contains(sessionId),
        'hasMessagesInMemory':
            _sessionMessages[sessionId]
                    ?.isNotEmpty ??
                false,
        'cursorSeq':
            _sessionLastSeq[sessionId] ?? 0,
        'serverLastSeq':
            _sessions[sessionId]?.lastSeq ?? 0,
      },
    ));

    // If this session received socket messages while non-visible, we MUST
    // fetch from the server to get those messages.  Socket messages are NOT
    // stored in _sessionMessages for non-visible sessions (only the seq
    // cursor is advanced), so the cache may be stale even if it has data.
    final hasPendingSocketMessages =
        _sessionsWithPendingSocketMessages.remove(sessionId);

    // Only tail-refresh when we have no messages in memory for this session
    // (first open or after restart).  When messages are already loaded the
    // incremental delta path (afterSeq = _sessionLastSeq) is sufficient and
    // avoids re-downloading the last 200 messages on every navigation.
    var hasMessages =
        _sessionMessages.containsKey(sessionId) &&
        (_sessionMessages[sessionId]?.isNotEmpty ?? false);

    logger.info(
      '[onSessionVisible] sessionId=$sessionId '
      'hasPendingSocketMessages=$hasPendingSocketMessages '
      'hasMessagesInMemory=$hasMessages '
      'cursorSeq=${_sessionLastSeq[sessionId] ?? 0} '
      'serverLastSeq=${_sessions[sessionId]?.lastSeq ?? 0}',
    );

    if (!hasMessages) {
      // Restore from MMKV cache so the UI shows messages immediately
      // while the HTTP fetch is in flight.  Even when
      // hasPendingSocketMessages is true, show the (possibly stale)
      // cache as a starting point — the user sees *something* instead
      // of a loading spinner for 5-15s while the server fetch runs.
      // The incremental delta fetch will fill in any missing messages.
      final cached = MessageCacheService().getMessages(sessionId);
      logger.info(
        '[onSessionVisible] cacheRestore: ${cached.length} '
        'cached messages '
        '(hasPendingSocket=$hasPendingSocketMessages)',
      );
      if (cached.isNotEmpty) {
        // Strip orphaned sidechain messages (see
        // _restoreAllCachedMessages).
        final clean = cached.any((m) => m['isSidechain'] == true)
            ? cached.where((m) => m['isSidechain'] != true).toList()
            : cached;
        if (clean.isNotEmpty) {
          _sessionMessages[sessionId] = clean;
          _sessionMessagesCache = null;
          _sessionMessagesViewCache.remove(sessionId);
          hasMessages = true;
          // Notify UI immediately so it can render cached messages.
          _notifySessionMessagesChanged(sessionId);
          _notifyDataChanged();
        }
      }
      // Only request a tail refresh when there are NO messages to show.
      // When cache was restored, the incremental delta path (afterSeq =
      // _sessionLastSeq) is sufficient and avoids a destructive
      // gap-recovery that clears the cached messages the user already
      // sees.  The delta fetch will pick up newer messages and merge
      // them with the cache.
      if (!hasMessages) {
        _requestTailRefresh(sessionId);
        logger.info(
          '[onSessionVisible] tailRefresh requested '
          '(hasMessages=$hasMessages '
          'hasPendingSocket=$hasPendingSocketMessages)',
        );
      }
    } else {
      // Messages are in memory (from cache or previous load). Check if the
      // server has newer messages that we're missing. This handles the case
      // where the app was closed and new messages arrived — delta sync may
      // not update session.lastSeq if only messages changed (no metadata).
      final cursorSeq = _sessionLastSeq[sessionId] ?? 0;
      final serverLastSeq = _sessions[sessionId]?.lastSeq ?? 0;
      final hadPendingUpdates = _sessionsWithPendingUpdates.remove(sessionId);

      logger.info(
        '[onSessionVisible] hasMessages path: cursorSeq=$cursorSeq '
        'serverLastSeq=$serverLastSeq hadPendingUpdates=$hadPendingUpdates',
      );

      // Check for gap: server is ahead of our cursor
      if (cursorSeq > 0 && serverLastSeq > cursorSeq) {
        // Server has messages we haven't seen. Let fetchMessages handle it
        // via the normal incremental delta path (or gapTooLarge tail-load).
        logger.info(
          '[onSessionVisible] gap detected: '
          'server($serverLastSeq) > cursor($cursorSeq) — will fetch delta',
        );
      } else if (hadPendingUpdates) {
        // Socket events arrived while session was non-visible, but cursor
        // appears caught up or ahead.  Only tail-refresh when cursor data
        // is truly invalid (zero/negative).  When cursor >= server, the
        // incremental delta fetch is either a no-op (caught up) or will
        // pick up any remaining messages — a destructive tail-refresh
        // would unnecessarily wipe and re-download messages.
        if (cursorSeq <= 0 || serverLastSeq <= 0) {
          _requestTailRefresh(sessionId);
          logger.info(
            '[onSessionVisible] tailRefresh '
            '(pending updates, invalid cursor)',
          );
        }
      }
    }
    if (!messagesSync.containsKey(sessionId)) {
      messagesSync[sessionId] = InvalidateSync(
        () => fetchMessages(sessionId),
        minInterval: Sync._messagesSyncMinInterval,
        name: 'fetchMessages:$sessionId',
      );
    }
    messagesSync[sessionId]?.invalidate();
  }

  void _requestTailRefresh(String sessionId) {
    _sessionsNeedingTailRefresh.add(sessionId);
  }

  int _tailAfterSeqForSession(String sessionId) {
    return _cursorManager.tailAfterSeq(
      sessionId,
      serverLastSeq:
          _sessions[sessionId]?.lastSeq ?? 0,
      initialLoad: Sync.initialLoad,
    );
  }

  /// Fetch messages for a session.
  ///
  /// On first open (no entry in [_sessionLastSeq]) this uses the session's
  /// [Session.lastSeq] hint to jump straight to the tail of the history,
  /// fetching only the most recent [Sync.initialLoad] messages.  Subsequent calls
  /// (incremental delta syncs) continue from [_sessionLastSeq] as before.
  Future<void> fetchMessages(String sessionId) async {
    logger.info(
      'Fetching messages for session: $sessionId',
    );
    final fetchStopwatch = Stopwatch()..start();

    // Start a Sentry span for this fetch operation
    final fetchSpan = Sentry.getSpan()?.startChild(
      'sync.fetchMessages',
      description: 'Fetch messages for session $sessionId',
    );
    fetchSpan?.setData('sessionId', sessionId);

    var sessionEncryption =
        encryption.getSessionEncryption(sessionId);
    if (sessionEncryption == null) {
      final encSpan = fetchSpan?.startChild(
        'sync.encryption.init',
        description: 'Wait for session encryption',
      );
      unawaited(Sentry.addBreadcrumb(Breadcrumb(
        message: 'fetchMessages: encryption null, '
            'awaiting sessions',
        category: 'sync.messages',
        data: {'sessionId': sessionId},
      )));
      // Encryption may not be initialized yet — wait for pending fetch.
      await sessionsSync.invalidateAndAwait();
      sessionEncryption = encryption.getSessionEncryption(sessionId);
      if (sessionEncryption == null) {
        // Force a full fetch in case changedSince race skipped the session.
        _forceFullFetchNext = true;
        await sessionsSync.invalidateAndAwait();
        sessionEncryption = encryption.getSessionEncryption(sessionId);
      }
      if (encSpan != null) unawaited(encSpan.finish());
      if (sessionEncryption == null) {
        logger.warning(
          'Session encryption not initialized for '
          '$sessionId after 2 attempts, skipping',
        );
        fetchSpan?.setData('status', 'preconditionFailed');
        fetchSpan?.setData('encryptionInitFailed', true);
        fetchSpan?.setData('elapsedMs', fetchStopwatch.elapsedMilliseconds);
        if (fetchSpan != null) unawaited(fetchSpan.finish());
        unawaited(Sentry.addBreadcrumb(Breadcrumb(
          message: 'fetchMessages: encryption still '
              'null after 2 attempts',
          category: 'sync.messages',
          level: SentryLevel.warning,
          data: {
            'sessionId': sessionId,
            'sessionExists':
                _sessions.containsKey(sessionId),
            'elapsedMs':
                fetchStopwatch.elapsedMilliseconds,
          },
        )));
        // Notify UI so the loading spinner clears.
        _notifySessionMessagesChanged(sessionId);
        _notifyDataChanged();
        return;
      }
    }

    try {
      final apiClient = ApiClient();
      // "First load" means no messages are in memory yet for this session
      // (new session or app was restarted — _sessionMessages is not
      // persisted to disk).  In this case we do a tail-load using the
      // server's lastSeq hint regardless of the persisted _sessionLastSeq.
      final isFirstLoad =
          !_sessionMessages.containsKey(sessionId) ||
          (_sessionMessages[sessionId]?.isEmpty ?? true);
      final forceTailRefresh = _sessionsNeedingTailRefresh.remove(sessionId);
      int afterSeq;

      // Detect large gaps: when the cursor is far behind the session's
      // current lastSeq, forward-crawling page by page is extremely slow
      // (100 msgs/page × decrypt × O(n) grouping per page).  Fall back
      // to a tail-load so we only fetch the most recent messages.
      final cursorSeq = _sessionLastSeq[sessionId] ?? 0;
      final serverLastSeq = _sessions[sessionId]?.lastSeq ?? 0;
      final gapTooLarge =
          !isFirstLoad &&
          !forceTailRefresh &&
          serverLastSeq > 0 &&
          cursorSeq <= serverLastSeq &&
          (serverLastSeq - cursorSeq) > Sync.initialLoad;

      logger.info(
        '[fetchMessages] $sessionId '
        'isFirstLoad=$isFirstLoad '
        'forceTailRefresh=$forceTailRefresh '
        'gapTooLarge=$gapTooLarge '
        'cursorSeq=$cursorSeq '
        'serverLastSeq=$serverLastSeq',
      );

      // Skip the HTTP round-trip when the cursor is at or ahead of the
      // server's known lastSeq — there is nothing to fetch.  Socket
      // events (new-message) update _sessionLastSeq via inline processing
      // for the visible session and can push cursor PAST the server's
      // lastSeq (since session.lastSeq lags behind socket events).
      // We guard with !hasGap so we don't skip when cursor > serverLastSeq —
      // that indicates socket events may have outpaced the server and we
      // should fetch to ensure no messages were missed.
      final hasGap = serverLastSeq > 0 && cursorSeq <= serverLastSeq &&
          (serverLastSeq - cursorSeq) > Sync.initialLoad;
      if (!isFirstLoad &&
          cursorSeq > 0 &&
          serverLastSeq > 0 &&
          cursorSeq == serverLastSeq &&
          !hasGap) {
        logger.info(
          '[fetchMessages] $sessionId already caught up '
          '(cursor=$cursorSeq server=$serverLastSeq) '
          '— skipping',
        );
        // Notify UI so any pending loading state clears.
        _notifySessionMessagesChanged(sessionId);
        return;
      }

      // Track that we're doing a tail-load gap recovery. We'll clear
      // stale messages AFTER the first page succeeds to avoid losing
      // messages if the network request fails. Declared early so it's
      // accessible in the while loop below.
      // Note: gapTooLarge is computed with !forceTailRefresh to short-circuit,
      // so we must use || here to ensure stale clearing happens for both
      // explicit tail-refresh requests AND large-gap detections.
      final isGapRecovery = gapTooLarge || forceTailRefresh;
      if (isFirstLoad || forceTailRefresh || gapTooLarge) {
        // Lazy tail-load: start near the end of the session
        // history so we don't download thousands of messages
        // that the UI will never show.
        //
        // For first load and tail refresh, compute the
        // window from the known max seq, ignoring the cursor.
        if (isFirstLoad || forceTailRefresh) {
          final knownMax = max(cursorSeq, serverLastSeq);
          afterSeq = knownMax <= Sync.initialLoad
              ? 0
              : knownMax - Sync.initialLoad;
          // after_seq=N returns messages with seq > N, so small
          // non-zero values (1-10) would skip the very first
          // message(s) of the conversation.  Round down to 0 when
          // the window barely exceeds Sync.initialLoad so the first
          // message is always included in the initial fetch.
          if (afterSeq > 0 && afterSeq <= 10) {
            afterSeq = 0;
          }
        } else {
          afterSeq = _tailAfterSeqForSession(sessionId);
        }
        if (gapTooLarge) {
          logger.info(
            '[fetchMessages] $sessionId gap too large '
            '(cursor=$cursorSeq server=$serverLastSeq) — '
            'switching to tail-load afterSeq=$afterSeq',
          );
        } else if (forceTailRefresh && !isFirstLoad) {
          logger.info(
            '[fetchMessages] $sessionId forcing tail refresh '
            'afterSeq=$afterSeq',
          );
        }
        if (isFirstLoad || gapTooLarge) {
          if (afterSeq > 0) {
            // Record where we started so the UI can offer "load older" later.
            _sessionFirstLoadedSeq[sessionId] = afterSeq + 1;
          } else {
            // Session is short — we will load everything; no older messages.
            _sessionFirstLoadedSeq[sessionId] = 0;
          }
          MMKVStorage().saveSessionFirstLoadedSeq(
            Map.unmodifiable(_sessionFirstLoadedSeq),
          );
        }
      } else if (cursorSeq == 0) {
        // No cursor established yet — use server's hint for tail refresh.
        afterSeq = _tailAfterSeqForSession(sessionId);
      } else {
        afterSeq = cursorSeq;
      }

      var page = 0;
      while (true) {
        // ── Check visibility BEFORE network call ──
        if (page > 0 && _visibleSessionId != sessionId) {
          logger.info(
            '[fetchMessages] $sessionId no longer visible '
            'after page $page — aborting',
          );
          // Notify UI so it stops the loading spinner. The session is
          // non-visible so further pagination is the responsibility of
          // onSessionVisible() when the user navigates back.
          _notifySessionMessagesChanged(sessionId);
          _notifyDataChanged();
          break;
        }

        final fetchStart = Stopwatch()..start();
        final Response<dynamic> response;
        if (testFetchMessagesOverride != null) {
          final overrideResult = await testFetchMessagesOverride!(
            sessionId,
            afterSeq,
            100,
          );
          // Synthesize a minimal Response to satisfy the rest of the logic.
          response = Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 200,
            data: overrideResult,
          );
        } else {
          response = await apiClient.get(
            '/v3/sessions/$sessionId/messages',
            queryParameters: {'after_seq': afterSeq, 'limit': 100},
          );
        }
        final fetchMs = fetchStart.elapsedMilliseconds;

        if (!apiClient.isSuccess(response)) {
          final statusCode = response.statusCode;
          logger.warning(
            'Failed to fetch messages: $statusCode',
          );
          unawaited(Sentry.addBreadcrumb(Breadcrumb(
            message: 'fetchMessages: HTTP error',
            category: 'sync.messages',
            level: SentryLevel.warning,
            data: {
              'sessionId': sessionId,
              'statusCode': statusCode,
              'afterSeq': afterSeq,
              'page': page,
              'elapsedMs':
                  fetchStopwatch.elapsedMilliseconds,
            },
          )));
          // 404 means the session doesn't exist on the server. Clean up
          // the local session and stop retries to prevent repeated 404s.
          if (statusCode == 404) {
            logger.warning(
              '[fetchMessages] Session $sessionId not found (404) '
              '— cleaning up local state',
            );
            messagesSync.remove(sessionId)?.dispose();
            _postSendCatchUpTimers.remove(sessionId)?.cancel();
            _loadingOlderMessages.remove(sessionId);
            _sessionMessages.remove(sessionId);
            _sessionMessagesCache = null;
            _sessionMessagesViewCache.remove(sessionId);
            _todoLists.remove(sessionId);
            if (sessionId == _visibleSessionId) {
              _visibleSessionId = null;
            }
            _sessions.remove(sessionId);
            _presenceTimers.remove(sessionId)?.cancel();
            _sessionDataKeys.remove(sessionId);
            _sessionEncryptedDataKeys.remove(sessionId);
            _sessionsNeedingTailRefresh.remove(sessionId);
            _sessionsWithPendingUpdates.remove(sessionId);
            _sessionsWithPendingSocketMessages.remove(sessionId);
            _sessionSpawnedAt.remove(sessionId);
            _autoRestoreInFlight.remove(sessionId);
            _pendingToolResults.remove(sessionId);
            if (isInitialized) {
              _sessionLastSeq.remove(sessionId);
              MMKVStorage().saveSessionLastSeq(
                Map.unmodifiable(_sessionLastSeq),
              );
              _sessionFirstLoadedSeq.remove(sessionId);
              MMKVStorage().saveSessionFirstLoadedSeq(
                Map.unmodifiable(_sessionFirstLoadedSeq),
              );
              _saveMsgsDebounceTimers.remove(sessionId)?.cancel();
              MessageCacheService().clearMessages(sessionId);
              encryption.removeSessionEncryption(sessionId);
            }
            _scheduleSessionsRefresh();
          } else {
            // For other errors, notify UI so it stops the loading spinner
            // and can show an error/empty state instead of spinning forever.
            _notifySessionMessagesChanged(sessionId);
          }
          _notifyDataChanged();
          break;
        }

        final data = response.data as Map<String, dynamic>;
        final messages = (data['messages'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        final hasMore = data['hasMore'] as bool? ?? false;

        logger.info(
          '[fetchMessages] $sessionId page=$page '
          'msgs=${messages.length} hasMore=$hasMore '
          'fetchMs=$fetchMs',
        );

        // ── Decrypt + process (isolate for large batches) ──
        final decryptStart = Stopwatch()..start();
        final processed = await sessionEncryption.decryptAndProcessMessages(
          messages,
          sessionId,
        );
        final decryptMs = decryptStart.elapsedMilliseconds;
        final userCount = processed.messages
            .where((message) => message['role'] == MessageRole.user)
            .length;
        final agentCount = processed.messages
            .where((message) => message['role'] == MessageRole.agent)
            .length;
        final eventCount = processed.messages
            .where((message) => message['kind'] == 'agent-event')
            .length;
        logger.info(
          '[fetchMessages] $sessionId page=$page '
          'processedMsgs=${processed.messages.length} '
          'users=$userCount agents=$agentCount events=$eventCount '
          'toolResults=${processed.toolResults.length} '
          'usageUpdates=${processed.usageUpdates.length} '
          'afterSeq=$afterSeq '
          'maxSeq=${processed.maxSeq}',
        );
        if (processed.droppedReasons.isNotEmpty) {
          for (final reason in processed.droppedReasons) {
            logger.warning(
              '[fetchMessages] $sessionId dropped: $reason',
            );
          }
        }

        // ── Yield before main-thread merge/group work ──
        await Future<void>.delayed(Duration.zero);

        // ── Upsert messages ──
        // For gap recovery, clear stale in-memory messages right before
        // the first successful upsert so we don't lose messages if the
        // network request fails. We defer clearing until we know the fetch
        // succeeded.
        if (isGapRecovery && page == 0 && processed.messages.isNotEmpty) {
          _sessionMessages.remove(sessionId);
          _sessionMessagesCache = null;
          _sessionMessagesViewCache.remove(sessionId);
          MessageCacheService().clearMessages(sessionId);
          logger.info(
            '[fetchMessages] $sessionId gap recovery: cleared stale messages '
            'before upserting ${processed.messages.length} new ones',
          );
        }
        final upsertStart = Stopwatch()..start();
        if (processed.messages.isNotEmpty) {
          _upsertSessionMessages(sessionId, processed.messages);
        }
        final upsertMs = upsertStart.elapsedMilliseconds;

        // ── Yield ──
        await Future<void>.delayed(Duration.zero);

        // ── Apply tool results + usage ──
        final toolStart = Stopwatch()..start();
        if (processed.toolResults.isNotEmpty) {
          _applyToolResults(sessionId, processed.toolResults);
        }
        // Apply any pending tool results that arrived before these messages.
        final pending = _pendingToolResults.remove(sessionId);
        if (pending != null && pending.isNotEmpty) {
          _applyToolResults(sessionId, pending);
        }
        for (final u in processed.usageUpdates) {
          _updateSessionUsage(
            u['sessionId'] as String,
            u['usage'] as Map<String, dynamic>,
            u['timestamp'] as int,
          );
        }
        final toolMs = toolStart.elapsedMilliseconds;

        // ── Yield ──
        await Future<void>.delayed(Duration.zero);

        // ── Group sidechain messages ──
        final groupStart = Stopwatch()..start();
        _groupSidechainMessages(sessionId);
        final groupMs = groupStart.elapsedMilliseconds;

        // ── Yield ──
        await Future<void>.delayed(Duration.zero);

        // ── Apply permission requests ──
        final permStart = Stopwatch()..start();
        _applyPermissionRequests(sessionId);
        final permMs = permStart.elapsedMilliseconds;


        if (processed.maxSeq > afterSeq) {
          afterSeq = processed.maxSeq;
        }
        _advanceSeqCursor(sessionId, afterSeq);

        if (processed.maxSeq > 0 &&
            processed.messages.isEmpty &&
            processed.toolResults.isEmpty &&
            messages.isNotEmpty) {
          // All raw messages were silently dropped by the processor.
          // Log the reasons so unrecognized formats are discoverable.
          for (final reason in processed.droppedReasons) {
            logger.warning(
              '[fetchMessages] dropped: $reason',
            );
          }
        }

        logger.info(
          '[fetchMessages] $sessionId page=$page '
          'decryptMs=$decryptMs '
          'upsert=$upsertMs tool=$toolMs '
          'group=$groupMs perm=$permMs',
        );

        // Notify the UI after each page so the chat screen can
        // display partial results immediately instead of waiting
        // for all pages to complete. This is critical for sessions
        // with many messages where pagination + decryption exceeds
        // the 5s awaitQueue timeout in ChatScreen._doInitialLoad.
        if (processed.messages.isNotEmpty) {
          _notifySessionMessagesChanged(sessionId);
          _notifyDataChanged();
        }

        if (!hasMore) break;
        page++;

        // Safety valve: stop this cycle to let the UI render, then
        // schedule a follow-up fetch so we keep crawling.  Without the
        // re-trigger, messages beyond the cutoff are lost until the
        // next external invalidation — which may never come if all new
        // messages use the inline socket path.
        const maxPages = 5; // 500 messages max per fetch cycle
        if (page >= maxPages) {
          logger.info(
            '[fetchMessages] $sessionId hit $maxPages page limit '
            '— stopping forward crawl at afterSeq=$afterSeq',
          );
          // Re-trigger so the next cycle continues from the new cursor.
          messagesSync[sessionId]?.invalidate();
          break;
        }

        // ── Yield between pages ──
        await Future<void>.delayed(Duration.zero);
      }
      // Final notification in case some pages had no messages
      // (notification already fired per-page for non-empty pages).
      _notifySessionMessagesChanged(sessionId);
      _notifyDataChanged();
      // Finish the fetch span successfully
      fetchSpan?.setData('totalElapsedMs', fetchStopwatch.elapsedMilliseconds);
      if (fetchSpan != null) unawaited(fetchSpan.finish());
    } on DioException catch (e) {
      fetchSpan?.setData('status', 'networkError');
      fetchSpan?.setData('dioExceptionType', e.type.name);
      fetchSpan?.setData('totalElapsedMs', fetchStopwatch.elapsedMilliseconds);
      if (fetchSpan != null) unawaited(fetchSpan.finish());
      unawaited(Sentry.addBreadcrumb(Breadcrumb(
        message: 'fetchMessages: DioException',
        category: 'sync.messages',
        level: SentryLevel.error,
        data: {
          'sessionId': sessionId,
          'type': e.type.name,
          'statusCode': e.response?.statusCode,
          'elapsedMs':
              fetchStopwatch.elapsedMilliseconds,
        },
      )));
      // Network error (e.g., connection lost). The InvalidateSync retry
      // mechanism will handle retries, but we must notify the UI now so
      // it doesn't spin forever while waiting for awaitQueue(). When
      // retries exhaust, the Completer completes with error and the chat
      // screen's timeout will handle it.
      _notifySessionMessagesChanged(sessionId);
      _notifyDataChanged();
      rethrow;
    } catch (error, stack) {
      fetchSpan?.status = SpanStatus.internalError();
      fetchSpan?.setData('error', error.toString());
      fetchSpan?.setData('totalElapsedMs', fetchStopwatch.elapsedMilliseconds);
      if (fetchSpan != null) unawaited(fetchSpan.finish());
      unawaited(Sentry.addBreadcrumb(Breadcrumb(
        message: 'fetchMessages: unexpected error',
        category: 'sync.messages',
        level: SentryLevel.error,
        data: {
          'sessionId': sessionId,
          'error': error.toString(),
          'elapsedMs':
              fetchStopwatch.elapsedMilliseconds,
        },
      )));
      logger.error(
        'Error fetching messages',
        error,
        stack,
      );
      // Notify listeners so the UI can handle the error state rather than
      // remaining in a stale loading state.
      _notifySessionMessagesChanged(sessionId);
      _notifyDataChanged();
    }
  }

  /// Fetch the page of messages that precedes what has already been loaded
  /// for [sessionId].  Call [hasOlderMessages] first to guard against
  /// unnecessary requests.
  Future<void> fetchOlderMessages(String sessionId) async {
    if (isLoadingOlderMessages(sessionId)) return;
    final firstLoaded = _sessionFirstLoadedSeq[sessionId] ?? 0;
    if (firstLoaded <= 1) return; // nothing older to fetch

    final sessionEncryption = encryption.getSessionEncryption(sessionId);
    if (sessionEncryption == null) return;

    _loadingOlderMessages.add(sessionId);
    _notifyDataChanged();

    try {
      const pageSize = 100;
      final startSeq = (firstLoaded - 1 - pageSize).clamp(0, firstLoaded - 1);

      final Response<dynamic> response;
      if (testFetchOlderMessagesOverride != null) {
        final overrideResult = await testFetchOlderMessagesOverride!(
          sessionId,
          startSeq,
          pageSize,
        );
        response = Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: overrideResult,
        );
      } else {
        final apiClient = ApiClient();
        response = await apiClient.get(
          '/v3/sessions/$sessionId/messages',
          queryParameters: {'after_seq': startSeq, 'limit': pageSize},
        );

        if (!apiClient.isSuccess(response)) {
          logger.warning(
            'Failed to fetch older messages: ${response.statusCode}',
          );
          return;
        }
      }

      final data = response.data as Map<String, dynamic>;
      final messages = (data['messages'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();

      logger.info(
        '[fetchOlderMessages] $sessionId '
        'msgs=${messages.length}',
      );

      final processed = await sessionEncryption.decryptAndProcessMessages(
        messages,
        sessionId,
      );

      logger.info(
        '[fetchOlderMessages] $sessionId '
        'processedMsgs=${processed.messages.length} '
        'toolResults=${processed.toolResults.length}',
      );
      if (processed.droppedReasons.isNotEmpty) {
        for (final reason in processed.droppedReasons) {
          logger.warning(
            '[fetchOlderMessages] $sessionId dropped: $reason',
          );
        }
      }

      // Yield before main-thread merge work
      await Future<void>.delayed(Duration.zero);

      if (processed.messages.isNotEmpty) {
        _upsertSessionMessages(sessionId, processed.messages);
      }
      if (processed.toolResults.isNotEmpty) {
        _applyToolResults(sessionId, processed.toolResults);
      }
      // Apply any pending tool results that arrived before these messages.
      final pending = _pendingToolResults.remove(sessionId);
      if (pending != null && pending.isNotEmpty) {
        _applyToolResults(sessionId, pending);
      }
      for (final u in processed.usageUpdates) {
        _updateSessionUsage(
          u['sessionId'] as String,
          u['usage'] as Map<String, dynamic>,
          u['timestamp'] as int,
        );
      }
      _groupSidechainMessages(sessionId);
      _applyPermissionRequests(sessionId);

      // Move the lower boundary back to cover the page we just fetched.
      _sessionFirstLoadedSeq[sessionId] = startSeq == 0 ? 0 : startSeq + 1;
      MMKVStorage().saveSessionFirstLoadedSeq(
        Map.unmodifiable(_sessionFirstLoadedSeq),
      );

      _notifySessionMessagesChanged(sessionId);
      _notifyDataChanged();
    } catch (error, stack) {
      logger.error('Error fetching older messages', error, stack);
    } finally {
      _loadingOlderMessages.remove(sessionId);
      _notifyDataChanged();
    }
  }

  /// Whether a session's agent is connected enough to receive messages.
  /// Checks both ephemeral presence and lifecycle metadata.
  /// Guards against stale lifecycleState by requiring a recent timestamp.
  bool _isSessionReady(Session s) {
    // Cross-check presence with a recent ephemeral event — same logic
    // as _resolveSendTargetSession to avoid trusting stale 'online'
    // presence after a daemon restart.
    final lastEphemeral = _lastEphemeralAt[s.id];
    final recentEphemeral =
        lastEphemeral != null &&
        DateTime.now().millisecondsSinceEpoch - lastEphemeral < 90000;
    if (s.isOnline && recentEphemeral) return true;
    final lc = s.metadata?.lifecycleState;
    if (lc != 'running') return false;
    // Only trust "running" if the timestamp is recent (< 2 minutes).
    final since = s.metadata?.lifecycleStateSince;
    if (since == null) return false;
    return DateTime.now().millisecondsSinceEpoch - since < 120000;
  }

  /// Wait for agent to be ready.
  ///
  /// Returns `true` when the session's presence becomes `'online'`
  /// (set by `handleEphemeralUpdate` when the daemon sends
  /// `session-alive` keep-alives — typically within 2 seconds),
  /// or when `lifecycleState` becomes `'running'` (set by the agent
  /// after connecting to Socket.IO — confirms push delivery).
  ///
  /// Note: `agentStateVersion` is intentionally NOT checked here
  /// because it persists across daemon restarts and would cause
  /// stale sessions to appear ready when the daemon is offline.
  Future<bool> waitForAgentReady(
    String sessionId, [
    int timeoutMs = Sync.sessionReadyTimeoutMs,
  ]) async {
    // Fast path: already online or lifecycle running
    final session = _sessions[sessionId];
    if (session != null && _isSessionReady(session)) return true;

    logger.info(
      '[sendMessage] waitForAgentReady waiting '
      'session=$sessionId isOnline=${session?.isOnline} '
      'lifecycleState=${session?.metadata?.lifecycleState}',
    );

    // Event-driven: resolve as soon as onDataChanged fires with session
    // ready, or after timeoutMs, whichever comes first.
    final completer = Completer<bool>();
    StreamSubscription<void>? sub;
    Timer? timer;

    timer = Timer(Duration(milliseconds: timeoutMs), () {
      if (!completer.isCompleted) completer.complete(false);
      sub?.cancel();
    });

    sub = onDataChanged.listen((_) {
      final s = _sessions[sessionId];
      if (s != null && _isSessionReady(s) && !completer.isCompleted) {
        completer.complete(true);
        timer?.cancel();
        sub?.cancel();
      }
    });

    final ready = await completer.future;
    logger.info(
      '[sendMessage] waitForAgentReady done '
      'session=$sessionId ready=$ready',
    );
    return ready;
  }

  /// Process a decrypted message into display messages and tool results.
  /// Test helper for [_processDecryptedMessage].
  @visibleForTesting
  (List<Map<String, dynamic>>, List<Map<String, dynamic>>)
  testProcessDecryptedMessage({
    required String id,
    required int seq,
    required String sessionId,
    required Map<String, dynamic> content,
    String? localId,
    int? createdAtMs,
  }) {
    return _processDecryptedMessage(
      DecryptedMessage(
        id: id,
        seq: seq,
        localId: localId,
        content: content,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          createdAtMs ?? DateTime.now().millisecondsSinceEpoch,
        ),
      ),
      sessionId,
    );
  }

  ///
  /// Returns a tuple of (displayMessages, toolResults).
  /// Display messages are added to the session message list.
  /// Tool results are used to update existing tool-call message states.
  (List<Map<String, dynamic>>, List<Map<String, dynamic>>)
  _processDecryptedMessage(DecryptedMessage message, String sessionId) {
    final createdAt = message.createdAt.millisecondsSinceEpoch;
    final content = message.content;

    if (content is! Map<String, dynamic>) {
      // Fallback for non-map content
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'kind': 'text',
            'content': content?.toString() ?? '',
            'raw': content,
          },
        ],
        [],
      );
    }

    final role = content['role'] as String?;
    final nestedContent = content['content'];

    // User messages: {role: 'user', content: {type: 'text', text: '...'}}
    if (role == MessageRole.user) {
      if (nestedContent is Map<String, dynamic> &&
          nestedContent['type'] == 'text') {
        return (
          [
            {
              'id': message.id,
              'localId': message.localId,
              'seq': message.seq,
              'createdAt': createdAt,
              'role': 'user',
              'kind': 'text',
              'content': nestedContent['text']?.toString() ?? '',
              'raw': content,
            },
          ],
          [],
        );
      }
      // Fallback for non-text user messages
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'user',
            'kind': 'text',
            'content': content.toString(),
            'raw': content,
          },
        ],
        [],
      );
    }

    // Agent messages: {role: 'agent', content: {type: ..., data: ...}}
    if (role == MessageRole.agent) {
      if (nestedContent is! Map<String, dynamic>) {
        return (
          [
            {
              'id': 'error-${message.id}_parse',
              'seq': message.seq,
              'createdAt': createdAt,
              'role': 'system',
              'kind': 'error',
              'errorType': 'agent_content_not_map',
              'errorMessage':
                  'Agent message content is not '
                  'a valid structure',
              'debugData': {
                'messageId': message.id,
                'seq': message.seq,
                'contentType': '${nestedContent.runtimeType}',
              },
            },
          ],
          <Map<String, dynamic>>[],
        );
      }

      final contentType = nestedContent['type'] as String?;

      // Output type: Claude/assistant messages
      if (contentType == 'output') {
        return _processOutputContent(
          message,
          nestedContent,
          createdAt,
          content,
          sessionId,
        );
      }

      // Event type: mode switches, limit reached, etc.
      if (contentType == 'event') {
        // When the agent sends session-cleared (after a /clear restart),
        // immediately drop the session's ephemeral presence to offline so
        // that waitForAgentReady blocks until the new Claude process sends
        // its first keep-alive. Without this, a follow-up message is posted
        // while the old Claude is dead and the new one hasn't connected yet.
        final evData = nestedContent['data'];
        if (evData is Map<String, dynamic>) {
          final evType = (evData['t'] ?? evData['type']) as String?;
          if (evType == 'session-cleared') {
            _presenceTimers[sessionId]?.cancel();
            _presenceTimers.remove(sessionId);
            final current = _sessions[sessionId];
            if (current != null) {
              _sessions[sessionId] = current.copyWith(
                presence: 'offline',
                thinking: false,
              );
              _notifyDataChanged();
            }
          }
        }
        return _processEventContent(message, nestedContent, createdAt, content);
      }

      // Codex type: Codex agent messages
      if (contentType == 'codex') {
        return _processCodexContent(
          message,
          nestedContent,
          createdAt,
          content,
          sessionId,
        );
      }

      // ACP type: unified agent communication protocol
      if (contentType == 'acp') {
        return _processAcpContent(message, nestedContent, createdAt, content);
      }

      // Session protocol envelope embedded directly under content.
      if (_looksLikeSessionEnvelope(nestedContent)) {
        return _processSessionContent(
          message,
          nestedContent,
          createdAt,
          content,
        );
      }

      // Session protocol wrapper (agent role).
      if (contentType == 'session') {
        return _processSessionContent(
          message,
          nestedContent,
          createdAt,
          content,
        );
      }

      final fallback = _extractAgentFallbackText(nestedContent);
      if (fallback != null && fallback.isNotEmpty) {
        return (
          [
            {
              'id': message.id,
              'localId': message.localId,
              'seq': message.seq,
              'createdAt': createdAt,
              'role': 'agent',
              'kind': 'text',
              'content': fallback,
              'raw': content,
            },
          ],
          <Map<String, dynamic>>[],
        );
      }

      return (
        [
          {
            'id': 'error-${message.id}_parse',
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'system',
            'kind': 'error',
            'errorType': 'unknown_agent_content_type',
            'errorMessage': 'Unrecognized agent content type: $contentType',
            'debugData': {
              'messageId': message.id,
              'seq': message.seq,
              'contentType': contentType,
            },
          },
        ],
        <Map<String, dynamic>>[],
      );
    }

    // Session protocol envelope role.
    if (role == MessageRole.session) {
      return _processSessionContent(
        message,
        nestedContent ?? content,
        createdAt,
        content,
      );
    }

    return (
      [
        {
          'id': 'error-${message.id}_parse',
          'seq': message.seq,
          'createdAt': createdAt,
          'role': 'system',
          'kind': 'error',
          'errorType': 'unknown_role',
          'errorMessage': 'Unrecognized message role: $role',
          'debugData': {
            'messageId': message.id,
            'seq': message.seq,
            'role': role,
          },
        },
      ],
      <Map<String, dynamic>>[],
    );
  }

  bool _looksLikeSessionEnvelope(dynamic value) {
    if (value is! Map<String, dynamic>) return false;
    final hasEvent =
        value['ev'] is Map<String, dynamic> ||
        value['event'] is Map<String, dynamic>;
    final hasIdentity =
        value['id'] != null || value['uuid'] != null || value['time'] != null;
    return hasEvent && hasIdentity;
  }

  String? _extractAgentFallbackText(dynamic nestedContent) {
    if (nestedContent is! Map<String, dynamic>) return null;

    final directText = nestedContent['text'] ?? nestedContent['message'];
    if (directText is String && directText.isNotEmpty) {
      return directText;
    }

    final data = nestedContent['data'];
    if (data is Map<String, dynamic>) {
      final dataMessage = data['message'];
      if (dataMessage is String && dataMessage.isNotEmpty) {
        return dataMessage;
      }
      final dataText = data['text'];
      if (dataText is String && dataText.isNotEmpty) {
        return dataText;
      }
    }

    return null;
  }

  (List<Map<String, dynamic>>, List<Map<String, dynamic>>)
  _processOutputContent(
    DecryptedMessage message,
    Map<String, dynamic> nestedContent,
    int createdAt,
    Map<String, dynamic> outerContent,
    String sessionId,
  ) {
    final data = nestedContent['data'];
    if (data is! Map<String, dynamic>) return ([], []);

    // Skip meta and compact summary messages
    if (data['isMeta'] == true || data['isCompactSummary'] == true) {
      return ([], []);
    }

    // Sidechain metadata for sub-agent grouping
    final isSidechain =
        data['isSidechain'] == true || data['is_sidechain'] == true;
    final dataUuid = (data['uuid'] ?? data['id']) as String?;
    final dataParentUuid =
        (data['subagent'] ?? data['parentUuid'] ?? data['parent_uuid'])
            as String?;

    final dataType = data['type'] as String?;

    if (dataType == 'assistant') {
      if (dataUuid == null || dataUuid.isEmpty) return ([], []);

      final agentMsg = data['message'];
      if (agentMsg is! Map<String, dynamic>) return ([], []);

      // Extract usage data for context window tracking
      final usageData = agentMsg['usage'] as Map<String, dynamic>?;
      if (usageData != null) {
        _updateSessionUsage(sessionId, usageData, createdAt);
      }

      final agentContentList = agentMsg['content'];
      if (agentContentList is! List) return ([], []);

      final results = <Map<String, dynamic>>[];
      var i = 0;
      for (final c in agentContentList) {
        if (c is! Map<String, dynamic>) {
          i++;
          continue;
        }
        final type = c['type'] as String?;

        if (type == 'text') {
          results.add({
            'id': '${message.id}_t$i',
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'text',
            'content': c['text']?.toString() ?? '',
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            'uuid': dataUuid,
            'parentUuid': ?dataParentUuid,
          });
        } else if (type == 'thinking') {
          results.add({
            'id': '${message.id}_k$i',
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'text',
            'isThinking': true,
            'content': '*Thinking...*\n\n*${c['thinking']}*',
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            'uuid': dataUuid,
            'parentUuid': ?dataParentUuid,
          });
        } else if (type == 'tool_use') {
          results.add({
            'id': '${message.id}_u$i',
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'tool-call',
            'name': c['name'],
            'input': c['input'],
            'toolUseId': c['id'],
            'state': 'running',
            'content': c,
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            'uuid': dataUuid,
            'parentUuid': ?dataParentUuid,
          });
        }
        i++;
      }
      return (results, []);
    }

    if (dataType == 'user') {
      // Sidechain root: isSidechain=true, message.content is
      // a string or content-block list (the prompt sent to the
      // sub-agent). We emit a hidden marker so
      // _groupSidechainMessages can match it.
      if (isSidechain) {
        final msgContent = data['message']?['content'];
        // Extract the prompt text — bare string or Claude API
        // content-block format [{type: 'text', text: '...'}].
        final promptText = msgContent is String
            ? msgContent
            : (msgContent is List
                ? _extractTextFromContentBlocks(msgContent)
                : null);
        if (promptText != null && promptText.isNotEmpty) {
          return (
            [
              {
                'id': '${message.id}_sc',
                'seq': message.seq,
                'createdAt': createdAt,
                'kind': 'sidechain-root',
                'isSidechain': true,
                'prompt': promptText,
                'uuid': ?dataUuid,
                'parentUuid': ?dataParentUuid,
              },
            ],
            [],
          );
        }
      }

      // Tool results - collect them to update existing tool-call states
      final toolResults = <Map<String, dynamic>>[];
      final msgContent = data['message']?['content'];

      if (msgContent is List) {
        for (final c in msgContent) {
          if (c is Map<String, dynamic> && c['type'] == 'tool_result') {
            toolResults.add({
              'toolUseId': c['tool_use_id'],
              'result': c['content'],
              'isError': c['is_error'] == true,
              'createdAt': createdAt,
              'permissions': c['permissions'],
              if (isSidechain) 'isSidechain': true,
              'uuid': ?dataUuid,
              'parentUuid': ?dataParentUuid,
            });
          }
        }
      }
      return ([], toolResults);
    }

    // Skip system, result, summary messages
    return ([], []);
  }

  (List<Map<String, dynamic>>, List<Map<String, dynamic>>) _processEventContent(
    DecryptedMessage message,
    Map<String, dynamic> nestedContent,
    int createdAt,
    Map<String, dynamic> outerContent,
  ) {
    final data = nestedContent['data'];
    if (data is! Map<String, dynamic>) return ([], []);

    // Skip ready and session-cleared events (session-cleared is handled at the
    // call site to reset ephemeral presence; ready is internal bookkeeping).
    if (data['type'] == 'ready' || data['type'] == 'session-cleared') {
      return ([], []);
    }

    return (
      [
        {
          'id': message.id,
          'localId': message.localId,
          'seq': message.seq,
          'createdAt': createdAt,
          'role': 'agent',
          'kind': 'agent-event',
          'event': data,
          'content': '',
          'raw': outerContent,
        },
      ],
      [],
    );
  }

  (List<Map<String, dynamic>>, List<Map<String, dynamic>>) _processCodexContent(
    DecryptedMessage message,
    Map<String, dynamic> nestedContent,
    int createdAt,
    Map<String, dynamic> outerContent,
    String sessionId,
  ) {
    final data = nestedContent['data'];
    if (data is! Map<String, dynamic>) return ([], []);

    final usageData =
        _extractUsageMap(data['usage']) ??
        _extractUsageMap(
          data['message'] is Map ? (data['message'] as Map)['usage'] : null,
        );
    if (usageData != null) {
      _updateSessionUsage(sessionId, usageData, createdAt);
    }

    final dataType = data['type'] as String?;

    // Sidechain metadata for sub-agent grouping
    final isSidechain =
        data['isSidechain'] == true || data['is_sidechain'] == true;
    final uuid =
        (data['uuid'] ?? data['id']) as String?;
    final parentUuid =
        (data['subagent'] ?? data['parentUuid'] ?? data['parent_uuid'])
            as String?;

    if (dataType == 'message' || dataType == 'reasoning') {
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'text',
            'content': data['message']?.toString() ?? '',
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            'uuid': ?uuid,
            'parentUuid': ?parentUuid,
          },
        ],
        [],
      );
    }

    if (dataType == 'tool-call') {
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'tool-call',
            'name': data['name'],
            'input': data['input'],
            'toolUseId': data['callId'],
            'state': 'running',
            'content': data,
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            'uuid': ?uuid,
            'parentUuid': ?parentUuid,
          },
        ],
        [],
      );
    }

    if (dataType == 'tool-call-result') {
      // Support both 'output' and 'content' fields for tool result
      final result = data['output'] ?? data['content'];
      return (
        [],
        [
          {
            'toolUseId': data['callId'],
            'result': result,
            'isError': data['isError'] == true || data['is_error'] == true,
            'createdAt': createdAt,
            if (isSidechain) 'isSidechain': true,
            'uuid': ?uuid,
            'parentUuid': ?parentUuid,
          },
        ],
      );
    }

    return ([], []);
  }

  Map<String, dynamic>? _extractUsageMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      try {
        return Map<String, dynamic>.from(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Extract text from Claude API content blocks format.
  ///
  /// Handles `[{type: 'text', text: '...'}, ...]` by concatenating
  /// all text blocks.
  String? _extractTextFromContentBlocks(List<dynamic> blocks) {
    final buffer = StringBuffer();
    for (final block in blocks) {
      if (block is Map<String, dynamic> && block['type'] == 'text') {
        final text = block['text'];
        if (text is String && text.isNotEmpty) {
          if (buffer.isNotEmpty) buffer.write('\n');
          buffer.write(text);
        }
      }
    }
    return buffer.isEmpty ? null : buffer.toString();
  }

  (List<Map<String, dynamic>>, List<Map<String, dynamic>>) _processAcpContent(
    DecryptedMessage message,
    Map<String, dynamic> nestedContent,
    int createdAt,
    Map<String, dynamic> outerContent,
  ) {
    final data = nestedContent['data'];
    if (data is! Map<String, dynamic>) return ([], []);

    final dataType = data['type'] as String?;

    // Sidechain metadata for sub-agent grouping
    final isSidechain =
        data['isSidechain'] == true || data['is_sidechain'] == true;
    final uuid =
        (data['uuid'] ?? data['id']) as String?;
    final parentUuid =
        (data['subagent'] ?? data['parentUuid'] ?? data['parent_uuid'])
            as String?;

    if (dataType == 'message' || dataType == 'reasoning') {
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'text',
            'content': data['message']?.toString() ?? '',
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            'uuid': ?uuid,
            'parentUuid': ?parentUuid,
          },
        ],
        [],
      );
    }

    if (dataType == 'thinking') {
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'text',
            'isThinking': true,
            'content': '*Thinking...*\n\n*${data['text']}*',
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            'uuid': ?uuid,
            'parentUuid': ?parentUuid,
          },
        ],
        [],
      );
    }

    if (dataType == 'tool-call') {
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'tool-call',
            'name': data['name'],
            'input': data['input'],
            'toolUseId': data['callId'],
            'state': 'running',
            'content': data,
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            'uuid': ?uuid,
            'parentUuid': ?parentUuid,
          },
        ],
        [],
      );
    }

    if (dataType == 'tool-result' || dataType == 'tool-call-result') {
      // Support both 'output' and 'content' fields for tool result
      final result = data['output'] ?? data['content'];
      return (
        [],
        [
          {
            'toolUseId': data['callId'],
            'result': result,
            'isError': data['isError'] == true || data['is_error'] == true,
            'createdAt': createdAt,
            if (isSidechain) 'isSidechain': true,
            'uuid': ?uuid,
            'parentUuid': ?parentUuid,
          },
        ],
      );
    }

    if (dataType == 'file-edit') {
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'tool-call',
            'name': 'file-edit',
            'input': {
              'filePath': data['filePath'],
              'description': data['description'],
              'diff': data['diff'],
              'oldContent': data['oldContent'],
              'newContent': data['newContent'],
            },
            'toolUseId': data['id'],
            'state': 'running',
            'content': data,
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            'uuid': ?uuid,
            'parentUuid': ?parentUuid,
          },
        ],
        [],
      );
    }

    // Skip task lifecycle events (task_started, task_complete, turn_aborted,
    // token_count, permission-request, etc.)
    return ([], []);
  }

  (List<Map<String, dynamic>>, List<Map<String, dynamic>>)
  _processSessionContent(
    DecryptedMessage message,
    dynamic nestedContent,
    int createdAt,
    Map<String, dynamic> outerContent,
  ) {
    Map<String, dynamic>? envelope;
    if (nestedContent is Map<String, dynamic>) {
      if (nestedContent['type'] == 'session' &&
          nestedContent['data'] is Map<String, dynamic>) {
        envelope = nestedContent['data'] as Map<String, dynamic>;
      } else {
        envelope = nestedContent;
      }
    }
    if (envelope == null) return ([], []);

    final event = envelope['ev'] ?? envelope['event'];
    if (event is! Map<String, dynamic>) return ([], []);

    final eventType = (event['t'] ?? event['type']) as String?;
    if (eventType == null) return ([], []);

    final eventRole = envelope['role'] as String?;
    final envelopeId =
        (envelope['id'] ?? envelope['uuid']) as String? ?? message.id;
    final eventCreatedAt = _parseCreatedAtMs(
      envelope['time'] ?? envelope['createdAt'] ?? createdAt,
    );
    final parentUuid =
        (envelope['subagent'] ??
                envelope['parentUuid'] ??
                envelope['parent_uuid'])
            as String?;
    final isSidechain = parentUuid != null && parentUuid.isNotEmpty;
    final uuid = (envelope['id'] ?? envelope['uuid']) as String? ?? message.id;

    if (eventType == 'turn-start' ||
        eventType == 'start' ||
        eventType == 'stop') {
      return ([], []);
    }

    if (eventType == 'turn-end') {
      return (
        [
          {
            'id': envelopeId,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': eventCreatedAt,
            'role': 'agent',
            'kind': 'agent-event',
            'event': {'type': 'ready'},
            'content': '',
            'raw': outerContent,
          },
        ],
        [],
      );
    }

    if (eventType == 'service') {
      if (eventRole != 'agent') return ([], []);
      return (
        [
          {
            'id': envelopeId,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': eventCreatedAt,
            'role': 'agent',
            'kind': 'text',
            'content': (event['text'] ?? event['message'])?.toString() ?? '',
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            if (uuid.isNotEmpty) 'uuid': uuid,
            'parentUuid': ?parentUuid,
          },
        ],
        [],
      );
    }

    if (eventType == 'text') {
      final text = (event['text'] ?? event['message'])?.toString() ?? '';
      if (eventRole == MessageRole.agent) {
        final thinking = event['thinking'] == true;
        return (
          [
            {
              'id': envelopeId,
              'localId': message.localId,
              'seq': message.seq,
              'createdAt': eventCreatedAt,
              'role': 'agent',
              'kind': 'text',
              if (thinking) 'isThinking': true,
              'content': thinking ? '*Thinking...*\n\n*$text*' : text,
              'raw': outerContent,
              if (isSidechain) 'isSidechain': true,
              if (uuid.isNotEmpty) 'uuid': uuid,
              'parentUuid': ?parentUuid,
            },
          ],
          [],
        );
      }

      if (eventRole == MessageRole.user) {
        if (isSidechain && text.isNotEmpty) {
          return (
            [
              {
                'id': '${envelopeId}_sc',
                'seq': message.seq,
                'createdAt': eventCreatedAt,
                'kind': 'sidechain-root',
                'isSidechain': true,
                'prompt': text,
                if (uuid.isNotEmpty) 'uuid': uuid,
                'parentUuid': parentUuid,
              },
            ],
            [],
          );
        }

        if (text.isNotEmpty) {
          return (
            [
              {
                'id': envelopeId,
                'localId': message.localId,
                'seq': message.seq,
                'createdAt': eventCreatedAt,
                'role': 'user',
                'kind': 'text',
                'content': text,
                'raw': outerContent,
              },
            ],
            [],
          );
        }
      }

      return ([], []);
    }

    if (eventType == 'tool-call-start') {
      if (eventRole != 'agent') return ([], []);
      final args = event['args'] ?? event['input'];
      final input = args is Map<String, dynamic> ? args : <String, dynamic>{};
      final callId =
          (event['call'] ?? event['callId'] ?? event['toolUseId']) as String?;
      return (
        [
          {
            'id': envelopeId,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': eventCreatedAt,
            'role': 'agent',
            'kind': 'tool-call',
            'name': (event['name'] ?? event['tool'])?.toString() ?? 'unknown',
            'input': input,
            'toolUseId': callId ?? envelopeId,
            'state': 'running',
            'content': event,
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            if (uuid.isNotEmpty) 'uuid': uuid,
            'parentUuid': ?parentUuid,
          },
        ],
        [],
      );
    }

    if (eventType == 'tool-call-end') {
      final callId =
          (event['call'] ?? event['callId'] ?? event['toolUseId']) as String?;
      if (callId == null || callId.isEmpty) return ([], []);
      return (
        [],
        [
          {
            'toolUseId': callId,
            'result': event['result'] ?? event['output'] ?? event['content'],
            'isError': event['isError'] == true || event['is_error'] == true,
            'createdAt': eventCreatedAt,
            if (isSidechain) 'isSidechain': true,
            if (uuid.isNotEmpty) 'uuid': uuid,
            'parentUuid': ?parentUuid,
          },
        ],
      );
    }

    if (eventType == 'file') {
      if (eventRole != 'agent') return ([], []);
      final image = event['image'];
      final imageMeta = image is Map<String, dynamic>
          ? {
              'width': image['width'],
              'height': image['height'],
              'thumbhash': image['thumbhash'],
            }
          : null;
      return (
        [
          {
            'id': envelopeId,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': eventCreatedAt,
            'role': 'agent',
            'kind': 'tool-call',
            'name': 'file',
            'input': {
              'ref': event['ref'],
              'name': event['name'],
              'size': event['size'],
              'image': ?imageMeta,
            },
            'toolUseId': envelopeId,
            'state': 'completed',
            'content': event,
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            if (uuid.isNotEmpty) 'uuid': uuid,
            'parentUuid': ?parentUuid,
          },
        ],
        [],
      );
    }

    return ([], []);
  }

  /// Group sidechain messages as children of their parent Task
  /// tool-call messages and remove them from the main message list.
  ///
  /// [changedIds] — when provided (inline streaming path), contains
  /// the IDs of messages that were just upserted.  If none of them
  /// Schedule a debounced full re-grouping sweep for [sessionId].
  ///
  /// Called after each inline sidechain message is processed.
  /// Coalesces rapid arrivals (e.g. 10 sidechain messages in 200 ms)
  /// into a single sweep that runs without [changedIds], forcing
  /// the grouping logic to iterate all messages and catch any that
  /// were orphaned because their parent hadn't been upserted yet.
  void _scheduleSidechainRegroup(String sessionId) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Track when the first regroup request in this burst arrived.
    _sidechainRegroupFirstRequestMs.putIfAbsent(sessionId, () => nowMs);

    // If the burst has lasted longer than 2s, fire immediately instead
    // of debouncing further.  During active agent streaming, messages
    // arrive every ~50ms and the 300ms debounce timer keeps getting
    // cancelled — without this cap, the sweep never fires and orphaned
    // sidechain messages remain invisible.
    final burstStartMs = _sidechainRegroupFirstRequestMs[sessionId]!;
    final burstDuration = nowMs - burstStartMs;
    if (burstDuration >= 2000) {
      _sidechainRegroupTimers[sessionId]?.cancel();
      _sidechainRegroupTimers.remove(sessionId);
      _sidechainRegroupFirstRequestMs.remove(sessionId);
      _runDeferredRegroupSweep(sessionId);
      return;
    }

    _sidechainRegroupTimers[sessionId]?.cancel();
    _sidechainRegroupTimers[sessionId] = Timer(
      const Duration(milliseconds: 300),
      () {
        _sidechainRegroupTimers.remove(sessionId);
        _sidechainRegroupFirstRequestMs.remove(sessionId);
        _runDeferredRegroupSweep(sessionId);
      },
    );
  }

  void _runDeferredRegroupSweep(String sessionId) {
    final messages = _sessionMessages[sessionId];
    if (messages == null || messages.isEmpty) return;

    // Only run if there are still ungrouped sidechain messages
    // sitting in the main list (a normal message list has no
    // isSidechain entries after successful grouping).
    final hasOrphans = messages.any(
      (m) => m['isSidechain'] == true,
    );
    if (!hasOrphans) return;

    logger.info(
      '[sidechain] running deferred re-group sweep '
      'for session=$sessionId',
    );
    _groupSidechainMessages(sessionId);
    _notifySessionMessagesChanged(sessionId);
    _notifyDataChanged();
  }

  /// Delegates to [SidechainGrouper] and updates session message
  /// state when grouping modifies the list.
  void _groupSidechainMessages(
    String sessionId, {
    Set<String>? changedIds,
  }) {
    final messages = _sessionMessages[sessionId];
    if (messages == null || messages.isEmpty) return;

    final result = _sidechainGrouper.groupMessages(
      messages,
      changedIds: changedIds,
    );

    if (result == null) return;

    if (result.hasOrphans &&
        !identical(result.messages, messages)) {
      _scheduleSidechainRegroup(sessionId);
    } else if (result.hasOrphans) {
      _scheduleSidechainRegroup(sessionId);
      return;
    }

    if (!identical(result.messages, messages)) {
      _sessionMessages[sessionId] = result.messages;
      _sessionMessagesCache = null;
      _sessionMessagesViewCache.remove(sessionId);
    }
  }

  /// Apply tool results to existing tool-call messages in a session.
  void _applyToolResults(
    String sessionId,
    List<Map<String, dynamic>> toolResults,
  ) {
    if (toolResults.isEmpty) return;

    final existing = _sessionMessages[sessionId] ?? <Map<String, dynamic>>[];
    if (existing.isEmpty) {
      // Queue tool results that arrived before their tool-call message.
      // They will be applied when the tool-call message arrives.
      _pendingToolResults
          .putIfAbsent(sessionId, () => [])
          .addAll(toolResults);
      return;
    }

    final (updated, changed) =
        _toolResultProcessor.applyToolResults(
      existing,
      toolResults,
    );

    if (changed) {
      _sessionMessages[sessionId] = updated;
      _sessionMessagesCache = null;
      _sessionMessagesViewCache.remove(sessionId);
    }
  }

  /// Enrich tool-call messages with permission data from
  /// [AgentState]. Delegates to [ToolResultProcessor].
  void _applyPermissionRequests(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return;

    final agentState = session.agentState;
    if (agentState == null) return;

    final existing = _sessionMessages[sessionId];
    if (existing == null || existing.isEmpty) return;

    final result =
        _toolResultProcessor.applyPermissionRequests(
      existing,
      agentState,
      _notifiedPermissionIds,
    );

    // Cancel notifications for resolved permissions.
    for (final permId in result.resolvedPermIds) {
      _notifiedPermissionIds.remove(permId);
      unawaited(
        NotificationService.instance
            .cancelPermissionNotification(permId),
      );
    }

    if (result.changed) {
      _sessionMessages[sessionId] = result.messages;
      _sessionMessagesCache = null;
      _sessionMessagesViewCache.remove(sessionId);
    }
  }

  void _updateSessionUsage(
    String sessionId,
    Map<String, dynamic> usage,
    int timestamp,
  ) {
    final existing = _sessionUsage[sessionId];
    final existingTs = existing?['timestamp'] as int? ?? 0;
    if (timestamp > existingTs) {
      final inputTokens = usage['input_tokens'] as int? ?? 0;
      final cacheCreation = usage['cache_creation_input_tokens'] as int? ?? 0;
      final cacheRead = usage['cache_read_input_tokens'] as int? ?? 0;
      final outputTokens = usage['output_tokens'] as int? ?? 0;
      _sessionUsage[sessionId] = {
        'inputTokens': inputTokens,
        'outputTokens': outputTokens,
        'cacheCreation': cacheCreation,
        'cacheRead': cacheRead,
        'contextSize': cacheCreation + cacheRead + inputTokens,
        'timestamp': timestamp,
      };
    }
  }

  bool _isMessageListOrdered(List<Map<String, dynamic>> messages) {
    for (var i = 1; i < messages.length; i++) {
      final prevCreated = _asInt(messages[i - 1]['createdAt']) ?? 0;
      final currCreated = _asInt(messages[i]['createdAt']) ?? 0;
      if (prevCreated > currCreated) {
        return false;
      }
      if (prevCreated == currCreated) {
        final prevSeq = messages[i - 1]['seq'] as int? ?? 0;
        final currSeq = messages[i]['seq'] as int? ?? 0;
        if (prevSeq > currSeq) {
          return false;
        }
      }
    }
    return true;
  }

  bool _canAppendMessagesFastPath(
    List<Map<String, dynamic>> existing,
    List<Map<String, dynamic>> incoming,
  ) {
    if (existing.isEmpty || incoming.isEmpty) return false;
    if (!_isMessageListOrdered(incoming)) return false;

    final lastMessage = existing.last;
    final lastCreatedAt = _asInt(lastMessage['createdAt']) ?? 0;
    final lastSeq = lastMessage['seq'] as int? ?? 0;

    // Build a small set of IDs from the tail of the existing list
    // (last 20 entries). This catches the common case of an update
    // to a recently-appended message without scanning the full list.
    // For true id collisions deeper in the list, the full merge path
    // handles them correctly (at O(n) cost, but those are rare).
    final tailStart =
        existing.length > 20 ? existing.length - 20 : 0;
    final recentIds = <String>{};
    for (var i = tailStart; i < existing.length; i++) {
      final id = existing[i]['id'] as String?;
      if (id != null && id.isNotEmpty) recentIds.add(id);
    }

    for (final message in incoming) {
      final messageId = message['id'] as String?;
      if (messageId == null || messageId.isEmpty) {
        return false;
      }

      // If this id already exists in the recent tail, it's an update
      // not an append — fall through to merge.
      if (recentIds.contains(messageId)) {
        return false;
      }

      // Messages with localId may collide with optimistic entries —
      // fall through to the full merge path.
      final localId = message['localId'] as String?;
      if (localId != null && localId.isNotEmpty) {
        return false;
      }

      final createdAt = _asInt(message['createdAt']) ?? 0;
      final seq = message['seq'] as int? ?? 0;
      if (createdAt < lastCreatedAt) {
        return false;
      }
      if (createdAt == lastCreatedAt && seq <= lastSeq) {
        return false;
      }
    }

    return true;
  }

  /// @visibleForTesting
  void testUpsertSessionMessages(
    String sessionId,
    List<Map<String, dynamic>> messages,
  ) {
    _upsertSessionMessages(sessionId, messages);
  }

  void _upsertSessionMessages(
    String sessionId,
    List<Map<String, dynamic>> messages,
  ) {
    final existing = _sessionMessages[sessionId] ?? <Map<String, dynamic>>[];
    const maxMessages = 3000;

    if (_canAppendMessagesFastPath(existing, messages)) {
      final appended = <Map<String, dynamic>>[...existing, ...messages];
      _sessionMessages[sessionId] = appended.length > maxMessages
          ? appended.sublist(appended.length - maxMessages)
          : appended;
      if (sessionId == _visibleSessionId) {
        final afterCount = _sessionMessages[sessionId]?.length ?? 0;
        logger.info(
          '[messages] upsert session=$sessionId '
          'incoming=${messages.length} '
          'before=${existing.length} '
          'after=$afterCount '
          'mode=append',
        );
      }
      _sessionMessagesCache = null;
      _sessionMessagesViewCache.remove(sessionId);
      return;
    }

    final merged = <String, Map<String, dynamic>>{
      for (final message in existing)
        if (message['id'] != null) message['id'] as String: message,
    };
    // Build a reverse index from localId → assigned id, so incoming server
    // messages replace the matching optimistic placeholder.
    // Build a reverse index from localId → assigned id, so incoming server
    // messages replace the matching optimistic placeholder.
    // IMPORTANT: skip empty-string localIds — the Go server sends
    // derefStr(nil) = "" for agent messages, and matching on "" would cause
    // every new agent message to evict a previous one from the list.
    final localIdToId = <String, String>{};
    for (final message in merged.values) {
      final localId = message['localId'] as String?;
      if (localId != null && localId.isNotEmpty && localId != message['id']) {
        localIdToId[localId] = message['id'] as String;
      }
    }
    for (final message in messages) {
      final messageId = message['id'] as String?;
      if (messageId == null || messageId.isEmpty) {
        // Defensive: skip messages without valid ids to prevent crashes.
        // The fast path already filters these at line 7070-7072.
        continue;
      }
      final localId = message['localId'] as String?;
      final hasLocalId = localId != null && localId.isNotEmpty;
      // If this is an incoming server message whose localId matches an
      // optimistic placeholder, remove the placeholder first.
      // Sidechain messages (sub-agent tool calls, sidechain-root
      // prompts) share localId with their parent Task/Agent tool-call
      // but must NOT remove the parent — they are separate messages.
      final isSidechainMsg =
          message['isSidechain'] == true ||
          message['kind'] == 'sidechain-root';
      if (hasLocalId && localId != messageId && !isSidechainMsg) {
        merged.remove(localId);
      }
      // Also remove via the reverse index, but ONLY if the target
      // is an optimistic placeholder (id == localId).  The reverse
      // index (`localIdToId`) maps localId → id for messages where
      // localId != id — so it never points at a placeholder.  When
      // multiple display messages share the same localId (e.g. text
      // + Task1 + Task2 from one assistant turn), the index captures
      // only the last one.  Blindly removing it evicts a sibling
      // message that has already been grouped with sidechain
      // children, causing permanent data loss (the re-added copy
      // from the server batch has no children).
      //
      // The first check (`merged.remove(localId)`) already handles
      // placeholder removal by key (placeholder.id == localId), so
      // this second check is only needed for the case where the
      // placeholder was previously replaced and now has a server id.
      // Guard: skip sidechain messages entirely (they share
      // localId with their parent Task/Agent tool-call).
      if (hasLocalId && !isSidechainMsg) {
        final existingId = localIdToId[localId];
        if (existingId != null && existingId != messageId) {
          // Only remove if the target is the optimistic placeholder
          // (its id matches the localId).  Since localIdToId excludes
          // entries where id == localId, this condition is never true
          // — which is correct: the first check above already removed
          // the placeholder by key.  This guard prevents the reverse
          // index from accidentally evicting sibling messages that
          // share the same localId.
          if (existingId == localId) {
            merged.remove(existingId);
          }
        }
      }
      // Preserve grouped sidechain children and root uuid metadata
      // when replacing a message — the incoming copy from the server
      // does not carry these (they are computed locally by the
      // grouper).  Without this, a delta-fetch that overlaps with
      // inline-processed messages replaces the grouped Task message
      // with a child-less copy, and the sidechain messages that were
      // already removed from the flat list can never be re-grouped.
      final existing = merged[messageId];
      if (existing != null) {
        final existingChildren =
            existing['children'] as List<dynamic>?;
        if (existingChildren != null &&
            existingChildren.isNotEmpty &&
            message['children'] == null) {
          message['children'] = existingChildren;
        }
        final existingRoots =
            existing['_sidechainRootUuids'] as List<dynamic>?;
        if (existingRoots != null &&
            existingRoots.isNotEmpty &&
            message['_sidechainRootUuids'] == null) {
          message['_sidechainRootUuids'] = existingRoots;
        }
      }
      merged[messageId] = message;
    }

    final sorted = merged.values.toList();

    // Optimize: skip sort if already sorted (common case when
    // appending new messages).
    var needsSort = false;
    for (var i = 1; i < sorted.length; i++) {
      final prevCreated = _asInt(sorted[i - 1]['createdAt']) ?? 0;
      final currCreated = _asInt(sorted[i]['createdAt']) ?? 0;
      if (prevCreated > currCreated) {
        needsSort = true;
        break;
      }
      // Also check seq if createdAt is equal.
      if (prevCreated == currCreated) {
        final prevSeq = sorted[i - 1]['seq'] as int? ?? 0;
        final currSeq = sorted[i]['seq'] as int? ?? 0;
        if (prevSeq > currSeq) {
          needsSort = true;
          break;
        }
      }
    }

    if (needsSort) {
      sorted.sort((a, b) {
        final aCreated = _asInt(a['createdAt']) ?? 0;
        final bCreated = _asInt(b['createdAt']) ?? 0;
        if (aCreated != bCreated) {
          return aCreated.compareTo(bCreated);
        }
        return (a['seq'] as int? ?? 0).compareTo(b['seq'] as int? ?? 0);
      });
    }

    _sessionMessages[sessionId] = sorted.length > maxMessages
        ? sorted.sublist(sorted.length - maxMessages)
        : sorted;
    if (sessionId == _visibleSessionId && messages.isNotEmpty) {
      final afterCount = _sessionMessages[sessionId]?.length ?? 0;
      logger.info(
        '[messages] upsert session=$sessionId '
        'incoming=${messages.length} '
        'before=${existing.length} '
        'after=$afterCount '
        'mode=merge',
      );
    }
    _sessionMessagesCache = null;
    _sessionMessagesViewCache.remove(sessionId);
  }
}
