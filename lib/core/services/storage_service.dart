import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth.dart';
import '../models/settings.dart';
import 'logger_service.dart' show logger;
import 'mmkv_storage.dart';

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
    } catch (e) {
      logger.warning('Error getting credentials: $e');
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
    } catch (e) {
      logger.warning('Error setting credentials: $e');
      return false;
    }
  }

  /// Remove credentials
  Future<bool> removeCredentials() async {
    try {
      await _secureStorage.delete(key: _authKey);
      _cachedCredentials = null;
      return true;
    } catch (e) {
      logger.warning('Error removing credentials: $e');
      return false;
    }
  }

  /// Check if authenticated
  Future<bool> isAuthenticated() async {
    final credentials = await getCredentials();
    return credentials != null;
  }
}

/// Settings storage with persistence using MMKV
class SettingsStorage {
  factory SettingsStorage() => _instance;
  SettingsStorage._();
  static final SettingsStorage _instance = SettingsStorage._();

  final _storage = MMKVStorage();
  final _apiKeyStorage = APIKeyStorage();
  bool _migrationChecked = false;
  Settings? _cachedSettings;

  // Debounce timer for settings updates to reduce MMKV writes
  Timer? _debounceTimer;
  static const Duration _debounceDelay = Duration(milliseconds: 500);

  /// Get settings from storage
  /// This loads API keys from secure storage and injects them into the settings
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

    // Load API keys from secure storage
    await _loadAPIKeysIntoSettings(settings);

    _cacheSettings(settings);
    return _cloneSettings(settings);
  }

  /// Check if migration is needed and perform it
  Future<void> _performMigrationIfNeeded(Settings settings) async {
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
    return Settings.fromJson(settings.toJson());
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

  /// Create a copy of settings without API keys for MMKV storage
  Settings _createSettingsCopyWithoutApiKeys(Settings settings) {
    final copy = Settings()
      ..schemaVersion = settings.schemaVersion
      ..themeMode = settings.themeMode
      ..viewInline = settings.viewInline
      // Don't copy inferenceOpenAIKey - it's in secure storage
      ..expandTodos = settings.expandTodos
      ..showLineNumbers = settings.showLineNumbers
      ..showLineNumbersInToolViews = settings.showLineNumbersInToolViews
      ..wrapLinesInDiffs = settings.wrapLinesInDiffs
      ..analyticsOptOut = settings.analyticsOptOut
      ..experiments = settings.experiments
      ..markdownCopyV2 = settings.markdownCopyV2
      ..useEnhancedSessionWizard = settings.useEnhancedSessionWizard
      ..alwaysShowContextSize = settings.alwaysShowContextSize
      ..agentInputEnterToSend = settings.agentInputEnterToSend
      ..developerModeEnabled = settings.developerModeEnabled
      ..avatarStyle = settings.avatarStyle
      ..showFlavorIcons = settings.showFlavorIcons
      ..compactSessionView = settings.compactSessionView
      ..hideInactiveSessions = settings.hideInactiveSessions
      ..reviewPromptAnswered = settings.reviewPromptAnswered
      ..reviewPromptLikedApp = settings.reviewPromptLikedApp
      ..ttsEnabled = settings.ttsEnabled
      ..voiceAssistantLanguage = settings.voiceAssistantLanguage
      ..preferredLanguage = settings.preferredLanguage
      ..recentMachinePaths = settings.recentMachinePaths
      ..lastUsedAgent = settings.lastUsedAgent
      ..lastUsedPermissionMode = settings.lastUsedPermissionMode
      ..lastUsedModelMode = settings.lastUsedModelMode
      ..profiles = settings.profiles
          .map((p) => _createProfileWithoutApiKeys(p))
          .toList()
      ..lastUsedProfile = settings.lastUsedProfile
      ..favoriteDirectories = settings.favoriteDirectories
      ..favoriteMachines = settings.favoriteMachines
      ..dismissedCLIWarnings = settings.dismissedCLIWarnings;

    return copy;
  }

  /// Create a copy of a profile without API keys
  AIBackendProfile _createProfileWithoutApiKeys(AIBackendProfile profile) {
    return AIBackendProfile(
      id: profile.id,
      name: profile.name,
      description: profile.description,
      anthropicConfig: profile.anthropicConfig,
      openaiConfig: profile.openaiConfig != null
          ? OpenAIConfig(
              baseUrl: profile.openaiConfig!.baseUrl,
              model: profile.openaiConfig!.model,
              // Don't copy apiKey
            )
          : null,
      azureOpenAIConfig: profile.azureOpenAIConfig != null
          ? AzureOpenAIConfig(
              endpoint: profile.azureOpenAIConfig!.endpoint,
              apiVersion: profile.azureOpenAIConfig!.apiVersion,
              deploymentName: profile.azureOpenAIConfig!.deploymentName,
              // Don't copy apiKey
            )
          : null,
      togetherAIConfig: profile.togetherAIConfig != null
          ? TogetherAIConfig(
              model: profile.togetherAIConfig!.model,
              // Don't copy apiKey
            )
          : null,
      tmuxConfig: profile.tmuxConfig,
      startupBashScript: profile.startupBashScript,
      environmentVariables: profile.environmentVariables,
      defaultSessionType: profile.defaultSessionType,
      defaultPermissionMode: profile.defaultPermissionMode,
      defaultModelMode: profile.defaultModelMode,
      compatibility: profile.compatibility,
      isBuiltIn: profile.isBuiltIn,
      createdAt: profile.createdAt,
      updatedAt: profile.updatedAt,
      version: profile.version,
    );
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

    final updated = _updateSetting(current, key, value) as Settings;

    // Cancel existing debounce timer and start a new one
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, () async {
      await saveSettings(updated);
      _debounceTimer = null;
    });

    // Update cache immediately so in-memory reads are consistent
    _cacheSettings(updated);
  }

  dynamic _updateSetting(dynamic settings, String key, dynamic value) {
    // Directly update mutable field instead of JSON roundtrip
    final updated = settings as Settings;
    switch (key) {
      case 'schemaVersion':
        updated.schemaVersion = value as int;
      case 'themeMode':
        updated.themeMode = value as String;
      case 'viewInline':
        updated.viewInline = value as bool;
      case 'inferenceOpenAIKey':
        updated.inferenceOpenAIKey = value as String?;
      case 'expandTodos':
        updated.expandTodos = value as bool;
      case 'showLineNumbers':
        updated.showLineNumbers = value as bool;
      case 'showLineNumbersInToolViews':
        updated.showLineNumbersInToolViews = value as bool;
      case 'wrapLinesInDiffs':
        updated.wrapLinesInDiffs = value as bool;
      case 'analyticsOptOut':
        updated.analyticsOptOut = value as bool;
      case 'experiments':
        updated.experiments = value as bool;
      case 'markdownCopyV2':
        updated.markdownCopyV2 = value as bool;
      case 'useEnhancedSessionWizard':
        updated.useEnhancedSessionWizard = value as bool;
      case 'alwaysShowContextSize':
        updated.alwaysShowContextSize = value as bool;
      case 'agentInputEnterToSend':
        updated.agentInputEnterToSend = value as bool;
      case 'developerModeEnabled':
        updated.developerModeEnabled = value as bool;
      case 'avatarStyle':
        updated.avatarStyle = value as String;
      case 'showFlavorIcons':
        updated.showFlavorIcons = value as bool;
      case 'compactSessionView':
        updated.compactSessionView = value as bool;
      case 'hideInactiveSessions':
        updated.hideInactiveSessions = value as bool;
      case 'reviewPromptAnswered':
        updated.reviewPromptAnswered = value as bool;
      case 'reviewPromptLikedApp':
        updated.reviewPromptLikedApp = value as bool?;
      case 'ttsEnabled':
        updated.ttsEnabled = value as bool;
      case 'voiceAssistantLanguage':
        updated.voiceAssistantLanguage = value as String?;
      case 'preferredLanguage':
        updated.preferredLanguage = value as String?;
      case 'lastUsedAgent':
        updated.lastUsedAgent = value as String?;
      case 'lastUsedPermissionMode':
        updated.lastUsedPermissionMode = value as String?;
      case 'lastUsedModelMode':
        updated.lastUsedModelMode = value as String?;
      case 'lastUsedProfile':
        updated.lastUsedProfile = value as String?;
      case 'profiles':
        updated.profiles = List<AIBackendProfile>.from(
          value as List<AIBackendProfile>,
        );
    }
    return updated;
  }

  /// Clear all settings
  Future<void> clearSettings() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    await _storage.clearSettings();
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

/// Session drafts storage with MMKV
class SessionDraftsStorage {
  factory SessionDraftsStorage() => _instance;
  SessionDraftsStorage._();
  static final SessionDraftsStorage _instance = SessionDraftsStorage._();

  final _storage = MMKVStorage();

  /// Get draft for a specific session
  Future<String?> getDraft(String sessionId) async {
    return _storage.getSessionDraft(sessionId);
  }

  /// Save draft for a specific session
  Future<void> saveDraft(String sessionId, String draft) async {
    await _storage.saveSessionDraft(sessionId, draft);
  }

  /// Remove draft for a specific session
  Future<void> removeDraft(String sessionId) async {
    await _storage.removeSessionDraft(sessionId);
  }

  /// Get all session drafts
  Future<Map<String, String>> getAllDrafts() async {
    return _storage.getSessionDrafts();
  }

  /// Clear all session drafts
  Future<void> clearAllDrafts() async {
    await _storage.clearSessionDrafts();
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
    } catch (e) {
      logger.warning('Error storing inference OpenAI key: $e');
      return false;
    }
  }

  /// Get the inference OpenAI API key
  Future<String?> getInferenceOpenAIKey() async {
    try {
      return await _secureStorage.read(key: _inferenceOpenAIKey);
    } catch (e) {
      logger.warning('Error getting inference OpenAI key: $e');
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
    } catch (e) {
      logger.warning('Error storing OpenAI config key: $e');
      return false;
    }
  }

  /// Get OpenAI config API key for a profile
  Future<String?> getOpenAIConfigKey(String profileId) async {
    try {
      final key = '$_openAIConfigKeyPrefix$profileId';
      return await _secureStorage.read(key: key);
    } catch (e) {
      logger.warning('Error getting OpenAI config key: $e');
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
    } catch (e) {
      logger.warning('Error storing Azure OpenAI config key: $e');
      return false;
    }
  }

  /// Get Azure OpenAI config API key for a profile
  Future<String?> getAzureOpenAIConfigKey(String profileId) async {
    try {
      final key = '$_azureOpenAIConfigKeyPrefix$profileId';
      return await _secureStorage.read(key: key);
    } catch (e) {
      logger.warning('Error getting Azure OpenAI config key: $e');
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
    } catch (e) {
      logger.warning('Error storing TogetherAI config key: $e');
      return false;
    }
  }

  /// Get TogetherAI config API key for a profile
  Future<String?> getTogetherAIConfigKey(String profileId) async {
    try {
      final key = '$_togetherAIConfigKeyPrefix$profileId';
      return await _secureStorage.read(key: key);
    } catch (e) {
      logger.warning('Error getting TogetherAI config key: $e');
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
    } catch (e) {
      logger.warning('Error clearing API keys: $e');
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
    } catch (e) {
      logger.warning('Error migrating API keys: $e');
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
  final sessionDraftsStorage = SessionDraftsStorage();
  final sessionPermissionModesStorage = SessionPermissionModesStorage();
  final profileStorage = ProfileStorage();

  /// Initialize all storage
  Future<void> initialize() async {
    await MMKVStorage.initialize();
    await ServerConfigStorage.initialize();
  }

  /// Clear all storage (except server config which persists across logouts)
  Future<void> clearAll() async {
    await tokenStorage.removeCredentials();
    await settingsStorage.clearSettings();
    await sessionDraftsStorage.clearAllDrafts();
    await sessionPermissionModesStorage.clearAllPermissionModes();
    await profileStorage.clearProfile();
    unawaited(MMKVStorage().clearAll());
    // Note: ServerConfigStorage is NOT cleared here as it
  }

  /// Clear server config separately (typically not called during logout)
  Future<void> clearServerConfig() async {
    unawaited(ServerConfigStorage().clearAll());
  }
}
