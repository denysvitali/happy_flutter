// Web-only storage implementation using SharedPreferences.
// This file must NOT import dart:io.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart' as models;
import '../models/settings.dart';
import 'logger_service.dart' show logger;

/// Storage key constants (mirrors mmkv_storage_native.dart)
class _Keys {
  static const String settings = 'settings';
  static const String sessionDrafts = 'session-drafts';
  static const String sessionPermissionModes = 'session-permission-modes';
  static const String sessionModelModes = 'session-model-modes';
  static const String sessionProfiles = 'session-profiles';
  static const String profile = 'profile';
  static const String sessionLastSeq = 'session-last-seq';
  static const String sessionFirstLoadedSeq = 'session-first-loaded-seq';
  static const String sessionsCache = 'sessions-cache';

  /// Prefix for server-config namespace (replaces separate MMKV instance)
  static const String serverConfigPrefix = 'server_config.';
  static const String serverUrl = 'custom-server-url';
  static const String serverUrlError = 'last-server-url-error';
}

/// SharedPreferences-backed storage for web.
///
/// Mirrors the public API of the native [MMKVStorage] so that callers
/// remain source-compatible across platforms.
class MMKVStorage {
  factory MMKVStorage() => _instance;
  MMKVStorage._();
  static final MMKVStorage _instance = MMKVStorage._();

  SharedPreferences? _prefs;
  bool _initialized = false;

  // In-memory caches for the synchronous seq methods.
  Map<String, int> _sessionLastSeq = {};
  Map<String, int> _sessionFirstLoadedSeq = {};

  /// Initialise the SharedPreferences instance.
  static Future<void> initialize() async {
    if (_instance._initialized) return;
    try {
      _instance._prefs = await SharedPreferences.getInstance();
      _instance._initialized = true;
      // Eagerly populate synchronous caches.
      _instance._loadSeqCaches();
    } catch (e) {
      logger.warning('WebStorage(MMKVStorage): init failed: $e');
      rethrow;
    }
  }

  void _loadSeqCaches() {
    _sessionLastSeq = _readIntMap(_Keys.sessionLastSeq);
    _sessionFirstLoadedSeq = _readIntMap(_Keys.sessionFirstLoadedSeq);
  }

  Map<String, int> _readIntMap(String key) {
    try {
      final json = _prefs?.getString(key);
      if (json != null) {
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        return decoded.map((k, v) => MapEntry(k, v as int));
      }
    } catch (e) {
      logger.warning('WebStorage: failed to read int map "$key": $e');
    }
    return {};
  }

  Future<SharedPreferences> _getPrefs() async {
    if (!_initialized) await initialize();
    return _prefs!;
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  Future<Settings> getSettings() async {
    try {
      final prefs = await _getPrefs();
      final json = prefs.getString(_Keys.settings);
      if (json != null) {
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        return Settings.fromJson(decoded);
      }
    } catch (e) {
      logger.warning('WebStorage: failed to load settings: $e');
    }
    return Settings();
  }

  Future<void> saveSettings(Settings settings) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(_Keys.settings, jsonEncode(settings.toJson()));
    } catch (e) {
      logger.warning('WebStorage: failed to save settings: $e');
      rethrow;
    }
  }

  Future<void> clearSettings() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_Keys.settings);
    } catch (e) {
      logger.warning('WebStorage: failed to clear settings: $e');
    }
  }

  // ── Session drafts ────────────────────────────────────────────────────────

  Future<String?> getSessionDraft(String sessionId) async {
    try {
      final prefs = await _getPrefs();
      final json = prefs.getString(_Keys.sessionDrafts);
      if (json != null) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return map[sessionId] as String?;
      }
    } catch (e) {
      logger.warning('WebStorage: failed to get session draft: $e');
    }
    return null;
  }

  Future<void> saveSessionDraft(String sessionId, String draft) async {
    try {
      final prefs = await _getPrefs();
      final json = prefs.getString(_Keys.sessionDrafts);
      final map = json != null
          ? jsonDecode(json) as Map<String, dynamic>
          : <String, dynamic>{};
      map[sessionId] = draft;
      await prefs.setString(_Keys.sessionDrafts, jsonEncode(map));
    } catch (e) {
      logger.warning('WebStorage: failed to save session draft: $e');
      rethrow;
    }
  }

  Future<void> removeSessionDraft(String sessionId) async {
    try {
      final prefs = await _getPrefs();
      final json = prefs.getString(_Keys.sessionDrafts);
      if (json != null) {
        final map = (jsonDecode(json) as Map<String, dynamic>)
          ..remove(sessionId);
        await prefs.setString(_Keys.sessionDrafts, jsonEncode(map));
      }
    } catch (e) {
      logger.warning('WebStorage: failed to remove session draft: $e');
    }
  }

  Future<Map<String, String>> getSessionDrafts() async {
    try {
      final prefs = await _getPrefs();
      final json = prefs.getString(_Keys.sessionDrafts);
      if (json != null) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return map.map((k, v) => MapEntry(k, v as String));
      }
    } catch (e) {
      logger.warning('WebStorage: failed to get session drafts: $e');
    }
    return {};
  }

  Future<void> clearSessionDrafts() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_Keys.sessionDrafts);
    } catch (e) {
      logger.warning('WebStorage: failed to clear session drafts: $e');
    }
  }

  // ── Session permission modes ───────────────────────────────────────────────

  Future<String?> getSessionPermissionMode(String sessionId) async {
    try {
      final prefs = await _getPrefs();
      final json = prefs.getString(_Keys.sessionPermissionModes);
      if (json != null) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return map[sessionId] as String?;
      }
    } catch (e) {
      logger.warning('WebStorage: failed to get session permission mode: $e');
    }
    return null;
  }

  Future<void> saveSessionPermissionMode(
    String sessionId,
    String mode,
  ) async {
    try {
      final prefs = await _getPrefs();
      final json = prefs.getString(_Keys.sessionPermissionModes);
      final map = json != null
          ? jsonDecode(json) as Map<String, dynamic>
          : <String, dynamic>{};
      map[sessionId] = mode;
      await prefs.setString(_Keys.sessionPermissionModes, jsonEncode(map));
    } catch (e) {
      logger.warning('WebStorage: failed to save session permission mode: $e');
      rethrow;
    }
  }

  Future<void> removeSessionPermissionMode(String sessionId) async {
    try {
      final prefs = await _getPrefs();
      final json = prefs.getString(_Keys.sessionPermissionModes);
      if (json != null) {
        final map = (jsonDecode(json) as Map<String, dynamic>)
          ..remove(sessionId);
        await prefs.setString(
          _Keys.sessionPermissionModes,
          jsonEncode(map),
        );
      }
    } catch (e) {
      logger.warning(
        'WebStorage: failed to remove session permission mode', e,
      );
    }
  }

  Future<Map<String, String>> getSessionPermissionModes() async {
    try {
      final prefs = await _getPrefs();
      final json = prefs.getString(_Keys.sessionPermissionModes);
      if (json != null) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return map.map((k, v) => MapEntry(k, v as String));
      }
    } catch (e) {
      logger.warning('WebStorage: failed to get session permission modes: $e');
    }
    return {};
  }

  Future<void> clearSessionPermissionModes() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_Keys.sessionPermissionModes);
    } catch (e) {
      logger.warning(
        'WebStorage: failed to clear session permission modes', e,
      );
    }
  }

  Future<String?> getSessionProfile(String sessionId) async {
    try {
      final prefs = await _getPrefs();
      final json = prefs.getString(_Keys.sessionProfiles);
      if (json != null) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return map[sessionId] as String?;
      }
    } catch (e) {
      logger.warning('WebStorage: failed to get session profile: $e');
    }
    return null;
  }

  Future<String?> getSessionModelMode(String sessionId) async {
    try {
      final prefs = await _getPrefs();
      final json = prefs.getString(_Keys.sessionModelModes);
      if (json != null) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return map[sessionId] as String?;
      }
    } catch (e) {
      logger.warning('WebStorage: failed to get session model mode: $e');
    }
    return null;
  }

  Future<void> saveSessionModelMode(
    String sessionId,
    String mode,
  ) async {
    try {
      final prefs = await _getPrefs();
      final json = prefs.getString(_Keys.sessionModelModes);
      final map = json != null
          ? jsonDecode(json) as Map<String, dynamic>
          : <String, dynamic>{};
      map[sessionId] = mode;
      await prefs.setString(_Keys.sessionModelModes, jsonEncode(map));
    } catch (e) {
      logger.warning('WebStorage: failed to save session model mode: $e');
      rethrow;
    }
  }

  Future<void> saveSessionProfile(
    String sessionId,
    String profileId,
  ) async {
    try {
      final prefs = await _getPrefs();
      final json = prefs.getString(_Keys.sessionProfiles);
      final map = json != null
          ? jsonDecode(json) as Map<String, dynamic>
          : <String, dynamic>{};
      map[sessionId] = profileId;
      await prefs.setString(_Keys.sessionProfiles, jsonEncode(map));
    } catch (e) {
      logger.warning('WebStorage: failed to save session profile: $e');
      rethrow;
    }
  }

  Future<void> removeSessionProfile(String sessionId) async {
    try {
      final prefs = await _getPrefs();
      final json = prefs.getString(_Keys.sessionProfiles);
      if (json != null) {
        final map = (jsonDecode(json) as Map<String, dynamic>)
          ..remove(sessionId);
        await prefs.setString(_Keys.sessionProfiles, jsonEncode(map));
      }
    } catch (e) {
      logger.warning('WebStorage: failed to remove session profile: $e');
    }
  }

  // ── Synchronous seq cursors (backed by in-memory cache) ───────────────────

  /// Returns the in-memory last-seq map.
  /// The map is populated during [initialize].
  Map<String, int> getSessionLastSeq() => Map.unmodifiable(_sessionLastSeq);

  void saveSessionLastSeq(Map<String, int> seqs) {
    _sessionLastSeq = Map.of(seqs);
    _persistIntMap(_Keys.sessionLastSeq, seqs);
  }

  void clearSessionLastSeq() {
    _sessionLastSeq = {};
    _persistIntMap(_Keys.sessionLastSeq, {});
  }

  Map<String, int> getSessionFirstLoadedSeq() =>
      Map.unmodifiable(_sessionFirstLoadedSeq);

  void saveSessionFirstLoadedSeq(Map<String, int> seqs) {
    _sessionFirstLoadedSeq = Map.of(seqs);
    _persistIntMap(_Keys.sessionFirstLoadedSeq, seqs);
  }

  void clearSessionFirstLoadedSeq() {
    _sessionFirstLoadedSeq = {};
    _persistIntMap(_Keys.sessionFirstLoadedSeq, {});
  }

  Map<String, dynamic>? getSessionsCache() {
    if (!_initialized) return null;
    try {
      final json = _prefs?.getString(_Keys.sessionsCache);
      if (json == null || json.isEmpty) return null;
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      logger.warning('WebStorage: failed to load sessions cache: $e');
    }
    return null;
  }

  void saveSessionsCache(Map<String, dynamic> cache) {
    if (!_initialized) return;
    _getPrefs().then((prefs) {
      prefs.setString(_Keys.sessionsCache, jsonEncode(cache));
    }).catchError((Object e) {
      logger.warning('WebStorage: failed to persist sessions cache: $e');
    });
  }

  void clearSessionsCache() {
    if (!_initialized) return;
    _getPrefs().then((prefs) {
      prefs.remove(_Keys.sessionsCache);
    }).catchError((Object e) {
      logger.warning('WebStorage: failed to clear sessions cache: $e');
    });
  }

  void _persistIntMap(String key, Map<String, int> map) {
    // Fire-and-forget; errors are logged but not thrown.
    _getPrefs().then((prefs) {
      prefs.setString(key, jsonEncode(map));
    }).catchError((Object e) {
      logger.warning('WebStorage: failed to persist "$key": $e');
    });
  }

  // ── Clear all ─────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    try {
      final prefs = await _getPrefs();
      // Remove all user-data keys (leave server_config.* keys intact).
      final userKeys = [
        _Keys.settings,
        _Keys.sessionDrafts,
        _Keys.sessionPermissionModes,
        _Keys.profile,
        _Keys.sessionLastSeq,
        _Keys.sessionFirstLoadedSeq,
      ];
      for (final k in userKeys) {
        await prefs.remove(k);
      }
      _sessionLastSeq = {};
      _sessionFirstLoadedSeq = {};
    } catch (e) {
      logger.warning('WebStorage: failed to clear all: $e');
    }
  }

  /// Test helper: write a raw string (for testing error handling).
  Future<void> writeRawString(String key, String value) async {
    final prefs = await _getPrefs();
    await prefs.setString(key, value);
  }

  // ─── Session message cache ──────────────────────────────────────────

  List<Map<String, dynamic>> getSessionMessages(String sessionId) {
    try {
      if (_prefs == null) return [];
      final raw = _prefs!.getString('session-messages-$sessionId');
      if (raw == null) return [];
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
    _getPrefs().then((prefs) {
      prefs.setString(
        'session-messages-$sessionId',
        jsonEncode(messages),
      );
    }).catchError((Object e) {
      logger.warning(
        'WebStorage: failed to save session messages: $e',
      );
    });
  }

  void clearSessionMessages(String sessionId) {
    _getPrefs().then((prefs) {
      prefs.remove('session-messages-$sessionId');
    }).catchError((Object e) {
      logger.warning(
        'WebStorage: failed to clear session messages: $e',
      );
    });
  }

  // ─── Outbox persistence ─────────────────────────────────────────────

  Future<String?> getOutboxEntries() async {
    final prefs = await _getPrefs();
    return prefs.getString('outbox-entries');
  }

  Future<void> saveOutboxEntries(String jsonStr) async {
    final prefs = await _getPrefs();
    await prefs.setString('outbox-entries', jsonStr);
  }
}

/// Web implementation of ServerConfigStorage.
///
/// Uses SharedPreferences with a `server_config.` prefix to namespace
/// keys, mirroring the separate MMKV instance used on native.
class ServerConfigStorage {
  factory ServerConfigStorage() => _instance;
  ServerConfigStorage._();
  static final ServerConfigStorage _instance = ServerConfigStorage._();

  SharedPreferences? _prefs;
  bool _initialized = false;

  // In-memory cache for synchronous getServerUrl / getLastServerUrlError
  String? _cachedServerUrl;
  String? _cachedServerUrlError;
  bool _cacheLoaded = false;

  static String _prefixedKey(String key) =>
      '${_Keys.serverConfigPrefix}$key';

  static Future<void> initialize() async {
    if (_instance._initialized) return;
    try {
      _instance._prefs = await SharedPreferences.getInstance();
      _instance._initialized = true;
      _instance._loadCache();
    } catch (e) {
      logger.warning('WebStorage(ServerConfigStorage): init failed: $e');
      rethrow;
    }
  }

  void _loadCache() {
    _cachedServerUrl =
        _prefs?.getString(_prefixedKey(_Keys.serverUrl));
    _cachedServerUrlError =
        _prefs?.getString(_prefixedKey(_Keys.serverUrlError));
    _cacheLoaded = true;
  }

  Future<SharedPreferences> _getPrefs() async {
    if (!_initialized) await initialize();
    return _prefs!;
  }

  /// Get custom server URL (synchronous via in-memory cache).
  String? getServerUrl() {
    if (!_cacheLoaded && _prefs != null) _loadCache();
    return _cachedServerUrl;
  }

  Future<void> setServerUrl(String? url) async {
    // Update the in-memory cache immediately so that synchronous callers
    // (e.g. getServerUrl() right after setServerUrl()) see the new value
    // without waiting for the async SharedPreferences write to complete.
    _cachedServerUrl =
        (url != null && url.trim().isNotEmpty) ? url.trim() : null;
    try {
      final prefs = await _getPrefs();
      final key = _prefixedKey(_Keys.serverUrl);
      if (_cachedServerUrl != null) {
        await prefs.setString(key, _cachedServerUrl!);
      } else {
        await prefs.remove(key);
      }
    } catch (e) {
      logger.warning('WebStorage: failed to set server URL: $e');
      rethrow;
    }
  }

  bool isUsingCustomServer() {
    final url = getServerUrl();
    return url != null && url.isNotEmpty;
  }

  Future<void> saveServerUrlError(String error) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(_prefixedKey(_Keys.serverUrlError), error);
      _cachedServerUrlError = error;
    } catch (e) {
      logger.warning('WebStorage: failed to save server URL error: $e');
    }
  }

  String? getLastServerUrlError() {
    if (!_cacheLoaded && _prefs != null) _loadCache();
    return _cachedServerUrlError;
  }

  Future<void> clearLastServerUrlError() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_prefixedKey(_Keys.serverUrlError));
      _cachedServerUrlError = null;
    } catch (e) {
      logger.warning('WebStorage: failed to clear server URL error: $e');
    }
  }

  Future<void> clearAll() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_prefixedKey(_Keys.serverUrl));
      await prefs.remove(_prefixedKey(_Keys.serverUrlError));
      _cachedServerUrl = null;
      _cachedServerUrlError = null;
    } catch (e) {
      logger.warning('WebStorage: failed to clear server config: $e');
    }
  }
}

/// Web implementation of ProfileStorage.
class ProfileStorage {
  factory ProfileStorage() => _instance;
  ProfileStorage._();
  static final ProfileStorage _instance = ProfileStorage._();

  static const String _profileKey = 'profile';
  final _storage = MMKVStorage();

  Future<models.Profile> loadProfile() async {
    try {
      final prefs = await _storage._getPrefs();
      final json = prefs.getString(_profileKey);
      if (json != null) {
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        return models.Profile(
          id: decoded['id'] as String? ?? '',
          timestamp: decoded['timestamp'] as int? ?? 0,
          firstName: decoded['firstName'] as String?,
          lastName: decoded['lastName'] as String?,
          connectedServices:
              (decoded['connectedServices'] as List<dynamic>?)
                      ?.map((e) => e as String)
                      .toList() ??
                  [],
        );
      }
    } catch (e) {
      logger.warning('WebStorage(ProfileStorage): failed to load profile: $e');
    }
    return models.Profile.defaults;
  }

  Future<void> saveProfile(models.Profile profile) async {
    try {
      final prefs = await _storage._getPrefs();
      await prefs.setString(
        _profileKey,
        jsonEncode({
          'id': profile.id,
          'timestamp': profile.timestamp,
          'firstName': profile.firstName,
          'lastName': profile.lastName,
          'connectedServices': profile.connectedServices,
        }),
      );
    } catch (e) {
      logger.warning('WebStorage(ProfileStorage): failed to save profile: $e');
      rethrow;
    }
  }

  Future<void> clearProfile() async {
    try {
      final prefs = await _storage._getPrefs();
      await prefs.remove(_profileKey);
    } catch (e) {
      logger.warning(
        'WebStorage(ProfileStorage): failed to clear profile', e,
      );
    }
  }
}
