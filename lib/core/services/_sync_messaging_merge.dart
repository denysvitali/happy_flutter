part of 'sync_service.dart';

extension SyncMessagingMerge on Sync {
  String? _messageContentSignature(Map<String, dynamic> message) {
    final content = message['content'];
    if (content is Map) {
      return content['c'] as String?;
    }
    if (content is String) {
      return _stableContentSignature(content);
    }
    return 'raw:${content?.hashCode ?? 0}';
  }

  String _stableContentSignature(String content) {
    final length = content.length;
    if (length <= 64) {
      return '$length:$content';
    }
    return '$length:${content.substring(0, 32)}:'
        '${content.substring(length - 32)}';
  }

  void _rebuildSessionContentSignatures(String sessionId) {
    final messages = _sessionMessages[sessionId];
    if (messages == null || messages.isEmpty) {
      _sessionContentSignatures.remove(sessionId);
      return;
    }

    final signatures = <String, String?>{};
    for (final message in messages) {
      final id = message['id'] as String?;
      if (id == null || id.isEmpty) continue;
      signatures[id] = _messageContentSignature(message);

      // Also store base wire ID for output messages (see
      // _updateSessionContentSignatures for rationale).
      final baseId = _stripOutputSuffix(id);
      if (baseId != null && baseId != id) {
        signatures[baseId] = _messageContentSignature(message);
      }
    }
    _sessionContentSignatures[sessionId] = signatures;
  }

  void _updateSessionContentSignatures(
    String sessionId,
    List<Map<String, dynamic>> messages,
  ) {
    if (messages.isEmpty) return;
    final signatures = _sessionContentSignatures.putIfAbsent(
      sessionId,
      () => <String, String?>{},
    );
    for (final message in messages) {
      final id = message['id'] as String?;
      if (id == null || id.isEmpty) continue;
      signatures[id] = _messageContentSignature(message);

      // Output content blocks get synthetic IDs (e.g. abc123_t0, abc123_k1).
      // When the same message is re-fetched from the server, it arrives with
      // the original wire ID (abc123) — not the synthetic one.  Without the
      // wire ID in signatures, the pre-filter can never match and every
      // re-fetch re-decrypts all output content blocks unnecessarily.
      // Store the base (wire) ID alongside the synthetic one so lookups
      // succeed on re-fetch.  Only strip known suffixes to avoid false
      // positives on wire IDs that legitimately end with _t0 etc.
      final baseId = _stripOutputSuffix(id);
      if (baseId != null && baseId != id) {
        signatures[baseId] = _messageContentSignature(message);
      }
    }
  }

  /// Strips known output content block suffixes from [id] and returns the
  /// base wire ID, or `null` if [id] doesn't match any known suffix pattern.
  ///
  /// Known suffixes: _t{n}, _k{n}, _u{n}, _sc, _bridge (n = decimal digits)
  String? _stripOutputSuffix(String id) {
    // _t0, _t1, ... _t99 etc. — match _<digits> at end
    if (id.length > 3 && _outputDigitsRegex.hasMatch(id)) {
      final base = id.substring(0, id.lastIndexOf('_'));
      if (base.isNotEmpty) return base;
    }
    if (id.endsWith('_sc') || id.endsWith('_bridge')) {
      return id.substring(0, id.lastIndexOf('_'));
    }
    return null;
  }

  // Pre-compiled regex for _<digits> suffix (used by _stripOutputSuffix)
  static final _outputDigitsRegex = RegExp(r'_\d+$');

  /// Default throttle between consecutive orphan-recovery
  /// fetchOlderMessages attempts. Prevents tight retry loops when
  /// pagination alone is paginating in circles (e.g. parent Task
  /// lives outside the loaded window).
  static const int _orphanFetchOlderDefaultThrottleMs = 60000;

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

  (List<Map<String, dynamic>>, List<Map<String, dynamic>>)
  _processSessionContent(
    DecryptedMessage message,
    dynamic nestedContent,
    int createdAt,
    Map<String, dynamic> outerContent,
  ) {
    Map<String, dynamic>? envelope;
    final nestedMap = WireParsers.asMap(nestedContent);
    if (nestedMap != null) {
      final nestedData = WireParsers.asMap(nestedMap['data']);
      if (nestedMap['type'] == 'session' && nestedData != null) {
        envelope = nestedData;
      } else {
        envelope = nestedMap;
      }
    }
    if (envelope == null) return ([], []);

    final event = envelope['ev'] ?? envelope['event'];
    final eventMap = WireParsers.asMap(event);
    if (eventMap == null) return ([], []);

    final eventType = (eventMap['t'] ?? eventMap['type']) as String?;
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
            'content':
                (eventMap['text'] ?? eventMap['message'])?.toString() ?? '',
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
      final text = (eventMap['text'] ?? eventMap['message'])?.toString() ?? '';
      if (eventRole == MessageRole.agent) {
        final thinking = eventMap['thinking'] == true;
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
      final args = eventMap['args'] ?? eventMap['input'];
      final input = WireParsers.asMap(args) ?? <String, dynamic>{};
      final callId =
          (eventMap['call'] ?? eventMap['callId'] ?? eventMap['toolUseId'])
              as String?;
      return (
        [
          {
            'id': envelopeId,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': eventCreatedAt,
            'role': 'agent',
            'kind': 'tool-call',
            'name':
                (eventMap['name'] ?? eventMap['tool'])?.toString() ?? 'unknown',
            'input': input,
            'toolUseId': callId ?? envelopeId,
            'state': 'running',
            'content': eventMap,
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
          (eventMap['call'] ?? eventMap['callId'] ?? eventMap['toolUseId'])
              as String?;
      if (callId == null || callId.isEmpty) return ([], []);
      return (
        [],
        [
          {
            'toolUseId': callId,
            'result':
                eventMap['result'] ?? eventMap['output'] ?? eventMap['content'],
            'isError':
                eventMap['isError'] == true || eventMap['is_error'] == true,
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
      final image = WireParsers.asMap(eventMap['image']);
      final imageMeta = image != null
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
              'ref': eventMap['ref'],
              'name': eventMap['name'],
              'size': eventMap['size'],
              'image': ?imageMeta,
            },
            'toolUseId': envelopeId,
            'state': 'completed',
            'content': eventMap,
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

  /// Called from message-processing hot paths whenever a message
  /// belonging to a session arrives.  Resets the consecutive-sweep
  /// failure counter so we don't absorb orphans while the server may
  /// still be delivering the parent Task message.
  void _resetSidechainRegroupSweepCount(String sessionId) {
    _sidechainRegroupSweepCount.remove(sessionId);
  }

  void _runDeferredRegroupSweep(String sessionId) {
    final messages = _sessionMessages[sessionId];
    if (messages == null || messages.isEmpty) return;

    // Only run if there are still ungrouped sidechain messages
    // sitting in the main list (a normal message list has no
    // isSidechain entries after successful grouping).
    final beforeOrphans = messages
        .where(isVisibleSidechainOrphan)
        .map((m) => m['id'] as String?)
        .whereType<String>()
        .toSet();

    if (beforeOrphans.isEmpty) {
      // No orphans left — clear any leftover counter state.
      _sidechainRegroupSweepCount.remove(sessionId);
      return;
    }

    logger.debug(
      '[sidechain] running deferred re-group sweep '
      'for session=$sessionId',
    );

    // Capture reference before _groupSidechainMessages may replace it.
    final beforeMessages = messages;
    _groupSidechainMessages(sessionId);

    final after = _sessionMessages[sessionId];
    final afterOrphans =
        after
            ?.where(isVisibleSidechainOrphan)
            .map((m) => m['id'] as String?)
            .whereType<String>()
            .toSet() ??
        const <String>{};

    // Progress was made — orphans were attached to real Tasks.
    // Reset counter and let normal flow continue.
    if (afterOrphans.isEmpty || afterOrphans.length < beforeOrphans.length) {
      _sidechainRegroupSweepCount.remove(sessionId);
      final messagesUpdated = !identical(beforeMessages, after);
      if (messagesUpdated) {
        _notifySessionMessagesChanged(sessionId);
        _notifyDataChanged({SyncDomain.messages});
      }
      return;
    }

    // Orphans still present after grouping. We do NOT absorb them
    // into synthetic Tasks anymore — that hid real subagent output
    // behind a "Subagent output (recovered)" tile the user couldn't
    // open. Instead: try to page older history to find the real
    // parent, and otherwise let the sidechain messages render in
    // place at the top level of the chat list.
    //
    // For sessions with many Agent spawns deep in history (worst-case
    // 15 Agents at seqs 13..494 inside a 1000+ message session,
    // cache=200, page=100), the user needs ~8 fetchOlder pages to walk
    // back to the first Agent. Aggressive cadence fires when every
    // orphan carries parent_tool_use_id (Claude's strong wire
    // promise that a real parent exists upstream).
    final messagesNow =
        _sessionMessages[sessionId] ?? const <Map<String, dynamic>>[];
    final visibleOrphanMessages = messagesNow
        .where(isVisibleSidechainOrphan)
        .toList(growable: false);
    final everyOrphanHasParentToolUseId =
        visibleOrphanMessages.isNotEmpty &&
        visibleOrphanMessages.every((m) {
          final ptu = m['parentToolUseId'];
          return ptu is String && ptu.isNotEmpty;
        });

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastFetchAttempt = _orphanFetchOlderAttemptedMs[sessionId] ?? 0;

    final hasMoreOlder = hasOlderMessages(sessionId);
    final useAggressiveThrottle =
        everyOrphanHasParentToolUseId && hasMoreOlder;
    final canRetryFetch =
        useAggressiveThrottle ||
        nowMs - lastFetchAttempt > _orphanFetchOlderDefaultThrottleMs;

    if (canRetryFetch && hasMoreOlder && !isLoadingOlderMessages(sessionId)) {
      _orphanFetchOlderAttemptedMs[sessionId] = nowMs;
      logger.info(
        '[sidechain] orphans persist for session=$sessionId — '
        'attempting fetchOlderMessages to locate parent Task '
        '(aggressive=$useAggressiveThrottle, '
        'orphanCount=${beforeOrphans.length})',
      );
      unawaited(
        fetchOlderMessages(sessionId)
            .then((_) {
              // The fetch path upserts and notifies; the next grouper
              // pass will rerun automatically. Reset the no-progress
              // counter so we get a fresh shot at convergence.
              _sidechainRegroupSweepCount.remove(sessionId);
              _scheduleSidechainRegroup(sessionId);
            })
            .catchError((Object error, StackTrace stack) {
              logger.warning(
                '[sidechain] fetchOlderMessages failed for session=$sessionId '
                'during orphan recovery',
                error,
                stack,
              );
            }),
      );
      return;
    }

    // No more history to walk, or the throttle is in effect. Surface
    // the orphans as-is — the chat list will render them inline (see
    // _chat_screen_builders). A debug breadcrumb lets us confirm the
    // orphan count without spamming Sentry; this path is the expected
    // end-state for sessions whose parent Task is outside the loaded
    // window or never arrives.
    if (hasMoreOlder) {
      // Throttled: re-schedule so we eventually retry.
      _scheduleSidechainRegroup(sessionId);
    } else {
      // History exhausted: keep the orphans visible in the chat, no
      // further work needed. Clear the sweep counter so we stop
      // running the grouper on every refresh for these sessions.
      _sidechainRegroupSweepCount.remove(sessionId);
      logger.info(
        '[sidechain] ${beforeOrphans.length} orphan(s) persist for '
        'session=$sessionId — history exhausted, rendering inline',
      );
    }
  }

  /// Delegates to [SidechainGrouper] and updates session message
  /// state when grouping modifies the list.
  void _groupSidechainMessages(String sessionId, {Set<String>? changedIds}) {
    final messages = _sessionMessages[sessionId];
    if (messages == null || messages.isEmpty) return;

    final result = _sidechainGrouper.groupMessages(
      _sessionMessages[sessionId] ?? messages,
      changedIds: changedIds,
    );

    if (result == null) return;

    if (result.hasOrphans) {
      _scheduleSidechainRegroup(sessionId);
    }

    // Always update _sessionMessages when the grouper ran and returned a
    // result, even if the list reference is the same (hasOrphans case).
    // Without this, _sessionMessages is never updated for the hasOrphans &&
    // identical(result.messages, messages) path, causing orphans to remain
    // and trigger the warning again on every subsequent deferred regroup
    // sweep call — creating an infinite warning loop.
    _sessionMessages[sessionId] = result.messages;
    // Always invalidate cache after assigning — the list reference may be
    // identical even when the list contents changed (hasOrphans path).
    _sessionMessagesCache = null;
    _sessionMessagesViewCache.remove(sessionId);
  }

  /// Apply tool results to existing tool-call messages in a session.
  /// Returns the set of toolUseIds that were matched, so callers can
  /// drain only those from the pending queue.
  Set<String> _applyToolResults(
    String sessionId,
    List<Map<String, dynamic>> toolResults,
  ) {
    if (toolResults.isEmpty) return const {};

    final existing = _sessionMessages[sessionId] ?? <Map<String, dynamic>>[];
    if (existing.isEmpty) {
      // Queue tool results that arrived before their tool-call message.
      // They will be applied when the tool-call message arrives.
      final pending = _pendingToolResults.putIfAbsent(sessionId, () => []);
      if (!identical(pending, toolResults)) {
        pending.addAll(toolResults);
      }
      return const {};
    }

    final result = _toolResultProcessor.applyToolResults(existing, toolResults);

    if (result.changed) {
      _sessionMessages[sessionId] = result.messages;
      _sessionMessagesCache = null;
      _sessionMessagesViewCache.remove(sessionId);
    }

    return result.matchedIds;
  }

  /// Enrich tool-call messages with permission data from
  /// [AgentState]. Delegates to [ToolResultProcessor].
  bool _applyPermissionRequests(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return false;

    final agentState = session.agentState;
    if (agentState == null) return false;

    final existing = _sessionMessages[sessionId];
    if (existing == null || existing.isEmpty) return false;

    final result = _toolResultProcessor.applyPermissionRequests(
      existing,
      agentState,
      _notifiedPermissionIds,
    );

    // Cancel notifications for resolved permissions.
    for (final permId in result.resolvedPermIds) {
      _notifiedPermissionIds.remove(permId);
      unawaited(
        NotificationService.instance.cancelPermissionNotification(permId),
      );
    }

    if (result.changed) {
      _sessionMessages[sessionId] = result.messages;
      _sessionMessagesCache = null;
      _sessionMessagesViewCache.remove(sessionId);
    }
    return result.changed;
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
    final tailStart = existing.length > 20 ? existing.length - 20 : 0;
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
    final maxMessages = sessionId == _visibleSessionId
        ? Sync._maxVisibleSessionMessages
        : Sync._maxBackgroundSessionMessages;

    if (_canAppendMessagesFastPath(existing, messages)) {
      final appended = <Map<String, dynamic>>[...existing, ...messages];
      final trimmed = appended.length > maxMessages
          ? appended.sublist(appended.length - maxMessages)
          : appended;
      _sessionMessages[sessionId] = trimmed;
      if (sessionId == _visibleSessionId && logger.shouldLog(LogLevel.debug)) {
        final afterCount = _sessionMessages[sessionId]?.length ?? 0;
        logger.debug(
          '[messages] upsert session=$sessionId '
          'incoming=${messages.length} '
          'before=${existing.length} '
          'after=$afterCount '
          'mode=append',
        );
      }
      _sessionMessagesCache = null;
      _sessionMessagesViewCache.remove(sessionId);
      if (trimmed.length == appended.length) {
        _updateSessionContentSignatures(sessionId, messages);
      } else {
        _rebuildSessionContentSignatures(sessionId);
      }
      _ensureFirstLoadedSeq(sessionId);
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
          message['isSidechain'] == true || message['kind'] == 'sidechain-root';
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
        final existingChildren = existing['children'] as List<dynamic>?;
        if (existingChildren != null &&
            existingChildren.isNotEmpty &&
            message['children'] == null) {
          message['children'] = existingChildren;
        }
        final existingRoots = existing['_sidechainRootUuids'] as List<dynamic>?;
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
    _rebuildSessionContentSignatures(sessionId);
    if (sessionId == _visibleSessionId &&
        messages.isNotEmpty &&
        logger.shouldLog(LogLevel.debug)) {
      final afterCount = _sessionMessages[sessionId]?.length ?? 0;
      logger.debug(
        '[messages] upsert session=$sessionId '
        'incoming=${messages.length} '
        'before=${existing.length} '
        'after=$afterCount '
        'mode=merge',
      );
    }
    _sessionMessagesCache = null;
    _sessionMessagesViewCache.remove(sessionId);
    _ensureFirstLoadedSeq(sessionId);
  }
}
