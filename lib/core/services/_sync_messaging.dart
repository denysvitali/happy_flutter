part of 'sync_service.dart';

extension SyncMessaging on Sync {
  /// Fetch messages for a session.
  ///
  /// On first open (no entry in [_sessionLastSeq]) this uses the session's
  /// [Session.lastSeq] hint to jump straight to the tail of the history,
  /// fetching only the most recent [Sync.initialLoad] messages.  Subsequent
  /// calls (incremental delta syncs) continue from [_sessionLastSeq] as before.
  Future<void> fetchMessages(String sessionId) async {
    logger.debug(
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

      logger.debug(
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
        logger.debug(
          '[fetchMessages] $sessionId already caught up '
          '(cursor=$cursorSeq server=$serverLastSeq) '
          '— skipping',
        );
        // Notify UI so any pending loading state clears, but do NOT
        // trigger a message cache save — no messages changed.
        _notifySessionMessagesChangedUiOnly(sessionId);
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
          logger.debug(
            '[fetchMessages] $sessionId gap too large '
            '(cursor=$cursorSeq server=$serverLastSeq) — '
            'switching to tail-load afterSeq=$afterSeq',
          );
        } else if (forceTailRefresh && !isFirstLoad) {
          logger.debug(
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
        // ── Check visibility ──
        // Continue fetching even when the session is no longer visible so
        // messages are not lost.  The user may navigate back at any time
        // and expects the full conversation to be there.  We skip only the
        // per-page UI notification for non-visible sessions to avoid
        // unnecessary repaints.
        final isStillVisible = _visibleSessionId == sessionId;

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
            _sessionSpawnedProfile.remove(sessionId);
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

        logger.debug(
          '[fetchMessages] $sessionId page=$page '
          'msgs=${messages.length} hasMore=$hasMore '
          'fetchMs=$fetchMs',
        );

        // ── Decrypt + process (isolate for large batches) ──
        // Pre-filter messages already decrypted and stored, so we
        // only decrypt genuinely new ones during catch-up polling.
        //
        // Build a map of id → encrypted content signature so we
        // can detect when the server returns an updated version
        // of a message we already have (same id, different
        // content).  Previously we filtered by id alone, which
        // silently dropped server-side updates.
        final existingSignatures = <String, String?>{};
        for (final m in _sessionMessages[sessionId] ??
            const <Map<String, dynamic>>[]) {
          final id = m['id'] as String?;
          if (id != null) {
            // Store the encrypted content blob ('c' field inside
            // the content map) as a lightweight signature.
            final content = m['content'];
            final sig = content is Map ? content['c'] as String? : null;
            existingSignatures[id] = sig;
          }
        }
        final newMessages = existingSignatures.isEmpty
            ? messages
            : [
                for (final m in messages)
                  if (!existingSignatures.containsKey(m['id']) ||
                      _hasUpdatedContent(m, existingSignatures))
                    m,
              ];
        final decryptStart = Stopwatch()..start();
        final processed = await sessionEncryption.decryptAndProcessMessages(
          newMessages,
          sessionId,
        );
        final decryptMs = decryptStart.elapsedMilliseconds;
        final skippedCount = messages.length - newMessages.length;
        final userCount = processed.messages
            .where((message) => message['role'] == MessageRole.user)
            .length;
        final agentCount = processed.messages
            .where((message) => message['role'] == MessageRole.agent)
            .length;
        final eventCount = processed.messages
            .where((message) => message['kind'] == 'agent-event')
            .length;
        logger.debug(
          '[fetchMessages] $sessionId page=$page '
          'fetched=${messages.length} skipped=$skippedCount '
          'decrypted=${newMessages.length} '
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
              '[fetchMessages] dropped: $reason',
            );
          }
        }

        // ── Yield before main-thread merge/group work ──
        await Future<void>.delayed(Duration.zero);

        // ── Upsert messages ──
        // Gap recovery: merge new tail-loaded messages into the existing
        // list instead of clearing first.  The upsert deduplicates by ID
        // and the 3000-message cap trims the oldest entries.  This
        // preserves messages the user already sees while filling in the
        // gap, avoiding permanent loss when pagination is interrupted.
        if (isGapRecovery && page == 0 && processed.messages.isNotEmpty) {
          logger.debug(
            '[fetchMessages] $sessionId gap recovery: '
            'merging ${processed.messages.length} new messages '
            '(existing=${_sessionMessages[sessionId]?.length ?? 0})',
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

        logger.debug(
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
          if (isStillVisible) {
            _notifySessionMessagesChanged(sessionId);
            _notifyDataChanged();
          }
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
          logger.debug(
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

  /// Returns `true` when the incoming wire message [m] has different
  /// encrypted content than what is stored in [existingSignatures].
  /// This detects server-side updates to messages we already have.
  static bool _hasUpdatedContent(
    Map<String, dynamic> m,
    Map<String, String?> existingSignatures,
  ) {
    final id = m['id'] as String?;
    if (id == null || !existingSignatures.containsKey(id)) return false;
    final existingSig = existingSignatures[id];
    final content = m['content'];
    final incomingSig =
        content is Map ? content['c'] as String? : null;
    // If neither version has an encrypted blob, treat as unchanged
    // to avoid redundant decryption of plaintext messages.
    if (existingSig == null && incomingSig == null) return false;
    return incomingSig != existingSig;
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

      logger.debug(
        '[fetchOlderMessages] $sessionId '
        'msgs=${messages.length}',
      );

      final processed = await sessionEncryption.decryptAndProcessMessages(
        messages,
        sessionId,
      );

      logger.debug(
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
      _paginationErrorController.add(sessionId);
    } finally {
      _loadingOlderMessages.remove(sessionId);
      _notifyDataChanged();
    }
  }

  /// Ensure [_sessionFirstLoadedSeq] reflects the actual boundary of
  /// in-memory messages for [sessionId].
  ///
  /// When a session starts small (< 200 messages), the initial
  /// [fetchMessages] call sets [_sessionFirstLoadedSeq] to 0 ("all
  /// loaded").  If the session then grows past [Sync.initialLoad]
  /// messages via socket events, [hasOlderMessages] continues to
  /// return false because nothing updates the boundary.  This method
  /// detects that staleness and corrects it by scanning the in-memory
  /// messages for their minimum seq.
  void _ensureFirstLoadedSeq(String sessionId) {
    final current = _sessionFirstLoadedSeq[sessionId];
    // Only fix when the boundary claims "all loaded" (0 or null) but
    // in-memory data suggests otherwise.
    if (current != null && current != 0) return;

    final messages = _sessionMessages[sessionId];
    if (messages == null || messages.isEmpty) return;

    int? minSeq;
    for (final m in messages) {
      final seq = m['seq'] as int?;
      if (seq != null && (minSeq == null || seq < minSeq)) {
        minSeq = seq;
      }
    }
    if (minSeq != null && minSeq > 1) {
      _sessionFirstLoadedSeq[sessionId] = minSeq;
      MMKVStorage().saveSessionFirstLoadedSeq(
        Map.unmodifiable(_sessionFirstLoadedSeq),
      );
    }
  }
}
