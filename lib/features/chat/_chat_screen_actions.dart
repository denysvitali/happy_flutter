// NOTE: _chat_screen_actions.dart is a `part` file because Dart's
// library-private (`_`) visibility is required for _ChatScreenState's
// private member access. Converting to a regular import would require
// making those members public, which violates the project's preference
// for minimal public APIs. LSP tools may not resolve definitions across
// part boundaries.
// ignore_for_file: invalid_use_of_protected_member
part of 'chat_screen.dart';

extension _ChatScreenActions on _ChatScreenState {
  /// Batches three async storage reads into a single setState call
  /// to avoid 3 separate rebuilds on screen open.
  Future<void> _loadInitialSettings() async {
    final storage = DraftStorage();
    final sessionId = widget.sessionId;

    final results = await Future.wait([
      storage.getPermissionMode(sessionId),
      storage.getModelMode(sessionId),
      storage.getProfileId(sessionId),
    ]);

    if (!mounted) return;

    final savedPermMode = results[0];
    final savedModelMode = results[1];
    final savedProfileId = results[2];

    final session = sync.sessions[sessionId];
    final flavor = session?.metadata?.flavor;
    final settings = ref.read(settingsNotifierProvider);

    final resolution = resolveModelSelection(
      savedPermissionMode: savedPermMode,
      savedModelMode: savedModelMode,
      savedProfileId: savedProfileId,
      sessionModelMode: session?.modelMode,
      sessionPermissionMode: session?.permissionMode,
      flavor: flavor,
      settingsProfiles: settings.profiles,
      builtInProfiles: builtInProfiles,
      lastUsedModelMode: settings.lastUsedModelMode,
    );

    // Test-only hook (see `testInitialSettingsApplyBarrier` doc comment):
    // lets widget tests pause here, after the DraftStorage reads resolved
    // but before this resolution is persisted/applied, to deterministically
    // race an interactive picker change against this async restore.
    if (ChatScreen.testInitialSettingsApplyBarrier case final barrier?) {
      await barrier();
      if (!mounted) return;
    }

    // Guard: only persist/apply permission mode / model / profile if the
    // user hasn't already interacted with one of the pickers before this
    // async load completed. _userOverrodeModelOrProfile starts false and is
    // set by _onPermissionModeChanged / _onModelModeChanged /
    // _onProfileChanged. Once true, this resolution is stale — applying any
    // of its fields (including permission mode) to UI state *or* storage
    // would silently discard an interactive pick.
    if (_userOverrodeModelOrProfile) {
      setState(() => _availableProfiles = resolution.availableProfiles);
      return;
    }

    if (resolution.shouldPersistPermissionMode) {
      unawaited(
        storage.savePermissionMode(
          sessionId,
          resolution.resolvedPermissionMode.toModeString(),
        ),
      );
    }
    if (resolution.hadGhostProfileReference) {
      logger.info(
        '[ChatScreen] saved profile "$savedProfileId" no longer '
        'exists in settings; falling back to no profile',
      );
      unawaited(storage.removeProfileId(sessionId));
    }

    setState(() {
      _permissionMode = resolution.resolvedPermissionMode;
      _modelMode = resolution.resolvedModelMode;
      _profileModelOverride = resolution.resolvedRawModelString;
      _selectedProfile = resolution.resolvedProfile;
      _availableProfiles = resolution.availableProfiles;
    });
  }

  Future<void> _doInitialLoad() async {
    if (_didStartInitialLoad) return;
    _didStartInitialLoad = true;
    final sessionId = widget.sessionId;
    final stopwatch = Stopwatch()..start();
    final initialMessageCount = _messages.length;
    var success = true;

    final transaction = Sentry.startTransaction(
      'chat.screen.load',
      'ui.load',
      bindToScope: true,
    )..setData('sessionId', sessionId);
    final otelTrace = OpenTelemetryService().startTrace(
      'chat.screen.load',
      attributes: {'session.id': sessionId},
    );

    // Safety timer: if loading is still in progress after 15s,
    // force-clear the spinner and report to Sentry.
    _loadingSafetyTimer?.cancel();
    _loadingSafetyTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted || !_isLoadingMessages) return;
      logger.warning(
        '[ChatScreen] Safety timeout: loading stuck '
        'for 15s session=$sessionId '
        'messages=${_messages.length}',
      );
      unawaited(
        Sentry.captureMessage(
          'ChatScreen loading stuck for 15s',
          level: SentryLevel.warning,
          params: [sessionId],
          hint: Hint.withMap({
            'sessionId': sessionId,
            'messageCount': _messages.length.toString(),
            'initialLoadComplete': _initialLoadComplete.toString(),
            'syncInitialized': sync.isInitialized.toString(),
            'hasMsgSync': (sync.messagesSync[sessionId] != null).toString(),
            'syncMessages': sync
                .messagesForSession(sessionId)
                .length
                .toString(),
            'elapsedMs': stopwatch.elapsedMilliseconds,
          }),
        ),
      );
      // Finish the transaction as failed
      transaction.setData('timeout', true);
      unawaited(transaction.finish());
      otelTrace
        ?..setAttribute('timeout', true)
        ..end(ok: false);
      setState(() {
        _isLoadingMessages = false;
        _initialLoadComplete = true;
        if (_messages.isEmpty) _loadFailed = true;
      });
    });

    try {
      final cacheSpan = transaction.startChild(
        'chat.cache.check',
        description: 'Check cached messages',
      );
      unawaited(
        (cacheSpan..setData('cachedCount', initialMessageCount)).finish(),
      );
      OpenTelemetryService()
          .startChildSpan(
            'chat.cache.check',
            parent: otelTrace,
            attributes: {'message.cached_count': initialMessageCount},
          )
          ?.end();

      unawaited(
        Sentry.addBreadcrumb(
          Breadcrumb(
            message: 'ChatScreen._doInitialLoad started',
            category: 'chat.load',
            data: {
              'sessionId': sessionId,
              'hasCachedMessages': _messages.isNotEmpty,
              'syncInitialized': sync.isInitialized,
            },
          ),
        ),
      );

      // Span for onSessionVisible
      final visibleSpan = transaction.startChild(
        'chat.sync.visible',
        description: 'Mark session as visible',
      );
      final otelVisibleSpan = OpenTelemetryService().startChildSpan(
        'chat.sync.visible',
        parent: otelTrace,
        attributes: {'session.id': sessionId},
      );
      unawaited(sync.onSessionVisible(sessionId));
      // Suppress the live "session activity" notification while the
      // user is looking at the session in-app.
      unawaited(sessionActivityCoordinator.setVisibleSession(sessionId));
      unawaited(visibleSpan.finish());
      otelVisibleSpan?.end();

      // Show cached messages immediately instead of
      // waiting for the debounced stream notification
      // (100ms). onSessionVisible() starts the cache restore path
      // immediately so sync can publish cached messages before the
      // network catch-up finishes.
      final refreshSpan = transaction.startChild(
        'chat.sync.refresh',
        description: 'Refresh from sync singleton',
      );
      final otelRefreshSpan = OpenTelemetryService().startChildSpan(
        'chat.sync.refresh',
        parent: otelTrace,
      );
      // If we have cached messages, clear the loading spinner
      // immediately so users see content instead of waiting up
      // to 5s for the sync queue to drain (warm start fix).
      final syncCachedCount = sync.messagesForSession(sessionId).length;
      final hasCached = _messages.isNotEmpty || syncCachedCount > 0;
      _refreshFromSync(markLoaded: hasCached);
      final firstPaintCount = _messages.length;
      refreshSpan
        ..setData('syncCachedCount', syncCachedCount)
        ..setData('firstPaintCount', firstPaintCount);
      unawaited(refreshSpan.finish());
      otelRefreshSpan
        ?..setAttribute('has_cached_messages', hasCached)
        ..setAttribute('message.sync_cached_count', syncCachedCount)
        ..setAttribute('message.first_paint_count', firstPaintCount)
        ..end();

      // Span for the message sync queue. When the cache is hot we
      // fire-and-forget so the transaction reflects what the user
      // actually perceived (cached content already on screen),
      // letting the background refresh continue via the data-change
      // stream. When there's no cache, we still need to await so
      // the spinner clears on real content rather than vanishing
      // into an empty list.
      final awaitSpan = transaction.startChild(
        'chat.sync.await',
        description: 'Await message sync queue',
      )..setData('hasCached', hasCached);
      final otelAwaitSpan = OpenTelemetryService().startChildSpan(
        'chat.sync.await',
        parent: otelTrace,
        attributes: {'has_cached_messages': hasCached},
      );
      final queueFuture = sync.messagesSync[sessionId]?.awaitQueue();
      // Cap background await at 8s so network-change stalls (Cronet
      // ERR_NETWORK_CHANGED) fail fast instead of blocking for 30s.
      // The per-page fetch already uses 8s connect+receive timeouts;
      // aligning the UI await prevents the 15s+ stalls seen in
      // trace 9554856ddcc15b9250663f04e65daa61.
      const backgroundTimeout = Duration(seconds: 8);
      if (hasCached) {
        awaitSpan.setData('mode', 'background');
        otelAwaitSpan?.setAttribute('mode', 'background');
        if (queueFuture != null) {
          unawaited(
            queueFuture
                .timeout(backgroundTimeout)
                .catchError((Object e, StackTrace st) {
                  // Real refresh fail — surface as a breadcrumb but
                  // don't fail the transaction; the user already sees
                  // cached data. Use a long timeout for background
                  // catch-up so large message gaps (cursor << serverSeq)
                  // don't falsely trip this path.
                  logger.warning(
                    '[ChatScreen] background messagesSync awaitQueue failed '
                    'session=$sessionId',
                    e,
                    st,
                  );
                  otelAwaitSpan?.recordError(e, st);
                  return;
                })
                .whenComplete(() {
                  final postRefreshCount = sync
                      .messagesForSession(sessionId)
                      .length;
                  awaitSpan.setData('postRefreshCount', postRefreshCount);
                  otelAwaitSpan?.setAttribute(
                    'message.post_refresh_count',
                    postRefreshCount,
                  );
                  unawaited(awaitSpan.finish());
                  otelAwaitSpan?.end();
                }),
          );
        } else {
          unawaited(awaitSpan.finish());
          otelAwaitSpan?.end();
        }
      } else {
        awaitSpan.setData('mode', 'blocking');
        otelAwaitSpan?.setAttribute('mode', 'blocking');
        try {
          await queueFuture?.timeout(const Duration(seconds: 5));
          awaitSpan.setData('timedOut', false);
          otelAwaitSpan?.setAttribute('timed_out', false);
        } catch (e) {
          success = false;
          awaitSpan
            ..setData('timedOut', true)
            ..setData('error', e.toString());
          otelAwaitSpan
            ?..setAttribute('timed_out', true)
            ..recordError(e);
        }
        unawaited(awaitSpan.finish());
        otelAwaitSpan?.end(ok: success);
      }
    } catch (error, stack) {
      success = false;
      logger.error(
        '[ChatScreen] _doInitialLoad error '
        'session=$sessionId',
        error,
        stack,
      );
      transaction.setData('error', error.toString());
      otelTrace?.recordError(error, stack);
      unawaited(
        Sentry.captureException(
          error,
          stackTrace: stack,
          hint: Hint.withMap({
            'context': 'ChatScreen._doInitialLoad',
            'sessionId': sessionId,
          }),
        ),
      );
    } finally {
      _loadingSafetyTimer?.cancel();
      _loadingSafetyTimer = null;
    }

    if (!mounted) {
      await transaction.finish();
      otelTrace?.end(ok: success);
      return;
    }

    unawaited(
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'ChatScreen._doInitialLoad completed',
          category: 'chat.load',
          data: {
            'sessionId': sessionId,
            'success': success,
            'elapsedMs': stopwatch.elapsedMilliseconds,
            'messageCount': _messages.length,
            'syncMessages': sync.messagesForSession(sessionId).length,
          },
        ),
      ),
    );

    _refreshFromSync(
      markLoaded: true,
      loadFailed: !success && _messages.isEmpty,
    );

    // Finish the transaction
    transaction
      ..setData('initialMessageCount', initialMessageCount)
      ..setData('finalMessageCount', _messages.length)
      ..setData('elapsedMs', stopwatch.elapsedMilliseconds);
    otelTrace
      ?..setAttribute('success', success)
      ..setAttribute('message.initial_count', initialMessageCount)
      ..setAttribute('message.final_count', _messages.length)
      ..setAttribute('chat.load_elapsed_ms', stopwatch.elapsedMilliseconds)
      ..end(ok: success);
    await transaction.finish();
  }

  Future<void> _retry() async {
    if (!mounted) return;
    _loadingSafetyTimer?.cancel();
    setState(() {
      _loadFailed = false;
      _isLoadingMessages = true;
      _didStartInitialLoad = false;
    });
    await _doInitialLoad();
  }

  void _onPermissionModeChanged(PermissionMode mode) {
    setState(() {
      _userOverrodeModelOrProfile = true;
      _permissionMode = mode;
    });
    ref
        .read(chatActionNotifierProvider.notifier)
        .savePermissionMode(widget.sessionId, mode.toModeString());
  }

  void _onModelModeChanged(ChatModelMode model) {
    final normalized = ChatModelMode.normalizeForFlavor(
      model,
      _session?.metadata?.flavor,
    );
    setState(() {
      _userOverrodeModelOrProfile = true;
      _modelMode = normalized;
      _profileModelOverride = normalized.modeString;
    });
    ref
        .read(chatActionNotifierProvider.notifier)
        .saveSelection(
          widget.sessionId,
          profileId: _selectedProfile?.id,
          modelMode: normalized.modeString,
        );

    // The next sendMessage call will automatically detect the model
    // change and kill+respawn the session with the new model.
    // No manual restart required.
    final isRunning = _session?.isPresenceOnline ?? false;
    if (isRunning && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Model changed. The session will restart '
            'automatically on the next message.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _refreshCodexModelModes(Session? session) async {
    if (session?.metadata?.flavor != 'codex') return;
    final machineId = session?.metadata?.machineId;
    if (machineId == null || machineId.isEmpty) return;
    if (_codexModelModesMachineId == machineId && _codexModelModes.length > 1) {
      return;
    }
    if (_isLoadingCodexModelModes) return;
    if (!sync.isEncryptionInitialized) return;

    _isLoadingCodexModelModes = true;
    try {
      final response = await ref
          .read(chatActionNotifierProvider.notifier)
          .loadCodexModels(machineId);
      if (!mounted || !response.success || response.models.isEmpty) return;
      final modes = ChatModelMode.fromCodexCatalog(response.models);
      setState(() {
        _codexModelModes = modes;
        _codexModelModesMachineId = machineId;
      });
    } catch (e) {
      // Encryption not initialized (syncRestore hasn't run yet) or
      // RPC transient failure.  Either way, fall back to the default
      // model list rather than crashing the screen.  The next
      // applyUpdates / onSessionVisible cycle can retry once sync
      // is ready.
      logger.warning('_refreshCodexModelModes: skipping - $e');
    } finally {
      _isLoadingCodexModelModes = false;
    }
  }

  void _onProfileChanged(AIBackendProfile? profile) {
    // Use the profile's default model mode when switching providers.
    // If no profile is selected, fall back to the server default mode.
    final profileDefaultModelMode = profile?.defaultModelMode;
    final rawModelString = profileDefaultModelMode != null
        ? ChatModelMode.normalizeRawForFlavor(
            profileDefaultModelMode,
            _session?.metadata?.flavor,
            preserveProviderOwned: profileOwnsRawCodexModel(profile),
          )
        : ChatModelMode.defaultModel.modeString;
    final newModel = profileDefaultModelMode != null
        ? ChatModelMode.normalizeForFlavor(
            ChatModelMode.fromString(rawModelString),
            _session?.metadata?.flavor,
          )
        : ChatModelMode.defaultModel;

    // Apply the profile's default permission mode (consistent with
    // how NewSessionScreen applies it on session creation).
    final profilePermMode = profile?.defaultPermissionMode;
    final newPermissionMode = profilePermMode != null
        ? (PermissionModeExtension.fromString(profilePermMode) ??
              _permissionMode)
        : _permissionMode;

    setState(() {
      _userOverrodeModelOrProfile = true;
      _selectedProfile = profile;
      _modelMode = newModel;
      _profileModelOverride = rawModelString;
      _permissionMode = newPermissionMode;
    });
    // Save the profile's defaultModelMode, not 'default'. Profile, model,
    // and (when the profile defines one) permission mode are written
    // atomically so the pairing can never desync.
    ref
        .read(chatActionNotifierProvider.notifier)
        .saveSelection(
          widget.sessionId,
          profileId: profile?.id,
          modelMode: rawModelString,
          permissionMode: profilePermMode != null
              ? newPermissionMode.toModeString()
              : null,
        );

    // The next sendMessage call will automatically detect the profile
    // mismatch and kill+respawn the session with the new env vars.
    // No manual restart required.
    final isRunning = _session?.isPresenceOnline ?? false;
    if (isRunning && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile changed. The session will restart '
            'automatically on the next message.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  static const _abortReason =
      "The user doesn't want to proceed with this tool "
      'use. The tool use was rejected (eg. if it was a '
      'file edit, the new_string was NOT written to the '
      'file). STOP what you are doing and wait for the '
      'user to tell you how to proceed.';

  Future<void> _abortSession() async {
    if (_isAborting) return;
    setState(() => _isAborting = true);
    try {
      await ref
          .read(chatActionNotifierProvider.notifier)
          .abortSession(widget.sessionId, reason: _abortReason);
    } catch (e, st) {
      if (mounted) {
        logger.warning(
          '[ChatScreen] _abortSession failed: '
          'sessionId=${widget.sessionId} $e',
          e,
          st,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Stop request failed. The agent may still be running.',
            ),
            action: SnackBarAction(label: 'Retry', onPressed: _abortSession),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAborting = false);
    }
  }

  void _onSuggestionTap(String suggestion) {
    _controller.text = suggestion;
    _controller.selection = TextSelection.collapsed(offset: suggestion.length);
  }

  Future<void> _onOptionPress(String option) async {
    if (_isSending) return;
    final sendIssue = _sessionSendIssue;
    if (sendIssue != null && sendIssue.blocksSend) {
      _showSendBlockedSnackBar(sendIssue);
      return;
    }
    try {
      final sentSessionId = await ref
          .read(chatActionNotifierProvider.notifier)
          .sendMessage(
            widget.sessionId,
            option,
            displayText: option,
            permissionMode: _permissionMode.toModeString(),
            modelMode: _effectiveModelModeString ?? _modelMode.modeString,
            profileId: _selectedProfile?.id,
          );
      if (_followRedirectedSession(sentSessionId)) {
        return;
      }
      _refreshFromSync();
    } catch (e, st) {
      logger.warning(
        '[ChatScreen] _onOptionPress failed: '
        'sessionId=${widget.sessionId} $e',
        e,
        st,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.l10n.chatFailedToSend}: $e')),
        );
      }
    }
  }

  Future<void> _retryMessage(Map<String, dynamic> message) async {
    final localId = message['localId'] as String? ?? message['id'] as String?;
    if (localId == null) return;

    try {
      await ref
          .read(chatActionNotifierProvider.notifier)
          .retryFailedMessage(widget.sessionId, localId);
    } catch (e, st) {
      logger.warning(
        '[ChatScreen] _retryMessage failed: '
        'sessionId=${widget.sessionId} localId=$localId $e',
        e,
        st,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to retry message: $e')));
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    final sendIssue = _sessionSendIssue;
    if (sendIssue != null && sendIssue.blocksSend) {
      _showSendBlockedSnackBar(sendIssue);
      return;
    }
    final localId = ref
        .read(chatActionNotifierProvider.notifier)
        .createLocalMessageId();

    unawaited(TtsService().stop());

    if (isClearCommand(text)) {
      _controller.clear();
      unawaited(DraftStorage().removeDraft(widget.sessionId));
      _autoScrollNotifier.value = true;
      setState(() {
        _isSending = true;
        _visibleCount = _initialVisibleCount(_messages.length);
      });
      try {
        final sentSessionId = await ref
            .read(chatActionNotifierProvider.notifier)
            .sendMessage(
              widget.sessionId,
              text,
              permissionMode: _permissionMode.toModeString(),
              modelMode: _effectiveModelModeString ?? _modelMode.modeString,
              profileId: _selectedProfile?.id,
            );
        if (_followRedirectedSession(sentSessionId)) {
          return;
        }
        _refreshFromSync();
        _scrollToBottom();
      } catch (e, st) {
        logger.warning(
          '[ChatScreen] _sendMessage /clear failed: '
          'sessionId=${widget.sessionId} $e',
          e,
          st,
        );
        if (mounted) {
          setState(() {
            _controller.text = text;
            _isSending = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.chatFailedToClear(e.toString())),
            ),
          );
        }
      } finally {
        if (mounted && _isSending) {
          setState(() => _isSending = false);
        }
      }
      return;
    }

    if (isLoopCommand(text)) {
      unawaited(_handleLoopCommand(text));
      return;
    }

    await _sendOptimisticUserText(text, localId: localId);
  }

  /// Shared optimistic send path for typed messages and loop fall-through.
  ///
  /// [localId] is the canonical client identity — never re-minted here.
  Future<void> _sendOptimisticUserText(
    String text, {
    required String localId,
  }) async {
    final optimisticStopwatch = Stopwatch()..start();
    _autoScrollNotifier.value = true;

    final optimisticMessage = buildOptimisticUserMessage(
      localId: localId,
      text: text,
    );
    setState(() {
      _messages = [..._messages, optimisticMessage];
      _isSending = true;
      _controller.clear();
      _visibleCount = _messages.length;
      _invalidateNeighborCache();
    });
    optimisticStopwatch.stop();
    OpenTelemetryService().recordDuration(
      'app.chat.optimistic_row',
      optimisticStopwatch.elapsed,
      attributes: {'source': 'composer'},
      description: 'Chat action to optimistic-row state update',
    );
    _scrollToBottom();

    unawaited(DraftStorage().removeDraft(widget.sessionId));

    try {
      final sentSessionId = await ref
          .read(chatActionNotifierProvider.notifier)
          .sendMessage(
            widget.sessionId,
            text,
            clientLocalId: localId,
            displayText: text,
            permissionMode: _permissionMode.toModeString(),
            modelMode: _effectiveModelModeString ?? _modelMode.modeString,
            profileId: _selectedProfile?.id,
          );
      if (_followRedirectedSession(sentSessionId)) {
        return;
      }
      // Optimistic message will be replaced by real message via WebSocket
      _refreshFromSync();
    } catch (e, st) {
      logger.warning(
        '[ChatScreen] _sendMessage failed: '
        'sessionId=${widget.sessionId} $e',
        e,
        st,
      );
      if (mounted) {
        // Mark optimistic message as failed instead of removing it,
        // so the user can see it and retry.
        setState(() {
          final next = markOptimisticMessageFailed(_messages, localId);
          if (identical(next, _messages)) {
            final msg =
                'chat_send: optimistic message not found for '
                'localId=$localId (session=${widget.sessionId})';
            logger.warning(msg);
            unawaited(Sentry.captureMessage(msg, level: SentryLevel.warning));
          }
          _messages = next;
          _controller.text = text;
          _isSending = false;
          _invalidateNeighborCache();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.l10n.chatFailedToSend}: $e')),
        );
      }
    } finally {
      if (mounted && _isSending) {
        setState(() => _isSending = false);
      }
    }
  }

  // ─── TTS playback navigation ───────────────────────────────────────────────

  /// Returns the agent text messages currently in the chat buffer
  /// that the TTS engine could speak, in chronological order.
  List<Map<String, dynamic>> _ttsSpeakableMessages() {
    return _messages
        .where((m) {
          if ((m['role'] as String? ?? '') != 'agent') return false;
          if ((m['kind'] as String?) != 'text') return false;
          if (m['isThinking'] == true) return false;
          final text = (m['content'] ?? m['text'] ?? '').toString();
          return text.isNotEmpty;
        })
        .toList(growable: false);
  }

  int _ttsCurrentIndex(List<Map<String, dynamic>> speakable) {
    final id = TtsService().currentToken.value;
    if (id == null) return -1;
    return speakable.indexWhere((m) => m['id']?.toString() == id);
  }

  bool _ttsCanGoPrev() {
    final speakable = _ttsSpeakableMessages();
    if (speakable.isEmpty) return false;
    final idx = _ttsCurrentIndex(speakable);
    // -1 (engine idle) → can jump to the latest. >0 → can step back.
    return idx == -1 ? speakable.length > 1 : idx > 0;
  }

  bool _ttsCanGoNext() {
    final speakable = _ttsSpeakableMessages();
    if (speakable.isEmpty) return false;
    final idx = _ttsCurrentIndex(speakable);
    return idx >= 0 && idx < speakable.length - 1;
  }

  void _ttsPrev() {
    final speakable = _ttsSpeakableMessages();
    if (speakable.isEmpty) return;
    final idx = _ttsCurrentIndex(speakable);
    final target = idx == -1 ? speakable.length - 2 : idx - 1;
    if (target < 0 || target >= speakable.length) return;
    _ttsSpeakAt(speakable[target]);
  }

  void _ttsNext() {
    final speakable = _ttsSpeakableMessages();
    if (speakable.isEmpty) return;
    final idx = _ttsCurrentIndex(speakable);
    if (idx == -1 || idx >= speakable.length - 1) return;
    _ttsSpeakAt(speakable[idx + 1]);
  }

  void _ttsStop() {
    unawaited(TtsService().stop());
  }

  void _ttsSpeakAt(Map<String, dynamic> message) {
    final id = message['id']?.toString();
    final text = (message['content'] ?? message['text'] ?? '').toString();
    if (text.isEmpty) return;
    // Keep the live gate in sync so the next streamed reply doesn't
    // get treated as a duplicate of whatever was last spoken.
    _ttsGate.recordSpoken(id);
    final settings = ref.read(settingsNotifierProvider);
    unawaited(
      TtsService().speak(
        text,
        token: id,
        useOffline: settings.ttsUseOffline,
        offlineVoiceId: settings.ttsVoiceId,
      ),
    );
  }

  bool _followRedirectedSession(String sentSessionId) {
    if (!mounted || sentSessionId == widget.sessionId) {
      return false;
    }
    // Migrate the current profile/permission/model config to the new
    // session so the redirected ChatScreen inherits the user's choices
    // instead of starting from defaults.
    final storage = DraftStorage();
    final profileId = _selectedProfile?.id;
    if (profileId != null) {
      unawaited(storage.saveProfileId(sentSessionId, profileId));
    } else {
      unawaited(storage.removeProfileId(sentSessionId));
    }
    unawaited(
      storage.savePermissionMode(sentSessionId, _permissionMode.toModeString()),
    );
    final modelStr = _effectiveModelModeString ?? _modelMode.modeString;
    unawaited(storage.saveModelMode(sentSessionId, modelStr));

    context.goNamed('chat', pathParameters: {'sessionId': sentSessionId});
    return true;
  }

  // ─── /loop slash-command interception ─────────────────────────────────

  /// Handle `/loop ...` text typed in the chat input.
  ///
  /// Three cases:
  ///   * `/loop list` → open the Loops screen for this session.
  ///   * `/loop cancel <id>` → RPC delete the loop, snackbar result.
  ///   * `/loop <interval> <prompt>` → open [CreateLoopSheet] pre-filled,
  ///     then RPC create. Falls through to Claude as a regular message
  ///     when the text doesn't match a known shape.
  Future<void> _handleLoopCommand(String text) async {
    final l10n = context.l10n;
    final sessionId = widget.sessionId;
    final lower = text.trim().toLowerCase();
    final body = lower.substring('/loop '.length).trim();

    // `/loop list` → open the loops screen.
    if (body == 'list') {
      unawaited(DraftStorage().removeDraft(sessionId));
      _controller.clear();
      unawaited(
        context.pushNamed(
          'chat-loops',
          pathParameters: {'sessionId': sessionId},
        ),
      );
      return;
    }

    // `/loop cancel <id>` → delete the loop.
    final cancelId = LoopCommandParser.parseCancelCommand(text);
    if (cancelId != null) {
      unawaited(DraftStorage().removeDraft(sessionId));
      _controller.clear();
      await deleteLoopWithFeedback(
        ref: ref,
        messenger: ScaffoldMessenger.of(context),
        isMounted: () => mounted,
        failureLogMessage: '[ChatScreen] /loop cancel failed',
        failureLabel: l10n.loopsLoopCancelFailed,
        successLabel: l10n.loopsLoopCancelled(cancelId),
        shouldHandleError: (error) => error is StateError,
        sessionId: sessionId,
        loopId: cancelId,
      );
      return;
    }

    // `/loop <interval> <prompt>` → open the create sheet.
    final request = LoopCommandParser.parse(text);
    if (request == null) {
      // Not a recognized loop shape — pass through to Claude unchanged.
      await _sendRawLoopText(text);
      return;
    }

    unawaited(DraftStorage().removeDraft(sessionId));
    _controller.clear();
    if (!mounted) return;
    final created = await showModalBottomSheet<Loop>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => CreateLoopSheet(
        sessionId: sessionId,
        initialExpression: request.expression,
        initialPrompt: request.prompt,
        initialRecurring: request.recurring,
      ),
    );
    if (created != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.loopsLoopScheduled(created.id))),
      );
    }
  }

  /// Send [text] as a regular user message (loop fall-through).
  ///
  /// Uses the same optimistic path and `localId` rules as [_sendMessage].
  Future<void> _sendRawLoopText(String text) async {
    final localId = ref
        .read(chatActionNotifierProvider.notifier)
        .createLocalMessageId();
    unawaited(TtsService().stop());
    await _sendOptimisticUserText(text, localId: localId);
  }

  /// Handle an [AutoRestoreFailure] emitted by the sync layer when
  /// `_resolveSendTargetSession`'s catch-all branch fired.  Flips the
  /// most recent in-flight optimistic message for the current session
  /// to `sendStatus: 'failed'` (preserving `localId` for retry) and
  /// surfaces a snackbar with `chatFailedToSend`.
  ///
  /// ROADMAP P0: previously the catch-all branch POSTed to a broken
  /// session and the failure vanished — the optimistic row kept
  /// showing `'sending'` forever and the user had no recourse.
  void _handleAutoRestoreFailure(AutoRestoreFailure failure) {
    if (!mounted) return;
    if (failure.sessionId != widget.sessionId) return;

    // Flip the most recent optimistic user message to 'failed' so
    // the user can retry with the same `localId`.  Walk backwards
    // because the optimistic insert always appends.
    String? failedLocalId;
    setState(() {
      for (var i = _messages.length - 1; i >= 0; i--) {
        final m = _messages[i];
        if ((m['role'] as String? ?? '') != 'user') continue;
        final status = m['sendStatus'] as String? ?? '';
        if (status != 'sending' && status != 'pending') continue;
        _messages = [
          ..._messages.sublist(0, i),
          {...m, 'sendStatus': 'failed'},
          ..._messages.sublist(i + 1),
        ];
        failedLocalId = m['localId'] as String?;
        break;
      }
      _isSending = false;
      _invalidateNeighborCache();
    });

    if (failedLocalId != null) {
      logger.info(
        '[ChatScreen] auto-restore failed; optimistic row marked failed '
        'localId=$failedLocalId session=${widget.sessionId} '
        'reason=${failure.reason}',
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.chatFailedToSend),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
