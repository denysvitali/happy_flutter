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
    final flavor = session.metadata?.flavor ?? _settingsSnapshot.lastUsedAgent;
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
            _advanceSeqCursor(targetSessionId, serverSeq);
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
            // Socket is reconnecting — the REST POST already succeeded so
            // the message is stored on the server.  Retry the daemon
            // notification after a delay so the agent picks it up promptly
            // once the socket reconnects, instead of waiting for the next
            // daemon poll cycle (which may be 30+ seconds).
            logger.warning(
              '[sendMessage] socket not connected, scheduling '
              'daemon notification retry '
              'session=$targetSessionId localId=$localId',
            );
            _retryDaemonNotification(
              targetSessionId,
              encryptedRawRecord,
              localId,
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
          } else if (_isSocketConnected()) {
            // Re-check socket — may have reconnected since the earlier
            // snapshot was taken.
            _socketSend('message', {
              'sid': targetSessionId,
              'message': encryptedRawRecord,
              'localId': localId,
            });
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
              Sentry.captureException(
                err,
                stackTrace: StackTrace.current,
              ),
            );
            throw err;
          }
        }

        if (sent && messagesSync.containsKey(targetSessionId)) {
          _startPostSendCatchUp(
            targetSessionId,
            stopAfterSeq: catchUpStopAfterSeq,
          );
        }
      } else {
        logger.warning(
          '[sendMessage] FAILED: status=${response.statusCode} '
          'session=$targetSessionId '
          'body=${response.data}',
        );
        throw StateError('Failed to send message: ${response.statusCode}');
      }
      await transaction.finish(status: const SpanStatus.ok());
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
      if (permanent) {
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
        if (serverSeq != null) {
          _advanceSeqCursor(entry.sessionId, serverSeq);
        }
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
        } else {
          _retryDaemonNotification(
            entry.sessionId,
            entry.encryptedContent,
            entry.localId,
          );
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
      if (m['localId'] == localId || m['id'] == localId) {
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
    }
    if (firstIdx >= 0) {
      msgs[firstIdx] = {...msgs[firstIdx], 'sendStatus': status};
      _sessionMessagesCache = null;
      _sessionMessagesViewCache.remove(sessionId);
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

    final entry = OutboxEntry(
      localId: localId,
      sessionId: sessionId,
      text: text,
      encryptedContent: encryptedRawRecord,
      rawRecord: raw,
      queuedAt: DateTime.now().millisecondsSinceEpoch,
      retryCount: 0, // Reset retry count
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
    // Fire-and-forget: await the socket connection then emit.
    // Guard with catchError so the Future never produces an unhandled
    // error during test teardown or after sync shutdown.
    unawaited(
      socketIoClient
          .waitForConnection(timeout: const Duration(seconds: 10))
          .then((connected) {
            if (!connected || !isInitialized) return;
            if (!_isSocketConnected()) return;
            logger.info(
              '[sendMessage] retrying daemon notification '
              'session=$sessionId localId=$localId',
            );
            _socketSend('message', {
              'sid': sessionId,
              'message': encryptedRawRecord,
              'localId': localId,
            });
          })
          .catchError((_) {
            // Silently swallow — the message is already stored on the server
            // via REST POST and the daemon will pick it up on its next poll.
          }),
    );
  }

  void _startPostSendCatchUp(String sessionId, {required int stopAfterSeq}) {
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

      final currentSeq = _sessionLastSeq[sessionId] ?? 0;
      if (currentSeq >= stopAfterSeq) {
        _postSendCatchUpTimers.remove(sessionId)?.cancel();
        _sessionsNeedingFetchProbe.remove(sessionId);
        logger.info(
          '[sendMessage] catch-up polling ended '
          'session=$sessionId reason=seq_advanced '
          'stopAfter=$stopAfterSeq current=$currentSeq',
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
}
