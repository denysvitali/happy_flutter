part of '../sync_service.dart';

/// `ProcessedMessageBundle.errorMessage` marker for "this session had no
/// encryption context yet". Recoverable and self-healing, so it is reported
/// as a skip rather than a pipeline error — see [SyncMessagePipeline
/// .ingestFromSocket].
const String _encryptionMissingReason = 'encryptionMissing';

extension SyncMessagePipeline on Sync {
  String _newTraceId(String sessionId, String suffix) {
    final randomSuffix = Random()
        .nextInt(1 << 16)
        .toRadixString(16)
        .padLeft(4, '0');
    return '$sessionId-$suffix-$randomSuffix-${DateTime.now().millisecondsSinceEpoch}';
  }

  String _sourceName(MessagePipelineSource source) =>
      source == MessagePipelineSource.socket ? 'socket' : 'http';

  void _logPipelineStage(
    String traceId,
    String sessionId,
    MessagePipelineStage stage,
    String outcome,
    Map<String, dynamic> data, {
    LogLevel level = LogLevel.debug,
  }) {
    // Streaming messages cross several successful pipeline stages. Keeping
    // every intermediate debug log turns a single token update into five or
    // more OTel log records, which is expensive on mobile. Preserve terminal
    // success and all non-success diagnostics; Jaeger spans retain timing for
    // the omitted intermediate stages.
    final isSuccessfulIntermediate =
        outcome == 'ok' ||
        (stage == MessagePipelineStage.raw && outcome == 'accepted');
    if (level == LogLevel.debug &&
        isSuccessfulIntermediate &&
        stage != MessagePipelineStage.notified) {
      return;
    }
    // The terminal `notified ok` line survived that filter and therefore fired
    // once per socket payload — ~9k records per device per day, the single
    // largest DEBUG contributor in Loki. Keep one fully detailed line per
    // window as a trace anchor and fold the rest into a counted summary.
    if (level == LogLevel.debug &&
        stage == MessagePipelineStage.notified &&
        outcome == 'ok' &&
        _summarizeNotified(sessionId)) {
      return;
    }
    final message =
        '[pipeline] $traceId session=$sessionId '
        'stage=${stage.name} outcome=$outcome payload=$data';
    switch (level) {
      case LogLevel.info:
        logger.info(message);
      case LogLevel.warning:
        logger.warning(message);
      case LogLevel.error:
        logger.error(message);
      case LogLevel.debug:
        logger.debug(message);
    }
  }

  /// One detailed `notified ok` line per [_notifiedSummaryWindowMs]; the rest
  /// are counted and reported as a single summary line when the window rolls.
  ///
  /// Returns `true` when the caller should suppress its own log line.
  bool _summarizeNotified(String sessionId) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsed = nowMs - _notifiedWindowStartedAtMs;
    // A backwards wall-clock jump (NTP correction) would otherwise wedge the
    // window shut; treat it as "start a new window".
    if (_notifiedWindowStartedAtMs == 0 ||
        elapsed < 0 ||
        elapsed >= _notifiedSummaryWindowMs) {
      _flushNotifiedSummary(elapsed);
      _notifiedWindowStartedAtMs = nowMs;
      return false;
    }
    _notifiedSuppressed++;
    _notifiedSessions.add(sessionId);
    return true;
  }

  void _flushNotifiedSummary(int elapsedMs) {
    if (_notifiedSuppressed == 0) return;
    // Summary is INFO so the DEBUG export sampler cannot discard the count
    // after doing the useful work of folding thousands of terminal records.
    logger.info(
      '[pipeline] stage=notified outcome=summary '
      'suppressed=$_notifiedSuppressed sessions=${_notifiedSessions.length} '
      'windowMs=$elapsedMs',
    );
    _notifiedSuppressed = 0;
    _notifiedSessions.clear();
  }

  /// Window state for [_summarizeNotified]. Static because `Sync` is a
  /// singleton and this is process-wide log-volume policy, not session state.
  // Five minutes bounds routine terminal pipeline export to at most two
  // records per window (one trace anchor plus one counted summary). Every
  // non-ok outcome bypasses this policy and is still logged immediately.
  static const int _notifiedSummaryWindowMs = 5 * 60 * 1000;
  static int _notifiedWindowStartedAtMs = 0;
  static int _notifiedSuppressed = 0;
  static final Set<String> _notifiedSessions = <String>{};

  /// Records folded into the current summary window — tests only.
  @visibleForTesting
  static int get debugNotifiedSuppressed => _notifiedSuppressed;

  /// Reset the `notified` summary window — tests only.
  @visibleForTesting
  static void debugResetNotifiedSummary() {
    _notifiedWindowStartedAtMs = 0;
    _notifiedSuppressed = 0;
    _notifiedSessions.clear();
  }

  void _releaseInlineDedupKey(String sessionId, String? dedupKey) {
    if (dedupKey == null || dedupKey.isEmpty) return;
    _pendingInlineMessageKeys.remove(dedupKey);
    _recentInlineMessageKeys.add(dedupKey);
    _recentInlineMessageKeyOrder.addLast(dedupKey);
    while (_recentInlineMessageKeyOrder.length > Sync._maxRecentInlineKeys) {
      _recentInlineMessageKeys.remove(
        _recentInlineMessageKeyOrder.removeFirst(),
      );
    }
  }

  /// Collects the `id` of every just-appended message so the sidechain
  /// grouper's `changedIds` fast-path can skip a full re-walk when the
  /// batch carries nothing sidechain-relevant. Returns an empty set when
  /// the batch has no messages with a string `id` (the grouper treats an
  /// empty set as "no changed ids known, do a full pass" — fine because
  /// a zero-message batch already short-circuits earlier).
  Set<String> _collectJustAppendedIds(List<Map<String, dynamic>> batch) {
    final ids = <String>{};
    for (final m in batch) {
      final id = m['id'];
      if (id is String && id.isNotEmpty) ids.add(id);
    }
    return ids;
  }

  /// Returns true when [messages] contains any groupable sidechain content.
  ///
  /// Keep this in sync with [SidechainGrouper]'s eligibility conditions so
  /// every path that can carry sidechain children (socket, HTTP fetch,
  /// mutation preview) triggers grouping and avoids double-rendering an
  /// already-grouped child that arrives in an overlapping fetch.
  ///
  /// `parentToolUseId` is intentionally checked with an `is String` guard
  /// (instead of `as String?`) so a wrong runtime type — e.g. an `int` —
  /// is treated as "no anchor" rather than crashing the whole batch. A
  /// malformed wire shape must never blackhole sidechain grouping.
  ///
  /// This is the canonical source of truth: `_sync_messaging.dart`'s
  /// `pageHasSidechain` must call this rather than re-inlining the
  /// predicate, otherwise the two gates can drift and an overlapping
  /// fetch can land back in the flat list.
  bool hasSidechainMessage(List<Map<String, dynamic>> messages) =>
      messages.any(_hasSidechainSignal);

  /// Single-message predicate backing [hasSidechainMessage] and shared with
  /// the HTTP fetch mirror in `_sync_messaging.dart` (`pageHasSidechain`).
  /// Centralised so both call sites agree on the trigger set — including
  /// the defensive `is String` coercion for `parentToolUseId` — and a
  /// future narrowing only has to land in one place.
  bool _hasSidechainSignal(Map<String, dynamic> message) {
    if (message['isSidechain'] == true) return true;
    final kind = message['kind'];
    if (kind == 'sidechain-root' || kind == 'sidechain-link') return true;
    if (message['taskEvent'] == true) return true;
    final parentToolUseId = message['parentToolUseId'];
    return parentToolUseId is String && parentToolUseId.isNotEmpty;
  }

  NormalizedMessageBatch normalizeSocketIngress(MessageIngressEvent event) {
    final traceId = event.traceId ?? _newTraceId(event.sessionId, 's');
    _logPipelineStage(
      traceId,
      event.sessionId,
      MessagePipelineStage.raw,
      'accepted',
      <String, dynamic>{
        'source': _sourceName(event.source),
        'payloadType': event.rawPayload.runtimeType.toString(),
      },
    );

    final rawPayloadMap = WireParsers.asMap(event.rawPayload);
    final embedded = rawPayloadMap == null
        ? const <String, dynamic>{}
        : WireParsers.asMap(rawPayloadMap['message']) ?? rawPayloadMap;

    final messages = <Map<String, dynamic>>[if (embedded.isNotEmpty) embedded];

    _logPipelineStage(
      traceId,
      event.sessionId,
      MessagePipelineStage.normalized,
      messages.isEmpty ? 'empty' : 'ok',
      <String, dynamic>{
        'count': messages.length,
        'isVisibleSession': event.isVisibleSession,
      },
    );

    return NormalizedMessageBatch(
      source: MessagePipelineSource.socket,
      sessionId: event.sessionId,
      messages: messages,
      traceId: traceId,
      metadata: <String, dynamic>{
        ...event.metadata,
        'isVisibleSession': event.isVisibleSession,
      },
    );
  }

  NormalizedMessageBatch normalizeHttpBatch(FetchResponseBatch batch) {
    _logPipelineStage(
      batch.traceId,
      batch.sessionId,
      MessagePipelineStage.raw,
      'accepted',
      <String, dynamic>{
        'source': 'http',
        'rawMessages': batch.rawMessages.length,
        'page': batch.page,
      },
    );

    final messages = batch.rawMessages.whereType<Map<String, dynamic>>().toList(
      growable: false,
    );

    _logPipelineStage(
      batch.traceId,
      batch.sessionId,
      MessagePipelineStage.normalized,
      'ok',
      <String, dynamic>{
        'count': messages.length,
        'isVisibleSession': batch.isVisibleSession,
      },
    );

    return NormalizedMessageBatch(
      source: MessagePipelineSource.http,
      sessionId: batch.sessionId,
      messages: messages,
      traceId: batch.traceId,
      metadata: <String, dynamic>{
        'isVisibleSession': batch.isVisibleSession,
        'page': batch.page,
        'afterSeq': batch.afterSeq,
        'notifyVisibleOnly': batch.notifyVisibleOnly,
      },
      afterSeq: batch.afterSeq,
    );
  }

  Future<void> ingestFromSocket(MessageIngressEvent event) async {
    final normalized = normalizeSocketIngress(event);
    final processed = await _processMessageBatch(
      normalized: normalized,
      notifySessionsDomain: event.notifySessionsDomain,
      emitSessionNotification: true,
      applyMutations: true,
    );
    // Surface inner-pipeline failures as `notified=error` so Loki never
    // reports a successful notification when `errorMessage` is set.
    // Without this, `outcome=(error|dropped)` greps miss every failure
    // that the inner work captured (e.g. encryptionMissing, decrypt
    // exceptions propagated up via `errorMessage`).
    final errorMessage = processed.errorMessage;
    if (errorMessage != null) {
      // A socket payload for a session whose encryption context has not been
      // resolved yet is not a failure: `_processMessageBatch` has already
      // kicked off catalogue recovery and invalidated the per-session
      // message sync, so the message lands on the next fetch. Reporting it
      // as `outcome=error` made five benign races per 48h look like data
      // loss. Report it as a skip and count it instead; genuinely unknown
      // failures keep the error outcome the `outcome=(error|dropped)` Loki
      // grep depends on.
      final skipped = errorMessage == _encryptionMissingReason;
      _logPipelineStage(
        normalized.traceId,
        normalized.sessionId,
        MessagePipelineStage.notified,
        skipped ? 'skipped' : 'error',
        <String, dynamic>{
          'source': 'socket',
          if (skipped) 'reason': errorMessage else 'errorMessage': errorMessage,
        },
        level: skipped ? LogLevel.info : LogLevel.debug,
      );
    } else {
      _logPipelineStage(
        normalized.traceId,
        normalized.sessionId,
        MessagePipelineStage.notified,
        'ok',
        <String, dynamic>{'source': 'socket'},
      );
    }
  }

  Future<ProcessedMessageBundle> ingestFromHttp(
    FetchResponseBatch batch, {
    bool applyMutations = false,
    bool emitSessionNotification = false,
  }) async {
    final normalized = normalizeHttpBatch(batch);
    return _processMessageBatch(
      normalized: normalized,
      notifySessionsDomain: batch.notifyVisibleOnly ? false : true,
      emitSessionNotification: emitSessionNotification,
      applyMutations: applyMutations,
    );
  }

  Future<ProcessedMessageBundle> _processMessageBatch({
    required NormalizedMessageBatch normalized,
    required bool notifySessionsDomain,
    required bool emitSessionNotification,
    required bool applyMutations,
  }) async {
    final sessionId = normalized.sessionId;
    final traceId = normalized.traceId;
    final dedupKey = normalized.metadata['dedupKey'] as String?;

    try {
      if (normalized.messages.isEmpty) {
        _releaseInlineDedupKey(sessionId, dedupKey);
        _logPipelineStage(
          traceId,
          sessionId,
          MessagePipelineStage.normalized,
          'empty',
          const <String, dynamic>{'messages': 0},
        );
        return ProcessedMessageBundle(
          messages: const [],
          toolResults: const [],
          usageUpdates: const [],
          maxSeq: 0,
          droppedReasons: const [],
          hasSidechain: false,
          traceId: traceId,
        );
      }

      final sessionEncryption = encryption.getSessionEncryption(sessionId);
      if (sessionEncryption == null) {
        _releaseInlineDedupKey(sessionId, dedupKey);
        // A session this client has never fetched legitimately has no
        // encryption context yet — the socket simply beat the catalogue
        // fetch that carries the DEK. Recovery below pulls it and the
        // message arrives on the next fetch, so that case is an info-level
        // skip. A session we *do* know about but cannot decrypt for is a
        // real key-material problem and stays at warning, where production
        // Loki forwards it (debug logs are not forwarded outside dev mode).
        final sessionKnown = _sessions.containsKey(sessionId);
        _logPipelineStage(
          traceId,
          sessionId,
          MessagePipelineStage.normalized,
          'no-encryption',
          <String, dynamic>{'sessionKnown': sessionKnown},
          level: sessionKnown ? LogLevel.warning : LogLevel.info,
        );
        OpenTelemetryService().recordCount(
          'app.messages.encryption_missing',
          attributes: <String, Object?>{
            'source': _sourceName(normalized.source),
            'session_known': sessionKnown ? 'true' : 'false',
          },
          description:
              'Message batches skipped because the session had no '
              'encryption context yet',
        );
        // Refresh the session catalogue as well as messages. The catalogue
        // response carries the encrypted DEK, so retrying only messages can
        // loop forever with the same missing decryptor. Recovery is
        // rate-limited per session to avoid hammering the server when key
        // material is permanently unavailable.
        await _recoverSessionEncryption(sessionId);
        sessionsSync.invalidate();
        messagesSync[sessionId]?.invalidate();
        if (emitSessionNotification) {
          _notifySessionMessagesChanged(sessionId);
        }
        return ProcessedMessageBundle(
          messages: const [],
          toolResults: const [],
          usageUpdates: const [],
          maxSeq: 0,
          droppedReasons: const [],
          hasSidechain: false,
          traceId: traceId,
          source: normalized.source,
          errorMessage: _encryptionMissingReason,
        );
      }

      // If the session fell back to legacy NaCl but the server still
      // advertises an encrypted data key, try to refresh the DEK before
      // decrypting. This recovers from server-side DEK rotation that
      // happened while the client held a stale/failed plaintext key.
      if (!sessionEncryption.canDecryptAes &&
          _sessionEncryptedDataKeys.containsKey(sessionId)) {
        await _recoverSessionEncryption(sessionId);
      }

      final sessionEncryptionToUse =
          encryption.getSessionEncryption(sessionId) ?? sessionEncryption;

      final processed = await sessionEncryptionToUse.decryptAndProcessMessages(
        normalized.messages,
        sessionId,
      );

      _logPipelineStage(
        traceId,
        sessionId,
        MessagePipelineStage.processed,
        'ok',
        <String, dynamic>{
          'messages': processed.messages.length,
          'toolResults': processed.toolResults.length,
          'usageUpdates': processed.usageUpdates.length,
        },
      );

      if (!applyMutations) {
        _logPipelineStage(
          traceId,
          sessionId,
          MessagePipelineStage.merged,
          'skipped-mutation',
          <String, dynamic>{'mutate': false, 'maxSeq': processed.maxSeq},
        );
        return ProcessedMessageBundle(
          messages: processed.messages,
          toolResults: processed.toolResults,
          usageUpdates: processed.usageUpdates,
          maxSeq: processed.maxSeq,
          droppedReasons: processed.droppedReasons,
          hasSidechain: hasSidechainMessage(processed.messages),
          source: normalized.source,
          traceId: traceId,
        );
      }

      var shouldNotify = false;
      // Loop control events (loops-updated / loop-fired / loop-expired) ride
      // the session message stream as agent-events; route them into loop
      // state and strip them so they never render as chat rows.
      final renderableMessages = consumeLoopControlMessages(
        sessionId,
        processed.messages,
      );
      if (renderableMessages.isNotEmpty) {
        _upsertSessionMessages(sessionId, renderableMessages);
        shouldNotify = true;
      }
      if (processed.toolResults.isNotEmpty) {
        _applyToolResults(sessionId, processed.toolResults);
        shouldNotify = true;
      }
      if (processed.usageUpdates.isNotEmpty) {
        for (final u in processed.usageUpdates) {
          final usageMap = WireParsers.asMap(u['usage']);
          if (usageMap != null) {
            _updateSessionUsage(
              u['sessionId'] as String,
              usageMap,
              u['timestamp'] as int,
            );
            shouldNotify = true;
          }
        }
      }
      if (_applyPermissionRequests(sessionId)) {
        shouldNotify = true;
      }

      final pending = _pendingToolResults[sessionId];
      if (pending != null && pending.isNotEmpty) {
        final matched = _applyToolResults(sessionId, pending);
        if (matched.isNotEmpty) {
          pending.removeWhere((r) => matched.contains(r['toolUseId']));
          if (pending.isEmpty) {
            _pendingToolResults.remove(sessionId);
          }
          shouldNotify = true;
        }
      }

      // Group sidechain children under their parent Task/Agent/Workflow
      // tool-call messages on EVERY append that carries sidechain content,
      // not only when the user is currently viewing this session. The
      // grouper is idempotent and a no-op when no relevant ids are
      // present, so running it off-screen has no UI cost — but skipping
      // it used to strand sub-agent children as orphans when the user
      // navigated away mid-burst, so they never collapsed back into
      // their parent Task tile on return. Pass the just-appended ids as
      // `changedIds` so the grouper's fast-path can skip a full re-walk
      // when nothing sidechain-relevant arrived in this batch.
      // Match the grouper's own eligibility conditions (sidechain flag,
      // bridge kinds, task events, parentToolUseId) so a batch that carries
      // groupable content without isSidechain=true still triggers grouping —
      // otherwise an overlapping fetch copy of an already-grouped child can
      // land back in the flat list and render twice.
      final hasSidechain = hasSidechainMessage(processed.messages);
      if (hasSidechain) {
        _groupSidechainMessages(
          sessionId,
          changedIds: _collectJustAppendedIds(renderableMessages),
        );
        _logPipelineStage(
          traceId,
          sessionId,
          MessagePipelineStage.grouped,
          'ok',
          const <String, dynamic>{},
        );
      }

      if (shouldNotify || processed.messages.isNotEmpty) {
        _releaseInlineDedupKey(sessionId, dedupKey);
        _advanceSeqCursor(sessionId, processed.maxSeq);
        if (emitSessionNotification) {
          _notifySessionMessagesChanged(sessionId);
          _notifyDataChanged(
            notifySessionsDomain
                ? const {SyncDomain.messages, SyncDomain.sessions}
                : const {SyncDomain.messages},
          );
        }
      } else {
        // No visible state changed (empty acks, meta messages, control
        // events). Still advance the cursor so gap detection stays correct,
        // but skip the UI notification to avoid rebuild churn during
        // high-frequency streaming.
        _releaseInlineDedupKey(sessionId, dedupKey);
        _advanceSeqCursor(sessionId, processed.maxSeq);
      }

      _logPipelineStage(
        traceId,
        sessionId,
        MessagePipelineStage.merged,
        'ok',
        <String, dynamic>{
          'mutate': shouldNotify,
          'sidechain': hasSidechain,
          'maxSeq': processed.maxSeq,
        },
      );

      return ProcessedMessageBundle(
        messages: processed.messages,
        toolResults: processed.toolResults,
        usageUpdates: processed.usageUpdates,
        maxSeq: processed.maxSeq,
        droppedReasons: processed.droppedReasons,
        hasSidechain: hasSidechain,
        source: normalized.source,
        traceId: traceId,
      );
    } catch (error, stack) {
      _releaseInlineDedupKey(sessionId, dedupKey);
      messagesSync[sessionId]?.invalidate();
      // Emit the structured `[pipeline]` breadcrumb first so Loki greps
      // for `outcome=(error|dropped)` capture the failure under the
      // pipeline namespace. The plain `logger.warning` below keeps the
      // full error + stack trace for Sentry but is not greppable by the
      // pipeline outcome query.
      _logPipelineStage(
        traceId,
        sessionId,
        MessagePipelineStage.processed,
        'error',
        <String, dynamic>{'errorMessage': error.toString()},
      );
      logger.warning(
        'Message pipeline failed for session=$sessionId',
        error,
        stack,
      );
      if (emitSessionNotification) {
        _notifySessionMessagesChanged(sessionId);
      }
      return ProcessedMessageBundle(
        messages: const [],
        toolResults: const [],
        usageUpdates: const [],
        maxSeq: 0,
        droppedReasons: const [],
        hasSidechain: false,
        source: normalized.source,
        traceId: traceId,
        errorMessage: error.toString(),
      );
    }
  }
}
