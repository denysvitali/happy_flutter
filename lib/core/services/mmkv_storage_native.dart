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
  static const String sessionPermissionModes =
      'session-permission-modes';
  static const String sessionModelModes = 'session-model-modes';
  static const String sessionProfiles = 'session-profiles';
  static const String profile = 'profile';
  static const String migrationComplete = 'mmkv-migration-complete';
  static const String sessionLastSeq = 'session-last-seq';
  static const String sessionFirstLoadedSeq =
      'session-first-loaded-seq';
  static const String sessionsCache = 'sessions-cache';
}

/// Generic store for a JSON-encoded `Map<String, String>` in MMKV.
///
/// Used by session-scoped maps (drafts, permission modes, model
/// modes, profiles) to eliminate identical CRUD boilerplate.
class _JsonMapStore {
  _JsonMapStore({
    required MMKV? Function() mmkv,
    required String key,
    Map<String, String>? cache,
  })  : _mmkv = mmkv,
        _key = key,
        _cache = cache;

  final MMKV? Function() _mmkv;
  final String _key;
  Map<String, String>? _cache;
  Timer? _persistTimer;

  /// Load from MMKV into cache, returning the map.
  Map<String, String> _loadCache() {
    try {
      final json = _mmkv()?.decodeString(_key);
      if (json != null) {
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        return decoded.map(
            (k, v) => MapEntry(k, v as String));
      }
    } catch (e) {
      logger.warning('MMKV: Failed to load $_key: $e');
    }
    return {};
  }

  /// Get all entries (re-reads from MMKV each time).
  Future<Map<String, String>> getAll() async {
    try {
      return _loadCache();
    } catch (e) {
      logger.warning('MMKV: Failed to get all $_key: $e');
    }
    return {};
  }

  /// Get a single entry by key.
  Future<String?> get(String id) async {
    // Use warm in-memory cache if available to avoid repeated JSON parse
    final cache = _cache ??= _loadCache();
    return cache[id];
  }

  /// Get a single entry synchronously (direct MMKV read).
  String? getDirect(String id) {
    try {
      final cache = _cache ??= _loadCache();
      return cache[id];
    } catch (e) {
      logger.warning('MMKV: Failed to get direct $_key[$id]: $e');
    }
    return null;
  }

  /// Save a key-value pair, updating in-memory cache immediately
  /// and debouncing persist to MMKV (500ms) to batch rapid writes.
  Future<void> save(String id, String value) async {
    try {
      final map = _cache ??= _loadCache();
      map[id] = value;
      _schedulePersist();
    } catch (e) {
      logger.warning('MMKV: Failed to save $_key[$id]: $e');
      rethrow;
    }
  }

  /// Remove an entry by key, updating in-memory cache immediately
  /// and debouncing persist to MMKV (500ms) to batch rapid writes.
  Future<void> remove(String id) async {
    try {
      final map = _cache ??= _loadCache();
      if (map.containsKey(id)) {
        map.remove(id);
        _schedulePersist();
      }
    } catch (e) {
      logger.warning('MMKV: Failed to remove $_key[$id]: $e');
    }
  }

  static const _debounceDuration = Duration(milliseconds: 500);

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(_debounceDuration, _persistNow);
  }

  void _persistNow() {
    final cache = _cache;
    if (cache != null) {
      _mmkv()?.encodeString(_key, jsonEncode(cache));
    }
  }

  /// Clear the entire map from MMKV.
  Future<void> clear() async {
    try {
      _mmkv()?.removeValue(_key);
    } catch (e) {
      logger.warning('MMKV: Failed to clear $_key: $e');
    }
  }

  // ── Cached (synchronous) accessors for permission/model modes ──

  /// Get from in-memory cache (must call [initCache] first).
  String? getFromCache(String id) => _cache?[id];

  /// Save to in-memory cache and persist synchronously.
  void saveToCache(String id, String value) {
    _cache ??= {};
    _cache![id] = value;
    try {
      _mmkv()?.encodeString(_key, jsonEncode(_cache));
    } catch (e) {
      logger.warning('MMKV: Failed to save cached $_key[$id]: $e');
    }
  }

  /// Initialize cache from MMKV. Returns the loaded map.
  Future<Map<String, String>> initCache() async {
    _cache = _loadCache();
    return _cache!;
  }

  /// Clear the in-memory cache (call after MMKV clear).
  void clearCache() {
    _cache = null;
  }
}

/// Generic store for a JSON-encoded `Map<String, int>` cursor map
/// backed by an in-memory cache with synchronous access.
class _IntCursorStore {
  _IntCursorStore({
    required MMKV? Function() mmkv,
    required String key,
  })   : _mmkv = mmkv,
        _key = key;

  final MMKV? Function() _mmkv;
  final String _key;
  Map<String, int>? _cache;

  Map<String, int> _loadFromMMKV() {
    try {
      final json = _mmkv()?.decodeString(_key);
      if (json != null) {
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        return decoded.map((k, v) => MapEntry(k, v as int));
      }
    } catch (e) {
      logger.warning('MMKV: Failed to load $_key: $e');
    }
    return {};
  }

  /// Get all entries (returns cached copy if available).
  Map<String, int> getAll() {
    if (_cache != null) return Map<String, int>.from(_cache!);
    final loaded = _loadFromMMKV();
    if (loaded.isNotEmpty) {
      _cache = loaded;
      return Map<String, int>.from(_cache!);
    }
    return {};
  }

  /// Get a single entry by key (uses cache if available).
  int? getSingle(String id) {
    if (_cache != null) return _cache![id];
    return getAll()[id];
  }

  /// Replace the entire map and persist.
  void saveAll(Map<String, int> seqs) {
    try {
      _mmkv()?.encodeString(_key, jsonEncode(seqs));
      _cache = Map<String, int>.from(seqs);
    } catch (e) {
      logger.warning('MMKV: Failed to save $_key: $e');
    }
  }

  /// Update a single entry and persist.
  void saveSingle(String id, int value) {
    _cache ??= getAll();
    _cache![id] = value;
    try {
      _mmkv()?.encodeString(_key, jsonEncode(_cache));
    } catch (e) {
      logger.warning('MMKV: Failed to save $_key[$id]: $e');
    }
  }

  /// Clear all entries and reset cache.
  void clearAll() {
    try {
      _mmkv()?.removeValue(_key);
      _cache = null;
    } catch (e) {
      logger.warning('MMKV: Failed to clear $_key: $e');
    }
  }
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

  // Lazy-initialized stores
  late final _JsonMapStore _draftsStore = _JsonMapStore(
    mmkv: () => _mmkv,
    key: _StorageKeys.sessionDrafts,
  );
  late final _JsonMapStore _permissionModesStore = _JsonMapStore(
    mmkv: () => _mmkv,
    key: _StorageKeys.sessionPermissionModes,
  );
  late final _JsonMapStore _modelModesStore = _JsonMapStore(
    mmkv: () => _mmkv,
    key: _StorageKeys.sessionModelModes,
  );
  late final _JsonMapStore _profilesStore = _JsonMapStore(
    mmkv: () => _mmkv,
    key: _StorageKeys.sessionProfiles,
  );
  late final _IntCursorStore _lastSeqStore = _IntCursorStore(
    mmkv: () => _mmkv,
    key: _StorageKeys.sessionLastSeq,
  );
  late final _IntCursorStore _firstLoadedSeqStore = _IntCursorStore(
    mmkv: () => _mmkv,
    key: _StorageKeys.sessionFirstLoadedSeq,
  );

  Future<void> _ensureInitialized() async {
    if (!_initialized) await initialize();
  }

  /// Initialize MMKV and migrate data from SharedPreferences if needed
  static Future<void> initialize() async {
    if (_instance._initialized) return;

    try {
      await MMKV.initialize();
      _instance._mmkv = MMKV.defaultMMKV();
      _instance._initialized = true;

      // Initialize in-memory caches
      _instance._lastSeqStore.getAll();
      _instance._firstLoadedSeqStore.getAll();
      await _instance._permissionModesStore.initCache();
      await _instance._modelModesStore.initCache();

      // Check if migration is needed
      final migrationComplete =
          _instance._mmkv!.decodeBool(_StorageKeys.migrationComplete);

      if (!migrationComplete) {
        await _instance._migrateFromSharedPreferences();
        _instance._mmkv!.encodeBool(
          _StorageKeys.migrationComplete,
          true,
        );
        logger.info(
          'MMKV: Migration from SharedPreferences completed',
        );
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

      for (final key in [
        _StorageKeys.settings,
        _StorageKeys.sessionDrafts,
        _StorageKeys.sessionPermissionModes,
        _StorageKeys.profile,
      ]) {
        final json = prefs.getString(key);
        if (json != null) {
          _mmkv!.encodeString(key, json);
          await prefs.remove(key);
        }
      }
    } catch (e) {
      logger.warning('MMKV: Migration failed: $e');
    }
  }

  // ── Settings ────────────────────────────────────────────────────

  /// Get settings from storage
  Future<Settings> getSettings() async {
    await _ensureInitialized();
    try {
      final settingsJson =
          _mmkv?.decodeString(_StorageKeys.settings);
      if (settingsJson != null) {
        final decoded =
            jsonDecode(settingsJson) as Map<String, dynamic>;
        return Settings.fromJson(decoded);
      }
    } catch (e) {
      logger.warning('MMKV: Failed to load settings: $e');
    }
    return Settings();
  }

  /// Save settings to storage
  Future<void> saveSettings(Settings settings) async {
    await _ensureInitialized();
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
    await _ensureInitialized();
    try {
      _mmkv?.removeValue(_StorageKeys.settings);
    } catch (e) {
      logger.warning('MMKV: Failed to clear settings: $e');
    }
  }

  // ── Session drafts (delegates to _JsonMapStore) ─────────────────

  /// Get draft for a specific session
  Future<String?> getSessionDraft(String sessionId) async {
    await _ensureInitialized();
    return _draftsStore.get(sessionId);
  }

  /// Get draft for a specific session directly (synchronous)
  String? getSessionDraftDirect(String sessionId) {
    if (!_initialized) return null;
    return _draftsStore.getDirect(sessionId);
  }

  /// Save draft for a specific session
  Future<void> saveSessionDraft(
      String sessionId, String draft) async {
    await _ensureInitialized();
    return _draftsStore.save(sessionId, draft);
  }

  /// Remove draft for a specific session
  Future<void> removeSessionDraft(String sessionId) async {
    await _ensureInitialized();
    return _draftsStore.remove(sessionId);
  }

  /// Get all session drafts
  Future<Map<String, String>> getSessionDrafts() async {
    await _ensureInitialized();
    return _draftsStore.getAll();
  }

  /// Clear all session drafts
  Future<void> clearSessionDrafts() async {
    await _ensureInitialized();
    return _draftsStore.clear();
  }

  // ── Session permission modes (delegates to _JsonMapStore) ──────

  /// Get permission mode for a specific session
  Future<String?> getSessionPermissionMode(
      String sessionId) async {
    await _ensureInitialized();
    return _permissionModesStore.get(sessionId);
  }

  /// Save permission mode for a specific session
  Future<void> saveSessionPermissionMode(
      String sessionId, String mode) async {
    await _ensureInitialized();
    return _permissionModesStore.save(sessionId, mode);
  }

  /// Remove permission mode for a specific session
  Future<void> removeSessionPermissionMode(
      String sessionId) async {
    await _ensureInitialized();
    return _permissionModesStore.remove(sessionId);
  }

  /// Get all session permission modes
  Future<Map<String, String>> getSessionPermissionModes() async {
    await _ensureInitialized();
    return _permissionModesStore.getAll();
  }

  /// Clear all session permission modes
  Future<void> clearSessionPermissionModes() async {
    await _ensureInitialized();
    await _permissionModesStore.clear();
    _permissionModesStore.clearCache();
  }

  /// Get permission mode directly from cache (synchronous)
  String? getSessionPermissionModeDirect(String sessionId) {
    if (!_initialized) return null;
    return _permissionModesStore.getFromCache(sessionId);
  }

  /// Save permission mode to cache and persist (synchronous)
  void saveSessionPermissionModeDirect(
      String sessionId, String mode) {
    if (!_initialized) return;
    _permissionModesStore.saveToCache(sessionId, mode);
  }

  // ── Session model modes (delegates to _JsonMapStore) ────────────

  /// Get model mode for a specific session
  Future<String?> getSessionModelMode(String sessionId) async {
    await _ensureInitialized();
    return _modelModesStore.get(sessionId);
  }

  /// Save model mode for a specific session
  Future<void> saveSessionModelMode(
      String sessionId, String mode) async {
    await _ensureInitialized();
    await _modelModesStore.save(sessionId, mode);
    // Update cache
    _modelModesStore.saveToCache(sessionId, mode);
  }

  /// Get model mode directly from cache (synchronous)
  String? getSessionModelModeDirect(String sessionId) {
    if (!_initialized) return null;
    return _modelModesStore.getFromCache(sessionId);
  }

  /// Save model mode to cache and persist (synchronous)
  void saveSessionModelModeDirect(
      String sessionId, String mode) {
    if (!_initialized) return;
    _modelModesStore.saveToCache(sessionId, mode);
  }

  // ── Session profiles (delegates to _JsonMapStore) ───────────────

  /// Get profile ID for a specific session
  Future<String?> getSessionProfile(String sessionId) async {
    await _ensureInitialized();
    return _profilesStore.get(sessionId);
  }

  /// Save profile ID for a specific session
  Future<void> saveSessionProfile(
      String sessionId, String profileId) async {
    await _ensureInitialized();
    return _profilesStore.save(sessionId, profileId);
  }

  /// Remove profile ID for a specific session
  Future<void> removeSessionProfile(String sessionId) async {
    await _ensureInitialized();
    return _profilesStore.remove(sessionId);
  }

  // ── Session last-seq (delegates to _IntCursorStore) ─────────────

  /// Get all persisted session last-seq cursors (synchronous)
  Map<String, int> getSessionLastSeq() => _lastSeqStore.getAll();

  /// Get a single session's last-seq cursor (synchronous, cached)
  int? getSessionLastSeqSingle(String sessionId) =>
      _lastSeqStore.getSingle(sessionId);

  /// Persist all session last-seq cursors (synchronous)
  void saveSessionLastSeq(Map<String, int> seqs) =>
      _lastSeqStore.saveAll(seqs);

  /// Update a single session's last-seq cursor (synchronous, cached)
  void saveSessionLastSeqSingle(String sessionId, int seq) =>
      _lastSeqStore.saveSingle(sessionId, seq);

  /// Clear all session last-seq cursors
  void clearSessionLastSeq() => _lastSeqStore.clearAll();

  // ── Session first-loaded-seq (delegates to _IntCursorStore) ─────

  /// Get all persisted session first-loaded-seq cursors (synchronous)
  Map<String, int> getSessionFirstLoadedSeq() =>
      _firstLoadedSeqStore.getAll();

  /// Get a single session's first-loaded-seq cursor (sync, cached)
  int? getSessionFirstLoadedSeqSingle(String sessionId) =>
      _firstLoadedSeqStore.getSingle(sessionId);

  /// Persist all session first-loaded-seq cursors (synchronous)
  void saveSessionFirstLoadedSeq(Map<String, int> seqs) =>
      _firstLoadedSeqStore.saveAll(seqs);

  /// Update a single session's first-loaded-seq cursor (sync)
  void saveSessionFirstLoadedSeqSingle(
          String sessionId, int seq) =>
      _firstLoadedSeqStore.saveSingle(sessionId, seq);

  /// Clear all session first-loaded-seq cursors
  void clearSessionFirstLoadedSeq() =>
      _firstLoadedSeqStore.clearAll();

  // ── Sessions cache ──────────────────────────────────────────────

  Map<String, dynamic>? getSessionsCache() {
    if (!_initialized) return null;
    try {
      final json = _mmkv?.decodeString(_StorageKeys.sessionsCache);
      if (json == null || json.isEmpty) return null;
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) return decoded;
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
      _mmkv?.encodeString(
          _StorageKeys.sessionsCache, jsonEncode(cache));
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

  // ── Clear all ───────────────────────────────────────────────────

  /// Clear all data from MMKV storage
  Future<void> clearAll() async {
    await _ensureInitialized();
    try {
      _mmkv?.clearAll();
    } catch (e) {
      logger.warning('MMKV: Failed to clear all: $e');
    }
  }

  /// Test helper: Write raw string to MMKV (for testing error handling)
  Future<void> writeRawString(String key, String value) async {
    await _ensureInitialized();
    _mmkv?.encodeString(key, value);
  }

  // ─── Session message cache ──────────────────────────────────────

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

  // ─── Outbox persistence ─────────────────────────────────────────

  Future<String?> getOutboxEntries() async {
    await _ensureInitialized();
    return _mmkv?.decodeString('outbox-entries');
  }

  Future<void> saveOutboxEntries(String jsonStr) async {
    await _ensureInitialized();
    _mmkv?.encodeString('outbox-entries', jsonStr);
  }
}

/// Server configuration storage using separate MMKV instance.
/// This persists across logouts and is separate from user data.
class ServerConfigStorage {
  factory ServerConfigStorage() => _instance;
  ServerConfigStorage._();
  static final ServerConfigStorage _instance =
      ServerConfigStorage._();

  MMKV? _mmkv;
  bool _initialized = false;

  static const String _serverUrlKey = 'custom-server-url';
  static const String _serverUrlErrorKey =
      'last-server-url-error';

  Future<void> _ensureInitialized() async {
    if (!_initialized) await initialize();
  }

  /// Ensure initialized synchronously (for sync getters).
  void _syncInit() {
    if (!_initialized) {
      try {
        _mmkv = MMKV('server-config');
        _initialized = true;
      } catch (e) {
        logger.warning(
          'ServerConfigStorage: Sync init failed: $e',
        );
      }
    }
  }

  /// Initialize server config MMKV instance
  static Future<void> initialize() async {
    if (_instance._initialized) return;

    try {
      await MMKV.initialize();
      _instance._mmkv = MMKV('server-config');
      _instance._initialized = true;
    } catch (e) {
      logger.warning(
        'ServerConfigStorage: Initialization failed: $e',
      );
      rethrow;
    }
  }

  /// Get custom server URL
  String? getServerUrl() {
    _syncInit();
    if (!_initialized) return null;
    try {
      return _mmkv?.decodeString(_serverUrlKey);
    } catch (e) {
      logger.warning(
        'ServerConfigStorage: Failed to get server URL: $e',
      );
      return null;
    }
  }

  /// Set custom server URL
  Future<void> setServerUrl(String? url) async {
    await _ensureInitialized();
    try {
      if (url != null && url.trim().isNotEmpty) {
        _mmkv?.encodeString(_serverUrlKey, url.trim());
      } else {
        _mmkv?.removeValue(_serverUrlKey);
      }
    } catch (e) {
      logger.warning(
        'ServerConfigStorage: Failed to set server URL: $e',
      );
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
    await _ensureInitialized();
    try {
      _mmkv?.encodeString(_serverUrlErrorKey, error);
    } catch (e) {
      logger.warning(
        'ServerConfigStorage: Failed to save server URL error',
        e,
      );
    }
  }

  /// Get the last server URL error
  String? getLastServerUrlError() {
    _syncInit();
    if (!_initialized) return null;
    try {
      return _mmkv?.decodeString(_serverUrlErrorKey);
    } catch (e) {
      logger.warning(
        'ServerConfigStorage: Failed to get server URL error',
        e,
      );
      return null;
    }
  }

  /// Clear the last server URL error
  Future<void> clearLastServerUrlError() async {
    await _ensureInitialized();
    try {
      _mmkv?.removeValue(_serverUrlErrorKey);
    } catch (e) {
      logger.warning(
        'ServerConfigStorage: Failed to clear server URL error',
        e,
      );
    }
  }

  /// Clear all server config data
  Future<void> clearAll() async {
    await _ensureInitialized();
    try {
      _mmkv?.clearAll();
    } catch (e) {
      logger.warning(
        'ServerConfigStorage: Failed to clear all: $e',
      );
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
        final decoded =
            jsonDecode(profileJson) as Map<String, dynamic>;
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
      logger.warning(
        'ProfileStorage: Failed to load profile: $e',
      );
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
      logger.warning(
        'ProfileStorage: Failed to save profile: $e',
      );
      rethrow;
    }
  }

  /// Clear profile from storage
  Future<void> clearProfile() async {
    try {
      _storage._mmkv?.removeValue(_StorageKeys.profile);
    } catch (e) {
      logger.warning(
        'ProfileStorage: Failed to clear profile: $e',
      );
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
