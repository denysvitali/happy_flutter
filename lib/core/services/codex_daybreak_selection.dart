import 'package:happy_flutter/core/services/mmkv_storage.dart';

/// A Codex cyber access program (Daybreak) choice, as sent in
/// `meta.codexCyberAccessProgram`. happy-cli-go applies it from the next
/// turn without restarting Codex and persists it in session metadata.
enum CodexDaybreakChoice {
  /// Use the daemon's configured program.
  machine('machine'),

  /// Request no program: Daybreak off, Codex selects automatically.
  off('auto'),

  /// Daybreak Blue (the tier `gpt-6.1-sol` accepts).
  blue('daybreak_blue'),

  /// Daybreak Red.
  red('daybreak_red'),

  /// The explicit standard treatment.
  standard('standard');

  const CodexDaybreakChoice(this.wire);

  /// Value sent to happy-cli-go.
  final String wire;

  static CodexDaybreakChoice? fromWire(String? value) {
    for (final choice in values) {
      if (choice.wire == value) return choice;
    }
    return null;
  }

  /// The choice whose effective program is [program] ("" = none).
  static CodexDaybreakChoice fromProgram(String program) => switch (program) {
    'daybreak_blue' => blue,
    'daybreak_red' => red,
    'standard' => standard,
    _ => off,
  };
}

/// Durable per-session Daybreak overrides.
class CodexDaybreakSelection {
  static const _prefix = 'codex-daybreak-selection-';

  String _key(String sessionId) => '$_prefix$sessionId';

  CodexDaybreakChoice? read(String sessionId) =>
      CodexDaybreakChoice.fromWire(MMKVStorage().getString(_key(sessionId)));

  void save(String sessionId, CodexDaybreakChoice choice) {
    MMKVStorage().setString(_key(sessionId), choice.wire);
  }

  /// Move the choice when a restored process receives a new ID.
  void move(String sourceSessionId, String restoredSessionId) {
    if (sourceSessionId == restoredSessionId) return;
    final value = read(sourceSessionId);
    if (value != null) save(restoredSessionId, value);
    MMKVStorage().removeKey(_key(sourceSessionId));
  }

  /// The `meta.codexCyberAccessProgram` value for the next message: the
  /// session's own choice, else Daybreak Blue when [daybreakByDefault] is on
  /// and the session has not reported a session-level choice. Null omits it.
  String? wireValueFor(
    String sessionId, {
    required bool daybreakByDefault,
    String? reportedSource,
  }) {
    final chosen = read(sessionId);
    if (chosen != null) return chosen.wire;
    if (daybreakByDefault && reportedSource != 'session') {
      return CodexDaybreakChoice.blue.wire;
    }
    return null;
  }
}
