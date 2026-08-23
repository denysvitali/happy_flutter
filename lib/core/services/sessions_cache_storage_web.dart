// Web-only sessions cache storage using IndexedDB via idb_shim.
//
// localStorage (SharedPreferences on web) has a ~5–10 MB quota shared across
// all keys. The sessions cache with hundreds of sessions can consume ~2 MB,
// leaving insufficient room for settings and other data. IndexedDB provides
// a much larger quota (50 MB+) and structured storage per key.
//
// Layout: one index record (`cache-index`) describing the snapshot plus one
// record per cached session (`session:<id>`). Saves encode per-session
// records in batches with event-loop yields, diff against what was last
// observed, and write only changed shards; the cold-start load decodes
// shards in batches the same way. A ~200-session cache therefore no longer
// jsonEncodes or jsonDecodes the whole ~2 MB blob in one blocking pass on
// the UI isolate. Caches written by older builds live in the single legacy
// `cache` record and are still read; the first successful sharded save
// removes that record.
//
// This file must NOT import dart:io.
library;

import 'dart:async';
import 'dart:convert';

import 'package:idb_shim/idb_browser.dart';

import '../utils/json_decoders.dart';
import 'logger_service.dart' show logger;

/// Storage key for the sessions cache in IndexedDB.
const String _sessionsCacheDbName = 'happy_sessions_cache';
const String _sessionsCacheStoreName = 'sessions_cache';

/// Legacy single-blob record written by older builds. Still read when no
/// index exists; removed after the first successful sharded save.
const String _sessionsCacheLegacyKey = 'cache';

/// Index record for the sharded layout.
const String _sessionsCacheIndexKey = 'cache-index';

/// Prefix for per-session shard keys.
const String _sessionsCacheShardPrefix = 'session:';

/// Format version stored inside the index record. A mismatched or missing
/// version falls back to the legacy single-blob read path.
const int _sessionsCacheShardFormatVersion = 1;

/// Records encoded / decoded per event-loop yield, mirroring
/// `_coldStartSessionRestoreBatchSize` in the Sync layer.
const int _sessionsCacheBatchSize = 25;

/// One session shard: its encoded form plus the instance it came from.
///
/// Sync reuses the same `toJson()` map until a Session object actually
/// changes, so an identical instance skips even the per-session re-encode.
class _SessionShard {
  const _SessionShard(this.json, this.instance);

  final String json;
  final Map<dynamic, dynamic> instance;
}

/// Sessions cache storage for web using IndexedDB.
///
/// Replaces SharedPreferences (localStorage) for the sessions cache only.
/// Other small data (settings, drafts, permission modes) stays in
/// SharedPreferences to avoid wasting IndexedDB overhead.
class SessionsCacheStorage {
  SessionsCacheStorage._();
  static final SessionsCacheStorage instance = SessionsCacheStorage._();

  Database? _db;

  /// Encoded JSON last observed (read or committed) per session id. Saves
  /// diff against it so unchanged shards produce no IndexedDB writes after
  /// a page reload.
  final Map<String, String> _knownShardJson = {};

  /// Source instances behind [_knownShardJson], for the O(1) identity
  /// fast path that skips the per-session encode entirely.
  final Map<String, Map<dynamic, dynamic>> _knownShardObjects = {};

  /// Session ids referenced by the last observed index.
  Set<String> _knownShardIds = <String>{};

  /// Index JSON last observed, so no-op saves skip the transaction.
  String? _knownIndexJson;

  /// Whether the legacy single-blob record has been removed after a
  /// successful sharded save.
  bool _legacyBlobRemoved = false;

  /// Opens the IndexedDB database, creating it if it doesn't exist.
  Future<Database> _openDb() async {
    if (_db != null) return _db!;
    final idbFactory = getIdbFactory();
    if (idbFactory == null) {
      throw StateError('IndexedDB not supported in this browser');
    }
    _db = await idbFactory.open(
      _sessionsCacheDbName,
      version: 1,
      onUpgradeNeeded: (VersionChangeEvent event) {
        final db = event.database;
        if (!db.objectStoreNames.contains(_sessionsCacheStoreName)) {
          db.createObjectStore(_sessionsCacheStoreName);
        }
      },
    );
    return _db!;
  }

  /// Reads one record in its own short read-only transaction.
  Future<Object?> _getObject(Database db, String key) async {
    final txn = db.transaction(_sessionsCacheStoreName, idbModeReadOnly);
    final value = await txn.objectStore(_sessionsCacheStoreName).getObject(key);
    await txn.completed;
    return value;
  }

  /// Async version — use this for cold-start load.
  ///
  /// Reads the index first; when present, assembles the same snapshot map
  /// the legacy single-blob layout produced, decoding shards in batches
  /// with event-loop yields between them. Falls back to the legacy record
  /// when there is no usable index.
  Future<Map<String, dynamic>?> getSessionsCacheAsync() async {
    try {
      final db = await _openDb();
      final indexRaw = await _getObject(db, _sessionsCacheIndexKey);
      if (indexRaw is String) {
        final index = JsonDecoders.tryDecodeRawMapOrNull(
          indexRaw,
          context: 'IndexedDB sessions cache index',
        );
        if (index != null && index['v'] == _sessionsCacheShardFormatVersion) {
          return await _loadShardedCache(db, index);
        }
      }
      return await _loadLegacyCache(db);
    } catch (e) {
      logger.warning('IndexedDB: failed to load sessions cache: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> _loadShardedCache(
    Database db,
    Map<String, dynamic> index,
  ) async {
    final ids = <String>[
      for (final id in index['ids'] ?? const <dynamic>[])
        if (id is String) id,
    ];
    // Fetch every record once in a single read-only transaction — IndexedDB
    // transactions auto-commit across event-loop yields, so requests must
    // never be interleaved with the decode batching below.
    final txn = db.transaction(_sessionsCacheStoreName, idbModeReadOnly);
    final store = txn.objectStore(_sessionsCacheStoreName);
    final keys = await store.getAllKeys(null);
    final values = await store.getAll(null);
    await txn.completed;
    // getAllKeys/getAll return entries in the same (key order) sequence.
    final rawByKey = <String, Object?>{};
    final bound = keys.length <= values.length ? keys.length : values.length;
    for (var i = 0; i < bound; i++) {
      final key = keys[i];
      if (key is String) rawByKey[key] = values[i];
    }

    final sessions = <Map<String, dynamic>>[];
    var processed = 0;
    for (final id in ids) {
      final raw = rawByKey['$_sessionsCacheShardPrefix$id'];
      if (raw is String) {
        _knownShardJson[id] = raw;
        final decoded = JsonDecoders.tryDecodeRawMapOrNull(
          raw,
          context: 'IndexedDB sessions cache shard $id',
        );
        if (decoded != null) sessions.add(decoded);
      }
      processed++;
      if (processed % _sessionsCacheBatchSize == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    // A missing shard (quota eviction, crashed save) degrades to loading
    // fewer sessions rather than failing the whole snapshot.
    _knownShardIds = ids.toSet();
    final keysRaw = index['keys'];
    return <String, dynamic>{
      'lastFetchedAt': index['lastFetchedAt'],
      'sessions': sessions,
      'encryptedDataKeys': keysRaw is Map
          ? Map<String, dynamic>.from(keysRaw)
          : <String, dynamic>{},
    };
  }

  /// Legacy single-blob read, byte-compatible with older builds.
  Future<Map<String, dynamic>?> _loadLegacyCache(Database db) async {
    final result = await _getObject(db, _sessionsCacheLegacyKey);
    if (result == null) return null;
    if (result is String) {
      return JsonDecoders.tryDecodeRawMapOrNull(
        result,
        context: 'IndexedDB sessions cache',
      );
    }
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    return null;
  }

  /// Saves the sessions cache to IndexedDB.
  void saveSessionsCache(Map<String, dynamic> cache) {
    // Fire-and-forget to keep the sync path non-blocking.
    _saveSessionsCacheAsync(cache);
  }

  Future<void> saveSessionsCacheAsync(Map<String, dynamic> cache) =>
      _saveSessionsCacheAsync(cache);

  Future<void> _saveSessionsCacheAsync(Map<String, dynamic> cache) async {
    try {
      final db = await _openDb();
      final shards = await _encodeShards(cache);
      // Records without usable ids cannot be addressed per-shard; keep the
      // legacy whole-blob write rather than dropping the snapshot.
      if (shards == null) {
        await _saveLegacyBlob(cache);
        return;
      }
      final indexJson = jsonEncode(<String, dynamic>{
        'v': _sessionsCacheShardFormatVersion,
        'lastFetchedAt': cache['lastFetchedAt'],
        'ids': shards.keys.toList(),
        'keys': cache['encryptedDataKeys'],
      });
      final changedIds = <String>[
        for (final entry in shards.entries)
          if (_knownShardJson[entry.key] != entry.value.json) entry.key,
      ];
      final removedIds = <String>[
        for (final id in _knownShardIds)
          if (!shards.containsKey(id)) id,
      ];
      final indexChanged = _knownIndexJson != indexJson;
      if (!indexChanged && changedIds.isEmpty && removedIds.isEmpty) {
        _rememberSnapshot(shards, indexJson);
        return;
      }

      final txn = db.transaction(_sessionsCacheStoreName, idbModeReadWrite);
      final store = txn.objectStore(_sessionsCacheStoreName);
      for (final id in changedIds) {
        unawaited(store.put(shards[id]!.json, '$_sessionsCacheShardPrefix$id'));
      }
      for (final id in removedIds) {
        unawaited(store.delete('$_sessionsCacheShardPrefix$id'));
      }
      // Self-heal shards orphaned by another tab or a crashed save: drop
      // any prefixed record the current snapshot does not contain.
      final allKeys = await store.getAllKeys(null);
      for (final key in allKeys) {
        if (key is! String || !key.startsWith(_sessionsCacheShardPrefix)) {
          continue;
        }
        if (!shards.containsKey(
          key.substring(_sessionsCacheShardPrefix.length),
        )) {
          unawaited(store.delete(key));
        }
      }
      unawaited(store.put(indexJson, _sessionsCacheIndexKey));
      if (!_legacyBlobRemoved) {
        _legacyBlobRemoved = true;
        unawaited(store.delete(_sessionsCacheLegacyKey));
      }
      await txn.completed;
      _rememberSnapshot(shards, indexJson);
    } catch (e) {
      logger.warning('IndexedDB: failed to save sessions cache: $e');
    }
  }

  /// Encodes each session record individually with event-loop yields
  /// between batches. Returns null when the snapshot cannot be sharded
  /// (missing/invalid records), signaling the legacy fallback.
  Future<Map<String, _SessionShard>?> _encodeShards(
    Map<String, dynamic> cache,
  ) async {
    final sessionsRaw = cache['sessions'];
    if (sessionsRaw is! List) return null;
    final shards = <String, _SessionShard>{};
    var processed = 0;
    for (final record in sessionsRaw) {
      if (record is! Map) return null;
      final id = record['id'];
      if (id is! String || id.isEmpty) return null;
      final unchanged = identical(_knownShardObjects[id], record);
      final json = unchanged && _knownShardJson[id] != null
          ? _knownShardJson[id]!
          : jsonEncode(record);
      shards[id] = _SessionShard(json, record);
      if (!unchanged) {
        processed++;
        if (processed % _sessionsCacheBatchSize == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }
    }
    return shards;
  }

  /// Commits [shards] + [indexJson] into the dirty-tracking memory so the
  /// next save diffs against exactly what this process last wrote. Only
  /// called after a transaction completed (or proved unnecessary).
  void _rememberSnapshot(Map<String, _SessionShard> shards, String indexJson) {
    _knownShardJson.clear();
    _knownShardObjects.clear();
    for (final entry in shards.entries) {
      _knownShardJson[entry.key] = entry.value.json;
      _knownShardObjects[entry.key] = entry.value.instance;
    }
    _knownShardIds = shards.keys.toSet();
    _knownIndexJson = indexJson;
  }

  /// Whole-blob write under the legacy record. Kept for snapshots that
  /// cannot be sharded and matches the pre-sharding format exactly.
  Future<void> _saveLegacyBlob(Map<String, dynamic> cache) async {
    try {
      final db = await _openDb();
      final txn = db.transaction(_sessionsCacheStoreName, idbModeReadWrite);
      final store = txn.objectStore(_sessionsCacheStoreName);
      await store.put(jsonEncode(cache), _sessionsCacheLegacyKey);
      await txn.completed;
    } catch (e) {
      logger.warning('IndexedDB: failed to save sessions cache: $e');
    }
  }

  /// Clears the sessions cache from IndexedDB.
  void clearSessionsCache() {
    _clearSessionsCacheAsync();
  }

  Future<void> _clearSessionsCacheAsync() async {
    try {
      final db = await _openDb();
      final txn = db.transaction(_sessionsCacheStoreName, idbModeReadWrite);
      final store = txn.objectStore(_sessionsCacheStoreName);
      unawaited(store.delete(_sessionsCacheLegacyKey));
      unawaited(store.delete(_sessionsCacheIndexKey));
      final allKeys = await store.getAllKeys(null);
      for (final key in allKeys) {
        if (key is String && key.startsWith(_sessionsCacheShardPrefix)) {
          unawaited(store.delete(key));
        }
      }
      await txn.completed;
      _knownShardJson.clear();
      _knownShardObjects.clear();
      _knownShardIds = <String>{};
      _knownIndexJson = null;
      _legacyBlobRemoved = false;
    } catch (e) {
      logger.warning('IndexedDB: failed to clear sessions cache: $e');
    }
  }

  /// Closes the database connection.
  void close() {
    _db?.close();
    _db = null;
  }
}
