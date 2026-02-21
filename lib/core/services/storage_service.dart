import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/auth.dart';
import '../models/settings.dart';
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
      debugPrint('Error getting credentials: $e');
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
      debugPrint('Error setting credentials: $e');
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
      debugPrint('Error removing credentials: $e');
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

  /// Get settings from storage
  Future<Settings> getSettings() async {
    return _storage.getSettings();
  }

  /// Save settings to storage
  Future<void> saveSettings(Settings settings) async {
    await _storage.saveSettings(settings);
  }

  /// Update a single setting
  Future<void> updateSetting<T>(String key, T value) async {
    final current = await getSettings();
    final updated = _updateSetting(current, key, value) as Settings;
    await saveSettings(updated);
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
    }
    return updated;
  }

  /// Clear all settings
  Future<void> clearSettings() async {
    await _storage.clearSettings();
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

/// Combined storage for app data
class Storage {

  factory Storage() => _instance;
  Storage._();
  static final Storage _instance = Storage._();

  final tokenStorage = TokenStorage();
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
