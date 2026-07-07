import 'dart:convert';

import '../models/workflow_run.dart';
import 'cached_storage.dart';
import 'logger_service.dart' show logger;
import 'mmkv_storage.dart';

/// MMKV-backed storage for workflow runs per session.
///
/// Persists workflows as a JSON-encoded list per session under the key
/// `workflows:<sessionId>`. Reads are lazy (on first access), writes are
/// debounced by [CachedStorage] to 500ms. The in-memory cache is exposed
/// via [cache] for read paths that need a snapshot.
///
/// Mirrors the [LoopStorage] pattern.
class WorkflowStorage {
  WorkflowStorage._();
  static final WorkflowStorage instance = WorkflowStorage._();

  /// MMKV instance used for persistence. Tests can override via
  /// [WorkflowStorage.storageForTesting].
  MMKVStorage _storage = MMKVStorage();

  /// Test-only injection point.
  void setStorageForTesting(MMKVStorage storage) {
    _storage = storage;
  }

  static const String _prefix = 'workflows:';

  String _key(String sessionId) => '$_prefix$sessionId';

  /// Loads the persisted workflows for [sessionId]. Returns an empty list
  /// when nothing is stored, decoding fails, or every entry was malformed.
  /// Malformed entries are skipped with a warning rather than failing the
  /// whole batch — see [WorkflowRun.tryFromJson].
  List<WorkflowRun> load(String sessionId) {
    try {
      final raw = _storage.getString(_key(sessionId));
      if (raw == null || raw.isEmpty) return const <WorkflowRun>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <WorkflowRun>[];
      final out = <WorkflowRun>[];
      for (final entry in decoded.whereType<Map>()) {
        final run = WorkflowRun.tryFromJson(Map<String, dynamic>.from(entry));
        if (run != null) {
          out.add(run);
        }
      }
      return List<WorkflowRun>.unmodifiable(out);
    } catch (e, st) {
      logger.warning(
        'WorkflowStorage.load($sessionId) failed: $e',
        e,
        st,
      );
      return const <WorkflowRun>[];
    }
  }

  /// Writes [workflows] for [sessionId] immediately, bypassing any debounce.
  ///
  /// Fire-and-forget — the MMKV write is synchronous, so any failure is
  /// logged but never propagates to the caller.
  void save(String sessionId, List<WorkflowRun> workflows) {
    try {
      final encoded = jsonEncode(
        workflows.map((w) => w.toJson()).toList(growable: false),
      );
      _storage.setString(_key(sessionId), encoded);
    } catch (e, st) {
      logger.warning(
        'WorkflowStorage.save($sessionId) failed: $e',
        e,
        st,
      );
    }
  }

  /// Clears any persisted workflows for [sessionId].
  void clear(String sessionId) {
    _storage.removeKey(_key(sessionId));
  }
}

/// Alias used by callers that prefer the verb-named factory.
typedef WorkflowStorageFactory = WorkflowStorage Function();

/// Default [WorkflowStorage] factory.
WorkflowStorage defaultWorkflowStorage() => WorkflowStorage.instance;

/// Extension-free helper to get the singleton.
extension WorkflowStorageExt on WorkflowStorage {
  static WorkflowStorage get shared => WorkflowStorage.instance;
}
