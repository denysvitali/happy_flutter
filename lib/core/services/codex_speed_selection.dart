import 'package:happy_flutter/core/services/mmkv_storage.dart';

/// Durable per-session Codex speed overrides.
///
/// The string representation leaves room for future speed tiers while this
/// client currently accepts only Standard and Fast.
class CodexSpeedSelection {
  static const _prefix = 'codex-speed-selection-';

  String _key(String sessionId) => '$_prefix$sessionId';

  /// Returns true for Fast, false for Standard, or null with no valid override.
  bool? read(String sessionId) {
    final value = MMKVStorage().getString(_key(sessionId));
    return switch (value) {
      'standard' => false,
      'fast' => true,
      _ => null,
    };
  }

  /// Persists a supported speed choice for this session.
  void save(String sessionId, bool fastMode) {
    MMKVStorage().setString(_key(sessionId), fastMode ? 'fast' : 'standard');
  }

  /// Move the durable choice when a restored process receives a new ID.
  void move(String sourceSessionId, String restoredSessionId) {
    if (sourceSessionId == restoredSessionId) return;
    final value = read(sourceSessionId);
    if (value != null) save(restoredSessionId, value);
    MMKVStorage().removeKey(_key(sourceSessionId));
  }
}
