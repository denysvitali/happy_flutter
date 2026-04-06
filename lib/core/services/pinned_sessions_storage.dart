import 'dart:async';
import 'dart:convert';

import 'package:mmkv/mmkv.dart';

import 'logger_service.dart' show logger;

/// MMKV-backed storage for pinned session IDs.
///
/// Uses the default MMKV instance via a getter, with 500ms debounce
/// on writes to batch rapid updates.
class PinnedSessionsStorage {
  PinnedSessionsStorage._();

  static final PinnedSessionsStorage instance = PinnedSessionsStorage._();

  static const String _key = 'pinned-sessions';

  MMKV? _mmkv;
  Set<String>? _cache;
  Timer? _persistTimer;

  static const _debounceDuration = Duration(milliseconds: 500);

  MMKV? _getMMKV() => _mmkv ?? MMKV.defaultMMKV();

  Set<String> _loadCache() {
    try {
      final json = _getMMKV()?.decodeString(_key);
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
      _getMMKV()?.encodeString(_key, jsonEncode(cache.toList()));
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
    final cache = getPinned();
    cache.add(id);
    _schedulePersist();
  }

  /// Removes a session from the pinned set.
  Future<void> unpinSession(String id) async {
    final cache = getPinned();
    cache.remove(id);
    _schedulePersist();
  }

  /// Clears all pinned sessions.
  Future<void> clearAll() async {
    _cache?.clear();
    _persistTimer?.cancel();
    _getMMKV()?.removeValue(_key);
  }

  /// Initializes the in-memory cache synchronously.
  Future<Set<String>> initCache() async {
    _cache = _loadCache();
    return _cache!;
  }
}
