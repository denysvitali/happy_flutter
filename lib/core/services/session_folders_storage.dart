import 'cached_storage.dart';

/// MMKV-backed storage for session-to-folder mapping.
///
/// Stores a JSON-encoded map from session id to folder name, backed by
/// [CachedStorage] for the in-memory cache and 500ms debounced write.
class SessionFoldersStorage extends CachedStorage<Map<String, String>> {
  SessionFoldersStorage._();

  static final SessionFoldersStorage instance = SessionFoldersStorage._();

  @override
  String get key => 'session-folders';

  @override
  String get logLabel => 'SessionFoldersStorage';

  @override
  Map<String, String> empty() => <String, String>{};

  @override
  Map<String, String> decode(dynamic json) =>
      (json as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String));

  @override
  dynamic encode(Map<String, String> value) => value;

  /// Returns all session-to-folder mappings.
  Map<String, String> getAllFolders() => cache;

  /// Returns the folder for [sessionId], or null if unfiled.
  String? getFolder(String sessionId) => getAllFolders()[sessionId];

  /// Sets the folder for [sessionId]. Pass null [folder] to unfiled.
  Future<void> setFolder(String sessionId, String? folder) async => mutate(
        (m) => folder == null ? m.remove(sessionId) : m[sessionId] = folder,
      );

  /// Removes a session from folder tracking.
  Future<void> removeSession(String sessionId) async =>
      mutate((m) => m.remove(sessionId));
}
