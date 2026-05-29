import 'cached_storage.dart';

/// MMKV-backed storage for the last [maxEntries] executed command palette IDs.
///
/// Most-recently executed command is at index 0. On each [recordCommand]
/// call the ID is moved (or prepended) to the front, and the list is
/// capped at [maxEntries]. Backed by [CachedStorage] for the in-memory
/// cache and 500ms debounced write.
class RecentCommandsStorage extends CachedStorage<List<String>> {
  RecentCommandsStorage._();

  static final RecentCommandsStorage instance = RecentCommandsStorage._();

  static const int maxEntries = 3;

  @override
  String get key => 'palette-recent-cmd-ids';

  @override
  String get logLabel => 'RecentCommandsStorage';

  @override
  List<String> empty() => <String>[];

  @override
  List<String> decode(dynamic json) =>
      (json as List<dynamic>).whereType<String>().take(maxEntries).toList();

  @override
  dynamic encode(List<String> value) => value;

  /// Returns the stored recent command IDs, most-recent first.
  List<String> getRecent() => cache;

  /// Records [commandId] as the most-recently executed command.
  ///
  /// Moves it to the front if already present, then caps the list
  /// at [maxEntries] and schedules a debounced persist (500ms).
  void recordCommand(String commandId) {
    mutate((list) {
      list
        ..remove(commandId)
        ..insert(0, commandId);
      if (list.length > maxEntries) {
        list.removeRange(maxEntries, list.length);
      }
    });
  }
}
