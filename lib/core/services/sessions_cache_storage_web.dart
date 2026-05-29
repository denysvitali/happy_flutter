// Web-only sessions cache storage using IndexedDB via idb_shim.
//
// localStorage (SharedPreferences on web) has a ~5–10 MB quota shared across
// all keys. The sessions cache with hundreds of sessions can consume ~2 MB,
// leaving insufficient room for settings and other data. IndexedDB provides
// a much larger quota (50 MB+) and structured storage per key.
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
const String _sessionsCacheKey = 'cache';

/// Sessions cache storage for web using IndexedDB.
///
/// Replaces SharedPreferences (localStorage) for the sessions cache only.
/// Other small data (settings, drafts, permission modes) stays in
/// SharedPreferences to avoid wasting IndexedDB overhead.
class SessionsCacheStorage {
  SessionsCacheStorage._();
  static final SessionsCacheStorage instance = SessionsCacheStorage._();

  Database? _db;

  /// Opens the IndexedDB database, creating it if it doesn't exist.
  Future<Database> _openDb() async {
    if (_db != null) return _db!;
    final idbFactory = getIdbFactory();
    if (idbFactory == null) {
      throw StateError(
        'IndexedDB not supported in this browser',
      );
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

  /// Async version — use this for cold-start load.
  Future<Map<String, dynamic>?> getSessionsCacheAsync() async {
    try {
      final db = await _openDb();
      final txn = db.transaction(_sessionsCacheStoreName, idbModeReadOnly);
      final store = txn.objectStore(_sessionsCacheStoreName);
      final result = await store.getObject(_sessionsCacheKey);
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
    } catch (e) {
      logger.warning('IndexedDB: failed to load sessions cache: $e');
    }
    return null;
  }

  /// Saves the sessions cache to IndexedDB.
  void saveSessionsCache(Map<String, dynamic> cache) {
    // Fire-and-forget to keep the sync path non-blocking.
    _saveSessionsCacheAsync(cache);
  }

  Future<void> _saveSessionsCacheAsync(Map<String, dynamic> cache) async {
    try {
      final db = await _openDb();
      final txn = db.transaction(_sessionsCacheStoreName, idbModeReadWrite);
      final store = txn.objectStore(_sessionsCacheStoreName);
      await store.put(jsonEncode(cache), _sessionsCacheKey);
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
      await store.delete(_sessionsCacheKey);
      await txn.completed;
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
