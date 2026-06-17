import 'dart:convert';

import '../models/loop.dart';
import 'cached_storage.dart';
import 'logger_service.dart' show logger;
import 'mmkv_storage.dart';

/// MMKV-backed storage for loops per session.
///
/// Persists loops as a JSON-encoded list per session under the key
/// `loops:<sessionId>`. Reads are lazy (on first access), writes are
/// debounced by [CachedStorage] to 500ms. The in-memory cache is exposed
/// via [cache] for read paths that need a snapshot.
///
/// Storage mirrors the `RecentCommandsStorage` pattern but is keyed per
/// session since each session has its own loop list.
class LoopStorage {
  LoopStorage._();
  static final LoopStorage instance = LoopStorage._();

  /// MMKV instance used for persistence. Tests can override via
  /// [LoopStorage.storageForTesting].
  MMKVStorage _storage = MMKVStorage();

  /// Test-only injection point.
  void setStorageForTesting(MMKVStorage storage) {
    _storage = storage;
  }

  static const String _prefix = 'loops:';

  String _key(String sessionId) => '$_prefix$sessionId';

  /// Loads the persisted loops for [sessionId]. Returns an empty list when
  /// nothing is stored or when decoding fails.
  List<Loop> load(String sessionId) {
    try {
      final raw = _storage.getString(_key(sessionId));
      if (raw == null || raw.isEmpty) return const <Loop>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <Loop>[];
      return decoded
          .whereType<Map>()
          .map(
            (e) => Loop.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(growable: false);
    } catch (e, st) {
      logger.warning('LoopStorage.load($sessionId) failed: $e', e, st);
      return const <Loop>[];
    }
  }

  /// Writes [loops] for [sessionId] immediately, bypassing any debounce.
  ///
  /// Fire-and-forget — the MMKV write is synchronous, so any failure is
  /// logged but never propagates to the caller.
  void save(String sessionId, List<Loop> loops) {
    try {
      final encoded = jsonEncode(
        loops.map((l) => l.toJson()).toList(growable: false),
      );
      _storage.setString(_key(sessionId), encoded);
    } catch (e, st) {
      logger.warning('LoopStorage.save($sessionId) failed: $e', e, st);
    }
  }

  /// Clears any persisted loops for [sessionId].
  void clear(String sessionId) {
    _storage.removeKey(_key(sessionId));
  }
}

/// Alias used by callers that prefer the verb-named factory
/// (e.g. `LoopStorage().load(...)`).
typedef LoopStorageFactory = LoopStorage Function();

/// Default [LoopStorage] factory.
LoopStorage defaultLoopStorage() => LoopStorage.instance;

/// Extension-free helper to get the singleton. Most call sites should
/// use [LoopStorage.instance] directly; this is a convenience for places
/// where [LoopStorage] is referenced as a type without the static accessor.
extension LoopStorageExt on LoopStorage {
  static LoopStorage get shared => LoopStorage.instance;
}
