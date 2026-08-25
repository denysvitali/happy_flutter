/// Decrypted message body that the native core has already parsed and
/// validated as JSON, carried as text until a worker isolate materializes
/// it into Dart objects.
///
/// The Rust core (`rust/happy_core/src/json.rs`) walks the full JSON grammar
/// in the same crossing as the decrypt. Building the Dart object tree is the
/// one part Rust cannot do cheaper than `jsonDecode`, so that step is
/// deferred to wherever the row is consumed — the message-processing
/// isolate for a page, or the single-row convenience path — and never
/// happens on the UI isolate for a batch. A distinct type (rather than a
/// bare `String`) keeps this unambiguous from a decrypted body whose JSON
/// value *is* a string.
///
/// Sendable across isolates: one final `String` field, no closures.
final class JsonText {
  const JsonText(this.text);

  /// Well-formed JSON text, byte-identical to the sealed plaintext.
  final String text;

  /// Character count, used by the cache byte budget.
  int get length => text.length;

  @override
  String toString() => text;
}

/// Row outcome codes reported by the native decrypt-and-parse batch.
/// Mirrors `RowStatus` in `rust/happy_core/src/json.rs`.
abstract final class NativeJsonRowStatus {
  static const int ok = 0;
  static const int badBase64 = 1;
  static const int badEnvelope = 2;
  static const int authFailed = 3;
  static const int notUtf8 = 4;
  static const int invalidJson = 5;
  static const int badKey = 6;

  static String label(int status) => switch (status) {
    ok => 'ok',
    badBase64 => 'bad_base64',
    badEnvelope => 'bad_envelope',
    authFailed => 'auth_failed',
    notUtf8 => 'not_utf8',
    invalidJson => 'invalid_json',
    badKey => 'bad_key',
    _ => 'unknown',
  };
}
