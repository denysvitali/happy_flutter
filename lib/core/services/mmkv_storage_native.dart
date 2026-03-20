import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:mmkv/mmkv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart' as models;
import '../models/settings.dart';
import 'logger_service.dart' show logger;

/// Storage keys for MMKV
class _StorageKeys {
  static const String settings = 'settings';
  static const String sessionDrafts = 'session-drafts';
  static const String sessionPermissionModes = 'session-permission-modes';
  static const String sessionModelModes = 'session-model-modes';
  static const String sessionProfiles = 'session-profiles';
  static const String profile = 'profile';
  static const String migrationComplete = 'mmkv-migration-complete';
  static const String sessionLastSeq = 'session-last-seq';
  static const String sessionFirstLoadedSeq = 'session-first-loaded-seq';
  static const String sessionsCache = 'sessions-cache';
}

/// MMKV-based storage wrapper with migration from SharedPreferences
class MMKVStorage {
  factory MMKVStorage() => _instance;
  MMKVStorage._();

  /// Named constructor for test fakes that need to extend MMKVStorage.
  @visibleForTesting
  MMKVStorage.testConstructor();

  static final MMKVStorage _instance = MMKVStorage._();

  MMKV? _mmkv;
  bool _initialized = false;

  // In-memory caches for frequently accessed session data
  Map<String, int>? _lastSeqCache;
  Map<String, int>? _firstLoadedSeqCache;
  Map<String, String>? _permissionModesCache;
  Map<String, String>? _modelModesCache;

  /// Initialize MMKV and migrate data from SharedPreferences if needed
  static Future<void> initialize() async {
    if (_instance._initialized) return;

    try {
      // Initialize MMKV library
      await MMKV.initialize();
      // Get default MMKV instance
      _instance._mmkv = MMKV.defaultMMKV();
      _instance._initialized = true;

      // Initialize in-memory caches
      _instance._lastSeqCache = _instance.getSessionLastSeq();
      _instance._firstLoadedSeqCache = _instance.getSessionFirstLoadedSeq();
      _instance._permissionModesCache = await _instance._loadPermissionModes();
      _instance._modelModesCache = await _instance._loadModelModes();

      // Check if migration is needed
      final migrationComplete =
          _instance._mmkv!.decodeBool(_StorageKeys.migrationComplete);

      if (!migrationComplete) {
        await _instance._migrateFromSharedPreferences();
        _instance._mmkv!.encodeBool(_StorageKeys.migrationComplete, true);
        logger.info('MMKV: Migration from SharedPreferences completed');
      }
    } catch (e) {
      logger.warning('MMKV: Initialization failed: $e');
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
      logger.warning('MMKV: Migration failed: $e');
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
      logger.warning('MMKV: Failed to load settings: $e');
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
      logger.warning('MMKV: Failed to save settings: $e');
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
      logger.warning('MMKV: Failed to clear settings: $e');
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
      logger.warning('MMKV: Failed to get session draft: $e');
    }

    return null;
  }

  /// Get draft for a specific session directly (synchronous)
  /// Returns null if not initialized or draft not found
  String? getSessionDraftDirect(String sessionId) {
    if (!_initialized) return null;

    try {
      final draftsJson = _mmkv?.decodeString(_StorageKeys.sessionDrafts);
      if (draftsJson != null) {
        final drafts = jsonDecode(draftsJson) as Map<String, dynamic>;
        return drafts[sessionId] as String?;
      }
    } catch (e) {
      logger.warning('MMKV: Failed to get session draft direct: $e');
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
      logger.warning('MMKV: Failed to save session draft: $e');
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
        final drafts = (jsonDecode(draftsJson) as Map<String, dynamic>)
          ..remove(sessionId);
        _mmkv?.encodeString(
          _StorageKeys.sessionDrafts,
          jsonEncode(drafts),
        );
      }
    } catch (e) {
      logger.warning('MMKV: Failed to remove session draft: $e');
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
      logger.warning('MMKV: Failed to get session drafts: $e');
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
      logger.warning('MMKV: Failed to clear session drafts: $e');
    }
  }

  /// Get permission mode for a specific session
  Future<String?> getSessionPermissionMode(String sessionId) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final modesJson = _mmkv?.decodeString(
        _StorageKeys.sessionPermissionModes,
      );
      if (modesJson != null) {
        final modes = jsonDecode(modesJson) as Map<String, dynamic>;
        return modes[sessionId] as String?;
      }
    } catch (e) {
      logger.warning('MMKV: Failed to get session permission mode: $e');
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
      final modesJson = _mmkv?.decodeString(
        _StorageKeys.sessionPermissionModes,
      );
      final modes = modesJson != null
          ? jsonDecode(modesJson) as Map<String, dynamic>
          : <String, dynamic>{};
      modes[sessionId] = mode;
      _mmkv?.encodeString(
          _StorageKeys.sessionPermissionModes, jsonEncode(modes));
    } catch (e) {
      logger.warning('MMKV: Failed to save session permission mode: $e');
      rethrow;
    }
  }

  /// Remove permission mode for a specific session
  Future<void> removeSessionPermissionMode(String sessionId) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final modesJson = _mmkv?.decodeString(
        _StorageKeys.sessionPermissionModes,
      );
      if (modesJson != null) {
        final modes = (jsonDecode(modesJson) as Map<String, dynamic>)
          ..remove(sessionId);
        _mmkv?.encodeString(
          _StorageKeys.sessionPermissionModes,
          jsonEncode(modes),
        );
      }
    } catch (e) {
      logger.warning('MMKV: Failed to remove session permission mode: $e');
    }
  }

  /// Get all session permission modes
  Future<Map<String, String>> getSessionPermissionModes() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final modesJson = _mmkv?.decodeString(
        _StorageKeys.sessionPermissionModes,
      );
      if (modesJson != null) {
        final modes = jsonDecode(modesJson) as Map<String, dynamic>;
        return modes.map<String, String>(
            (key, value) => MapEntry(key, value as String));
      }
    } catch (e) {
      logger.warning('MMKV: Failed to get session permission modes: $e');
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
      _permissionModesCache = null;
    } catch (e) {
      logger.warning('MMKV: Failed to clear session permission modes: $e');
    }
  }

  /// Load permission modes into memory cache (private helper)
  Future<Map<String, String>> _loadPermissionModes() async {
    if (!_initialized) return {};
    try {
      final modesJson = _mmkv?.decodeString(
        _StorageKeys.sessionPermissionModes,
      );
      if (modesJson != null) {
        final modes = jsonDecode(modesJson) as Map<String, dynamic>;
        return modes.map<String, String>(
            (key, value) => MapEntry(key, value as String));
      }
    } catch (e) {
      logger.warning('MMKV: Failed to load permission modes cache: $e');
    }
    return {};
  }

  /// Get permission mode directly from cache (synchronous)
  String? getSessionPermissionModeDirect(String sessionId) {
    if (!_initialized) return null;
    _permissionModesCache ??= {};
    return _permissionModesCache![sessionId];
  }

  /// Save permission mode to cache and persist (synchronous)
  void saveSessionPermissionModeDirect(String sessionId, String mode) {
    if (!_initialized) return;

    _permissionModesCache ??= {};
    _permissionModesCache![sessionId] = mode;

    try {
      _mmkv?.encodeString(
        _StorageKeys.sessionPermissionModes,
        jsonEncode(_permissionModesCache),
      );
    } catch (e) {
      logger.warning('MMKV: Failed to save session permission mode: $e');
    }
  }

  /// Get model mode for a specific session
  Future<String?> getSessionModelMode(String sessionId) async {
    if (!_initialized) {
      await initialize();
    }
    try {
      final json = _mmkv?.decodeString(_StorageKeys.sessionModelModes);
      if (json != null) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return map[sessionId] as String?;
      }
    } catch (e) {
      logger.warning('MMKV: Failed to get session model mode: $e');
    }
    return null;
  }

  /// Save model mode for a specific session
  Future<void> saveSessionModelMode(
    String sessionId,
    String mode,
  ) async {
    if (!_initialized) {
      await initialize();
    }
    try {
      final json = _mmkv?.decodeString(_StorageKeys.sessionModelModes);
      final map = json != null
          ? jsonDecode(json) as Map<String, dynamic>
          : <String, dynamic>{};
      map[sessionId] = mode;
      _mmkv?.encodeString(_StorageKeys.sessionModelModes, jsonEncode(map));
      // Update cache
      _modelModesCache ??= {};
      _modelModesCache![sessionId] = mode;
    } catch (e) {
      logger.warning('MMKV: Failed to save session model mode: $e');
      rethrow;
    }
  }

  /// Load model modes into memory cache (private helper)
  Future<Map<String, String>> _loadModelModes() async {
    if (!_initialized) return {};
    try {
      final json = _mmkv?.decodeString(_StorageKeys.sessionModelModes);
      if (json != null) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return map.map<String, String>(
            (key, value) => MapEntry(key, value as String));
      }
    } catch (e) {
      logger.warning('MMKV: Failed to load model modes cache: $e');
    }
    return {};
  }

  /// Get model mode directly from cache (synchronous)
  String? getSessionModelModeDirect(String sessionId) {
    if (!_initialized) return null;
    _modelModesCache ??= {};
    return _modelModesCache![sessionId];
  }

  /// Save model mode to cache and persist (synchronous)
  void saveSessionModelModeDirect(String sessionId, String mode) {
    if (!_initialized) return;

    _modelModesCache ??= {};
    _modelModesCache![sessionId] = mode;

    try {
      _mmkv?.encodeString(
        _StorageKeys.sessionModelModes,
        jsonEncode(_modelModesCache),
      );
    } catch (e) {
      logger.warning('MMKV: Failed to save session model mode: $e');
    }
  }

  /// Get profile ID for a specific session
  Future<String?> getSessionProfile(String sessionId) async {
    if (!_initialized) {
      await initialize();
    }
    try {
      final json = _mmkv?.decodeString(_StorageKeys.sessionProfiles);
      if (json != null) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return map[sessionId] as String?;
      }
    } catch (e) {
      logger.warning('MMKV: Failed to get session profile: $e');
    }
    return null;
  }

  /// Save profile ID for a specific session
  Future<void> saveSessionProfile(
    String sessionId,
    String profileId,
  ) async {
    if (!_initialized) {
      await initialize();
    }
    try {
      final json = _mmkv?.decodeString(_StorageKeys.sessionProfiles);
      final map = json != null
          ? jsonDecode(json) as Map<String, dynamic>
          : <String, dynamic>{};
      map[sessionId] = profileId;
      _mmkv?.encodeString(_StorageKeys.sessionProfiles, jsonEncode(map));
    } catch (e) {
      logger.warning('MMKV: Failed to save session profile: $e');
      rethrow;
    }
  }

  /// Remove profile ID for a specific session
  Future<void> removeSessionProfile(String sessionId) async {
    if (!_initialized) {
      await initialize();
    }
    try {
      final json = _mmkv?.decodeString(_StorageKeys.sessionProfiles);
      if (json != null) {
        final map = (jsonDecode(json) as Map<String, dynamic>)
          ..remove(sessionId);
        _mmkv?.encodeString(_StorageKeys.sessionProfiles, jsonEncode(map));
      }
    } catch (e) {
      logger.warning('MMKV: Failed to remove session profile: $e');
    }
  }

  /// Get all persisted session last-seq cursors (synchronous — MMKV is sync)
  Map<String, int> getSessionLastSeq() {
    if (!_initialized) return {};

    // Return cached copy if available
    if (_lastSeqCache != null) {
      return Map<String, int>.from(_lastSeqCache!);
    }

    try {
      final json = _mmkv?.decodeString(_StorageKeys.sessionLastSeq);
      if (json != null) {
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        _lastSeqCache = decoded.map((k, v) => MapEntry(k, v as int));
        return Map<String, int>.from(_lastSeqCache!);
      }
    } catch (e) {
      logger.warning('MMKV: Failed to get session last seq: $e');
    }
    return {};
  }

  /// Get a single session's last-seq cursor (synchronous, cached)
  int? getSessionLastSeqSingle(String sessionId) {
    if (!_initialized) return null;

    // Use cache if available
    if (_lastSeqCache != null) {
      return _lastSeqCache![sessionId];
    }

    // Fall back to loading all data
    final all = getSessionLastSeq();
    return all[sessionId];
  }

  /// Persist all session last-seq cursors (synchronous)
  void saveSessionLastSeq(Map<String, int> seqs) {
    if (!_initialized) return;
    try {
      _mmkv?.encodeString(
        _StorageKeys.sessionLastSeq,
        jsonEncode(seqs),
      );
      // Update cache
      _lastSeqCache = Map<String, int>.from(seqs);
    } catch (e) {
      logger.warning('MMKV: Failed to save session last seq: $e');
    }
  }

  /// Update a single session's last-seq cursor (synchronous, cached)
  void saveSessionLastSeqSingle(String sessionId, int seq) {
    if (!_initialized) return;

    // Initialize cache if needed
    _lastSeqCache ??= getSessionLastSeq();

    // Update cache
    _lastSeqCache![sessionId] = seq;

    try {
      _mmkv?.encodeString(
        _StorageKeys.sessionLastSeq,
        jsonEncode(_lastSeqCache),
      );
    } catch (e) {
      logger.warning('MMKV: Failed to save session last seq: $e');
    }
  }

  /// Clear all session last-seq cursors
  void clearSessionLastSeq() {
    if (!_initialized) return;
    try {
      _mmkv?.removeValue(_StorageKeys.sessionLastSeq);
      _lastSeqCache = null;
    } catch (e) {
      logger.warning('MMKV: Failed to clear session last seq: $e');
    }
  }

  /// Get all persisted session first-loaded-seq cursors (synchronous)
  Map<String, int> getSessionFirstLoadedSeq() {
    if (!_initialized) return {};

    // Return cached copy if available
    if (_firstLoadedSeqCache != null) {
      return Map<String, int>.from(_firstLoadedSeqCache!);
    }

    try {
      final json =
          _mmkv?.decodeString(_StorageKeys.sessionFirstLoadedSeq);
      if (json != null) {
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        _firstLoadedSeqCache = decoded.map((k, v) => MapEntry(k, v as int));
        return Map<String, int>.from(_firstLoadedSeqCache!);
      }
    } catch (e) {
      logger.warning('MMKV: Failed to get session first loaded seq: $e');
    }
    return {};
  }

  /// Get a single session's first-loaded-seq cursor (synchronous, cached)
  int? getSessionFirstLoadedSeqSingle(String sessionId) {
    if (!_initialized) return null;

    // Use cache if available
    if (_firstLoadedSeqCache != null) {
      return _firstLoadedSeqCache![sessionId];
    }

    // Fall back to loading all data
    final all = getSessionFirstLoadedSeq();
    return all[sessionId];
  }

  /// Persist all session first-loaded-seq cursors (synchronous)
  void saveSessionFirstLoadedSeq(Map<String, int> seqs) {
    if (!_initialized) return;
    try {
      _mmkv?.encodeString(
        _StorageKeys.sessionFirstLoadedSeq,
        jsonEncode(seqs),
      );
      // Update cache
      _firstLoadedSeqCache = Map<String, int>.from(seqs);
    } catch (e) {
      logger.warning('MMKV: Failed to save session first loaded seq: $e');
    }
  }

  /// Update a single session's first-loaded-seq cursor (synchronous, cached)
  void saveSessionFirstLoadedSeqSingle(String sessionId, int seq) {
    if (!_initialized) return;

    // Initialize cache if needed
    _firstLoadedSeqCache ??= getSessionFirstLoadedSeq();

    // Update cache
    _firstLoadedSeqCache![sessionId] = seq;

    try {
      _mmkv?.encodeString(
        _StorageKeys.sessionFirstLoadedSeq,
        jsonEncode(_firstLoadedSeqCache),
      );
    } catch (e) {
      logger.warning('MMKV: Failed to save session first loaded seq: $e');
    }
  }

  /// Clear all session first-loaded-seq cursors
  void clearSessionFirstLoadedSeq() {
    if (!_initialized) return;
    try {
      _mmkv?.removeValue(_StorageKeys.sessionFirstLoadedSeq);
      _firstLoadedSeqCache = null;
    } catch (e) {
      logger.warning(
        'MMKV: Failed to clear session first loaded seq', e,
      );
    }
  }

  Map<String, dynamic>? getSessionsCache() {
    if (!_initialized) return null;
    try {
      final json = _mmkv?.decodeString(_StorageKeys.sessionsCache);
      if (json == null || json.isEmpty) return null;
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      logger.warning('MMKV: Failed to get sessions cache: $e');
    }
    return null;
  }

  void saveSessionsCache(Map<String, dynamic> cache) {
    if (!_initialized) return;
    try {
      _mmkv?.encodeString(_StorageKeys.sessionsCache, jsonEncode(cache));
    } catch (e) {
      logger.warning('MMKV: Failed to save sessions cache: $e');
    }
  }

  void clearSessionsCache() {
    if (!_initialized) return;
    try {
      _mmkv?.removeValue(_StorageKeys.sessionsCache);
    } catch (e) {
      logger.warning('MMKV: Failed to clear sessions cache: $e');
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
      logger.warning('MMKV: Failed to clear all: $e');
    }
  }

  /// Test helper: Write raw string to MMKV (for testing error handling)
  Future<void> writeRawString(String key, String value) async {
    if (!_initialized) {
      await initialize();
    }
    _mmkv?.encodeString(key, value);
  }

  // ─── Session message cache ──────────────────────────────────────────

  List<Map<String, dynamic>> getSessionMessages(String sessionId) {
    final raw = _mmkv?.decodeString('session-messages-$sessionId');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  void saveSessionMessages(
    String sessionId,
    List<Map<String, dynamic>> messages,
  ) {
    _mmkv?.encodeString(
      'session-messages-$sessionId',
      jsonEncode(messages),
    );
  }

  void clearSessionMessages(String sessionId) {
    _mmkv?.removeValue('session-messages-$sessionId');
  }

  // ─── Outbox persistence ─────────────────────────────────────────────

  Future<String?> getOutboxEntries() async {
    if (!_initialized) await initialize();
    return _mmkv?.decodeString('outbox-entries');
  }

  Future<void> saveOutboxEntries(String jsonStr) async {
    if (!_initialized) await initialize();
    _mmkv?.encodeString('outbox-entries', jsonStr);
  }
}

/// Server configuration storage using separate MMKV instance
/// This persists across logouts and is separate from user data
class ServerConfigStorage {
  factory ServerConfigStorage() => _instance;
  ServerConfigStorage._();
  static final ServerConfigStorage _instance = ServerConfigStorage._();

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
      logger.warning('ServerConfigStorage: Initialization failed: $e');
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
        logger.warning('ServerConfigStorage: Sync init failed: $e');
        return null;
      }
    }

    try {
      return _mmkv?.decodeString(_serverUrlKey);
    } catch (e) {
      logger.warning('ServerConfigStorage: Failed to get server URL: $e');
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
      logger.warning('ServerConfigStorage: Failed to set server URL: $e');
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
      logger.warning(
        'ServerConfigStorage: Failed to save server URL error', e,
      );
    }
  }

  /// Get the last server URL error
  String? getLastServerUrlError() {
    if (!_initialized) {
      try {
        _mmkv = MMKV('server-config');
        _initialized = true;
      } catch (e) {
        logger.warning('ServerConfigStorage: Sync init failed: $e');
        return null;
      }
    }

    try {
      return _mmkv?.decodeString(_serverUrlErrorKey);
    } catch (e) {
      logger.warning(
        'ServerConfigStorage: Failed to get server URL error', e,
      );
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
      logger.warning(
        'ServerConfigStorage: Failed to clear server URL error', e,
      );
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
      logger.warning('ServerConfigStorage: Failed to clear all: $e');
    }
  }
}

/// Profile storage using MMKV
class ProfileStorage {
  factory ProfileStorage() => _instance;
  ProfileStorage._();
  static final ProfileStorage _instance = ProfileStorage._();

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
      logger.warning('ProfileStorage: Failed to load profile: $e');
    }

    return models.Profile.defaults;
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
      logger.warning('ProfileStorage: Failed to save profile: $e');
      rethrow;
    }
  }

  /// Clear profile from storage
  Future<void> clearProfile() async {
    try {
      _storage._mmkv?.removeValue(_StorageKeys.profile);
    } catch (e) {
      logger.warning('ProfileStorage: Failed to clear profile: $e');
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
