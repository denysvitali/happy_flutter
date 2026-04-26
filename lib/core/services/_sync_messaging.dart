part of 'sync_service.dart';

extension SyncMessaging on Sync {
  /// Fetch messages for a session.
  ///
  /// On first open (no entry in [_sessionLastSeq]) this uses the session's
  /// [Session.lastSeq] hint to jump straight to the tail of the history,
  /// fetching only the most recent [Sync.initialLoad] messages.  Subsequent
  /// calls (incremental delta syncs) continue from [_sessionLastSeq] as before.
  Future<void> fetchMessages(String sessionId) async {
    logger.debug('Fetching messages for session: $sessionId');
    final fetchStopwatch = Stopwatch()..start();

    // Start a low-cardinality transaction if there is no parent span so
    // GlitchTip can aggregate fetches across sessions.
    final parentSpan = Sentry.getSpan();
    final fetchSpan =
        parentSpan?.startChild(
          'sync.fetchMessages',
          description: 'Fetch messages for visible/background session',
        ) ??
        Sentry.startTransaction(
          'sync.fetchMessages',
          'sync.fetch',
          bindToScope: false,
        );
    fetchSpan
      ..setData('sessionId', sessionId)
      ..setData('hasParentSpan', parentSpan != null);

    var sessionEncryption = encryption.getSessionEncryption(sessionId);
    if (sessionEncryption == null) {
      final encSpan = fetchSpan.startChild(
        'sync.encryption.init',
        description: 'Wait for session encryption',
      );
      unawaited(
        Sentry.addBreadcrumb(
          Breadcrumb(
            message:
                'fetchMessages: encryption null, '
                'awaiting sessions',
            category: 'sync.messages',
            data: {'sessionId': sessionId},
          ),
        ),
      );
      // Encryption may not be initialized yet — wait for pending fetch.
      await sessionsSync.invalidateAndAwait();
      sessionEncryption = encryption.getSessionEncryption(sessionId);
      if (sessionEncryption == null) {
        // Force a full fetch in case changedSince race skipped the session.
        _forceFullFetchNext = true;
        await sessionsSync.invalidateAndAwait();
        sessionEncryption = encryption.getSessionEncryption(sessionId);
      }
      unawaited(encSpan.finish());
      if (sessionEncryption == null) {
        logger.warning(
          'Session encryption not initialized for '
          '$sessionId after 2 attempts, skipping',
        );
        fetchSpan.setData('status', 'preconditionFailed');
        fetchSpan.setData('encryptionInitFailed', true);
        fetchSpan.setData('elapsedMs', fetchStopwatch.elapsedMilliseconds);
        unawaited(fetchSpan.finish());
        unawaited(
          Sentry.addBreadcrumb(
            Breadcrumb(
              message:
                  'fetchMessages: encryption still '
                  'null after 2 attempts',
              category: 'sync.messages',
              level: SentryLevel.warning,
              data: {
                'sessionId': sessionId,
                'sessionExists': _sessions.containsKey(sessionId),
                'elapsedMs': fetchStopwatch.elapsedMilliseconds,
              },
            ),
          ),
        );
        // Notify UI so the loading spinner clears.
        _notifySessionMessagesChanged(sessionId);
        _notifyDataChanged({SyncDomain.messages, SyncDomain.sessions});
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
      final forceProbe = _sessionsNeedingFetchProbe.remove(sessionId);
      int afterSeq;

      // Detect large gaps: when the cursor is far behind the session's
      // current lastSeq, forward-crawling page by page is extremely slow
      // (100 msgs/page × decrypt × O(n) grouping per page).  Fall back
      // to a tail-load so we only fetch the most recent messages.
      //
      // On reconnect, use the pre-reconnect cursor snapshot for the
      // visible session to avoid skipping the disconnect gap.  Inline
      // socket events arriving after reconnect can advance the cursor
      // past messages that arrived while the socket was down — using
      // the snapshot ensures the fetch starts from the correct position.
      final rawCursorSeq = _sessionLastSeq[sessionId] ?? 0;
      final cursorSeq = (forceProbe &&
              sessionId == _visibleSessionId &&
              _reconnectCursorSnapshot != null &&
              _reconnectCursorSnapshot! < rawCursorSeq)
          ? _reconnectCursorSnapshot!
          : rawCursorSeq;
      if (forceProbe &&
          _reconnectCursorSnapshot != null &&
          sessionId == _visibleSessionId) {
        logger.debug(
          '[fetchMessages] $sessionId using reconnect cursor snapshot '
          '(snapshot=$_reconnectCursorSnapshot, live=$rawCursorSeq)',
        );
        _reconnectCursorSnapshot = null;
      }
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
        'forceProbe=$forceProbe '
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
      final hasGap =
          serverLastSeq > 0 &&
          cursorSeq <= serverLastSeq &&
          (serverLastSeq - cursorSeq) > Sync.initialLoad;
      if (!isFirstLoad &&
          !forceProbe &&
          cursorSeq > 0 &&
          serverLastSeq > 0 &&
          cursorSeq == serverLastSeq &&
          !hasGap) {
        logger.debug(
          '[fetchMessages] $sessionId already caught up '
          '(cursor=$cursorSeq server=$serverLastSeq) '
          '— skipping',
        );
        // Even when skipping the HTTP fetch, run the sidechain grouper
        // if there are pending orphans — they arrived via socket inline
        // processing but grouping may not have run yet (e.g. the last
        // inline batch had no top-level sidechain content but orphans
        // from a prior batch are still in the list).  Also run if the
        // session was marked as needing regroup when visible.
        final messages = _sessionMessages[sessionId];
        final hasOrphans = messages != null &&
            messages.any((m) => m['isSidechain'] == true);
        if (hasOrphans ||
            _sessionsNeedingVisibleRegroup.contains(sessionId)) {
          // Skip the grouper if orphan processing is suppressed — the
          // deferred sweep determined these orphans are stuck (parent
          // Task never arrived) and 30s haven't elapsed yet.  Without
          // this guard, every fetchMessages call re-runs the O(4n)
          // grouper for sessions with persistent orphans.
          if (hasOrphans) {
            final nowMs = DateTime.now().millisecondsSinceEpoch;
            final suppressedUntil = _orphanSuppressedUntilMs[sessionId];
            if (suppressedUntil != null && nowMs < suppressedUntil) {
              // Clear the flag so onSessionVisible doesn't retry grouping
              // for these stuck orphans during the suppression window.
              _sessionsNeedingVisibleRegroup.remove(sessionId);
              _notifySessionMessagesChangedUiOnly(sessionId);
              _notifyDataChanged({SyncDomain.messages, SyncDomain.sessions});
              return;
            }
          }
          // Log orphan count for telemetry — helps quantify how often
          // this catch-up path fixes sidechain orphans.
          if (hasOrphans) {
            // hasOrphans is only true when messages != null
            final orphanCount = messages.where((m) => m['isSidechain'] == true).length;
            logger.info(
              '[fetchMessages] $sessionId: caught-up skip with '
              '$orphanCount orphan(s) — running grouper in catch-up path',
            );
          }
          _groupSidechainMessages(sessionId);
          _sessionsNeedingVisibleRegroup.remove(sessionId);
          _notifySessionMessagesChanged(sessionId);
          _notifyDataChanged({SyncDomain.messages, SyncDomain.sessions});
        } else {
          _notifySessionMessagesChangedUiOnly(sessionId);
          _notifyDataChanged({SyncDomain.messages, SyncDomain.sessions});
        }
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
      var didMutateMessages = false;
      var shouldRegroupWhenVisible = false;
      var notifiedVisibleData = false;
      fetchSpan
        ..setData('isFirstLoad', isFirstLoad)
        ..setData('forceTailRefresh', forceTailRefresh)
        ..setData('forceProbe', forceProbe)
        ..setData('gapTooLarge', gapTooLarge)
        ..setData('cursorSeq', cursorSeq)
        ..setData('serverLastSeq', serverLastSeq);

      var totalFetchedMessages = 0;
      var totalDecryptedMessages = 0;
      var totalSkippedMessages = 0;
      var totalToolResults = 0;
      var totalUsageUpdates = 0;
      var totalPagesFetched = 0;
      while (true) {
        // ── Check visibility ──
        // Continue fetching even when the session is no longer visible so
        // messages are not lost.  The user may navigate back at any time
        // and expects the full conversation to be there.  We skip only the
        // per-page UI notification for non-visible sessions to avoid
        // unnecessary repaints.
        final isStillVisible = _visibleSessionId == sessionId;

        final pageSpan = fetchSpan.startChild(
          'sync.fetchMessages.page',
          description: 'Fetch/process page $page',
        );
        pageSpan
          ..setData('page', page)
          ..setData('afterSeq', afterSeq)
          ..setData('isVisible', isStillVisible);
        final maxPages = isStillVisible
            ? Sync._visibleMessageFetchPageLimit
            : Sync._backgroundMessageFetchPageLimit;
        pageSpan.setData('maxPagesThisRun', maxPages);

        final httpSpan = pageSpan.startChild(
          'sync.fetchMessages.http',
          description: 'Fetch message page',
        );
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
            queryParameters: {'after_seq': afterSeq, 'limit': 1000},
            options: Options(
              extra: const {'bypassCache': true},
              connectTimeout: Sync._messageFetchConnectTimeout,
              receiveTimeout: Sync._messageFetchReceiveTimeout,
            ),
          );
        }
        final fetchMs = fetchStart.elapsedMilliseconds;
        httpSpan
          ..setData('httpMs', fetchMs)
          ..setData('statusCode', response.statusCode ?? 0);
        await httpSpan.finish();

        if (!apiClient.isSuccess(response)) {
          final statusCode = response.statusCode;
          pageSpan
            ..status = const SpanStatus.internalError()
            ..setData('statusCode', statusCode ?? 0);
          logger.warning('Failed to fetch messages: $statusCode');
          unawaited(
            Sentry.addBreadcrumb(
              Breadcrumb(
                message: 'fetchMessages: HTTP error',
                category: 'sync.messages',
                level: SentryLevel.warning,
                data: {
                  'sessionId': sessionId,
                  'statusCode': statusCode,
                  'afterSeq': afterSeq,
                  'page': page,
                  'elapsedMs': fetchStopwatch.elapsedMilliseconds,
                },
              ),
            ),
          );
          // 404 means the session doesn't exist on the server. Clean up
          // the local session and stop retries to prevent repeated 404s.
          if (statusCode == 404) {
            logger.info(
              '[fetchMessages] Session $sessionId not found (404) '
              '— cleaning up local state',
            );
            _cleanupDeletedSession(sessionId);
          } else {
            // For other errors, notify UI so it stops the loading spinner
            // and can show an error/empty state instead of spinning forever.
            _notifySessionMessagesChanged(sessionId);
          }
          _notifyDataChanged({SyncDomain.messages, SyncDomain.sessions});
          await pageSpan.finish(status: const SpanStatus.internalError());
          break;
        }

        final data = WireParsers.asMap(response.data);
        if (data == null) {
          logger.warning(
            '[fetchMessages] $sessionId page=$page: '
            'response.data is ${response.data.runtimeType}, '
            'expected Map',
          );
          break;
        }
        final messages = (data['messages'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        final hasMore = data['hasMore'] as bool? ?? false;
        totalPagesFetched++;
        totalFetchedMessages += messages.length;
        pageSpan
          ..setData('fetchedMessages', messages.length)
          ..setData('hasMore', hasMore);

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
        final filterSpan = pageSpan.startChild(
          'sync.fetchMessages.filter',
          description: 'Filter unchanged messages',
        );
        final existingSignatures =
            _sessionContentSignatures[sessionId] ?? const <String, String?>{};
        final newMessages = existingSignatures.isEmpty
            ? messages
            : [
                for (final m in messages)
                  if (!existingSignatures.containsKey(m['id']) ||
                      _hasUpdatedContent(m, existingSignatures))
                    m,
              ];
        filterSpan
          ..setData('existingSignatures', existingSignatures.length)
          ..setData('newMessages', newMessages.length)
          ..setData('skippedMessages', messages.length - newMessages.length);
        await filterSpan.finish();

        final decryptSpan = pageSpan.startChild(
          'sync.fetchMessages.decrypt',
          description: 'Decrypt and process page',
        );
        final decryptStart = Stopwatch()..start();
        final processed = await sessionEncryption.decryptAndProcessMessages(
          newMessages,
          sessionId,
        );
        final decryptMs = decryptStart.elapsedMilliseconds;
        final skippedCount = messages.length - newMessages.length;
        totalSkippedMessages += skippedCount;
        totalDecryptedMessages += newMessages.length;
        totalToolResults += processed.toolResults.length;
        totalUsageUpdates += processed.usageUpdates.length;
        pageSpan
          ..setData('decryptMs', decryptMs)
          ..setData('newMessages', newMessages.length)
          ..setData('skippedMessages', skippedCount)
          ..setData('processedMessages', processed.messages.length)
          ..setData('toolResults', processed.toolResults.length)
          ..setData('usageUpdates', processed.usageUpdates.length)
          ..setData('maxSeq', processed.maxSeq);
        decryptSpan
          ..setData('decryptMs', decryptMs)
          ..setData('processedMessages', processed.messages.length)
          ..setData('toolResults', processed.toolResults.length)
          ..setData('usageUpdates', processed.usageUpdates.length)
          ..setData('maxSeq', processed.maxSeq);
        await decryptSpan.finish();
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
            logger.warning('[fetchMessages] dropped: $reason');
          }
        }

        // ── Yield before main-thread merge/group work ──
        final mergeSpan = pageSpan.startChild(
          'sync.fetchMessages.merge',
          description: 'Merge page into local state',
        );
        final mergeStart = Stopwatch()..start();
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
        if (processed.messages.isNotEmpty) {
          _upsertSessionMessages(sessionId, processed.messages);
          didMutateMessages = true;
          shouldRegroupWhenVisible =
              shouldRegroupWhenVisible ||
              processed.messages.any(
                (message) =>
                    message['isSidechain'] == true ||
                    message['kind'] == 'sidechain-root',
              );
        }

        // ── Yield ──
        await Future<void>.delayed(Duration.zero);

        // ── Apply tool results + usage ──
        if (processed.toolResults.isNotEmpty) {
          _applyToolResults(sessionId, processed.toolResults);
        }
        // Apply any pending tool results that arrived before these
        // messages. Only drain matched results so cross-path ordering
        // can't lose results.
        final pending = _pendingToolResults[sessionId];
        if (pending != null && pending.isNotEmpty) {
          final matched = _applyToolResults(sessionId, pending);
          if (matched.isNotEmpty) {
            pending.removeWhere(
                (r) => matched.contains(r['toolUseId']));
            if (pending.isEmpty) {
              _pendingToolResults.remove(sessionId);
            }
          }
        }
        for (final u in processed.usageUpdates) {
          final usageMap = WireParsers.asMap(u['usage']);
          if (usageMap != null) {
            _updateSessionUsage(
              u['sessionId'] as String,
              usageMap,
              u['timestamp'] as int,
            );
          }
        }

        // ── Apply permission requests (per-page, cheap) ──
        _applyPermissionRequests(sessionId);
        mergeSpan.setData('mergeApplyMs', mergeStart.elapsedMilliseconds);
        await mergeSpan.finish();
        pageSpan.setData('mergeApplyMs', mergeStart.elapsedMilliseconds);

        if (processed.maxSeq > afterSeq) {
          afterSeq = processed.maxSeq;
        }
        _advanceSeqCursor(sessionId, afterSeq);

        if (processed.maxSeq > 0 &&
            processed.messages.isEmpty &&
            processed.toolResults.isEmpty &&
            messages.isNotEmpty) {
          // All raw messages were silently dropped by the processor.
          // This case is already covered by the droppedReasons logging
          // in the block above — do NOT log again to avoid duplicate
          // GlitchTip events (each unique reason string creates a
          // separate issue in GlitchTip, inflating event counts).
        }

        logger.debug(
          '[fetchMessages] $sessionId page=$page '
          'decryptMs=$decryptMs '
          'upsert=${processed.messages.isNotEmpty}',
        );

        // Notify the UI after each page so the chat screen can
        // display partial results immediately instead of waiting
        // for all pages to complete. This is critical for sessions
        // with many messages where pagination + decryption exceeds
        // the 5s awaitQueue timeout in ChatScreen._doInitialLoad.
        if (processed.messages.isNotEmpty && isStillVisible) {
          if (!notifiedVisibleData) {
            notifiedVisibleData = true;
            _notifySessionMessagesChanged(sessionId);
            _notifyDataChanged({SyncDomain.messages, SyncDomain.sessions});
          }
        }

        if (!hasMore) {
          await pageSpan.finish();
          break;
        }
        page++;

        // Safety valve: stop this cycle to let the UI render, then
        // schedule a follow-up fetch so we keep crawling.  Without the
        // re-trigger, messages beyond the cutoff are lost until the
        // next external invalidation — which may never come if all new
        // messages use the inline socket path.
        if (page >= maxPages) {
          logger.debug(
            '[fetchMessages] $sessionId hit $maxPages page limit '
            '— stopping forward crawl at afterSeq=$afterSeq',
          );
          // Re-trigger so the next cycle continues from the new cursor.
          messagesSync[sessionId]?.invalidate();
          pageSpan.setData('hitMaxPages', true);
          await pageSpan.finish();
          break;
        }

        // ── Yield between pages ──
        await Future<void>.delayed(Duration.zero);
        await pageSpan.finish();
      }
      final isVisibleAtCompletion = _visibleSessionId == sessionId;
      // Final notification in case some pages had no messages
      // (notification already fired per-page for non-empty pages).
      // Run sidechain grouping once after all pages are loaded —
      // previously this ran per-page doing O(4n) work each time.
      //
      // For non-visible sessions, defer regrouping and UI-domain
      // notifications until the session is opened. Background sync
      // should update in-memory/cache state without forcing expensive
      // main-isolate regroup + rebuild work across the app.
      if (isVisibleAtCompletion) {
        final finalizeSpan = fetchSpan.startChild(
          'sync.fetchMessages.finalize',
          description: 'Finalize visible fetch state',
        );
        _groupSidechainMessages(sessionId);
        _notifySessionMessagesChanged(sessionId);
        _notifyDataChanged({SyncDomain.messages, SyncDomain.sessions});
        await finalizeSpan.finish();

        // Cross-device backfill: when a session is opened for the
        // first time on this device and the tail-load only covered
        // a small seq window (because the server's `lastSeq` counts
        // non-message events like metadata/agent-state updates),
        // the user can land on a screen with very few messages even
        // though the session has a long history.  Proactively pull
        // a couple of older pages so the initial view has a useful
        // amount of context without waiting for the user to scroll
        // to the oldest message.
        if (isFirstLoad) {
          unawaited(_backfillInitialHistory(sessionId));
        }
      } else if (didMutateMessages) {
        final finalizeSpan = fetchSpan.startChild(
          'sync.fetchMessages.finalize',
          description: 'Persist background fetch state',
        );
        _scheduleSaveMessages(sessionId);
        if (shouldRegroupWhenVisible) {
          _sessionsNeedingVisibleRegroup.add(sessionId);
        }
        await finalizeSpan.finish();
      }
      // Finish the fetch span successfully
      fetchSpan
        ..setData('pagesFetched', totalPagesFetched)
        ..setData('totalFetchedMessages', totalFetchedMessages)
        ..setData('totalDecryptedMessages', totalDecryptedMessages)
        ..setData('totalSkippedMessages', totalSkippedMessages)
        ..setData('totalToolResults', totalToolResults)
        ..setData('totalUsageUpdates', totalUsageUpdates)
        ..setData('mutatedMessages', didMutateMessages)
        ..setData('regroupOnVisible', shouldRegroupWhenVisible)
        ..setData('completedVisible', isVisibleAtCompletion)
        ..setData('totalElapsedMs', fetchStopwatch.elapsedMilliseconds);
      unawaited(fetchSpan.finish());
    } on DioException catch (e) {
      // If the server returns 404, the session was deleted. Clean up
      // local state instead of retrying (which would produce 2 more
      // wasted 404 requests via InvalidateSync).
      if (e.response?.statusCode == 404) {
        logger.info(
          '[fetchMessages] $sessionId returned 404 — '
          'cleaning up deleted session',
        );
        _cleanupDeletedSession(sessionId);
        unawaited(fetchSpan.finish());
        return;
      }
      fetchSpan.setData('status', 'networkError');
      fetchSpan.setData('dioExceptionType', e.type.name);
      fetchSpan.setData('totalElapsedMs', fetchStopwatch.elapsedMilliseconds);
      unawaited(fetchSpan.finish());
      unawaited(
        Sentry.addBreadcrumb(
          Breadcrumb(
            message: 'fetchMessages: DioException',
            category: 'sync.messages',
            level: SentryLevel.error,
            data: {
              'sessionId': sessionId,
              'type': e.type.name,
              'statusCode': e.response?.statusCode,
              'elapsedMs': fetchStopwatch.elapsedMilliseconds,
            },
          ),
        ),
      );
      // Network error (e.g., connection lost). The InvalidateSync retry
      // mechanism will handle retries, but we must notify the UI now so
      // it doesn't spin forever while waiting for awaitQueue(). When
      // retries exhaust, the Completer completes with error and the chat
      // screen's timeout will handle it.
      _notifySessionMessagesChanged(sessionId);
      _notifyDataChanged({SyncDomain.messages, SyncDomain.sessions});
      rethrow;
    } catch (error, stack) {
      fetchSpan.status = SpanStatus.internalError();
      fetchSpan.setData('error', error.toString());
      fetchSpan.setData('totalElapsedMs', fetchStopwatch.elapsedMilliseconds);
      unawaited(fetchSpan.finish());
      unawaited(
        Sentry.addBreadcrumb(
          Breadcrumb(
            message: 'fetchMessages: unexpected error',
            category: 'sync.messages',
            level: SentryLevel.error,
            data: {
              'sessionId': sessionId,
              'error': error.toString(),
              'elapsedMs': fetchStopwatch.elapsedMilliseconds,
            },
          ),
        ),
      );
      logger.error('Error fetching messages', error, stack);
      // Notify listeners so the UI can handle the error state rather than
      // remaining in a stale loading state.
      _notifySessionMessagesChanged(sessionId);
      _notifyDataChanged({SyncDomain.messages, SyncDomain.sessions});
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
    final incomingSig = content is Map ? content['c'] as String? : null;
    // If neither version has an encrypted blob, treat as unchanged
    // to avoid redundant decryption of plaintext messages.
    if (existingSig == null && incomingSig == null) return false;
    return incomingSig != existingSig;
  }

  /// Target number of messages to have loaded after a fresh first-open
  /// so the user doesn't land on a nearly-empty chat when the server's
  /// [Session.lastSeq] counts non-message events.
  static const int _initialBackfillTargetMessages = 40;

  /// Maximum number of extra older pages to fetch during the initial
  /// cross-device backfill. Bounded to avoid unbounded scroll-back on
  /// very sparse sessions.
  static const int _initialBackfillMaxPages = 3;

  /// After a first-load tail fetch, pull additional older pages if the
  /// visible message count is below [_initialBackfillTargetMessages]
  /// and older history is available. Best-effort and fire-and-forget.
  Future<void> _backfillInitialHistory(String sessionId) async {
    for (var i = 0; i < _initialBackfillMaxPages; i++) {
      final loaded = _sessionMessages[sessionId]?.length ?? 0;
      if (loaded >= _initialBackfillTargetMessages) return;
      if (!hasOlderMessages(sessionId)) return;
      if (isLoadingOlderMessages(sessionId)) return;
      try {
        await fetchOlderMessages(sessionId);
      } catch (error, stack) {
        logger.warning(
          '[backfillInitialHistory] $sessionId page=$i failed',
          error,
          stack,
        );
        return;
      }
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
    _notifyDataChanged({SyncDomain.messages});

    final transaction = Sentry.startTransaction(
      'chat.fetchOlderMessages',
      'sync.pagination',
      bindToScope: false,
    )..setData('sessionId', sessionId);

    try {
      const pageSize = 100;
      final startSeq = (firstLoaded - 1 - pageSize).clamp(0, firstLoaded - 1);

      final Response<dynamic> response;
      final httpSpan = transaction.startChild(
        'chat.fetchOlderMessages.http',
        description: 'Fetch older message page',
      );
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
          options: Options(
            extra: const {'bypassCache': true},
            receiveTimeout: const Duration(seconds: 15),
          ),
        );

        if (!apiClient.isSuccess(response)) {
          httpSpan.setData('statusCode', response.statusCode ?? 0);
          await httpSpan.finish(status: const SpanStatus.internalError());
          if (response.statusCode == 404) {
            logger.info(
              '[fetchOlderMessages] $sessionId returned 404 — '
              'cleaning up deleted session',
            );
            _cleanupDeletedSession(sessionId);
            await transaction.finish();
            return;
          }
          logger.warning(
            'Failed to fetch older messages: ${response.statusCode}',
          );
          await transaction.finish(status: const SpanStatus.internalError());
          return;
        }
      }
      httpSpan.setData('statusCode', response.statusCode ?? 0);
      await httpSpan.finish();

      final data = WireParsers.asMap(response.data);
      if (data == null) {
        logger.warning(
          '[fetchOlderMessages] $sessionId: response.data is '
          '${response.data.runtimeType}, expected Map',
        );
        await transaction.finish(status: const SpanStatus.internalError());
        return;
      }
      final messages = (data['messages'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      transaction.setData('fetchedMessages', messages.length);

      logger.debug(
        '[fetchOlderMessages] $sessionId '
        'msgs=${messages.length}',
      );

      final decryptStart = Stopwatch()..start();
      final processed = await sessionEncryption.decryptAndProcessMessages(
        messages,
        sessionId,
      );
      transaction
        ..setData('decryptMs', decryptStart.elapsedMilliseconds)
        ..setData('processedMessages', processed.messages.length)
        ..setData('toolResults', processed.toolResults.length)
        ..setData('usageUpdates', processed.usageUpdates.length);

      logger.debug(
        '[fetchOlderMessages] $sessionId '
        'processedMsgs=${processed.messages.length} '
        'toolResults=${processed.toolResults.length}',
      );
      if (processed.droppedReasons.isNotEmpty) {
        for (final reason in processed.droppedReasons) {
          logger.warning('[fetchOlderMessages] $sessionId dropped: $reason');
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
      // Apply any pending tool results that arrived before these
      // messages. Only drain matched results.
      final pending = _pendingToolResults[sessionId];
      if (pending != null && pending.isNotEmpty) {
        final matched = _applyToolResults(sessionId, pending);
        if (matched.isNotEmpty) {
          pending.removeWhere(
              (r) => matched.contains(r['toolUseId']));
          if (pending.isEmpty) {
            _pendingToolResults.remove(sessionId);
          }
        }
      }
      for (final u in processed.usageUpdates) {
        final usageMap = WireParsers.asMap(u['usage']);
        if (usageMap != null) {
          _updateSessionUsage(
            u['sessionId'] as String,
            usageMap,
            u['timestamp'] as int,
          );
        }
      }
      _groupSidechainMessages(sessionId);
      _applyPermissionRequests(sessionId);

      // Move the lower boundary back to cover the page we just fetched.
      _sessionFirstLoadedSeq[sessionId] = startSeq == 0 ? 0 : startSeq + 1;
      MMKVStorage().saveSessionFirstLoadedSeq(
        Map.unmodifiable(_sessionFirstLoadedSeq),
      );

      _notifySessionMessagesChanged(sessionId);
      _notifyDataChanged({SyncDomain.messages});
      await transaction.finish();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        logger.info(
          '[fetchOlderMessages] $sessionId returned 404 — '
          'cleaning up deleted session',
        );
        _cleanupDeletedSession(sessionId);
        await transaction.finish();
      } else {
        transaction
          ..setData('error', e.toString())
          ..setData('currentRoute', PerformanceContextService().currentRoute);
        await transaction.finish(status: const SpanStatus.internalError());
        _paginationErrorController.add(sessionId);
      }
    } catch (error, stack) {
      transaction
        ..setData('error', error.toString())
        ..setData('currentRoute', PerformanceContextService().currentRoute);
      await transaction.finish(status: const SpanStatus.internalError());
      logger.error('Error fetching older messages', error, stack);
      _paginationErrorController.add(sessionId);
    } finally {
      _loadingOlderMessages.remove(sessionId);
      _notifyDataChanged({SyncDomain.messages});
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

  /// Clean up all local state for a session that was deleted on the server.
  void _cleanupDeletedSession(String sessionId) {
    messagesSync.remove(sessionId)?.dispose();
    _postSendCatchUpTimers.remove(sessionId)?.cancel();
    _loadingOlderMessages.remove(sessionId);
    _sessionMessages.remove(sessionId);
    _invalidatePreviewCache(sessionId);
    _sessionContentSignatures.remove(sessionId);
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
    _sessionsNeedingVisibleRegroup.remove(sessionId);
    _sessionsWithPendingUpdates.remove(sessionId);
    _sessionsWithPendingSocketMessages.remove(sessionId);
    _sessionsNeedingFetchProbe.remove(sessionId);
    _sessionSpawnedAt.remove(sessionId);
    _sessionSpawnedProfile.remove(sessionId);
    _autoRestoreInFlight.remove(sessionId);
    _pendingToolResults.remove(sessionId);
    if (isInitialized) {
      _sessionLastSeq.remove(sessionId);
      MMKVStorage().saveSessionLastSeq(Map.unmodifiable(_sessionLastSeq));
      _sessionFirstLoadedSeq.remove(sessionId);
      MMKVStorage().saveSessionFirstLoadedSeq(
        Map.unmodifiable(_sessionFirstLoadedSeq),
      );
      _saveMsgsDebounceTimers.remove(sessionId)?.cancel();
      MessageCacheService().clearMessages(sessionId);
      encryption.removeSessionEncryption(sessionId);
    }
    _scheduleSessionsRefresh();
    _notifyDataChanged({SyncDomain.messages, SyncDomain.sessions});
  }
}
