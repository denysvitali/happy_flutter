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

  /// Finds an optimistic user row whose server echo omitted `localId`.
  ///
  /// `localId` is the authoritative identity.  This fallback is only for
  /// legacy/history records that lose it in transit, and is deliberately
  /// constrained to a pending user row with the same content and a nearby
  /// timestamp.  Matching by text alone would collapse repeated sends such
  /// as two consecutive `continue` messages.
  String? _findUnidentifiedOptimisticUser(
    Iterable<Map<String, dynamic>> existing,
    Map<String, dynamic> incoming,
  ) {
    if (incoming['role'] != 'user') return null;
    if (incoming['localId'] is String &&
        (incoming['localId'] as String).isNotEmpty) {
      return null;
    }

    final incomingSignature = _messageContentSignature(incoming);
    if (incomingSignature == null) return null;
    final incomingCreatedAt = _asInt(incoming['createdAt']);
    if (incomingCreatedAt == null) return null;

    String? bestId;
    var bestDistance = 5 * 60 * 1000 + 1;
    for (final candidate in existing) {
      if (candidate['role'] != 'user' ||
          candidate['id'] != candidate['localId']) {
        continue;
      }
      final status = candidate['sendStatus'];
      if (status != 'sending' && status != 'failed') continue;
      if (_messageContentSignature(candidate) != incomingSignature) {
        continue;
      }
      final candidateCreatedAt = _asInt(candidate['createdAt']);
      if (candidateCreatedAt == null) continue;
      final distance = (candidateCreatedAt - incomingCreatedAt).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestId = candidate['localId'] as String?;
      }
    }
    return bestId;
  }

  /// Detects the agent-side prompt echo emitted by some CLI output streams.
  ///
  /// These records are distinct from the user's persisted message: their
  /// outer role is `agent`, but their generic output payload repeats the
  /// prompt word-for-word immediately before the actual response.  They must
  /// not create a second visible chat bubble.  The processor marks only that
  /// generic output shape as a candidate; matching additionally requires a
  /// preceding user row with identical content, a nearby timestamp, and an
  /// adjacent server sequence when both sequences are available.
  bool _isPromptEcho(
    Iterable<Map<String, dynamic>> existing,
    Map<String, dynamic> incoming,
  ) {
    if (incoming['isPromptEchoCandidate'] != true ||
        incoming['role'] != 'agent') {
      return false;
    }
    final incomingSignature = _messageContentSignature(incoming);
    final incomingCreatedAt = _asInt(incoming['createdAt']);
    if (incomingSignature == null || incomingCreatedAt == null) return false;
    final incomingSeq = _asInt(incoming['seq']);

    for (final candidate in existing) {
      if (candidate['role'] != 'user' ||
          _messageContentSignature(candidate) != incomingSignature) {
        continue;
      }
      final candidateCreatedAt = _asInt(candidate['createdAt']);
      if (candidateCreatedAt == null ||
          incomingCreatedAt < candidateCreatedAt ||
          incomingCreatedAt - candidateCreatedAt > 2 * 60 * 1000) {
        continue;
      }
      final candidateSeq = _asInt(candidate['seq']);
      if (candidateSeq != null &&
          candidateSeq > 0 &&
          incomingSeq != null &&
          incomingSeq > candidateSeq + 2) {
        continue;
      }
      return true;
    }
    return false;
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

  /// Incremental replacement for [_rebuildSessionContentSignatures] on the
  /// upsert path.
  ///
  /// The full rebuild recomputes a fingerprint for every one of up to 1000
  /// rows on the main isolate, once per fetched page, even though a page only
  /// ever changes the rows it carries. This instead drops entries for rows
  /// that left the window (trim, optimistic-placeholder eviction,
  /// prompt-echo skip) with a pure map/set walk, then refreshes only the
  /// [incoming] rows that actually survived the merge.
  ///
  /// Refreshing only surviving rows matters: a row dropped by
  /// `_isPromptEcho` must not leave a signature behind, or the fetch
  /// pre-filter would treat it as already-present and never merge it.
  void _applySessionContentSignatureDelta(
    String sessionId,
    List<Map<String, dynamic>> incoming,
  ) {
    final messages = _sessionMessages[sessionId];
    if (messages == null || messages.isEmpty) {
      _sessionContentSignatures.remove(sessionId);
      return;
    }
    final signatures = _sessionContentSignatures[sessionId];
    if (signatures == null) {
      _rebuildSessionContentSignatures(sessionId);
      return;
    }

    final liveKeys = <String>{};
    for (final message in messages) {
      final id = message['id'] as String?;
      if (id == null || id.isEmpty) continue;
      liveKeys.add(id);
      // Output content blocks also register their base wire ID — keep both
      // alive so a re-fetch still matches (see
      // [_updateSessionContentSignatures]).
      final baseId = _stripOutputSuffix(id);
      if (baseId != null && baseId != id) {
        liveKeys.add(baseId);
      }
    }
    signatures.removeWhere((key, _) => !liveKeys.contains(key));

    for (final message in incoming) {
      final id = message['id'] as String?;
      if (id == null || id.isEmpty || !liveKeys.contains(id)) continue;
      final signature = _messageContentSignature(message);
      signatures[id] = signature;
      final baseId = _stripOutputSuffix(id);
      if (baseId != null && baseId != id) {
        signatures[baseId] = signature;
      }
    }
  }

  /// Prunes signature entries for exactly [dropped] rows that fell off
  /// the window head during a pure-append trim.
  ///
  /// Same prune step [_applySessionContentSignatureDelta] performs, minus
  /// the O(window) live-key walk: the append fast path has no eviction
  /// sites of its own, so the caller can name the removed rows exactly.
  /// Removing a base wire ID still aliased by a surviving row is safe —
  /// a missing signature only costs one redundant re-decrypt at the next
  /// fetch, while a stale signature would wrongly skip the merge.
  void _pruneSessionContentSignaturePrefix(
    String sessionId,
    List<Map<String, dynamic>> dropped,
  ) {
    final signatures = _sessionContentSignatures[sessionId];
    if (signatures == null || signatures.isEmpty || dropped.isEmpty) {
      return;
    }
    for (final message in dropped) {
      final id = message['id'] as String?;
      if (id == null || id.isEmpty) continue;
      signatures.remove(id);
      final baseId = _stripOutputSuffix(id);
      if (baseId != null && baseId != id) {
        signatures.remove(baseId);
      }
    }
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
  /// lives outside the loaded window). See [Sync._orphanSuppressionWindowMs].
  static const int _orphanFetchOlderDefaultThrottleMs =
      Sync._orphanSuppressionWindowMs;

  /// Extended throttle applied once history is genuinely exhausted (no
  /// older messages left to page through). See
  /// [Sync._orphanSuppressionExtendedWindowMs].
  static const int _orphanFetchOlderExhaustedThrottleMs =
      Sync._orphanSuppressionExtendedWindowMs;

  /// Number of consecutive no-progress fetchOlder attempts allowed in
  /// aggressive mode. While a parent Task likely exists just below the
  /// loaded window, we want to paginate quickly; after this many futile
  /// pages we fall back to the default throttle to avoid hammering the
  /// server when the parent is genuinely missing. Derived from the
  /// seq-based budget so the aggressive phase reaches the same distance
  /// regardless of [Sync._orphanFetchOlderPageSize]. See
  /// [Sync._orphanAggressiveWalkbackSequences].
  static const int _orphanFetchOlderAggressiveAttempts =
      Sync._orphanAggressiveWalkbackSequences ~/ Sync._orphanFetchOlderPageSize;

  /// Hard cap on total no-progress fetchOlder attempts. Once reached,
  /// orphan recovery gives up and the sidechain messages render inline
  /// until new activity (new messages arriving) resets the counter.
  /// Page-counted (not a flat attempt count) so deeply nested sub-agent
  /// trees get enough budget to recover. See
  /// [Sync._orphanFetchOlderMaxPageSequences].
  static const int _orphanFetchOlderMaxAttempts =
      Sync._orphanFetchOlderMaxPageSequences ~/ Sync._orphanFetchOlderPageSize;

  static const String _orphanWalkbackGiveUpStorageKey =
      'orphan-walkback-give-up-signatures';
  void _loadOrphanWalkbackGiveUpSignatures() {
    if (_orphanWalkbackGiveUpSignaturesLoaded) return;
    _orphanWalkbackGiveUpSignaturesLoaded = true;
    final encoded = MMKVStorage().getString(_orphanWalkbackGiveUpStorageKey);
    if (encoded == null || encoded.isEmpty) return;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return;
      _orphanWalkbackGiveUpSignatures
        ..clear()
        ..addAll(
          decoded.map<String, String>((key, value) {
            return MapEntry(key.toString(), value as String);
          }),
        );
    } catch (error, stack) {
      logger.warning(
        '[sidechain] failed to load persisted orphan give-up state',
        error,
        stack,
      );
    }
  }

  void _persistOrphanWalkbackGiveUpSignatures() {
    MMKVStorage().setString(
      _orphanWalkbackGiveUpStorageKey,
      jsonEncode(_orphanWalkbackGiveUpSignatures),
    );
  }

  String? _orphanParentGroupSignature(Set<String> parentKeys) {
    if (parentKeys.isEmpty) return null;
    final sortedKeys = parentKeys.toList()..sort();
    // JSON preserves the sorted string boundaries exactly, avoiding a hash
    // collision that could suppress a genuinely new parent group.
    return jsonEncode(sortedKeys);
  }

  Set<String> _orphanParentKeys(Iterable<Map<String, dynamic>> messages) =>
      messages
          .where(isVisibleSidechainOrphan)
          .map(WireParsers.sidechainParentToolUseId)
          .whereType<String>()
          .toSet();

  void _clearOrphanWalkbackGiveUp(String sessionId) {
    _loadOrphanWalkbackGiveUpSignatures();
    if (_orphanWalkbackGiveUpSignatures.remove(sessionId) != null) {
      _persistOrphanWalkbackGiveUpSignatures();
    }
  }

  void _markOrphanWalkbackGiveUp(String sessionId, String? signature) {
    if (signature == null) return;
    _loadOrphanWalkbackGiveUpSignatures();
    if (_orphanWalkbackGiveUpSignatures[sessionId] == signature) return;
    _orphanWalkbackGiveUpSignatures[sessionId] = signature;
    _persistOrphanWalkbackGiveUpSignatures();
  }

  bool _hasPersistedOrphanGiveUp(
    String sessionId,
    List<Map<String, dynamic>> messages,
  ) {
    _loadOrphanWalkbackGiveUpSignatures();
    final persisted = _orphanWalkbackGiveUpSignatures[sessionId];
    if (persisted == null) return false;
    final parentKeys = _orphanParentKeys(messages);

    // The normal socket/fetch path clears this marker in
    // [_upsertSessionMessages], but tests and cache-restore paths can hand
    // the grouper a complete window directly. A real parent in that window
    // must always win over a stale persisted give-up marker.
    final parentArrived = messages.any(
      (message) =>
          _isAgentContainerTool(message) &&
          _messageIdentityKeys(message).any(parentKeys.contains),
    );
    if (parentArrived) {
      _clearOrphanWalkbackGiveUp(sessionId);
      _orphanWalkbackParentKeys[sessionId] = parentKeys;
      return false;
    }

    _orphanWalkbackParentKeys[sessionId] = parentKeys;
    return _orphanParentGroupSignature(parentKeys) == persisted;
  }

  bool _isAgentContainerTool(Map<String, dynamic> message) {
    final name = message['name'];
    return message['kind'] == 'tool-call' &&
        (name == 'Task' || name == 'Agent' || name == 'Workflow');
  }

  Set<String> _messageIdentityKeys(Map<String, dynamic> message) => {
    for (final value in [message['id'], message['uuid'], message['toolUseId']])
      if (value is String && value.isNotEmpty) value,
  };

  void _liftOrphanGiveUpIfNewParentArrived(
    String sessionId,
    List<Map<String, dynamic>> existing,
    List<Map<String, dynamic>> incoming,
  ) {
    _loadOrphanWalkbackGiveUpSignatures();
    if (!_orphanWalkbackGiveUpSignatures.containsKey(sessionId)) return;

    final trackedParents = _orphanWalkbackParentKeys[sessionId] ??=
        _orphanParentKeys(existing);
    final parentArrived = incoming.any(
      (message) =>
          _isAgentContainerTool(message) &&
          _messageIdentityKeys(message).any(trackedParents.contains),
    );
    final newParentGroupArrived = incoming
        .where(isVisibleSidechainOrphan)
        .map(WireParsers.sidechainParentToolUseId)
        .whereType<String>()
        .any((parentKey) => !trackedParents.contains(parentKey));
    if (parentArrived || newParentGroupArrived) {
      _clearOrphanWalkbackGiveUp(sessionId);
    }
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
    final beforeOrphanMessages = messages
        .where(isVisibleSidechainOrphan)
        .toList(growable: false);
    final beforeOrphans = beforeOrphanMessages
        .map((m) => m['id'] as String?)
        .whereType<String>()
        .toSet();

    if (beforeOrphans.isEmpty) {
      // No orphans left — clear any leftover counter state.
      _sidechainRegroupSweepCount.remove(sessionId);
      _orphanFetchOlderNoProgressCount.remove(sessionId);
      _orphanWalkbackOrphanIds.remove(sessionId);
      _orphanWalkbackParentKeys.remove(sessionId);
      _clearOrphanWalkbackGiveUp(sessionId);
      return;
    }

    // Walk-back only helps the visible session: background sessions are
    // trimmed to the newest _maxBackgroundSessionMessages (200) on every
    // upsert, so a fetched older page — and any parent Task it contains —
    // is discarded before the grouper can see it. Don't burn network and
    // decrypt work on a chat the user isn't looking at; flag it so
    // onSessionVisible regroups and re-arms the walk-back budget instead.
    if (sessionId != _visibleSessionId) {
      _sessionsNeedingVisibleRegroup.add(sessionId);
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // A genuinely new orphan situation opens a fresh walk-back budget and
    // lifts any suppression: either some previously-unresolved id
    // disappeared (real progress), or a newly-arrived orphan belongs to a
    // parent Task group we haven't already been walking back for (a
    // disjoint new burst deserves its own look even while an older,
    // stuck burst is still pending). Pure growth of an ALREADY-TRACKED
    // parent group — more children of the same un-found Task arriving,
    // every previously-seen id still present — must NOT reset the
    // budget: that was a real production bug. A single stuck subagent
    // kept emitting child sidechain messages sharing one parentToolUseId
    // whose own parent Task never arrived; because the orphan *id* set
    // changed on every sweep (new child ids), the old hash-based check
    // reset noProgressCount to 0 every time, so the hard cap below was
    // never reached and the walk-back hammered fetchOlderMessages
    // indefinitely. Message upserts must not reset the counter either —
    // the walk-back's own fetchOlderMessages upserts every page it
    // fetches, and a blanket reset pinned the counter below both caps,
    // looping a 100-message fetch+decrypt every ~450ms indefinitely.
    final previousOrphanIds = _orphanWalkbackOrphanIds[sessionId];
    final previousParentKeys = _orphanWalkbackParentKeys[sessionId];
    final newlyArrivedMessages = previousOrphanIds == null
        ? beforeOrphanMessages
        : beforeOrphanMessages
              .where((m) => !previousOrphanIds.contains(m['id']))
              .toList(growable: false);
    final hasNewParentGroup =
        previousParentKeys == null ||
        newlyArrivedMessages.any((m) {
          final parentKey = WireParsers.sidechainParentToolUseId(m);
          return parentKey == null || !previousParentKeys.contains(parentKey);
        });
    final resolvedSome =
        previousOrphanIds != null &&
        !beforeOrphans.containsAll(previousOrphanIds);
    final isPureGrowth =
        previousOrphanIds != null && !resolvedSome && !hasNewParentGroup;
    if (!isPureGrowth) {
      _orphanFetchOlderNoProgressCount.remove(sessionId);
      _orphanSuppressedUntilMs.remove(sessionId);
    }
    _orphanWalkbackOrphanIds[sessionId] = beforeOrphans;
    _orphanWalkbackParentKeys[sessionId] = beforeOrphanMessages
        .map(WireParsers.sidechainParentToolUseId)
        .whereType<String>()
        .toSet();

    final orphanParentSignature = _orphanParentGroupSignature(
      _orphanWalkbackParentKeys[sessionId]!,
    );
    _loadOrphanWalkbackGiveUpSignatures();
    if (orphanParentSignature != null &&
        _orphanWalkbackGiveUpSignatures[sessionId] == orphanParentSignature) {
      // This parent group already exhausted both pagination and the
      // resident-window recovery path, possibly in a previous process.
      // Keep rendering the children inline without another O(n) grouping
      // pass. A real parent Task or a disjoint parent group clears this
      // signature in [_upsertSessionMessages].
      _sidechainRegroupSweepCount.remove(sessionId);
      return;
    }

    // If we've already given up on exactly this orphan set (throttled,
    // hard cap reached, or history exhausted), don't keep running the
    // O(n) grouper on every scheduled sweep. A changed orphan set lifts
    // the suppression above.
    final suppressedUntil = _orphanSuppressedUntilMs[sessionId];
    if (suppressedUntil != null && nowMs < suppressedUntil) {
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
      _orphanFetchOlderNoProgressCount.remove(sessionId);
      _orphanWalkbackOrphanIds.remove(sessionId);
      _orphanWalkbackParentKeys.remove(sessionId);
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
    // For sessions with many Agent spawns deep in history, the parent
    // Task can sit thousands of seqs behind the newest completion events.
    // Use the server-supported large page only for this automatic visible
    // recovery path; normal user scroll pagination stays small.
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

    final lastFetchAttempt = _orphanFetchOlderAttemptedMs[sessionId] ?? 0;
    final noProgressCount = _orphanFetchOlderNoProgressCount[sessionId] ?? 0;

    final hasMoreOlder = hasOlderMessages(sessionId);
    final useAggressiveThrottle =
        everyOrphanHasParentToolUseId &&
        hasMoreOlder &&
        noProgressCount < _orphanFetchOlderAggressiveAttempts;

    // Hard cap: if we've walked back many pages without attaching a single
    // orphan, the parent Task is probably outside the available history or
    // the wire data is inconsistent. Stop trying and render inline. The
    // counter intentionally stays at the cap — only a changed orphan set
    // (signature reset above) or an onSessionVisible re-arm grants a new
    // budget, so the give-up can't silently undo itself when the
    // suppression window lapses.
    if (noProgressCount >= _orphanFetchOlderMaxAttempts) {
      _sidechainRegroupSweepCount.remove(sessionId);
      _orphanFetchOlderAttemptedMs.remove(sessionId);
      _orphanSuppressedUntilMs[sessionId] =
          nowMs + _orphanFetchOlderDefaultThrottleMs;
      _markOrphanWalkbackGiveUp(sessionId, orphanParentSignature);
      logger.info(
        '[sidechain] ${beforeOrphans.length} orphan(s) persist for '
        'session=$sessionId — gave up after '
        '$_orphanFetchOlderMaxAttempts fetchOlder attempts, rendering inline',
      );
      return;
    }

    // Aggressive mode is deliberately unthrottled. A cold start whose cache
    // window is all sidechain orphans has to page back fast enough to surface
    // the early Agents, which is why the cadence is a pinned contract (see
    // test/integration/orphan_cold_start_15_agents_e2e_test.dart). The cost
    // that originally motivated a floor here came from 500-row ~1.5 MB pages
    // that were then discarded: the page is still 500 rows, but that cost is
    // now absorbed by the 30 s receive timeout plus the InvalidateSync retry,
    // and the at-visible-cap case below returns before fetching at all, so the
    // remaining aggressive pages are the productive ones.
    final canRetryFetch =
        useAggressiveThrottle ||
        nowMs - lastFetchAttempt > _orphanFetchOlderDefaultThrottleMs;

    // The walk-back exists to pull a parent Task into the loaded window. When
    // the session is already at its message cap, `_upsertSessionMessages`
    // trims back to the newest N on every upsert and throws the entire fetched
    // page away — including the parent we went looking for. Every page is then
    // guaranteed to make zero progress, and the no-progress counter simply
    // climbs to the hard cap while burning bandwidth and decrypt time.
    // The cap is per-session: background sessions trim to
    // [Sync._maxBackgroundSessionMessages], so comparing against the visible
    // constant left this skip dead for every non-visible session.
    final loadedCount = messagesNow.length;
    final trimCap = _sessionTrimCap(sessionId);
    if (loadedCount >= trimCap) {
      _sidechainRegroupSweepCount.remove(sessionId);
      _orphanSuppressedUntilMs[sessionId] =
          nowMs + _orphanFetchOlderExhaustedThrottleMs;
      _markOrphanWalkbackGiveUp(sessionId, orphanParentSignature);
      logger.info(
        '[sidechain] ${beforeOrphans.length} orphan(s) persist for '
        'session=$sessionId — session is at its message cap '
        '($loadedCount/$trimCap messages), so any fetched older page would be '
        'trimmed away; rendering inline',
      );
      return;
    }

    if (canRetryFetch && hasMoreOlder && !isLoadingOlderMessages(sessionId)) {
      _orphanFetchOlderAttemptedMs[sessionId] = nowMs;
      logger.info(
        '[sidechain] orphans persist for session=$sessionId — '
        'attempting fetchOlderMessages to locate parent Task '
        '(aggressive=$useAggressiveThrottle, '
        'orphanCount=${beforeOrphans.length}, '
        'noProgressCount=$noProgressCount)',
      );
      unawaited(
        fetchOlderMessages(sessionId, pageSize: Sync._orphanFetchOlderPageSize)
            .then((_) {
              // The fetch path upserts and notifies; the next grouper
              // pass will rerun automatically. Reset the no-progress
              // counter if we actually made progress, otherwise bump it.
              // Reaching the end of history also counts as a resolved
              // outcome for this counter's purposes — the synchronous
              // hasMoreOlder check on the next sweep already routes to
              // the "history exhausted" give-up path below, so crediting
              // it here avoids an extra spurious no-progress increment
              // right at the boundary where pagination legitimately ran
              // out rather than the walk-back simply failing to find a
              // parent.
              final afterSweep = _sessionMessages[sessionId];
              final afterSweepOrphans =
                  afterSweep
                      ?.where(isVisibleSidechainOrphan)
                      .map((m) => m['id'] as String?)
                      .whereType<String>()
                      .toSet() ??
                  const <String>{};
              if (afterSweepOrphans.isEmpty ||
                  afterSweepOrphans.length < beforeOrphans.length ||
                  !hasOlderMessages(sessionId)) {
                _orphanFetchOlderNoProgressCount.remove(sessionId);
              } else {
                final currentNoProgress =
                    _orphanFetchOlderNoProgressCount[sessionId] ?? 0;
                final nextNoProgress = currentNoProgress + 1;
                _orphanFetchOlderNoProgressCount[sessionId] = nextNoProgress;

                // The callback schedules the next deferred sweep. Persist
                // the cap before that sweep runs so it skips the full
                // grouper instead of performing one final O(n) pass merely
                // to discover that the walk-back has already given up.
                final currentParentSignature = _orphanParentGroupSignature(
                  _orphanParentKeys(
                    afterSweep ?? const <Map<String, dynamic>>[],
                  ),
                );
                if (nextNoProgress >= _orphanFetchOlderMaxAttempts &&
                    currentParentSignature == orphanParentSignature) {
                  _markOrphanWalkbackGiveUp(sessionId, currentParentSignature);
                }
              }
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
      // Throttled because of no progress. Suppress further sweeps for the
      // default throttle window instead of rescheduling every 300 ms.
      // New messages arriving for this session reset the no-progress counter
      // and allow another attempt; otherwise the next fetchMessages catch-up
      // path will retry once the suppression window expires.
      _orphanSuppressedUntilMs[sessionId] =
          nowMs + _orphanFetchOlderDefaultThrottleMs;
      logger.info(
        '[sidechain] ${beforeOrphans.length} orphan(s) persist for '
        'session=$sessionId — throttled after $noProgressCount '
        'no-progress attempt(s), retry in '
        '${_orphanFetchOlderDefaultThrottleMs}ms',
      );
    } else {
      // History exhausted: keep the orphans visible in the chat, no
      // further work needed. Clear the sweep counter so we stop
      // running the grouper on every refresh for these sessions.
      _sidechainRegroupSweepCount.remove(sessionId);
      _orphanFetchOlderNoProgressCount.remove(sessionId);
      _orphanFetchOlderAttemptedMs.remove(sessionId);
      _orphanSuppressedUntilMs[sessionId] =
          nowMs + _orphanFetchOlderExhaustedThrottleMs;
      _markOrphanWalkbackGiveUp(sessionId, orphanParentSignature);
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

    if (_hasPersistedOrphanGiveUp(sessionId, messages)) {
      _sidechainGrouperSkips++;
      return;
    }

    // Revision memo. A full pass over an unchanged window would re-walk
    // every resident row (up to 1000, five passes) to reach the exact same
    // answer as last time. The generation counter is bumped by every
    // message-window mutation path, so "same generation" means "no row was
    // added, replaced, removed or mutated in place since the last clean
    // pass" — including the streaming in-place update, which reuses the
    // list reference (so reference identity alone would be unsound).
    // Only clean outcomes are memoized: an orphan result must keep
    // scheduling the deferred sweep and re-running when it fires.
    final gen = _sessionMessagesMutationGen[sessionId] ?? 0;
    if (changedIds == null && _sidechainCleanAtGen[sessionId] == gen) {
      _sidechainGrouperSkips++;
      return;
    }
    _sidechainGrouperRuns++;

    final result = _sidechainGrouper.groupMessages(
      _sessionMessages[sessionId] ?? messages,
      changedIds: changedIds,
    );

    if (result == null) {
      if (changedIds == null) _sidechainCleanAtGen[sessionId] = gen;
      return;
    }

    if (result.hasOrphans) {
      _sidechainCleanAtGen.remove(sessionId);
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
    _invalidateMessageCaches(sessionId);
    if (!result.hasOrphans && changedIds == null) {
      // Record the generation *after* our own invalidation bump so the
      // next full pass over this exact window is skipped.
      _sidechainCleanAtGen[sessionId] = _sessionMessagesMutationGen[sessionId]!;
    }
  }

  /// Apply tool results to existing tool-call messages in a session.
  ///
  /// Results whose tool-call has not yet arrived are queued into
  /// `_pendingToolResults` so a later batch can match them — this
  /// covers both the empty-session case and the realistic case where
  /// the session already has prior messages but the matching
  /// tool-call is still in flight (a wire ordering seen from
  /// same-millisecond Codex events).
  ///
  /// Returns the set of toolUseIds that were matched, so callers can
  /// drain only those from the pending queue.
  Set<String> _applyToolResults(
    String sessionId,
    List<Map<String, dynamic>> toolResults,
  ) {
    if (toolResults.isEmpty) return const {};

    // The retry path in the orchestrator / legacy messaging code passes
    // `_pendingToolResults[sessionId]` itself as `toolResults`; that replay
    // must not self-append, and it is the touch point where expired
    // entries are pruned.
    final isPendingReplay = identical(
      _pendingToolResults[sessionId],
      toolResults,
    );
    if (isPendingReplay) {
      _prunePendingToolResults(sessionId);
      if (toolResults.isEmpty) return const {};
    }

    final existing = _sessionMessages[sessionId] ?? <Map<String, dynamic>>[];
    if (existing.isEmpty) {
      // Queue tool results that arrived before their tool-call message.
      // They will be applied when the tool-call message arrives.
      if (!isPendingReplay) {
        _queuePendingToolResults(sessionId, toolResults);
      }
      return const {};
    }

    final result = _toolResultProcessor.applyToolResults(existing, toolResults);

    if (result.changed) {
      _sessionMessages[sessionId] = result.messages;
      _invalidateMessageCaches(sessionId);
    }

    // Queue any results whose tool-call has not arrived yet so they
    // can be matched on a later batch. Without this, a tool-result
    // that lands one seq before its tool-call (a real wire ordering
    // seen from same-millisecond Codex events) is silently dropped
    // once the session already has prior messages, leaving the
    // tool-call stuck in `running` state forever.
    if (!isPendingReplay) {
      final unmatched = toolResults
          .where((r) => !result.matchedIds.contains(r['toolUseId']))
          .toList();
      if (unmatched.isNotEmpty) {
        _queuePendingToolResults(sessionId, unmatched);
      }
    }

    return result.matchedIds;
  }

  /// Append tool results to the session's pending queue with a local-clock
  /// stamp, enforcing the TTL and the per-session FIFO cap.
  void _queuePendingToolResults(
    String sessionId,
    List<Map<String, dynamic>> results,
  ) {
    final queue = _pendingToolResults.putIfAbsent(sessionId, () => []);
    final nowMs =
        testPendingToolResultNowMsOverride ??
        DateTime.now().millisecondsSinceEpoch;
    for (final r in results) {
      queue.add({...r, Sync.pendingToolResultQueuedAtKey: nowMs});
    }
    if (queue.length > Sync.maxPendingToolResultsPerSession) {
      final dropped = queue.length - Sync.maxPendingToolResultsPerSession;
      queue.removeRange(0, dropped);
      logger.info(
        '[toolResults] pending queue for $sessionId over cap — '
        'dropped $dropped oldest unmatched result(s)',
      );
    }
  }

  /// Drop pending tool results older than [Sync.pendingToolResultTtlMs].
  /// Their tool-call was trimmed out of the resident window (or never
  /// existed) — they can never match and only add rescan cost.
  void _prunePendingToolResults(String sessionId) {
    final queue = _pendingToolResults[sessionId];
    if (queue == null || queue.isEmpty) return;
    final nowMs =
        testPendingToolResultNowMsOverride ??
        DateTime.now().millisecondsSinceEpoch;
    final before = queue.length;
    queue.removeWhere((r) {
      final queuedAt = r[Sync.pendingToolResultQueuedAtKey];
      // Entries queued by builds without the stamp expire immediately —
      // they are at least one upgrade old.
      if (queuedAt is! int) return true;
      return nowMs - queuedAt > Sync.pendingToolResultTtlMs;
    });
    if (queue.isEmpty) {
      _pendingToolResults.remove(sessionId);
    }
    final dropped = before - queue.length;
    if (dropped > 0) {
      logger.info(
        '[toolResults] expired $dropped pending result(s) for $sessionId',
      );
    }
  }

  /// Shrink resident message windows of idle background sessions.
  ///
  /// See the field docs on [Sync.idleSessionShrinkKeepRows]. Skips the
  /// visible session, recently-touched sessions, and sessions with an
  /// unsettled send (a `sending`/`pending`/`failed` row must stay resident
  /// for retry identity and optimistic replacement). Shrinking records the
  /// history-trim ledger and re-arms the scroll-back boundary to the oldest
  /// retained seq, mirroring what the newest-N trim in
  /// [_upsertSessionMessages] does — reopening the session pages history
  /// back in instead of showing a false "beginning of conversation".
  void _maybeShrinkIdleSessionWindows({bool force = false}) {
    final nowMs =
        testIdleShrinkNowMsOverride ?? DateTime.now().millisecondsSinceEpoch;
    if (!force &&
        nowMs - _lastIdleShrinkSweepMs <
            Sync.idleSessionShrinkSweepIntervalMs) {
      return;
    }
    _lastIdleShrinkSweepMs = nowMs;

    var shrunkSessions = 0;
    var releasedRows = 0;

    // Pass 1 — time-based: sessions untouched beyond the idle grace window.
    for (final sessionId in _sessionMessages.keys.toList(growable: false)) {
      if (sessionId == _visibleSessionId) continue;
      final rows = _sessionMessages[sessionId];
      if (rows == null || rows.length <= Sync.idleSessionShrinkKeepRows) {
        continue;
      }
      final touchedAt = _sessionMessagesTouchedAtMs[sessionId];
      if (touchedAt == null) {
        // No touch record (predates tracking) — start the idle clock now.
        _sessionMessagesTouchedAtMs[sessionId] = nowMs;
        continue;
      }
      if (nowMs - touchedAt < Sync.idleSessionShrinkAfterMs) continue;
      final released = _shrinkSessionWindow(sessionId);
      if (released > 0) {
        shrunkSessions++;
        releasedRows += released;
      }
    }

    // Pass 2 — residency budget: even before the idle grace elapses, only the
    // [Sync.maxFullResidentSessions] most-recently-touched non-visible
    // sessions keep their full transcript. Every full session older than that
    // is shrunk to the preview window now. Without this cap, fanning across a
    // large catalog retains one full ~200-row decrypted transcript per session
    // for the whole grace window — the heap growth that scaled RSS with
    // session count (progressive-lag audit 2026-08-24, fifth pass).
    final budgetResult = _enforceResidentSessionBudget();
    shrunkSessions += budgetResult.$1;
    releasedRows += budgetResult.$2;

    if (shrunkSessions > 0) {
      logger.info(
        '[messages] idle-window shrink: $shrunkSessions session(s), '
        '$releasedRows row(s) released',
      );
    }

    _reconcileStalledThinkingSessions(nowMs);
  }

  /// Shrink every full-resident session outside the
  /// [Sync.maxFullResidentSessions] most-recent slots down to the preview
  /// window. Unthrottled and independent of the idle grace window, so it can
  /// run on the session-switch path (`onSessionVisible`) to reclaim promptly
  /// while the user is actively navigating — not only on the throttled
  /// 5-minute sweep. Returns `(sessionsShrunk, rowsReleased)`.
  (int, int) _enforceResidentSessionBudget() {
    var shrunkSessions = 0;
    var releasedRows = 0;
    for (final sessionId in _fullResidentSessionsBeyondBudget()) {
      final released = _shrinkSessionWindow(sessionId);
      if (released > 0) {
        shrunkSessions++;
        releasedRows += released;
      }
    }
    return (shrunkSessions, releasedRows);
  }

  /// Enforce the resident-session budget outside the throttled shrink sweep
  /// (called on session switch). Logs only when it actually reclaims.
  void enforceResidentSessionBudgetNow() {
    final (shrunkSessions, releasedRows) = _enforceResidentSessionBudget();
    if (shrunkSessions > 0) {
      logger.info(
        '[messages] residency-budget shrink on switch: $shrunkSessions '
        'session(s), $releasedRows row(s) released',
      );
    }
  }

  /// Non-visible sessions still holding more than the preview window, ranked
  /// most-recently-touched first, that fall outside the
  /// [Sync.maxFullResidentSessions] most-recent slots. Sessions with no touch
  /// record sort oldest (they predate tracking). Returns an empty list when
  /// the number of full-resident sessions is within budget.
  List<String> _fullResidentSessionsBeyondBudget() {
    final full = <String>[];
    for (final entry in _sessionMessages.entries) {
      if (entry.key == _visibleSessionId) continue;
      if (entry.value.length <= Sync.idleSessionShrinkKeepRows) continue;
      full.add(entry.key);
    }
    if (full.length <= Sync.maxFullResidentSessions) return const <String>[];
    full.sort((a, b) {
      final ta = _sessionMessagesTouchedAtMs[a] ?? 0;
      final tb = _sessionMessagesTouchedAtMs[b] ?? 0;
      return tb.compareTo(ta); // most-recent first
    });
    return full.sublist(Sync.maxFullResidentSessions);
  }

  /// Shrink one non-visible session's resident window to
  /// [Sync.idleSessionShrinkKeepRows] newest rows, preserving retry identity
  /// (an unsettled send keeps the session full) and re-arming the scroll-back
  /// boundary so reopening pages history back in instead of showing a false
  /// "beginning of conversation" (the 2026-08-03 hollowed-session bug shape).
  ///
  /// Returns the number of rows released, or 0 if the session was skipped
  /// (already at/below the preview window, or holding an unsettled send).
  int _shrinkSessionWindow(String sessionId) {
    final rows = _sessionMessages[sessionId];
    if (rows == null || rows.length <= Sync.idleSessionShrinkKeepRows) return 0;
    // Same predicate as AutoArchiveService.hasUnsettledSend (not imported
    // here: auto_archive_service already imports sync_service).
    final hasUnsettledSend = rows.any((message) {
      final status = message['sendStatus'];
      return status == 'sending' || status == 'pending' || status == 'failed';
    });
    if (hasUnsettledSend) return 0;

    final dropped = rows.sublist(
      0,
      rows.length - Sync.idleSessionShrinkKeepRows,
    );
    _sessionMessages[sessionId] = rows.sublist(
      rows.length - Sync.idleSessionShrinkKeepRows,
    );
    // Rows left the window: full-history residency can no longer be claimed,
    // and a previously-pinned "fully loaded" walk must un-pin so
    // hasOlderMessages doesn't go false over a 25-row window.
    _sessionsHistoryTrimmed.add(sessionId);
    _sessionsHistoryFullyLoaded.remove(sessionId);
    final minSeq = _minLoadedSeq(sessionId);
    if (minSeq != null && minSeq > 1) {
      _sessionFirstLoadedSeq[sessionId] = minSeq;
      _scheduleSaveFirstLoadedSeq();
    }
    _pruneSessionContentSignaturePrefix(sessionId, dropped);
    _pendingToolResults.remove(sessionId);
    _invalidateMessageCaches(sessionId);
    return dropped.length;
  }

  /// Demote `thinking` on sessions whose process stopped producing events.
  ///
  /// `thinking` is only ever cleared by a server event; a daemon that dies
  /// mid-turn, or whose terminal event is lost, leaves it true forever.
  /// Every surface keyed on it then animates at full frame rate on an
  /// otherwise idle chat — the streaming caret, the stop bar, running tool
  /// rows, and the sub-agent banner can all latch at once, which is the
  /// measured "renderer never idles" signature (progressive-lag audit
  /// 2026-08-24, third pass). A turn that has produced zero message
  /// mutations for [Sync.stuckThinkingReconcileAfterMs] while its daemon
  /// keeps heartbeating is treated as wedged: thinking is demoted locally
  /// and stuck running tool rows walk back to canceled, same as the
  /// presence-offline path. Truth self-heals — the next server update
  /// rewrites the field, and a late tool result overwrites a canceled row.
  void _reconcileStalledThinkingSessions(int nowMs) {
    var demoted = 0;
    for (final entry in _sessions.entries.toList(growable: false)) {
      final session = entry.value;
      if (!session.thinking) continue;
      final touchedAt = _sessionMessagesTouchedAtMs[entry.key];
      // No resident window yet (spawned, nothing streamed) — conservative
      // skip; spawn-readiness handling owns that case.
      if (touchedAt == null) continue;
      if (nowMs - touchedAt < Sync.stuckThinkingReconcileAfterMs) continue;
      _sessions[entry.key] = session.copyWith(thinking: false);
      _reconcileStuckRunningTools(entry.key);
      demoted++;
    }
    if (demoted > 0) {
      logger.info(
        '[sessions] demoted thinking on $demoted stalled session(s) '
        '(no message mutations for '
        '${Sync.stuckThinkingReconcileAfterMs}ms)',
      );
      _notifyDataChanged({SyncDomain.sessions});
    }
  }

  /// Mark resident tool-calls stuck in `running` as `canceled` once the
  /// turn is over.
  ///
  /// A tool result that was lost, aborted, or queued against a tool-call
  /// trimmed out of the resident window leaves its row in `running` forever.
  /// Every such row keeps a full-fps pulse animation, a 1s elapsed-time
  /// tick, and an indeterminate spinner alive for as long as it is mounted —
  /// a resting chat can never let the frame pipeline go idle. Called when a
  /// session's `thinking` flips false (socket delta) and when presence goes
  /// offline: in both cases no process is producing results for these calls.
  ///
  /// Rows waiting on an unresolved permission are skipped — they are
  /// legitimately parked, not stuck. A late result for a canceled row still
  /// wins: [ToolResultProcessor.applyToolResults] overwrites state on match.
  void _reconcileStuckRunningTools(String sessionId) {
    final messages = _sessionMessages[sessionId];
    if (messages == null || messages.isEmpty) return;

    final (updated, changed) = _cancelRunningRows(messages);
    if (!changed) return;

    _sessionMessages[sessionId] = updated;
    _invalidateMessageCaches(sessionId);
    logger.info(
      '[toolResults] canceled stuck running tool row(s) for $sessionId '
      '(turn ended without results)',
    );
    _notifySessionMessagesChanged(sessionId);
  }

  (List<Map<String, dynamic>>, bool) _cancelRunningRows(
    List<Map<String, dynamic>> messages,
  ) {
    var changed = false;
    List<Map<String, dynamic>>? updated;
    for (var i = 0; i < messages.length; i++) {
      final msg = messages[i];
      var next = msg;

      final children = msg['children'];
      if (children is List<dynamic>) {
        final typedChildren = children
            .whereType<Map<String, dynamic>>()
            .toList();
        final (updatedChildren, childChanged) = _cancelRunningRows(
          typedChildren,
        );
        if (childChanged) {
          next = {...next, 'children': updatedChildren};
        }
      }

      if (msg['kind'] == 'tool-call' &&
          msg['state'] == 'running' &&
          msg['result'] == null &&
          !_hasPendingPermission(msg)) {
        next = {...next, 'state': 'canceled'};
      }

      if (!identical(next, msg)) {
        changed = true;
        updated ??= List<Map<String, dynamic>>.of(messages);
        updated[i] = next;
      }
    }
    return (updated ?? messages, changed);
  }

  bool _hasPendingPermission(Map<String, dynamic> msg) {
    final permission = msg['permission'];
    if (permission is! Map<String, dynamic>) return false;
    final status = permission['status'];
    return status != 'approved' && status != 'denied' && status != 'canceled';
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
      _invalidateMessageCaches(sessionId);
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

  /// Order comparator shared by the merge sort and the in-place update
  /// guard: createdAt first, seq as the tie-break.
  int _messageOrderCompare(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aCreated = _asInt(a['createdAt']) ?? 0;
    final bCreated = _asInt(b['createdAt']) ?? 0;
    if (aCreated != bCreated) return aCreated.compareTo(bCreated);
    return (a['seq'] as int? ?? 0).compareTo(b['seq'] as int? ?? 0);
  }

  /// In-place update fast path for the streaming case.
  ///
  /// A streaming turn re-delivers the *same* agent row 20-50x/second as
  /// tokens arrive. [_canAppendMessagesFastPath] deliberately rejects those
  /// (the id already exists), so every token fell through to the full merge:
  /// a whole-list `LinkedHashMap` rebuild, a localId reverse index over every
  /// row, an O(resident) `_isPromptEcho` scan per incoming row, a full
  /// `toList()` copy and an order re-check — five passes over up to 1000
  /// decrypted rows per token. That is the measured sustained 5-30 s jank
  /// window on chat (progressive-lag audit 2026-08-24, seventh pass), and the
  /// allocation churn behind the GC stalls.
  ///
  /// When every incoming row is a pure content update of a row already in the
  /// tail, and none of the merge path's identity semantics can apply, the row
  /// is replaced where it sits — O(incoming + tail) instead of O(resident).
  /// Anything touching send identity (`localId` on either side), prompt-echo
  /// candidates, user rows, or a replacement that would reorder the list
  /// falls through to the proven full merge.
  bool _tryInPlaceTailUpdate(
    List<Map<String, dynamic>> existing,
    List<Map<String, dynamic>> incoming,
  ) {
    if (existing.isEmpty || incoming.isEmpty) return false;

    const tailWindow = 20;
    final tailStart = existing.length > tailWindow
        ? existing.length - tailWindow
        : 0;
    final tailIndex = <String, int>{};
    for (var i = tailStart; i < existing.length; i++) {
      final id = existing[i]['id'] as String?;
      if (id != null && id.isNotEmpty) tailIndex[id] = i;
    }

    final targets = <int>[];
    for (final message in incoming) {
      final id = message['id'] as String?;
      if (id == null || id.isEmpty) return false;
      final index = tailIndex[id];
      if (index == null) return false;

      // Optimistic replacement, prompt-echo suppression and the
      // unidentified-user fallback are merge-path semantics. Never emulate
      // them here — the canonical localId contract outranks the fast path.
      final localId = message['localId'] as String?;
      if (localId != null && localId.isNotEmpty) return false;
      if (message['isPromptEchoCandidate'] == true) return false;
      if (message['role'] == 'user') return false;

      final target = existing[index];
      final targetLocalId = target['localId'] as String?;
      if (targetLocalId != null && targetLocalId.isNotEmpty) return false;

      // Replacing in place is only safe while it cannot reorder the list.
      if (index > 0 && _messageOrderCompare(existing[index - 1], message) > 0) {
        return false;
      }
      if (index < existing.length - 1 &&
          _messageOrderCompare(message, existing[index + 1]) > 0) {
        return false;
      }
      targets.add(index);
    }

    for (var i = 0; i < incoming.length; i++) {
      final message = incoming[i];
      final index = targets[i];
      final target = existing[index];
      // Same preservation the merge path performs when replacing a row: the
      // server copy carries neither grouped children nor root uuids, both of
      // which are computed locally by the sidechain grouper.
      final existingChildren = target['children'] as List<dynamic>?;
      if (existingChildren != null &&
          existingChildren.isNotEmpty &&
          message['children'] == null) {
        message['children'] = existingChildren;
      }
      final existingRoots = target['_sidechainRootUuids'] as List<dynamic>?;
      if (existingRoots != null &&
          existingRoots.isNotEmpty &&
          message['_sidechainRootUuids'] == null) {
        message['_sidechainRootUuids'] = existingRoots;
      }
      try {
        existing[index] = message;
      } on UnsupportedError {
        // A fixed-length or unmodifiable window slipped in — let the full
        // merge path rebuild the list instead.
        return false;
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

      // Prompt-echo candidates need the full merge path: only it runs
      // `_isPromptEcho`, and a blind append would leak the echo as a
      // second visible bubble repeating the user's prompt.
      if (message['isPromptEchoCandidate'] == true) {
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
    _notifySessionMessagesChangedUiOnly(sessionId);
  }

  void _upsertSessionMessages(
    String sessionId,
    List<Map<String, dynamic>> messages,
  ) {
    // Audit 2026-08-03: localIds minted in an earlier process lifetime
    // arrive via fetch/socket rows. Seeding them into the invariant
    // monitor keeps restart-time acks from reading as false
    // `unknown_acked_local_id` violations.
    for (final message in messages) {
      final localId = message['localId'];
      if (localId is String && localId.isNotEmpty) {
        messageInvariantMonitor.seedSentLocalId(localId);
      }
    }
    // NOTE: do NOT reset _orphanFetchOlderNoProgressCount here. The
    // orphan walk-back's own fetchOlderMessages upserts every page it
    // fetches, so a blanket reset on upsert pinned the counter below
    // both caps and the walk-back looped forever. If an upsert delivers
    // the missing parent Task, the grouper attaches the orphans and the
    // sweep's progress path clears the counter; if it delivers new
    // orphans, the sweep's signature check opens a fresh budget.
    final existing = _sessionMessages[sessionId] ?? <Map<String, dynamic>>[];
    _liftOrphanGiveUpIfNewParentArrived(sessionId, existing, messages);
    final maxMessages = _sessionTrimCap(sessionId);

    if (_canAppendMessagesFastPath(existing, messages)) {
      final appended = <Map<String, dynamic>>[...existing, ...messages];
      final trimmed = appended.length > maxMessages
          ? appended.sublist(appended.length - maxMessages)
          : appended;
      if (trimmed.length != appended.length) {
        // Rows fell off the head — full-history residency can no longer be
        // claimed for this session. See the pin guard in
        // fetchOlderMessages.
        _sessionsHistoryTrimmed.add(sessionId);
      }
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
      _invalidateMessageCaches(sessionId);
      if (trimmed.length == appended.length) {
        _updateSessionContentSignatures(sessionId, messages);
      } else {
        // Rows fell off the head. The append fast path performs no other
        // removals, so the trimmed prefix is the exact set of rows that
        // left the window — prune its keys directly instead of walking
        // the whole list to rediscover them.
        _pruneSessionContentSignaturePrefix(
          sessionId,
          appended.sublist(0, appended.length - maxMessages),
        );
        _updateSessionContentSignatures(sessionId, messages);
      }
      _ensureFirstLoadedSeq(sessionId);
      return;
    }

    // Streaming updates re-deliver an existing tail row many times a second.
    // Replacing it where it sits avoids rebuilding and re-scanning the whole
    // resident window per token; identity-sensitive rows still fall through.
    if (_tryInPlaceTailUpdate(existing, messages)) {
      _sessionMessages[sessionId] = existing;
      if (sessionId == _visibleSessionId && logger.shouldLog(LogLevel.debug)) {
        logger.debug(
          '[messages] upsert session=$sessionId '
          'incoming=${messages.length} '
          'before=${existing.length} '
          'after=${existing.length} '
          'mode=in_place',
        );
      }
      _invalidateMessageCaches(sessionId);
      _updateSessionContentSignatures(sessionId, messages);
      _ensureFirstLoadedSeq(sessionId);
      return;
    }

    final merged = <String, Map<String, dynamic>>{
      for (final message in existing)
        if (message['id'] != null) message['id'] as String: message,
    };
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
      if (_isPromptEcho(merged.values, message)) {
        continue;
      }
      final messageId = message['id'] as String?;
      if (messageId == null || messageId.isEmpty) {
        // Defensive: skip messages without valid ids to prevent crashes.
        // The fast path already filters these at line 7070-7072.
        continue;
      }
      final localId = message['localId'] as String?;
      final hasLocalId = localId != null && localId.isNotEmpty;
      if (!hasLocalId && message['role'] == 'user') {
        final fallbackLocalId = _findUnidentifiedOptimisticUser(
          merged.values,
          message,
        );
        if (fallbackLocalId != null) {
          merged.remove(fallbackLocalId);
          // Preserve the canonical client identity even when the incoming
          // record came through a path that dropped localId.
          message['localId'] = fallbackLocalId;
          message['sendStatus'] = 'sent';
        }
      }
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

    if (sorted.length > maxMessages) {
      // Rows fell off the head — full-history residency can no longer be
      // claimed for this session. See the pin guard in fetchOlderMessages.
      _sessionsHistoryTrimmed.add(sessionId);
      _sessionMessages[sessionId] = sorted.sublist(sorted.length - maxMessages);
    } else {
      _sessionMessages[sessionId] = sorted;
    }
    _applySessionContentSignatureDelta(sessionId, messages);
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
    _invalidateMessageCaches(sessionId);
    _ensureFirstLoadedSeq(sessionId);
  }
}
