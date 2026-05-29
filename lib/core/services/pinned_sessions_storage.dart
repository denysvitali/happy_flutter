import 'cached_storage.dart';

/// MMKV-backed storage for pinned session IDs.
///
/// Backed by [CachedStorage], which provides the in-memory cache and the
/// 500ms debounced MMKV write.
class PinnedSessionsStorage extends CachedStorage<Set<String>> {
  PinnedSessionsStorage._();

  static final PinnedSessionsStorage instance = PinnedSessionsStorage._();

  @override
  String get key => 'pinned-sessions';

  @override
  String get logLabel => 'PinnedSessionsStorage';

  @override
  Set<String> empty() => <String>{};

  @override
  Set<String> decode(dynamic json) =>
      (json as List<dynamic>).whereType<String>().toSet();

  @override
  dynamic encode(Set<String> value) => value.toList();

  /// Returns the current pinned set, loading from MMKV on first call.
  Set<String> getPinned() => cache;

  /// Returns true if the session is currently pinned.
  bool isPinned(String id) => getPinned().contains(id);

  /// Adds a session to the pinned set.
  Future<void> pinSession(String id) async => mutate((s) => s.add(id));

  /// Removes a session from the pinned set.
  Future<void> unpinSession(String id) async => mutate((s) => s.remove(id));
}
