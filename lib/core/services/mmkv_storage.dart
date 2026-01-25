import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mmkv/mmkv.dart';
import '../models/settings.dart';
import '../models/profile.dart' as models;

/// Storage keys for MMKV
class _StorageKeys {
  static const String settings = 'settings';
  static const String sessionDrafts = 'session-drafts';
  static const String sessionPermissionModes = 'session-permission-modes';
  static const String profile = 'profile';
  static const String migrationComplete = 'mmkv-migration-complete';
}

/// MMKV-based storage wrapper with migration from SharedPreferences
class MMKVStorage {
  static final MMKVStorage _instance = MMKVStorage._();
  MMKVStorage._();
  factory MMKVStorage() => _instance;

  MMKV? _mmkv;
  bool _initialized = false;

  /// Initialize MMKV and migrate data from SharedPreferences if needed
  static Future<void> initialize() async {
    if (_instance._initialized) return;

    try {
      // Initialize MMKV library
      await MMKV.initialize();
      // Get default MMKV instance
      _instance._mmkv = MMKV.defaultMMKV();
      _instance._initialized = true;

      // Check if migration is needed
      final migrationComplete =
          _instance._mmkv!.decodeBool(_StorageKeys.migrationComplete) ?? false;

      if (!migrationComplete) {
        await _instance._migrateFromSharedPreferences();
        _instance._mmkv!.encodeBool(_StorageKeys.migrationComplete, true);
        debugPrint('MMKV: Migration from SharedPreferences completed');
      }
    } catch (e) {
      debugPrint('MMKV: Initialization failed: $e');
      rethrow;
    }
  }

  /// Migrate data from SharedPreferences to MMKV
  Future<void> _migrateFromSharedPreferences() async {
    if (_mmkv == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Migrate settings
      final settingsJson = prefs.getString(_StorageKeys.settings);
      if (settingsJson != null) {
        _mmkv!.encodeString(_StorageKeys.settings, settingsJson);
        await prefs.remove(_StorageKeys.settings);
      }

      // Migrate session drafts
      final draftsJson = prefs.getString(_StorageKeys.sessionDrafts);
      if (draftsJson != null) {
        _mmkv!.encodeString(_StorageKeys.sessionDrafts, draftsJson);
        await prefs.remove(_StorageKeys.sessionDrafts);
      }

      // Migrate session permission modes
      final modesJson = prefs.getString(_StorageKeys.sessionPermissionModes);
      if (modesJson != null) {
        _mmkv!.encodeString(_StorageKeys.sessionPermissionModes, modesJson);
        await prefs.remove(_StorageKeys.sessionPermissionModes);
      }

      // Migrate profile
      final profileJson = prefs.getString(_StorageKeys.profile);
      if (profileJson != null) {
        _mmkv!.encodeString(_StorageKeys.profile, profileJson);
        await prefs.remove(_StorageKeys.profile);
      }
    } catch (e) {
      debugPrint('MMKV: Migration failed: $e');
      // Don't rethrow - allow app to continue even if migration fails
    }
  }

  /// Get settings from storage
  Future<Settings> getSettings() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final settingsJson = _mmkv?.decodeString(_StorageKeys.settings);
      if (settingsJson != null) {
        final decoded = jsonDecode(settingsJson) as Map<String, dynamic>;
        return Settings.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('MMKV: Failed to load settings: $e');
    }

    return Settings();
  }

  /// Save settings to storage
  Future<void> saveSettings(Settings settings) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final settingsJson = jsonEncode(settings.toJson());
      _mmkv?.encodeString(_StorageKeys.settings, settingsJson);
    } catch (e) {
      debugPrint('MMKV: Failed to save settings: $e');
      rethrow;
    }
  }

  /// Clear settings from storage
  Future<void> clearSettings() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      _mmkv?.removeValue(_StorageKeys.settings);
    } catch (e) {
      debugPrint('MMKV: Failed to clear settings: $e');
    }
  }

  /// Get draft for a specific session
  Future<String?> getSessionDraft(String sessionId) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final draftsJson = _mmkv?.decodeString(_StorageKeys.sessionDrafts);
      if (draftsJson != null) {
        final drafts = jsonDecode(draftsJson) as Map<String, dynamic>;
        return drafts[sessionId] as String?;
      }
    } catch (e) {
      debugPrint('MMKV: Failed to get session draft: $e');
    }

    return null;
  }

  /// Save draft for a specific session
  Future<void> saveSessionDraft(String sessionId, String draft) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final draftsJson = _mmkv?.decodeString(_StorageKeys.sessionDrafts);
      final drafts = draftsJson != null
          ? jsonDecode(draftsJson) as Map<String, dynamic>
          : <String, dynamic>{};
      drafts[sessionId] = draft;
      _mmkv?.encodeString(
          _StorageKeys.sessionDrafts, jsonEncode(drafts));
    } catch (e) {
      debugPrint('MMKV: Failed to save session draft: $e');
      rethrow;
    }
  }

  /// Remove draft for a specific session
  Future<void> removeSessionDraft(String sessionId) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final draftsJson = _mmkv?.decodeString(_StorageKeys.sessionDrafts);
      if (draftsJson != null) {
        final drafts = jsonDecode(draftsJson) as Map<String, dynamic>;
        drafts.remove(sessionId);
        _mmkv?.encodeString(
            _StorageKeys.sessionDrafts, jsonEncode(drafts));
      }
    } catch (e) {
      debugPrint('MMKV: Failed to remove session draft: $e');
    }
  }

  /// Get all session drafts
  Future<Map<String, String>> getSessionDrafts() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final draftsJson = _mmkv?.decodeString(_StorageKeys.sessionDrafts);
      if (draftsJson != null) {
        final drafts = jsonDecode(draftsJson) as Map<String, dynamic>;
        return drafts.map<String, String>(
            (key, value) => MapEntry(key, value as String));
      }
    } catch (e) {
      debugPrint('MMKV: Failed to get session drafts: $e');
    }

    return {};
  }

  /// Clear all session drafts
  Future<void> clearSessionDrafts() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      _mmkv?.removeValue(_StorageKeys.sessionDrafts);
    } catch (e) {
      debugPrint('MMKV: Failed to clear session drafts: $e');
    }
  }

  /// Get permission mode for a specific session
  Future<String?> getSessionPermissionMode(String sessionId) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final modesJson = _mmkv?.decodeString(_StorageKeys.sessionPermissionModes);
      if (modesJson != null) {
        final modes = jsonDecode(modesJson) as Map<String, dynamic>;
        return modes[sessionId] as String?;
      }
    } catch (e) {
      debugPrint('MMKV: Failed to get session permission mode: $e');
    }

    return null;
  }

  /// Save permission mode for a specific session
  Future<void> saveSessionPermissionMode(
      String sessionId, String mode) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final modesJson = _mmkv?.decodeString(_StorageKeys.sessionPermissionModes);
      final modes = modesJson != null
          ? jsonDecode(modesJson) as Map<String, dynamic>
          : <String, dynamic>{};
      modes[sessionId] = mode;
      _mmkv?.encodeString(
          _StorageKeys.sessionPermissionModes, jsonEncode(modes));
    } catch (e) {
      debugPrint('MMKV: Failed to save session permission mode: $e');
      rethrow;
    }
  }

  /// Remove permission mode for a specific session
  Future<void> removeSessionPermissionMode(String sessionId) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final modesJson = _mmkv?.decodeString(_StorageKeys.sessionPermissionModes);
      if (modesJson != null) {
        final modes = jsonDecode(modesJson) as Map<String, dynamic>;
        modes.remove(sessionId);
        _mmkv?.encodeString(
            _StorageKeys.sessionPermissionModes, jsonEncode(modes));
      }
    } catch (e) {
      debugPrint('MMKV: Failed to remove session permission mode: $e');
    }
  }

  /// Get all session permission modes
  Future<Map<String, String>> getSessionPermissionModes() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final modesJson = _mmkv?.decodeString(_StorageKeys.sessionPermissionModes);
      if (modesJson != null) {
        final modes = jsonDecode(modesJson) as Map<String, dynamic>;
        return modes.map<String, String>(
            (key, value) => MapEntry(key, value as String));
      }
    } catch (e) {
      debugPrint('MMKV: Failed to get session permission modes: $e');
    }

    return {};
  }

  /// Clear all session permission modes
  Future<void> clearSessionPermissionModes() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      _mmkv?.removeValue(_StorageKeys.sessionPermissionModes);
    } catch (e) {
      debugPrint('MMKV: Failed to clear session permission modes: $e');
    }
  }

  /// Clear all data from MMKV storage
  Future<void> clearAll() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      _mmkv?.clearAll();
    } catch (e) {
      debugPrint('MMKV: Failed to clear all: $e');
    }
  }

  /// Test helper: Write raw string to MMKV (for testing error handling)
  Future<void> writeRawString(String key, String value) async {
    if (!_initialized) {
      await initialize();
    }
    _mmkv?.encodeString(key, value);
  }
}

/// Server configuration storage using separate MMKV instance
/// This persists across logouts and is separate from user data
class ServerConfigStorage {
  static final ServerConfigStorage _instance = ServerConfigStorage._();
  ServerConfigStorage._();
  factory ServerConfigStorage() => _instance;

  MMKV? _mmkv;
  bool _initialized = false;

  static const String _serverUrlKey = 'custom-server-url';
  static const String _serverUrlErrorKey = 'last-server-url-error';

  /// Initialize server config MMKV instance
  static Future<void> initialize() async {
    if (_instance._initialized) return;

    try {
      await MMKV.initialize();
      _instance._mmkv = MMKV('server-config');
      _instance._initialized = true;
    } catch (e) {
      debugPrint('ServerConfigStorage: Initialization failed: $e');
      rethrow;
    }
  }

  /// Get custom server URL
  String? getServerUrl() {
    if (!_initialized) {
      try {
        _mmkv = MMKV('server-config');
        _initialized = true;
      } catch (e) {
        debugPrint('ServerConfigStorage: Sync init failed: $e');
        return null;
      }
    }

    try {
      return _mmkv?.decodeString(_serverUrlKey);
    } catch (e) {
      debugPrint('ServerConfigStorage: Failed to get server URL: $e');
      return null;
    }
  }

  /// Set custom server URL
  Future<void> setServerUrl(String? url) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      if (url != null && url.trim().isNotEmpty) {
        _mmkv?.encodeString(_serverUrlKey, url.trim());
      } else {
        _mmkv?.removeValue(_serverUrlKey);
      }
    } catch (e) {
      debugPrint('ServerConfigStorage: Failed to set server URL: $e');
      rethrow;
    }
  }

  /// Check if using custom server URL
  bool isUsingCustomServer() {
    final customUrl = getServerUrl();
    return customUrl != null && customUrl.isNotEmpty;
  }

  /// Save server URL error for display on auth screen
  Future<void> saveServerUrlError(String error) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      _mmkv?.encodeString(_serverUrlErrorKey, error);
    } catch (e) {
      debugPrint('ServerConfigStorage: Failed to save server URL error: $e');
    }
  }

  /// Get the last server URL error
  String? getLastServerUrlError() {
    if (!_initialized) {
      try {
        _mmkv = MMKV('server-config');
        _initialized = true;
      } catch (e) {
        debugPrint('ServerConfigStorage: Sync init failed: $e');
        return null;
      }
    }

    try {
      return _mmkv?.decodeString(_serverUrlErrorKey);
    } catch (e) {
      debugPrint('ServerConfigStorage: Failed to get server URL error: $e');
      return null;
    }
  }

  /// Clear the last server URL error
  Future<void> clearLastServerUrlError() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      _mmkv?.removeValue(_serverUrlErrorKey);
    } catch (e) {
      debugPrint('ServerConfigStorage: Failed to clear server URL error: $e');
    }
  }

  /// Clear all server config data
  Future<void> clearAll() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      _mmkv?.clearAll();
    } catch (e) {
      debugPrint('ServerConfigStorage: Failed to clear all: $e');
    }
  }
}

/// Profile storage using MMKV
class ProfileStorage {
  static final ProfileStorage _instance = ProfileStorage._();
  ProfileStorage._();
  factory ProfileStorage() => _instance;

  final _storage = MMKVStorage();

  /// Load profile from storage
  /// Returns a default empty Profile if not found
  Future<models.Profile> loadProfile() async {
    try {
      final profileJson = await _getString(_StorageKeys.profile);
      if (profileJson != null) {
        final decoded = jsonDecode(profileJson) as Map<String, dynamic>;
        // Map old format to new Profile format
        return models.Profile(
          id: decoded['id'] as String? ?? '',
          timestamp: decoded['timestamp'] as int? ?? 0,
          firstName: decoded['firstName'] as String?,
          lastName: decoded['lastName'] as String?,
          connectedServices: (decoded['connectedServices'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              [],
        );
      }
    } catch (e) {
      debugPrint('ProfileStorage: Failed to load profile: $e');
    }

    return const models.Profile(id: '');
  }

  /// Save profile to storage
  Future<void> saveProfile(models.Profile profile) async {
    try {
      final profileJson = jsonEncode({
        'id': profile.id,
        'timestamp': profile.timestamp,
        'firstName': profile.firstName,
        'lastName': profile.lastName,
        'connectedServices': profile.connectedServices,
      });
      await _setString(_StorageKeys.profile, profileJson);
    } catch (e) {
      debugPrint('ProfileStorage: Failed to save profile: $e');
      rethrow;
    }
  }

  /// Clear profile from storage
  Future<void> clearProfile() async {
    try {
      _storage._mmkv?.removeValue(_StorageKeys.profile);
    } catch (e) {
      debugPrint('ProfileStorage: Failed to clear profile: $e');
    }
  }

  Future<String?> _getString(String key) async {
    if (!_storage._initialized) {
      await MMKVStorage.initialize();
    }
    return _storage._mmkv?.decodeString(key);
  }

  Future<void> _setString(String key, String value) async {
    if (!_storage._initialized) {
      await MMKVStorage.initialize();
    }
    _storage._mmkv?.encodeString(key, value);
  }
}
