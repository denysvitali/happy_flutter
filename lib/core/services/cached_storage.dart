import 'dart:async';
import 'dart:convert';

import 'logger_service.dart' show logger;
import 'mmkv_storage.dart';

/// Base class for MMKV-backed stores that keep an in-memory cache of type [T]
/// and persist it to a single MMKV key with a 500ms debounce.
///
/// Encapsulates the repeated lazy-load + Timer-based debounced-write pattern
/// found across [PinnedSessionsStorage], [SessionFoldersStorage], and
/// [RecentCommandsStorage]. Subclasses provide the storage [key], a
/// [decode]/[encode] pair, and an [empty] value.
abstract class CachedStorage<T> {
  CachedStorage({MMKVStorage? storage})
      : _storage = storage ?? MMKVStorage();

  final MMKVStorage _storage;

  T? _cache;
  Timer? _persistTimer;

  static const Duration debounceDuration = Duration(milliseconds: 500);

  /// MMKV key under which the encoded value is stored.
  String get key;

  /// Label used in warning logs when a load fails. Defaults to the runtime
  /// type name.
  String get logLabel => '$runtimeType';

  /// Value returned when nothing is persisted or decoding fails.
  T empty();

  /// Decodes a previously [encode]d JSON payload back into [T].
  T decode(dynamic json);

  /// Encodes the current cache into a JSON-serializable value.
  dynamic encode(T value);

  T _loadCache() {
    try {
      final raw = _storage.getString(key);
      if (raw != null) {
        return decode(jsonDecode(raw));
      }
    } catch (e) {
      logger.warning('$logLabel: Failed to load: $e');
    }
    return empty();
  }

  /// Returns the cached value, lazily loading from MMKV on first access.
  T get cache => _cache ??= _loadCache();

  /// Mutates the cache (loading it first if needed) and schedules a
  /// debounced persist. Convenience for subclass mutators.
  void mutate(void Function(T value) update) {
    update(cache);
    schedulePersist();
  }

  /// Cancels any pending write and starts a fresh 500ms debounce timer.
  void schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(debounceDuration, persistNow);
  }

  /// Writes the current cache to MMKV immediately, bypassing the debounce.
  void persistNow() {
    final value = _cache;
    if (value != null) {
      _storage.setString(key, jsonEncode(encode(value)));
    }
  }

  /// Eagerly loads the in-memory cache and returns it.
  T initCache() => _cache = _loadCache();

  /// Clears the cache, cancels any pending write, and removes the MMKV key.
  void clearAll() {
    _persistTimer?.cancel();
    _persistTimer = null;
    _cache = null;
    _storage.removeKey(key);
  }
}
