/// Compile-time identity types for messaging.
///
/// These extension types (Dart 3.10+) wrap [String] without runtime cost
/// while preventing accidental mixing of different ID kinds at the
/// type-checker level.
///
/// They are deliberately **not** exhaustively adopted across the codebase
/// — that would require touching every `_sync_messaging*` part file and
/// would conflict with the architecture branch's parallel work.  Instead
/// they are:
///
///  1. Exported from a single place (this file) so the architecture
///     branch can adopt the same names later without rename churn.
///  2. Used at the entry point of [Sync.sendMessage] (see
///     `_sync_messaging_send.dart`) and the merge boundary so the four
///     P0 invariants from `ROADMAP.md` (`one tap → one localId`) are
///     reinforced at the type level.
///  3. Convertible to/from raw [String] via the implicit `value`
///     getter, so existing string-based call sites continue to work
///     during the migration.
library;

/// Client-generated identifier for a single logical message.
///
/// This is the canonical identifier that survives optimistic UI, REST
/// send, retry, socket forwarding, and merge.  Once a [LocalId] is
/// minted by [Sync.createLocalMessageId] it must **never** be
/// regenerated for the same logical send — see ROADMAP P0.
///
/// Wraps a [String] with zero runtime overhead.  Use [.value] to obtain
/// the raw string when interacting with JSON or wire formats.
extension type const LocalId(String value) implements Object {
  /// Whether this id is the empty sentinel.  The Go server sends
  /// `derefStr(nil) = ""` for agent messages, and the merge logic in
  /// `_sync_messaging_merge.dart` skips empty localIds to avoid
  /// evicting unrelated messages.
  bool get isEmpty => value.isEmpty;

  /// Whether this id has a non-empty value.
  bool get isNotEmpty => value.isNotEmpty;
}

/// Server-assigned message identifier (the value of `'id'` on the wire).
///
/// Distinct from [LocalId]: the server may keep the client's [LocalId]
/// in the `'localId'` field while assigning a new authoritative
/// [ServerMessageId] in `'id'`.
extension type const ServerMessageId(String value) implements Object {
  bool get isEmpty => value.isEmpty;
  bool get isNotEmpty => value.isNotEmpty;
}

/// Stable identifier for a session.
extension type const SessionId(String value) implements Object {
  bool get isEmpty => value.isEmpty;
  bool get isNotEmpty => value.isNotEmpty;
}

/// Helpers for converting between raw maps and identity types.
///
/// These read fields from the loose `Map<String, dynamic>` shape used
/// throughout `_sync_messaging*` without forcing an immediate rewrite
/// of every call site.
extension MessageMapIdentity on Map<String, dynamic> {
  /// Read the `'localId'` field as a [LocalId], or `null` if absent.
  LocalId? get localIdOrNull {
    final raw = this['localId'];
    if (raw is String) return LocalId(raw);
    return null;
  }

  /// Read the `'id'` field as a [ServerMessageId], or `null` if absent.
  ServerMessageId? get serverIdOrNull {
    final raw = this['id'];
    if (raw is String) return ServerMessageId(raw);
    return null;
  }
}
