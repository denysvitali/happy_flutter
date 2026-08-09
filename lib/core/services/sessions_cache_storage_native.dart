// Native implementation: delegates sessions cache reads/writes to MMKVStorage.
// Uses the same storage engine as all other data on native platforms.
library;

import 'package:happy_flutter/core/services/mmkv_storage.dart';

/// Sessions cache storage for native platforms.
///
/// On native, the sessions cache is stored in the same MMKV instance as all
/// other data. No special handling needed — just delegate to MMKVStorage.
class SessionsCacheStorage {
  SessionsCacheStorage._();
  static final SessionsCacheStorage instance = SessionsCacheStorage._();

  Map<String, dynamic>? getSessionsCache() => MMKVStorage().getSessionsCache();

  /// Async variant for API compatibility with the web implementation.
  /// On native, MMKV is synchronous so we wrap it.
  Future<Map<String, dynamic>?> getSessionsCacheAsync() async {
    return getSessionsCache();
  }

  void saveSessionsCache(Map<String, dynamic> cache) {
    MMKVStorage().saveSessionsCache(cache);
  }

  Future<void> saveSessionsCacheAsync(Map<String, dynamic> cache) =>
      MMKVStorage().saveSessionsCacheAsync(cache);

  void clearSessionsCache() => MMKVStorage().clearSessionsCache();
}
