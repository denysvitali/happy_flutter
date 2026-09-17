import 'dart:async' show TimeoutException, unawaited;

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/push_api.dart';
import '../encryption/encryption_manager.dart';
import '../models/profile.dart';
import '../models/purchases.dart';
import '../models/settings.dart';
import '../services/logger_service.dart' show logger;
import '../services/mmkv_storage.dart';
import '../sync/invalidate_sync.dart';
import '../sync/sync_domain.dart';
import '../wire/wire_parsers.dart';

/// Manages settings, profile, purchases, push token, and native update
/// synchronization. Extracted from the Sync god object.
class SettingsManager {
  SettingsManager({
    required Encryption encryption,
    ApiClient? client,
    required int nativeUpdateFreshnessMs,
    required bool Function(Object) isTransientConnectionError,
    required InvalidateSync Function() settingsSyncGetter,
    required InvalidateSync Function() profileSyncGetter,
    required InvalidateSync Function() purchasesSyncGetter,
    required void Function(Set<SyncDomain>) onDataChanged,
  }) : _encryption = encryption,
       _client = client ?? ApiClient(),
       _nativeUpdateFreshnessMs = nativeUpdateFreshnessMs,
       _isTransientConnectionError = isTransientConnectionError,
       _settingsSyncGetter = settingsSyncGetter,
       _profileSyncGetter = profileSyncGetter,
       _purchasesSyncGetter = purchasesSyncGetter,
       _onDataChanged = onDataChanged;

  final Encryption _encryption;
  final ApiClient _client;
  int _generation = 0;
  final int _nativeUpdateFreshnessMs;
  final bool Function(Object) _isTransientConnectionError;
  final InvalidateSync Function() _settingsSyncGetter;
  final InvalidateSync Function() _profileSyncGetter;
  final InvalidateSync Function() _purchasesSyncGetter;
  final void Function(Set<SyncDomain>) _onDataChanged;

  Settings _settingsSnapshot = Settings();
  int _settingsVersion = 0;
  final Map<String, dynamic> _pendingSettings = {};
  int? _lastSettingsPostAtMs;
  Future<void>? _settingsOpQueue;

  Profile? _profile;
  Purchases _purchases = Purchases.defaults;

  String? _registeredPushToken;
  String? _nativeUpdateUrl;
  int? _lastNativeUpdateFetchedAt;

  /// Current settings snapshot.
  Settings get settingsSnapshot => _settingsSnapshot;
  set settingsSnapshot(Settings value) => _settingsSnapshot = value;

  /// Current settings server version.
  int get settingsVersion => _settingsVersion;
  set settingsVersion(int value) => _settingsVersion = value;

  /// Settings that have been applied locally but not yet posted to server.
  Map<String, dynamic> get pendingSettings => _pendingSettings;

  /// Last successful settings POST timestamp, or null if none.
  int? get lastSettingsPostAtMs => _lastSettingsPostAtMs;

  /// Current user profile, or null if not fetched.
  Profile? get profile => _profile;
  set profile(Profile? value) => _profile = value;

  /// Current purchases state.
  Purchases get purchases => _purchases;
  set purchases(Purchases value) => _purchases = value;

  /// Last registered FCM/APNs push token, or null.
  String? get registeredPushToken => _registeredPushToken;

  /// Native app update URL, or null if none available.
  String? get nativeUpdateUrl => _nativeUpdateUrl;
  set nativeUpdateUrl(String? value) => _nativeUpdateUrl = value;

  /// Last native-update fetch timestamp, or null.
  int? get lastNativeUpdateFetchedAt => _lastNativeUpdateFetchedAt;

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Sync settings with the server: POST pending deltas, then GET latest.
  ///
  /// Overlapping calls serialize on a manager-owned lane independent of
  /// InvalidateSync suspension, so a queued call observes the version the
  /// previous write acknowledged instead of racing it with a stale
  /// expectedVersion. Each call keeps the generation captured at entry, so a
  /// runtime reset between enqueue and run can never mutate fresh state.
  Future<void> syncSettings() {
    final generation = _generation;
    final previous = _settingsOpQueue;
    final operation = previous == null
        ? _runSettingsSync(generation)
        : previous.then((_) => _runSettingsSync(generation));
    // Keep the lane usable after failure without swallowing the caller's
    // error (InvalidateSync must retry failed writes).
    _settingsOpQueue = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }

  Future<void> _runSettingsSync(int generation) async {
    if (generation != _generation) return;
    logger.info('Syncing settings...');

    try {
      final apiClient = _client;

      // Apply pending settings
      var postedSuccessfully = false;
      if (_pendingSettings.isNotEmpty) {
        // Capture the document and the version it is based on together, so
        // the POST cannot pair a re-read version with a stale merged body.
        final postedDelta = Map<String, dynamic>.of(_pendingSettings);
        final expectedVersion = _settingsVersion;
        final mergedJson = <String, dynamic>{
          ..._settingsSnapshot.toJson(),
          ...postedDelta,
        };
        final encryptedPending = await _encryption.encryptRaw(mergedJson);
        if (generation != _generation) return;

        final updateResponse = await apiClient.post(
          '/v1/account/settings',
          data: {
            'settings': encryptedPending,
            'expectedVersion': expectedVersion,
          },
        );
        if (generation != _generation) return;

        final updateData = WireParsers.asMap(updateResponse.data);
        final updateSuccess = updateData?['success'] == true;
        if (apiClient.isSuccess(updateResponse) && updateSuccess) {
          // A response acknowledges only the submitted values. Edits made
          // during encryption/HTTP remain pending and visible.
          _pendingSettings.removeWhere(
            (key, value) =>
                postedDelta.containsKey(key) && postedDelta[key] == value,
          );
          _settingsSnapshot = Settings.fromJson({
            ...mergedJson,
            ..._pendingSettings,
          });
          final newVersion = _asInt(updateData?['settingsVersion']);
          if (newVersion != null) {
            _settingsVersion = newVersion;
          }
          postedSuccessfully = true;
          _lastSettingsPostAtMs = DateTime.now().millisecondsSinceEpoch;
          _onDataChanged({SyncDomain.settings});
          unawaited(MMKVStorage().saveSettings(_settingsSnapshot));
        } else if (updateData?['error'] == 'version-mismatch') {
          final currentSettingsEncrypted =
              updateData?['currentSettings'] as String?;
          final currentVersion = _asInt(updateData?['currentVersion']) ?? 0;
          final serverSettingsMap = currentSettingsEncrypted != null
              ? WireParsers.asMap(
                  await _encryption.decryptRaw(currentSettingsEncrypted),
                )
              : null;
          if (generation != _generation) return;
          final serverSettings = serverSettingsMap != null
              ? Settings.fromJsonWithFallback(
                  serverSettingsMap,
                  _settingsSnapshot,
                )
              : _settingsSnapshot;
          _settingsSnapshot = Settings.fromJson(<String, dynamic>{
            ...serverSettings.toJson(),
            ..._pendingSettings,
          });
          _settingsVersion = currentVersion;
          _onDataChanged({SyncDomain.settings});
          // Re-enter through InvalidateSync's bounded retry/backoff. A GET
          // here would overwrite the optimistic snapshot and finish without
          // posting the rebased delta.
          throw StateError('Settings version conflict; retry pending edits');
        } else {
          throw StateError('Settings write was not acknowledged');
        }
      }

      // Fetch latest settings — skip after a successful POST.
      if (!postedSuccessfully) {
        try {
          final response = await apiClient
              .get('/v1/account/settings')
              .timeout(const Duration(seconds: 10));
          if (generation != _generation) return;

          if (apiClient.isSuccess(response)) {
            final data = WireParsers.asMap(response.data);
            final encryptedSettings = data?['settings'] as String?;

            if (encryptedSettings != null) {
              final decrypted = WireParsers.asMap(
                await _encryption.decryptRaw(encryptedSettings),
              );
              if (generation != _generation) return;
              if (decrypted != null) {
                final fetched = Settings.fromJsonWithFallback(
                  decrypted,
                  _settingsSnapshot,
                );
                _settingsSnapshot = Settings.fromJson({
                  ...fetched.toJson(),
                  ..._pendingSettings,
                });
                _settingsVersion =
                    _asInt(data?['settingsVersion']) ?? _settingsVersion;
                _onDataChanged({SyncDomain.settings});
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
        } on TimeoutException {
          // This is a successful stale-data fallback, not data loss. Keep it
          // out of warning/Sentry issue reporting; connectivity telemetry
          // already captures the surrounding outage.
          logger.info(
            'Settings fetch timed out after 10s; using cached settings',
          );
        }
      }
    } catch (error) {
      if (generation != _generation) return;
      // HTTP owns the cancellable write deadline. Let InvalidateSync retry
      // failed writes, including conflicts after an ambiguous server commit.
      rethrow;
    }
  }

  /// Apply a settings delta. The delta is merged into pending settings and
  /// the settings sync is invalidated so the next cycle posts it.
  Future<void> applySettings(Map<String, dynamic> delta) async {
    _settingsSnapshot = Settings.fromJson({
      ..._settingsSnapshot.toJson(),
      ...delta,
    });
    for (final entry in delta.entries) {
      _pendingSettings[entry.key] = entry.value;
    }
    _settingsSyncGetter().invalidate();
  }

  /// Sync purchases — piggybacks on profile sync.
  Future<void> syncPurchases() async {
    await _profileSyncGetter().awaitQueue();
  }

  /// Fetch profile from server. Also extracts purchases data.
  Future<void> fetchProfile() async {
    final generation = _generation;
    logger.info('Fetching profile...');

    try {
      final apiClient = _client;

      // Bound the fetch so a stalled connection cannot hang the bootstrap
      // fan-out (profile fires alongside settings/machines/sessions on
      // cold start/resume). On timeout we keep the cached profile — the
      // same graceful-fallback pattern syncSettings() uses — so the UI
      // renders stale-but-present data instead of blocking.
      final response = await apiClient
          .get('/v1/account/profile')
          .timeout(const Duration(seconds: 10));
      if (generation != _generation) return;

      if (apiClient.isSuccess(response)) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          _profile = Profile.fromJson(data);
          _purchases = Purchases.parse(data['purchases']);
          _onDataChanged({SyncDomain.profile, SyncDomain.settings});
        } else {
          logger.warning(
            'Failed to fetch profile: invalid response type '
            '${data.runtimeType}',
          );
        }
      } else {
        logger.warning('Failed to fetch profile: ${response.statusCode}');
      }
    } on TimeoutException {
      // Cached profile data remains usable, so this is expected degraded
      // operation rather than an actionable warning/Sentry issue.
      logger.info('Profile fetch timed out after 10s; using cached profile');
    } on DioException {
      rethrow;
    } catch (error, stack) {
      if (generation != _generation) return;
      logger.error('Error fetching profile', error, stack);
    }
  }

  /// Refresh profile data.
  Future<void> refreshProfile() async {
    await _profileSyncGetter().invalidateAndAwait();
  }

  /// Refresh purchases data.
  Future<void> refreshPurchases() async {
    _purchasesSyncGetter().invalidate();
  }

  /// Fetch native app update status.
  Future<void> fetchNativeUpdate() async {
    final generation = _generation;
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

    final lastFetched = _lastNativeUpdateFetchedAt;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (lastFetched != null && nowMs - lastFetched < _nativeUpdateFreshnessMs) {
      logger.debug(
        'Skipping native update fetch '
        '(${(nowMs - lastFetched) ~/ 1000}s since last)',
      );
      return;
    }

    logger.info('Fetching native update...');

    try {
      final apiClient = _client;
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
      if (generation != _generation) return;
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
      _lastNativeUpdateFetchedAt = nowMs;
    } catch (error, stack) {
      if (generation != _generation) return;
      if (_isTransientConnectionError(error)) {
        logger.info('Native update fetch aborted (transient): $error');
      } else {
        logger.error('Failed to fetch native update', error, stack);
      }
      _nativeUpdateUrl = null;
    }
  }

  /// Register or refresh device push token.
  Future<void> syncPushToken() async {
    final generation = _generation;
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
      if (generation != _generation) return;
      if (notificationSettings.authorizationStatus ==
          AuthorizationStatus.notDetermined) {
        notificationSettings = await messaging.requestPermission();
        if (generation != _generation) return;
      }
      if (notificationSettings.authorizationStatus ==
              AuthorizationStatus.denied ||
          notificationSettings.authorizationStatus ==
              AuthorizationStatus.notDetermined) {
        return;
      }

      if (_registeredPushToken != null) {
        return;
      }

      final token = await messaging.getToken();
      if (generation != _generation) return;
      if (token == null || token.isEmpty) {
        return;
      }

      if (_registeredPushToken == token) {
        return;
      }

      await PushApi().registerToken(token);
      if (generation != _generation) return;
      _registeredPushToken = token;
    } catch (error, stack) {
      if (generation != _generation) return;
      logger.error('Failed to sync push token', error, stack);
    }
  }

  /// Clears all managed state.
  void clear() {
    _generation++;
    _settingsOpQueue = null;
    _settingsSnapshot = Settings();
    _settingsVersion = 0;
    _pendingSettings.clear();
    _lastSettingsPostAtMs = null;
    _profile = null;
    _purchases = Purchases.defaults;
    _registeredPushToken = null;
    _nativeUpdateUrl = null;
    _lastNativeUpdateFetchedAt = null;
  }
}
