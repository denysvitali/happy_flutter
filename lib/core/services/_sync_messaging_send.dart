part of 'sync_service.dart';

extension SyncMessagingSend on Sync {
  /// Create a stable client-side message id that can be shared across
  /// optimistic UI, REST persistence, socket forwarding, and retries.
  ///
  /// Returns a raw [String] for backwards compatibility with the many
  /// existing call sites in the codebase.  The same id is also exposed
  /// as a [LocalId] via [createLocalId] for new code that wants the
  /// type-safe variant.
  String createLocalMessageId() => createLocalId().value;

  /// Type-safe variant of [createLocalMessageId] returning a [LocalId].
  ///
  /// Prefer this in new code so the compiler can prevent accidental
  /// mixing with [ServerMessageId] or unrelated [String] values.
  LocalId createLocalId() {
    try {
      return LocalId(encryption.generateId());
    } catch (_) {
      return LocalId(
        '${DateTime.now().microsecondsSinceEpoch}-'
        '${Random().nextInt(1 << 32)}',
      );
    }
  }

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
    String? clientLocalId,
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

    // Compute effective model mode before _resolveSendTargetSession so we can
    // pass it for model-change detection. Use the current session's flavor —
    // if auto-restore spawns a new session the flavor will be correct there.
    final flavor = session.metadata?.flavor ?? settingsSnapshot.lastUsedAgent;
    final isGemini = flavor == 'gemini';
    final requestedModelMode = _normalizeModelModeForAgent(modelMode, flavor);
    final effectiveModelMode =
        requestedModelMode != null && requestedModelMode != 'default'
        ? requestedModelMode
        : isGemini
        ? 'gemini-2.5-pro'
        : 'default';

    final sendTarget = await _resolveSendTargetSession(
      sessionId: sessionId,
      session: session,
      sessionEncryption: sessionEncryption,
      effectivePermissionMode: effectivePermissionMode,
      profileId: profileId,
      modelMode: effectiveModelMode,
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
    final localId = clientLocalId ?? createLocalMessageId();
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

    final sendTransaction =
        Sentry.startTransaction('chat.sendMessage', 'task', bindToScope: false)
          ..setData('sessionId', targetSessionId)
          ..setData('localId', localId)
          ..setData('textLength', text.length)
          ..setData('permissionMode', wirePermissionMode)
          ..setData('model', model ?? 'default');

    // OTel sibling of the Sentry transaction above. The OTel span is
    // also pushed onto the active-span stack so the outbound HTTP POST
    // (and any other spans started from this point onward) become
    // children of chat.send_message, giving a single trace that joins
    // mobile send → server spawn → sub-agent fan-out.
    final otelService = OpenTelemetryService();
    final sendSpan = otelService.startTrace(
      'chat.send_message',
      kind: SpanKind.internal,
      attributes: {
        'session.id': targetSessionId,
        'message.local_id': localId,
        'message.text_length': text.length,
        'message.permission_mode': wirePermissionMode,
        'message.model': model ?? 'default',
        'message.sent_from': sentFrom,
      },
    );
    if (sendSpan != null) {
      otelService.pushCurrentSpan(sendSpan);
    }

    // Ensure catch-up polling is active for this session. Without this,
    // if sendMessage() is called before onSessionVisible() (e.g. from the
    // sessions list before the chat screen initialises), _startPostSendCatchUp
    // silently no-ops and the agent response never appears.
    if (!messagesSync.containsKey(targetSessionId)) {
      unawaited(onSessionVisible(targetSessionId));
    }

    // Sending a message is definitive local activity for this session.
    // Reflect that immediately so the sessions list promotes the row
    // even before the next debounced fetch/update-session round-trip.
    final now = DateTime.now().millisecondsSinceEpoch;
    final currentSession = _sessions[targetSessionId];
    if (currentSession != null) {
      _sessions[targetSessionId] = currentSession.copyWith(
        active: true,
        activeAt: now,
        updatedAt: now,
      );
      _notifyDataChanged({SyncDomain.sessions});
    }

    // Register the minted localId with the invariant monitor so a later ack
    // can distinguish an unknown id (never sent) from an unmatched one (sent,
    // but the optimistic row went missing). Pure observation.
    messageInvariantMonitor.recordOptimisticSent(localId);
    _upsertSessionMessages(targetSessionId, [
      {
        'id': localId,
        'localId': localId,
        'seq': 0,
        'createdAt': now,
        'role': 'user',
        'kind': 'text',
        'content': text,
        'raw': rawRecord,
        'sendStatus': 'sending',
      },
    ]);
    _notifySessionMessagesChanged(targetSessionId);

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

    // lastCompleteSendFuture is exposed for tests to synchronise on.
    final completeSendFuture = _completeSend(
      targetSessionId: targetSessionId,
      localId: localId,
      text: text,
      rawRecord: rawRecord,
      encryptedRawRecord: encryptedRawRecord,
      transaction: sendTransaction,
      otelSpan: sendSpan,
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
    required OTelSpan? otelSpan,
  }) async {
    final apiClient = ApiClient();
    var sent = false;
    var catchUpStopAfterSeq = (_sessionLastSeq[targetSessionId] ?? 0) + 1;
    var handledPermanentFailure = false;
    try {
      if (InvalidateSync.isBackgrounded) {
        logger.info(
          '[sendMessage] app backgrounded before delivery; '
          'queueing outbox retry session=$targetSessionId localId=$localId',
        );
        await messageOutbox.add(
          _createOutboxEntry(
            sessionId: targetSessionId,
            localId: localId,
            text: text,
            encryptedRawRecord: encryptedRawRecord,
            rawRecord: rawRecord,
          ),
        );
        await transaction.finish(status: const SpanStatus.cancelled());
        return;
      }
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
          DateTime.now().millisecondsSinceEpoch - spawnedAt <
              Sync.recentlySpawnedFlagMs;
      final waitBudget = recentlySpawned
          ? Sync.recentlySpawnedWaitMs
          : Sync.sessionReadyTimeoutMs;
      final ready = await waitForAgentReady(targetSessionId, waitBudget);
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
          // Promote the single-line warn to Sentry so we can correlate
          // user-visible "send feels slow" reports with a real spawn-readiness
          // failure. One event per occurrence; the OTel counter below
          // provides the rate.
          unawaited(
            Sentry.captureMessage(
              'sendMessage: spawn readiness timeout',
              level: SentryLevel.warning,
              hint: Hint.withMap({
                'sessionId': targetSessionId,
                'spawnedAt': spawnedAt,
                'waitMs': Sync.recentlySpawnedWaitMs,
                'recentlySpawned': true,
              }),
            ),
          );
          // Mirror the hint into the test-only capture list so tests can
          // assert the exact payload without mocking Sentry directly.
          _spawnReadinessTimeoutCaptures.add({
            'sessionId': targetSessionId,
            'spawnedAt': spawnedAt,
            'waitMs': Sync.recentlySpawnedWaitMs,
            'recentlySpawned': true,
          });
          PowerDiagnosticsOtelReporter.instance.recordAppError(
            'app.session.spawn_timeout',
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
      if (InvalidateSync.isBackgrounded) {
        logger.info(
          '[sendMessage] app backgrounded before POST; '
          'queueing outbox retry session=$targetSessionId localId=$localId',
        );
        await messageOutbox.add(
          _createOutboxEntry(
            sessionId: targetSessionId,
            localId: localId,
            text: text,
            encryptedRawRecord: encryptedRawRecord,
            rawRecord: rawRecord,
          ),
        );
        unawaited(postSpan.finish(status: const SpanStatus.cancelled()));
        await transaction.finish(status: const SpanStatus.cancelled());
        return;
      }
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

        final ackedServerMsg = _findAckedServerMessage(serverMessages, localId);

        if (ackedServerMsg != null) {
          sent = true;
          final serverSeq = _applyServerAckedUserMessage(
            sessionId: targetSessionId,
            localId: localId,
            text: text,
            rawRecord: rawRecord,
            ackedServerMsg: ackedServerMsg,
            logPrefix: '[sendMessage]',
            notifyOnComplete: true,
          );
          if (serverSeq != null) {
            catchUpStopAfterSeq = serverSeq;
          }

          _notifyDaemonOfStoredMessage(
            sessionId: targetSessionId,
            encryptedRawRecord: encryptedRawRecord,
            localId: localId,
            logPrefix: '[sendMessage]',
          );
        } else {
          logger.warning(
            '[sendMessage] REST send had no localId ack; '
            'falling back to socket emit '
            'session=$targetSessionId localId=$localId',
          );
          if (socketConnected) {
            _emitSocketMessage(targetSessionId, encryptedRawRecord, localId);
            sent = true;
            _updateMessageSendStatus(targetSessionId, localId, 'sent');
            _notifySessionMessagesChanged(targetSessionId);
          } else if (_isSocketConnected()) {
            // Re-check socket — may have reconnected since the earlier
            // snapshot was taken.
            _emitSocketMessage(targetSessionId, encryptedRawRecord, localId);
            sent = true;
            _updateMessageSendStatus(targetSessionId, localId, 'sent');
            _notifySessionMessagesChanged(targetSessionId);
          } else {
            final err = StateError(
              'Failed to send message: '
              'server did not acknowledge message',
            );
            logger.error(
              '[sendMessage] server did not acknowledge message '
              'session=$targetSessionId localId=$localId '
              'status=${response.statusCode} body=${response.data}',
            );
            unawaited(
              Sentry.captureException(err, stackTrace: StackTrace.current),
            );
            throw err;
          }
        }

        if (sent && messagesSync.containsKey(targetSessionId)) {
          _startPostSendCatchUp(
            targetSessionId,
            sentUserSeq: catchUpStopAfterSeq,
          );
        }
      } else {
        logger.warning(
          '[sendMessage] FAILED: status=${response.statusCode} '
          'session=$targetSessionId '
          'body=${response.data}',
        );
        final error = StateError(
          'Failed to send message: ${response.statusCode}',
        );
        if (_isPermanentSendFailure(error)) {
          handledPermanentFailure = true;
          transaction.setData('error', error.toString());
          await transaction.finish(status: const SpanStatus.internalError());
          otelSpan?.recordError(error, StackTrace.current);
          otelSpan?.end(ok: false);
          _updateMessageSendStatus(targetSessionId, localId, 'failed');
          _notifySessionMessagesChanged(targetSessionId);
        } else {
          throw error;
        }
      }
      if (!handledPermanentFailure) {
        await transaction.finish(status: const SpanStatus.ok());
        otelSpan?.end(ok: true);
      }
    } catch (e, stack) {
      final permanent = !sent && _isPermanentSendFailure(e);
      // A permanently-unrestorable session is an expected user-facing
      // condition (session deleted on the server), not a code defect —
      // log at warning so it doesn't surface as a Sentry error.
      if (_isRetryableSendFailure(e) ||
          Sync._isTransientConnectionError(e) ||
          permanent) {
        logger.warning('[sendMessage] error sending', e, stack);
      } else {
        logger.error('[sendMessage] error sending', e, stack);
      }
      transaction.setData('error', e.toString());
      await transaction.finish(status: const SpanStatus.internalError());
      otelSpan?.recordError(e, stack);
      otelSpan?.end(ok: false);
      if (permanent) {
        _updateMessageSendStatus(targetSessionId, localId, 'failed');
        _notifySessionMessagesChanged(targetSessionId);
      } else if (!sent) {
        // Queue in the outbox for automatic retry with backoff.
        unawaited(
          messageOutbox.add(
            _createOutboxEntry(
              sessionId: targetSessionId,
              localId: localId,
              text: text,
              encryptedRawRecord: encryptedRawRecord,
              rawRecord: rawRecord,
            ),
          ),
        );
        // The outbox onStatusChanged callback sets 'pending' status.
      }
    }
    // Pop the active OTel span we pushed in sendMessage so the next
    // sync tick (e.g. socket events, post-send catch-up) starts a fresh
    // trace rather than nesting under chat.send_message forever.
    if (otelSpan != null) {
      OpenTelemetryService().popCurrentSpan();
    }
    // Wake any listener that is still waiting on the send attempt; real
    // message mutations above use _notifySessionMessagesChanged and bump the
    // revision.
    _notifySessionMessagesChangedUiOnly(targetSessionId);
  }

  OutboxEntry _createOutboxEntry({
    required String sessionId,
    required String localId,
    required String text,
    required String encryptedRawRecord,
    required Map<String, dynamic> rawRecord,
    int retryCount = 0,
  }) {
    return OutboxEntry(
      localId: localId,
      sessionId: sessionId,
      text: text,
      encryptedContent: encryptedRawRecord,
      rawRecord: rawRecord,
      queuedAt: DateTime.now().millisecondsSinceEpoch,
      retryCount: retryCount,
    );
  }

  void _emitSocketMessage(
    String sessionId,
    String encryptedRawRecord,
    String localId,
  ) {
    _socketSend('message', {
      'sid': sessionId,
      'message': encryptedRawRecord,
      'localId': localId,
    });
  }

  bool _matchesLocalId(Map<String, dynamic> message, String localId) {
    return message['localId'] == localId || message['id'] == localId;
  }

  Map<String, dynamic>? _findAckedServerMessage(
    List<Map<String, dynamic>> serverMessages,
    String localId,
  ) {
    for (final msg in serverMessages) {
      if (msg['localId'] == localId) return msg;
    }
    return null;
  }

  int? _applyServerAckedUserMessage({
    required String sessionId,
    required String localId,
    required String text,
    required Map<String, dynamic> rawRecord,
    required Map<String, dynamic> ackedServerMsg,
    required String logPrefix,
    required bool notifyOnComplete,
  }) {
    final serverId = ackedServerMsg['id'] as String?;
    final serverSeq = _asInt(ackedServerMsg['seq']);
    final serverCreatedAt = _asInt(ackedServerMsg['createdAt']);
    if (serverSeq != null) {
      _advanceSeqCursor(sessionId, serverSeq);
    }
    logger.info(
      '$logPrefix ACK localId=$localId '
      'serverId=${serverId ?? 'null'} '
      'seq=${serverSeq ?? -1}',
    );
    if (serverId != null && serverSeq != null && serverCreatedAt != null) {
      _upsertSessionMessages(sessionId, [
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
      if (notifyOnComplete) {
        _notifySessionMessagesChanged(sessionId);
      }
    } else {
      _updateMessageSendStatus(sessionId, localId, 'sent');
      _notifySessionMessagesChanged(sessionId);
      logger.warning(
        '$logPrefix server ack missing id/seq/createdAt '
        'session=$sessionId localId=$localId',
      );
    }
    return serverSeq;
  }

  void _notifyDaemonOfStoredMessage({
    required String sessionId,
    required String encryptedRawRecord,
    required String localId,
    required String logPrefix,
  }) {
    if (_isSocketConnected()) {
      logger.info(
        '$logPrefix emitting socket message event '
        'session=$sessionId localId=$localId',
      );
      _emitSocketMessage(sessionId, encryptedRawRecord, localId);
      return;
    }

    // Socket is reconnecting; REST already stored the message. Retry the
    // daemon notification so the agent picks it up before its next poll.
    logger.warning(
      '$logPrefix socket not connected, scheduling '
      'daemon notification retry session=$sessionId localId=$localId',
    );
    _retryDaemonNotification(sessionId, encryptedRawRecord, localId);
  }

  /// Returns true for errors that indicate the message will never succeed
  /// (e.g. session doesn't exist).  These should be marked failed
  /// immediately rather than queued for retry.
  static bool _isPermanentSendFailure(Object error) {
    if (error is! StateError) return false;
    final message = error.message;
    // 404 = session not found on server. Retrying won't help.
    if (message.contains('Failed to send message: 404')) {
      return true;
    }
    // Auto-restore resolved the session as permanently gone or
    // unrestorable. The outbox cannot recover it, so mark failed
    // immediately instead of retrying a session that no longer exists.
    if (message.contains('Session not found:') ||
        message.contains('Could not restore')) {
      return true;
    }
    return false;
  }

  static bool _isRetryableSendFailure(Object error) {
    if (error is! StateError) return false;
    final message = error.message;
    return message.contains('Failed to send message: 5') ||
        message.contains('server did not acknowledge message');
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

      final ackedMsg = _findAckedServerMessage(serverMessages, entry.localId);

      if (ackedMsg != null) {
        final serverSeq = _applyServerAckedUserMessage(
          sessionId: entry.sessionId,
          localId: entry.localId,
          text: entry.text,
          rawRecord: entry.rawRecord,
          ackedServerMsg: ackedMsg,
          logPrefix: '[MessageOutbox]',
          notifyOnComplete: false,
        );
        _notifyDaemonOfStoredMessage(
          sessionId: entry.sessionId,
          encryptedRawRecord: entry.encryptedContent,
          localId: entry.localId,
          logPrefix: '[MessageOutbox]',
        );
        if (messagesSync.containsKey(entry.sessionId)) {
          _startPostSendCatchUp(entry.sessionId, sentUserSeq: serverSeq ?? 0);
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
      // Still notify the UI so the message isn't stuck in "pending" state.
      logger.error(
        '[MessageOutbox] local processing threw after HTTP 200 '
        'localId=${entry.localId} — '
        'server has message, treating as delivered',
        e,
        stack,
      );
      _notifySessionMessagesChanged(entry.sessionId);
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
    var matchCount = 0;
    var firstIdx = -1;
    for (var i = 0; i < msgs.length; i++) {
      final m = msgs[i];
      if (_matchesLocalId(m, localId)) {
        matchCount++;
        if (firstIdx == -1) firstIdx = i;
      }
    }
    // Canary invariant #1: exactly one logical message per LocalId.
    // No-op when kCanary is false.
    CanaryAssert.noDuplicateLocalId(
      localId: localId,
      rowCount: matchCount,
      sessionId: sessionId,
    );
    // Canary invariant #2: a `'sent'` ack must have found a matching
    // optimistic placeholder.  If matchCount == 0 the merge code lost
    // the localId↔id mapping somewhere upstream.
    if (status == 'sent') {
      CanaryAssert.ackMatchedOptimistic(
        localId: localId,
        optimisticFound: matchCount > 0,
        sessionId: sessionId,
      );
      // Always-on runtime tap (unlike CanaryAssert, not gated on kCanary):
      // observes unmatched-optimistic, duplicate-localId, and unknown-acked
      // localId on every server ack. Pure observation, never throws.
      messageInvariantMonitor.recordAck(
        localId: localId,
        optimisticRowCount: matchCount,
        sessionId: sessionId,
      );
    }
    if (firstIdx >= 0) {
      msgs[firstIdx] = {...msgs[firstIdx], 'sendStatus': status};
      _invalidateMessageCaches(sessionId);
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

    Map<String, dynamic>? failedMessage;
    for (final m in msgs) {
      if (_matchesLocalId(m, localId)) {
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

    final raw = failedMessage['raw'];
    if (raw == null || raw is! Map<String, dynamic>) {
      logger.warning(
        '[retryFailedMessage] message missing raw data: localId=$localId',
      );
      return;
    }

    // Canary invariant #3: retry MUST reuse the original LocalId.
    // The current code always passes the same `localId` argument
    // through, but this assert guards future refactors where the
    // retry path could accidentally mint a new id.  No-op when
    // kCanary is false.
    final observedLocalId = failedMessage['localId'] as String? ?? localId;
    CanaryAssert.retryPreservesLocalId(
      expected: localId,
      observed: observedLocalId,
    );
    // Always-on runtime tap: a retry must reuse the original localId and
    // must not spawn a second logical row. Count the rows matching the
    // original id so a retry-created duplicate is observable in production.
    var retryRowCount = 0;
    for (final m in msgs) {
      if (_matchesLocalId(m, localId)) retryRowCount++;
    }
    messageInvariantMonitor.recordRetry(
      expected: localId,
      observed: observedLocalId,
      rowCount: retryRowCount,
      sessionId: sessionId,
    );

    final text =
        failedMessage['text'] as String? ??
        failedMessage['content'] as String? ??
        '';

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

    final encryptedRawRecord = await sessionEncryption.encryptRawRecord(raw);

    final entry = _createOutboxEntry(
      sessionId: sessionId,
      localId: localId,
      text: text,
      encryptedRawRecord: encryptedRawRecord,
      rawRecord: raw,
      retryCount: 0,
    );

    _updateMessageSendStatus(sessionId, localId, 'sending');

    await messageOutbox.add(entry);

    logger.info(
      '[retryFailedMessage] queued for retry: '
      'sessionId=$sessionId localId=$localId',
    );

    _notifySessionMessagesChanged(sessionId);
  }

  /// Retry emitting a daemon notification after a brief delay.
  ///
  /// When the socket was reconnecting at the time of the REST POST, the
  /// message is already stored on the server.  This method waits for the
  /// socket to reconnect and then emits the notification so the daemon
  /// processes the message promptly, instead of waiting for its next poll
  /// cycle.  Fires once and gives up silently if the socket doesn't
  /// reconnect within the timeout.
  void _retryDaemonNotification(
    String sessionId,
    String encryptedRawRecord,
    String localId,
  ) {
    if (InvalidateSync.isBackgrounded) return;
    // Fire-and-forget: await the socket connection then emit.
    // Guard with catchError so the Future never produces an unhandled
    // error during test teardown or after sync shutdown.
    unawaited(
      socketIoClient
          .waitForConnection(timeout: const Duration(seconds: 10))
          .then((connected) {
            if (!connected || !isInitialized) return;
            if (InvalidateSync.isBackgrounded) return;
            if (!_isSocketConnected()) return;
            logger.info(
              '[sendMessage] retrying daemon notification '
              'session=$sessionId localId=$localId',
            );
            _emitSocketMessage(sessionId, encryptedRawRecord, localId);
          })
          .catchError((_) {
            // Silently swallow — the message is already stored on the server
            // via REST POST and the daemon will pick it up on its next poll.
          }),
    );
  }

  void _startPostSendCatchUp(String sessionId, {required int sentUserSeq}) {
    _postSendCatchUpTimers.remove(sessionId)?.cancel();
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    bool shouldStop(String reason) {
      if (!isInitialized ||
          !messagesSync.containsKey(sessionId) ||
          DateTime.now().isAfter(deadline)) {
        _postSendCatchUpTimers.remove(sessionId)?.cancel();
        _sessionsNeedingFetchProbe.remove(sessionId);
        logger.info(
          '[sendMessage] catch-up polling ended '
          'session=$sessionId reason=$reason',
        );
        return true;
      }

      if (_hasPostSendResponseAfterSeq(sessionId, sentUserSeq)) {
        _postSendCatchUpTimers.remove(sessionId)?.cancel();
        _sessionsNeedingFetchProbe.remove(sessionId);
        final currentSeq = _sessionLastSeq[sessionId] ?? 0;
        logger.info(
          '[sendMessage] catch-up polling ended '
          'session=$sessionId reason=response_seen '
          'sentSeq=$sentUserSeq current=$currentSeq',
        );
        return true;
      }

      return false;
    }

    bool runProbe() {
      if (shouldStop('timeout_or_inactive')) {
        return false;
      }

      // Force a probe instead of trusting session.lastSeq here. The
      // sessions delta feed can lag behind message storage, so
      // currentSeq >= serverLastSeq does NOT prove the agent has not
      // responded yet.
      _sessionsNeedingFetchProbe.add(sessionId);
      messagesSync[sessionId]?.invalidate();
      return true;
    }

    void startPeriodicPolling() {
      _postSendCatchUpTimers[sessionId] = Timer.periodic(
        const Duration(seconds: 10),
        (_) => runProbe(),
      );
    }

    final shouldDelayInitialProbe =
        sessionId == _visibleSessionId && _isSocketConnected();
    if (shouldDelayInitialProbe) {
      // Visible sessions with a live socket should receive inline updates
      // without an eager history fetch. Keep a short fallback probe so a
      // missed inline event still self-heals quickly.
      _postSendCatchUpTimers[sessionId] = Timer(
        Sync._visiblePostSendProbeDelay,
        () {
          final shouldContinue = runProbe();
          if (!shouldContinue) {
            return;
          }
          startPeriodicPolling();
        },
      );
      return;
    }

    final shouldContinue = runProbe();
    if (!shouldContinue) {
      return;
    }
    startPeriodicPolling();
  }

  bool _hasPostSendResponseAfterSeq(String sessionId, int sentUserSeq) {
    if (sentUserSeq <= 0) return false;

    final messages = _sessionMessages[sessionId];
    if (messages == null || messages.isEmpty) return false;

    for (final message in messages) {
      final seq = _asInt(message['seq']) ?? 0;
      if (seq <= sentUserSeq) continue;
      if (_isPostSendResponseMessage(message)) {
        return true;
      }
    }
    return false;
  }

  bool _isPostSendResponseMessage(Map<String, dynamic> message) {
    if (message['isSidechain'] == true) return false;
    if (message['role'] == MessageRole.agent) return true;

    final kind = message['kind'] as String?;
    if (kind == 'agent-event') {
      final event = WireParsers.asMap(message['event']);
      final type = event?['type'] as String?;
      return type != 'ready' &&
          type != 'thinking' &&
          type != 'tool-execution-update' &&
          type != 'usage_report';
    }
    return kind == 'tool-call' ||
        kind == 'task-event' ||
        message['isThinking'] == true;
  }
}
