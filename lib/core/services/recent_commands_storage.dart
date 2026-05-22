import 'dart:convert';

import 'logger_service.dart' show logger;
import 'mmkv_storage.dart';

/// MMKV-backed storage for the last [maxEntries] executed command palette IDs.
///
/// Most-recently executed command is at index 0. On each [recordCommand]
/// call the ID is moved (or prepended) to the front, and the list is
/// capped at [maxEntries].
class RecentCommandsStorage {
  RecentCommandsStorage._();

  static final RecentCommandsStorage instance = RecentCommandsStorage._();

  static const String _key = 'palette-recent-cmd-ids';
  static const int maxEntries = 3;

  final _storage = MMKVStorage();
  List<String>? _cache;

  List<String> _loadCache() {
    try {
      final json = _storage.getString(_key);
      if (json != null) {
        final decoded = jsonDecode(json) as List<dynamic>;
        return decoded.whereType<String>().take(maxEntries).toList();
      }
    } catch (e) {
      logger.warning('RecentCommandsStorage: Failed to load: $e');
    }
    return [];
  }

  void _persist() {
    final cache = _cache;
    if (cache != null) {
      _storage.setString(_key, jsonEncode(cache));
    }
  }

  /// Returns the stored recent command IDs, most-recent first.
  List<String> getRecent() => _cache ??= _loadCache();

  /// Records [commandId] as the most-recently executed command.
  ///
  /// Moves it to the front if already present, then caps the list
  /// at [maxEntries] and persists synchronously.
  void recordCommand(String commandId) {
    final list = getRecent();
    list
      ..remove(commandId)
      ..insert(0, commandId);
    if (list.length > maxEntries) {
      list.removeRange(maxEntries, list.length);
    }
    _persist();
  }

  /// Clears all recent commands.
  void clearAll() {
    _cache?.clear();
    _storage.removeKey(_key);
  }
}
