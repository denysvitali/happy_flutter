part of 'sync_service.dart';

extension _SyncOperations on Sync {
  Future<void> syncSettings() async {
    logger.info('Syncing settings...');

    try {
      final apiClient = ApiClient();

      // Apply pending settings
      var postedSuccessfully = false;
      if (pendingSettings.isNotEmpty) {
        final mergedSettings = Settings.fromJson({
          ..._settingsSnapshot.toJson(),
          ...pendingSettings,
        });
        final encryptedPending = await encryption.encryptRaw(
          mergedSettings.toJson(),
        );

        final updateResponse = await apiClient.post(
          '/v1/account/settings',
          data: {
            'settings': encryptedPending,
            'expectedVersion': _settingsVersion,
          },
        );

        final updateData = updateResponse.data as Map<String, dynamic>?;
        final updateSuccess = updateData?['success'] == true;
        if (apiClient.isSuccess(updateResponse) && updateSuccess) {
          _settingsSnapshot = mergedSettings;
          pendingSettings.clear();
          // Extract the incremented version from the POST response
          // so the next optimistic write uses the correct base.
          final newVersion = _asInt(updateData?['settingsVersion']);
          if (newVersion != null) {
            _settingsVersion = newVersion;
          }
          postedSuccessfully = true;
          _notifyDataChanged();
          unawaited(MMKVStorage().saveSettings(_settingsSnapshot));
        } else if (updateData?['error'] == 'version-mismatch') {
          final currentSettingsEncrypted =
              updateData?['currentSettings'] as String?;
          final currentVersion = _asInt(updateData?['currentVersion']) ?? 0;
          final serverSettingsMap = currentSettingsEncrypted != null
              ? await encryption.decryptRaw(currentSettingsEncrypted)
                    as Map<String, dynamic>?
              : null;
          final serverSettings = Settings.fromJson(serverSettingsMap ?? {});
          _settingsSnapshot = Settings.fromJson({
            ...serverSettings.toJson(),
            ...pendingSettings,
          });
          _settingsVersion = currentVersion;
          _notifyDataChanged();
        }
      }

      // Fetch latest settings — skip after a successful POST to avoid
      // overwriting with stale server data that hasn't committed the
      // POST yet.  The next periodic sync or socket push will reconcile.
      if (!postedSuccessfully) {
        final response = await apiClient.get('/v1/account/settings');

        if (apiClient.isSuccess(response)) {
          final data = response.data as Map<String, dynamic>;
          final encryptedSettings = data['settings'] as String?;

          if (encryptedSettings != null) {
            final decrypted =
                await encryption.decryptRaw(encryptedSettings)
                    as Map<String, dynamic>?;
            if (decrypted != null) {
              _settingsSnapshot = Settings.fromJson(decrypted);
              _settingsVersion =
                  _asInt(data['settingsVersion']) ?? _settingsVersion;
              _notifyDataChanged();
              // Persist to MMKV so the next cold start has fresh data.
              unawaited(
                MMKVStorage().saveSettings(_settingsSnapshot),
              );
            }
          } else {
            _settingsSnapshot = Settings();
            _settingsVersion =
                _asInt(data['settingsVersion']) ?? _settingsVersion;
            _notifyDataChanged();
          }
        } else {
          logger.warning(
            'Failed to fetch settings: ${response.statusCode}',
          );
        }
      }
    } on DioException {
      rethrow;
    } catch (error, stack) {
      logger.error(
        'Error syncing settings',
        error,
        stack,
      );
    }
  }

  /// Sync purchases — piggybacks on [profileSync] since [fetchProfile]
  /// already extracts purchases from the same endpoint.  Avoids a
  /// duplicate HTTP request to `/v1/account/profile`.
  Future<void> syncPurchases() async {
    await profileSync.awaitQueue();
  }

  /// Fetch profile from server. Also extracts and stores purchases data from
  /// the same response to avoid a second identical HTTP call from
  /// [syncPurchases].
  Future<void> fetchProfile() async {
    logger.info('Fetching profile...');

    try {
      final apiClient = ApiClient();

      final response = await apiClient.get('/v1/account/profile');

      if (apiClient.isSuccess(response)) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          _profile = Profile.fromJson(data);
          _purchases = Purchases.parse(data['purchases']);
        } else {
          logger.warning(
            'Failed to fetch profile: invalid response type '
            '${data.runtimeType}',
          );
        }
      } else {
        logger.warning('Failed to fetch profile: ${response.statusCode}');
      }
    } on DioException {
      rethrow;
    } catch (error, stack) {
      logger.error(
        'Error fetching profile',
        error,
        stack,
      );
    }
  }

  /// Fetch native app update status
  Future<void> fetchNativeUpdate() async {
    logger.info('Fetching native update...');
    if (kIsWeb) {
      _nativeUpdateUrl = null;
      return;
    }

    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => null,
    };
    if (platform == null) {
      _nativeUpdateUrl = null;
      return;
    }

    try {
      final apiClient = ApiClient();
      final response = await apiClient.post(
        '/v1/version',
        data: <String, dynamic>{
          'platform': platform,
          'version': const String.fromEnvironment(
            'FLUTTER_BUILD_NAME',
            defaultValue: '1.0.0',
          ),
          'app_id': const String.fromEnvironment(
            'FLUTTER_APPLICATION_ID',
            defaultValue: 'happy.flutter',
          ),
        },
      );
      if (!apiClient.isSuccess(response)) {
        _nativeUpdateUrl = null;
        return;
      }

      final data = response.data as Map<String, dynamic>?;
      final updateUrl =
          data?['updateUrl'] as String? ?? data?['update_url'] as String?;
      _nativeUpdateUrl = updateUrl != null && updateUrl.isNotEmpty
          ? updateUrl
          : null;
    } catch (error, stack) {
      if (Sync._isTransientConnectionError(error)) {
        logger.info(
          'Native update fetch aborted (transient): $error',
        );
      } else {
        logger.error(
          'Failed to fetch native update',
          error,
          stack,
        );
      }
      _nativeUpdateUrl = null;
    }
  }

  /// Register or refresh device push token
  Future<void> syncPushToken() async {
    logger.info('Syncing push token...');
    if (kIsWeb) {
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        logger.info('Skipping push token sync: Firebase is not initialized');
        return;
      }

      final messaging = FirebaseMessaging.instance;
      var notificationSettings = await messaging.getNotificationSettings();
      if (notificationSettings.authorizationStatus ==
          AuthorizationStatus.notDetermined) {
        notificationSettings = await messaging.requestPermission();
      }
      if (notificationSettings.authorizationStatus ==
              AuthorizationStatus.denied ||
          notificationSettings.authorizationStatus ==
              AuthorizationStatus.notDetermined) {
        return;
      }

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        return;
      }

      if (_registeredPushToken == token) {
        return;
      }

      await PushApi().registerToken(token);
      _registeredPushToken = token;
    } catch (error, stack) {
      logger.error('Failed to sync push token', error, stack);
    }
  }

  /// Refresh machines from server
  Future<void> refreshMachines() async {
    // Route through machinesSync so concurrent calls are coalesced rather than
    // firing two parallel GET /v1/machines requests.
    await machinesSync.invalidateAndAwait();
  }

  /// Refresh sessions from server
  Future<void> refreshSessions() async {
    await sessionsSync.invalidateAndAwait();
  }

  /// Mark a session as optimistically archived.
  ///
  /// Call this after a successful archive API call. The session will be
  /// filtered from the active list until the server confirms with
  /// `active: false`. This prevents the "archive then reappear" bug caused
  /// by server replication lag.
  void markSessionArchived(String sessionId) {
    _optimisticallyArchivedSessions.add(sessionId);
    _notifyDataChanged();
  }

  /// Mark a session as optimistically unarchived.
  ///
  /// Call this after a successful unarchive API call. Removes the session
  /// from the optimistic archive filter so it can appear in the active list.
  void markSessionUnarchived(String sessionId) {
    _optimisticallyArchivedSessions.remove(sessionId);
    _notifyDataChanged();
  }

  /// Returns whether a session is optimistically archived.
  ///
  /// Use this to filter sessions from the active list.
  bool isSessionOptimisticallyArchived(String sessionId) {
    return _optimisticallyArchivedSessions.contains(sessionId);
  }

  /// Returns a copy of all optimistically archived session IDs.
  ///
  /// Use this for filtering in widget build methods.
  Set<String> getOptimisticallyArchivedIds() {
    return Set<String>.from(_optimisticallyArchivedSessions);
  }

  /// Refresh friends and pending requests from server.
  Future<void> refreshFriends() async {
    await friendsSync.invalidateAndAwait();
    // friendRequestsSync is a no-op (requests come with friends).
  }

  /// Refresh feed items from server.
  Future<void> refreshFeed() async {
    await feedSync.invalidateAndAwait();
  }

  /// Delete a session.
  Future<bool> deleteSession(String sessionId) async {
    try {
      final api = ApiClient();
      final response = await api.delete('/v1/sessions/$sessionId');
      if (!api.isSuccess(response)) {
        return false;
      }

      _handleDeleteSession(<String, dynamic>{'sid': sessionId});
      return true;
    } catch (error, stack) {
      logger.error('Failed to delete session $sessionId', error, stack);
      return false;
    }
  }

  /// Create a session on a target machine/path and return the new session ID.
  ///
  /// Sends a `spawn-happy-session` RPC to the machine daemon, which starts a
  /// new Claude Code agent in [path].  If the directory does not yet exist the
  /// daemon returns a `requestToApproveDirectoryCreation` result; passing
  /// [approvedNewDirectoryCreation] = true tells it to create the directory.
  ///
  /// The active profile's environment variables (API keys, model config, etc.)
  /// and the last-used agent type are automatically read from settings and
  /// forwarded to the daemon so it can configure the agent correctly.
  ///
  /// Throws a [StateError] with a human-readable message on failure.
  Future<String> createSession({
    required String machineId,
    required String path,
    bool approvedNewDirectoryCreation = false,
    /// Explicit profile ID for this session. Takes precedence over
    /// [_settingsSnapshot.lastUsedProfile]. Should be passed when creating a
    /// session so the correct profile env vars are used, rather than relying
    /// on [lastUsedProfile] which can change over time.
    String? profileId,
    /// Optional initial message to pipe directly to the agent's stdin
    /// on startup via the HAPPY_INITIAL_PROMPT env var.  Bypasses the
    /// WebSocket message chain which is unreliable for the very first
    /// message on freshly-spawned sessions.
    String? message,
  }) async {
    if (!isInitialized) {
      throw StateError('Sync is not initialized');
    }
    if (!_isSocketConnected()) {
      throw StateError('Not connected to server');
    }

    // Fail fast if the machine is offline — don't wait 60 s for a timeout.
    //
    // The server marks machines inactive after 10 min without a heartbeat.
    // We use a 2 min activeAt threshold so that clock skew and the server's
    // 30 s activity-cache throttle don't cause false positives (the old 60 s
    // threshold matched the daemon HTTP heartbeat exactly).  When the server
    // has explicitly set active=false we reject immediately regardless of
    // activeAt.
    final machine = _machines[machineId];
    if (machine != null) {
      if (!machine.active) {
        throw StateError('Machine is offline');
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      const onlineThresholdMs = 120 * 1000;
      if (now - machine.activeAt >= onlineThresholdMs) {
        logger.warning(
          'Machine $machineId appears offline: '
          'activeAt=${machine.activeAt}, now=$now, '
          'delta=${now - machine.activeAt}ms',
        );
        throw StateError('Machine is offline');
      }
    }

    // Derive agent type and environment variables from the profile.
    // Use explicit profileId if provided, otherwise fall back to
    // [_settingsSnapshot.lastUsedProfile].
    final effectiveProfileId =
        profileId ?? _settingsSnapshot.lastUsedProfile;
    final profile = effectiveProfileId != null
        ? _resolveProfile(effectiveProfileId)
        : null;
    final profileEnvVars =
        profile != null ? _profileEnvironmentVariables(profile) : null;
    final agent = _settingsSnapshot.lastUsedAgent;
    final permMode =
        profile?.defaultPermissionMode ??
        _settingsSnapshot.lastUsedPermissionMode;
    // Pass the user's last-used model so the daemon writes it into session
    // metadata.  Profile env vars are always forwarded as-is — the profile
    // defines the backend (API keys, base URLs, model names) and stripping
    // model env vars would break profiles that configure a specific model
    // (e.g. Z.AI's GLM-4.6 via ANTHROPIC_MODEL).
    final envVars = _spawnEnvironmentVariables(profileEnvVars);
    if (message != null && message.isNotEmpty) {
      envVars['HAPPY_INITIAL_PROMPT'] = message;
    }
    final req = SpawnSessionRequest(
      type: 'spawn-in-directory',
      directory: path,
      approvedNewDirectoryCreation: true, // Always approve like React Native
      agent: agent,
      permissionMode: permMode,
      model: _getModelOverride(profile: profile),
      environmentVariables: envVars,
    );

    final result = await _typedMachineRPC(
      machineId,
      'spawn-happy-session',
      req.toJson(),
      SpawnSessionResponse.fromJson,
      timeout: const Duration(seconds: 60),
    );

    if (result.type == 'success') {
      final sessionId = result.sessionId;
      if (sessionId == null || sessionId.isEmpty) {
        throw StateError('Machine returned empty session ID');
      }

      // Initialize encryption from the DEK included in the spawn response,
      // avoiding the sync race condition where delta fetches miss the new
      // session's dataEncryptionKey.
      final dek = result.dataEncryptionKey;
      if (dek != null && dek.isNotEmpty) {
        final decryptedKey = await encryption.decryptEncryptionKey(dek);
        if (decryptedKey != null) {
          await encryption.initializeSessions({sessionId: decryptedKey});
        }
      }
      _sessionSpawnedAt[sessionId] = DateTime.now().millisecondsSinceEpoch;
      logger.info(
        '[createSession] Registered session $sessionId in _sessionSpawnedAt',
      );

      // Force a full fetch (not delta) to ensure the newly created session
      // is included in the results. This prevents a race condition where
      // server clock skew causes the session to be excluded from delta
      // fetches (changedSince > session.updatedAt).
      _forceFullFetchNext = true;
      await refreshSessions();

      // Optimistic insert: if the server's /v2/sessions endpoint hasn't
      // propagated the new session yet (replication lag between the RPC
      // endpoint that created it and the REST endpoint that lists it),
      // add a placeholder directly to _sessions. This prevents
      // "Session X not loaded" errors in sendMessage(). The placeholder
      // will be replaced with full server data on the next successful
      // fetch that includes this session.
      if (!_sessions.containsKey(sessionId)) {
        final now = DateTime.now().millisecondsSinceEpoch;
        _sessions[sessionId] = Session(
          id: sessionId,
          seq: 0,
          createdAt: now,
          updatedAt: now,
          active: true,
          activeAt: now,
          metadata: Metadata(
            host: '',
            machineId: machineId,
            path: path,
            flavor: agent,
            lifecycleState: 'starting',
          ),
          metadataVersion: 0,
          agentStateVersion: 0,
          thinking: false,
          presence: 'offline',
        );
      }
      // Flush data change notification immediately so the counter is
      // incremented before loadFromSync() is called. This ensures the
      // sessions list updates without requiring a pull-to-refresh.
      _flushDataChanged();

      // Pre-initialise messagesSync so the chat screen doesn't need to
      // wait for onSessionVisible() — prevents a window where the user
      // navigates to the chat screen before the sync entry exists.
      if (!messagesSync.containsKey(sessionId)) {
        onSessionVisible(sessionId);
      }

      // Optimistic insert: show the initial message immediately in the
      // chat screen while the daemon child pipes it to Claude via stdin.
      if (message != null && message.isNotEmpty) {
        _upsertSessionMessages(sessionId, [
          <String, dynamic>{
            'id': 'initial-${DateTime.now().millisecondsSinceEpoch}',
            'seq': 0,
            'createdAt': DateTime.now().millisecondsSinceEpoch,
            'role': 'user',
            'kind': 'text',
            'content': message,
            'sendStatus': 'sending',
          },
        ]);
        _notifySessionMessagesChanged(sessionId);
      }

      return sessionId;
    }

    if (result.type == 'requestToApproveDirectoryCreation') {
      return createSession(
        machineId: machineId,
        path: path,
        approvedNewDirectoryCreation: true,
      );
    }

    final errorMsg = result.errorMessage ?? 'unknown error';

    // The daemon waits 15 s for the agent's startup webhook before returning
    // an error.  The agent often connects to the server ~2 s after that
    // deadline, so the session IS created even though the RPC returned an
    // error.  Retry once: wait briefly, force a full session refresh, then
    // look for a recently-created session on this machine + path.
    if (errorMsg.contains('webhook timeout')) {
      logger.info(
        '[createSession] spawn webhook timeout for '
        'machine=$machineId path=$path — waiting for late session',
      );
      await Future<void>.delayed(const Duration(seconds: 5));
      _forceFullFetchNext = true;
      await refreshSessions();

      final now = DateTime.now().millisecondsSinceEpoch;
      final candidates =
          _sessions.values
              .where(
                (s) {
                  final ageMs = now - s.createdAt;
                  final matchesMachineId = s.metadata?.machineId == machineId;
                  final matchesPath = s.metadata?.path == path;
                  final recent = ageMs < 90000;
                  final isMatch = matchesMachineId && matchesPath && recent;
                  if (matchesPath && ageMs < 120000) {
                    logger.info(
                      '[createSession] checking session ${s.id}: '
                      'machineId=${s.metadata?.machineId} '
                      '(matches=$matchesMachineId) '
                      'path=${s.metadata?.path} '
                      '(matches=$matchesPath) '
                      'age=${(ageMs / 1000).toStringAsFixed(1)}s '
                      '(recent=$recent) '
                      'isMatch=$isMatch',
                    );
                  }
                  return isMatch;
                },
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      logger.info(
        '[createSession] found ${candidates.length} candidate sessions '
        'matching machine=$machineId path=$path',
      );

      if (candidates.isNotEmpty) {
        final found = candidates.first;
        logger.info(
          '[createSession] recovered session ${found.id} '
          'after webhook timeout',
        );
        _sessionSpawnedAt[found.id] = found.createdAt;
        _notifyDataChanged();
        return found.id;
      }

      logger.warning(
        '[createSession] session not found after webhook timeout retry '
        'machine=$machineId path=$path',
      );
    }

    throw StateError(errorMsg);
  }

  /// Execute a bash command on a machine.
  Future<BashResponse> machineBash({
    required String machineId,
    required String command,
    required String cwd,
  }) async {
    try {
      return await _typedMachineRPC(
        machineId,
        'bash',
        BashRequest(command: command, cwd: cwd).toJson(),
        BashResponse.fromJson,
      );
    } catch (error) {
      if (error is StateError &&
          error.message.contains('not connected')) {
        logger.info('machineBash: socket not connected');
      } else {
        logger.error('machineBash error', error);
      }
    }
    return const BashResponse(success: false, stderr: 'RPC call failed');
  }

  /// Read a file from a machine via encrypted RPC.
  Future<ReadFileResponse> machineReadFile({
    required String machineId,
    required String filePath,
  }) async {
    try {
      return await _typedMachineRPC(
        machineId,
        'readFile',
        ReadFileRequest(path: filePath).toJson(),
        ReadFileResponse.fromJson,
      );
    } catch (error) {
      if (error is StateError &&
          error.message.contains('not connected')) {
        logger.info('machineReadFile: socket not connected');
      } else {
        logger.error('machineReadFile error', error);
      }
    }
    return const ReadFileResponse(
      success: false,
      error: 'RPC call failed',
    );
  }

  /// Fetch Claude Code usage limits from a machine via encrypted RPC.
  ///
  /// The machine daemon reads `~/.claude/.credentials.json` and calls the
  /// Anthropic OAuth usage API, returning the raw JSON payload.
  Future<ClaudeUsageLimitsResponse> machineGetClaudeUsageLimits({
    required String machineId,
  }) async {
    try {
      return await _typedMachineRPC(
        machineId,
        'get-claude-usage-limits',
        <String, dynamic>{},
        ClaudeUsageLimitsResponse.fromJson,
      );
    } catch (error) {
      if (error is StateError &&
          error.message.contains('not connected')) {
        logger.info(
          'machineGetClaudeUsageLimits: socket not connected',
        );
      } else {
        logger.warning(
          'machineGetClaudeUsageLimits error',
          error,
        );
      }
    }
    return const ClaudeUsageLimitsResponse(
      success: false,
      error: 'RPC call failed',
    );
  }

  /// Create a git worktree on a machine under `.dev/worktree/<name>` relative
  /// to [basePath] and return the absolute path to the new worktree.
  ///
  /// Mirrors React Native's `createWorktree` utility.
  /// Throws [StateError] if [basePath] is not a git repository or the
  /// worktree creation fails after retries.
  Future<String> createWorktree({
    required String machineId,
    required String basePath,
  }) async {
    final gitCheck = await machineBash(
      machineId: machineId,
      command: 'git rev-parse --git-dir',
      cwd: basePath,
    );
    if (!gitCheck.success) {
      throw StateError('Not a Git repository');
    }

    final name = _generateWorktreeName();
    final worktreePath = '.dev/worktree/$name';
    var result = await machineBash(
      machineId: machineId,
      command: 'git worktree add -b $name $worktreePath',
      cwd: basePath,
    );
    if (result.success) {
      return '$basePath/$worktreePath';
    }

    if (result.stderr.contains('already exists')) {
      for (var i = 2; i <= 4; i++) {
        final newName = '$name-$i';
        final newPath = '.dev/worktree/$newName';
        result = await machineBash(
          machineId: machineId,
          command: 'git worktree add -b $newName $newPath',
          cwd: basePath,
        );
        if (result.success) {
          return '$basePath/$newPath';
        }
      }
    }

    throw StateError(
      result.stderr.isNotEmpty ? result.stderr : 'Failed to create worktree',
    );
  }

  String _generateWorktreeName() {
    final rand = Random();
    final adj = Sync._worktreeAdjectives[rand.nextInt(Sync._worktreeAdjectives.length)];
    final noun = Sync._worktreeNouns[rand.nextInt(Sync._worktreeNouns.length)];
    return '$adj-$noun';
  }

  /// Convert an [AIBackendProfile] into a flat map of environment variables
  /// that will be forwarded to the machine daemon when spawning a session.
  ///
  /// Resolve a profile by ID: custom profiles first, then built-in.
  AIBackendProfile? _resolveProfile(String id) {
    for (final p in _settingsSnapshot.profiles) {
      if (p.id == id) return p;
    }
    return getBuiltInProfile(id);
  }

  /// Mirrors React Native's `getProfileEnvironmentVariables` in settings.ts.
  Map<String, String> _profileEnvironmentVariables(AIBackendProfile profile) {
    final envVars = <String, String>{};

    for (final v in profile.environmentVariables) {
      envVars[v.name] = v.value;
    }

    final anthropic = profile.anthropicConfig;
    if (anthropic != null) {
      if (anthropic.baseUrl != null) {
        envVars['ANTHROPIC_BASE_URL'] = anthropic.baseUrl!;
      }
      if (anthropic.authToken != null) {
        envVars['ANTHROPIC_AUTH_TOKEN'] = anthropic.authToken!;
      }
      if (anthropic.model != null) {
        envVars['ANTHROPIC_MODEL'] = anthropic.model!;
      }
    }

    final openai = profile.openaiConfig;
    if (openai != null) {
      if (openai.apiKey != null) {
        envVars['OPENAI_API_KEY'] = openai.apiKey!;
      }
      if (openai.baseUrl != null) {
        envVars['OPENAI_BASE_URL'] = openai.baseUrl!;
      }
      if (openai.model != null) {
        envVars['OPENAI_MODEL'] = openai.model!;
      }
    }

    final azure = profile.azureOpenAIConfig;
    if (azure != null) {
      if (azure.apiKey != null) {
        envVars['AZURE_OPENAI_API_KEY'] = azure.apiKey!;
      }
      if (azure.endpoint != null) {
        envVars['AZURE_OPENAI_ENDPOINT'] = azure.endpoint!;
      }
      if (azure.apiVersion != null) {
        envVars['AZURE_OPENAI_API_VERSION'] = azure.apiVersion!;
      }
      if (azure.deploymentName != null) {
        envVars['AZURE_OPENAI_DEPLOYMENT_NAME'] = azure.deploymentName!;
      }
    }

    final together = profile.togetherAIConfig;
    if (together != null) {
      if (together.apiKey != null) {
        envVars['TOGETHER_API_KEY'] = together.apiKey!;
      }
      if (together.model != null) {
        envVars['TOGETHER_MODEL'] = together.model!;
      }
    }

    final tmux = profile.tmuxConfig;
    if (tmux != null) {
      if (tmux.sessionName != null) {
        envVars['TMUX_SESSION_NAME'] = tmux.sessionName!;
      }
      if (tmux.tmpDir != null) {
        envVars['TMUX_TMPDIR'] = tmux.tmpDir!;
      }
      if (tmux.updateEnvironment != null) {
        envVars['TMUX_UPDATE_ENVIRONMENT'] = tmux.updateEnvironment.toString();
      }
    }

    return envVars;
  }

  /// Build daemon spawn environment variables with safe defaults.
  Map<String, String> _spawnEnvironmentVariables(Map<String, String>? base) {
    return <String, String>{...?base};
  }

  /// Never pass --model when spawning sessions. The model is always
  /// determined by profile env vars (ANTHROPIC_MODEL, OPENAI_MODEL, etc.)
  /// or the CLI's own defaults. Passing --model causes stale model names
  /// (e.g. GLM-5) to leak across profile switches.
  String? _getModelOverride({AIBackendProfile? profile}) => null;

  /// Get environment variables and profile for spawning a session, using the
  /// profile associated with the session if available. Does NOT fall back to
  /// [lastUsedProfile] — if no profile is saved for the session, returns
  /// empty env vars and null profile to avoid using a wrong profile after
  /// profile switches.
  Future<({Map<String, String> envVars, AIBackendProfile? profile})>
      _getSpawnEnvVarsForSession(String sessionId) async {
    final override = testGetSpawnEnvVarsOverride;
    if (override != null) return override(sessionId);
    // Get the profile ID that was saved for this specific session.
    final profileId = await MMKVStorage().getSessionProfile(sessionId);
    if (profileId != null) {
      final profile = _resolveProfile(profileId);
      if (profile != null) {
        return (
          envVars: _spawnEnvironmentVariables(
            _profileEnvironmentVariables(profile),
          ),
          profile: profile,
        );
      }
    }
    // No profile saved for this session — return empty env vars rather than
    // falling back to lastUsedProfile which may have changed since creation.
    return (envVars: _spawnEnvironmentVariables(null), profile: null);
  }

  Future<
    ({String sessionId, Session session, SessionEncryption sessionEncryption})
  >
  _resolveSendTargetSession({
    required String sessionId,
    required Session session,
    required SessionEncryption sessionEncryption,
    required String effectivePermissionMode,
  }) async {
    final lifecycleState = session.metadata?.lifecycleState;
    final agentIsStartingOrRunning =
        lifecycleState == 'starting' || lifecycleState == 'running';
    // Guard against stale lifecycleState: if the agent process crashed without
    // updating metadata to "archived", lifecycleState stays "running" even
    // though the session is offline.  Only trust lifecycleState if the
    // timestamp is recent (< 2 minutes).
    final lifecycleStateSince = session.metadata?.lifecycleStateSince;
    final lifecycleRecent =
        lifecycleStateSince != null &&
        DateTime.now().millisecondsSinceEpoch - lifecycleStateSince < 120000;
    final spawnedAt = _sessionSpawnedAt[sessionId];
    final recentlySpawned =
        spawnedAt != null &&
        DateTime.now().millisecondsSinceEpoch - spawnedAt < 120000;
    // When lifecycleState is explicitly 'archived', the agent process is
    // gone.  Don't trust a stale presence='online' — fall through to
    // auto-restore instead.
    final isArchived = lifecycleState == 'archived';
    // Don't trust presence='online' by itself — after a daemon restart a
    // full session fetch resets all presence-expiry timers, leaving dead
    // sessions with stale 'online' presence for up to 60 s.  Cross-check
    // with the last ephemeral event (keep-alive / activity) timestamp so
    // we only trust presence that is backed by a recent real-time signal.
    final lastEphemeral = _lastEphemeralAt[sessionId];
    final recentEphemeral =
        lastEphemeral != null &&
        DateTime.now().millisecondsSinceEpoch - lastEphemeral < 90000;
    final isOnlineTrusted = session.isOnline && recentEphemeral;
    final looksReady =
        !isArchived &&
        (isOnlineTrusted ||
            (agentIsStartingOrRunning && lifecycleRecent) ||
            recentlySpawned);
    logger.info(
      '[sendMessage] _resolveSendTargetSession '
      'session=$sessionId looksReady=$looksReady '
      '(isOnline=${session.isOnline}, '
      'isOnlineTrusted=$isOnlineTrusted, '
      'lifecycleState=$lifecycleState, '
      'lifecycleRecent=$lifecycleRecent, '
      'recentlySpawned=$recentlySpawned, '
      'agentStateVersion=${session.agentStateVersion})',
    );
    if (looksReady) {
      return (
        sessionId: sessionId,
        session: session,
        sessionEncryption: sessionEncryption,
      );
    }

    final machineId = session.metadata?.machineId;
    final path = session.metadata?.path;
    if (machineId == null ||
        machineId.isEmpty ||
        path == null ||
        path.isEmpty) {
      return (
        sessionId: sessionId,
        session: session,
        sessionEncryption: sessionEncryption,
      );
    }

    // Fail fast if the machine is offline — don't wait 60 s for a timeout.
    final machine = _machines[machineId];
    if (machine != null && !machine.active) {
      logger.info(
        '[sendMessage] machine=$machineId is offline, '
        'skipping auto-restore',
      );
      return (
        sessionId: sessionId,
        session: session,
        sessionEncryption: sessionEncryption,
      );
    }

    logger.info(
      '[sendMessage] session=$sessionId appears offline '
      '(presence=${session.presence}, lifecycleState=$lifecycleState); '
      'attempting auto-restore',
    );

    if (_autoRestoreInFlight.contains(sessionId)) {
      logger.info(
        '[sendMessage] auto-restore already in-flight for '
        'session=$sessionId, skipping duplicate',
      );
      return (
        sessionId: sessionId,
        session: session,
        sessionEncryption: sessionEncryption,
      );
    }
    _autoRestoreInFlight.add(sessionId);
    try {
      // Resolve profile env vars for this session before spawning.
      final spawnResult =
          await _getSpawnEnvVarsForSession(sessionId);
      final req = SpawnSessionRequest(
        type: 'spawn-in-directory',
        directory: path,
        sessionId: sessionId,
        agent: session.metadata?.flavor ?? 'claude',
        permissionMode: effectivePermissionMode,
        model: _getModelOverride(profile: spawnResult.profile),
        environmentVariables: spawnResult.envVars,
      );
      final result = await _typedMachineRPC(
        machineId,
        'spawn-happy-session',
        req.toJson(),
        SpawnSessionResponse.fromJson,
        timeout: const Duration(seconds: 60),
      );
      if (result.type != 'success') {
        logger.warning(
          '[sendMessage] auto-restore not successful '
          'session=$sessionId type=${result.type ?? 'null'} '
          'error=${result.errorMessage ?? 'unknown'}',
        );
        return (
          sessionId: sessionId,
          session: session,
          sessionEncryption: sessionEncryption,
        );
      }

      final restoredSessionId = result.sessionId;
      if (restoredSessionId == null || restoredSessionId.isEmpty) {
        logger.warning(
          '[sendMessage] auto-restore returned empty session id '
          'for requested=$sessionId',
        );
        return (
          sessionId: sessionId,
          session: session,
          sessionEncryption: sessionEncryption,
        );
      }

      await _primeSessionFromSpawnResult(
        requestedSessionId: sessionId,
        restoredSessionId: restoredSessionId,
        seedSession: session,
        result: result,
      );
      if (restoredSessionId != sessionId) {
        logger.info(
          '[sendMessage] auto-restore redirected session '
          '$sessionId -> $restoredSessionId',
        );
        // Keep the list fresh, but do not force a full /v2/sessions reload.
        sessionsSync.invalidate();
      }

      var restoredSession = _sessions[restoredSessionId];
      if (restoredSession == null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        restoredSession = Session(
          id: restoredSessionId,
          seq: 0,
          createdAt: now,
          updatedAt: now,
          active: true,
          activeAt: now,
          metadata: Metadata(
            host: session.metadata?.host ?? '',
            machineId: machineId,
            path: path,
            flavor: session.metadata?.flavor,
            lifecycleState: 'starting',
          ),
          metadataVersion: 0,
          agentStateVersion: 0,
          thinking: false,
          presence: 'offline',
        );
        _sessions[restoredSessionId] = restoredSession;
        _notifyDataChanged();
      }

      var restoredSessionEncryption = encryption.getSessionEncryption(
        restoredSessionId,
      );
      if (restoredSessionEncryption == null && restoredSessionId == sessionId) {
        restoredSessionEncryption = sessionEncryption;
      }
      if (restoredSessionEncryption == null) {
        await sessionsSync.invalidateAndAwait();
        restoredSessionEncryption = encryption.getSessionEncryption(
          restoredSessionId,
        );
      }
      if (restoredSessionEncryption == null) {
        logger.warning(
          '[sendMessage] auto-restore missing encryption for '
          'session=$restoredSessionId; using original session',
        );
        return (
          sessionId: sessionId,
          session: session,
          sessionEncryption: sessionEncryption,
        );
      }

      return (
        sessionId: restoredSessionId,
        session: restoredSession,
        sessionEncryption: restoredSessionEncryption,
      );
    } catch (error, stack) {
      // Transient network errors during auto-restore are expected
      // when the device is offline — log at info to avoid Sentry noise.
      if (Sync._isTransientConnectionError(error)) {
        logger.info(
          '[sendMessage] auto-restore failed (transient) '
          'session=$sessionId: $error',
        );
      } else {
        logger
          ..warning(
            '[sendMessage] auto-restore failed for session=$sessionId',
            error,
          )
          ..warning(
            '[sendMessage] auto-restore stacktrace '
            'for session=$sessionId',
            stack,
          );
      }
      return (
        sessionId: sessionId,
        session: session,
        sessionEncryption: sessionEncryption,
      );
    } finally {
      _autoRestoreInFlight.remove(sessionId);
    }
  }
}
