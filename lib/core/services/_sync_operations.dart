part of 'sync_service.dart';

extension SyncOperations on Sync {
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

        final updateData = WireParsers.asMap(updateResponse.data);
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
          _lastSettingsPostAtMs = DateTime.now().millisecondsSinceEpoch;
          _notifyDataChanged({SyncDomain.settings});
          unawaited(MMKVStorage().saveSettings(_settingsSnapshot));
        } else if (updateData?['error'] == 'version-mismatch') {
          final currentSettingsEncrypted =
              updateData?['currentSettings'] as String?;
          final currentVersion = _asInt(updateData?['currentVersion']) ?? 0;
          final serverSettingsMap = currentSettingsEncrypted != null
              ? WireParsers.asMap(
                  await encryption.decryptRaw(currentSettingsEncrypted),
                )
              : null;
          final serverSettings = serverSettingsMap != null
              ? Settings.fromJsonWithFallback(
                  serverSettingsMap,
                  _settingsSnapshot,
                )
              : _settingsSnapshot;
          _settingsSnapshot = Settings.fromJson({
            ...serverSettings.toJson(),
            ...pendingSettings,
          });
          _settingsVersion = currentVersion;
          _notifyDataChanged({SyncDomain.settings});
        }
      }

      // Fetch latest settings — skip after a successful POST to avoid
      // overwriting with stale server data that hasn't committed the
      // POST yet.  The next periodic sync or socket push will reconcile.
      if (!postedSuccessfully) {
        final response = await apiClient.get('/v1/account/settings');

        if (apiClient.isSuccess(response)) {
          final data = WireParsers.asMap(response.data);
          final encryptedSettings = data?['settings'] as String?;

          if (encryptedSettings != null) {
            final decrypted = WireParsers.asMap(
              await encryption.decryptRaw(encryptedSettings),
            );
            if (decrypted != null) {
              _settingsSnapshot = Settings.fromJsonWithFallback(
                decrypted,
                _settingsSnapshot,
              );
              _settingsVersion =
                  _asInt(data?['settingsVersion']) ?? _settingsVersion;
              _notifyDataChanged({SyncDomain.settings});
              // Persist to MMKV so the next cold start has fresh data.
              unawaited(MMKVStorage().saveSettings(_settingsSnapshot));
            }
          } else {
            _settingsVersion =
                _asInt(data?['settingsVersion']) ?? _settingsVersion;
            logger.warning(
              'Settings response did not include settings payload; '
              'preserving existing settings snapshot',
            );
          }
        } else {
          logger.warning('Failed to fetch settings: ${response.statusCode}');
        }
      }
    } on DioException {
      rethrow;
    } catch (error, stack) {
      logger.error('Error syncing settings', error, stack);
    }
  }

  /// Sync purchases — piggybacks on [profileSync] since [fetchProfile]
  /// already extracts purchases from the same endpoint.  Avoids a
  /// duplicate HTTP request to `/v1/account/profile`.
  Future<void> syncPurchases() async {
    await profileSync.awaitQueue();
  }

  /// Fetch profile from server. Also extracts and stores purchases data
  /// from the same response to avoid a second identical HTTP call from
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
      logger.error('Error fetching profile', error, stack);
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

      final data = WireParsers.asMap(response.data);
      final updateUrl =
          data?['updateUrl'] as String? ?? data?['update_url'] as String?;
      _nativeUpdateUrl = updateUrl != null && updateUrl.isNotEmpty
          ? updateUrl
          : null;
    } catch (error, stack) {
      if (Sync._isTransientConnectionError(error)) {
        logger.info('Native update fetch aborted (transient): $error');
      } else {
        logger.error('Failed to fetch native update', error, stack);
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

      // Skip the expensive getToken() call if we've already registered a
      // token on this device — the token only changes on app reinstall or
      // FCM invalidation, both of which survive a warm restart.
      if (_registeredPushToken != null) {
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
    // Route through machinesSync so concurrent calls are coalesced rather
    // than firing two parallel GET /v1/machines requests.
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
    _notifyDataChanged({SyncDomain.sessions});
  }

  /// Mark a session as optimistically unarchived.
  ///
  /// Call this after a successful unarchive API call. Removes the session
  /// from the optimistic archive filter so it can appear in the active
  /// list.
  void markSessionUnarchived(String sessionId) {
    _optimisticallyArchivedSessions.remove(sessionId);
    _notifyDataChanged({SyncDomain.sessions});
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
}
