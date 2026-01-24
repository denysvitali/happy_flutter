import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/auth.dart';
import '../models/settings.dart';
import 'mmkv_storage.dart';

/// Secure storage for authentication credentials
class TokenStorage {
  static final TokenStorage _instance = TokenStorage._();
  TokenStorage._();

  factory TokenStorage() => _instance;

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
  static final SettingsStorage _instance = SettingsStorage._();
  SettingsStorage._();

  factory SettingsStorage() => _instance;

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
    final json = settings.toJson();
    json[key] = value;
    return Settings.fromJson(json);
  }

  /// Clear all settings
  Future<void> clearSettings() async {
    await _storage.clearSettings();
  }
}

/// Session drafts storage with MMKV
class SessionDraftsStorage {
  static final SessionDraftsStorage _instance = SessionDraftsStorage._();
  SessionDraftsStorage._();

  factory SessionDraftsStorage() => _instance;

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
  static final SessionPermissionModesStorage _instance =
      SessionPermissionModesStorage._();
  SessionPermissionModesStorage._();

  factory SessionPermissionModesStorage() => _instance;

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
  static final Storage _instance = Storage._();
  Storage._();

  factory Storage() => _instance;

  final tokenStorage = TokenStorage();
  final settingsStorage = SettingsStorage();
  final sessionDraftsStorage = SessionDraftsStorage();
  final sessionPermissionModesStorage = SessionPermissionModesStorage();

  /// Initialize all storage
  Future<void> initialize() async {
    await MMKVStorage.initialize();
    await ServerConfigStorage.initialize();
  }

  /// Clear all storage
  Future<void> clearAll() async {
    await tokenStorage.removeCredentials();
    await settingsStorage.clearSettings();
    await sessionDraftsStorage.clearAllDrafts();
    await sessionPermissionModesStorage.clearAllPermissionModes();
    unawaited(MMKVStorage().clearAll());
    ServerConfigStorage().clearAll();
  }
}
