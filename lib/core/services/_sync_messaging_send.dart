part of 'sync_service.dart';

/// Wire `content` for an outbound user message: either the legacy
/// single-map text shape (`{'type': 'text', 'text': …}`) or a
/// content-block array (text + image blocks). Dart has no union types,
/// so this stays [Object] — every consumer narrows with `is Map` /
/// `is List` before reading.
typedef _UserOutboundContent = Object;

/// A send failure that no retry can fix (session deleted, or rejected
/// by a precondition). Classified at the throw site where both the
/// status code and the response body are available, so the outbox does
/// not burn its retry budget on a message that can never land.
class PermanentSendFailure extends StateError {
  PermanentSendFailure(super.message);
}

typedef _ResolvedSendOptions = ({
  String effectivePermissionMode,
  String effectiveModelMode,
});

typedef _PreparedSendPayload = ({
  String wirePermissionMode,
  String localId,
  String sentFrom,
  String? model,
  String displayContent,
  Map<String, dynamic> rawRecord,
});

/// Measure one bounded send-preparation phase in both Jaeger and Prometheus.
///
/// Phase and outcome are deliberately the only metric labels. Session ids,
/// local ids, model names, and message content would turn this histogram into
/// a high-cardinality stream (and could expose user-controlled values).
Future<T> _measureSendPreparation<T>({
  required OpenTelemetryService otelService,
  required OTelSpan? parentSpan,
  required String phase,
  required FutureOr<T> Function() body,
}) async {
  final stopwatch = Stopwatch()..start();
  final phaseSpan = parentSpan == null
      ? null
      : otelService.startChildSpan(
          'chat.send.prepare.$phase',
          parent: parentSpan,
          attributes: <String, Object?>{'send.prepare.phase': phase},
        );
  var outcome = 'success';
  try {
    return await Future<T>.sync(body);
  } catch (error, stack) {
    outcome = 'error';
    phaseSpan?.recordError(error, stack);
    rethrow;
  } finally {
    stopwatch.stop();
    otelService.recordDuration(
      'app.chat.send.prepare',
      stopwatch.elapsed,
      attributes: <String, Object?>{'phase': phase, 'outcome': outcome},
      description: 'Outbound message preparation duration by phase',
    );
    phaseSpan?.end(ok: outcome == 'success');
  }
}

void _recordSendPreparationTotal(
  OpenTelemetryService otelService,
  Stopwatch stopwatch, {
  required String outcome,
}) {
  if (stopwatch.isRunning) stopwatch.stop();
  otelService.recordDuration(
    'app.chat.send.prepare',
    stopwatch.elapsed,
    attributes: <String, Object?>{'phase': 'total', 'outcome': outcome},
    description: 'Outbound message preparation duration by phase',
  );
}

/// Hard wall-clock budget covering ONE foreground send attempt end to
/// end: agent-readiness wait plus every HTTP attempt.
///
/// Without it the stages compose serially and unbounded —
/// 15 s waitForAgentReady + 4 Dio attempts with 1/2/4 s backoff — which
/// is the 45.6 s "successful" send in trace
/// 54e38e087cdd4f51912fffeed3d52383. On expiry the message is handed to
/// the outbox and the row flips to 'pending' ("Retry queued") instead of
/// spinning forever.
///
/// Exception: a session spawned within [Sync.recentlySpawnedFlagMs] gets
/// `Sync.recentlySpawnedWaitMs + _kSendMinPostWindow` instead, so the
/// readiness wait it genuinely needs is not silently clamped to 6 s.
const Duration _kSendDeadline = Duration(seconds: 12);

Duration get _sendDeadline => Sync.testSendDeadlineOverride ?? _kSendDeadline;

/// Slice of [_kSendDeadline] reserved for the HTTP POST, so a slow
/// readiness wait can never consume the whole budget.
const Duration _kSendMinPostWindow = Duration(seconds: 6);

Duration get _sendMinPostWindow =>
    Sync.testSendMinPostWindowOverride ?? _kSendMinPostWindow;

/// Bound for the encryption/session recovery round trips in
/// [SyncMessagingSend.sendMessage]. Up to three sequential
/// `invalidateAndAwait()` calls run before the send even starts; they had
/// no timeout at all.
const Duration _kSendRecoveryTimeout = Duration(seconds: 5);

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
  /// The fallback below must stay globally unique: the server dedupes
  /// on `UNIQUE(session_id, local_id)`, and a null/empty/colliding
  /// local_id never conflicts, so every retry would insert a NEW ROW —
  /// the user sees their message duplicated. A silent degradation here
  /// is therefore a correctness bug, not a cosmetic one.
  LocalId createLocalId() {
    try {
      final generated = encryption.generateId();
      if (generated.isNotEmpty) return LocalId(generated);
      throw StateError('encryption.generateId() returned an empty id');
    } catch (error, stack) {
      // 128 bits of randomness (two 32-bit draws) plus a microsecond
      // timestamp: still satisfies the uniqueness contract the server's
      // dedupe key depends on. Loud, because losing the primary id
      // source means every downstream identity guarantee is running on
      // the backup.
      final fallback =
          '${DateTime.now().microsecondsSinceEpoch}-'
          '${Random().nextInt(1 << 32).toRadixString(16)}'
          '${Random().nextInt(1 << 32).toRadixString(16)}';
      logger.error(
        '[createLocalId] encryption.generateId() failed; falling back to '
        'a timestamp+random localId=$fallback — server dedupe depends on '
        'this id being unique',
        error,
        stack,
      );
      unawaited(
        Sentry.captureException(
          error,
          stackTrace: stack,
          hint: Hint.withMap({'context': 'createLocalId fallback'}),
        ),
      );
      return LocalId(fallback);
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
    List<OutgoingImage>? images,
    String? codexDeliveryMode,
  }) async {
    // Mint identity before any fallible setup. Encryption/session recovery can
    // fail before the ordinary optimistic insert, but the user must still get
    // one retryable row carrying the same canonical localId.
    final localId = clientLocalId ?? createLocalMessageId();
    final runtimeGeneration = _runtimeGeneration;
    final optimisticInsertedAtStart = _insertPreparingOptimistic(
      sessionId: sessionId,
      localId: localId,
      text: text,
      displayText: displayText,
      permissionMode: permissionMode,
      modelMode: modelMode,
      images: images,
      codexDeliveryMode: codexDeliveryMode,
      runtimeGeneration: runtimeGeneration,
    );
    // OTel sibling of the Sentry transaction started below. The span is
    // opened BEFORE encryption recovery and target resolution: those can
    // do three sequential `invalidateAndAwait()` round trips and may
    // spawn a session, and none of that used to be inside any span at
    // all — it was invisible even in the root duration.
    //
    // The span is also pushed onto the active-span stack so the outbound
    // HTTP POST (and anything else started from here on) becomes a child
    // of chat.send_message, giving a single trace that joins
    // mobile send → server spawn → sub-agent fan-out.
    final otelService = OpenTelemetryService();
    final prepareStopwatch = Stopwatch()..start();
    final sendSpan = otelService.startTrace(
      'chat.send_message',
      kind: SpanKind.internal,
      attributes: {
        'session.id': sessionId,
        'message.text_length': text.length,
        'message.image_count': images?.length ?? 0,
      },
    );
    try {
      return await _sendMessageTraced(
        sessionId,
        text,
        clientLocalId: localId,
        displayText: displayText,
        permissionMode: permissionMode,
        modelMode: modelMode,
        profileId: profileId,
        images: images,
        codexDeliveryMode: codexDeliveryMode,
        otelService: otelService,
        sendSpan: sendSpan,
        prepareStopwatch: prepareStopwatch,
        optimisticInsertedAtStart: optimisticInsertedAtStart,
      );
    } catch (error, stack) {
      _preserveFailedPreparation(
        sessionId: sessionId,
        localId: localId,
        text: text,
        displayText: displayText,
        permissionMode: permissionMode,
        modelMode: modelMode,
        images: images,
        codexDeliveryMode: codexDeliveryMode,
        runtimeGeneration: runtimeGeneration,
      );
      // Setup failed before _completeSend could take ownership of the
      // span — end it here so the failure is exported instead of leaked.
      _recordSendPreparationTotal(
        otelService,
        prepareStopwatch,
        outcome: 'error',
      );
      sendSpan
        ?..recordError(error, stack)
        ..setAttribute('send.outcome', 'setup_failed')
        ..setAttribute('send.prepare_ms', prepareStopwatch.elapsedMilliseconds)
        ..end(ok: false);
      rethrow;
    }
  }

  bool _insertPreparingOptimistic({
    required String sessionId,
    required String localId,
    required String text,
    required String? displayText,
    required String? permissionMode,
    required String? modelMode,
    required List<OutgoingImage>? images,
    required String? codexDeliveryMode,
    required int runtimeGeneration,
  }) {
    if (!isInitialized || runtimeGeneration != _runtimeGeneration) return false;
    final content = _buildOutboundUserContent(text, images: images);
    final rawRecord = <String, dynamic>{
      'role': 'user',
      'content': content,
      'meta': <String, dynamic>{
        'permissionMode': permissionMode ?? 'default',
        'model': modelMode == 'default' ? null : modelMode,
        'displayText': ?displayText,
        'codexDeliveryMode': ?codexDeliveryMode,
      },
    };
    final now = DateTime.now().millisecondsSinceEpoch;
    messageInvariantMonitor.recordOptimisticSent(localId);
    _upsertSessionMessages(sessionId, [
      {
        'id': localId,
        'localId': localId,
        'seq': 0,
        'createdAt': now,
        'role': 'user',
        'kind': 'text',
        'content': _extractDisplayTextFromUserContent(content, text),
        'raw': rawRecord,
        'sendStatus': 'sending',
      },
    ]);
    _notifySessionMessagesChanged(sessionId);
    return true;
  }

  void _preserveFailedPreparation({
    required String sessionId,
    required String localId,
    required String text,
    required String? displayText,
    required String? permissionMode,
    required String? modelMode,
    required List<OutgoingImage>? images,
    required String? codexDeliveryMode,
    required int runtimeGeneration,
  }) {
    if (!isInitialized || runtimeGeneration != _runtimeGeneration) return;
    final messages = _sessionMessages.putIfAbsent(sessionId, () => []);
    final existing = messages.indexWhere((m) => _matchesLocalId(m, localId));
    if (existing >= 0) {
      _updateMessageSendStatus(sessionId, localId, 'failed');
      _notifySessionMessagesChanged(sessionId);
      return;
    }

    final rawRecord = <String, dynamic>{
      'role': 'user',
      'content': _buildOutboundUserContent(text, images: images),
      'meta': <String, dynamic>{
        'permissionMode': permissionMode ?? 'default',
        'model': modelMode == 'default' ? null : modelMode,
        'displayText': ?displayText,
        'codexDeliveryMode': ?codexDeliveryMode,
      },
    };
    final now = DateTime.now().millisecondsSinceEpoch;
    messageInvariantMonitor.recordOptimisticSent(localId);
    _upsertSessionMessages(sessionId, [
      {
        'id': localId,
        'localId': localId,
        'seq': 0,
        'createdAt': now,
        'role': 'user',
        'kind': 'text',
        'content': _extractDisplayTextFromUserContent(
          rawRecord['content'],
          text,
        ),
        'raw': rawRecord,
        'sendStatus': 'failed',
      },
    ]);
    _notifySessionMessagesChanged(sessionId);
  }

  Future<String> _sendMessageTraced(
    String sessionId,
    String text, {
    required OpenTelemetryService otelService,
    required OTelSpan? sendSpan,
    required Stopwatch prepareStopwatch,
    required bool optimisticInsertedAtStart,
    String? clientLocalId,
    String? displayText,
    String? permissionMode,
    String? modelMode,
    String? profileId,
    List<OutgoingImage>? images,
    String? codexDeliveryMode,
  }) async {
    var sessionEncryption = await _measureSendPreparation<SessionEncryption>(
      otelService: otelService,
      parentSpan: sendSpan,
      phase: 'encryption_context',
      body: () async {
        var resolved = encryption.getSessionEncryption(sessionId);
        if (resolved == null) {
          logger.info(
            '[sendMessage] encryption missing for session=$sessionId, '
            'attempting recovery',
          );
          // Try fetching just this session before doing a full list re-fetch.
          await fetchSingleSession(sessionId);
          resolved = encryption.getSessionEncryption(sessionId);
          if (resolved == null) {
            await _boundedSessionsRefresh();
            resolved = encryption.getSessionEncryption(sessionId);
          }
          if (resolved == null) {
            _forceFullFetchNext = true;
            await _boundedSessionsRefresh();
            resolved = encryption.getSessionEncryption(sessionId);
          }
          if (resolved == null) {
            throw StateError(
              'Session encryption not initialized for $sessionId',
            );
          }
        }
        return resolved;
      },
    );

    var session = await _measureSendPreparation<Session>(
      otelService: otelService,
      parentSpan: sendSpan,
      phase: 'session_context',
      body: () async {
        var resolved = _sessions[sessionId];
        if (resolved == null) {
          // Try fetching just this session instead of a full list re-fetch.
          resolved = await fetchSingleSession(sessionId);
          if (resolved == null) {
            _forceFullFetchNext = true;
            await _boundedSessionsRefresh();
            resolved = _sessions[sessionId];
          }
        }
        if (resolved == null) {
          final now = DateTime.now().millisecondsSinceEpoch;
          resolved = Session(
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
          _sessions[sessionId] = resolved;
          _notifyDataChanged({SyncDomain.sessions});
        }
        return resolved;
      },
    );

    final resolvedOptions = await _measureSendPreparation<_ResolvedSendOptions>(
      otelService: otelService,
      parentSpan: sendSpan,
      phase: 'send_options',
      body: () {
        final requestedPermissionMode = permissionMode;
        final sandboxEnabled = session.metadata?.sandboxEnabled ?? false;
        final storedPermissionMode = session.permissionMode;
        final effectivePermissionMode =
            requestedPermissionMode != null &&
                requestedPermissionMode != 'default'
            ? requestedPermissionMode
            : (storedPermissionMode != null &&
                  storedPermissionMode != 'default')
            ? storedPermissionMode
            : (sandboxEnabled ? 'bypassPermissions' : 'default');

        // Compute before target resolution so model changes can restore.
        final flavor =
            session.metadata?.flavor ?? settingsSnapshot.lastUsedAgent;
        final requestedModelMode = flavor == 'codex' && modelMode != null
            ? (_isClaudeModelAlias(modelMode) ? 'default' : modelMode)
            : _normalizeModelModeForAgent(modelMode, flavor);
        final effectiveModelMode =
            requestedModelMode != null && requestedModelMode != 'default'
            ? requestedModelMode
            : flavor == 'gemini'
            ? 'gemini-2.5-pro'
            : 'default';
        return (
          effectivePermissionMode: effectivePermissionMode,
          effectiveModelMode: effectiveModelMode,
        );
      },
    );
    final effectivePermissionMode = resolvedOptions.effectivePermissionMode;
    final effectiveModelMode = resolvedOptions.effectiveModelMode;

    final sendTarget =
        await _measureSendPreparation<
          ({
            String sessionId,
            Session session,
            SessionEncryption sessionEncryption,
          })
        >(
          otelService: otelService,
          parentSpan: sendSpan,
          phase: 'target_resolution',
          body: () => _resolveSendTargetSession(
            sessionId: sessionId,
            session: session,
            sessionEncryption: sessionEncryption,
            effectivePermissionMode: effectivePermissionMode,
            profileId: profileId,
            modelMode: effectiveModelMode,
          ),
        );
    final targetSessionId = sendTarget.sessionId;
    session = sendTarget.session;
    sessionEncryption = sendTarget.sessionEncryption;

    final payload = await _measureSendPreparation<_PreparedSendPayload>(
      otelService: otelService,
      parentSpan: sendSpan,
      phase: 'payload_build',
      body: () {
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
        final model = effectiveModelMode != 'default'
            ? effectiveModelMode
            : null;
        final outboundContent = _buildOutboundUserContent(text, images: images);
        final displayContent = _extractDisplayTextFromUserContent(
          outboundContent,
          text,
        );
        final rawRecord = <String, dynamic>{
          'role': 'user',
          'content': outboundContent,
          'meta': <String, dynamic>{
            'sentFrom': sentFrom,
            'permissionMode': wirePermissionMode,
            'model': model,
            'fallbackModel': null,
            'appendSystemPrompt': Sync._appendSystemPrompt,
            'displayText': ?displayText,
            'codexDeliveryMode': ?codexDeliveryMode,
          },
        };
        return (
          wirePermissionMode: wirePermissionMode,
          localId: localId,
          sentFrom: sentFrom,
          model: model,
          displayContent: displayContent,
          rawRecord: rawRecord,
        );
      },
    );
    final wirePermissionMode = payload.wirePermissionMode;
    final localId = payload.localId;
    final sentFrom = payload.sentFrom;
    final model = payload.model;
    final displayContent = payload.displayContent;
    final rawRecord = payload.rawRecord;
    logger.info(
      '[sendMessage] START session=$targetSessionId '
      'localId=$localId '
      'requestedSession=$sessionId '
      'mode=$wirePermissionMode '
      'model=${model ?? 'default'} '
      'textLen=${text.length} '
      'images=${images?.length ?? 0}',
    );

    final sendTransaction =
        Sentry.startTransaction('chat.sendMessage', 'task', bindToScope: false)
          ..setData('sessionId', targetSessionId)
          ..setData('localId', localId)
          ..setData('textLength', text.length)
          ..setData('permissionMode', wirePermissionMode)
          ..setData('model', model ?? 'default');

    sendSpan
      ?..setAttribute('session.target_id', targetSessionId)
      ..setAttribute('message.local_id', localId)
      ..setAttribute('message.permission_mode', wirePermissionMode)
      ..setAttribute('message.model', model ?? 'default')
      ..setAttribute('message.sent_from', sentFrom);

    await _measureSendPreparation<void>(
      otelService: otelService,
      parentSpan: sendSpan,
      phase: 'optimistic_insert',
      body: () {
        // Ensure catch-up polling is active for this session. Without this,
        // sends before onSessionVisible() never start response catch-up.
        if (!messagesSync.containsKey(targetSessionId)) {
          unawaited(onSessionVisible(targetSessionId));
        }

        // Sending is definitive local activity. Promote the session before
        // the next debounced fetch/update-session round-trip.
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

        // Auto-restore can redirect the send to a replacement session. Move
        // the already-visible optimistic row rather than showing it in both
        // timelines. For the normal same-session path, the upsert below
        // enriches the early row with the final resolved wire options.
        if (optimisticInsertedAtStart && targetSessionId != sessionId) {
          final requestedMessages = _sessionMessages[sessionId];
          requestedMessages?.removeWhere((m) => _matchesLocalId(m, localId));
          _invalidateMessageCaches(sessionId);
          _notifySessionMessagesChanged(sessionId);
        }
        // Register if startup happened outside an initialized runtime and no
        // early row could be inserted. REST, socket, retry, and merge still
        // share this same canonical localId.
        if (!optimisticInsertedAtStart) {
          messageInvariantMonitor.recordOptimisticSent(localId);
        }
        _upsertSessionMessages(targetSessionId, [
          {
            'id': localId,
            'localId': localId,
            'seq': 0,
            'createdAt': now,
            'role': 'user',
            'kind': 'text',
            'content': displayContent,
            'raw': rawRecord,
            'sendStatus': 'sending',
          },
        ]);
        _notifySessionMessagesChanged(targetSessionId);
      },
    );

    // Encrypt after the optimistic insert so the user sees instant feedback.
    // The encrypted record is only needed for the HTTP POST to the server.
    final encryptedRawRecord = await _measureSendPreparation<String>(
      otelService: otelService,
      parentSpan: sendSpan,
      phase: 'encryption',
      body: () async {
        final encryptSpan = sendTransaction.startChild(
          'chat.encrypt',
          description: 'Encrypt message for session',
        );
        try {
          return await sessionEncryption.encryptRawRecord(rawRecord);
        } finally {
          unawaited(encryptSpan.finish());
        }
      },
    );

    _recordSendPreparationTotal(
      otelService,
      prepareStopwatch,
      outcome: 'success',
    );
    sendSpan?.setAttribute(
      'send.prepare_ms',
      prepareStopwatch.elapsedMilliseconds,
    );

    // lastCompleteSendFuture is exposed for tests to synchronise on.
    final prepareMs = prepareStopwatch.elapsedMilliseconds;
    Future<void> completeSend() => _completeSend(
      prepareMs: prepareMs,
      targetSessionId: targetSessionId,
      localId: localId,
      text: displayContent,
      rawRecord: rawRecord,
      encryptedRawRecord: encryptedRawRecord,
      transaction: sendTransaction,
      otelSpan: sendSpan,
    );
    final completeSendFuture = messageOutbox.serialize(
      targetSessionId,
      () => sendSpan == null
          ? completeSend()
          : otelService.withActiveSpan(sendSpan, completeSend),
    );
    lastCompleteSendFuture = completeSendFuture;
    unawaited(completeSendFuture);

    return targetSessionId;
  }

  /// `sessionsSync.invalidateAndAwait()` with a bound.
  ///
  /// The pre-send recovery path can run three of these back to back with
  /// no timeout at all, entirely ahead of the send's own budget. A stalled
  /// sessions fetch must not hold a user message hostage — on expiry we
  /// fall through and let the caller decide (session synthesis, or the
  /// outbox).
  Future<void> _boundedSessionsRefresh() async {
    try {
      await sessionsSync.invalidateAndAwait().timeout(_kSendRecoveryTimeout);
    } on TimeoutException {
      logger.warning(
        '[sendMessage] sessions refresh exceeded '
        '${_kSendRecoveryTimeout.inSeconds}s during send recovery; '
        'continuing without it',
      );
    }
  }

  /// Background half of [sendMessage]: waits for agent, POSTs to REST,
  /// emits socket event, and updates the optimistic message status.
  Future<void> _completeSend({
    required int prepareMs,
    required String targetSessionId,
    required String localId,
    required String text,
    required Map<String, dynamic> rawRecord,
    required String encryptedRawRecord,
    required ISentrySpan transaction,
    required OTelSpan? otelSpan,
  }) async {
    final runtimeGeneration = _runtimeGeneration;
    bool runtimeIsStale() =>
        runtimeGeneration != _runtimeGeneration || !isInitialized;
    final apiClient = ApiClient();
    final sendStopwatch = Stopwatch()..start();
    // A freshly-spawned session legitimately needs up to
    // Sync.recentlySpawnedWaitMs before it can receive anything (pod
    // start is routinely >10 s). Clamping that wait into the ordinary
    // 12 s budget would leave it 6 s, turn every spawn-then-send into a
    // spurious 'spawn readiness timeout' alarm, and lie about how long
    // the client actually waited. Spawned sends therefore get their own,
    // longer deadline: the full readiness wait PLUS the reserved POST
    // window. Ordinary sends keep _kSendDeadline.
    final spawnedAt = _sessionSpawnedAt[targetSessionId];
    final recentlySpawned =
        spawnedAt != null &&
        DateTime.now().millisecondsSinceEpoch - spawnedAt <
            Sync.recentlySpawnedFlagMs;
    final sendBudget = recentlySpawned
        ? Duration(milliseconds: Sync._recentlySpawnedWaitBudgetMs) +
              _sendMinPostWindow
        : _sendDeadline;
    final sendDeadline = DateTime.now().add(sendBudget);
    var sent = false;
    var ackedByServer = false;
    var catchUpStopAfterSeq = (_sessionLastSeq[targetSessionId] ?? 0) + 1;
    var handledPermanentFailure = false;
    // Outcome vocabulary for the root span. A 45 s "success" is not a
    // success, and a socket-fallback delivery is not a clean one — the
    // parent span must say which of those happened instead of always
    // reporting ok.
    var outcome = 'unknown';
    var ready = false;
    try {
      if (InvalidateSync.isBackgrounded) {
        logger.info(
          '[sendMessage] app backgrounded before delivery; '
          'queueing outbox retry session=$targetSessionId localId=$localId',
        );
        await _queueMessageRetry(
          sessionId: targetSessionId,
          localId: localId,
          text: text,
          encryptedRawRecord: encryptedRawRecord,
          rawRecord: rawRecord,
        );
        outcome = 'backgrounded';
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
      final requestedWaitBudget = recentlySpawned
          ? Sync._recentlySpawnedWaitBudgetMs
          : Sync.sessionReadyTimeoutMs;
      // Clamp the wait so it can never eat the whole send budget: the
      // POST always keeps at least _kSendMinPostWindow. Spawned sends
      // are exempt — their deadline was sized above to fit the full
      // readiness wait plus that same POST window, so clamping them
      // again would only shave off the elapsed milliseconds.
      final waitBudget = recentlySpawned
          ? requestedWaitBudget
          : min(
              requestedWaitBudget,
              max(
                0,
                _remainingSendBudget(sendDeadline).inMilliseconds -
                    _sendMinPostWindow.inMilliseconds,
              ),
            );
      final otelWaitSpan = otelSpan == null
          ? null
          : OpenTelemetryService().startChildSpan(
              'chat.wait_for_agent',
              parent: otelSpan,
              kind: SpanKind.internal,
              attributes: {
                'session.id': targetSessionId,
                'agent.recently_spawned': recentlySpawned,
                'agent.wait_budget_ms': waitBudget,
                'agent.wait_budget_requested_ms': requestedWaitBudget,
              },
            );
      try {
        ready = await waitForAgentReady(targetSessionId, waitBudget);
        if (runtimeIsStale()) return;
        otelWaitSpan
          ?..setAttribute('agent.ready', ready)
          ..end(ok: ready);
      } catch (error, stack) {
        otelWaitSpan
          ?..recordError(error, stack)
          ..end(ok: false);
        rethrow;
      }
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
              // waitMs must be what the client ACTUALLY waited, not the
              // nominal constant: a clamped budget used to be reported
              // as 15 000 ms on a 6 s wait.
              hint: Hint.withMap({
                'sessionId': targetSessionId,
                'spawnedAt': spawnedAt,
                'waitMs': waitBudget,
                'requestedWaitMs': requestedWaitBudget,
                'recentlySpawned': true,
              }),
            ),
          );
          // Mirror the hint into the test-only capture list so tests can
          // assert the exact payload without mocking Sentry directly.
          _spawnReadinessTimeoutCaptures.add({
            'sessionId': targetSessionId,
            'spawnedAt': spawnedAt,
            'waitMs': waitBudget,
            'requestedWaitMs': requestedWaitBudget,
            'recentlySpawned': true,
          });
          PowerDiagnosticsOtelReporter.instance.recordAppError(
            'app.session.spawn_timeout',
          );
          logger.info(
            '[sendMessage] recently spawned agent not ready; '
            'queueing until ready session=$targetSessionId '
            'localId=$localId',
          );
          await _queueMessageRetry(
            sessionId: targetSessionId,
            localId: localId,
            text: text,
            encryptedRawRecord: encryptedRawRecord,
            rawRecord: rawRecord,
          );
          outcome = 'agent_starting';
          transaction.setData('queuedForReadiness', true);
          await transaction.finish(status: const SpanStatus.deadlineExceeded());
          return;
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
        await _queueMessageRetry(
          sessionId: targetSessionId,
          localId: localId,
          text: text,
          encryptedRawRecord: encryptedRawRecord,
          rawRecord: rawRecord,
        );
        outcome = 'backgrounded';
        unawaited(postSpan.finish(status: const SpanStatus.cancelled()));
        await transaction.finish(status: const SpanStatus.cancelled());
        return;
      }
      // One deadline over the whole attempt. ApiClient retries the POST
      // up to 4 times with 1/2/4 s backoff; without this cap the retries
      // stack on top of the readiness wait and the user watches a
      // spinner for 45 s. On expiry the outbox owns the message.
      final postBudget = _remainingSendBudget(sendDeadline);
      final Response<dynamic> response;
      try {
        response = await apiClient
            .post(
              '/v3/sessions/$targetSessionId/messages',
              options: Options(
                sendTimeout: Sync._messageSendTimeout,
                receiveTimeout: Sync._messageSendTimeout,
              ),
              data: {
                'messages': [
                  {'content': encryptedRawRecord, 'localId': localId},
                ],
              },
            )
            .timeout(postBudget);
      } on TimeoutException catch (error, stack) {
        if (runtimeIsStale()) return;
        logger.warning(
          '[sendMessage] send deadline exceeded after '
          '${sendStopwatch.elapsedMilliseconds}ms; handing to outbox '
          'session=$targetSessionId localId=$localId',
          error,
          stack,
        );
        outcome = 'deadline_exceeded';
        unawaited(postSpan.finish(status: const SpanStatus.deadlineExceeded()));
        await transaction.finish(status: const SpanStatus.deadlineExceeded());
        PowerDiagnosticsOtelReporter.instance.recordAppError(
          'app.send.deadline_exceeded',
        );
        // The row flips to 'pending' ("Retry queued") via the outbox
        // status callback, so the user sees a real state instead of an
        // eternal spinner. If the retry then finds the message already
        // persisted, the row is upgraded to "Delivered · slow" rather than
        // leaving the user with a degraded-looking send that landed.
        _registerSendDeadline(localId);
        await _queueMessageRetry(
          sessionId: targetSessionId,
          localId: localId,
          text: text,
          encryptedRawRecord: encryptedRawRecord,
          rawRecord: rawRecord,
        );
        return;
      }
      if (runtimeIsStale()) return;
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
        final serverMessages = _serverMessagesFromResponseData(data);
        logger.info(
          '[sendMessage] response contained '
          '${serverMessages.length} message(s) localId=$localId',
        );

        final ackedServerMsg = _findAckedServerMessage(serverMessages, localId);

        if (ackedServerMsg != null) {
          sent = true;
          ackedByServer = true;
          final serverSeq = _applyStoredUserMessageAck(
            sessionId: targetSessionId,
            localId: localId,
            text: text,
            rawRecord: rawRecord,
            encryptedRawRecord: encryptedRawRecord,
            ackedServerMsg: ackedServerMsg,
            logPrefix: '[sendMessage]',
            notifyOnComplete: true,
          );
          if (serverSeq != null) {
            catchUpStopAfterSeq = serverSeq;
          }
        } else {
          logger.warning(
            '[sendMessage] REST send had no localId ack; '
            'falling back to socket emit '
            'session=$targetSessionId localId=$localId',
          );
          // A 200 with no localId ack is a DEGRADED delivery: the server
          // never confirmed our identity for this message, so the span
          // must not report a clean success.
          if (socketConnected || _isSocketConnected()) {
            // The second check re-reads the socket — it may have
            // reconnected since the earlier snapshot was taken.
            _emitSocketMessage(targetSessionId, encryptedRawRecord, localId);
            sent = true;
            outcome = 'socket_fallback';
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
        final status = response.statusCode ?? 0;
        // Classify here, where the body is still in hand: the server
        // collapses NotFound into a bare 500, so the status code alone
        // sends a deleted session down the retryable branch and burns
        // 4 HTTP + 3 outbox attempts.
        final permanent =
            _isPermanentSendStatus(status) ||
            _sendBodyIndicatesSessionGone(response.data);
        final error = permanent
            ? PermanentSendFailure('Failed to send message: $status')
            : StateError('Failed to send message: $status');
        if (permanent) {
          handledPermanentFailure = true;
          outcome = 'permanent_failure';
          transaction.setData('error', error.toString());
          await transaction.finish(status: const SpanStatus.internalError());
          otelSpan?.recordError(error, StackTrace.current);
          _updateMessageSendStatus(targetSessionId, localId, 'failed');
          _notifySessionMessagesChanged(targetSessionId);
        } else {
          throw error;
        }
      }
      if (!handledPermanentFailure) {
        if (outcome == 'unknown') {
          outcome = ready ? 'ok' : 'agent_not_ready';
        }
        await transaction.finish(status: const SpanStatus.ok());
      }
    } catch (e, stack) {
      if (runtimeIsStale()) return;
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
      outcome = permanent ? 'permanent_failure' : 'error';
      if (permanent) {
        _updateMessageSendStatus(targetSessionId, localId, 'failed');
        _notifySessionMessagesChanged(targetSessionId);
      } else if (!sent) {
        // Queue in the outbox for automatic retry with backoff.
        unawaited(
          _queueMessageRetry(
            sessionId: targetSessionId,
            localId: localId,
            text: text,
            encryptedRawRecord: encryptedRawRecord,
            rawRecord: rawRecord,
          ),
        );
        // The outbox onStatusChanged callback sets 'pending' status.
      }
    } finally {
      // Single exit point for the root span. Both backgrounded early
      // returns used to skip every end() — and a BatchSpanProcessor only
      // exports on end, so every backgrounded send produced zero
      // telemetry. Sends on flaky mobile links are exactly the ones that
      // background mid-flight, so the worst cases were the most
      // under-reported.
      sendStopwatch.stop();
      final elapsedMs = sendStopwatch.elapsedMilliseconds;
      // A slow success is not a success: flag it so the latency tail is
      // visible in the outcome dimension, not only in span duration.
      final degraded =
          outcome != 'ok' || elapsedMs >= _sendDeadline.inMilliseconds ~/ 2;
      otelSpan
        ?..setAttribute('send.outcome', outcome)
        ..setAttribute('send.elapsed_ms', elapsedMs)
        // `send.elapsed_ms` covers only the post-prepare budget. The
        // prepare phase (encryption recovery, up to three bounded
        // sessions refreshes, an auto-restore spawn) runs before the
        // deadline starts, so the user-perceived latency is the sum.
        ..setAttribute('send.total_ms', prepareMs + elapsedMs)
        ..setAttribute('send.agent_ready', ready)
        ..setAttribute('send.acked_by_server', ackedByServer)
        ..setAttribute('send.degraded', degraded)
        ..end(ok: ready && sent && ackedByServer);
      // Wake any listener that is still waiting on the send attempt; real
      // message mutations above use _notifySessionMessagesChanged and bump
      // the revision.
      _notifySessionMessagesChangedUiOnly(targetSessionId);
    }
  }

  /// Time left before the whole-send deadline, floored at 1 s so an
  /// already-blown budget still issues one bounded request rather than
  /// failing instantly.
  Duration _remainingSendBudget(DateTime deadline) {
    final remaining = deadline.difference(DateTime.now());
    return remaining < const Duration(seconds: 1)
        ? const Duration(seconds: 1)
        : remaining;
  }

  Future<void> _queueMessageRetry({
    required String sessionId,
    required String localId,
    required String text,
    required String encryptedRawRecord,
    required Map<String, dynamic> rawRecord,
    int retryCount = 0,
  }) {
    return messageOutbox
        .add(
          OutboxEntry(
            localId: localId,
            sessionId: sessionId,
            text: text,
            encryptedContent: encryptedRawRecord,
            rawRecord: rawRecord,
            queuedAt: DateTime.now().millisecondsSinceEpoch,
            retryCount: retryCount,
          ),
        )
        .catchError((Object error, StackTrace stack) {
          logger.error(
            '[MessageOutbox] durable enqueue failed '
            'session=$sessionId localId=$localId',
            error,
            stack,
          );
          _updateMessageSendStatus(sessionId, localId, 'failed');
          _notifySessionMessagesChanged(sessionId);
        });
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

  int _countLocalIdMatches(String sessionId, String localId) {
    final msgs = _sessionMessages[sessionId];
    if (msgs == null) return 0;
    var count = 0;
    for (final msg in msgs) {
      if (_matchesLocalId(msg, localId)) count++;
    }
    return count;
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

  List<Map<String, dynamic>> _serverMessagesFromResponseData(
    Map<String, dynamic>? data,
  ) {
    return (data?['messages'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  int? _applyStoredUserMessageAck({
    required String sessionId,
    required String localId,
    required String text,
    required Map<String, dynamic> rawRecord,
    required String encryptedRawRecord,
    required Map<String, dynamic> ackedServerMsg,
    required String logPrefix,
    required bool notifyOnComplete,
  }) {
    final serverSeq = _applyServerAckedUserMessage(
      sessionId: sessionId,
      localId: localId,
      text: text,
      rawRecord: rawRecord,
      ackedServerMsg: ackedServerMsg,
      logPrefix: logPrefix,
      notifyOnComplete: notifyOnComplete,
    );
    _notifyDaemonOfStoredMessage(
      sessionId: sessionId,
      encryptedRawRecord: encryptedRawRecord,
      localId: localId,
      logPrefix: logPrefix,
    );
    return serverSeq;
  }

  void _acceptStoredUserMessageWithoutAck({
    required String sessionId,
    required String localId,
    required String encryptedRawRecord,
    required String logPrefix,
  }) {
    logger.warning(
      '$logPrefix no localId ack localId=$localId - '
      'HTTP 200 accepted, treating as delivered',
    );
    _notifyDaemonOfStoredMessage(
      sessionId: sessionId,
      encryptedRawRecord: encryptedRawRecord,
      localId: localId,
      logPrefix: logPrefix,
    );
    _updateMessageSendStatus(sessionId, localId, 'sent');
    _notifySessionMessagesChanged(sessionId);
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
      messageInvariantMonitor.recordAck(
        localId: localId,
        optimisticRowCount: _countLocalIdMatches(sessionId, localId),
        sessionId: sessionId,
      );
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
    if (error is PermanentSendFailure) return true;
    if (error is! StateError) return false;
    final message = error.message;
    final status = _sendStatusCodeFrom(message);
    if (status != null && _isPermanentSendStatus(status)) {
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

  static final RegExp _sendStatusCodeRegExp = RegExp(
    r'Failed to send message: (\d{3})',
  );

  static int? _sendStatusCodeFrom(String message) {
    final match = _sendStatusCodeRegExp.firstMatch(message);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  /// Status codes that no amount of retrying can fix.
  ///
  /// 404 Not Found / 410 Gone: the session is not on the server.
  /// 409 Conflict / 412 Failed Precondition: the session exists but is
  /// in a state that rejects the write — the daemon's `FailedPrecondition`
  /// maps here. Retrying just burns the outbox budget.
  static bool _isPermanentSendStatus(int statusCode) {
    return statusCode == 404 ||
        statusCode == 409 ||
        statusCode == 410 ||
        statusCode == 412;
  }

  static final RegExp _sessionGoneBodyRegExp = RegExp(
    r'not[\s_-]?found|no such session|session[\s_-]?gone|'
    r'failed[\s_-]?precondition|unknown session',
    caseSensitive: false,
  );

  /// Defensive body sniff for a "session is gone" error.
  ///
  /// The server currently collapses NotFound into a bare HTTP 500 (a
  /// server-side fix is in flight). Until that ships, trusting the
  /// status code alone sends a deleted session down the retryable
  /// `:5xx` branch and burns 4 HTTP attempts plus 3 outbox attempts.
  static bool _sendBodyIndicatesSessionGone(Object? body) {
    if (body == null) return false;
    final text = body.toString();
    final sample = text.length > 512 ? text.substring(0, 512) : text;
    return _sessionGoneBodyRegExp.hasMatch(sample);
  }

  static bool _isRetryableSendFailure(Object error) {
    if (error is! StateError) return false;
    final message = error.message;
    return message.contains('Failed to send message: 5') ||
        message.contains('server did not acknowledge message');
  }

  /// Classifies a non-2xx HTTP [status] from the message endpoint as an
  /// outbox delivery failure.
  ///
  /// The endpoint is idempotent (ON CONFLICT DO NOTHING), so anything
  /// short of a definitive rejection is worth retrying: 5xx, 408 and 429
  /// are transient, other 4xx are permanent. The body is checked FIRST
  /// because the server collapses NotFound into a bare 500 — the status
  /// code alone would send a deleted session down the hours-long
  /// transient path.
  static OutboxDeliveryFailure _classifySendHttpStatus(
    int status,
    Object? body,
  ) {
    if (_sendBodyIndicatesSessionGone(body)) {
      return const OutboxDeliveryFailure(
        OutboxFailureClass.permanent,
        'session_gone',
      );
    }
    if (status >= 500) {
      return const OutboxDeliveryFailure(
        OutboxFailureClass.transient,
        'server_error',
      );
    }
    if (status == 408 || status == 429) {
      return const OutboxDeliveryFailure(
        OutboxFailureClass.transient,
        'rate_limited',
      );
    }
    final gone =
        _isPermanentSendStatus(status) || _sendBodyIndicatesSessionGone(body);
    return OutboxDeliveryFailure(
      OutboxFailureClass.permanent,
      gone ? 'session_gone' : 'client_rejected',
    );
  }

  /// Outbox delivery callback: re-attempt a single queued message.
  ///
  /// Returns `null` on success, or an [OutboxDeliveryFailure] whose class
  /// selects the outbox retry budget (transient retries for hours,
  /// permanent dead-letters quickly).
  Future<OutboxDeliveryFailure?> _deliverOutboxEntry(OutboxEntry entry) async {
    if (!isInitialized) {
      return const OutboxDeliveryFailure(
        OutboxFailureClass.transient,
        'sync_not_ready',
      );
    }

    final session = _sessions[entry.sessionId];
    final lifecycle = session?.effectiveLifecycleState?.toLowerCase();
    if (lifecycle == 'starting' || lifecycle == 'connecting') {
      logger.info(
        '[MessageOutbox] deferring delivery until agent readiness '
        'session=${entry.sessionId} localId=${entry.localId} '
        'lifecycle=$lifecycle',
      );
      return const OutboxDeliveryFailure(
        OutboxFailureClass.transient,
        'agent_starting',
      );
    }

    final apiClient = ApiClient();
    final Response<dynamic> response;
    try {
      response = await apiClient.post(
        '/v3/sessions/${entry.sessionId}/messages',
        options: Options(
          sendTimeout: Sync._messageSendTimeout,
          receiveTimeout: Sync._messageSendTimeout,
        ),
        data: {
          'messages': [
            {'content': entry.encryptedContent, 'localId': entry.localId},
          ],
        },
      );
    } on DioException catch (e, stack) {
      final serverResponse = e.response;
      if (serverResponse == null) {
        // No HTTP response means the request never reached the server
        // (DNS failure, connection abort, timeout before headers, etc.).
        // Let the outbox retry; the server does not have the message yet.
        logger.warning(
          '[MessageOutbox] delivery failed without server response '
          'localId=${entry.localId} — will retry',
          e,
          stack,
        );
        final isTimeout =
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout;
        return OutboxDeliveryFailure(
          OutboxFailureClass.transient,
          isTimeout ? 'timeout' : 'network',
        );
      }

      if (!apiClient.isSuccess(serverResponse)) {
        logger.warning(
          '[MessageOutbox] delivery failed '
          'status=${serverResponse.statusCode} '
          'localId=${entry.localId}',
        );
        return _classifySendHttpStatus(
          serverResponse.statusCode ?? 0,
          serverResponse.data,
        );
      }

      // A 2xx response was received but the request still threw (defensive:
      // this should not happen with Dio's default validateStatus). Trust the
      // idempotent server storage and treat the message as delivered.
      logger.error(
        '[MessageOutbox] local processing threw after HTTP 200 '
        'localId=${entry.localId} — '
        'server has message, treating as delivered',
        e,
        stack,
      );
      _notifySessionMessagesChanged(entry.sessionId);
      return null;
    }

    if (!apiClient.isSuccess(response)) {
      logger.warning(
        '[MessageOutbox] re-send failed '
        'status=${response.statusCode} '
        'localId=${entry.localId}',
      );
      return _classifySendHttpStatus(response.statusCode ?? 0, response.data);
    }

    try {
      final data = WireParsers.asMap(response.data);
      final serverMessages = _serverMessagesFromResponseData(data);

      final ackedMsg = _findAckedServerMessage(serverMessages, entry.localId);

      if (ackedMsg != null) {
        final serverSeq = _applyStoredUserMessageAck(
          sessionId: entry.sessionId,
          localId: entry.localId,
          text: entry.text,
          rawRecord: entry.rawRecord,
          encryptedRawRecord: entry.encryptedContent,
          ackedServerMsg: ackedMsg,
          logPrefix: '[MessageOutbox]',
          notifyOnComplete: false,
        );
        if (messagesSync.containsKey(entry.sessionId)) {
          _startPostSendCatchUp(entry.sessionId, sentUserSeq: serverSeq ?? 0);
        }
        _reportSlowSendConfirmed(entry);
        logger.info(
          '[MessageOutbox] delivered localId=${entry.localId} '
          'session=${entry.sessionId}',
        );
        return null;
      }

      // Server accepted but no localId ack. Trust the HTTP 200 since the
      // server uses idempotent storage (ON CONFLICT DO NOTHING).
      _acceptStoredUserMessageWithoutAck(
        sessionId: entry.sessionId,
        localId: entry.localId,
        encryptedRawRecord: entry.encryptedContent,
        logPrefix: '[MessageOutbox]',
      );
      if (messagesSync.containsKey(entry.sessionId)) {
        _startPostSendCatchUp(entry.sessionId, sentUserSeq: 0);
      }
      _reportSlowSendConfirmed(entry);
      return null;
    } catch (e, stack) {
      // Exceptions during local processing (after HTTP 200 was received)
      // do NOT count as delivery failures — the server has already stored
      // the message. Counting exceptions as failures risks permanently
      // losing a message that the server already has (e.g., after 3 retries
      // the client marks it as failed even though the server stored it).
      // Still notify the UI so the message isn't stuck in "pending" state.
      logger.error(
        '[MessageOutbox] local processing threw after HTTP 200 '
        'localId=${entry.localId} — '
        'server has message, treating as delivered',
        e,
        stack,
      );
      _notifySessionMessagesChanged(entry.sessionId);
      return null;
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
      final currentStatus = msgs[firstIdx]['sendStatus'] as String?;
      // Server acknowledgement is terminal. A delayed retry timer or outbox
      // status callback must never regress a confirmed row to pending/failed.
      if (currentStatus == 'sent' && status != 'sent') return;
      msgs[firstIdx] = {...msgs[firstIdx], 'sendStatus': status};
      _invalidateMessageCaches(sessionId);
    }
  }

  /// Upgrades a deadline-timed-out send to "delivered, slowly" once the
  /// retry proves the server already had it.
  ///
  /// Same `localId`, same logical message, same `'sent'` status — only the
  /// display hint and the telemetry outcome change, so the send that the
  /// client gave up on stops being reported as degraded after it landed.
  void _reportSlowSendConfirmed(OutboxEntry entry) {
    if (!_consumeSendDeadline(entry.localId)) return;
    _markSendSlow(entry.sessionId, entry.localId);
    _notifySessionMessagesChanged(entry.sessionId);
    logger.info(
      '[MessageOutbox] slow send confirmed — server already had the '
      'message session=${entry.sessionId} localId=${entry.localId}',
    );
    OpenTelemetryService().recordCount(
      'app.send.sent_slow',
      description:
          'Sends that blew the client deadline but were already '
          'persisted server-side when the retry confirmed them',
    );
  }

  /// Remembers that [localId] was handed to the outbox because the client
  /// gave up on its own deadline, not because the server rejected it.
  ///
  /// Three receive-timeout traces showed the message had already been
  /// persisted before the client stopped waiting: the retry POST came back
  /// 200 in 93-379ms and the server's `ON CONFLICT (session_id, local_id)`
  /// dedupe returned the existing row. That is a slow send, not a failed
  /// one, and the UI should say so once the retry confirms it.
  void _registerSendDeadline(String localId) {
    if (localId.isEmpty) return;
    if (_sendDeadlineLocalIds.add(localId)) {
      _sendDeadlineLocalIdOrder.addLast(localId);
    }
    while (_sendDeadlineLocalIdOrder.length > Sync._maxSendDeadlineLocalIds) {
      _sendDeadlineLocalIds.remove(_sendDeadlineLocalIdOrder.removeFirst());
    }
  }

  bool _consumeSendDeadline(String localId) {
    if (!_sendDeadlineLocalIds.remove(localId)) return false;
    _sendDeadlineLocalIdOrder.remove(localId);
    return true;
  }

  /// Marks the row for [localId] as "delivered, but slowly".
  ///
  /// Purely additive: `sendStatus` stays `'sent'` and `localId` is
  /// untouched, so nothing in the identity contract, the FSM, or the merge
  /// path sees a new state. The flag only lets the bubble say "Delivered ·
  /// slow" instead of leaving the user on the preceding "Retry queued".
  void _markSendSlow(String sessionId, String localId) {
    final msgs = _sessionMessages[sessionId];
    if (msgs == null) return;
    final idx = msgs.indexWhere((m) => _matchesLocalId(m, localId));
    if (idx == -1) return;
    if (msgs[idx]['sendSlow'] == true) return;
    msgs[idx] = {...msgs[idx], 'sendSlow': true};
    _invalidateMessageCaches(sessionId);
  }

  /// Whether the outbox currently owns a retry for [localId].
  ///
  /// The chat screen's stall watchdog uses this to avoid telling the user
  /// "Retry queued" while the original send is still in flight and no
  /// retry exists.
  bool isOutboxPending(String localId) => messageOutbox.contains(localId);

  /// Re-apply outbox ownership to a session's rows.
  ///
  /// The outbox republishes statuses through `onStatusChanged`, but that
  /// callback drops everything for sessions whose messages are not loaded
  /// yet — which is every session at cold start except the few warmed by
  /// `_restoreRecentCachedMessagesAsync()`. A row restored from MMKV with
  /// its last persisted `'sending'` status would therefore spin forever
  /// and never show the retry affordance (which only renders for
  /// `'failed'`), leaving the preserved dead-letter payload unreachable.
  ///
  /// Call this whenever a session's messages become visible/loaded.
  /// Returns the number of rows whose status changed.
  int reconcileOutboxStatuses(String sessionId) {
    final msgs = _sessionMessages[sessionId];
    if (msgs == null || msgs.isEmpty) return 0;
    var changed = 0;
    void apply(String localId, String status) {
      final idx = msgs.indexWhere((m) => _matchesLocalId(m, localId));
      if (idx == -1) return;
      if (msgs[idx]['sendStatus'] == status) return;
      msgs[idx] = {...msgs[idx], 'sendStatus': status};
      changed++;
    }

    for (final entry in messageOutbox.entries) {
      if (entry.sessionId != sessionId) continue;
      apply(entry.localId, 'pending');
    }
    for (final entry in messageOutbox.deadEntries) {
      if (entry.sessionId != sessionId) continue;
      apply(entry.localId, 'failed');
    }
    if (changed > 0) {
      logger.info(
        '[reconcileOutboxStatuses] restored outbox state for '
        'session=$sessionId rows=$changed',
      );
      _invalidateMessageCaches(sessionId);
      _notifySessionMessagesChanged(sessionId);
    }
    return changed;
  }

  /// Last-resort retry path: rebuild the send from the outbox
  /// dead-letter bucket when the in-memory chat row can no longer
  /// supply the original `raw` record (cold start, evicted cache, or a
  /// row that was never persisted with its payload).
  ///
  /// Returns `true` when a dead-lettered entry was requeued.
  Future<bool> _retryFromDeadLetter(String sessionId, String localId) async {
    if (messageOutbox.deadEntry(localId) == null) return false;
    final revived = await messageOutbox.reviveDead(localId);
    if (!revived) return false;
    _updateMessageSendStatus(sessionId, localId, 'sending');
    logger.info(
      '[retryFailedMessage] requeued from dead-letter bucket: '
      'sessionId=$sessionId localId=$localId',
    );
    _notifySessionMessagesChanged(sessionId);
    return true;
  }

  /// Retry a failed message send.
  ///
  /// Re-queues the message in the outbox with reset retry count.
  /// The message must have a 'raw' field containing the original
  /// unencrypted message record.
  Future<MessageRetryResult> retryFailedMessage(
    String sessionId,
    String localId,
  ) async {
    final msgs = _sessionMessages[sessionId];
    if (msgs == null) {
      if (await _retryFromDeadLetter(sessionId, localId)) {
        return const MessageRetryResult(MessageRetryOutcome.queued);
      }
      logger.warning('[retryFailedMessage] session not found: $sessionId');
      return const MessageRetryResult(MessageRetryOutcome.sessionUnavailable);
    }

    Map<String, dynamic>? failedMessage;
    for (final m in msgs) {
      if (_matchesLocalId(m, localId)) {
        failedMessage = m;
        break;
      }
    }

    if (failedMessage == null) {
      if (await _retryFromDeadLetter(sessionId, localId)) {
        return const MessageRetryResult(MessageRetryOutcome.queued);
      }
      logger.warning(
        '[retryFailedMessage] message not found: '
        'sessionId=$sessionId localId=$localId',
      );
      return const MessageRetryResult(MessageRetryOutcome.messageNotFound);
    }

    final raw = failedMessage['raw'];
    if (raw == null || raw is! Map<String, dynamic>) {
      if (await _retryFromDeadLetter(sessionId, localId)) {
        return const MessageRetryResult(MessageRetryOutcome.queued);
      }
      logger.warning(
        '[retryFailedMessage] message missing raw data: localId=$localId',
      );
      return const MessageRetryResult(MessageRetryOutcome.rawDataUnavailable);
    }

    // A message whose image bytes were stripped by the offline cache
    // cannot be retried — the raw record no longer carries the pixels,
    // and sending a hollow base64 block would deliver a broken image to
    // the agent. Leave the row in 'failed' state; the user must re-attach.
    if (hasStrippedImageBlocks(raw)) {
      logger.warning(
        '[retryFailedMessage] image data stripped by cache, cannot retry: '
        'sessionId=$sessionId localId=$localId',
      );
      return const MessageRetryResult(
        MessageRetryOutcome.attachmentDataUnavailable,
      );
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
      try {
        await fetchSingleSession(sessionId);
      } catch (e, stack) {
        logger.warning(
          '[retryFailedMessage] encryption recovery failed for '
          'session=$sessionId localId=$localId',
          e,
          stack,
        );
        return const MessageRetryResult(
          MessageRetryOutcome.encryptionUnavailable,
        );
      }
      sessionEncryption = encryption.getSessionEncryption(sessionId);
    }
    if (sessionEncryption == null) {
      logger.warning(
        '[retryFailedMessage] cannot get encryption for session=$sessionId',
      );
      return const MessageRetryResult(
        MessageRetryOutcome.encryptionUnavailable,
      );
    }

    late final String encryptedRawRecord;
    try {
      encryptedRawRecord = await sessionEncryption.encryptRawRecord(raw);
    } catch (e, stack) {
      logger.warning(
        '[retryFailedMessage] encryption failed for '
        'session=$sessionId localId=$localId',
        e,
        stack,
      );
      return const MessageRetryResult(MessageRetryOutcome.encryptionFailed);
    }

    _updateMessageSendStatus(sessionId, localId, 'sending');

    await _queueMessageRetry(
      sessionId: sessionId,
      localId: localId,
      text: text,
      encryptedRawRecord: encryptedRawRecord,
      rawRecord: raw,
      retryCount: 0,
    );

    logger.info(
      '[retryFailedMessage] queued for retry: '
      'sessionId=$sessionId localId=$localId',
    );

    _notifySessionMessagesChanged(sessionId);
    return const MessageRetryResult(MessageRetryOutcome.queued);
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
            // Every give-up path below means the agent will not be woken
            // until its next poll cycle. The message is safe (REST already
            // stored it) but the user perceives a stalled agent, so each
            // reason is logged and counted rather than swallowed.
            final reason = !connected
                ? 'socket_never_connected'
                : !isInitialized
                ? 'sync_shutdown'
                : InvalidateSync.isBackgrounded
                ? 'backgrounded'
                : !_isSocketConnected()
                ? 'socket_dropped'
                : null;
            if (reason != null) {
              logger.warning(
                '[sendMessage] daemon notification retry gave up '
                'session=$sessionId localId=$localId reason=$reason — '
                'agent wakes on its next poll',
              );
              PowerDiagnosticsOtelReporter.instance.recordAppError(
                'app.send.daemon_notify_gave_up',
              );
              return;
            }
            logger.info(
              '[sendMessage] retrying daemon notification '
              'session=$sessionId localId=$localId',
            );
            _emitSocketMessage(sessionId, encryptedRawRecord, localId);
          })
          .catchError((Object error, StackTrace stack) {
            // The message is already stored on the server via REST POST,
            // so this is not data loss — but a globally dead socket emit
            // path would otherwise be invisible.
            logger.warning(
              '[sendMessage] daemon notification retry failed '
              'session=$sessionId localId=$localId',
              error,
              stack,
            );
            PowerDiagnosticsOtelReporter.instance.recordAppError(
              'app.send.daemon_notify_failed',
            );
          }),
    );
  }

  void _startPostSendCatchUp(String sessionId, {required int sentUserSeq}) {
    _postSendCatchUpTimers.remove(sessionId)?.cancel();
    final deadline = DateTime.now().add(Sync._postSendCatchUpBudget);
    var probeIndex = 0;

    bool shouldStop(String reason) {
      // Split the old catch-all `timeout_or_inactive`: 34% of polls ended
      // under that label with no way to tell "the agent was still thinking
      // when the budget ran out" from "sync was torn down" or "nobody is
      // watching this session's messages any more".
      final stopReason = !isInitialized
          ? 'sync_inactive'
          : !messagesSync.containsKey(sessionId)
          ? 'session_unwatched'
          : DateTime.now().isAfter(deadline)
          ? 'budget_exhausted'
          : null;
      if (stopReason != null) {
        _postSendCatchUpTimers.remove(sessionId)?.cancel();
        _cancelMessageFetchProbe(sessionId);
        logger.info(
          '[sendMessage] catch-up polling ended '
          'session=$sessionId reason=$stopReason probes=$probeIndex '
          'trigger=$reason',
        );
        return true;
      }

      if (_hasPostSendResponseAfterSeq(sessionId, sentUserSeq)) {
        _postSendCatchUpTimers.remove(sessionId)?.cancel();
        _cancelMessageFetchProbe(sessionId);
        final currentSeq = _sessionLastSeq[sessionId] ?? 0;
        logger.info(
          '[sendMessage] catch-up polling ended '
          'session=$sessionId reason=response_seen probes=$probeIndex '
          'sentSeq=$sentUserSeq current=$currentSeq',
        );
        return true;
      }

      return false;
    }

    bool runProbe() {
      if (shouldStop('probe')) {
        return false;
      }

      // Force a probe instead of trusting session.lastSeq here. The
      // sessions delta feed can lag behind message storage, so
      // currentSeq >= serverLastSeq does NOT prove the agent has not
      // responded yet.
      probeIndex++;
      _requestMessageFetchProbe(sessionId);
      messagesSync[sessionId]?.invalidate();
      return true;
    }

    /// Re-arms one probe at a time so the interval can widen: the first
    /// minute after a send is when an agent reply is most likely, and
    /// keeping a flat 10 s cadence across the longer budget would triple
    /// the fetch load on sessions that are simply slow to answer.
    void scheduleNextProbe() {
      _postSendCatchUpTimers[sessionId] = Timer(
        Sync._postSendCatchUpInterval(probeIndex),
        () {
          if (!runProbe()) return;
          scheduleNextProbe();
        },
      );
    }

    void startPeriodicPolling() => scheduleNextProbe();

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

  static final RegExp _markdownImageRegExp = RegExp(
    r'!\[[^\]]*\]\((.*?)\)',
    dotAll: true,
  );

  /// Builds the wire `content` for a user message.
  ///
  /// Plain text sends keep the legacy single-map shape
  /// (`{'type': 'text', 'text': …}`) — the daemon has special-case
  /// handling for it (slash commands, loop commands). Anything with
  /// images becomes a content-block array, which the daemon forwards
  /// verbatim into Claude's stream-json stdin (base64 image blocks are
  /// accepted there; URL sources are rejected by the API gateway).
  _UserOutboundContent _buildOutboundUserContent(
    String text, {
    List<OutgoingImage>? images,
  }) {
    final matches = _markdownImageRegExp.allMatches(text);
    final hasImages = images != null && images.isNotEmpty;
    if (matches.isEmpty && !hasImages) {
      return <String, dynamic>{'type': 'text', 'text': text};
    }

    final blocks = <Map<String, dynamic>>[];
    if (matches.isEmpty) {
      if (text.trim().isNotEmpty) {
        blocks.add({'type': 'text', 'text': text});
      }
    } else {
      var cursor = 0;
      for (final match in matches) {
        final before = text.substring(cursor, match.start);
        if (before.trim().isNotEmpty) {
          blocks.add({'type': 'text', 'text': before});
        }

        final imageUrl = match.group(1)?.trim() ?? '';
        if (imageUrl.isNotEmpty) {
          blocks.add({
            'type': 'image',
            'source': {'type': 'url', 'url': imageUrl},
          });
        }
        cursor = match.end;
      }

      final after = text.substring(cursor);
      if (after.trim().isNotEmpty) {
        blocks.add({'type': 'text', 'text': after});
      }
    }

    if (hasImages) {
      for (final image in images) {
        blocks.add(image.toContentBlock());
      }
    }

    return blocks;
  }

  String _extractDisplayTextFromUserContent(
    _UserOutboundContent content,
    String fallback,
  ) {
    if (content is Map<String, dynamic>) {
      final text = content['text'];
      if (text is String) return text;
    }

    if (content is List) {
      final blocks = content.whereType<Map<String, dynamic>>().toList();
      final text = _extractTextFromContentBlocks(blocks);
      if (text != null && text.isNotEmpty) return text;

      final hasImage = blocks.any((block) => block['type'] == 'image');
      if (hasImage) return '[image]';
    }

    return fallback;
  }

  String? _extractTextFromContentBlocks(List<Map<String, dynamic>> blocks) {
    final buffer = StringBuffer();
    for (final block in blocks) {
      if (block['type'] == 'text') {
        final text = block['text'];
        if (text is String && text.isNotEmpty) {
          if (buffer.isNotEmpty) buffer.write('\n');
          buffer.write(text);
        }
      }
    }
    return buffer.isEmpty ? null : buffer.toString();
  }
}
