// ignore_for_file: invalid_use_of_protected_member
part of 'chat_screen.dart';

extension _ChatScreenActions on _ChatScreenState {
  /// Batches three async storage reads into a single setState call
  /// to avoid 3 separate rebuilds on screen open.
  Future<void> _loadInitialSettings() async {
    final storage = DraftStorage();
    final sessionId = widget.sessionId;

    // Fire all three reads in parallel.
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

    // Permission mode.
    var permissionMode = PermissionMode.defaultMode;
    if (savedPermMode != null) {
      permissionMode =
          PermissionModeExtension.fromString(savedPermMode) ??
          PermissionMode.defaultMode;
    } else if (session?.permissionMode != null) {
      permissionMode =
          PermissionModeExtension.fromString(session!.permissionMode!) ??
          PermissionMode.defaultMode;
      unawaited(
        storage.savePermissionMode(
          sessionId,
          permissionMode.toModeString(),
        ),
      );
    }

    // Profile & settings (read once, used below for both model and profile).
    final settings = ref.read(settingsNotifierProvider);

    // First, determine the selected profile so we can use its
    // defaultModelMode.
    // Profile.
    final seen = <String>{};
    final deduped = <AIBackendProfile>[];
    for (final p in [...settings.profiles, ...builtInProfiles]) {
      if (seen.add(p.id)) deduped.add(p);
    }

    AIBackendProfile? selectedProfile;
    final effectiveProfileId = savedProfileId ?? settings.lastUsedProfile;
    if (effectiveProfileId != null) {
      try {
        selectedProfile =
            deduped.firstWhere((p) => p.id == effectiveProfileId);
      } catch (_) {
        selectedProfile = null;
        logger.warning(
          '[ChatScreen] saved profile "$effectiveProfileId" no longer '
          'exists in settings; falling back to no profile',
        );
      }
    }

    // Model mode.
    final flavor = session?.metadata?.flavor;
    String? rawModelModeString;
    var modelMode = ClaudeModel.defaultModel;

    // Priority: saved draft > session model > profile default
    // > settings default
    if (savedModelMode != null) {
      rawModelModeString = savedModelMode;
      modelMode = ClaudeModel.normalizeForFlavor(
        ClaudeModel.fromString(savedModelMode),
        flavor,
      );
    } else if (session?.modelMode != null) {
      rawModelModeString = session!.modelMode;
      modelMode = ClaudeModel.normalizeForFlavor(
        ClaudeModel.fromString(session.modelMode),
        flavor,
      );
    } else if (selectedProfile?.defaultModelMode != null) {
      // Use the profile's default model mode
      rawModelModeString = selectedProfile!.defaultModelMode;
      modelMode = ClaudeModel.normalizeForFlavor(
        ClaudeModel.fromString(selectedProfile.defaultModelMode),
        flavor,
      );
    } else if (settings.lastUsedModelMode != null) {
      // Fall back to the user's last-used model preference so new sessions
      // inherit the model the user most recently picked.
      rawModelModeString = settings.lastUsedModelMode;
      modelMode = ClaudeModel.normalizeForFlavor(
        ClaudeModel.fromString(settings.lastUsedModelMode),
        flavor,
      );
    }

    setState(() {
      _permissionMode = permissionMode;
      // Guard: only apply model/profile if the user hasn't already interacted
      // with the model or profile pickers before this async load completed.
      // _rawModelModeString starts null; once the user picks a model via
      // _onModelModeChanged or a profile via _onProfileChanged, it becomes
      // non-null. We must not overwrite their choice here.
      if (_rawModelModeString == null) {
        _modelMode = modelMode;
        _rawModelModeString = rawModelModeString;
      }
      _availableProfiles = deduped;
      _selectedProfile ??= selectedProfile;
    });
  }

  Future<void> _doInitialLoad() async {
    if (_didStartInitialLoad) return;
    _didStartInitialLoad = true;
    final sessionId = widget.sessionId;
    final stopwatch = Stopwatch()..start();
    var success = true;

    // Start a Sentry transaction for the entire chat loading flow
    final transaction = Sentry.startTransaction(
      'chat.screen.load',
      'ui.load',
      bindToScope: true,
    )..setData('sessionId', sessionId);

    // Safety timer: if loading is still in progress after 15s,
    // force-clear the spinner and report to Sentry.
    _loadingSafetyTimer?.cancel();
    _loadingSafetyTimer = Timer(
      const Duration(seconds: 15),
      () {
        if (!mounted || !_isLoadingMessages) return;
        logger.warning(
          '[ChatScreen] Safety timeout: loading stuck '
          'for 15s session=$sessionId '
          'messages=${_messages.length}',
        );
        unawaited(Sentry.captureMessage(
          'ChatScreen loading stuck for 15s',
          level: SentryLevel.warning,
          params: [sessionId],
          hint: Hint.withMap({
            'sessionId': sessionId,
            'messageCount': _messages.length.toString(),
            'initialLoadComplete': _initialLoadComplete.toString(),
            'syncInitialized': sync.isInitialized.toString(),
            'hasMsgSync':
                (sync.messagesSync[sessionId] != null).toString(),
            'syncMessages':
                sync.messagesForSession(sessionId).length.toString(),
            'elapsedMs': stopwatch.elapsedMilliseconds,
          }),
        ));
        // Finish the transaction as failed
        transaction.setData('timeout', true);
        unawaited(transaction.finish());
        setState(() {
          _isLoadingMessages = false;
          _initialLoadComplete = true;
          if (_messages.isEmpty) _loadFailed = true;
        });
      },
    );

    try {
      final cacheSpan = transaction.startChild(
        'chat.cache.check',
        description: 'Check cached messages',
      );
      unawaited(
        (cacheSpan..setData('cachedCount', _messages.length)).finish(),
      );

      unawaited(Sentry.addBreadcrumb(Breadcrumb(
        message: 'ChatScreen._doInitialLoad started',
        category: 'chat.load',
        data: {
          'sessionId': sessionId,
          'hasCachedMessages': _messages.isNotEmpty,
          'syncInitialized': sync.isInitialized,
        },
      )));

      // Span for onSessionVisible
      final visibleSpan = transaction.startChild(
        'chat.sync.visible',
        description: 'Mark session as visible',
      );
      sync.onSessionVisible(sessionId);
      unawaited(visibleSpan.finish());

      // Show cached messages immediately instead of
      // waiting for the debounced stream notification
      // (100ms). onSessionVisible() loads the MMKV cache
      // synchronously so sync already has messages in
      // memory at this point.
      final refreshSpan = transaction.startChild(
        'chat.sync.refresh',
        description: 'Refresh from sync singleton',
      );
      _refreshFromSync();
      unawaited(refreshSpan.finish());

      // Span for awaiting message sync queue
      final awaitSpan = transaction.startChild(
        'chat.sync.await',
        description: 'Await message sync queue',
      );
      try {
        await sync.messagesSync[sessionId]
            ?.awaitQueue()
            .timeout(const Duration(seconds: 5));
        awaitSpan.setData('timedOut', false);
      } catch (e) {
        success = false;
        awaitSpan
          ..setData('timedOut', true)
          ..setData('error', e.toString());
      }
      unawaited(awaitSpan.finish());
    } catch (error, stack) {
      success = false;
      logger.error(
        '[ChatScreen] _doInitialLoad error '
        'session=$sessionId',
        error,
        stack,
      );
      transaction.setData('error', error.toString());
      unawaited(Sentry.captureException(
        error,
        stackTrace: stack,
        hint: Hint.withMap({
          'context': 'ChatScreen._doInitialLoad',
          'sessionId': sessionId,
        }),
      ));
    } finally {
      _loadingSafetyTimer?.cancel();
      _loadingSafetyTimer = null;
    }

    if (!mounted) {
      await transaction.finish();
      return;
    }

    unawaited(Sentry.addBreadcrumb(Breadcrumb(
      message: 'ChatScreen._doInitialLoad completed',
      category: 'chat.load',
      data: {
        'sessionId': sessionId,
        'success': success,
        'elapsedMs': stopwatch.elapsedMilliseconds,
        'messageCount': _messages.length,
        'syncMessages': sync.messagesForSession(sessionId).length,
      },
    )));

    _refreshFromSync(
      markLoaded: true,
      loadFailed: !success && _messages.isEmpty,
    );

    // Finish the transaction
    transaction
      ..setData('finalMessageCount', _messages.length)
      ..setData('elapsedMs', stopwatch.elapsedMilliseconds);
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
    setState(() => _permissionMode = mode);
    ref
        .read(chatActionNotifierProvider.notifier)
        .savePermissionMode(widget.sessionId, mode.toModeString());
  }

  void _onModelModeChanged(ClaudeModel model) {
    final normalized = ClaudeModel.normalizeForFlavor(
      model,
      _session?.metadata?.flavor,
    );
    setState(() {
      _modelMode = normalized;
      _rawModelModeString = normalized.modeString;
    });
    ref
        .read(chatActionNotifierProvider.notifier)
        .saveModelMode(widget.sessionId, normalized.modeString);
  }

  void _onProfileChanged(AIBackendProfile? profile) {
    // Use the profile's default model mode when switching providers.
    // If no profile is selected, fall back to ClaudeModel.defaultModel.
    final profileDefaultModelMode = profile?.defaultModelMode;
    final newModel = profileDefaultModelMode != null
        ? ClaudeModel.normalizeForFlavor(
            ClaudeModel.fromString(profileDefaultModelMode),
            _session?.metadata?.flavor,
          )
        : ClaudeModel.defaultModel;
    final rawModelString =
        profileDefaultModelMode ?? newModel.modeString;

    // Apply the profile's default permission mode (consistent with
    // how NewSessionScreen applies it on session creation).
    final profilePermMode = profile?.defaultPermissionMode;
    final newPermissionMode = profilePermMode != null
        ? (PermissionModeExtension.fromString(profilePermMode) ??
            _permissionMode)
        : _permissionMode;

    setState(() {
      _selectedProfile = profile;
      _modelMode = newModel;
      _rawModelModeString = rawModelString;
      _permissionMode = newPermissionMode;
    });
    final notifier = ref.read(chatActionNotifierProvider.notifier);
    notifier.saveProfile(widget.sessionId, profile?.id);
    // Save the profile's defaultModelMode, not 'default'
    notifier.saveModelMode(widget.sessionId, rawModelString);
    if (profilePermMode != null) {
      notifier.savePermissionMode(
        widget.sessionId,
        newPermissionMode.toModeString(),
      );
    }

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
          const SnackBar(
            content: Text(
              'Could not abort — this feature may not be '
              'available on the server',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAborting = false);
    }
  }

  void _onSuggestionTap(String suggestion) {
    _controller.text = suggestion;
    _controller.selection = TextSelection.collapsed(
      offset: suggestion.length,
    );
  }

  Future<void> _onOptionPress(String option) async {
    if (_isSending) return;
    try {
      final sentSessionId = await ref
          .read(chatActionNotifierProvider.notifier)
          .sendMessage(
            widget.sessionId,
            option,
            displayText: option,
            permissionMode: _permissionMode.toModeString(),
            modelMode: _rawModelModeString ?? _modelMode.modeString,
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
          SnackBar(
            content: Text('${context.l10n.chatFailedToSend}: $e'),
          ),
        );
      }
    }
  }

  Future<void> _retryMessage(Map<String, dynamic> message) async {
    final localId =
        message['localId'] as String? ?? message['id'] as String?;
    if (localId == null) return;

    try {
      await sync.retryFailedMessage(widget.sessionId, localId);
    } catch (e, st) {
      logger.warning(
        '[ChatScreen] _retryMessage failed: '
        'sessionId=${widget.sessionId} localId=$localId $e',
        e,
        st,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to retry message: $e')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    unawaited(TtsService().stop());

    if (text == '/clear') {
      _controller.clear();
      unawaited(DraftStorage().removeDraft(widget.sessionId));
      _autoScrollNotifier.value = true;
      setState(() {
        _isSending = true;
        _visibleCount = _ChatScreenState._pageSize;
      });
      try {
        final sentSessionId = await ref
            .read(chatActionNotifierProvider.notifier)
            .sendMessage(
              widget.sessionId,
              text,
              permissionMode: _permissionMode.toModeString(),
              modelMode: _rawModelModeString ?? _modelMode.modeString,
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
              content: Text(
                context.l10n.chatFailedToClear(e.toString()),
              ),
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

    _autoScrollNotifier.value = true;

    // ── Optimistic UI: Show message immediately ──
    final optimisticMessage = <String, dynamic>{
      'id': 'optimistic-${DateTime.now().millisecondsSinceEpoch}',
      'role': 'user',
      'content': text,
      'text': text,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'seq': -1, // Will be replaced by server
      'sendStatus': 'sending', // Track for potential rollback
    };
    setState(() {
      _messages = [..._messages, optimisticMessage];
      _isSending = true;
      _controller.clear();
      _visibleCount = (_visibleCount + 1).clamp(0, _messages.length);
      _invalidateNeighborCache();
    });
    _scrollToBottom();

    unawaited(DraftStorage().removeDraft(widget.sessionId));

    try {
      final sentSessionId = await ref
          .read(chatActionNotifierProvider.notifier)
          .sendMessage(
            widget.sessionId,
            text,
            displayText: text,
            permissionMode: _permissionMode.toModeString(),
            modelMode: _rawModelModeString ?? _modelMode.modeString,
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
          final idx = _messages.indexWhere(
            (m) => m['id'] == optimisticMessage['id'],
          );
          if (idx != -1) {
            _messages = [
              ..._messages.sublist(0, idx),
              {..._messages[idx], 'sendStatus': 'failed'},
              ..._messages.sublist(idx + 1),
            ];
          }
          _controller.text = text;
          _isSending = false;
          _invalidateNeighborCache();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.chatFailedToSend}: $e'),
          ),
        );
      }
    } finally {
      if (mounted && _isSending) {
        setState(() => _isSending = false);
      }
    }
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
      storage.savePermissionMode(
        sentSessionId,
        _permissionMode.toModeString(),
      ),
    );
    final modelStr = _rawModelModeString ?? _modelMode.modeString;
    unawaited(storage.saveModelMode(sentSessionId, modelStr));

    context.goNamed(
      'chat',
      pathParameters: {'sessionId': sentSessionId},
    );
    return true;
  }
}
