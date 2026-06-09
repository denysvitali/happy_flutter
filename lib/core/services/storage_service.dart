import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../models/auth.dart';
import '../models/settings.dart';
import '../models/settings_update.dart';
import 'logger_service.dart' show logger;
import 'mmkv_storage.dart';
import 'server_config_storage.dart';

/// Secure storage for authentication credentials
class TokenStorage {
  factory TokenStorage() => _instance;
  TokenStorage._();
  static final TokenStorage _instance = TokenStorage._();

  static const String _authKey = 'auth_credentials';

  final _secureStorage = const FlutterSecureStorage();
  AuthCredentials? _cachedCredentials;

  /// Get credentials from secure storage
  Future<AuthCredentials?> getCredentials() async {
    if (_cachedCredentials != null) {
      return _cachedCredentials;
    }

    try {
      final stored = await _secureStorage.read(key: _authKey);
      if (stored == null) return null;

      final credentials = AuthCredentials.fromJson(
        jsonDecode(stored) as Map<String, dynamic>,
      );
      _cachedCredentials = credentials;
      return credentials;
    } catch (e, stack) {
      if (_isSecureStorageReadCorruption(e)) {
        await _deleteCorruptSecureValue(
          storage: _secureStorage,
          key: _authKey,
          label: 'credentials',
          error: e,
          stack: stack,
        );
        _cachedCredentials = null;
        return null;
      }
      logger.error('Error getting credentials', e, stack);
      return null;
    }
  }

  /// Store credentials securely
  Future<bool> setCredentials(AuthCredentials credentials) async {
    try {
      final json = jsonEncode(credentials.toJson());
      await _secureStorage.write(key: _authKey, value: json);
      _cachedCredentials = credentials;
      return true;
    } catch (e, stack) {
      logger.error('Error setting credentials', e, stack);
      return false;
    }
  }

  /// Remove credentials
  Future<bool> removeCredentials() async {
    try {
      await _secureStorage.delete(key: _authKey);
      _cachedCredentials = null;
      return true;
    } catch (e, stack) {
      logger.error('Error removing credentials', e, stack);
      return false;
    }
  }

  /// Check if authenticated
  Future<bool> isAuthenticated() async {
    final credentials = await getCredentials();
    return credentials != null;
  }
}

bool _isSecureStorageReadCorruption(Object error) {
  final text = error.toString();
  return error is PlatformException &&
      error.message == 'read' &&
      (text.contains('IllegalBlockSizeException') ||
          text.contains('BadPaddingException') ||
          text.contains('WRONG_FINAL_BLOCK_LENGTH') ||
          text.contains('AEADBadTagException'));
}

Future<void> _deleteCorruptSecureValue({
  required FlutterSecureStorage storage,
  required String key,
  required String label,
  required Object error,
  required StackTrace stack,
}) async {
  logger.warning(
    'Secure storage value for $label is unreadable; clearing it',
    error,
    stack,
  );
  try {
    await storage.delete(key: key);
  } catch (deleteError, deleteStack) {
    logger.error(
      'Failed to clear unreadable secure storage value for $label',
      deleteError,
      deleteStack,
    );
  }
}

/// Settings storage with persistence using MMKV
class SettingsStorage {
  factory SettingsStorage() => _instance;
  SettingsStorage._();
  static final SettingsStorage _instance = SettingsStorage._();

  /// MMKV key for the "api-key migration completed" flag.
  ///
  /// Bumping [_apiKeyMigrationVersion] forces the migration to re-run
  /// (e.g. if the migration shape changes). The flag short-circuits the
  /// hot path on subsequent launches once a given version has run
  /// successfully, eliminating a small amount of CPU on every cold start.
  static const String _apiKeyMigrationFlagKey = 'api-key-migration-version';
  static const int _apiKeyMigrationVersion = 1;

  final _storage = MMKVStorage();
  final _apiKeyStorage = APIKeyStorage();
  bool _migrationChecked = false;
  Settings? _cachedSettings;

  /// Profile IDs whose API keys have already been hydrated from
  /// secure storage into [_cachedSettings]. Tracked separately so
  /// repeat hydrations are cheap (no secure-storage round-trip).
  final Set<String> _hydratedProfileIds = <String>{};

  /// True once the (process-wide) inference OpenAI key has been
  /// hydrated into [_cachedSettings].
  bool _inferenceKeyHydrated = false;

  // Debounce timer for settings updates to reduce MMKV writes
  Timer? _debounceTimer;
  static const Duration _debounceDelay = Duration(milliseconds: 500);

  /// Get settings from storage.
  ///
  /// **Cold-start optimization**: API keys are NOT loaded eagerly. The
  /// returned settings expose profiles with `apiKey: null`. Call
  /// [hydrateProfileApiKeys] to populate keys for a specific profile on
  /// demand (typically when spawning a session that uses that profile).
  ///
  /// This avoids N sequential FlutterSecureStorage reads (≈50–150ms each
  /// on Android) on every cold start for users with multiple profiles —
  /// a significant contributor to the production cold-start p95 of ~9s.
  Future<Settings> getSettings() async {
    final cachedSettings = _cachedSettings;
    if (cachedSettings != null) {
      return _cloneSettings(cachedSettings);
    }

    final settings = await _storage.getSettings();

    // Perform one-time migration if needed
    if (!_migrationChecked) {
      await _performMigrationIfNeeded(settings);
      _migrationChecked = true;
    }

    _cacheSettings(settings);
    return _cloneSettings(settings);
  }

  /// Get settings from MMKV only, without hydrating API keys from secure
  /// storage. Useful on startup when only local UI settings are needed.
  ///
  /// Equivalent to [getSettings] now that API key hydration is lazy, but
  /// kept as a distinct entry point for call sites that explicitly want
  /// to communicate "I don't need API keys".
  Future<Settings> getLocalSettings() async {
    final settings = await _storage.getSettings();
    if (!_migrationChecked) {
      await _performMigrationIfNeeded(settings);
      _migrationChecked = true;
    }
    _cacheSettings(settings);
    return _cloneSettings(settings);
  }

  /// Eagerly hydrate every profile's API key from secure storage.
  ///
  /// Use sparingly — only for screens that need to display or edit
  /// every key at once (e.g. settings editor). The session-spawn path
  /// should use [hydrateProfileApiKeys] instead so it only pays the
  /// cost for the profile actually being used.
  Future<Settings> getSettingsWithApiKeys() async {
    final settings = await getSettings();
    await _loadAPIKeysIntoSettings(settings);
    _cacheSettings(settings);
    for (final p in settings.profiles) {
      _hydratedProfileIds.add(p.id);
    }
    _inferenceKeyHydrated = true;
    return _cloneSettings(settings);
  }

  /// Hydrate API keys for a single profile from secure storage.
  ///
  /// Idempotent: returns immediately if the profile's keys have already
  /// been loaded. Mutates the in-memory cache so subsequent [getSettings]
  /// callers see the populated keys.
  ///
  /// Returns the hydrated profile (or null if the profile is not in the
  /// current settings). Designed for the session-spawn hot path so we
  /// pay one secure-storage round-trip per profile, the first time it
  /// is used.
  Future<AIBackendProfile?> hydrateProfileApiKeys(String profileId) async {
    if (_hydratedProfileIds.contains(profileId)) {
      final cached = _cachedSettings;
      if (cached != null) {
        for (final p in cached.profiles) {
          if (p.id == profileId) return _cloneProfile(p);
        }
      }
      return null;
    }

    // Ensure base settings are loaded.
    final cached = _cachedSettings ?? await () async {
      await getSettings();
      return _cachedSettings;
    }();
    if (cached == null) return null;

    AIBackendProfile? target;
    for (final p in cached.profiles) {
      if (p.id == profileId) {
        target = p;
        break;
      }
    }
    if (target == null) return null;

    final hydrated = await _profileWithApiKeys(target);
    // Replace the cached profile in-place so subsequent reads pick up
    // the populated keys.
    cached.profiles = [
      for (final p in cached.profiles)
        if (p.id == profileId) hydrated else p,
    ];
    _hydratedProfileIds.add(profileId);
    return _cloneProfile(hydrated);
  }

  /// Hydrate the inference OpenAI key (used by `inferenceOpenAIKey`,
  /// not tied to a specific profile).
  Future<String?> hydrateInferenceOpenAIKey() async {
    if (_inferenceKeyHydrated) {
      return _cachedSettings?.inferenceOpenAIKey;
    }
    final key = await _apiKeyStorage.getInferenceOpenAIKey();
    final cached = _cachedSettings;
    if (cached != null) {
      cached.inferenceOpenAIKey = key;
    }
    _inferenceKeyHydrated = true;
    return key;
  }

  @visibleForTesting
  bool isProfileHydrated(String profileId) =>
      _hydratedProfileIds.contains(profileId);

  AIBackendProfile _cloneProfile(AIBackendProfile profile) {
    return AIBackendProfile.fromJson(profile.toJson());
  }

  /// Check if migration is needed and perform it
  Future<void> _performMigrationIfNeeded(Settings settings) async {
    // Fast-path: if we've already completed migration at the current
    // schema version on a previous launch, skip the in-memory scan of
    // every profile's API key fields.
    try {
      final completed = _storage.getString(_apiKeyMigrationFlagKey);
      if (completed != null) {
        final v = int.tryParse(completed);
        if (v != null && v >= _apiKeyMigrationVersion) {
          return;
        }
      }
    } catch (e) {
      // Defensive: if the MMKV read throws (e.g. in tests with a stub
      // platform), fall through to the legacy scan path rather than
      // skipping migration entirely.
      logger.info('SettingsStorage: migration flag read failed: $e');
    }

    // Check if there are API keys in the settings (old format)
    final needsMigration =
        settings.inferenceOpenAIKey != null ||
        settings.profiles.any(
          (p) =>
              p.openaiConfig?.apiKey != null ||
              p.azureOpenAIConfig?.apiKey != null ||
              p.togetherAIConfig?.apiKey != null,
        );

    if (needsMigration) {
      logger.info('SettingsStorage: Migrating API keys to secure storage');
      await _apiKeyStorage.migrateFromSettings(settings);

      // Clear API keys from settings and save
      settings.inferenceOpenAIKey = null;

      // Create new profiles list with cleared API keys
      final updatedProfiles = <AIBackendProfile>[];
      for (final profile in settings.profiles) {
        // Create new config instances without API keys using copyWith
        OpenAIConfig? newOpenAIConfig;
        AzureOpenAIConfig? newAzureConfig;
        TogetherAIConfig? newTogetherConfig;

        if (profile.openaiConfig != null) {
          newOpenAIConfig = OpenAIConfig(
            baseUrl: profile.openaiConfig!.baseUrl,
            model: profile.openaiConfig!.model,
          );
        }
        if (profile.azureOpenAIConfig != null) {
          newAzureConfig = AzureOpenAIConfig(
            endpoint: profile.azureOpenAIConfig!.endpoint,
            apiVersion: profile.azureOpenAIConfig!.apiVersion,
            deploymentName: profile.azureOpenAIConfig!.deploymentName,
          );
        }
        if (profile.togetherAIConfig != null) {
          newTogetherConfig = TogetherAIConfig(
            model: profile.togetherAIConfig!.model,
          );
        }

        updatedProfiles.add(
          profile.copyWith(
            openaiConfig: newOpenAIConfig,
            azureOpenAIConfig: newAzureConfig,
            togetherAIConfig: newTogetherConfig,
          ),
        );
      }
      settings.profiles = updatedProfiles;

      // Save the cleaned settings back to MMKV
      await _storage.saveSettings(settings);
      logger.info('SettingsStorage: API key migration complete');
    }

    // Persist the "migration completed" flag so subsequent launches
    // can short-circuit the in-memory scan above. Even when no
    // migration was needed this run, we still set the flag — the
    // determination ("no inline keys present") is itself the result
    // we want to cache.
    try {
      _storage.setString(
        _apiKeyMigrationFlagKey,
        _apiKeyMigrationVersion.toString(),
      );
    } catch (e) {
      // Non-fatal: flag persistence is purely a perf optimization.
      logger.info('SettingsStorage: migration flag write failed: $e');
    }
  }

  /// Load API keys from secure storage into settings object
  Future<void> _loadAPIKeysIntoSettings(Settings settings) async {
    final inferenceKeyFuture = _apiKeyStorage.getInferenceOpenAIKey();
    final updatedProfilesFuture = Future.wait(
      settings.profiles.map(_profileWithApiKeys),
    );

    settings
      ..inferenceOpenAIKey = await inferenceKeyFuture
      ..profiles = await updatedProfilesFuture;
  }

  Future<AIBackendProfile> _profileWithApiKeys(AIBackendProfile profile) async {
    // Start all API key fetches in parallel
    final openAIKeyFuture = profile.openaiConfig != null
        ? _apiKeyStorage.getOpenAIConfigKey(profile.id)
        : Future<String?>.value(null);
    final azureKeyFuture = profile.azureOpenAIConfig != null
        ? _apiKeyStorage.getAzureOpenAIConfigKey(profile.id)
        : Future<String?>.value(null);
    final togetherAIKeyFuture = profile.togetherAIConfig != null
        ? _apiKeyStorage.getTogetherAIConfigKey(profile.id)
        : Future<String?>.value(null);

    // Wait for all keys in parallel (not sequential)
    final results = await Future.wait([
      openAIKeyFuture,
      azureKeyFuture,
      togetherAIKeyFuture,
    ]);

    final openAIKey = results[0];
    final azureKey = results[1];
    final togetherAIKey = results[2];

    return profile.copyWith(
      openaiConfig: profile.openaiConfig != null && openAIKey != null
          ? OpenAIConfig(
              apiKey: openAIKey,
              baseUrl: profile.openaiConfig!.baseUrl,
              model: profile.openaiConfig!.model,
            )
          : null,
      azureOpenAIConfig: profile.azureOpenAIConfig != null && azureKey != null
          ? AzureOpenAIConfig(
              apiKey: azureKey,
              endpoint: profile.azureOpenAIConfig!.endpoint,
              apiVersion: profile.azureOpenAIConfig!.apiVersion,
              deploymentName: profile.azureOpenAIConfig!.deploymentName,
            )
          : null,
      togetherAIConfig:
          profile.togetherAIConfig != null && togetherAIKey != null
          ? TogetherAIConfig(
              apiKey: togetherAIKey,
              model: profile.togetherAIConfig!.model,
            )
          : null,
    );
  }

  Settings _cloneSettings(Settings settings) {
    // Shallow clone — top-level primitives copied by value, collection
    // fields copied into fresh List/Map instances so callers can mutate
    // them without leaking back into the cached snapshot. Element
    // objects (e.g. AIBackendProfile) are shared since their fields are
    // final.
    //
    // Replaces `Settings.fromJson(settings.toJson())`, which round-
    // tripped through JSON encoding for the same effect on every cache
    // read/write and accounted for ~30% of settings-related allocations
    // (perf #11).
    return settings.shallowClone();
  }

  void _cacheSettings(Settings settings) {
    _cachedSettings = _cloneSettings(settings);
  }

  /// Save settings to storage
  /// API keys are saved to secure storage, not MMKV
  Future<void> saveSettings(Settings settings) async {
    // Save API keys to secure storage first
    await _saveAPIKeysFromSettings(settings);

    // Create a copy without API keys for MMKV storage
    final settingsForStorage = _createSettingsCopyWithoutApiKeys(settings);
    await _storage.saveSettings(settingsForStorage);
    _cacheSettings(settings);
    // Any profile we just persisted has its key in secure storage
    // *and* in the in-memory cache, so subsequent reads should not
    // need to re-hit secure storage.
    for (final p in settings.profiles) {
      _hydratedProfileIds.add(p.id);
    }
    if (settings.inferenceOpenAIKey != null) {
      _inferenceKeyHydrated = true;
    }
  }

  /// Save API keys from settings to secure storage
  Future<void> _saveAPIKeysFromSettings(Settings settings) async {
    // Save inference OpenAI key
    if (settings.inferenceOpenAIKey != null) {
      await _apiKeyStorage.setInferenceOpenAIKey(settings.inferenceOpenAIKey);
    }

    // Save profile-specific API keys
    for (final profile in settings.profiles) {
      if (profile.openaiConfig?.apiKey != null) {
        await _apiKeyStorage.setOpenAIConfigKey(
          profile.id,
          profile.openaiConfig!.apiKey,
        );
      }
      if (profile.azureOpenAIConfig?.apiKey != null) {
        await _apiKeyStorage.setAzureOpenAIConfigKey(
          profile.id,
          profile.azureOpenAIConfig!.apiKey,
        );
      }
      if (profile.togetherAIConfig?.apiKey != null) {
        await _apiKeyStorage.setTogetherAIConfigKey(
          profile.id,
          profile.togetherAIConfig!.apiKey,
        );
      }
    }
  }

  /// Create a copy of settings without API keys for MMKV storage.
  ///
  /// `MMKVStorage.saveSettings` persists via `settings.toJson()`, which
  /// already strips profile API keys (see `Settings.toJson` →
  /// `AIBackendProfile.toJsonWithoutApiKeys`). The MMKV layer never
  /// observes API keys regardless of what is passed in, so a shallow
  /// clone is sufficient — we don't need a `fromJson(toJson())` round-
  /// trip to materially scrub the in-memory object (perf #11).
  Settings _createSettingsCopyWithoutApiKeys(Settings settings) {
    return settings.shallowClone();
  }

  /// Update a single setting
  Future<void> updateSetting<T>(String key, T value) async {
    final current = await getSettings();

    // Handle API key fields specially
    if (key == 'inferenceOpenAIKey') {
      await _apiKeyStorage.setInferenceOpenAIKey(value as String?);
      // Update in-memory settings but don't save to MMKV
      current.inferenceOpenAIKey = value as String?;
      _cacheSettings(current);
      return;
    }

    try {
      SettingsUpdate.applyMutable(current, key, value);
    } on UnknownSettingsKeyException catch (e) {
      // Forward/backward compatibility: a settings key that no longer
      // exists in this build (e.g. renamed/removed in a newer version,
      // or echoed back by the server for an older client) must not
      // crash the app. Drop the key and continue.
      // Regression guard for GlitchTip HAPPY_FLUTTER-3C6 (ttsUseOffline
      // crash on build 152201): never let a stale key reach an
      // ArgumentError throw on a production hot path.
      logger.warning(
        'Dropping unknown settings key "${e.key}" from storage write',
      );
      unawaited(
        Sentry.addBreadcrumb(
          Breadcrumb(
            message: 'Settings: dropped unknown key from storage write',
            category: 'settings.unknownKey',
            level: SentryLevel.warning,
            data: {'key': e.key},
          ),
        ),
      );
      return;
    }
    final updated = current;

    // Cancel existing debounce timer and start a new one
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, () async {
      await saveSettings(updated);
      _debounceTimer = null;
    });

    // Update cache immediately so in-memory reads are consistent
    _cacheSettings(updated);
  }

  /// Clear all settings
  Future<void> clearSettings() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    await _storage.clearSettings();
    // Reset hydration tracking — a future re-login may pull different
    // profiles, and we must not assume their keys are already in cache.
    _hydratedProfileIds.clear();
    _inferenceKeyHydrated = false;
    _cachedSettings = null;
  }

  /// Test-only hook so unit tests can re-exercise the migration flag
  /// path on a single [SettingsStorage] singleton.
  @visibleForTesting
  void resetForTests() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _hydratedProfileIds.clear();
    _inferenceKeyHydrated = false;
    _cachedSettings = null;
    _migrationChecked = false;
  }

  /// Suspend the debounce timer when app goes to background.
  /// Cancels any pending settings write without saving (settings remain
  /// in-memory and will be saved on next change or app exit).
  void suspend() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// Dispose of the debounce timer
  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }
}

/// Session permission modes storage with MMKV
class SessionPermissionModesStorage {
  factory SessionPermissionModesStorage() => _instance;
  SessionPermissionModesStorage._();
  static final SessionPermissionModesStorage _instance =
      SessionPermissionModesStorage._();

  final _storage = MMKVStorage();

  /// Get permission mode for a specific session
  Future<String?> getPermissionMode(String sessionId) async {
    return _storage.getSessionPermissionMode(sessionId);
  }

  /// Save permission mode for a specific session
  Future<void> savePermissionMode(String sessionId, String mode) async {
    await _storage.saveSessionPermissionMode(sessionId, mode);
  }

  /// Get model mode for a specific session
  Future<String?> getModelMode(String sessionId) async {
    return _storage.getSessionModelMode(sessionId);
  }

  /// Save model mode for a specific session
  Future<void> saveModelMode(String sessionId, String mode) async {
    await _storage.saveSessionModelMode(sessionId, mode);
  }

  /// Remove permission mode for a specific session
  Future<void> removePermissionMode(String sessionId) async {
    await _storage.removeSessionPermissionMode(sessionId);
  }

  /// Get all session permission modes
  Future<Map<String, String>> getAllPermissionModes() async {
    return _storage.getSessionPermissionModes();
  }

  /// Clear all session permission modes
  Future<void> clearAllPermissionModes() async {
    await _storage.clearSessionPermissionModes();
  }
}

/// Secure storage for API keys
class APIKeyStorage {
  factory APIKeyStorage() => _instance;
  APIKeyStorage._();
  static final APIKeyStorage _instance = APIKeyStorage._();

  final _secureStorage = const FlutterSecureStorage();

  // Secure storage keys for API keys
  static const String _inferenceOpenAIKey = 'inference_openai_key';
  static const String _openAIConfigKeyPrefix = 'openai_config_key_';
  static const String _azureOpenAIConfigKeyPrefix = 'azure_openai_config_key_';
  static const String _togetherAIConfigKeyPrefix = 'togetherai_config_key_';

  /// Store the inference OpenAI API key
  Future<bool> setInferenceOpenAIKey(String? apiKey) async {
    try {
      if (apiKey != null && apiKey.isNotEmpty) {
        await _secureStorage.write(key: _inferenceOpenAIKey, value: apiKey);
      } else {
        await _secureStorage.delete(key: _inferenceOpenAIKey);
      }
      return true;
    } catch (e, stack) {
      logger.error('Error storing inference OpenAI key', e, stack);
      return false;
    }
  }

  /// Get the inference OpenAI API key
  Future<String?> getInferenceOpenAIKey() async {
    try {
      return await _secureStorage.read(key: _inferenceOpenAIKey);
    } catch (e, stack) {
      if (_isSecureStorageReadCorruption(e)) {
        await _deleteCorruptSecureValue(
          storage: _secureStorage,
          key: _inferenceOpenAIKey,
          label: 'inference OpenAI key',
          error: e,
          stack: stack,
        );
        return null;
      }
      logger.error('Error getting inference OpenAI key', e, stack);
      return null;
    }
  }

  /// Store OpenAI config API key for a profile
  Future<bool> setOpenAIConfigKey(String profileId, String? apiKey) async {
    try {
      final key = '$_openAIConfigKeyPrefix$profileId';
      if (apiKey != null && apiKey.isNotEmpty) {
        await _secureStorage.write(key: key, value: apiKey);
      } else {
        await _secureStorage.delete(key: key);
      }
      return true;
    } catch (e, stack) {
      logger.error('Error storing OpenAI config key', e, stack);
      return false;
    }
  }

  /// Get OpenAI config API key for a profile
  Future<String?> getOpenAIConfigKey(String profileId) async {
    final key = '$_openAIConfigKeyPrefix$profileId';
    try {
      return await _secureStorage.read(key: key);
    } catch (e, stack) {
      if (_isSecureStorageReadCorruption(e)) {
        await _deleteCorruptSecureValue(
          storage: _secureStorage,
          key: key,
          label: 'OpenAI config key',
          error: e,
          stack: stack,
        );
        return null;
      }
      logger.error('Error getting OpenAI config key', e, stack);
      return null;
    }
  }

  /// Store Azure OpenAI config API key for a profile
  Future<bool> setAzureOpenAIConfigKey(String profileId, String? apiKey) async {
    try {
      final key = '$_azureOpenAIConfigKeyPrefix$profileId';
      if (apiKey != null && apiKey.isNotEmpty) {
        await _secureStorage.write(key: key, value: apiKey);
      } else {
        await _secureStorage.delete(key: key);
      }
      return true;
    } catch (e, stack) {
      logger.error('Error storing Azure OpenAI config key', e, stack);
      return false;
    }
  }

  /// Get Azure OpenAI config API key for a profile
  Future<String?> getAzureOpenAIConfigKey(String profileId) async {
    final key = '$_azureOpenAIConfigKeyPrefix$profileId';
    try {
      return await _secureStorage.read(key: key);
    } catch (e, stack) {
      if (_isSecureStorageReadCorruption(e)) {
        await _deleteCorruptSecureValue(
          storage: _secureStorage,
          key: key,
          label: 'Azure OpenAI config key',
          error: e,
          stack: stack,
        );
        return null;
      }
      logger.error('Error getting Azure OpenAI config key', e, stack);
      return null;
    }
  }

  /// Store TogetherAI config API key for a profile
  Future<bool> setTogetherAIConfigKey(String profileId, String? apiKey) async {
    try {
      final key = '$_togetherAIConfigKeyPrefix$profileId';
      if (apiKey != null && apiKey.isNotEmpty) {
        await _secureStorage.write(key: key, value: apiKey);
      } else {
        await _secureStorage.delete(key: key);
      }
      return true;
    } catch (e, stack) {
      logger.error('Error storing TogetherAI config key', e, stack);
      return false;
    }
  }

  /// Get TogetherAI config API key for a profile
  Future<String?> getTogetherAIConfigKey(String profileId) async {
    final key = '$_togetherAIConfigKeyPrefix$profileId';
    try {
      return await _secureStorage.read(key: key);
    } catch (e, stack) {
      if (_isSecureStorageReadCorruption(e)) {
        await _deleteCorruptSecureValue(
          storage: _secureStorage,
          key: key,
          label: 'TogetherAI config key',
          error: e,
          stack: stack,
        );
        return null;
      }
      logger.error('Error getting TogetherAI config key', e, stack);
      return null;
    }
  }

  /// Clear all API keys (used during logout)
  Future<bool> clearAllAPIKeys() async {
    try {
      // Get all keys
      final allKeys = await _secureStorage.readAll();
      // Delete only API key entries
      for (final entry in allKeys.entries) {
        if (entry.key.startsWith(_openAIConfigKeyPrefix) ||
            entry.key.startsWith(_azureOpenAIConfigKeyPrefix) ||
            entry.key.startsWith(_togetherAIConfigKeyPrefix) ||
            entry.key == _inferenceOpenAIKey) {
          await _secureStorage.delete(key: entry.key);
        }
      }
      return true;
    } catch (e, stack) {
      logger.error('Error clearing API keys', e, stack);
      return false;
    }
  }

  /// Migrate API keys from settings to secure storage
  /// Returns true if migration was successful or not needed
  Future<bool> migrateFromSettings(Settings settings) async {
    try {
      // Migrate inference OpenAI key
      if (settings.inferenceOpenAIKey != null &&
          settings.inferenceOpenAIKey!.isNotEmpty) {
        await setInferenceOpenAIKey(settings.inferenceOpenAIKey);
      }

      // Migrate profile-specific API keys
      for (final profile in settings.profiles) {
        if (profile.openaiConfig?.apiKey != null) {
          await setOpenAIConfigKey(profile.id, profile.openaiConfig!.apiKey);
        }
        if (profile.azureOpenAIConfig?.apiKey != null) {
          await setAzureOpenAIConfigKey(
            profile.id,
            profile.azureOpenAIConfig!.apiKey,
          );
        }
        if (profile.togetherAIConfig?.apiKey != null) {
          await setTogetherAIConfigKey(
            profile.id,
            profile.togetherAIConfig!.apiKey,
          );
        }
      }

      return true;
    } catch (e, stack) {
      logger.error('Error migrating API keys', e, stack);
      return false;
    }
  }
}

/// Combined storage for app data
class Storage {
  factory Storage() => _instance;
  Storage._();
  static final Storage _instance = Storage._();

  final tokenStorage = TokenStorage();
  final apiKeyStorage = APIKeyStorage();
  final settingsStorage = SettingsStorage();
  final sessionPermissionModesStorage = SessionPermissionModesStorage();
  final profileStorage = ProfileStorage();

  /// Initialize all storage.
  ///
  /// MMKVStorage and ServerConfigStorage are independent (each calls the
  /// idempotent `MMKV.initialize()` itself) so we run them in parallel to
  /// shave a few hundred ms off cold start.
  Future<void> initialize() async {
    await Future.wait<void>([
      MMKVStorage.initialize(),
      ServerConfigStorage.initialize(),
    ]);
  }

  /// Clear all storage (except server config which persists across logouts)
  Future<void> clearAll() async {
    await tokenStorage.removeCredentials();
    await settingsStorage.clearSettings();
    await MMKVStorage().clearSessionDrafts();
    await sessionPermissionModesStorage.clearAllPermissionModes();
    await profileStorage.clearProfile();
    unawaited(MMKVStorage().clearAll());
    // Note: ServerConfigStorage is NOT cleared here as it
  }

  /// Clear server config separately (typically not called during logout)
  Future<void> clearServerConfig() async {
    unawaited(ServerConfigStorage().clearAll());
  }

  /// Check if this is a fresh install or an upgrade and return
  /// changelog info if needed.
  ///
  /// Call this after storage is initialized and you have the current
  /// app version. Returns a record of (previousVersion, currentVersion)
  /// if the changelog should be shown, null otherwise.
  ({String? fromVersion, String toVersion})? checkVersionChange(
    String currentVersion,
  ) {
    final storage = MMKVStorage();
    final installed = storage.getInstalledVersion();

    if (installed == null) {
      // First install — no changelog to show
      storage.setInstalledVersion(currentVersion);
      return null;
    }

    if (installed != currentVersion) {
      storage.setInstalledVersion(currentVersion);
      return (fromVersion: installed, toVersion: currentVersion);
    }

    return null;
  }
}
