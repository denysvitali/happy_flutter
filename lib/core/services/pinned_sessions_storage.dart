import 'dart:async';
import 'dart:convert';

import 'logger_service.dart' show logger;
import 'mmkv_storage.dart';

/// MMKV-backed storage for pinned session IDs.
///
/// Uses the default MMKV instance via a getter, with 500ms debounce
/// on writes to batch rapid updates.
class PinnedSessionsStorage {
  PinnedSessionsStorage._();

  static final PinnedSessionsStorage instance = PinnedSessionsStorage._();

  static const String _key = 'pinned-sessions';

  final _storage = MMKVStorage();

  Set<String>? _cache;
  Timer? _persistTimer;

  static const _debounceDuration = Duration(milliseconds: 500);

  Set<String> _loadCache() {
    try {
      final json = _storage.getString(_key);
      if (json != null) {
        final decoded = jsonDecode(json) as List<dynamic>;
        return decoded.whereType<String>().toSet();
      }
    } catch (e) {
      logger.warning('PinnedSessionsStorage: Failed to load: $e');
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
      _storage.setString(_key, jsonEncode(cache.toList()));
    }
  }

  /// Returns the current pinned set, loading from MMKV on first call.
  Set<String> getPinned() {
    return _cache ??= _loadCache();
  }

  /// Returns true if the session is currently pinned.
  bool isPinned(String id) => getPinned().contains(id);

  /// Adds a session to the pinned set.
  Future<void> pinSession(String id) async {
    getPinned().add(id);
    _schedulePersist();
  }

  /// Removes a session from the pinned set.
  Future<void> unpinSession(String id) async {
    getPinned().remove(id);
    _schedulePersist();
  }

  /// Clears all pinned sessions.
  Future<void> clearAll() async {
    _cache?.clear();
    _persistTimer?.cancel();
    _storage.removeKey(_key);
  }

  /// Initializes the in-memory cache synchronously.
  Future<Set<String>> initCache() async {
    _cache = _loadCache();
    return _cache!;
  }
}
