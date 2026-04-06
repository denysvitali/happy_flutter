import 'dart:async';
import 'dart:convert';

import 'logger_service.dart' show logger;
import 'mmkv_storage.dart';

/// MMKV-backed storage for session-to-folder mapping.
///
/// Stores a JSON-encoded Map<String, String> (sessionId -> folder name).
/// Follows the 500ms debounce pattern for batching writes.
class SessionFoldersStorage {
  SessionFoldersStorage._();

  static final SessionFoldersStorage instance = SessionFoldersStorage._();

  static const String _key = 'session-folders';

  final _storage = MMKVStorage();

  Map<String, String>? _cache;
  Timer? _persistTimer;

  static const _debounceDuration = Duration(milliseconds: 500);

  Map<String, String> _loadCache() {
    try {
      final json = _storage.getString(_key);
      if (json != null) {
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        return decoded.map((k, v) => MapEntry(k, v as String));
      }
    } catch (e) {
      logger.warning('SessionFoldersStorage: Failed to load: $e');
    }
    return {};
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(_debounceDuration, _persistNow);
  }

  void _persistNow() {
    final cache = _cache;
    if (cache != null) {
      _storage.setString(_key, jsonEncode(cache));
    }
  }

  /// Returns all session-to-folder mappings.
  Map<String, String> getAllFolders() {
    return _cache ??= _loadCache();
  }

  /// Returns the folder for [sessionId], or null if unfiled.
  String? getFolder(String sessionId) => getAllFolders()[sessionId];

  /// Sets the folder for [sessionId]. Pass null [folder] to unfiled.
  Future<void> setFolder(String sessionId, String? folder) async {
    final cache = getAllFolders();
    if (folder == null) {
      cache.remove(sessionId);
    } else {
      cache[sessionId] = folder;
    }
    _schedulePersist();
  }

  /// Removes a session from folder tracking.
  Future<void> removeSession(String sessionId) async {
    final cache = getAllFolders();
    cache.remove(sessionId);
    _schedulePersist();
  }

  /// Clears all folder assignments.
  Future<void> clearAll() async {
    _cache?.clear();
    _persistTimer?.cancel();
    _storage.removeKey(_key);
  }

  /// Initializes the in-memory cache.
  Future<Map<String, String>> initCache() async {
    _cache = _loadCache();
    return _cache!;
  }
}
