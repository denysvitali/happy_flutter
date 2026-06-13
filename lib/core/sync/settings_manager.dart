import 'dart:async' show unawaited;

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
import '../utils/invalidate_sync.dart';
import '../utils/sync_domain.dart';
import '../utils/wire_parsers.dart';

/// Manages settings, profile, purchases, push token, and native update
/// synchronization. Extracted from the Sync god object.
class SettingsManager {
  SettingsManager({
    required Encryption encryption,
    required int nativeUpdateFreshnessMs,
    required bool Function(Object) isTransientConnectionError,
    required InvalidateSync Function() settingsSyncGetter,
    required InvalidateSync Function() profileSyncGetter,
    required InvalidateSync Function() purchasesSyncGetter,
    required void Function(Set<SyncDomain>) onDataChanged,
  })  : _encryption = encryption,
        _nativeUpdateFreshnessMs = nativeUpdateFreshnessMs,
        _isTransientConnectionError = isTransientConnectionError,
        _settingsSyncGetter = settingsSyncGetter,
        _profileSyncGetter = profileSyncGetter,
        _purchasesSyncGetter = purchasesSyncGetter,
        _onDataChanged = onDataChanged;

  final Encryption _encryption;
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
  Future<void> syncSettings() async {
    logger.info('Syncing settings...');

    try {
      final apiClient = ApiClient();

      // Apply pending settings
      var postedSuccessfully = false;
      if (_pendingSettings.isNotEmpty) {
        final mergedJson = <String, dynamic>{
          ..._settingsSnapshot.toJson(),
          ..._pendingSettings,
        };
        final mergedSettings = Settings.fromJson(mergedJson);
        final encryptedPending = await _encryption.encryptRaw(mergedJson);

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
          _pendingSettings.clear();
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
          final serverSettings = serverSettingsMap != null
              ? Settings.fromJsonWithFallback(
                  serverSettingsMap,
                  _settingsSnapshot,
                )
              : _settingsSnapshot;
          _settingsSnapshot = Settings.fromJson(
            <String, dynamic>{
              ...serverSettings.toJson(),
              ..._pendingSettings,
            },
          );
          _settingsVersion = currentVersion;
          _onDataChanged({SyncDomain.settings});
        }
      }

      // Fetch latest settings — skip after a successful POST.
      if (!postedSuccessfully) {
        final response = await apiClient.get('/v1/account/settings');

        if (apiClient.isSuccess(response)) {
          final data = WireParsers.asMap(response.data);
          final encryptedSettings = data?['settings'] as String?;

          if (encryptedSettings != null) {
            final decrypted = WireParsers.asMap(
              await _encryption.decryptRaw(encryptedSettings),
            );
            if (decrypted != null) {
              _settingsSnapshot = Settings.fromJsonWithFallback(
                decrypted,
                _settingsSnapshot,
              );
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
      }
    } on DioException {
      rethrow;
    } catch (error, stack) {
      logger.error('Error syncing settings', error, stack);
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
    logger.info('Fetching profile...');

    try {
      final apiClient = ApiClient();

      final response = await apiClient.get('/v1/account/profile');

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
    } on DioException {
      rethrow;
    } catch (error, stack) {
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
    if (lastFetched != null &&
        nowMs - lastFetched < _nativeUpdateFreshnessMs) {
      logger.debug(
        'Skipping native update fetch '
        '(${(nowMs - lastFetched) ~/ 1000}s since last)',
      );
      return;
    }

    logger.info('Fetching native update...');

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
      _lastNativeUpdateFetchedAt = nowMs;
    } catch (error, stack) {
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

  /// Clears all managed state.
  void clear() {
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
