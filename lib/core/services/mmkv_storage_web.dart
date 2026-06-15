// Web-only storage implementation using IndexedDB via idb_shim.
//
// localStorage (SharedPreferences on web) has a ~5–10 MB quota shared across
// all keys. Session message caches, per-session maps, and settings can easily
// exceed this limit. IndexedDB provides a much larger quota (50 MB+) and
// avoids QuotaExceededError.
//
// On first run, data is migrated from SharedPreferences (localStorage) to
// IndexedDB. After migration, SharedPreferences is cleared to free the
// localStorage quota.
//
// This file must NOT import dart:io.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:idb_shim/idb_browser.dart';
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
  static const String installedVersion = 'installed-version';

  // Server config keys moved to server_config_storage_web.dart.
}

const String _dbName = 'happy_storage';
const String _storeName = 'kv';
const String _migratedKey = '_idb_migrated';

/// IndexedDB-backed storage for web.
///
/// Mirrors the public API of the native [MMKVStorage] so that callers
/// remain source-compatible across platforms.
class MMKVStorage {
  factory MMKVStorage() => _instance;
  MMKVStorage._();

  /// Named constructor for test fakes that need to extend MMKVStorage.
  @visibleForTesting
  MMKVStorage.testConstructor();

  static final MMKVStorage _instance = MMKVStorage._();

  Database? _db;
  final Map<String, String> _cache = {};
  final Set<String> _sessionMessageCacheKeys = <String>{};
  bool _initialized = false;

  // In-memory caches for the synchronous seq methods.
  Map<String, int> _sessionLastSeq = {};
  Map<String, int> _sessionFirstLoadedSeq = {};

  /// Initialise the IndexedDB instance and migrate from SharedPreferences.
  static Future<void> initialize() async {
    if (_instance._initialized) return;
    try {
      final idbFactory = getIdbFactory();
      if (idbFactory == null) {
        throw StateError('IndexedDB not supported in this browser');
      }

      _instance._db = await idbFactory.open(
        _dbName,
        version: 1,
        onUpgradeNeeded: (VersionChangeEvent event) {
          final db = event.database;
          if (!db.objectStoreNames.contains(_storeName)) {
            db.createObjectStore(_storeName);
          }
        },
      );

      // Migrate from SharedPreferences (localStorage) on first run.
      await _instance._migrateFromLocalStorage();

      // Load all data into memory for synchronous reads.
      await _instance._loadAll();

      _instance._initialized = true;
      _instance._loadSeqCaches();
    } catch (e) {
      logger.warning('WebStorage(MMKVStorage): init failed: $e');
      rethrow;
    }
  }

  /// Migrate data from SharedPreferences (localStorage) to IndexedDB.
  ///
  /// On first run after the code upgrade, all existing localStorage data is
  /// copied into IndexedDB. SharedPreferences is then cleared to free the
  /// 5–10 MB localStorage quota. A migration flag prevents re-running.
  Future<void> _migrateFromLocalStorage() async {
    try {
      // Check if migration already done.
      final txn = _db!.transaction(_storeName, idbModeReadOnly);
      final store = txn.objectStore(_storeName);
      final migrated = await store.getObject(_migratedKey);
      await txn.completed;
      if (migrated != null) return;

      // Read all data from SharedPreferences.
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys().toList();

      if (allKeys.isNotEmpty) {
        final writeTxn = _db!.transaction(_storeName, idbModeReadWrite);
        final writeStore = writeTxn.objectStore(_storeName);
        for (final key in allKeys) {
          final value = prefs.getString(key);
          if (value != null) {
            unawaited(writeStore.put(value, key));
          }
        }
        unawaited(writeStore.put('true', _migratedKey));
        await writeTxn.completed;

        // Free localStorage quota.
        await prefs.clear();

        logger.info(
          'WebStorage: migrated ${allKeys.length} keys '
          'from localStorage to IndexedDB',
        );
      } else {
        // No data to migrate — just mark as done.
        final writeTxn = _db!.transaction(_storeName, idbModeReadWrite);
        final writeStore = writeTxn.objectStore(_storeName);
        unawaited(writeStore.put('true', _migratedKey));
        await writeTxn.completed;
      }
    } catch (e) {
      logger.warning('WebStorage: migration from localStorage failed: $e');
      // Non-fatal — proceed with empty cache; data will be re-fetched
      // from the server.
    }
  }

  /// Load all IndexedDB entries into the in-memory cache.
  ///
  /// Session message blobs (`session-messages-*`) are skipped — they can
  /// be large (200 messages × ~1KB each) and loading all of them for
  /// every session into Dart memory at startup causes OOM on web,
  /// especially under CanvasKit. They are loaded on-demand in
  /// [getSessionMessages].
  Future<void> _loadAll() async {
    try {
      final txn = _db!.transaction(_storeName, idbModeReadOnly);
      final store = txn.objectStore(_storeName);
      final keys = await store.getAllKeys(null);
      for (final key in keys) {
        if (key == _migratedKey) continue;
        final keyStr = key as String;
        if (keyStr.startsWith('session-messages-')) {
          _sessionMessageCacheKeys.add(keyStr);
          continue;
        }
        final value = await store.getObject(key);
        if (value is String) {
          _cache[keyStr] = value;
        }
      }
      await txn.completed;
    } catch (e) {
      logger.warning('WebStorage: failed to load cache: $e');
    }
  }

  void _loadSeqCaches() {
    _sessionLastSeq = _readIntMap(_Keys.sessionLastSeq);
    _sessionFirstLoadedSeq = _readIntMap(_Keys.sessionFirstLoadedSeq);
  }

  Map<String, int> _readIntMap(String key) {
    try {
      final json = _cache[key];
      if (json != null) {
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        return decoded.map((k, v) => MapEntry(k, v as int));
      }
    } catch (e) {
      logger.warning('WebStorage: failed to read int map "$key": $e');
    }
    return {};
  }

  // ── Persistence helpers ──────────────────────────────────────────────────

  /// Update in-memory cache and fire-and-forget persist to IndexedDB.
  void _persist(String key, String value) {
    _cache[key] = value;
    _doPersist(key, value);
  }

  Future<void> _doPersist(String key, String value) async {
    try {
      final txn = _db!.transaction(_storeName, idbModeReadWrite);
      final store = txn.objectStore(_storeName);
      await store.put(value, key);
      await txn.completed;
    } catch (e) {
      logger.warning('IndexedDB: failed to persist "$key": $e');
    }
  }

  /// Update in-memory cache and await IndexedDB write.
  Future<void> _persistAsync(String key, String value) async {
    _cache[key] = value;
    await _doPersist(key, value);
  }

  /// Remove from in-memory cache and fire-and-forget delete from IndexedDB.
  void _remove(String key) {
    _cache.remove(key);
    _doRemove(key);
  }

  Future<void> _doRemove(String key) async {
    try {
      final txn = _db!.transaction(_storeName, idbModeReadWrite);
      final store = txn.objectStore(_storeName);
      await store.delete(key);
      await txn.completed;
    } catch (e) {
      logger.warning('IndexedDB: failed to delete "$key": $e');
    }
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  Future<Settings> getSettings() async {
    try {
      final json = _cache[_Keys.settings];
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
      await _persistAsync(_Keys.settings, jsonEncode(settings.toJson()));
    } catch (e) {
      // IndexedDB is much larger than localStorage, but log and continue
      // on any failure — settings will be re-fetched from server on
      // next app start.
      logger.warning('WebStorage: failed to save settings: $e');
    }
  }

  Future<void> clearSettings() async {
    _remove(_Keys.settings);
  }

  // ── Session drafts ────────────────────────────────────────────────────────

  Future<String?> getSessionDraft(String sessionId) async {
    try {
      final json = _cache[_Keys.sessionDrafts];
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
      final json = _cache[_Keys.sessionDrafts];
      final map = json != null
          ? jsonDecode(json) as Map<String, dynamic>
          : <String, dynamic>{};
      map[sessionId] = draft;
      await _persistAsync(_Keys.sessionDrafts, jsonEncode(map));
    } catch (e) {
      logger.warning('WebStorage: failed to save session draft: $e');
    }
  }

  Future<void> removeSessionDraft(String sessionId) async {
    try {
      final json = _cache[_Keys.sessionDrafts];
      if (json != null) {
        final map = (jsonDecode(json) as Map<String, dynamic>)
          ..remove(sessionId);
        await _persistAsync(_Keys.sessionDrafts, jsonEncode(map));
      }
    } catch (e) {
      logger.warning('WebStorage: failed to remove session draft: $e');
    }
  }

  Future<Map<String, String>> getSessionDrafts() async {
    try {
      final json = _cache[_Keys.sessionDrafts];
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
    _remove(_Keys.sessionDrafts);
  }

  // ── Session permission modes ───────────────────────────────────────────

  Future<String?> getSessionPermissionMode(String sessionId) async {
    try {
      final json = _cache[_Keys.sessionPermissionModes];
      if (json != null) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return map[sessionId] as String?;
      }
    } catch (e) {
      logger.warning('WebStorage: failed to get session permission mode: $e');
    }
    return null;
  }

  Future<void> saveSessionPermissionMode(String sessionId, String mode) async {
    try {
      final json = _cache[_Keys.sessionPermissionModes];
      final map = json != null
          ? jsonDecode(json) as Map<String, dynamic>
          : <String, dynamic>{};
      map[sessionId] = mode;
      await _persistAsync(_Keys.sessionPermissionModes, jsonEncode(map));
    } catch (e) {
      logger.warning('WebStorage: failed to save session permission mode: $e');
    }
  }

  Future<void> removeSessionPermissionMode(String sessionId) async {
    try {
      final json = _cache[_Keys.sessionPermissionModes];
      if (json != null) {
        final map = (jsonDecode(json) as Map<String, dynamic>)
          ..remove(sessionId);
        await _persistAsync(_Keys.sessionPermissionModes, jsonEncode(map));
      }
    } catch (e) {
      logger.warning(
        'WebStorage: failed to remove session permission mode: $e',
      );
    }
  }

  Future<Map<String, String>> getSessionPermissionModes() async {
    try {
      final json = _cache[_Keys.sessionPermissionModes];
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
    _remove(_Keys.sessionPermissionModes);
  }

  // ── Session profiles ───────────────────────────────────────────────────

  Future<String?> getSessionProfile(String sessionId) async {
    try {
      final json = _cache[_Keys.sessionProfiles];
      if (json != null) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return map[sessionId] as String?;
      }
    } catch (e) {
      logger.warning('WebStorage: failed to get session profile: $e');
    }
    return null;
  }

  // ── Session model modes ────────────────────────────────────────────────

  Future<String?> getSessionModelMode(String sessionId) async {
    try {
      final json = _cache[_Keys.sessionModelModes];
      if (json != null) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return map[sessionId] as String?;
      }
    } catch (e) {
      logger.warning('WebStorage: failed to get session model mode: $e');
    }
    return null;
  }

  Future<void> saveSessionModelMode(String sessionId, String mode) async {
    try {
      final json = _cache[_Keys.sessionModelModes];
      final map = json != null
          ? jsonDecode(json) as Map<String, dynamic>
          : <String, dynamic>{};
      map[sessionId] = mode;
      await _persistAsync(_Keys.sessionModelModes, jsonEncode(map));
    } catch (e) {
      logger.warning('WebStorage: failed to save session model mode: $e');
    }
  }

  Future<void> saveSessionProfile(String sessionId, String profileId) async {
    try {
      final json = _cache[_Keys.sessionProfiles];
      final map = json != null
          ? jsonDecode(json) as Map<String, dynamic>
          : <String, dynamic>{};
      map[sessionId] = profileId;
      await _persistAsync(_Keys.sessionProfiles, jsonEncode(map));
    } catch (e) {
      logger.warning('WebStorage: failed to save session profile: $e');
    }
  }

  Future<void> removeSessionProfile(String sessionId) async {
    try {
      final json = _cache[_Keys.sessionProfiles];
      if (json != null) {
        final map = (jsonDecode(json) as Map<String, dynamic>)
          ..remove(sessionId);
        await _persistAsync(_Keys.sessionProfiles, jsonEncode(map));
      }
    } catch (e) {
      logger.warning('WebStorage: failed to remove session profile: $e');
    }
  }

  /// Get every persisted (sessionId -> profileId) mapping. Used by the
  /// stale-profile sweep when a profile is deleted from settings.
  Future<Map<String, String>> getAllSessionProfiles() async {
    try {
      final json = _cache[_Keys.sessionProfiles];
      if (json != null) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return map.map((k, v) => MapEntry(k, v as String));
      }
    } catch (e) {
      logger.warning('WebStorage: failed to get all session profiles: $e');
    }
    return {};
  }

  // ── Synchronous seq cursors (backed by in-memory cache) ───────────────

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
      final json = _cache[_Keys.sessionsCache];
      if (json == null || json.isEmpty) return null;
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e) {
      logger.warning('WebStorage: failed to load sessions cache: $e');
    }
    return null;
  }

  void saveSessionsCache(Map<String, dynamic> cache) {
    if (!_initialized) return;
    _persist(_Keys.sessionsCache, jsonEncode(cache));
  }

  void clearSessionsCache() {
    if (!_initialized) return;
    _remove(_Keys.sessionsCache);
  }

  void _persistIntMap(String key, Map<String, int> map) {
    // Fire-and-forget; errors are logged but not thrown.
    _persist(key, jsonEncode(map));
  }

  // ── Clear all ─────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    try {
      // Remove all user-data keys (leave server_config.* keys intact).
      final userKeys = [
        _Keys.settings,
        _Keys.sessionDrafts,
        _Keys.sessionPermissionModes,
        _Keys.sessionModelModes,
        _Keys.sessionProfiles,
        _Keys.profile,
        _Keys.sessionLastSeq,
        _Keys.sessionFirstLoadedSeq,
        _Keys.sessionsCache,
      ];
      for (final k in userKeys) {
        _cache.remove(k);
      }
      // Remove session message keys.
      _cache.removeWhere((k, _) => k.startsWith('session-messages-'));
      // Persist deletions to IndexedDB.
      final txn = _db!.transaction(_storeName, idbModeReadWrite);
      final store = txn.objectStore(_storeName);
      for (final k in userKeys) {
        unawaited(store.delete(k));
      }
      // Clear all session message keys from IndexedDB.
      final allKeys = await store.getAllKeys(null);
      for (final k in allKeys) {
        if ((k as String).startsWith('session-messages-')) {
          unawaited(store.delete(k));
        }
      }
      await txn.completed;
      _sessionLastSeq = {};
      _sessionFirstLoadedSeq = {};
      _sessionMessageCacheKeys.clear();
    } catch (e) {
      logger.warning('WebStorage: failed to clear all: $e');
    }
  }

  /// Test helper: write a raw string (for testing error handling).
  Future<void> writeRawString(String key, String value) async {
    await _persistAsync(key, value);
  }

  // ─── Session message cache ──────────────────────────────────────────

  List<Map<String, dynamic>> getSessionMessages(String sessionId) {
    final key = 'session-messages-$sessionId';
    try {
      final raw = _cache[key];
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSessionMessagesAsync(
    String sessionId,
  ) async {
    final key = 'session-messages-$sessionId';
    try {
      var raw = _cache[key];
      if (raw == null && _sessionMessageCacheKeys.contains(key)) {
        final txn = _db!.transaction(_storeName, idbModeReadOnly);
        final store = txn.objectStore(_storeName);
        final value = await store.getObject(key);
        await txn.completed;
        if (value is String) {
          raw = value;
          _cache[key] = value;
        }
      }
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      logger.warning('WebStorage: failed to read messages for $sessionId: $e');
      return [];
    }
  }

  /// Returns all session IDs that have cached messages.
  List<String> getCachedSessionIds() {
    const prefix = 'session-messages-';
    return _sessionMessageCacheKeys
        .where((k) => k.startsWith(prefix))
        .map((k) => k.substring(prefix.length))
        .toList();
  }

  /// Saves messages to the cache.
  ///
  /// Returns `true` on success, `false` if the IndexedDB write fails
  /// (e.g. QuotaExceededError). On failure the in-memory cache is
  /// updated so reads stay consistent, but the data will not survive
  /// a page reload.
  bool saveSessionMessages(
    String sessionId,
    List<Map<String, dynamic>> messages,
  ) {
    return saveSessionMessagesEncoded(sessionId, jsonEncode(messages));
  }

  bool saveSessionMessagesEncoded(String sessionId, String encodedMessages) {
    final key = 'session-messages-$sessionId';
    // Always update in-memory cache so reads are consistent.
    _cache[key] = encodedMessages;
    _sessionMessageCacheKeys.add(key);
    // Fire-and-forget persist; errors are logged inside _doPersist.
    _doPersist(key, encodedMessages);
    return true;
  }

  void clearSessionMessages(String sessionId) {
    final key = 'session-messages-$sessionId';
    _sessionMessageCacheKeys.remove(key);
    _remove(key);
  }

  // ─── Generic key-value access ────────────────────────────────────────

  /// Read a raw string for an arbitrary key.
  String? getString(String key) => _cache[key];

  /// Write a raw string for an arbitrary key.
  void setString(String key, String value) {
    _persist(key, value);
  }

  /// Read a raw bool for an arbitrary key.
  bool? getBool(String key) {
    final value = _cache[key];
    if (value == null) return null;
    return value == 'true';
  }

  /// Write a raw bool for an arbitrary key.
  void setBool(String key, bool value) {
    _persist(key, value.toString());
  }

  /// Remove a single key.
  void removeKey(String key) {
    _remove(key);
  }

  // ─── Version tracking ─────────────────────────────────────────────

  /// Get the installed version (null if first install)
  String? getInstalledVersion() {
    if (!_initialized) return null;
    return _cache[_Keys.installedVersion];
  }

  /// Save the installed version
  void setInstalledVersion(String version) {
    if (!_initialized) return;
    _persist(_Keys.installedVersion, version);
  }

  // ─── Outbox persistence ─────────────────────────────────────────────

  Future<String?> getOutboxEntries() async {
    return _cache['outbox-entries'];
  }

  Future<void> saveOutboxEntries(String jsonStr) async {
    await _persistAsync('outbox-entries', jsonStr);
  }
}

// ServerConfigStorage has been extracted to server_config_storage.dart
// (conditional export: server_config_storage_web.dart / _native.dart).

/// Web implementation of ProfileStorage.
class ProfileStorage {
  factory ProfileStorage() => _instance;
  ProfileStorage._();
  static final ProfileStorage _instance = ProfileStorage._();

  static const String _profileKey = 'profile';
  final _storage = MMKVStorage();

  Future<models.Profile> loadProfile() async {
    try {
      final json = _storage._cache[_profileKey];
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
      await _storage._persistAsync(
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
    }
  }

  Future<void> clearProfile() async {
    _storage._remove(_profileKey);
  }
}
