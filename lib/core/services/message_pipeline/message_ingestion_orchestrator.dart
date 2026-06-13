part of '../sync_service.dart';

extension SyncMessagePipeline on Sync {
  String _newTraceId(String sessionId, String suffix) {
    final randomSuffix =
        Random().nextInt(1 << 16).toRadixString(16).padLeft(4, '0');
    return '$sessionId-$suffix-$randomSuffix-${DateTime.now().millisecondsSinceEpoch}';
  }

  String _sourceName(MessagePipelineSource source) =>
      source == MessagePipelineSource.socket ? 'socket' : 'http';

  void _logPipelineStage(
    String traceId,
    String sessionId,
    MessagePipelineStage stage,
    String outcome,
    Map<String, dynamic> data,
  ) {
    logger.debug(
      '[pipeline] $traceId session=$sessionId stage=${stage.name} '
      'outcome=$outcome payload=$data',
    );
  }

  void _releaseInlineDedupKey(String sessionId, String? dedupKey) {
    if (dedupKey == null || dedupKey.isEmpty) return;
    _pendingInlineMessageKeys.remove(dedupKey);
    _recentInlineMessageKeys.add(dedupKey);
    _recentInlineMessageKeyOrder.addLast(dedupKey);
    while (_recentInlineMessageKeyOrder.length > Sync._maxRecentInlineKeys) {
      _recentInlineMessageKeys.remove(_recentInlineMessageKeyOrder.removeFirst());
    }
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

    final messages = <Map<String, dynamic>>[
      if (embedded.isNotEmpty) embedded,
    ];

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

    final messages = batch.rawMessages
        .where((m) => m is Map<String, dynamic>)
        .toList(growable: false);

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
    await _processMessageBatch(
      normalized: normalized,
      notifySessionsDomain: event.notifySessionsDomain,
      emitSessionNotification: true,
      applyMutations: true,
    );
    _logPipelineStage(
      normalized.traceId,
      normalized.sessionId,
      MessagePipelineStage.notified,
      'ok',
      <String, dynamic>{'source': 'socket'},
    );
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
        _logPipelineStage(
          traceId,
          sessionId,
          MessagePipelineStage.normalized,
          'no-encryption',
          const <String, dynamic>{},
        );
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
          errorMessage: 'encryptionMissing',
        );
      }

      final processed = await sessionEncryption.decryptAndProcessMessages(
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
          <String, dynamic>{
            'mutate': false,
            'maxSeq': processed.maxSeq,
          },
        );
        return ProcessedMessageBundle(
          messages: processed.messages,
          toolResults: processed.toolResults,
          usageUpdates: processed.usageUpdates,
          maxSeq: processed.maxSeq,
          droppedReasons: processed.droppedReasons,
          hasSidechain: processed.messages.any(
            (message) =>
                message['isSidechain'] == true ||
                message['kind'] == 'sidechain-root',
          ),
          source: normalized.source,
          traceId: traceId,
        );
      }

      bool shouldNotify = false;
      if (processed.messages.isNotEmpty) {
        _upsertSessionMessages(sessionId, processed.messages);
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

      final hasSidechain = processed.messages.any(
        (message) =>
            message['isSidechain'] == true ||
            message['kind'] == 'sidechain-root',
      );
      if (hasSidechain && _visibleSessionId == sessionId) {
        _groupSidechainMessages(sessionId);
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
        _releaseInlineDedupKey(sessionId, dedupKey);
        if (emitSessionNotification) {
          _notifySessionMessagesChanged(sessionId);
          if (notifySessionsDomain) {
            _notifyDataChanged({SyncDomain.messages, SyncDomain.sessions});
          }
        }
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
