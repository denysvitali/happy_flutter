// Native implementation: delegates sessions cache reads/writes to MMKVStorage.
// Uses the same storage engine as all other data on native platforms.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;

import 'logger_service.dart' show logger;
import 'mmkv_storage.dart';

/// Sessions cache storage for native platforms.
///
/// On native, the sessions cache is stored in the same MMKV instance as all
/// other data. No special handling needed — just delegate to MMKVStorage.
class SessionsCacheStorage {
  SessionsCacheStorage._();
  static final SessionsCacheStorage instance = SessionsCacheStorage._();

  Map<String, dynamic>? getSessionsCache() => MMKVStorage().getSessionsCache();

  /// Async variant used by cold start. The cheap MMKV string read stays on
  /// the calling isolate; the parse of up to ~200 cached session records
  /// (the expensive part — hundreds of KB of JSON) runs in a worker so it
  /// cannot block first frame. Mirrors the message-cache worker pattern.
  Future<Map<String, dynamic>?> getSessionsCacheAsync() async {
    final raw = MMKVStorage().getSessionsCacheRawJson();
    if (raw == null || raw.isEmpty) return null;
    try {
      return await compute(_decodeSessionsCacheJson, raw);
    } catch (e) {
      logger.warning('MMKV: sessions cache worker decode failed: $e');
      // Isolate spawn failure (some test environments) — decode inline
      // rather than losing the cold-start cache entirely.
      return _decodeSessionsCacheJson(raw);
    }
  }

  void saveSessionsCache(Map<String, dynamic> cache) {
    MMKVStorage().saveSessionsCache(cache);
  }

  Future<void> saveSessionsCacheAsync(Map<String, dynamic> cache) =>
      MMKVStorage().saveSessionsCacheAsync(cache);

  void clearSessionsCache() => MMKVStorage().clearSessionsCache();
}

/// Top-level so [compute] can send it to a worker isolate.
Map<String, dynamic>? _decodeSessionsCacheJson(String json) {
  try {
    final decoded = jsonDecode(json);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {
    // Caller logs with storage context; a corrupt cache behaves as absent.
  }
  return null;
}
